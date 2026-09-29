import 'package:json_annotation/json_annotation.dart';

/// The kind of document being produced.
///
/// CV type and target region are independent axes: a `researchCv` for
/// [RegionCode.germany] and one for [RegionCode.unitedStates] share a section
/// set but differ in ordering, paper size and personal-detail rules.
enum CvType {
  @JsonValue('job_resume')
  jobResume,
  @JsonValue('professional_cv')
  professionalCv,
  @JsonValue('academic_cv')
  academicCv,
  @JsonValue('student_resume')
  studentResume,
  @JsonValue('internship_resume')
  internshipResume,
  @JsonValue('graduate_resume')
  graduateResume,
  @JsonValue('scholarship_cv')
  scholarshipCv,
  @JsonValue('research_cv')
  researchCv,
  @JsonValue('phd_cv')
  phdCv,
  @JsonValue('europass')
  europass,
  @JsonValue('ats_resume')
  atsResume;

  /// Stable snake_case identifier used by the database, JSON backup and
  /// the bundled template/rule metadata.
  String get id => switch (this) {
    CvType.jobResume => 'job_resume',
    CvType.professionalCv => 'professional_cv',
    CvType.academicCv => 'academic_cv',
    CvType.studentResume => 'student_resume',
    CvType.internshipResume => 'internship_resume',
    CvType.graduateResume => 'graduate_resume',
    CvType.scholarshipCv => 'scholarship_cv',
    CvType.researchCv => 'research_cv',
    CvType.phdCv => 'phd_cv',
    CvType.europass => 'europass',
    CvType.atsResume => 'ats_resume',
  };

  static CvType fromId(String id) => CvType.values.firstWhere(
        (CvType t) => t.id == id,
        orElse: () => CvType.professionalCv,
      );

  /// Academic documents follow the conventions of research hiring rather
  /// than industry hiring: publications outrank summary length, page limits
  /// are lifted, and a photo is almost never expected.
  bool get isAcademic =>
      this == CvType.academicCv ||
      this == CvType.researchCv ||
      this == CvType.phdCv ||
      this == CvType.scholarshipCv ||
      this == CvType.graduateResume;

  /// Documents aimed at a student or early-career audience, where education
  /// legitimately sits above work experience.
  bool get isEarlyCareer =>
      this == CvType.studentResume || this == CvType.internshipResume;

  /// The ATS type forces a single-column, graphic-free rendering regardless
  /// of the chosen template's decoration level.
  bool get forcesAtsLayout => this == CvType.atsResume;
}
