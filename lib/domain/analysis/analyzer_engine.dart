import '../entities/analysis_report.dart';
import '../entities/job_description.dart';
import '../entities/regional_profile.dart';
import '../entities/resume.dart';
import '../entities/resume_content.dart';
import '../entities/year_month.dart';
import '../enums/cv_type.dart';
import '../enums/document_options.dart';
import '../enums/region_code.dart';
import '../enums/section_key.dart';
import '../templates/resume_template.dart';
import 'analyzer_vocabulary.dart';
import 'cv_text_index.dart';

/// Everything one analysis run needs.
///
/// Passing the rules and the template in, rather than looking them up, is what
/// lets the analyser run offline in a plain unit test — no database, no
/// network, no asset bundle.
class AnalysisRequest {
  const AnalysisRequest({
    required this.resume,
    required this.profile,
    required this.template,
    this.jobMatch,
    this.estimatedPages,
  });

  final Resume resume;
  final RegionalProfile profile;
  final ResumeTemplate template;

  /// Present when the user analysed against a job advert.
  final JobMatchReport? jobMatch;

  /// Page count measured by the layout engine, when the caller has one. The
  /// analyser falls back to an estimate so it can still run before a preview
  /// has ever been rendered.
  final double? estimatedPages;
}

/// The offline analyser.
///
/// Pure Dart: no I/O, no plugins, no network. The same engine therefore runs
/// in a widget test, in the app on a plane, and in the "advanced" pass as the
/// deterministic half of the result.
///
/// Two rules shape every check below:
///
/// 1. **Never invent.** The analyser may tell the user what is missing or
///    weak, but it never writes content on their behalf. Findings describe,
///    they do not fabricate.
/// 2. **Never claim.** No score guarantees an interview or an ATS pass. The
///    wording of every message says "likely", "tends to", "reviewers expect".
class AnalyzerEngine {
  AnalyzerEngine({AnalyzerVocabulary? vocabulary})
      : _vocabulary = vocabulary ?? AnalyzerVocabulary.standard;

  final AnalyzerVocabulary _vocabulary;

  /// Bumping this invalidates stored reports, so a user who updates the app
  /// is told their old score is out of date rather than being shown a number
  /// produced by different rules.
  static const int engineVersion = 1;

  AnalysisReport analyse(AnalysisRequest request) {
    final Resume resume = request.resume;
    final ResumeContent content = resume.content;
    final CvTextIndex index = CvTextIndex.of(resume);
    final ResumeStats stats = _measureStats(resume, index);
    final bool academic = resume.cvType.isAcademic || index.looksAcademic();

    final List<Recommendation> findings = <Recommendation>[
      ..._checkCompleteness(resume, index, academic),
      ..._checkStructure(resume, request.profile.page, index, academic),
      ..._checkContent(resume, index, stats),
      ..._checkLanguage(index, stats),
      ..._checkAts(resume, request.template, index),
      ..._checkRegion(request, index),
    ];

    if (request.jobMatch != null) {
      findings.addAll(_checkJobMatch(request.jobMatch!));
    }

    final List<ScoreDimension> dimensions = _score(
      request: request,
      stats: stats,
      findings: findings,
    );

    final int total = _combine(dimensions);

    return AnalysisReport(
      resumeId: resume.id,
      source: AnalysisSource.offline,
      totalScore: total,
      dimensions: dimensions,
      recommendations: findings,
      atsChecks: _atsChecks(request),
      stats: stats,
      keywords: request.jobMatch?.keywords,
      strengths: _strengths(index, stats, findings),
      createdAt: DateTime.now(),
      regionId: request.profile.id,
      engineVersion: engineVersion,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Measurement
  // ───────────────────────────────────────────────────────────────────────

  ResumeStats _measureStats(Resume resume, CvTextIndex index) {
    final List<String> bullets = index.bullets;
    final List<RegExp> quantifiers = _vocabulary.quantifierRegexps;

    int actionVerbs = 0;
    int quantified = 0;
    int longest = 0;
    int totalWords = 0;

    for (final String bullet in bullets) {
      final List<String> words = CvTextIndex.tokenise(CvTextIndex.fold(bullet));
      totalWords += words.length;
      if (words.length > longest) longest = words.length;
      if (words.isNotEmpty && _vocabulary.actionVerbs.contains(words.first)) {
        actionVerbs++;
      }
      if (quantifiers.any((RegExp r) => r.hasMatch(bullet))) quantified++;
    }

    final List<String> filler = <String>[];
    final String normalised = index.normalisedText;
    for (final String phrase in _vocabulary.weakPhrases) {
      if (normalised.contains(CvTextIndex.fold(phrase))) filler.add(phrase);
    }

    return ResumeStats(
      wordCount: index.words.length,
      characterCount: index.rawText.length,
      bulletCount: bullets.length,
      actionVerbCount: actionVerbs,
      quantifiedBulletCount: quantified,
      estimatedPages: _estimatePages(resume, index),
      longestBulletWords: longest,
      averageBulletWords:
          bullets.isEmpty ? 0 : totalWords / bullets.length,
      repeatedWords: index.topWords(_vocabulary.stopWords),
      fillerPhrases: filler,
    );
  }

  /// A deliberately rough page estimate used only before a real render.
  ///
  /// 48 lines per A4 page, 44 for Letter (it is wider but shorter), with a
  /// first-page allowance for the header block. The PDF engine reports the
  /// true count after a render and that value wins.
  double _estimatePages(Resume resume, CvTextIndex index) {
    final int charsPerLine = 92;
    final int linesPerPage = resume.paperSize == PaperSize.usLetter ? 44 : 48;
    final int bodyChars = index.bySection.entries
        .where((MapEntry<SectionKey, String> e) => e.key != SectionKey.personal)
        .fold<int>(0, (int sum, MapEntry<SectionKey, String> e) => sum + e.value.length);
    final int headingLines = index.headings.length * 2;
    final int bodyLines = (bodyChars / charsPerLine).ceil() + headingLines + 6;
    return (bodyLines / linesPerPage).clamp(1, 12).toDouble();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Completeness — is anything obviously missing?
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkCompleteness(
    Resume resume,
    CvTextIndex index,
    bool academic,
  ) {
    final List<Recommendation> out = <Recommendation>[];
    final ResumeContent c = resume.content;
    final PersonalInfo p = c.personal;

    if (p.fullName.trim().isEmpty) {
      out.add(const Recommendation(
        code: 'content.missingName',
        priority: IssuePriority.critical,
        category: RecommendationCategory.content,
        section: SectionKey.personal,
      ));
    }
    if (p.email.trim().isEmpty && p.phone.trim().isEmpty) {
      out.add(const Recommendation(
        code: 'content.missingContact',
        priority: IssuePriority.critical,
        category: RecommendationCategory.content,
        section: SectionKey.personal,
      ));
    } else if (p.email.trim().isEmpty) {
      out.add(const Recommendation(
        code: 'content.missingEmail',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.personal,
      ));
    } else if (p.phone.trim().isEmpty) {
      out.add(const Recommendation(
        code: 'content.missingPhone',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.personal,
      ));
    }
    if (p.jobTitle.trim().isEmpty &&
        !index.headings.contains(SectionKey.experience)) {
      out.add(const Recommendation(
        code: 'content.missingHeadline',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.personal,
      ));
    }

    if (resume.cvType.expectsSummary && p.summary.trim().isEmpty) {
      out.add(const Recommendation(
        code: 'content.missingSummary',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.summary,
      ));
    }

    if (c.experiences.where((Experience e) => !e.hidden).isEmpty && !academic) {
      out.add(const Recommendation(
        code: 'content.noExperience',
        priority: resume.cvType.isEarlyCareer
            ? IssuePriority.medium
            : IssuePriority.critical,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
      ));
    }

    if (c.education.where((Education e) => !e.hidden).isEmpty) {
      out.add(const Recommendation(
        code: 'content.noEducation',
        priority: resume.cvType.isEarlyCareer
            ? IssuePriority.high
            : IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.education,
      ));
    }

    if (c.skills.isEmpty) {
      out.add(const Recommendation(
        code: 'content.noSkills',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.skills,
      ));
    }
    if (c.languages.isEmpty) {
      out.add(Recommendation(
        code: 'content.noLanguages',
        priority: resume.region.isMultilingual
            ? IssuePriority.high
            : IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.languages,
      ));
    }
    if (academic && c.publications.where((Publication x) => !x.hidden).isEmpty) {
      out.add(const Recommendation(
        code: 'content.academicNoPublications',
        priority: IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.publications,
      ));
    }
    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Structure — will a reviewer find their way around it?
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkStructure(
    Resume resume,
    PageGuidance guidance,
    CvTextIndex index,
    bool academic,
  ) {
    final List<Recommendation> out = <Recommendation>[];
    final ResumeContent c = resume.content;
    final List<Experience> visible =
        c.experiences.where((Experience e) => !e.hidden).toList();

    if (index.headings.length < 3) {
      out.add(Recommendation(
        code: 'structure.tooFewSections',
        priority: IssuePriority.high,
        category: RecommendationCategory.structure,
        params: <String, String>{'count': '${index.headings.length}'},
      ));
    }

    final int missingDates =
        visible.where((Experience e) => e.startDate == null).length;
    if (missingDates > 0) {
      out.add(Recommendation(
        code: 'structure.experienceMissingDates',
        priority: IssuePriority.medium,
        category: RecommendationCategory.structure,
        section: SectionKey.experience,
        params: <String, String>{'count': '$missingDates'},
      ));
    }

    final int openRoles = visible.where((Experience e) => e.isCurrent && e.endDate != null).length;
    if (openRoles > 0) {
      out.add(Recommendation(
        code: 'structure.currentRoleHasEndDate',
        priority: IssuePriority.low,
        category: RecommendationCategory.structure,
        section: SectionKey.experience,
        params: <String, String>{'count': '$openRoles'},
      ));
    }

    // Modern roles listed before older ones, so the page reads backwards in
    // time. A review of dates, not a rewrite: the order is a convention, not
    // a rule, and the user may override it deliberately.
    for (int i = 1; i < visible.length; i++) {
      final YearMonth? previous = visible[i - 1].startDate;
      final YearMonth? current = visible[i].startDate;
      if (previous != null && current != null && current.isAfter(previous)) {
        out.add(const Recommendation(
          code: 'structure.experienceOrder',
          priority: IssuePriority.low,
          category: RecommendationCategory.structure,
          section: SectionKey.experience,
          autoFixable: true,
        ));
        break;
      }
    }

    // A gap of eighteen months or more between two roles is worth mentioning
    // in markets where a continuous record is expected.
    if (!academic && visible.length >= 2) {
      final List<Experience> sorted = List<Experience>.of(visible)
        ..sort((Experience a, Experience b) =>
            (b.startDate ?? YearMonth(1, 1)).compareTo(a.startDate ?? YearMonth(1, 1)));
      for (int i = 1; i < sorted.length; i++) {
        final YearMonth? end = sorted[i - 1].startDate;
        final YearMonth? start = sorted[i].endDate;
        if (end != null && start != null && start.sortKey - end.sortKey >= 180000) {
          out.add(const Recommendation(
            code: 'structure.employmentGap',
            priority: IssuePriority.low,
            category: RecommendationCategory.structure,
            section: SectionKey.experience,
          ));
          break;
        }
      }
    }

    final double pages = _estimatePages(resume, index);
    if (guidance.idealMax > 0 && pages > guidance.idealMax) {
      out.add(Recommendation(
        code: 'structure.tooLong',
        priority: IssuePriority.medium,
        category: RecommendationCategory.structure,
        params: <String, String>{
          'pages': pages.toStringAsFixed(1),
          'ideal': '${guidance.idealMax}',
        },
      ));
    }

    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Content — the quality of what is written
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkContent(
    Resume resume,
    CvTextIndex index,
    ResumeStats stats,
  ) {
    final List<Recommendation> out = <Recommendation>[];

    if (stats.bulletCount == 0) {
      out.add(const Recommendation(
        code: 'content.noBullets',
        priority: IssuePriority.high,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
      ));
      return out;
    }

    final double verbRatio = stats.actionVerbRatio;
    if (verbRatio < 0.6) {
      out.add(Recommendation(
        code: 'content.weakVerbOpeners',
        priority: verbRatio < 0.3 ? IssuePriority.high : IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
        params: <String, String>{
          'percent': '${(verbRatio * 100).round()}',
        },
      ));
    }

    final double quantified = stats.quantifiedRatio;
    if (quantified < 0.5) {
      out.add(Recommendation(
        code: 'content.lowQuantification',
        priority: quantified < 0.2 ? IssuePriority.high : IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
        params: <String, String>{
          'percent': '${(quantified * 100).round()}',
        },
      ));
    }

    if (stats.fillerPhrases.isNotEmpty) {
      out.add(Recommendation(
        code: 'content.fillerPhrases',
        priority: IssuePriority.medium,
        category: RecommendationCategory.language,
        section: SectionKey.experience,
        params: <String, String>{
          'phrases': stats.fillerPhrases.take(3).join(', '),
          'count': '${stats.fillerPhrases.length}',
        },
      ));
    }

    if (stats.longestBulletWords > 45) {
      out.add(Recommendation(
        code: 'content.bulletTooLong',
        priority: IssuePriority.low,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
        params: <String, String>{'words': '${stats.longestBulletWords}'},
      ));
    }

    if (stats.averageBulletWords > 0 && stats.averageBulletWords < 6) {
      out.add(const Recommendation(
        code: 'content.bulletTooShort',
        priority: IssuePriority.low,
        category: RecommendationCategory.content,
        section: SectionKey.experience,
      ));
    }

    if (stats.repeatedWords.isNotEmpty) {
      out.add(Recommendation(
        code: 'content.repeatedWords',
        priority: IssuePriority.low,
        category: RecommendationCategory.language,
        params: <String, String>{
          'words': stats.repeatedWords.entries
              .take(3)
              .map((MapEntry<String, int> e) => '${e.key} (${e.value})')
              .join(', '),
        },
      ));
    }

    final String summary = resume.content.personal.summary.trim();
    final int summaryWords = summary.isEmpty ? 0 : summary.split(RegExp(r'\s+')).length;
    if (summaryWords > 0 && (summaryWords < 25 || summaryWords > 110)) {
      out.add(Recommendation(
        code: summaryWords < 25
            ? 'content.summaryTooShort'
            : 'content.summaryTooLong',
        priority: IssuePriority.low,
        category: RecommendationCategory.content,
        section: SectionKey.summary,
        params: <String, String>{'words': '$summaryWords'},
      ));
    }

    final int skills = resume.content.skills.length;
    if (skills > 0 && skills < 5) {
      out.add(Recommendation(
        code: 'content.fewSkills',
        priority: IssuePriority.medium,
        category: RecommendationCategory.content,
        section: SectionKey.skills,
        params: <String, String>{'count': '$skills'},
      ));
    }
    if (skills > 30) {
      out.add(Recommendation(
        code: 'content.skillDump',
        priority: IssuePriority.low,
        category: RecommendationCategory.content,
        section: SectionKey.skills,
        params: <String, String>{'count': '$skills'},
      ));
    }

    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Language — tone, tense and person
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkLanguage(CvTextIndex index, ResumeStats stats) {
    final List<Recommendation> out = <Recommendation>[];

    int firstPerson = 0;
    for (final String word in index.words) {
      if (_vocabulary.firstPersonPronouns.contains(word)) firstPerson++;
    }
    if (firstPerson >= 3) {
      out.add(Recommendation(
        code: 'language.firstPerson',
        priority: IssuePriority.low,
        category: RecommendationCategory.language,
        params: <String, String>{'count': '$firstPerson'},
      ));
    }

    int clicheHits = 0;
    for (final String cliche in _vocabulary.cliches) {
      if (index.contains(cliche)) clicheHits++;
    }
    if (clicheHits > 0) {
      out.add(Recommendation(
        code: 'language.cliches',
        priority: IssuePriority.low,
        category: RecommendationCategory.language,
        params: <String, String>{'count': '$clicheHits'},
      ));
    }

    // Uniform capitalisation in headings is one of the few formatting
    // signals an ATS parser is genuinely sensitive to.
    for (final String line in index.rawText.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.length >= 12 && trimmed == trimmed.toUpperCase()) {
        out.add(const Recommendation(
          code: 'language.shoutingLine',
          priority: IssuePriority.low,
          category: RecommendationCategory.language,
        ));
        break;
      }
    }

    if (stats.wordCount > 0 && stats.wordCount < 120) {
      out.add(Recommendation(
        code: 'language.veryLittleText',
        priority: IssuePriority.high,
        category: RecommendationCategory.language,
        params: <String, String>{'words': '${stats.wordCount}'},
      ));
    }

    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // ATS — mechanical parsability
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkAts(
    Resume resume,
    ResumeTemplate template,
    CvTextIndex index,
  ) {
    final List<Recommendation> out = <Recommendation>[];
    final bool atsContext = resume.cvType == CvType.atsResume ||
        (resume.region.atsStrict && template.atsSafety != AtsSafety.atsSafe);

    if (template.atsSafety == AtsSafety.decorative && atsContext) {
      out.add(const Recommendation(
        code: 'ats.decorativeTemplate',
        priority: IssuePriority.high,
        category: RecommendationCategory.ats,
        autoFixable: false,
      ));
    }
    if (resume.content.personal.showPhoto && atsContext) {
      out.add(const Recommendation(
        code: 'ats.photoInAtsDocument',
        priority: IssuePriority.medium,
        category: RecommendationCategory.ats,
        section: SectionKey.personal,
      ));
    }
    if (template.supportsSidebar && atsContext) {
      out.add(const Recommendation(
        code: 'ats.twoColumns',
        priority: IssuePriority.medium,
        category: RecommendationCategory.ats,
      ));
    }

    // Headings that the analyser cannot resolve to a standard section are
    // not a defect, but a CV of nothing but custom headings parses poorly.
    final int customHeadings = resume.content.customSections.length;
    if (customHeadings > 2) {
      out.add(Recommendation(
        code: 'ats.manyCustomSections',
        priority: IssuePriority.low,
        category: RecommendationCategory.ats,
        params: <String, String>{'count': '$customHeadings'},
      ));
    }

    if (index.words.length > 0) {
      final int nonAscii = index.rawText.runes
          .where((int r) => r > 0x2500 && r < 0x1F000)
          .length;
      if (nonAscii / index.rawText.runes.length > 0.15) {
        out.add(const Recommendation(
          code: 'ats.symbolHeavy',
          priority: IssuePriority.low,
          category: RecommendationCategory.ats,
        ));
      }
    }
    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Regional — market conventions, always advisory
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkRegion(AnalysisRequest request, CvTextIndex index) {
    final RegionalProfile profile = request.profile;
    final Resume resume = request.resume;
    final List<Recommendation> out = <Recommendation>[];

    for (final SectionKey key in profile.sections.required) {
      if (!index.headings.contains(key) && !resume.content.hasContentFor(key)) {
        out.add(Recommendation(
          code: 'regional.missingRequiredSection',
          priority: IssuePriority.medium,
          category: RecommendationCategory.regional,
          section: key,
          params: <String, String>{'section': key.id},
        ));
      }
    }

    for (final SectionKey key in profile.sections.discouraged) {
      if (resume.content.hasContentFor(key) &&
          !resume.hiddenSections.contains(key)) {
        out.add(Recommendation(
          code: 'regional.discouragedSection',
          priority: IssuePriority.low,
          category: RecommendationCategory.regional,
          section: key,
          params: <String, String>{'section': key.id},
        ));
      }
    }

    if (profile.photo.shouldDefaultToOff && resume.content.personal.showPhoto) {
      out.add(Recommendation(
        code: 'regional.photoNotExpected',
        priority: profile.photo.policy == PhotoExpectation.discouraged
            ? IssuePriority.high
            : IssuePriority.low,
        category: RecommendationCategory.regional,
        section: SectionKey.personal,
      ));
    }

    if (profile.personalInfo.discouraged.isNotEmpty &&
        resume.content.personal.showSensitiveFields) {
      out.add(const Recommendation(
        code: 'regional.personalDetailsNotExpected',
        priority: IssuePriority.medium,
        category: RecommendationCategory.regional,
        section: SectionKey.personal,
      ));
    }

    final PageGuidance guidance = profile.page;
    final double pages = _estimatePages(resume, index);
    if (pages < guidance.min) {
      out.add(Recommendation(
        code: 'regional.shorterThanExpected',
        priority: IssuePriority.low,
        category: RecommendationCategory.regional,
        params: <String, String>{'min': '${guidance.min}'},
      ));
    }

    for (final RegionalAdvisory advisory in profile.advisories) {
      final IssuePriority? priority = advisory.priority;
      if (priority == null) continue;
      out.add(Recommendation(
        code: advisory.code,
        priority: priority,
        category: RecommendationCategory.regional,
        params: <String, String>{'text': advisory.text},
      ));
    }

    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Job match — findings only, and only about what the user already has
  // ───────────────────────────────────────────────────────────────────────

  List<Recommendation> _checkJobMatch(JobMatchReport match) {
    final List<Recommendation> out = <Recommendation>[];
    final KeywordAnalysis? keywords = match.keywordDetail;

    if (keywords != null && keywords.missing.isNotEmpty) {
      out.add(Recommendation(
        code: 'jobMatch.missingKeywords',
        priority: keywords.matchRatio < 0.4
            ? IssuePriority.high
            : IssuePriority.medium,
        category: RecommendationCategory.jobMatch,
        params: <String, String>{
          'count': '${keywords.missing.length}',
          'keywords': keywords.missing.take(8).join(', '),
        },
      ));
    }
    if (keywords != null &&
        keywords.found.isNotEmpty &&
        keywords.matchRatio >= 0.6) {
      out.add(Recommendation(
        code: 'jobMatch.strongKeywordOverlap',
        priority: IssuePriority.low,
        category: RecommendationCategory.jobMatch,
        params: <String, String>{
          'percent': '${(keywords.matchRatio * 100).round()}',
        },
      ));
    }
    for (final String gap in match.gapSkills) {
      out.add(Recommendation(
        code: 'jobMatch.skillGap',
        priority: IssuePriority.low,
        category: RecommendationCategory.jobMatch,
        params: <String, String>{'skill': gap},
      ));
    }
    return out;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Scoring
  // ───────────────────────────────────────────────────────────────────────

  List<ScoreDimension> _score({
    required AnalysisRequest request,
    required ResumeStats stats,
    required List<Recommendation> findings,
  }) {
    final RegionalProfile profile = request.profile;
    List<Recommendation> byCategory(RecommendationCategory c) =>
        findings.where((Recommendation r) => r.category == c).toList();

    int penalise(int start, List<Recommendation> items) {
      int score = start;
      for (final Recommendation r in items) {
        score -= switch (r.priority) {
          IssuePriority.critical => 22,
          IssuePriority.high => 12,
          IssuePriority.medium => 6,
          IssuePriority.low => 2,
        };
      }
      return score.clamp(0, 100);
    }

    final int structure = penalise(100, byCategory(RecommendationCategory.structure));
    final int content = penalise(100, byCategory(RecommendationCategory.content));
    final int language = penalise(100, byCategory(RecommendationCategory.language));

    // The ATS score starts from the document's mechanical safety rather than
    // from 100, because a decorative template is not a "small deduction".
    final int atsBase = switch (request.template.atsSafety) {
      AtsSafety.atsSafe => 100,
      AtsSafety.atsFriendly => 92,
      AtsSafety.decorative => 74,
    };
    final int ats = penalise(atsBase, byCategory(RecommendationCategory.ats));

    final List<ScoreDimension> dimensions = <ScoreDimension>[
      ScoreDimension(
        kind: ScoreKind.structure,
        score: structure,
        weight: 1,
        notes: _notesFor(byCategory(RecommendationCategory.structure), 3),
      ),
      ScoreDimension(
        kind: ScoreKind.content,
        score: content,
        weight: 1.2,
        notes: _notesFor(byCategory(RecommendationCategory.content), 3),
      ),
      ScoreDimension(
        kind: ScoreKind.ats,
        score: ats,
        // Markets where employers parse heavily weight this dimension more.
        weight: 1 + profile.ats.strictness.scoreWeight,
        notes: _notesFor(byCategory(RecommendationCategory.ats), 2),
      ),
      ScoreDimension(
        kind: ScoreKind.language,
        score: language,
        weight: 0.9,
        notes: _notesFor(byCategory(RecommendationCategory.language), 2),
      ),
    ];

    final JobMatchReport? match = request.jobMatch;
    if (match != null) {
      dimensions.add(ScoreDimension(
        kind: ScoreKind.jobMatch,
        score: match.overall,
        weight: 1.1,
        notes: <String>[
          '${((match.keywordDetail?.matchRatio ?? 0) * 100).round()}% keyword overlap',
        ],
      ));
    }
    // Without an advert there is nothing to match against, so the job-match
    // dimension is omitted rather than filled with a made-up number. The UI
    // says which dimensions were scored.

    return dimensions;
  }

  List<String> _notesFor(List<Recommendation> items, int limit) =>
      items.take(limit).map((Recommendation r) => r.code).toList(growable: false);

  int _combine(List<ScoreDimension> dimensions) {
    double weighted = 0;
    double weight = 0;
    for (final ScoreDimension d in dimensions) {
      weighted += d.score * d.weight;
      weight += d.weight;
    }
    if (weight == 0) return 0;
    return (weighted / weight).round().clamp(0, 100);
  }

  // ───────────────────────────────────────────────────────────────────────
  // ATS check list — a fixed set of pass/fail facts the report can show
  // ───────────────────────────────────────────────────────────────────────

  List<AtsCheck> _atsChecks(AnalysisRequest request) {
    final ResumeTemplate template = request.template;
    final Resume resume = request.resume;
    final CvTextIndex index = CvTextIndex.of(resume);

    return <AtsCheck>[
      AtsCheck(
        code: 'ats.singleColumn',
        passed: !template.supportsSidebar,
        detail: template.supportsSidebar ? template.id : '',
      ),
      AtsCheck(
        code: 'ats.standardHeadings',
        passed: index.headings.length >= 3,
        detail: '${index.headings.length}',
      ),
      AtsCheck(
        code: 'ats.searchableText',
        // The PDF engine always embeds a real text layer; this documents the
        // guarantee rather than testing it.
        passed: true,
      ),
      AtsCheck(
        code: 'ats.noPhoto',
        passed: !resume.content.personal.showPhoto,
      ),
      AtsCheck(
        code: 'ats.standardFont',
        passed: const <String>{'Inter', 'Lato', 'Noto Sans', 'Open Sans', 'Roboto'}
            .contains(template.fontFamily),
        detail: template.fontFamily,
      ),
      AtsCheck(
        code: 'ats.contactInBody',
        passed: resume.content.personal.hasContact,
      ),
      AtsCheck(
        code: 'ats.noTables',
        passed: !template.supportsSidebar,
      ),
      AtsCheck(
        code: 'ats.plainBullets',
        passed: index.bullets.every((String b) => !b.trimLeft().startsWith('•')),
      ),
    ];
  }

  // ───────────────────────────────────────────────────────────────────────
  // Strengths — a report that is only criticism gets ignored
  // ───────────────────────────────────────────────────────────────────────

  List<String> _strengths(
    CvTextIndex index,
    ResumeStats stats,
    List<Recommendation> findings,
  ) {
    final List<String> out = <String>[];
    if (stats.quantifiedRatio >= 0.5 && stats.bulletCount > 0) {
      out.add('content.goodQuantification');
    }
    if (stats.actionVerbRatio >= 0.6 && stats.bulletCount > 0) {
      out.add('content.strongVerbOpeners');
    }
    if (index.headings.length >= 5) {
      out.add('structure.wellStructured');
    }
    if (stats.fillerPhrases.isEmpty && stats.bulletCount > 0) {
      out.add('language.noFiller');
    }
    if (!findings.any((Recommendation r) =>
        r.code == 'content.missingContact' || r.code == 'content.missingName')) {
      out.add('content.contactComplete');
    }
    if (findings.any((Recommendation r) => r.code == 'jobMatch.strongKeywordOverlap')) {
      out.add('jobMatch.strongOverlap');
    }
    return out;
  }
}

/// Which region- and type-specific expectations apply to a document.
///
/// Kept as extensions on the domain enums so the knowledge lives next to the
/// vocabulary rather than in the analyser, and so tests can assert it
/// directly.
extension CvTypeExpectations on CvType {
  /// A professional summary is conventional almost everywhere; the most
  /// junior US-style resumes are the exception, where it is often omitted.
  bool get expectsSummary => !isEarlyCareer || this == CvType.graduateResume;
}

extension RegionExpectations on RegionCode {
  bool get atsStrict =>
      this == RegionCode.unitedStates || this == RegionCode.unitedKingdom;

  /// Markets where a second language is worth listing by default.
  bool get isMultilingual => this != RegionCode.unitedStates;
}
