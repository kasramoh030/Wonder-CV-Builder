import '../entities/analysis_report.dart';
import '../entities/job_description.dart';
import '../enums/industry.dart';
import 'analyzer_vocabulary.dart';
import 'cv_text_index.dart';

/// Reads a pasted job advert and compares it with a CV.
///
/// The hard rule this class exists to enforce: **a keyword the user does not
/// have is reported as missing, never as something to add.** The output
/// separates "the advert mentions this and your CV does too" from "the advert
/// mentions this and your CV does not", and the UI shows the second list with
/// an explicit instruction not to claim skills that are not real. Nothing in
/// this file ever proposes text for the user to paste into their CV.
///
/// Extraction is entirely rule-based and offline. The same advert therefore
/// always yields the same keywords, which matters when a user compares two
/// CV versions against the same post.
class JobDescriptionAnalyzer {
  JobDescriptionAnalyzer({AnalyzerVocabulary? vocabulary})
      : _vocabulary = vocabulary ?? AnalyzerVocabulary.standard;

  final AnalyzerVocabulary _vocabulary;

  /// Terminology that is noise in almost every advert, in the three languages
  /// the app is built for.
  static const Set<String> advertStopWords = <String>{
    'about', 'above', 'across', 'after', 'again', 'against', 'all', 'also',
    'always', 'among', 'another', 'any', 'are', 'around', 'based', 'because',
    'become', 'been', 'before', 'being', 'below', 'best', 'better', 'between',
    'both', 'bring', 'build', 'came', 'can', 'career', 'come', 'company',
    'could', 'day', 'days', 'deep', 'does', 'doing', 'done', 'down', 'during',
    'each', 'either', 'else', 'enable', 'end', 'ensure', 'even', 'ever',
    'every', 'excellent', 'help', 'here', 'high', 'highly', 'hire', 'hiring',
    'how', 'ideal', 'including', 'into', 'join', 'just', 'keep', 'know',
    'like', 'look', 'looking', 'make', 'many', 'may', 'might', 'more', 'most',
    'much', 'must', 'need', 'needs', 'new', 'next', 'nice', 'offer', 'often',
    'only', 'other', 'our', 'ours', 'out', 'over', 'part', 'per', 'plus',
    'preferred', 'provide', 'providing', 'required', 'role', 'same', 'should',
    'since', 'some', 'still', 'such', 'support', 'than', 'their', 'them',
    'then', 'there', 'these', 'they', 'thing', 'things', 'those', 'through',
    'time', 'under', 'understand', 'upon', 'using', 'very', 'want', 'well',
    'what', 'when', 'where', 'whether', 'while', 'who', 'why', 'will',
    'within', 'without', 'work', 'working', 'would', 'year', 'years', 'your',
    'yours', 'you', 'opportunity', 'apply', 'candidate', 'candidates',
    'position', 'job', 'great', 'good', 'strong', 'ability', 'able',
    'responsibilities', 'requirements', 'qualifications', 'skills',
    'knowledge', 'understanding', 'environment', 'culture', 'benefits',
    'salary', 'equal', 'please', 'team', 'teams', 'people', 'person',
    'successful', 'relevant', 'related', 'degree', 'field',
    'aufgaben', 'anforderungen', 'wir', 'sie', 'und', 'oder', 'mit', 'für',
    'das', 'der', 'die', 'den', 'dem', 'eine', 'einen', 'als', 'bei', 'aus',
    'werden', 'wird', 'sind', 'ist', 'haben', 'hat', 'kann', 'können', 'uns',
    'unser', 'unserer', 'stelle', 'stellen', 'bereich', 'kenntnisse',
    'erfahrung', 'profil', 'ihre', 'ihrer', 'auch', 'sowie',
    'زمینه', 'شرکت', 'موقعیت', 'شغل', 'نیاز', 'دارد', 'حداقل', 'حداکثر',
    'آگهی', 'استخدام', 'باشد', 'توانایی', 'آشنا', 'مسلط', 'داشتن', 'کار',
    'برای', 'این', 'های', 'مورد', 'تمام', 'سایر', 'همکاری', 'تیم',
  };

  /// Phrases that introduce an advert's role, so the extractor can find the
  /// title without understanding German or Persian grammar.
  static const List<String> _titleMarkers = <String>[
    'job title', 'job title:', 'position:', 'position -', 'role:',
    'vacancy:', 'we are hiring', 'stellenbezeichnung', 'stelle:',
    'aufgabengebiet', 'عنوان شغلی', 'موقعیت شغلی', 'عنوان:', 'پوزیشن:',
  ];

  /// Phrases that introduce a requirement list.
  static const List<String> _requirementMarkers = <String>[
    'requirements', 'required', 'must have', 'you have', 'qualifications',
    'experience with', 'proficient', 'knowledge of', 'what you bring',
    'anforderungen', 'voraussetzungen', 'sie bringen mit', 'erfahrung mit',
    'wir erwarten', 'نیازمندی‌ها', 'شرایط', 'مهارت‌های مورد نیاز',
    'آشنایی با', 'تسلط بر',
  ];

  /// Phrases that mark a skill as a nice-to-have rather than a must.
  static const List<String> _preferredMarkers = <String>[
    'nice to have', 'a plus', 'bonus', 'desirable', 'advantageous',
    'wünschenswert', 'von vorteil', 'pluspunkt', 'امتیاز', 'مزیت',
    'ترجیحا', 'اولویت',
  ];

  JobDescription parse({
    required String rawText,
    String? knownTitle,
    String? resumeId,
    String id = '',
  }) {
    final String normalised = CvTextIndex.normalise(rawText);
    final List<String> lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList(growable: false);

    final String title = (knownTitle != null && knownTitle.trim().isNotEmpty)
        ? knownTitle.trim()
        : _guessTitle(lines, normalised);

    final List<String> keywords = _keywords(normalised);
    final Set<String> technologyTerms = <String>{
      for (final Set<String> domain in _vocabulary.roleKeywords.values) ...domain,
    };

    final List<String> technologies = <String>[];
    final List<String> required = <String>[];
    final List<String> preferred = <String>[];
    for (final String keyword in keywords) {
      if (technologyTerms.contains(keyword) || _looksLikeTechnology(keyword)) {
        technologies.add(keyword);
      } else if (_isPreferred(normalised, keyword)) {
        preferred.add(keyword);
      } else {
        required.add(keyword);
      }
    }

    final SeniorityLevel? seniority = _guessSeniority(normalised);
    final int? years = _guessYears(normalised);

    return JobDescription(
      id: id,
      resumeId: resumeId,
      jobTitle: title,
      company: _guessCompany(lines),
      rawText: rawText,
      createdAt: DateTime.now(),
      requirements: JobRequirements(
        requiredSkills: required,
        preferredSkills: preferred,
        technologies: technologies,
        atsKeywordPool: keywords,
        detectedSeniority: seniority?.id,
        detectedIndustries: _guessIndustries(normalised),
        yearsRequired: years,
        educationLevel: _guessEducationLevel(normalised),
        languages: _guessLanguages(normalised),
        qualifications: _requirementLines(lines),
      ),
    );
  }

  /// Compares a parsed advert with the CV text.
  JobMatchReport match({
    required JobDescription advert,
    required CvTextIndex cv,
    String resumeId = '',
  }) {
    final JobRequirements requirements = advert.requirements;
    final List<String> pool = requirements.atsKeywordPool;

    final List<String> found = <String>[];
    final List<String> missing = <String>[];
    for (final String keyword in pool) {
      if (cv.contains(keyword)) {
        found.add(keyword);
      } else {
        missing.add(keyword);
      }
    }

    // CV terms the advert never mentions: evidence the CV is not tailored,
    // which is useful feedback but never framed as a defect.
    final String advertText = CvTextIndex.fold(advert.rawText);
    final List<String> unverified = <String>[];
    for (final String word in cv
        .topWords(_vocabulary.stopWords, limit: 20, minCount: 2)
        .keys) {
      if (word.length < 4) continue;
      if (!advertText.contains(word)) unverified.add(word);
    }

    final double ratio =
        pool.isEmpty ? 0 : found.length / pool.length;

    // Skill gaps are the advert's technology keywords the CV never mentions.
    // They are reported as gaps to think about — never as lines to add.
    final List<String> gapSkills = <String>[
      for (final String t in requirements.technologies)
        if (!cv.contains(t)) display(t),
    ]..sort();

    final int skillsScore = _percentage(found, requirements.requiredSkills);
    final int keywordScore = (ratio * 100).round().clamp(0, 100);
    final int experienceScore = _experienceScore(advert, cv);
    final int educationScore = _educationScore(advert, cv);
    final int seniorityScore = _seniorityScore(advert, cv);
    final int domainScore = _domainScore(advert, cv);

    // Keyword overlap dominates, because it is the only dimension measured
    // directly rather than inferred from the advert's wording.
    final int overall = ((keywordScore * 0.45) +
            (skillsScore * 0.2) +
            (experienceScore * 0.15) +
            (educationScore * 0.1) +
            (seniorityScore * 0.1))
        .round()
        .clamp(0, 100);

    return JobMatchReport(
      resumeId: resumeId,
      jobDescriptionId: advert.id,
      overall: overall,
      skills: skillsScore,
      experience: experienceScore,
      education: educationScore,
      keywords: keywordScore,
      seniority: seniorityScore,
      domain: domainScore,
      keywordDetail: KeywordAnalysis(
        found: found,
        missing: missing,
        unverified: unverified,
        matchRatio: ratio,
      ),
      explanation: <String, String>{
        'keywords': 'Your CV mentions ${found.length} of ${pool.length} '
            'terms that stand out in this advert '
            '($keywordScore% overlap).',
        'skills': requirements.requiredSkills.isEmpty
            ? 'The advert does not list explicit required skills.'
            : '${found.where(requirements.requiredSkills.contains).length} of '
                '${requirements.requiredSkills.length} required skills appear '
                'in your CV.',
        'experience': _experienceExplanation(advert, cv),
        'education': educationScore >= 90
            ? 'Your education section matches what the advert asks for.'
            : 'The advert mentions an education requirement your CV does not '
                'clearly state.',
        'seniority': advert.requirements.detectedSeniority == null
            ? 'The advert does not state a seniority level.'
            : 'The advert reads as '
                '${advert.requirements.detectedSeniority} level.',
        'domain': domainScore >= 80
            ? 'Your experience reads as being in the same field as the advert.'
            : 'The advert\'s field is not obvious from your CV wording.',
        'honesty': 'Missing keywords are shown so you can judge whether you '
            'genuinely have that skill. Only add something if you have real '
            'experience with it.',
      },
      gapSkills: gapSkills,
      createdAt: DateTime.now(),
    );
  }

  // ── extraction helpers ───────────────────────────────────────────────────

  String _guessTitle(List<String> lines, String normalised) {
    for (final String marker in _titleMarkers) {
      final int at = normalised.indexOf(marker);
      if (at < 0) continue;
      final String tail = normalised.substring(at + marker.length);
      final String candidate = tail
          .split(RegExp(r'[\n•\-–—|,;:()\[\]]'))
          .map((String s) => s.trim())
          .firstWhere(
            (String s) => s.length >= 3 && s.length <= 60,
            orElse: () => '',
          );
      if (candidate.isNotEmpty) return display(candidate);
    }
    // Otherwise the first short line is usually the role: adverts title
    // themselves before they explain themselves.
    for (final String line in lines.take(6)) {
      final int words = line.split(RegExp(r'\s+')).length;
      if (words >= 2 && words <= 9 && line.length <= 70) return line;
    }
    return lines.isEmpty ? '' : lines.first;
  }

  String _guessCompany(List<String> lines) {
    for (final String line in lines.take(12)) {
      final String lower = line.toLowerCase();
      if (lower.startsWith('company') || lower.startsWith('unternehmen')) {
        final int colon = line.indexOf(':');
        if (colon > 0) return line.substring(colon + 1).trim();
      }
      if (RegExp(r'\b(GmbH|AG|Ltd|LLC|Inc|PLC|B\.V\.|S\.A\.)\b').hasMatch(line)) {
        return line.trim();
      }
    }
    return '';
  }

  List<String> _requirementLines(List<String> lines) {
    final List<String> out = <String>[];
    bool inside = false;
    for (final String line in lines) {
      final String lower = line.toLowerCase();
      if (_requirementMarkers.any(lower.startsWith)) {
        inside = true;
        continue;
      }
      if (inside) {
        if (line.length > 160) break;
        out.add(line);
        if (out.length >= 12) break;
      }
    }
    return out;
  }

  /// Candidate keywords: significant words and two-word phrases.
  List<String> _keywords(String normalised) {
    final List<String> tokens = CvTextIndex.tokenise(normalised);
    final Set<String> stop = <String>{
      ..._vocabulary.stopWords,
      ...advertStopWords,
    };

    final Map<String, int> counts = <String, int>{};
    for (final String token in tokens) {
      if (token.length < 3 || stop.contains(token)) continue;
      if (int.tryParse(token) != null) continue;
      counts[token] = (counts[token] ?? 0) + 1;
    }
    for (int i = 0; i < tokens.length - 1; i++) {
      final String a = tokens[i];
      final String b = tokens[i + 1];
      if (a.length < 3 || b.length < 3) continue;
      if (stop.contains(a) || stop.contains(b)) continue;
      final String phrase = '$a $b';
      counts[phrase] = (counts[phrase] ?? 0) + 1;
    }

    final bool inRequirementBlock =
        _requirementMarkers.any(normalised.contains);

    // Longer phrases first, so "machine learning" wins over "learning", then
    // anything already covered by a chosen phrase is dropped.
    final List<String> ranked = counts.keys.toList()
      ..sort((String a, String b) {
        final int byLength = b.length.compareTo(a.length);
        if (byLength != 0) return byLength;
        return (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      });

    final List<String> chosen = <String>[];
    for (final String candidate in ranked) {
      final int count = counts[candidate] ?? 0;
      final bool singleWord = !candidate.contains(' ');
      if (singleWord && count < 2 && !inRequirementBlock) continue;
      if (singleWord && candidate.length < 4) continue;
      if (singleWord && chosen.any((String c) => c.contains(candidate))) {
        continue;
      }
      chosen.add(candidate);
      if (chosen.length >= 30) break;
    }
    return chosen;
  }

  bool _isPreferred(String text, String keyword) {
    final int at = text.indexOf(keyword);
    if (at < 0) return false;
    final int start = at - 90 < 0 ? 0 : at - 90;
    final String around = text.substring(start, at);
    return _preferredMarkers.any(around.contains);
  }

  bool _looksLikeTechnology(String keyword) => RegExp(
        r'(\.js|\.net|\.py|sql|api|sdk|cloud|framework|library|docker|'
        r'kubernetes|flutter|dart|kotlin|swift|react|angular|vue|node|python|'
        r'java|golang|rust|terraform|jenkins|gitlab|graphql|rest|aws|azure|'
        r'gcp|linux|figma|photoshop|excel|sap|tableau|power bi|tensorflow|'
        r'pytorch|scrum|agile|kanban|jira|confluence)',
      ).hasMatch(keyword);

  SeniorityLevel? _guessSeniority(String text) {
    if (RegExp(r'\b(chief|cto|ceo|vp|head of|director|leitung)\b').hasMatch(text)) {
      return SeniorityLevel.executive;
    }
    if (RegExp(r'\b(lead|principal|staff|manager|teamlead)\b').hasMatch(text)) {
      return SeniorityLevel.manager;
    }
    if (RegExp(r'\b(senior|sr\.?|erfahren|ارشد)\b').hasMatch(text)) {
      return SeniorityLevel.senior;
    }
    if (RegExp(r'\b(junior|jr\.?|graduate|entry.level|trainee|praktikum|intern)')
        .hasMatch(text)) {
      return SeniorityLevel.junior;
    }
    if (RegExp(r'\b(mid.level|midlevel|intermediate)\b').hasMatch(text)) {
      return SeniorityLevel.mid;
    }
    return null;
  }

  int? _guessYears(String text) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})\s*(?:\+|-|–|\bto\b)?\s*(?:years?|jahre|سال)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String _guessEducationLevel(String text) {
    final List<String> levels = <String>[];
    if (RegExp(r'\b(ph\.?d|doctorate|promotion|دکترا)\b').hasMatch(text)) {
      levels.add('doctorate');
    }
    if (RegExp(r'\b(master|m\.?s\.?c|mba|diplom|magister|ارشد)\b').hasMatch(text)) {
      levels.add('master');
    }
    if (RegExp(r'\b(bachelor|b\.?s\.?c|undergraduate|کارشناسی)\b').hasMatch(text)) {
      levels.add('bachelor');
    }
    return levels.join(', ');
  }

  List<String> _guessLanguages(String text) {
    final List<String> out = <String>[];
    const Map<String, List<String>> candidates = <String, List<String>>{
      'en': <String>['english', 'englisch', 'انگلیسی'],
      'de': <String>['german', 'deutsch', 'آلمانی'],
      'fa': <String>['persian', 'farsi', 'فارسی'],
      'fr': <String>['french', 'französisch', 'فرانسوی'],
      'ar': <String>['arabic', 'arabisch', 'عربی'],
    };
    for (final MapEntry<String, List<String>> entry in candidates.entries) {
      if (entry.value.any(text.contains)) out.add(entry.key);
    }
    return out;
  }

  List<String> _guessIndustries(String text) {
    final List<String> out = <String>[];
    for (final MapEntry<String, Set<String>> domain
        in _vocabulary.roleKeywords.entries) {
      int hits = 0;
      for (final String word in domain.value) {
        if (text.contains(word)) hits++;
      }
      if (hits >= 3) out.add(domain.key);
    }
    return out;
  }

  // ── scoring helpers ──────────────────────────────────────────────────────

  int _percentage(List<String> found, List<String> pool) {
    if (pool.isEmpty) return 0;
    final int hits = pool.where(found.contains).length;
    return ((hits / pool.length) * 100).round().clamp(0, 100);
  }

  int _experienceScore(JobDescription advert, CvTextIndex cv) {
    final int? required = advert.requirements.yearsRequired;
    final int? earliest = _earliestYear(cv);
    if (required == null || earliest == null) return 60;
    final int available = DateTime.now().year - earliest;
    if (available >= required) return 100;
    if (available + 1 >= required) return 80;
    return (available / required * 70).round().clamp(10, 70);
  }

  String _experienceExplanation(JobDescription advert, CvTextIndex cv) {
    final int? required = advert.requirements.yearsRequired;
    if (required == null) {
      return 'The advert does not state a number of years.';
    }
    final int? earliest = _earliestYear(cv);
    if (earliest == null) {
      return 'The advert asks for $required years; your CV has no dated '
          'entries to compare against.';
    }
    final int available = DateTime.now().year - earliest;
    return 'The advert asks for $required years. Your earliest dated entry is '
        '$earliest ($available years of visible history). '
        'This is an estimate from what is printed, not a judgement.';
  }

  int? _earliestYear(CvTextIndex cv) {
    final Iterable<RegExpMatch> matches =
        RegExp(r'\b(19|20)\d{2}\b').allMatches(cv.normalisedText);
    if (matches.isEmpty) return null;
    return matches
        .map((RegExpMatch m) => int.tryParse(m.group(0) ?? '') ?? 9999)
        .reduce((int a, int b) => a < b ? a : b);
  }

  int _educationScore(JobDescription advert, CvTextIndex cv) {
    if (advert.requirements.educationLevel.isEmpty) return 80;
    final bool hasDegree = RegExp(
      r'\b(bachelor|master|b\.?sc|m\.?sc|ph\.?d|mba|diplom|کارشناسی|ارشد|دکترا)',
      caseSensitive: false,
    ).hasMatch(cv.normalisedText);
    return hasDegree ? 100 : 45;
  }

  int _seniorityScore(JobDescription advert, CvTextIndex cv) {
    final SeniorityLevel? required =
        SeniorityLevel.fromIdOrNull(advert.requirements.detectedSeniority);
    if (required == null) return 70;
    final bool seniorWords = RegExp(
      r'\b(senior|lead|head|principal|manager|director|سرپرست|مدیر|ارشد)\b',
    ).hasMatch(cv.normalisedText);
    return switch (required) {
      SeniorityLevel.executive ||
      SeniorityLevel.manager =>
        seniorWords ? 90 : 55,
      SeniorityLevel.senior => seniorWords ? 95 : 70,
      SeniorityLevel.mid || SeniorityLevel.academic => seniorWords ? 85 : 90,
      _ => seniorWords ? 75 : 95,
    };
  }

  int _domainScore(JobDescription advert, CvTextIndex cv) {
    final String? domain = _vocabulary.bestDomainFor(cv.foldedText);
    if (domain == null) return 60;
    if (advert.requirements.detectedIndustries.isEmpty) return 75;
    return advert.requirements.detectedIndustries.contains(domain) ? 90 : 65;
  }

  /// Title-cases a keyword for display without destroying technology casing.
  static String display(String keyword) {
    const Map<String, String> proper = <String, String>{
      'javascript': 'JavaScript', 'typescript': 'TypeScript', 'github': 'GitHub',
      'gitlab': 'GitLab', 'mysql': 'MySQL', 'postgresql': 'PostgreSQL',
      'nosql': 'NoSQL', 'sql': 'SQL', 'api': 'API', 'apis': 'APIs', 'aws': 'AWS',
      'gcp': 'GCP', 'css': 'CSS', 'html': 'HTML', 'php': 'PHP',
      'kotlin': 'Kotlin', 'flutter': 'Flutter', 'dart': 'Dart',
      'python': 'Python', 'tensorflow': 'TensorFlow', 'pytorch': 'PyTorch',
      'ci/cd': 'CI/CD', 'jira': 'Jira', 'figma': 'Figma', 'docker': 'Docker',
      'kubernetes': 'Kubernetes', 'terraform': 'Terraform', 'linux': 'Linux',
      'excel': 'Excel', 'sap': 'SAP', 'seo': 'SEO', 'sem': 'SEM', 'crm': 'CRM',
      'kpi': 'KPI', 'okr': 'OKR', 'ux': 'UX', 'ui': 'UI',
    };
    return proper[keyword] ?? keyword;
  }
}
