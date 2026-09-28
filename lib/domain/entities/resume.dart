import 'package:json_annotation/json_annotation.dart';

import '../enums/cv_type.dart';
import '../enums/document_options.dart';
import '../enums/industry.dart';
import '../enums/region_code.dart';
import '../enums/section_key.dart';
import 'resume_content.dart';

part 'resume.g.dart';

/// A CV document: content plus the presentation decisions that apply to it.
///
/// The same row can act as the *Master Profile* — a document whose content
/// is complete and which other CVs are duplicated from. That avoids a
/// parallel data model for something that is, in the end, a CV with extra
/// usage semantics.
@JsonSerializable(explicitToJson: true)
class Resume {
  const Resume({
    required this.id,
    required this.title,
    required this.content,
    this.isMasterProfile = false,
    this.region = RegionCode.international,
    this.cvType = CvType.professionalCv,
    this.industry = Industry.other,
    this.seniority = SeniorityLevel.mid,
    this.languageCode = 'en',
    this.templateId = 'professional',
    this.accentColorHex,
    this.fontFamily,
    this.paperSize = PaperSize.a4,
    this.sectionOrder = const <SectionKey>[],
    this.hiddenSections = const <SectionKey>[],
    this.customSectionTitles = const <String, String>{},
    this.baseFontSize = 10.5,
    this.createdAt,
    this.updatedAt,
    this.lastOpenedAt,
    this.archived = false,
  });

  final String id;
  final String title;

  /// Identifies which profile this document was derived from, purely for
  /// display ("from Master Profile"). Content is always copied, never
  /// referenced, so editing a CV can never corrupt the profile.
  final bool isMasterProfile;

  // ── Targeting ────────────────────────────────────────────────────────────
  final RegionCode region;
  final CvType cvType;
  final Industry industry;
  final SeniorityLevel seniority;

  /// Content language of the document itself — independent from the app's
  /// UI language. A German CV can be written while the app runs in Persian.
  final String languageCode;

  // ── Presentation ─────────────────────────────────────────────────────────
  final String templateId;

  /// `null` means "use the template's own accent".
  final String? accentColorHex;

  /// `null` means "use the template's own font".
  final String? fontFamily;
  final PaperSize paperSize;

  // ── Structure ────────────────────────────────────────────────────────────
  /// Explicit order of the sections that are shown. Sections missing from
  /// this list are hidden, which makes reordering and hiding one operation.
  final List<SectionKey> sectionOrder;
  final List<SectionKey> hiddenSections;

  /// Overrides for [SectionKey.custom] section headings, keyed by section id.
  final Map<String, String> customSectionTitles;

  /// Base text size in points used by the PDF engine before auto-fitting.
  final double baseFontSize;

  // ── Content ──────────────────────────────────────────────────────────────
  final ResumeContent content;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastOpenedAt;

  /// Soft delete. Archived CVs stay recoverable and are excluded from all
  /// listings, including the analyser and the export flow.
  final bool archived;

  factory Resume.fromJson(Map<String, dynamic> json) => _$ResumeFromJson(json);

  Map<String, dynamic> toJson() => _$ResumeToJson(this);

  /// Sections actually rendered, in order, with hidden ones removed.
  List<SectionKey> get effectiveSections {
    final Set<SectionKey> hidden = hiddenSections.toSet();
    final List<SectionKey> ordered = sectionOrder.isEmpty
        ? defaultSectionOrder(cvType, region)
        : sectionOrder;
    return ordered
        .where((SectionKey k) => !hidden.contains(k))
        .toList(growable: false);
  }

  bool isSectionVisible(SectionKey key) =>
      effectiveSections.contains(key) && content.hasContentFor(key);

  /// Sections the user has switched on that currently hold no content —
  /// the builder nudges these towards completion.
  List<SectionKey> get emptyVisibleSections => effectiveSections
      .where((SectionKey k) => k.isCollection && !content.hasContentFor(k))
      .toList(growable: false);

  Resume copyWith({
    String? title,
    bool? isMasterProfile,
    RegionCode? region,
    CvType? cvType,
    Industry? industry,
    SeniorityLevel? seniority,
    String? languageCode,
    String? templateId,
    String? accentColorHex,
    String? fontFamily,
    PaperSize? paperSize,
    List<SectionKey>? sectionOrder,
    List<SectionKey>? hiddenSections,
    Map<String, String>? customSectionTitles,
    double? baseFontSize,
    ResumeContent? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool? archived,
    bool clearAccentColor = false,
    bool clearFontFamily = false,
  }) =>
      Resume(
        id: id,
        title: title ?? this.title,
        isMasterProfile: isMasterProfile ?? this.isMasterProfile,
        region: region ?? this.region,
        cvType: cvType ?? this.cvType,
        industry: industry ?? this.industry,
        seniority: seniority ?? this.seniority,
        languageCode: languageCode ?? this.languageCode,
        templateId: templateId ?? this.templateId,
        accentColorHex: clearAccentColor ? null : (accentColorHex ?? this.accentColorHex),
        fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
        paperSize: paperSize ?? this.paperSize,
        sectionOrder: sectionOrder ?? this.sectionOrder,
        hiddenSections: hiddenSections ?? this.hiddenSections,
        customSectionTitles: customSectionTitles ?? this.customSectionTitles,
        baseFontSize: baseFontSize ?? this.baseFontSize,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        archived: archived ?? this.archived,
      );

  /// Default section order for a document type in a market.
  ///
  /// These are conventions, not laws — the function is the single place
  /// where "what a normal CV looks like" is encoded, and the user can
  /// always reorder afterwards.
  static List<SectionKey> defaultSectionOrder(CvType type, RegionCode region) {
    if (type.isAcademic) {
      return const <SectionKey>[
        SectionKey.personal,
        SectionKey.summary,
        SectionKey.researchInterests,
        SectionKey.education,
        SectionKey.academicAppointments,
        SectionKey.publications,
        SectionKey.researchExperience,
        SectionKey.teachingExperience,
        SectionKey.grants,
        SectionKey.awards,
        SectionKey.conferences,
        SectionKey.presentations,
        SectionKey.projects,
        SectionKey.skills,
        SectionKey.languages,
        SectionKey.certifications,
        SectionKey.academicService,
        SectionKey.memberships,
        SectionKey.volunteering,
        SectionKey.references,
      ];
    }

    if (type == CvType.europass) {
      return const <SectionKey>[
        SectionKey.personal,
        SectionKey.summary,
        SectionKey.experience,
        SectionKey.education,
        SectionKey.languages,
        SectionKey.digitalSkills,
        SectionKey.skills,
        SectionKey.certifications,
        SectionKey.projects,
        SectionKey.volunteering,
        SectionKey.publications,
        SectionKey.references,
      ];
    }

    if (type.isEarlyCareer) {
      return const <SectionKey>[
        SectionKey.personal,
        SectionKey.summary,
        SectionKey.education,
        SectionKey.skills,
        SectionKey.projects,
        SectionKey.experience,
        SectionKey.certifications,
        SectionKey.awards,
        SectionKey.languages,
        SectionKey.volunteering,
        SectionKey.interests,
        SectionKey.references,
      ];
    }

    // Professional / ATS / regional documents.
    return <SectionKey>[
      SectionKey.personal,
      SectionKey.summary,
      SectionKey.experience,
      SectionKey.education,
      SectionKey.skills,
      SectionKey.projects,
      SectionKey.certifications,
      if (region == RegionCode.iran) SectionKey.courses,
      if (region == RegionCode.iran) SectionKey.militaryService,
      SectionKey.languages,
      SectionKey.awards,
      SectionKey.publications,
      SectionKey.volunteering,
      SectionKey.interests,
      if (region == RegionCode.germany) SectionKey.additionalInfo,
      SectionKey.references,
    ];
  }
}
