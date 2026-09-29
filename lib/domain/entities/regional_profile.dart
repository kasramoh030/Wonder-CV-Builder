import 'dart:convert';

import '../enums/document_options.dart';
import '../enums/section_key.dart';
import '../templates/resume_template.dart';

/// How strongly a market expects a photo on a CV.
enum PhotoExpectation {
  /// Recruiters generally expect one (rare, and never a hard requirement).
  expected,

  /// Common but entirely optional — the safe default almost everywhere.
  optional,

  /// Not customary; including one is more likely to hurt than help.
  discouraged,

  /// Actively counter-productive for legal or fairness reasons.
  forbidden;

  static PhotoExpectation fromId(String id) =>
      PhotoExpectation.values.firstWhere(
        (PhotoExpectation e) => e.name == id,
        orElse: () => PhotoExpectation.optional,
      );

  String get id => name;
}

/// How strictly a market's employers parse applications automatically.
enum AtsStrictness {
  low,
  medium,
  high;

  static AtsStrictness fromId(String id) => AtsStrictness.values.firstWhere(
        (AtsStrictness s) => s.name == id,
        orElse: () => AtsStrictness.medium,
      );

  String get id => name;

  /// Weight applied to the ATS dimension when scoring. Markets with heavy
  /// automated screening get a higher weight, because a formatting problem
  /// there is fatal rather than merely untidy.
  double get scoreWeight => switch (this) {
        AtsStrictness.low => 0.15,
        AtsStrictness.medium => 0.2,
        AtsStrictness.high => 0.3,
      };
}

/// Everything a target market says about how a CV should look and read.
///
/// The whole object is parsed from `assets/data/regional_rules/<id>.json`.
/// No rule is compiled into the app: adding Canada or Australia means adding
/// one JSON file, not touching the analyser, the builder or the renderer.
class RegionalProfile {
  const RegionalProfile({
    required this.id,
    this.schemaVersion = 1,
    this.version = 1,
    this.labelKey = '',
    this.summary = '',
    this.paperSize = PaperSize.a4,
    this.documentLanguage = 'en',
    this.acceptedDocumentLanguages = const <String>['en'],
    this.dateSystem = DateSystem.gregorian,
    this.dateSystemOptions = const <DateSystem>[DateSystem.gregorian],
    this.dateFormat = 'MM/YYYY',
    this.photo = const PhotoPolicy(),
    this.personalInfo = const PersonalInfoPolicy(),
    this.sections = const SectionPolicy(),
    this.page = const PageGuidance(),
    this.ats = const AtsPolicy(),
    this.language = const LanguagePolicy(),
    this.advisories = const <RegionalAdvisory>[],
  });

  final String id;
  final int schemaVersion;
  final int version;

  /// Key into `AppLocalizations`, so the region name follows the UI language.
  final String labelKey;
  final String summary;

  final PaperSize paperSize;
  final String documentLanguage;
  final List<String> acceptedDocumentLanguages;
  final DateSystem dateSystem;
  final List<DateSystem> dateSystemOptions;
  final String dateFormat;

  final PhotoPolicy photo;
  final PersonalInfoPolicy personalInfo;
  final SectionPolicy sections;
  final PageGuidance page;
  final AtsPolicy ats;
  final LanguagePolicy language;
  final List<RegionalAdvisory> advisories;

  factory RegionalProfile.fromJson(Map<String, dynamic> json) => RegionalProfile(
        id: json['id'] as String? ?? 'international',
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        version: (json['version'] as num?)?.toInt() ?? 1,
        labelKey: json['labelKey'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        paperSize: PaperSize.fromId(json['paperSize'] as String? ?? 'a4'),
        documentLanguage: json['documentLanguage'] as String? ?? 'en',
        acceptedDocumentLanguages: _stringList(json['acceptedDocumentLanguages']),
        dateSystem: DateSystem.fromId(json['dateSystem'] as String? ?? 'gregorian'),
        dateSystemOptions: _stringList(json['dateSystemOptions'])
            .map(DateSystem.fromId)
            .toList(growable: false),
        dateFormat: json['dateFormat'] as String? ?? 'MM/YYYY',
        photo: PhotoPolicy.fromJson(_map(json['photo'])),
        personalInfo: PersonalInfoPolicy.fromJson(_map(json['personalInfo'])),
        sections: SectionPolicy.fromJson(_map(json['sections'])),
        page: PageGuidance.fromJson(_map(json['page'])),
        ats: AtsPolicy.fromJson(_map(json['ats'])),
        language: LanguagePolicy.fromJson(_map(json['language'])),
        advisories: _list(json['advisories'])
            .map((Object? e) => RegionalAdvisory.fromJson(_map(e)))
            .toList(growable: false),
      );

  /// Parses a rule bundle from raw asset bytes.
  ///
  /// A malformed or partial file degrades to the neutral profile rather than
  /// throwing: regional rules are content, and content should never take the
  /// app down.
  static RegionalProfile parse(String source) {
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return const RegionalProfile(id: 'international');
      return RegionalProfile.fromJson(decoded);
    } on FormatException {
      return const RegionalProfile(id: 'international');
    }
  }

  /// `true` when the region's rules have changed since [other] was loaded,
  /// used to invalidate stored analysis reports.
  bool isNewerThan(RegionalProfile other) =>
      id == other.id && (version > other.version || schemaVersion > other.schemaVersion);

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

  static List<String> _stringList(Object? value) =>
      _list(value).whereType<String>().toList(growable: false);
}

/// Photo expectations for a market.
class PhotoPolicy {
  const PhotoPolicy({
    this.policy = PhotoExpectation.optional,
    this.conventional = false,
    this.shape = PhotoShape.circle,
    this.note = '',
  });

  final PhotoExpectation policy;
  final bool conventional;
  final PhotoShape shape;
  final String note;

  factory PhotoPolicy.fromJson(Map<String, dynamic> json) => PhotoPolicy(
        policy: PhotoExpectation.fromId(json['policy'] as String? ?? 'optional'),
        conventional: json['conventional'] as bool? ?? false,
        shape: PhotoShape.fromId(json['shape'] as String? ?? 'circle'),
        note: json['note'] as String? ?? '',
      );

  bool get shouldDefaultToOff => policy != PhotoExpectation.expected;
}

/// Which personal details a market expects, tolerates, or considers risky.
class PersonalInfoPolicy {
  const PersonalInfoPolicy({
    this.showSensitiveByDefault = false,
    this.conventional = const <String>[],
    this.discouraged = const <String>[],
    this.neverIncludeByDefault = const <String>[],
    this.note = '',
  });

  /// Master switch for the sensitive block. `false` everywhere except where
  /// a market genuinely expects those fields.
  final bool showSensitiveByDefault;

  /// Fields recruiters in this market may still look for.
  final List<String> conventional;

  /// Fields that are legal but considered unnecessary or risky.
  final List<String> discouraged;

  /// Fields the app will not enable on the user's behalf under any
  /// circumstance — the user must switch these on deliberately.
  final List<String> neverIncludeByDefault;

  final String note;

  factory PersonalInfoPolicy.fromJson(Map<String, dynamic> json) => PersonalInfoPolicy(
        showSensitiveByDefault: json['showSensitiveByDefault'] as bool? ?? false,
        conventional: RegionalProfile._stringList(json['conventional']),
        discouraged: RegionalProfile._stringList(json['discouraged']),
        neverIncludeByDefault:
            RegionalProfile._stringList(json['neverIncludeByDefault']),
        note: json['note'] as String? ?? '',
      );
}

/// Section expectations for a market.
class SectionPolicy {
  const SectionPolicy({
    this.order = const <SectionKey>[],
    this.required = const <SectionKey>[],
    this.recommended = const <SectionKey>[],
    this.discouraged = const <SectionKey>[],
  });

  /// Conventional reading order. Falls back to the CV type's default when
  /// empty.
  final List<SectionKey> order;

  /// Missing one of these is a *content* finding, not a fatal one.
  final List<SectionKey> required;
  final List<SectionKey> recommended;

  /// Present, but unusual for this market — worth a gentle note, never an
  /// automatic removal.
  final List<SectionKey> discouraged;

  factory SectionPolicy.fromJson(Map<String, dynamic> json) => SectionPolicy(
        order: _keys(json['order']),
        required: _keys(json['required']),
        recommended: _keys(json['recommended']),
        discouraged: _keys(json['discouraged']),
      );

  static List<SectionKey> _keys(Object? value) => RegionalProfile._stringList(value)
      .map(SectionKey.fromId)
      .toList(growable: false);
}

/// Expected length of a CV in a market.
class PageGuidance {
  const PageGuidance({
    this.min = 1,
    this.max = 3,
    this.idealMax = 2,
    this.note = '',
  });

  final int min;
  final int max;

  /// Beyond this, the analyser raises a length recommendation. It never
  /// suggests cutting content to fit — only that the reviewer may stop
  /// reading.
  final int idealMax;
  final String note;

  factory PageGuidance.fromJson(Map<String, dynamic> json) => PageGuidance(
        min: (json['min'] as num?)?.toInt() ?? 1,
        max: (json['max'] as num?)?.toInt() ?? 3,
        idealMax: (json['idealMax'] as num?)?.toInt() ?? 2,
        note: json['note'] as String? ?? '',
      );
}

/// How much automated parsing a market's employers do.
class AtsPolicy {
  const AtsPolicy({
    this.strictness = AtsStrictness.medium,
    this.photoOnAts = false,
    this.notes = const <String>[],
  });

  final AtsStrictness strictness;

  /// Whether a photo may safely be kept in an ATS-bound document.
  final bool photoOnAts;
  final List<String> notes;

  factory AtsPolicy.fromJson(Map<String, dynamic> json) => AtsPolicy(
        strictness: AtsStrictness.fromId(json['strictness'] as String? ?? 'medium'),
        photoOnAts: json['photoOnAts'] as bool? ?? false,
        notes: RegionalProfile._stringList(json['notes']),
      );
}

/// Tone and tense expectations.
class LanguagePolicy {
  const LanguagePolicy({
    this.expectedTone = 'professional',
    this.verbTensePreference = 'mixed',
    this.notes = const <String>[],
  });

  final String expectedTone;
  final String verbTensePreference;
  final List<String> notes;

  factory LanguagePolicy.fromJson(Map<String, dynamic> json) => LanguagePolicy(
        expectedTone: json['expectedTone'] as String? ?? 'professional',
        verbTensePreference: json['verbTensePreference'] as String? ?? 'mixed',
        notes: RegionalProfile._stringList(json['notes']),
      );
}

/// A market-specific piece of advice shown alongside the analysis.
///
/// Advisories are deliberately advisory: they describe what is customary,
/// never what is mandatory. The app makes no claim that any format is the
/// only legal CV format in a country.
class RegionalAdvisory {
  const RegionalAdvisory({
    required this.code,
    required this.text,
    this.severity = 'info',
  });

  final String code;
  final String text;
  final String severity;

  factory RegionalAdvisory.fromJson(Map<String, dynamic> json) => RegionalAdvisory(
        code: json['code'] as String? ?? 'regional.unknown',
        text: json['text'] as String? ?? '',
        severity: json['severity'] as String? ?? 'info',
      );

  IssuePriority? get priority => switch (severity) {
        'critical' => IssuePriority.critical,
        'high' => IssuePriority.high,
        'medium' => IssuePriority.medium,
        'low' => IssuePriority.low,
        _ => null,
      };
}
