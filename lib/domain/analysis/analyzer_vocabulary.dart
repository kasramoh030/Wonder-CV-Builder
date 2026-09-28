import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Words and phrases the offline analyser reasons about.
///
/// The core list is compiled in rather than read from an asset: it is small,
/// typed, and must never fail to load on a device where the app has to work
/// offline. It can still be *extended* from `assets/data/analyzer/`, which is
/// how a future release (or a power user) adds vocabulary without touching
/// the analyser — see [AnalyzerVocabulary.load].
class AnalyzerVocabulary {
  const AnalyzerVocabulary({
    required this.actionVerbs,
    required this.weakPhrases,
    required this.stopWords,
    required this.firstPersonPronouns,
    required this.cliches,
    required this.quantifierPatterns,
    required this.roleKeywords,
  });

  /// Verbs that make a bullet scan as an achievement rather than a duty.
  /// Persian entries are written the way they appear in Iranian CVs: the
  /// verbal noun ("طراحی", "مدیریت") rather than the conjugated form.
  final Set<String> actionVerbs;

  /// Openers that signal a job description instead of a result.
  final List<String> weakPhrases;

  /// Ignored when counting keyword repetition.
  final Set<String> stopWords;

  /// "I led…" wastes a word in English and reads oddly in German.
  final Set<String> firstPersonPronouns;

  /// Empty praise that recruiters skip past.
  final Set<String> cliches;

  /// Regular-expression *sources* that indicate a measurable outcome.
  ///
  /// Stored as strings because `RegExp` cannot be `const`, and the whole
  /// vocabulary is a compile-time constant so it can never fail to load.
  /// [quantifierRegexps] does the compilation once per analyser instance.
  final List<String> quantifierPatterns;

  /// The compiled form of [quantifierPatterns].
  List<RegExp> get quantifierRegexps => quantifierPatterns
      .map((String source) => RegExp(source, caseSensitive: false))
      .toList(growable: false);

  /// Skill vocabulary per domain, used by the job-advert analyser to
  /// recognise technologies and by the CV analyser to spot keyword stuffing.
  final Map<String, Set<String>> roleKeywords;

  static const AnalyzerVocabulary standard = AnalyzerVocabulary(
    actionVerbs: <String>{
      // English
      'achieved', 'accelerated', 'administered', 'analysed', 'analyzed',
      'architected', 'automated', 'balanced', 'built', 'centralised',
      'centralized', 'championed', 'coached', 'consolidated', 'contributed',
      'converted', 'coordinated', 'created', 'cut', 'delivered', 'deployed',
      'designed', 'developed', 'diagnosed', 'directed', 'documented', 'drove',
      'earned', 'eliminated', 'engineered', 'established', 'evaluated',
      'exceeded', 'executed', 'expanded', 'facilitated', 'forecasted',
      'founded', 'generated', 'grew', 'guided', 'implemented', 'improved',
      'increased', 'influenced', 'initiated', 'inspected', 'installed',
      'integrated', 'introduced', 'launched', 'led', 'managed', 'mentored',
      'migrated', 'modelled', 'modeled', 'modernised', 'modernized',
      'monitored', 'negotiated', 'onboarded', 'optimised', 'optimized',
      'orchestrated', 'organised', 'organized', 'overhauled', 'owned',
      'partnered', 'performed', 'pioneered', 'planned', 'prioritised',
      'prioritized', 'produced', 'programmed', 'promoted', 'proposed',
      'prototyped', 'published', 'rebuilt', 'reduced', 'refactored',
      'reorganised', 'reorganized', 'researched', 'resolved', 'restructured',
      'revamped', 'reviewed', 'scaled', 'secured', 'shipped', 'simplified',
      'spearheaded', 'standardised', 'standardized', 'steered', 'streamlined',
      'strengthened', 'supervised', 'supported', 'surpassed', 'taught',
      'trained', 'transformed', 'translated', 'troubleshot', 'unified',
      'validated', 'won',
      // German
      'aufgebaut', 'ausgebaut', 'ausgewertet', 'bearbeitet', 'begleitet',
      'beraten', 'beschleunigt', 'betreut', 'durchgeführt', 'eingeführt',
      'entwickelt', 'erstellt', 'erweitert', 'geführt', 'geleitet',
      'gestaltet', 'gesteigert', 'implementiert', 'initiiert', 'koordiniert',
      'konzipiert', 'optimiert', 'organisiert', 'plante', 'reduziert',
      'senkte', 'standardisiert', 'trainiert', 'umgesetzt', 'verbessert',
      'verantwortete', 'vereinfacht', 'verwaltete', 'vorangetrieben',
      // Persian
      'طراحی', 'مدیریت', 'اجرا', 'توسعه', 'رهبری', 'هماهنگی', 'تحلیل',
      'بهینه‌سازی', 'راه‌اندازی', 'پیاده‌سازی', 'برنامه‌ریزی', 'آموزش',
      'نظارت', 'ایجاد', 'ارتقا', 'کاهش', 'افزایش', 'بازطراحی', 'تدوین',
      'مذاکره', 'پژوهش', 'بررسی', 'اصلاح', 'سازماندهی', 'مستندسازی',
      'خودکارسازی', 'یکپارچه‌سازی', 'ارزیابی', 'گزارش‌گیری', 'هدایت',
    },
    weakPhrases: <String>[
      'responsible for',
      'duties included',
      'tasked with',
      'worked on',
      'helped with',
      'in charge of',
      'assisted in',
      'participated in',
      'involved in',
      'verantwortlich für',
      'war zuständig für',
      'aufgaben umfassten',
      'mitgeholfen bei',
      'beteiligt an',
      'مسئول انجام',
      'وظایف شامل',
      'کمک به',
      'همکاری در',
      'مشارکت در عهده‌دار',
    ],
    stopWords: <String>{
      'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from', 'has',
      'have', 'he', 'her', 'in', 'is', 'it', 'its', 'of', 'on', 'or', 'that',
      'the', 'their', 'they', 'this', 'to', 'was', 'were', 'which', 'will',
      'with', 'you', 'your',
      'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen',
      'einem', 'eines', 'und', 'oder', 'aber', 'mit', 'von', 'zu', 'zum',
      'zur', 'in', 'im', 'auf', 'für', 'als', 'bei', 'aus', 'nach', 'über',
      'ist', 'sind', 'war', 'waren', 'wird', 'werden', 'ich',
      'و', 'در', 'به', 'از', 'که', 'را', 'این', 'آن', 'با', 'برای', 'بر',
      'است', 'هست', 'بود', 'شد', 'شده', 'می', 'یک', 'تا', 'یا', 'اما',
    },
    firstPersonPronouns: <String>{
      'i', 'me', 'my', 'mine', 'myself',
      'ich', 'mich', 'mir', 'mein', 'meine', 'meinen', 'meiner',
      'من', 'مرا', 'مال',
    },
    cliches: <String>{
      'team player', 'hard worker', 'hard-working', 'go-getter', 'self-starter',
      'think outside the box', 'detail-oriented', 'results-driven',
      'dynamic professional', 'excellent communication skills',
      'teamfähig', 'belastbar', 'flexibel', 'motiviert', 'zuverlässig',
      'سخت‌کوش', 'پویا', 'خلاق و نوآور',
    },
    quantifierPatterns: <String>[
      '[0-9]',
      r'\b\d+(\.\d+)?\s?%',
      r'\b\d+(\.\d+)?\s?(k|m|bn|billion|million|thousand)\b',
      r'[€$£¥]\s?\d',
      r'\b\d+\s?(users|customers|clients|employees|people|engineers|students|projects|countries|markets|products|teams)\b',
      r'\b(دو|سه|چهار|پنج|ده|صد|هزار|میلیون|میلیارد)\b',
      r'\b\d+\s?(کاربر|مشتری|نفر|پروژه|درصد|میلیون|هزار)\b',
    ],
    roleKeywords: <String, Set<String>>{
      'software': <String>{
        'dart', 'flutter', 'kotlin', 'java', 'swift', 'python', 'javascript',
        'typescript', 'react', 'node', 'go', 'rust', 'c#', 'c++', 'sql',
        'nosql', 'postgres', 'mysql', 'mongodb', 'redis', 'docker',
        'kubernetes', 'aws', 'azure', 'gcp', 'git', 'ci/cd', 'terraform',
        'graphql', 'rest', 'api', 'microservices', 'linux', 'agile', 'scrum',
        'testing', 'unit tests', 'tdd', 'performance', 'security',
      },
      'data': <String>{
        'python', 'r', 'sql', 'pandas', 'numpy', 'scikit-learn', 'tensorflow',
        'pytorch', 'spark', 'airflow', 'dbt', 'tableau', 'power bi', 'looker',
        'etl', 'data warehouse', 'machine learning', 'statistics', 'a/b test',
      },
      'product': <String>{
        'roadmap', 'backlog', 'user research', 'stakeholder', 'kpi', 'okr',
        'a/b test', 'agile', 'scrum', 'jira', 'figma', 'analytics',
        'go-to-market', 'pricing', 'discovery',
      },
      'design': <String>{
        'figma', 'sketch', 'adobe xd', 'illustrator', 'photoshop', 'prototype',
        'design system', 'accessibility', 'wcag', 'user testing', 'wireframe',
        'typography', 'motion',
      },
      'marketing': <String>{
        'seo', 'sem', 'google ads', 'meta ads', 'content marketing',
        'email marketing', 'crm', 'hubspot', 'salesforce', 'analytics',
        'conversion', 'copywriting', 'social media',
      },
      'finance': <String>{
        'excel', 'ifrs', 'gaap', 'budgeting', 'forecasting', 'sap', 'oracle',
        'audit', 'tax', 'reconciliation', 'cash flow', 'variance analysis',
      },
      'healthcare': <String>{
        'patient care', 'ehr', 'emr', 'hipaa', 'clinical', 'triage',
        'medication', 'infection control', 'bls', 'acls',
      },
      'academic': <String>{
        'publications', 'peer-reviewed', 'citation', 'grant', 'conference',
        'lecturing', 'supervision', 'methodology', 'ethnography', 'regression',
        'qualitative', 'quantitative', 'ethics approval',
      },
      'education': <String>{
        'curriculum', 'lesson planning', 'assessment', 'classroom management',
        'differentiated instruction', 'iep', 'student outcomes',
      },
      'engineering': <String>{
        'cad', 'solidworks', 'autocad', 'matlab', 'lean', 'six sigma',
        'iso 9001', 'quality control', 'maintenance', 'plc', 'scada',
      },
    },
  );

  /// Merges the compiled vocabulary with an optional bundle extension.
  ///
  /// If `assets/data/analyzer/vocabulary.json` is present its keys are *added*
  /// to the compiled sets, so shipping new terminology never requires editing
  /// the analyser. A malformed extension is ignored rather than fatal: the
  /// offline analyser must always have something to work with.
  static Future<AnalyzerVocabulary> load({AssetBundle? bundle}) async {
    final AssetBundle source = bundle ?? rootBundle;
    try {
      final String raw =
          await source.loadString('assets/data/analyzer/vocabulary.json');
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return standard;
      return standard.mergedWith(decoded);
    } on Object {
      return standard;
    }
  }

  /// Pure equivalent of [load], so the merge logic is unit-testable without
  /// an asset bundle.
  AnalyzerVocabulary mergedWith(Map<String, dynamic> json) {
    Set<String> union(Set<String> base, Object? extra) => <String>{
          ...base,
          ...?(extra is List
              ? extra.whereType<String>().map((String s) => s.toLowerCase().trim())
              : null),
        };

    List<String> unionList(List<String> base, Object? extra) => <String>[
          ...base,
          ...?(extra is List
              ? extra.whereType<String>().map((String s) => s.toLowerCase().trim())
              : null),
        ];

    return AnalyzerVocabulary(
      actionVerbs: union(actionVerbs, json['actionVerbs']),
      weakPhrases: unionList(weakPhrases, json['weakPhrases']),
      stopWords: union(stopWords, json['stopWords']),
      firstPersonPronouns: union(firstPersonPronouns, json['firstPersonPronouns']),
      cliches: union(cliches, json['cliches']),
      quantifierPatterns: quantifierPatterns,
      roleKeywords: _mergeRoleKeywords(json['roleKeywords']),
    );
  }

  Map<String, Set<String>> _mergeRoleKeywords(Object? extra) {
    final Map<String, Set<String>> merged = <String, Set<String>>{
      for (final MapEntry<String, Set<String>> e in roleKeywords.entries)
        e.key: <String>{...e.value},
    };
    if (extra is Map) {
      for (final MapEntry<Object?, Object?> e in extra.entries) {
        final String domain = e.key.toString().toLowerCase();
        final Object? words = e.value;
        if (words is! List) continue;
        merged
            .putIfAbsent(domain, () => <String>{})
            .addAll(words.whereType<String>().map((String s) => s.toLowerCase()));
      }
    }
    return merged;
  }

  /// The domain whose vocabulary best matches [text], or `null` when nothing
  /// stands out. Used to pick a keyword pool for a CV with no job advert.
  String? bestDomainFor(String text) {
    String best = '';
    int bestHits = 0;
    for (final MapEntry<String, Set<String>> entry in roleKeywords.entries) {
      int hits = 0;
      for (final String word in entry.value) {
        if (text.contains(word)) hits++;
      }
      if (hits > bestHits) {
        bestHits = hits;
        best = entry.key;
      }
    }
    return bestHits >= 2 ? best : null;
  }
}
