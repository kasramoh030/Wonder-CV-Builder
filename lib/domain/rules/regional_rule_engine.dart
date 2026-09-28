import '../entities/regional_profile.dart';
import '../entities/resume.dart';
import '../entities/resume_content.dart';
import '../enums/cv_type.dart';
import '../enums/document_options.dart';
import '../enums/region_code.dart';
import '../enums/section_key.dart';
import '../templates/resume_template.dart';

/// The resolved set of presentation decisions for one document.
///
/// This is the single place where *regional rules* meet *the user's own
/// choices*: the profile supplies what a market conventionally expects, the
/// resume supplies what the user actually asked for, and the plan resolves
/// the two. The builder, the preview and the PDF engine all read the plan, so
/// none of them has to know about specific countries.
///
/// Precedence is deliberate and always the same:
///   user's explicit choice > regional convention > neutral default.
/// The app never silently overrides something the user switched on; it
/// explains the convention instead, and that explanation is what
/// [advisories] carries.
class FormatPlan {
  const FormatPlan({
    required this.regionId,
    required this.printedSections,
    required this.addableSections,
    required this.requiredSections,
    required this.discouragedSections,
    required this.showPhoto,
    required this.showSensitiveFields,
    required this.paperSize,
    required this.dateSystem,
    required this.dateSystemOptions,
    required this.dateFormat,
    required this.page,
    required this.ats,
    required this.advisories,
    required this.documentLanguage,
    required this.acceptedDocumentLanguages,
  });

  final String regionId;

  /// Sections that will actually be printed, in order: visible, ordered by
  /// the region's convention, and containing something.
  final List<SectionKey> printedSections;

  /// Sections the user has not switched on that this market would consider
  /// normal — the builder's "suggested" list. Never enabled automatically.
  final List<SectionKey> addableSections;

  final List<SectionKey> requiredSections;
  final List<SectionKey> discouragedSections;

  final bool showPhoto;
  final bool showSensitiveFields;

  final PaperSize paperSize;
  final DateSystem dateSystem;
  final List<DateSystem> dateSystemOptions;
  final String dateFormat;

  final PageGuidance page;
  final AtsPolicy ats;
  final List<RegionalAdvisory> advisories;

  final String documentLanguage;
  final List<String> acceptedDocumentLanguages;

  /// `true` when a convention is worth surfacing but must not block the user.
  bool get hasAdvisories => advisories.isNotEmpty;

  static const FormatPlan neutral = FormatPlan(
    regionId: 'international',
    printedSections: <SectionKey>[],
    addableSections: <SectionKey>[],
    requiredSections: <SectionKey>[],
    discouragedSections: <SectionKey>[],
    showPhoto: false,
    showSensitiveFields: false,
    paperSize: PaperSize.a4,
    dateSystem: DateSystem.gregorian,
    dateSystemOptions: <DateSystem>[DateSystem.gregorian],
    dateFormat: 'MM/YYYY',
    page: PageGuidance(),
    ats: AtsPolicy(),
    advisories: <RegionalAdvisory>[],
    documentLanguage: 'en',
    acceptedDocumentLanguages: <String>['en'],
  );
}

/// Turns a [RegionalProfile] plus a [Resume] into a [FormatPlan].
///
/// Pure and synchronous: the profile is already loaded by the time this runs,
/// so the builder and the PDF engine can both call it during a build without
/// awaiting anything.
abstract final class RegionalRuleEngine {
  static FormatPlan planFor({
    required RegionalProfile profile,
    required Resume resume,
    ResumeTemplate? template,
    DateSystem? dateSystemOverride,
  }) {
    // Order: the region's conventional order wins over the CV type default,
    // because the same CV type is laid out differently in Berlin and Boston.
    final List<SectionKey> base = profile.sections.order.isNotEmpty
        ? _mergeOrder(profile.sections.order, resume, template)
        : resume.effectiveSections;

    final List<SectionKey> ordered = _mergeOrder(base, resume, template);

    final List<SectionKey> printed = ordered
        .where((SectionKey k) => !resume.hiddenSections.contains(k))
        .where((SectionKey k) => k == SectionKey.personal || resume.content.hasContentFor(k))
        .toList(growable: false);

    // Suggested additions: what this market would normally expect that the
    // user has not switched on. Personal details are never suggested.
    final List<SectionKey> suggested = <SectionKey>[
      ...profile.sections.required,
      ...profile.sections.recommended,
    ]
        .where((SectionKey k) => k != SectionKey.personal)
        .where((SectionKey k) => !resume.effectiveSections.contains(k))
        .toSet()
        .toList(growable: false);

    final PersonalInfo personal = resume.content.personal;
    final PhotoExpectation photoPolicy = profile.photo.policy;

    // The user's switch is final. The rules only decide the *default* it
    // starts from, and whether to warn about it.
    final bool showPhoto = personal.showPhoto;
    final bool showSensitive =
        personal.showSensitiveFields && profile.personalInfo.showSensitiveByDefault;

    return FormatPlan(
      regionId: profile.id,
      printedSections: printed,
      addableSections: suggested,
      requiredSections: profile.sections.required,
      discouragedSections: profile.sections.discouraged,
      showPhoto: showPhoto,
      showSensitiveFields: showSensitive,
      paperSize: resume.paperSize,
      // The user's own calendar preference wins over the market's, because a
      // Persian speaker applying in Germany may still want to read their own
      // dates. Presentation only: storage is always ISO Gregorian.
      dateSystem: dateSystemOverride ?? profile.dateSystem,
      dateSystemOptions: profile.dateSystemOptions.isEmpty
          ? const <DateSystem>[DateSystem.gregorian]
          : profile.dateSystemOptions,
      dateFormat: profile.dateFormat,
      page: profile.page,
      ats: profile.ats,
      advisories: _advisoriesFor(
        profile: profile,
        resume: resume,
        template: template,
        photoPolicy: photoPolicy,
      ),
      documentLanguage: profile.documentLanguage,
      acceptedDocumentLanguages: profile.acceptedDocumentLanguages,
    );
  }

  /// The default section set for a new document in a market.
  ///
  /// Used when a CV is created, so a German CV opens with a Lebenslauf-shaped
  /// skeleton and a US resume opens with a one-page one.
  static List<SectionKey> seedOrder({
    required CvType cvType,
    required RegionCode region,
    required RegionalProfile profile,
  }) {
    final List<SectionKey> typeDefault =
        Resume.defaultSectionOrder(cvType, region);
    if (profile.sections.order.isEmpty) return typeDefault;

    final List<SectionKey> merged = <SectionKey>[
      ...profile.sections.order,
      ...typeDefault.where((SectionKey k) => !profile.sections.order.contains(k)),
      ...profile.sections.required.where(
        (SectionKey k) => !profile.sections.order.contains(k) && !typeDefault.contains(k),
      ),
    ];
    return merged.toSet().toList(growable: false);
  }

  /// A document's starting paper size, before the user overrides it.
  static PaperSize defaultPaperSize(RegionalProfile profile) => profile.paperSize;

  /// A document's starting date system, before the user overrides it.
  ///
  /// Iran offers both calendars; the document defaults to the region's own
  /// primary one, and the user can switch per document.
  static DateSystem defaultDateSystem(RegionalProfile profile) =>
      profile.dateSystem;

  // ── internals ────────────────────────────────────────────────────────────

  /// Combines a rule-supplied order with the sections the user actually has
  /// switched on.
  ///
  /// A template with a fixed order (an ATS template, for instance) takes
  /// precedence, because its layout depends on it. Everything else keeps the
  /// rules' order and appends the rest so nothing the user enabled can
  /// silently disappear from the document.
  static List<SectionKey> _mergeOrder(
    List<SectionKey> base,
    Resume resume,
    ResumeTemplate? template,
  ) {
    final List<SectionKey>? forced = template?.forcedSectionOrder;
    if (forced != null && forced.isNotEmpty) {
      return <SectionKey>[
        ...forced,
        ...base.where((SectionKey k) => !forced.contains(k)),
      ];
    }

    final List<SectionKey> userOrder = resume.effectiveSections;
    final List<SectionKey> merged = <SectionKey>[
      ...base,
      ...userOrder.where((SectionKey k) => !base.contains(k)),
    ];
    return merged.where((SectionKey k) => k != SectionKey.personal).toList()
      ..insert(0, SectionKey.personal);
  }

  /// Convention notes worth showing: only where the user's document diverges
  /// from a market norm, so the panel stays quiet when there is nothing to
  /// say.
  static List<RegionalAdvisory> _advisoriesFor({
    required RegionalProfile profile,
    required Resume resume,
    required ResumeTemplate? template,
    required PhotoExpectation photoPolicy,
  }) {
    final List<RegionalAdvisory> out = <RegionalAdvisory>[];

    if (resume.content.personal.showPhoto &&
        photoPolicy != PhotoExpectation.expected) {
      out.add(RegionalAdvisory(
        code: photoPolicy == PhotoExpectation.forbidden
            ? 'regional.photoForbidden'
            : 'regional.photoNotExpected',
        severity: photoPolicy == PhotoExpectation.discouraged ? 'medium' : 'low',
        text: profile.photo.note.isNotEmpty
            ? profile.photo.note
            : 'A photo is not usually included for this market.',
      ));
    }

    if (resume.content.personal.showSensitiveFields &&
        !profile.personalInfo.showSensitiveByDefault) {
      out.add(RegionalAdvisory(
        code: 'regional.personalDetails',
        severity: 'medium',
        text: profile.personalInfo.note.isNotEmpty
            ? profile.personalInfo.note
            : 'Personal details such as date of birth are not usually listed '
                'for this market. They stay off unless you switch them on.',
      ));
    }

    if (template != null &&
        template.atsSafety == AtsSafety.decorative &&
        profile.ats.strictness == AtsStrictness.high) {
      out.add(const RegionalAdvisory(
        code: 'regional.atsStrictMarket',
        severity: 'medium',
        text: 'Employers in this market often screen applications with '
            'software. A simpler layout parses more reliably.',
      ));
    }

    if (resume.paperSize != profile.paperSize) {
      out.add(RegionalAdvisory(
        code: 'regional.paperOverride',
        severity: 'low',
        text: 'This market normally prints on '
            '${profile.paperSize == PaperSize.a4 ? 'A4' : 'US Letter'}. '
            'Your document uses a different size.',
      ));
    }

    out.addAll(profile.advisories);
    return out;
  }
}
