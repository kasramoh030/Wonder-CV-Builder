import '../../domain/entities/resume_content.dart';
import '../../domain/enums/section_key.dart';
import '../../l10n/app_localizations.dart';

/// The shape of editor a section needs.
///
/// Twenty-nine sections do not need twenty-nine screens: they fall into five
/// shapes, and every one of them is edited by the same widget with a different
/// record description. A new section in the vocabulary therefore costs a
/// mapping line, not a screen.
enum SectionFormKind {
  /// The candidate's own details, with the photo switch and — when the
  /// market allows them — the sensitive fields.
  personal,

  /// One long text field: a summary, additional information, a service record.
  narrative,

  /// A list of records with dates, often with bullet points.
  entries,

  /// A plain list of short strings, shown as chips.
  strings,

  /// User-named sections, holding either prose or records.
  custom,
}

/// Title of a section in the interface language.
String sectionTitle(SectionKey key, AppLocalizations l10n) => switch (key) {
      SectionKey.personal => l10n.sectionPersonal,
      SectionKey.summary => l10n.sectionSummary,
      SectionKey.experience => l10n.sectionExperience,
      SectionKey.education => l10n.sectionEducation,
      SectionKey.skills => l10n.sectionSkills,
      SectionKey.languages => l10n.sectionLanguages,
      SectionKey.projects => l10n.sectionProjects,
      SectionKey.certifications => l10n.sectionCertifications,
      SectionKey.awards => l10n.sectionAwards,
      SectionKey.publications => l10n.sectionPublications,
      SectionKey.volunteering => l10n.sectionVolunteering,
      SectionKey.references => l10n.sectionReferences,
      SectionKey.courses => l10n.sectionCourses,
      SectionKey.interests => l10n.sectionInterests,
      SectionKey.militaryService => l10n.sectionMilitaryService,
      SectionKey.drivingLicence => l10n.sectionDrivingLicence,
      SectionKey.researchInterests => l10n.sectionResearchInterests,
      SectionKey.researchExperience => l10n.sectionResearchExperience,
      SectionKey.teachingExperience => l10n.sectionTeachingExperience,
      SectionKey.academicAppointments => l10n.sectionAcademicAppointments,
      SectionKey.conferences => l10n.sectionConferences,
      SectionKey.presentations => l10n.sectionPresentations,
      SectionKey.grants => l10n.sectionGrants,
      SectionKey.academicService => l10n.sectionAcademicService,
      SectionKey.memberships => l10n.sectionMemberships,
      SectionKey.digitalSkills => l10n.sectionDigitalSkills,
      SectionKey.achievements => l10n.sectionAchievements,
      SectionKey.keySkills => l10n.sectionKeySkills,
      SectionKey.additionalInfo => l10n.sectionAdditionalInfo,
      SectionKey.custom => l10n.sectionCustom,
    };

SectionFormKind formKindFor(SectionKey key) => switch (key) {
      SectionKey.personal => SectionFormKind.personal,
      SectionKey.summary ||
      SectionKey.additionalInfo ||
      SectionKey.militaryService ||
      SectionKey.drivingLicence =>
        SectionFormKind.narrative,
      SectionKey.interests ||
      SectionKey.researchInterests ||
      SectionKey.digitalSkills ||
      SectionKey.keySkills =>
        SectionFormKind.strings,
      SectionKey.custom => SectionFormKind.custom,
      _ => SectionFormKind.entries,
    };

/// Hint shown above an empty editor.
String sectionHint(SectionKey key, AppLocalizations l10n) =>
    switch (formKindFor(key)) {
      SectionFormKind.personal => l10n.fieldFullName,
      SectionFormKind.narrative => l10n.builderEmptySectionHint,
      SectionFormKind.entries => l10n.builderEmptySectionHint,
      SectionFormKind.strings => l10n.builderEmptySectionHint,
      SectionFormKind.custom => l10n.fieldCustomSectionTitle,
    };

/// Reads the single body of a narrative section.
String narrativeOf(ResumeContent content, SectionKey key) => switch (key) {
      SectionKey.summary => content.personal.summary,
      SectionKey.additionalInfo => content.additionalInfo,
      SectionKey.militaryService => content.militaryService,
      SectionKey.drivingLicence => content.drivingLicence,
      _ => '',
    };

/// Replaces the body of a narrative section.
///
/// Kept next to [narrativeOf] so the write side can never drift from the read
/// side: both switch over the same four keys, and a key that gains a body has
/// to appear in both.
ResumeContent withNarrative(
  ResumeContent content,
  SectionKey key,
  String value,
) =>
    switch (key) {
      SectionKey.summary => content.copyWith(
          personal: content.personal.copyWith(summary: value),
        ),
      SectionKey.additionalInfo => content.copyWith(additionalInfo: value),
      SectionKey.militaryService => content.copyWith(militaryService: value),
      SectionKey.drivingLicence => content.copyWith(drivingLicence: value),
      _ => content,
    };

/// The short-string list backing a chip section, or `null` when the section is
/// not a chip section.
List<String>? stringListOf(ResumeContent content, SectionKey key) =>
    switch (key) {
      SectionKey.interests => content.interests,
      SectionKey.researchInterests => content.researchInterests,
      SectionKey.digitalSkills => content.digitalSkills,
      SectionKey.keySkills => content.keySkills,
      _ => null,
    };

ResumeContent withStringList(
  ResumeContent content,
  SectionKey key,
  List<String> values,
) =>
    switch (key) {
      SectionKey.interests => content.copyWith(interests: values),
      SectionKey.researchInterests => content.copyWith(researchInterests: values),
      SectionKey.digitalSkills => content.copyWith(digitalSkills: values),
      SectionKey.keySkills => content.copyWith(keySkills: values),
      _ => content,
    };
