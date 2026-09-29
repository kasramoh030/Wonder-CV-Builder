import '../entities/resume.dart';
import '../entities/resume_content.dart';
import '../enums/section_key.dart';

/// A flattened, searchable view of a CV.
///
/// Both analysers (offline rules and job-advert matching) need the same
/// things: the full text, the bullets, and a normalised word set. Building it
/// once here keeps the two engines consistent — a keyword that counts as
/// "present" for the ATS check counts as present for the job match too.
class CvTextIndex {
  CvTextIndex._({
    required this.rawText,
    required this.normalisedText,
    required this.foldedText,
    required this.words,
    required this.bullets,
    required this.headings,
    required this.bySection,
  });

  /// Text as the user typed it, used for display.
  final String rawText;

  /// Lower-cased, whitespace-collapsed form, used for phrase matching.
  final String normalisedText;

  /// Accent- and variant-folded form: `Müller` → `muller`, Arabic Yeh → Persian
  /// Yeh, Persian digits → ASCII. Search never fails because of a diacritic.
  final String foldedText;

  /// Normalised tokens, stop words included (the analyser decides what to
  /// ignore).
  final List<String> words;

  /// Every bullet, as authored, across responsibilities and achievements.
  final List<String> bullets;

  /// Section headings the document will print, in the order they will print.
  final List<SectionKey> headings;

  /// Flattened text per section, so a finding can say *where* it applies.
  final Map<SectionKey, String> bySection;

  /// `true` when [term] appears anywhere in the document.
  bool contains(String term) => foldedText.contains(fold(term));

  /// Number of times [term] appears, counted on word boundaries for single
  /// words and as a substring for multi-word phrases.
  int occurrences(String term) {
    final String needle = fold(term);
    if (needle.isEmpty) return 0;
    if (needle.contains(' ')) {
      int count = 0;
      int from = 0;
      while (true) {
        final int at = foldedText.indexOf(needle, from);
        if (at < 0) return count;
        count++;
        from = at + needle.length;
      }
    }
    return words.where((String w) => w == needle).length;
  }

  /// Tokens worth counting: stop words and single letters removed.
  Iterable<String> get significantWords =>
      words.where((String w) => w.length > 2);

  static CvTextIndex of(Resume resume, {Set<SectionKey>? hiddenSections}) {
    final ResumeContent c = resume.content;
    final Set<SectionKey> hidden =
        hiddenSections ?? resume.hiddenSections.toSet();
    final List<String> lines = <String>[];
    final List<String> bullets = <String>[];
    final Map<SectionKey, String> bySection = <SectionKey, String>{};
    final List<SectionKey> headings = <SectionKey>[];

    void section(SectionKey key, List<String> lines) {
      if (lines.isEmpty || hidden.contains(key)) return;
      headings.add(key);
      bySection[key] = lines.join('\n');
    }

    // Personal block: facts and links, but not the field labels.
    final PersonalInfo p = c.personal;
    lines.addAll(<String>[
      p.fullName,
      p.jobTitle,
      p.summary,
      p.email,
      p.phone,
      p.locationLine,
      p.linkedIn,
      p.gitHub,
      p.website,
    ].where((String s) => s.trim().isNotEmpty));

    section(
      SectionKey.summary,
      <String>[p.summary].where((String s) => s.trim().isNotEmpty).toList(),
    );

    final List<String> experience = <String>[];
    for (final Experience e in c.experiences) {
      if (e.hidden) continue;
      experience.addAll(<String>[e.jobTitle, e.company, e.location, e.technologyLine]);
      for (final String b in e.allBullets) {
        if (b.trim().isEmpty) continue;
        experience.add(b);
        bullets.add(b);
      }
    }
    section(SectionKey.experience, experience);

    final List<String> education = <String>[];
    for (final Education e in c.education) {
      if (e.hidden) continue;
      education.addAll(<String>[
        e.degree,
        e.fieldOfStudy,
        e.institution,
        e.location,
        e.description,
      ]);
    }
    section(SectionKey.education, education);

    final List<String> skills = <String>[];
    for (final Skill s in c.skills) {
      if (s.name.trim().isEmpty) continue;
      skills.addAll(<String>[s.name, s.category]);
    }
    section(SectionKey.skills, skills);

    section(
      SectionKey.languages,
      c.languages.map((LanguageSkill l) => '${l.language} ${l.level.id}').toList(),
    );

    final List<String> projects = <String>[];
    for (final Project pr in c.projects) {
      if (pr.hidden) continue;
      projects.addAll(<String>[pr.name, pr.description, pr.technologies.join(' ')]);
      for (final String b in <String>[pr.description]) {
        if (b.trim().isNotEmpty) bullets.add(b);
      }
    }
    section(SectionKey.projects, projects);

    section(
      SectionKey.certifications,
      c.certifications
          .where((Certification x) => !x.hidden)
          .map((Certification x) => '${x.name} ${x.organization}')
          .toList(),
    );
    section(
      SectionKey.awards,
      c.awards
          .where((Award a) => !a.hidden)
          .map((Award a) => '${a.title} ${a.issuer} ${a.description}')
          .toList(),
    );
    section(
      SectionKey.publications,
      c.publications
          .where((Publication x) => !x.hidden)
          .map((Publication x) => '${x.title} ${x.authors} ${x.venue}')
          .toList(),
    );

    for (final SectionKey key in <SectionKey>[
      SectionKey.volunteering,
      SectionKey.courses,
      SectionKey.researchExperience,
      SectionKey.teachingExperience,
      SectionKey.academicAppointments,
      SectionKey.conferences,
      SectionKey.presentations,
      SectionKey.grants,
      SectionKey.academicService,
      SectionKey.memberships,
    ]) {
      final List<String> entries = c
          .datedEntriesFor(key)
          .where((DatedEntry e) => !e.hidden)
          .map((DatedEntry e) =>
              '${e.title} ${e.organization} ${e.location} ${e.description}')
          .toList();
      section(key, entries);
      for (final DatedEntry e in c.datedEntriesFor(key)) {
        if (!e.hidden && e.description.trim().isNotEmpty) {
          bullets.add(e.description);
        }
      }
    }

    section(
      SectionKey.references,
      c.references
          .where((Reference r) => !r.hidden)
          .map((Reference r) =>
              '${r.name} ${r.position} ${r.organization} ${r.email} ${r.phone}')
          .toList(),
    );

    for (final CustomSection cs in c.customSections) {
      if (cs.hidden) continue;
      final List<String> body = <String>[
        cs.bodyText,
        ...cs.entries.where((DatedEntry e) => !e.hidden).map(
              (DatedEntry e) =>
                  '${e.title} ${e.organization} ${e.description}',
            ),
      ];
      bySection[SectionKey.additionalInfo] = <String>[
        ...?bySection[SectionKey.additionalInfo]?.split('\n'),
        cs.title,
        ...body,
      ].join('\n');
      lines.addAll(body);
    }

    section(
      SectionKey.researchInterests,
      c.researchInterests,
    );
    section(SectionKey.interests, c.interests);
    section(SectionKey.digitalSkills, c.digitalSkills);
    section(SectionKey.keySkills, c.keySkills);

    section(
      SectionKey.additionalInfo,
      <String>[
        ...?bySection[SectionKey.additionalInfo]?.split('\n'),
        c.additionalInfo,
        c.militaryService,
        c.drivingLicence,
      ].where((String s) => s.trim().isNotEmpty).toList(),
    );

    lines.addAll(bySection.values.expand((String s) => s.split('\n')));

    final String raw = lines.where((String s) => s.trim().isNotEmpty).join('\n');
    final String normalised = normalise(raw);
    return CvTextIndex._(
      rawText: raw,
      normalisedText: normalised,
      foldedText: fold(normalised),
      words: tokenise(normalised),
      bullets: bullets.where((String b) => b.trim().isNotEmpty).toList(),
      headings: headings,
      bySection: bySection,
    );
  }

  /// Lower-case and collapse whitespace, keeping punctuation as typed.
  static String normalise(String input) => input
      .replaceAll(RegExp(r'[\u200b\u200e\u200f]'), '')
      .toLowerCase()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  /// Removes accents where that is safe, and unifies the Arabic/Persian
  /// letter variants that look identical but compare differently.
  static String fold(String input) {
    final StringBuffer out = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      switch (rune) {
        case 0x064A || 0x0649 || 0x06CC: // Arabic yeh, alef maksura, farsi yeh
          out.write('ی');
        case 0x0643: // Arabic kaf → farsi keheh
          out.write('ک');
        case 0x0629: // teh marbuta → heh
          out.write('ه');
        case 0x0623 || 0x0625 || 0x0622: // alef variants → bare alef
          out.write('ا');
        case 0x0640: // tatweel: purely decorative
          break;
        case 0x200C: // ZWNJ carries meaning in Persian; keep it
          out.write('\u200c');
        case 0x00E4 || 0x00C4: // ä
          out.write('a');
        case 0x00F6 || 0x00D6: // ö
          out.write('o');
        case 0x00FC || 0x00DC: // ü
          out.write('u');
        case 0x00DF: // ß
          out.write('ss');
        case 0x00E9 || 0x00E8 || 0x00EA: // é è ê
          out.write('e');
        case 0x00E7: // ç
          out.write('c');
        default:
          // Persian and Arabic-Indic digits become ASCII so a keyword written
          // with either keyboard matches.
          if (rune >= 0x06F0 && rune <= 0x06F9) {
            out.write(rune - 0x06F0);
          } else if (rune >= 0x0660 && rune <= 0x0669) {
            out.write(rune - 0x0660);
          } else {
            out.writeCharCode(rune);
          }
      }
    }
    return out.toString();
  }

  /// Splits on anything that is not a letter, a digit or a ZWNJ.
  static List<String> tokenise(String input) => input
      .split(RegExp(r'[^\p{L}\p{N}\u200c]+', unicode: true))
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);

  /// Word-level occurrence counts, stop words excluded, most frequent first.
  Map<String, int> topWords(Set<String> stopWords, {int limit = 10, int minCount = 3}) {
    final Map<String, int> counts = <String, int>{};
    for (final String word in significantWords) {
      if (stopWords.contains(word)) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> sorted = counts.entries
        .where((MapEntry<String, int> e) => e.value >= minCount)
        .toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    return <String, int>{
      for (final MapEntry<String, int> e in sorted.take(limit)) e.key: e.value,
    };
  }

  /// Whether the document looks like an academic CV, which changes what the
  /// analyser expects (publications matter, a one-page limit does not).
  bool looksAcademic() =>
      headings.contains(SectionKey.publications) ||
      headings.contains(SectionKey.researchExperience) ||
      headings.contains(SectionKey.grants) ||
      headings.contains(SectionKey.teachingExperience);
}
