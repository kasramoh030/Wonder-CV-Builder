import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/resume_content.dart';
import '../../domain/entities/year_month.dart';
import '../../domain/enums/proficiency.dart';
import '../../domain/enums/section_key.dart';

/// What a parsed document produced.
///
/// [found] counts what landed in each section, so the review step can say
/// "three roles, twelve skills" instead of showing a wall of fields with no
/// idea what the parser managed to read.
class ImportedResume {
  const ImportedResume({
    required this.content,
    required this.found,
    required this.unrecognisedHeadings,
  });

  final ResumeContent content;
  final Map<SectionKey, int> found;

  /// Headings the parser did not recognise, kept verbatim as custom sections
  /// so nothing the user wrote is silently dropped.
  final List<String> unrecognisedHeadings;

  bool get isEmpty =>
      found.isEmpty && content.personal.firstName.trim().isEmpty;
}

/// Reads a CV out of plain text.
///
/// Everything here is a heuristic and is presented to the user as such: the
/// import flow always shows what was understood and asks for confirmation
/// before a single field reaches the database. Recognising a heading in three
/// languages is guesswork with a good hit rate, not a guarantee, and the
/// review screen is what makes the difference acceptable.
abstract final class ResumeImporter {
  static const Uuid _uuid = Uuid();

  static const Map<String, SectionKey> _headings = <String, SectionKey>{
    // English
    'summary': SectionKey.summary,
    'profilesummary': SectionKey.summary,
    'professionalprofile': SectionKey.summary,
    'profile': SectionKey.summary,
    'objective': SectionKey.summary,
    'about': SectionKey.summary,
    'aboutme': SectionKey.summary,
    'careersummary': SectionKey.summary,
    'experience': SectionKey.experience,
    'workexperience': SectionKey.experience,
    'professionalexperience': SectionKey.experience,
    'employmenthistory': SectionKey.experience,
    'workhistory': SectionKey.experience,
    'employment': SectionKey.experience,
    'education': SectionKey.education,
    'academicbackground': SectionKey.education,
    'educationandtraining': SectionKey.education,
    'skills': SectionKey.skills,
    'technicalskills': SectionKey.skills,
    'skillsandtools': SectionKey.skills,
    'corecompetencies': SectionKey.skills,
    'keyskills': SectionKey.keySkills,
    'digitalskills': SectionKey.digitalSkills,
    'languages': SectionKey.languages,
    'languageskills': SectionKey.languages,
    'projects': SectionKey.projects,
    'personalprojects': SectionKey.projects,
    'selectedprojects': SectionKey.projects,
    'certifications': SectionKey.certifications,
    'certificates': SectionKey.certifications,
    'licences': SectionKey.certifications,
    'licenses': SectionKey.certifications,
    'awards': SectionKey.awards,
    'honours': SectionKey.awards,
    'honors': SectionKey.awards,
    'achievements': SectionKey.achievements,
    'publications': SectionKey.publications,
    'volunteering': SectionKey.volunteering,
    'volunteerexperience': SectionKey.volunteering,
    'references': SectionKey.references,
    'courses': SectionKey.courses,
    'training': SectionKey.courses,
    'interests': SectionKey.interests,
    'hobbies': SectionKey.interests,
    'researchinterests': SectionKey.researchInterests,
    'researchexperience': SectionKey.researchExperience,
    'teachingexperience': SectionKey.teachingExperience,
    'academicappointments': SectionKey.academicAppointments,
    'conferences': SectionKey.conferences,
    'presentations': SectionKey.presentations,
    'grants': SectionKey.grants,
    'academicservice': SectionKey.academicService,
    'memberships': SectionKey.memberships,
    'additionalinformation': SectionKey.additionalInfo,
    'additionalinfo': SectionKey.additionalInfo,
    'otherinformation': SectionKey.additionalInfo,
    'militaryservice': SectionKey.militaryService,
    'drivinglicence': SectionKey.drivingLicence,
    'drivinglicense': SectionKey.drivingLicence,
    // Deutsch
    'profil': SectionKey.summary,
    'kurzprofil': SectionKey.summary,
    'berufsprofil': SectionKey.summary,
    'berufserfahrung': SectionKey.experience,
    'beruflicherwerdegang': SectionKey.experience,
    'praxiserfahrung': SectionKey.experience,
    'berufspraxis': SectionKey.experience,
    'ausbildung': SectionKey.education,
    'studium': SectionKey.education,
    'bildung': SectionKey.education,
    'kenntnisse': SectionKey.skills,
    'fachkenntnisse': SectionKey.skills,
    'fähigkeiten': SectionKey.skills,
    'sprachen': SectionKey.languages,
    'sprachkenntnisse': SectionKey.languages,
    'projekte': SectionKey.projects,
    'zertifikate': SectionKey.certifications,
    'zertifizierungen': SectionKey.certifications,
    'weiterbildungen': SectionKey.courses,
    'kurse': SectionKey.courses,
    'auszeichnungen': SectionKey.awards,
    'preise': SectionKey.awards,
    'publikationen': SectionKey.publications,
    'veröffentlichungen': SectionKey.publications,
    'ehrenamt': SectionKey.volunteering,
    'ehrenamtlichesengagement': SectionKey.volunteering,
    'referenzen': SectionKey.references,
    'interessen': SectionKey.interests,
    'hobbys': SectionKey.interests,
    'forschung': SectionKey.researchExperience,
    'forschungserfahrung': SectionKey.researchExperience,
    'lehre': SectionKey.teachingExperience,
    'lehrerfahrung': SectionKey.teachingExperience,
    'konferenzen': SectionKey.conferences,
    'vorträge': SectionKey.presentations,
    'stipendien': SectionKey.grants,
    'mitgliedschaften': SectionKey.memberships,
    'zusätzlicheinformationen': SectionKey.additionalInfo,
    'weitereinformationen': SectionKey.additionalInfo,
    'sonstiges': SectionKey.additionalInfo,
  };

  /// Parses [text] into a draft document.
  static ImportedResume parse(String text) {
    final List<String> lines = _lines(text);
    final _Contact contact = _Contact.scan(lines);
    final List<_Block> blocks = _split(lines);

    List<Experience> experiences = const <Experience>[];
    List<Education> education = const <Education>[];
    List<Skill> skills = const <Skill>[];
    List<LanguageSkill> languages = const <LanguageSkill>[];
    List<Project> projects = const <Project>[];
    List<Certification> certifications = const <Certification>[];
    List<Award> awards = const <Award>[];
    List<Publication> publications = const <Publication>[];
    List<DatedEntry> volunteering = const <DatedEntry>[];
    List<DatedEntry> courses = const <DatedEntry>[];
    List<DatedEntry> research = const <DatedEntry>[];
    List<DatedEntry> teaching = const <DatedEntry>[];
    List<DatedEntry> conferences = const <DatedEntry>[];
    List<DatedEntry> grants = const <DatedEntry>[];
    List<DatedEntry> memberships = const <DatedEntry>[];
    List<Reference> references = const <Reference>[];
    List<CustomSection> custom = const <CustomSection>[];
    List<String> interests = const <String>[];
    List<String> additional = <String>[];
    String military = '';
    String licence = '';
    String summary = contact.leadingText;

    for (final _Block block in blocks) {
      switch (block.key) {
        case SectionKey.summary:
          summary = '${summary.isEmpty ? '' : '$summary\n'}${block.body}'.trim();
        case SectionKey.experience:
          experiences = block.entries.map(_experience).toList(growable: false);
        case SectionKey.education:
          education = block.entries.map(_education).toList(growable: false);
        case SectionKey.skills:
        case SectionKey.keySkills:
        case SectionKey.digitalSkills:
          skills = <Skill>[...skills, ..._skills(block.body)];
        case SectionKey.languages:
          languages = _languages(block.body);
        case SectionKey.projects:
          projects = block.entries.map(_project).toList(growable: false);
        case SectionKey.certifications:
          certifications =
              block.entries.map(_certification).toList(growable: false);
        case SectionKey.awards:
        case SectionKey.achievements:
          awards = <Award>[...awards, ...block.entries.map(_award)];
        case SectionKey.publications:
          publications =
              block.entries.map(_publication).toList(growable: false);
        case SectionKey.volunteering:
          volunteering = block.entries.map(_dated).toList(growable: false);
        case SectionKey.courses:
          courses = block.entries.map(_dated).toList(growable: false);
        case SectionKey.researchExperience:
          research = block.entries.map(_dated).toList(growable: false);
        case SectionKey.teachingExperience:
          teaching = block.entries.map(_dated).toList(growable: false);
        case SectionKey.conferences:
        case SectionKey.presentations:
          conferences = <DatedEntry>[...conferences, ...block.entries.map(_dated)];
        case SectionKey.grants:
          grants = block.entries.map(_dated).toList(growable: false);
        case SectionKey.memberships:
          memberships = block.entries.map(_dated).toList(growable: false);
        case SectionKey.references:
          references = block.entries.map(_reference).toList(growable: false);
        case SectionKey.interests:
        case SectionKey.researchInterests:
          interests = <String>[...interests, ..._tokens(block.body)];
        case SectionKey.militaryService:
          military = block.body;
        case SectionKey.drivingLicence:
          licence = block.body;
        case SectionKey.additionalInfo:
          additional = <String>[...additional, block.body];
        case SectionKey.custom:
          custom = <CustomSection>[
            ...custom,
            CustomSection(
              id: _uuid.v4(),
              title: block.title,
              bodyText: block.body,
              useEntries: false,
            ),
          ];
        case SectionKey.personal:
          break;
      }
    }

    final PersonalInfo personal = PersonalInfo(
      firstName: contact.firstName,
      lastName: contact.lastName,
      jobTitle: contact.jobTitle,
      email: contact.email,
      phone: contact.phone,
      city: contact.city,
      country: contact.country,
      linkedIn: contact.linkedIn,
      gitHub: contact.gitHub,
      website: contact.website,
      summary: summary,
    );

    final ResumeContent content = ResumeContent(
      personal: personal,
      experiences: experiences,
      education: education,
      skills: skills,
      languages: languages,
      projects: projects,
      certifications: certifications,
      awards: awards,
      publications: publications,
      volunteering: volunteering,
      courses: courses,
      researchExperience: research,
      teachingExperience: teaching,
      conferences: conferences,
      grants: grants,
      memberships: memberships,
      references: references,
      customSections: custom,
      interests: interests,
      additionalInfo: additional.join('\n\n'),
      militaryService: military,
      drivingLicence: licence,
    );

    final Map<SectionKey, int> found = <SectionKey, int>{};
    void count(SectionKey key, int value) {
      if (value > 0) found[key] = value;
    }

    count(SectionKey.experience, experiences.length);
    count(SectionKey.education, education.length);
    count(SectionKey.skills, skills.length);
    count(SectionKey.languages, languages.length);
    count(SectionKey.projects, projects.length);
    count(SectionKey.certifications, certifications.length);
    count(SectionKey.awards, awards.length);
    count(SectionKey.publications, publications.length);
    count(SectionKey.volunteering, volunteering.length);
    count(SectionKey.courses, courses.length);
    count(SectionKey.researchExperience, research.length);
    count(SectionKey.teachingExperience, teaching.length);
    count(SectionKey.conferences, conferences.length);
    count(SectionKey.grants, grants.length);
    count(SectionKey.memberships, memberships.length);
    count(SectionKey.references, references.length);
    count(SectionKey.interests, interests.length);
    if (summary.isNotEmpty) found[SectionKey.summary] = summary.split(' ').length;

    return ImportedResume(
      content: content,
      found: found,
      unrecognisedHeadings: blocks
          .where((_Block b) => b.key == SectionKey.custom)
          .map((_Block b) => b.title)
          .toList(growable: false),
    );
  }

  // ── Structure ────────────────────────────────────────────────────────────

  static List<String> _lines(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((String line) => line.replaceAll(RegExp(r'\s+$'), ''))
      .toList(growable: false);

  /// Splits the document at recognised headings.
  ///
  /// Leading lines before the first heading become a block that feeds the
  /// summary, which is where an unlabelled professional profile usually sits.
  static List<_Block> _split(List<String> lines) {
    final List<_Block> blocks = <_Block>[];
    _Block current = _Block(
      key: SectionKey.personal,
      title: '',
      lines: <String>[],
    );
    int blankRun = 0;

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        blankRun++;
        current.rawLines.add('');
        continue;
      }
      final SectionKey? heading = _headingFor(trimmed);
      if (heading != null) {
        if (_hasBody(current)) blocks.add(current);
        current = _Block(key: heading, title: trimmed, lines: <String>[]);
        blankRun = 0;
        continue;
      }
      current.rawLines.add(trimmed);
      blankRun = 0;
    }
    if (_hasBody(current)) blocks.add(current);
    return blocks;
  }

  static bool _hasBody(_Block block) => block.rawLines
      .any((String line) => line.trim().isNotEmpty && line.trim() != block.title);

  /// A heading is a short line that names one of the sections.
  ///
  /// The length and word limits are what keep a sentence that happens to start
  /// with the word "experience" from being treated as a heading.
  static SectionKey? _headingFor(String line) {
    final String cleaned = _normaliseHeading(line);
    if (cleaned.isEmpty || cleaned.length > 42) return null;
    if (cleaned.split(' ').length > 4) return null;
    final SectionKey? exact = _headings[cleaned.replaceAll(' ', '')];
    if (exact != null) return exact;
    return _headings[cleaned];
  }

  static String _normaliseHeading(String line) => line
      .replaceAll(RegExp(r'[:：\s]+$'), '')
      .replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
      .toLowerCase()
      .replaceAll('\u200c', '')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
      .trim();

  // ── Section bodies ───────────────────────────────────────────────────────

  static List<List<String>> _entryGroups(List<String> rawLines) {
    final List<List<String>> groups = <List<String>>[];
    List<String> current = <String>[];
    for (final String line in rawLines) {
      if (line.trim().isEmpty) {
        if (current.isNotEmpty) groups.add(current);
        current = <String>[];
        continue;
      }
      if (current.isNotEmpty &&
          _dates(line) != null &&
          current.any((String existing) => _dates(existing) != null)) {
        // A second date line means the previous role ended and this one began,
        // even when the author did not leave a blank line between them.
        groups.add(current);
        current = <String>[];
      }
      current.add(line.trim());
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  static Experience _experience(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return Experience(
      id: _uuid.v4(),
      jobTitle: parts.title,
      company: parts.organisation,
      location: parts.location,
      startDate: parts.start,
      endDate: parts.end,
      isCurrent: parts.current,
      responsibilities: parts.details,
      technologies: parts.technologies,
    );
  }

  static Education _education(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    String institution = parts.organisation;
    String degree = parts.title;
    for (final String line in group) {
      if (_institutionWords.any(line.toLowerCase().contains)) {
        institution = line.replaceAll(_datePattern, '').trim();
      }
      if (_degreeWords.any(line.toLowerCase().contains)) {
        degree = line.replaceAll(_datePattern, '').trim();
      }
    }
    return Education(
      id: _uuid.v4(),
      institution: institution,
      degree: degree,
      fieldOfStudy: parts.field,
      location: parts.location,
      startDate: parts.start,
      endDate: parts.end,
      description: parts.details.join('\n'),
    );
  }

  static Project _project(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return Project(
      id: _uuid.v4(),
      name: parts.title,
      description: parts.details.join('\n'),
      technologies: parts.technologies,
      url: parts.url,
      startDate: parts.start,
      endDate: parts.end,
    );
  }

  static Certification _certification(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return Certification(
      id: _uuid.v4(),
      name: parts.title,
      organization: parts.organisation,
      date: parts.start,
    );
  }

  static Award _award(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return Award(
      id: _uuid.v4(),
      title: parts.title,
      issuer: parts.organisation,
      date: parts.start,
      description: parts.details.join('\n'),
    );
  }

  static Publication _publication(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return Publication(
      id: _uuid.v4(),
      title: parts.title,
      authors: parts.organisation,
      venue: parts.field,
      date: parts.start,
      doi: _doi.firstMatch(group.join(' '))?.group(0) ?? '',
      url: parts.url,
    );
  }

  static DatedEntry _dated(List<String> group) {
    final _EntryParts parts = _entryParts(group);
    return DatedEntry(
      id: _uuid.v4(),
      title: parts.title,
      organization: parts.organisation,
      location: parts.location,
      startDate: parts.start,
      endDate: parts.end,
      description: parts.details.join('\n'),
      url: parts.url,
    );
  }

  static Reference _reference(List<String> group) {
    final String body = group.join('\n');
    final String first = group.first;
    final List<String> nameParts = first.split(RegExp(r'[|,–—]')).map((String p) => p.trim()).toList();
    return Reference(
      id: _uuid.v4(),
      name: nameParts.isNotEmpty ? nameParts.first : first,
      position: nameParts.length > 1 ? nameParts[1] : '',
      organization: nameParts.length > 2 ? nameParts[2] : '',
      email: _email.firstMatch(body)?.group(0) ?? '',
      phone: _phone.firstMatch(body)?.group(0)?.trim() ?? '',
    );
  }

  static List<Skill> _skills(String body) => _tokens(body)
      .map((String name) => Skill(id: _uuid.v4(), name: name))
      .toList(growable: false);

  static List<LanguageSkill> _languages(String body) {
    final List<LanguageSkill> out = <LanguageSkill>[];
    for (final String token in _tokens(body)) {
      final String lower = token.toLowerCase();
      final LanguageLevel level = _languageLevel(lower);
      final String name = token
          .replaceAll(RegExp(r'[\(\[]?[A-C][12][\)\]]?'), '')
          .replaceAll(RegExp(r'[-–—:,]\s*$'), '')
          .replaceAll(RegExp(r'\s*[-–—:,]\s*(native|fluent|basic|good|مادری|مبتدی|پیشرفته).*$',
              caseSensitive: false), '')
          .trim();
      if (name.isEmpty) continue;
      out.add(LanguageSkill(id: _uuid.v4(), language: name, level: level));
    }
    return out;
  }

  /// Reads the level out of a language line.
  ///
  /// CEFR levels are the only scale that means the same thing in every market
  /// this app covers, so they are tried first; the wording in between is
  /// matched in all three languages.
  static LanguageLevel _languageLevel(String lower) {
    // `contains` rather than word boundaries: a boundary in a regular
    // expression only knows ASCII word characters, so it would never match
    // next to Persian text. The input is a single line from a CV, where a
    // substring match is exactly what is wanted.
    if (_containsAny(lower, const <String>[
      'c2',
      'native',
      'mother tongue',
      'muttersprache',
      'مادری',
    ])) {
      return LanguageLevel.native;
    }
    if (_containsAny(lower, const <String>[
      'c1',
      'fluent',
      'fließend',
      'fliessend',
      'sicher',
      'مسلط',
    ])) {
      return LanguageLevel.fluent;
    }
    if (_containsAny(lower, const <String>['b2', 'good', 'gut', 'خوب'])) {
      return LanguageLevel.advanced;
    }
    if (_containsAny(lower, const <String>[
      'b1',
      'intermediate',
      'mittel',
      'متوسط',
    ])) {
      return LanguageLevel.intermediate;
    }
    if (_containsAny(lower, const <String>[
      'a1',
      'a2',
      'basic',
      'grundkenntnisse',
      'مقدماتی',
    ])) {
      return LanguageLevel.beginner;
    }
    return LanguageLevel.intermediate;
  }

  static bool _containsAny(String haystack, List<String> needles) =>
      needles.any(haystack.contains);

  static List<String> _tokens(String body) => body
      .split(RegExp(r'[\n;,•·|،]'))
      .map((String token) => token
          .replaceAll(RegExp(r'^[\s\-–—*▪]+'), '')
          .replaceAll(RegExp(r'\s{2,}.*$'), '')
          .trim())
      .where((String token) =>
          token.isNotEmpty && token.length <= 60 && !token.contains('http'))
      .toList(growable: false);

  // ── Entry parts ──────────────────────────────────────────────────────────

  static _EntryParts _entryParts(List<String> group) {
    final List<String> details = <String>[];
    final List<String> technologies = <String>[];
    String title = '';
    String organisation = '';
    String location = '';
    String field = '';
    String url = '';
    YearMonth? start;
    YearMonth? end;
    bool current = false;

    final List<String> rest = <String>[];
    for (final String raw in group) {
      final String line = raw.trim();
      final _DateRange? range = _dates(line);
      if (range != null && start == null) {
        start = range.start;
        end = range.end;
        current = range.current;
        final String remainder =
            line.replaceAll(_datePattern, '').replaceAll(RegExp(r'[|–—,()]\s*$'), '').trim();
        if (remainder.isNotEmpty) rest.add(remainder);
        continue;
      }
      rest.add(line);
    }

    for (final String line in rest) {
      final String lower = line.toLowerCase();
      if (_technologyPrefixes.any(lower.startsWith)) {
        technologies.addAll(_tokens(
          line.substring(line.indexOf(':') + 1),
        ));
        continue;
      }
      if (_bulletPattern.hasMatch(line)) {
        details.add(_cleanBullet(line));
        continue;
      }
      if (_urlPattern.hasMatch(line) && line.split(' ').length <= 3) {
        url = _urlPattern.firstMatch(line)!.group(0)!;
        continue;
      }
      if (title.isEmpty) {
        final _SplitTitle split = _splitTitle(line);
        title = split.title;
        if (split.organisation.isNotEmpty) organisation = split.organisation;
        continue;
      }
      if (organisation.isEmpty) {
        organisation = line;
        continue;
      }
      if (location.isEmpty && _looksLikePlace(line)) {
        location = line;
        continue;
      }
      if (field.isEmpty && _degreeWords.any(lower.contains)) {
        field = line;
        continue;
      }
      details.add(line);
    }

    if (organisation.isEmpty && title.contains(',')) {
      final List<String> parts = title.split(',');
      title = parts.first.trim();
      organisation = parts.sublist(1).join(',').trim();
    }

    return _EntryParts(
      title: title,
      organisation: organisation,
      location: location,
      field: field,
      url: url,
      start: start,
      end: end,
      current: current,
      details: details,
      technologies: technologies,
    );
  }

  static final RegExp _bulletPattern = RegExp(r'^\s*[-–—*•·▪‣o]\s+');

  static const List<String> _technologyPrefixes = <String>[
    'technologies:',
    'technology:',
    'tech:',
    'tech stack:',
    'stack:',
    'tools:',
    'technologien:',
    'umgesetzt mit:',
    'فناوری:',
    'ابزار:',
  ];

  static const RegExp _urlPattern = RegExp(r'https?://[^\s]+|www\.[^\s]+');

  static const RegExp _doi = RegExp(r'10\.\d{4,9}/[^\s]+');

  static const RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

  static const RegExp _phone =
      RegExp(r'(\+?\d[\d\s().\-]{6,}\d)');

  static bool _looksLikePlace(String line) =>
      line.length <= 40 && !line.contains('@') && !_datePattern.hasMatch(line);

  static String _cleanBullet(String line) =>
      line.replaceAll(_bulletPattern, '').trim();

  static _SplitTitle _splitTitle(String line) {
    for (final String separator in const <String>[
      ' – ',
      ' — ',
      ' - ',
      ' | ',
      ' at ',
      ' bei ',
      ' @ ',
    ]) {
      final int index = line.indexOf(separator);
      if (index > 0) {
        return _SplitTitle(
          title: line.substring(0, index).trim(),
          organisation: line.substring(index + separator.length).trim(),
        );
      }
    }
    return _SplitTitle(title: line.trim(), organisation: '');
  }

  static const Set<String> _institutionWords = <String>{
    'university',
    'universität',
    'hochschule',
    'institute',
    'college',
    'school',
    'academy',
    'دانشگاه',
    'مؤسسه',
    'مدرسه',
  };

  static const Set<String> _degreeWords = <String>{
    'bachelor',
    'master',
    'b.sc',
    'm.sc',
    'bsc',
    'msc',
    'ba',
    'ma',
    'phd',
    'diplom',
    'magister',
    'associate',
    'doctor',
    'کارشناسی',
    'کارشناسی ارشد',
    'دکتری',
    'دیپلم',
  };

  // ── Dates ────────────────────────────────────────────────────────────────

  /// A year, a month and year, or a range of either, ending in "present".
  ///
  /// One pattern covers the shapes that actually appear in CVs; the range
  /// separator is handled by splitting the match, so "2020 – heute" and
  /// "Jan 2020 - Mar 2022" both reduce to two [YearMonth] values.
  static final RegExp _datePattern = RegExp(
    r'(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(?:19|20)\d{2}'
    r'\s*[-–—/]\s*'
    r'(?:(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(?:19|20)\d{2}'
    r'|present|current|now|ongoing|heute|seit|تاکنون|اکنون)'
    r'|(?:19|20)\d{2}\s*[-–—/]\s*'
    r'(?:(?:19|20)\d{2}|present|current|now|ongoing|heute|seit|تاکنون|اکنون)'
    r'|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(?:19|20)\d{2}'
    r'|(?:19|20)\d{2}',
    caseSensitive: false,
  );

  static _DateRange? _dates(String line) {
    final RegExpMatch? match = _datePattern.firstMatch(line);
    if (match == null) return null;
    final List<String> parts = match
        .group(0)!
        .split(RegExp(r'\s*[-–—/]\s*'))
        .map((String part) => part.trim())
        .toList(growable: false);
    final YearMonth? start = _month(parts.first);
    if (start == null) return null;
    bool current = false;
    YearMonth? end;
    if (parts.length > 1) {
      final String last = parts.last.toLowerCase();
      if (RegExp(r'present|current|now|ongoing|heute|seit|تاکنون|اکنون')
          .hasMatch(last)) {
        current = true;
      } else {
        end = _month(parts.last);
      }
    }
    return _DateRange(start: start, end: end, current: current);
  }

  static YearMonth? _month(String raw) {
    final String cleaned = raw.trim().toLowerCase();
    final RegExpMatch? year = RegExp(r'(19|20)\d{2}').firstMatch(cleaned);
    if (year == null) return null;
    final int value = int.parse(year.group(0)!);
    final int? month = _months.entries
        .where((MapEntry<String, int> entry) => cleaned.contains(entry.key))
        .map((MapEntry<String, int> entry) => entry.value)
        .firstOrNull;
    return YearMonth(value, month);
  }

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
    'januar': 1,
    'februar': 2,
    'märz': 3,
    'mai': 5,
    'juni': 6,
    'juli': 7,
    'oktober': 10,
    'dezember': 12,
  };
}

/// A section of the source document.
class _Block {
  const _Block({required this.key, required this.title, required this.lines});

  final SectionKey key;
  final String title;
  final List<String> lines;

  List<String> get rawLines => lines;

  String get body => lines
      .where((String line) => line.trim().isNotEmpty)
      .join('\n')
      .trim();

  List<List<String>> get entries => ResumeImporter._entryGroups(lines);
}

class _EntryParts {
  const _EntryParts({
    required this.title,
    required this.organisation,
    required this.location,
    required this.field,
    required this.url,
    required this.start,
    required this.end,
    required this.current,
    required this.details,
    required this.technologies,
  });

  final String title;
  final String organisation;
  final String location;
  final String field;
  final String url;
  final YearMonth? start;
  final YearMonth? end;
  final bool current;
  final List<String> details;
  final List<String> technologies;
}

class _DateRange {
  const _DateRange({required this.start, required this.end, required this.current});

  final YearMonth start;
  final YearMonth? end;
  final bool current;
}

class _SplitTitle {
  const _SplitTitle({required this.title, required this.organisation});

  final String title;
  final String organisation;
}

/// Contact details, which appear in the first few lines of almost every CV.
class _Contact {
  const _Contact({
    required this.firstName,
    required this.lastName,
    required this.jobTitle,
    required this.email,
    required this.phone,
    required this.city,
    required this.country,
    required this.linkedIn,
    required this.gitHub,
    required this.website,
    required this.leadingText,
  });

  final String firstName;
  final String lastName;
  final String jobTitle;
  final String email;
  final String phone;
  final String city;
  final String country;
  final String linkedIn;
  final String gitHub;
  final String website;
  final String leadingText;

  static _Contact scan(List<String> lines) {
    final String head = lines.take(12).join('\n');
    final String email = ResumeImporter._email.firstMatch(head)?.group(0) ?? '';
    final String phone =
        ResumeImporter._phone.firstMatch(head)?.group(0)?.trim() ?? '';
    final String linkedIn = RegExp(r'(?:https?://)?(?:[a-z]{2,3}\.)?linkedin\.com/[^\s,;]+',
            caseSensitive: false)
        .firstMatch(head)
        ?.group(0) ??
        '';
    final String gitHub = RegExp(r'(?:https?://)?(?:www\.)?github\.com/[^\s,;]+',
            caseSensitive: false)
        .firstMatch(head)
        ?.group(0) ??
        '';
    String website = '';
    for (final RegExpMatch match
        in ResumeImporter._urlPattern.allMatches(head)) {
      final String url = match.group(0)!;
      if (url.contains('linkedin') || url.contains('github')) continue;
      website = url;
      break;
    }

    String firstName = '';
    String lastName = '';
    String jobTitle = '';
    String city = '';
    String country = '';
    final List<String> leading = <String>[];

    for (final String raw in lines.take(8)) {
      final String line = raw.trim();
      if (line.isEmpty) continue;
      if (line.contains('@') ||
          line.contains('linkedin') ||
          line.contains('github') ||
          ResumeImporter._urlPattern.hasMatch(line) ||
          ResumeImporter._phone.hasMatch(line) && line.replaceAll(RegExp(r'\D'), '').length > 6) {
        continue;
      }
      if (ResumeImporter._headingFor(line) != null) break;
      if (firstName.isEmpty && _looksLikeName(line)) {
        final List<String> parts = line.split(RegExp(r'\s+'));
        firstName = parts.first;
        lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        continue;
      }
      if (firstName.isNotEmpty && jobTitle.isEmpty && _looksLikeTitle(line)) {
        jobTitle = line;
        continue;
      }
      if (city.isEmpty && _looksLikeCity(line)) {
        final List<String> parts = line.split(',');
        city = parts.first.trim();
        country = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
        continue;
      }
      leading.add(line);
    }

    return _Contact(
      firstName: firstName,
      lastName: lastName,
      jobTitle: jobTitle,
      email: email,
      phone: phone,
      city: city,
      country: country,
      linkedIn: linkedIn,
      gitHub: gitHub,
      website: website,
      leadingText: leading.join('\n').trim(),
    );
  }

  static bool _looksLikeName(String line) {
    if (line.length > 48) return false;
    if (RegExp(r'\d').hasMatch(line)) return false;
    final List<String> words = line.split(RegExp(r'\s+'));
    if (words.length < 2 || words.length > 5) return false;
    if (line.toUpperCase() == line && line.length > 24) return false;
    return RegExp(r"^[\p{L}][\p{L}\s.\-’']+$", unicode: true).hasMatch(line);
  }

  static bool _looksLikeTitle(String line) {
    if (line.length > 60) return false;
    if (line.split(' ').length > 9) return false;
    if (RegExp(r'\d').hasMatch(line)) return false;
    return true;
  }

  static bool _looksLikeCity(String line) {
    if (line.length > 48) return false;
    if (line.contains(RegExp(r'[.]{2,}'))) return false;
    return RegExp(r'^[\p{L}][\p{L}\s.\-]+(,\s*[\p{L}][\p{L}\s.\-]+)?$',
            unicode: true)
        .hasMatch(line);
  }
}
