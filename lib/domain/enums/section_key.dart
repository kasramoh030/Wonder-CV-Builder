import 'package:json_annotation/json_annotation.dart';

/// Every content block a CV can contain.
///
/// The builder, the template engine, the PDF renderer and the analyser all
/// address sections through this enum, which is why it is the single most
/// important type in the domain: it is the vocabulary the whole app speaks.
enum SectionKey {
  @JsonValue('personal')
  personal,
  @JsonValue('summary')
  summary,
  @JsonValue('experience')
  experience,
  @JsonValue('education')
  education,
  @JsonValue('skills')
  skills,
  @JsonValue('languages')
  languages,
  @JsonValue('projects')
  projects,
  @JsonValue('certifications')
  certifications,
  @JsonValue('awards')
  awards,
  @JsonValue('publications')
  publications,
  @JsonValue('volunteering')
  volunteering,
  @JsonValue('references')
  references,
  @JsonValue('courses')
  courses,
  @JsonValue('interests')
  interests,
  @JsonValue('militaryService')
  militaryService,
  @JsonValue('drivingLicence')
  drivingLicence,
  @JsonValue('researchInterests')
  researchInterests,
  @JsonValue('researchExperience')
  researchExperience,
  @JsonValue('teachingExperience')
  teachingExperience,
  @JsonValue('academicAppointments')
  academicAppointments,
  @JsonValue('conferences')
  conferences,
  @JsonValue('presentations')
  presentations,
  @JsonValue('grants')
  grants,
  @JsonValue('academicService')
  academicService,
  @JsonValue('memberships')
  memberships,
  @JsonValue('digitalSkills')
  digitalSkills,
  @JsonValue('achievements')
  achievements,
  @JsonValue('keySkills')
  keySkills,
  @JsonValue('additionalInfo')
  additionalInfo,
  @JsonValue('custom')
  custom;

  /// Stable identifier. Stored in `sectionOrder`/`hiddenSections`, so it
  /// must never change once a CV has been saved.
  String get id => switch (this) {
    SectionKey.personal => 'personal',
    SectionKey.summary => 'summary',
    SectionKey.experience => 'experience',
    SectionKey.education => 'education',
    SectionKey.skills => 'skills',
    SectionKey.languages => 'languages',
    SectionKey.projects => 'projects',
    SectionKey.certifications => 'certifications',
    SectionKey.awards => 'awards',
    SectionKey.publications => 'publications',
    SectionKey.volunteering => 'volunteering',
    SectionKey.references => 'references',
    SectionKey.courses => 'courses',
    SectionKey.interests => 'interests',
    SectionKey.militaryService => 'military_service',
    SectionKey.drivingLicence => 'driving_licence',
    SectionKey.researchInterests => 'research_interests',
    SectionKey.researchExperience => 'research_experience',
    SectionKey.teachingExperience => 'teaching_experience',
    SectionKey.academicAppointments => 'academic_appointments',
    SectionKey.conferences => 'conferences',
    SectionKey.presentations => 'presentations',
    SectionKey.grants => 'grants',
    SectionKey.academicService => 'academic_service',
    SectionKey.memberships => 'memberships',
    SectionKey.digitalSkills => 'digital_skills',
    SectionKey.achievements => 'achievements',
    SectionKey.keySkills => 'key_skills',
    SectionKey.additionalInfo => 'additional_info',
    SectionKey.custom => 'custom',
  };

  static SectionKey fromId(String id) => SectionKey.values.firstWhere(
        (SectionKey k) => k.id == id,
        orElse: () => SectionKey.custom,
      );

  /// Sections that hold a list of entries the user adds one by one, as
  /// opposed to free text ([SectionKey.summary], [SectionKey.personal]).
  bool get isCollection => switch (this) {
        SectionKey.personal ||
        SectionKey.summary ||
        SectionKey.researchInterests ||
        SectionKey.interests ||
        SectionKey.digitalSkills ||
        SectionKey.keySkills ||
        SectionKey.additionalInfo ||
        SectionKey.militaryService ||
        SectionKey.drivingLicence =>
          false,
        _ => true,
      };

  /// Canonical ATS-recognised heading. The analyser checks that a CV uses
  /// these (or a close regional variant) instead of creative headings such
  /// as "Where I've Been".
  bool get isAtsStandard => switch (this) {
        SectionKey.personal ||
        SectionKey.summary ||
        SectionKey.experience ||
        SectionKey.education ||
        SectionKey.skills ||
        SectionKey.languages ||
        SectionKey.projects ||
        SectionKey.certifications ||
        SectionKey.awards ||
        SectionKey.publications ||
        SectionKey.volunteering ||
        SectionKey.references ||
        SectionKey.courses ||
        SectionKey.memberships ||
        SectionKey.additionalInfo ||
        SectionKey.achievements ||
        SectionKey.keySkills =>
          true,
        _ => false,
      };

  /// Sections that belong to academic CVs. Used to build a sensible default
  /// section order per [CvType] and region.
  bool get isAcademicOnly => switch (this) {
        SectionKey.researchInterests ||
        SectionKey.researchExperience ||
        SectionKey.teachingExperience ||
        SectionKey.academicAppointments ||
        SectionKey.conferences ||
        SectionKey.presentations ||
        SectionKey.grants ||
        SectionKey.academicService ||
        SectionKey.publications =>
          true,
        _ => false,
      };

  /// Sections whose content is a plain list of dated one-liners.
  bool get isDatedList => switch (this) {
        SectionKey.courses ||
        SectionKey.conferences ||
        SectionKey.presentations ||
        SectionKey.grants ||
        SectionKey.academicService ||
        SectionKey.memberships ||
        SectionKey.researchExperience ||
        SectionKey.teachingExperience ||
        SectionKey.academicAppointments ||
        SectionKey.volunteering =>
          true,
        _ => false,
      };
}
