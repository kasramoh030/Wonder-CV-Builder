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
/// **user's explicit choice > regional convention > neutral default.**
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

  /// Sections that will actually be printed: visible, ordered by the region's
  /// convention, and containing something.
  final List<SectionKey> printedSections;

  /// Sections the user has not switched on that this market would consider
  /// normal — the builder's "suggested" list. Never enabled automatically.
  final List<SectionKey> addableSections;

  final List<SectionKey> requiredSections;
  final List<SectionKey> discouragedSections;

  /// What the document will show, after the user's choices are applied.
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

  bool get hasAdvisories => advisories.isNotEmpty;

  /// `true` when the section is printed but the market would rather it were
  /// not — the builder shows a gentle note, never an automatic removal.
  bool isDiscouraged(SectionKey key) => discouragedSections.contains(key);

  bool isRequired(SectionKey key) => requiredSections.contains(key);
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
    final List<SectionKey> ordered = resolveSectionOrder(
      profile: profile,
      resume: resume,
      template: template,
    );

    final List<SectionKey> printed = ordered
        .where((SectionKey k) => !resume.hiddenSections.contains(k))
        .where((SectionKey k) =>
            k == SectionKey.personal || resume.content.hasContentFor(k))
        .toList(growable: false);

    // What the market expects that the user has not switched on. Offered,
    // never enabled: adding a section the user did not ask for is exactly the
    // kind of silent edit the brief forbids.
    final List<SectionKey> suggested = <SectionKey>[
      ...profile.sections.required,
      ...profile.sections.recommended,
    ]
        .where((SectionKey k) => k != SectionKey.personal)
        .where((SectionKey k) => !resume.effectiveSections.contains(k))
        .toSet()
        .toList(growable: false);

    return FormatPlan(
      regionId: profile.id,
      printedSections: printed,
      addableSections: suggested,
      requiredSections: profile.sections.required,
      discouragedSections: profile.sections.discouraged,
      showPhoto: resume.content.personal.showPhoto,
      showSensitiveFields: resume.content.personal.showSensitiveFields &&
          profile.personalInfo.showSensitiveByDefault,
      paperSize: resume.paperSize,
      // The user's own calendar preference wins over the market's: a Persian
      // speaker applying in Germany may still want to read their own dates.
      // Presentation only — storage is always ISO Gregorian.
      dateSystem: dateSystemOverride ?? profile.dateSystem,
      dateSystemOptions: profile.dateSystemOptions.isEmpty
          ? const <DateSystem>[DateSystem.gregorian]
          : profile.dateSystemOptions,
      dateFormat: profile.dateFormat,
      page: profile.page,
      ats: profile.ats,
      advisories: advisoriesFor(
        profile: profile,
        resume: resume,
        template: template,
      ),
      documentLanguage: profile.documentLanguage,
      acceptedDocumentLanguages: profile.acceptedDocumentLanguages,
    );
  }

  /// The order sections should be printed in.
  ///
  /// A template with a fixed order wins, because its layout depends on it;
  /// otherwise the market's conventional order leads and anything the user
  /// switched on that the market did not mention is appended, so nothing they
  /// enabled can silently vanish from the document.
  static List<SectionKey> resolveSectionOrder({
    required RegionalProfile profile,
    required Resume resume,
    ResumeTemplate? template,
  }) {
    final List<SectionKey> userOrder = resume.effectiveSections;
    final List<SectionKey>? forced = template?.forcedSectionOrder;
    final List<SectionKey> base;
    if (forced != null && forced.isNotEmpty) {
      base = <SectionKey>[
        ...forced,
        ...userOrder.where((SectionKey k) => !forced.contains(k)),
      ];
    } else if (profile.sections.order.isNotEmpty) {
      base = <SectionKey>[
        ...profile.sections.order,
        ...userOrder.where((SectionKey k) => !profile.sections.order.contains(k)),
      ];
    } else {
      base = userOrder;
    }

    final List<SectionKey> result =
        base.where((SectionKey k) => k != SectionKey.personal).toList();
    result.insert(0, SectionKey.personal);
    return result.toSet().toList(growable: false);
  }

  /// The default section set for a new document in a market.
  ///
  /// Used when a CV is created, so a German CV opens with a Lebenslauf-shaped
  /// skeleton and a US resume opens with a one-page one, without the user
  /// having to rearrange anything.
  static List<SectionKey> seedOrder({
    required CvType cvType,
    required RegionCode region,
    required RegionalProfile profile,
  }) {
    final List<SectionKey> typeDefault =
        Resume.defaultSectionOrder(cvType, region);
    if (profile.sections.order.isEmpty) return typeDefault;

    return <SectionKey>[
      ...profile.sections.order,
      ...typeDefault.where((SectionKey k) => !profile.sections.order.contains(k)),
      ...profile.sections.required.where(
        (SectionKey k) =>
            !profile.sections.order.contains(k) && !typeDefault.contains(k),
      ),
    ].toSet().toList(growable: false);
  }

  /// Convention notes worth showing: only where the document diverges from a
  /// market norm, so the panel stays quiet when there is nothing to say.
  static List<RegionalAdvisory> advisoriesFor({
    required RegionalProfile profile,
    required Resume resume,
    ResumeTemplate? template,
  }) {
    final List<RegionalAdvisory> out = <RegionalAdvisory>[];
    final PersonalInfo personal = resume.content.personal;

    if (personal.showPhoto &&
        profile.photo.policy != PhotoExpectation.expected) {
      out.add(RegionalAdvisory(
        code: profile.photo.policy == PhotoExpectation.forbidden
            ? 'regional.photoForbidden'
            : 'regional.photoNotExpected',
        severity:
            profile.photo.policy == PhotoExpectation.discouraged ? 'medium' : 'low',
        text: profile.photo.note.isNotEmpty
            ? profile.photo.note
            : 'A photo is not usually included for this market.',
      ));
    }

    if (personal.showSensitiveFields &&
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
            'software, so a simpler layout parses more reliably.',
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
