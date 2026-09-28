import '../enums/cv_type.dart';
import '../enums/document_options.dart';
import '../enums/region_code.dart';
import '../enums/section_key.dart';

/// How a template arranges the page.
///
/// The PDF engine switches on this enum rather than on the template id, so
/// adding a thirteenth template means adding data — not a branch in the
/// renderer.
enum ResumeLayout {
  /// Everything in one flow. The only safe layout for strict ATS parsing.
  singleColumn,

  /// Contact block as a band across the top, body in one column.
  headerBand,

  /// Narrow side column for contact, skills and languages; main column for
  /// the narrative sections.
  sidebarLeft,

  /// Mirrored sidebar, used by templates that read better with the dates on
  /// the outside edge.
  sidebarRight,

  /// Two columns with a full-width header, used by the European layouts.
  headerBandTwoColumn,
}

/// Everything that distinguishes one template from another.
///
/// A template is *data*: the renderer contains no per-template code paths.
/// This is what makes "add a template" a ten-line change, and what lets the
/// analyser reason about a document's ATS safety by reading
/// [atsSafety] instead of guessing from a screenshot.
class ResumeTemplate {
  const ResumeTemplate({
    required this.id,
    required this.nameKey,
    required this.category,
    required this.layout,
    required this.accentHex,
    this.atsSafety = AtsSafety.atsFriendly,
    this.fontFamily = 'Inter',
    this.baseFontSize = 10.5,
    this.lineHeight = 1.35,
    this.sectionGap = 14,
    this.headingUppercase = true,
    this.headingRule = true,
    this.showPhoto = false,
    this.photoShape = PhotoShape.circle,
    this.premium = false,
    this.recommendedRegions = const <RegionCode>[],
    this.recommendedTypes = const <CvType>[],
    this.recommendedPages = (1, 2),
    this.forcedSectionOrder,
    this.supportsSidebar = true,
  });

  final String id;

  /// Localisation key — resolved through `AppLocalizations` so template
  /// names are translated like every other string.
  final String nameKey;
  final TemplateCategory category;
  final ResumeLayout layout;
  final AtsSafety atsSafety;

  /// `#RRGGBB`.
  final String accentHex;

  /// Default body font. Always one of the families bundled with the app, so
  /// a PDF can never reference a font the device does not have.
  final String fontFamily;
  final double baseFontSize;
  final double lineHeight;

  /// Vertical space inserted before each section heading, in points.
  final double sectionGap;

  final bool headingUppercase;
  final bool headingRule;
  final bool showPhoto;
  final PhotoShape photoShape;

  /// Premium templates are the freemium boundary. The flag is data so the
  /// paywall can be enforced in one place (see `Entitlements`).
  final bool premium;

  /// Regions this template was designed for. Used for sorting the gallery,
  /// never to hard-block a choice.
  final List<RegionCode> recommendedRegions;
  final List<CvType> recommendedTypes;

  /// Expected page count, surfaced as guidance.
  final (int, int) recommendedPages;

  /// Overrides the CV type's default order — used by the regional templates
  /// where the conventional section order is the whole point.
  final List<SectionKey>? forcedSectionOrder;

  /// `false` for single-column templates, so the builder hides the layout
  /// toggle.
  final bool supportsSidebar;

  bool get isSingleColumn =>
      layout == ResumeLayout.singleColumn || layout == ResumeLayout.headerBand;

  bool get isAtsSafe => atsSafety == AtsSafety.atsSafe;
}

enum PhotoShape {
  circle,
  rounded,
  square;

  static PhotoShape fromId(String id) => PhotoShape.values.firstWhere(
        (PhotoShape s) => s.name == id,
        orElse: () => PhotoShape.circle,
      );
}

/// The twelve templates the app ships with.
///
/// They are deliberately not twelve variations of one design: each entry
/// earns its place by serving a market or a document type that the others
/// serve badly. The ATS template in particular is the one a user should
/// reach for when a job portal will machine-read the file.
abstract final class ResumeTemplates {
  static const ResumeTemplate professional = ResumeTemplate(
    id: 'professional',
    nameKey: 'tplProfessional',
    category: TemplateCategory.professional,
    layout: ResumeLayout.headerBand,
    accentHex: '#1F3A5F',
    baseFontSize: 10.5,
    recommendedPages: (1, 2),
    recommendedRegions: <RegionCode>[
      RegionCode.international,
      RegionCode.unitedStates,
      RegionCode.unitedKingdom,
    ],
  );

  static const ResumeTemplate modern = ResumeTemplate(
    id: 'modern',
    nameKey: 'tplModern',
    category: TemplateCategory.modern,
    layout: ResumeLayout.sidebarLeft,
    accentHex: '#4F46E5',
    baseFontSize: 10.5,
    recommendedPages: (1, 2),
  );

  static const ResumeTemplate minimal = ResumeTemplate(
    id: 'minimal',
    nameKey: 'tplMinimal',
    category: TemplateCategory.modern,
    layout: ResumeLayout.singleColumn,
    accentHex: '#111827',
    headingUppercase = false,
    headingRule = false,
    baseFontSize: 10.5,
    sectionGap: 16,
    recommendedPages: (1, 1),
    supportsSidebar: false,
  );

  static const ResumeTemplate executive = ResumeTemplate(
    id: 'executive',
    nameKey: 'tplExecutive',
    category: TemplateCategory.professional,
    layout: ResumeLayout.headerBand,
    accentHex: '#7C2D12',
    fontFamily: 'Lato',
    baseFontSize: 10.5,
    premium = true,
    recommendedPages: (2, 3),
    recommendedTypes: <CvType>[CvType.professionalCv, CvType.jobResume],
  );

  /// The only template guaranteed to survive a strict parser: one column,
  /// no graphics, no tables, no header/footer, standard headings and text
  /// that extracts cleanly in reading order.
  static const ResumeTemplate ats = ResumeTemplate(
    id: 'ats',
    nameKey: 'tplAts',
    category: TemplateCategory.professional,
    layout: ResumeLayout.singleColumn,
    accentHex: '#000000',
    atsSafety: AtsSafety.atsSafe,
    fontFamily: 'Noto Sans',
    baseFontSize: 10.5,
    headingUppercase = true,
    headingRule = false,
    sectionGap: 12,
    supportsSidebar: false,
    recommendedPages: (1, 2),
    recommendedTypes: <CvType>[CvType.atsResume, CvType.jobResume],
  );

  static const ResumeTemplate academic = ResumeTemplate(
    id: 'academic',
    nameKey: 'tplAcademic',
    category: TemplateCategory.academic,
    layout: ResumeLayout.singleColumn,
    accentHex: '#334155',
    fontFamily: 'Noto Sans',
    baseFontSize: 10,
    headingUppercase = false,
    lineHeight: 1.4,
    supportsSidebar: false,
    recommendedPages: (3, 12),
    recommendedTypes: <CvType>[
      CvType.academicCv,
      CvType.researchCv,
      CvType.phdCv,
      CvType.scholarshipCv,
    ],
  );

  static const ResumeTemplate european = ResumeTemplate(
    id: 'european',
    nameKey: 'tplEuropean',
    category: TemplateCategory.regional,
    layout: ResumeLayout.headerBandTwoColumn,
    accentHex: '#0E7490',
    baseFontSize: 10.5,
    recommendedRegions: <RegionCode>[RegionCode.europe, RegionCode.international],
    recommendedPages: (2, 3),
  );

  /// Inspired by the Europass structure. Deliberately named
  /// "Europass-style": Europass is one widely used European format among
  /// several, and presenting it as *the* European standard would be wrong.
  static const ResumeTemplate europass = ResumeTemplate(
    id: 'europass',
    nameKey: 'tplEuropass',
    category: TemplateCategory.regional,
    layout: ResumeLayout.headerBandTwoColumn,
    accentHex: '#003399',
    fontFamily: 'Open Sans',
    baseFontSize: 10.5,
    recommendedRegions: <RegionCode>[RegionCode.europe],
    recommendedTypes: <CvType>[CvType.europass],
    recommendedPages: (2, 4),
  );

  /// Lebenslauf conventions: tabular date column, no summary by default,
  /// photo conventional, signature block at the end.
  static const ResumeTemplate german = ResumeTemplate(
    id: 'german',
    nameKey: 'tplGerman',
    category: TemplateCategory.regional,
    layout: ResumeLayout.sidebarRight,
    accentHex: '#1E3A8A',
    fontFamily: 'Lato',
    baseFontSize: 10.5,
    showPhoto: true,
    recommendedRegions: <RegionCode>[RegionCode.germany],
    recommendedPages: (2, 3),
  );

  /// UK convention: no photo, no date of birth, a personal profile at the
  /// top and "References available on request" as a closing line.
  static const ResumeTemplate uk = ResumeTemplate(
    id: 'uk',
    nameKey: 'tplUk',
    category: TemplateCategory.regional,
    layout: ResumeLayout.headerBand,
    accentHex: '#0F766E',
    baseFontSize: 10.5,
    recommendedRegions: <RegionCode>[RegionCode.unitedKingdom],
    recommendedTypes: <CvType>[CvType.jobResume, CvType.professionalCv],
    recommendedPages: (2, 2),
  );

  /// US resume conventions: no photo, no personal details, one page for
  /// early career, two beyond that.
  static const ResumeTemplate usResume = ResumeTemplate(
    id: 'us_resume',
    nameKey: 'tplUsResume',
    category: TemplateCategory.regional,
    layout: ResumeLayout.singleColumn,
    accentHex: '#1D4ED8',
    atsSafety: AtsSafety.atsFriendly,
    baseFontSize: 10.5,
    supportsSidebar: false,
    recommendedRegions: <RegionCode>[RegionCode.unitedStates],
    recommendedTypes: <CvType>[CvType.jobResume, CvType.graduateResume],
    recommendedPages: (1, 2),
  );

  /// The one expressive template in the set, for design, marketing and
  /// creative roles where a sidebar and a stronger accent are an asset.
  static const ResumeTemplate creative = ResumeTemplate(
    id: 'creative',
    nameKey: 'tplCreative',
    category: TemplateCategory.creative,
    layout: ResumeLayout.sidebarLeft,
    accentHex: '#DB2777',
    atsSafety: AtsSafety.decorative,
    fontFamily: 'Lato',
    baseFontSize: 10.5,
    photoShape: PhotoShape.rounded,
    showPhoto: true,
    premium = true,
    recommendedRegions: <RegionCode>[RegionCode.international],
    recommendedTypes: <CvType>[CvType.jobResume],
    recommendedPages: (1, 2),
  );

  static const List<ResumeTemplate> all = <ResumeTemplate>[
    professional,
    modern,
    minimal,
    executive,
    ats,
    academic,
    european,
    europass,
    german,
    uk,
    usResume,
    creative,
  ];

  /// Look-up by id, falling back to the professional template so a CV that
  /// references a template removed in a later version still opens.
  static ResumeTemplate byId(String id) {
    for (final ResumeTemplate template in all) {
      if (template.id == id) return template;
    }
    return professional;
  }

  /// Templates worth offering first for a given market and document type.
  static List<ResumeTemplate> recommended({
    required RegionCode region,
    required CvType cvType,
  }) {
    final List<ResumeTemplate> exact = all
        .where(
          (ResumeTemplate t) =>
              t.recommendedRegions.contains(region) &&
              (t.recommendedTypes.isEmpty || t.recommendedTypes.contains(cvType)),
        )
        .toList(growable: false);
    if (exact.isNotEmpty) return exact;

    final List<ResumeTemplate> regional = all
        .where((ResumeTemplate t) => t.recommendedRegions.contains(region))
        .toList(growable: false);
    if (regional.isNotEmpty) return regional;

    return all
        .where((ResumeTemplate t) => t.recommendedRegions.isEmpty)
        .toList(growable: false);
  }
}
