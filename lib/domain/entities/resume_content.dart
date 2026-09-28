import 'package:json_annotation/json_annotation.dart';

import '../enums/proficiency.dart';
import '../enums/section_key.dart';
import 'year_month.dart';

part 'resume_content.g.dart';

/// Identity and contact block.
///
/// Note the split between ordinary fields and *sensitive* fields
/// ([nationalId], [birthDate], [gender], [nationality], [maritalStatus]).
/// Sensitive fields are hidden unless [showSensitiveFields] is true, and
/// they are hidden by default for every region except Iran, where a
/// national ID and military-service status are still commonly requested.
/// The region profile decides the initial value; the user always has the
/// final say.
@JsonSerializable(explicitToJson: true)
class PersonalInfo {
  const PersonalInfo({
    this.firstName = '',
    this.lastName = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.city = '',
    this.province = '',
    this.country = '',
    this.linkedIn = '',
    this.gitHub = '',
    this.website = '',
    this.photoPath,
    this.showPhoto = false,
    this.summary = '',
    this.nationalId = '',
    this.birthDate,
    this.gender = '',
    this.nationality = '',
    this.maritalStatus = '',
    this.showSensitiveFields = false,
  });

  final String firstName;
  final String lastName;
  final String jobTitle;
  final String email;
  final String phone;
  final String city;
  final String province;
  final String country;

  /// Normalised link, without a protocol, e.g. `linkedin.com/in/ada`.
  final String linkedIn;
  final String gitHub;
  final String website;

  /// Absolute path to a locally stored photo. Never uploaded anywhere.
  final String? photoPath;
  final bool showPhoto;

  /// The professional summary, kept on the identity block because templates
  /// render it directly under the name in most layouts.
  final String summary;

  // ── Sensitive (opt-in) ───────────────────────────────────────────────────
  final String nationalId;
  final YearMonth? birthDate;
  final String gender;
  final String nationality;
  final String maritalStatus;
  final bool showSensitiveFields;

  factory PersonalInfo.fromJson(Map<String, dynamic> json) =>
      _$PersonalInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PersonalInfoToJson(this);

  /// Display name, tolerant of either part being missing.
  String get fullName {
    final String trimmed = '$firstName $lastName'.trim();
    return trimmed.isEmpty ? '' : trimmed;
  }

  bool get hasContact => email.isNotEmpty || phone.isNotEmpty;

  /// Ordered list of contact fragments that templates and the analyser can
  /// render without knowing about each individual field.
  List<String> get contactFragments => <String>[
        if (city.isNotEmpty || country.isNotEmpty)
          <String>[city, province, country].where((String s) => s.isNotEmpty).join(', '),
        if (phone.isNotEmpty) phone,
        if (email.isNotEmpty) email,
        if (linkedIn.isNotEmpty) linkedIn,
        if (gitHub.isNotEmpty) gitHub,
        if (website.isNotEmpty) website,
      ];

  PersonalInfo copyWith({
    String? firstName,
    String? lastName,
    String? jobTitle,
    String? email,
    String? phone,
    String? city,
    String? province,
    String? country,
    String? linkedIn,
    String? gitHub,
    String? website,
    String? photoPath,
    bool? showPhoto,
    String? summary,
    String? nationalId,
    YearMonth? birthDate,
    String? gender,
    String? nationality,
    String? maritalStatus,
    bool? showSensitiveFields,
    bool clearPhotoPath = false,
    bool clearBirthDate = false,
  }) =>
      PersonalInfo(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        jobTitle: jobTitle ?? this.jobTitle,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        province: province ?? this.province,
        country: country ?? this.country,
        linkedIn: linkedIn ?? this.linkedIn,
        gitHub: gitHub ?? this.gitHub,
        website: website ?? this.website,
        photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
        showPhoto: showPhoto ?? this.showPhoto,
        summary: summary ?? this.summary,
        nationalId: nationalId ?? this.nationalId,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        gender: gender ?? this.gender,
        nationality: nationality ?? this.nationality,
        maritalStatus: maritalStatus ?? this.maritalStatus,
        showSensitiveFields: showSensitiveFields ?? this.showSensitiveFields,
      );
}

/// A job in the work-history section.
@JsonSerializable(explicitToJson: true)
class Experience {
  const Experience({
    required this.id,
    this.company = '',
    this.jobTitle = '',
    this.location = '',
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.responsibilities = const <String>[],
    this.achievements = const <String>[],
    this.technologies = const <String>[],
    this.hidden = false,
  });

  final String id;
  final String company;
  final String jobTitle;
  final String location;
  final YearMonth? startDate;
  final YearMonth? endDate;
  final bool isCurrent;

  /// Bullet list of what the person was responsible for.
  final List<String> responsibilities;

  /// Bullet list of measurable outcomes. The Achievement Builder writes
  /// here; the analyser scores density of action verbs and results here.
  final List<String> achievements;

  /// Tools, languages and platforms, rendered as a subtle chip row.
  final List<String> technologies;

  /// Lets a CV exclude a profile entry without deleting it.
  final bool hidden;

  factory Experience.fromJson(Map<String, dynamic> json) => _$ExperienceFromJson(json);

  Map<String, dynamic> toJson() => _$ExperienceToJson(this);

  bool get isEmpty =>
      company.isEmpty && jobTitle.isEmpty && responsibilities.isEmpty && achievements.isEmpty;

  /// All free text belonging to this entry, used by the analyser.
  List<String> get allBullets => <String>[...responsibilities, ...achievements];

  Experience copyWith({
    String? company,
    String? jobTitle,
    String? location,
    YearMonth? startDate,
    YearMonth? endDate,
    bool? isCurrent,
    List<String>? responsibilities,
    List<String>? achievements,
    List<String>? technologies,
    bool? hidden,
    bool clearStart = false,
    bool clearEnd = false,
  }) =>
      Experience(
        id: id,
        company: company ?? this.company,
        jobTitle: jobTitle ?? this.jobTitle,
        location: location ?? this.location,
        startDate: clearStart ? null : (startDate ?? this.startDate),
        endDate: clearEnd ? null : (endDate ?? this.endDate),
        isCurrent: isCurrent ?? this.isCurrent,
        responsibilities: responsibilities ?? this.responsibilities,
        achievements: achievements ?? this.achievements,
        technologies: technologies ?? this.technologies,
        hidden: hidden ?? this.hidden,
      );
}

/// A degree, diploma or course of study.
@JsonSerializable(explicitToJson: true)
class Education {
  const Education({
    required this.id,
    this.institution = '',
    this.degree = '',
    this.fieldOfStudy = '',
    this.location = '',
    this.startDate,
    this.endDate,
    this.gpa = '',
    this.description = '',
    this.hidden = false,
  });

  final String id;

  /// University, school or training provider.
  final String institution;

  /// e.g. `BSc`, `MSc`, `Bachelor of Engineering`.
  final String degree;
  final String fieldOfStudy;
  final String location;
  final YearMonth? startDate;
  final YearMonth? endDate;

  /// Kept as text: scales differ wildly (0–20 in Iran, 4.0 GPA in the US,
  /// classifications in the UK) and normalising them loses meaning.
  final String gpa;
  final String description;
  final bool hidden;

  factory Education.fromJson(Map<String, dynamic> json) => _$EducationFromJson(json);

  Map<String, dynamic> toJson() => _$EducationToJson(this);

  String get qualificationLine {
    final List<String> parts = <String>[
      if (degree.isNotEmpty) degree,
      if (fieldOfStudy.isNotEmpty) fieldOfStudy,
    ];
    return parts.join(', ');
  }

  Education copyWith({
    String? institution,
    String? degree,
    String? fieldOfStudy,
    String? location,
    YearMonth? startDate,
    YearMonth? endDate,
    String? gpa,
    String? description,
    bool? hidden,
    bool clearStart = false,
    bool clearEnd = false,
  }) =>
      Education(
        id: id,
        institution: institution ?? this.institution,
        degree: degree ?? this.degree,
        fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
        location: location ?? this.location,
        startDate: clearStart ? null : (startDate ?? this.startDate),
        endDate: clearEnd ? null : (endDate ?? this.endDate),
        gpa: gpa ?? this.gpa,
        description: description ?? this.description,
        hidden: hidden ?? this.hidden,
      );
}

/// A skill, optionally grouped and levelled.
@JsonSerializable()
class Skill {
  const Skill({
    required this.id,
    this.name = '',
    this.level = SkillLevel.intermediate,
    this.category = '',
    this.showLevel = true,
  });

  final String id;
  final String name;
  final SkillLevel level;

  /// Free-form grouping such as `Languages`, `Frameworks`, `Soft skills`.
  final String category;

  /// Templates that render skills as a compact comma list hide the level.
  final bool showLevel;

  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);

  Map<String, dynamic> toJson() => _$SkillToJson(this);

  Skill copyWith({
    String? name,
    SkillLevel? level,
    String? category,
    bool? showLevel,
  }) =>
      Skill(
        id: id,
        name: name ?? this.name,
        level: level ?? this.level,
        category: category ?? this.category,
        showLevel: showLevel ?? this.showLevel,
      );
}

/// A spoken language.
@JsonSerializable()
class LanguageSkill {
  const LanguageSkill({
    required this.id,
    this.language = '',
    this.level = LanguageLevel.intermediate,
  });

  final String id;
  final String language;
  final LanguageLevel level;

  factory LanguageSkill.fromJson(Map<String, dynamic> json) =>
      _$LanguageSkillFromJson(json);

  Map<String, dynamic> toJson() => _$LanguageSkillToJson(this);

  LanguageSkill copyWith({String? language, LanguageLevel? level}) =>
      LanguageSkill(id: id, language: language ?? this.language, level: level ?? this.level);
}

/// A portfolio or side project.
@JsonSerializable()
class Project {
  const Project({
    required this.id,
    this.name = '',
    this.description = '',
    this.technologies = const <String>[],
    this.url = '',
    this.repository = '',
    this.startDate,
    this.endDate,
    this.hidden = false,
  });

  final String id;
  final String name;
  final String description;
  final List<String> technologies;
  final String url;
  final String repository;
  final YearMonth? startDate;
  final YearMonth? endDate;
  final bool hidden;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  Project copyWith({
    String? name,
    String? description,
    List<String>? technologies,
    String? url,
    String? repository,
    YearMonth? startDate,
    YearMonth? endDate,
    bool? hidden,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        technologies: technologies ?? this.technologies,
        url: url ?? this.url,
        repository: repository ?? this.repository,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        hidden: hidden ?? this.hidden,
      );
}

/// A certification, licence or credential.
@JsonSerializable(explicitToJson: true)
class Certification {
  const Certification({
    required this.id,
    this.name = '',
    this.organization = '',
    this.date,
    this.credentialId = '',
    this.verificationUrl = '',
    this.hidden = false,
  });

  final String id;
  final String name;
  final String organization;
  final YearMonth? date;
  final String credentialId;
  final String verificationUrl;
  final bool hidden;

  factory Certification.fromJson(Map<String, dynamic> json) =>
      _$CertificationFromJson(json);

  Map<String, dynamic> toJson() => _$CertificationToJson(this);

  Certification copyWith({
    String? name,
    String? organization,
    YearMonth? date,
    String? credentialId,
    String? verificationUrl,
    bool? hidden,
  }) =>
      Certification(
        id: id,
        name: name ?? this.name,
        organization: organization ?? this.organization,
        date: date ?? this.date,
        credentialId: credentialId ?? this.credentialId,
        verificationUrl: verificationUrl ?? this.verificationUrl,
        hidden: hidden ?? this.hidden,
      );
}

/// An award, prize or honour.
@JsonSerializable(explicitToJson: true)
class Award {
  const Award({
    required this.id,
    this.title = '',
    this.issuer = '',
    this.date,
    this.description = '',
    this.hidden = false,
  });

  final String id;
  final String title;
  final String issuer;
  final YearMonth? date;
  final String description;
  final bool hidden;

  factory Award.fromJson(Map<String, dynamic> json) => _$AwardFromJson(json);

  Map<String, dynamic> toJson() => _$AwardToJson(this);

  Award copyWith({
    String? title,
    String? issuer,
    YearMonth? date,
    String? description,
    bool? hidden,
  }) =>
      Award(
        id: id,
        title: title ?? this.title,
        issuer: issuer ?? this.issuer,
        date: date ?? this.date,
        description: description ?? this.description,
        hidden: hidden ?? this.hidden,
      );
}

/// A publication, with the metadata academic reviewers expect to see.
@JsonSerializable(explicitToJson: true)
class Publication {
  const Publication({
    required this.id,
    this.title = '',
    this.authors = '',
    this.venue = '',
    this.date,
    this.doi = '',
    this.url = '',
    this.type = PublicationType.journalArticle,
    this.hidden = false,
  });

  final String id;
  final String title;

  /// Author list *as the candidate wants it printed*, including any
  /// emphasis convention (e.g. bolding their own name is handled by the
  /// template, not by this string).
  final String authors;

  /// Journal, conference or publisher.
  final String venue;
  final YearMonth? date;
  final String doi;
  final String url;
  final PublicationType type;
  final bool hidden;

  factory Publication.fromJson(Map<String, dynamic> json) =>
      _$PublicationFromJson(json);

  Map<String, dynamic> toJson() => _$PublicationToJson(this);

  Publication copyWith({
    String? title,
    String? authors,
    String? venue,
    YearMonth? date,
    String? doi,
    String? url,
    PublicationType? type,
    bool? hidden,
  }) =>
      Publication(
        id: id,
        title: title ?? this.title,
        authors: authors ?? this.authors,
        venue: venue ?? this.venue,
        date: date ?? this.date,
        doi: doi ?? this.doi,
        url: url ?? this.url,
        type: type ?? this.type,
        hidden: hidden ?? this.hidden,
      );
}

enum PublicationType {
  @JsonValue('journal_article')
  journalArticle,
  @JsonValue('conference_paper')
  conferencePaper,
  @JsonValue('book_chapter')
  bookChapter,
  @JsonValue('book')
  book,
  @JsonValue('preprint')
  preprint,
  @JsonValue('thesis')
  thesis,
  @JsonValue('patent')
  patent,
  @JsonValue('other')
  other;

  String get id => switch (this) {
    PublicationType.journalArticle => 'journal_article',
    PublicationType.conferencePaper => 'conference_paper',
    PublicationType.bookChapter => 'book_chapter',
    PublicationType.book => 'book',
    PublicationType.preprint => 'preprint',
    PublicationType.thesis => 'thesis',
    PublicationType.patent => 'patent',
    PublicationType.other => 'other',
  };

  static PublicationType fromId(String id) => PublicationType.values.firstWhere(
        (PublicationType t) => t.id == id,
        orElse: () => PublicationType.journalArticle,
      );

  /// Sort weight used when a template groups publications by kind.
  int get groupOrder => switch (this) {
        PublicationType.book => 0,
        PublicationType.bookChapter => 1,
        PublicationType.journalArticle => 2,
        PublicationType.conferencePaper => 3,
        PublicationType.patent => 4,
        PublicationType.thesis => 5,
        PublicationType.preprint => 6,
        PublicationType.other => 7,
      };
}

/// A dated one-liner used by the simpler list sections.
///
/// Rather than modelling "conference", "grant", "course" and "presentation"
/// as four near-identical classes, they share [DatedEntry] and differ only
/// in which label the template prints and which fields it emphasises.
@JsonSerializable(explicitToJson: true)
class DatedEntry {
  const DatedEntry({
    required this.id,
    this.title = '',
    this.organization = '',
    this.location = '',
    this.startDate,
    this.endDate,
    this.description = '',
    this.url = '',
    this.hidden = false,
  });

  final String id;
  final String title;
  final String organization;
  final String location;
  final YearMonth? startDate;
  final YearMonth? endDate;
  final String description;
  final String url;
  final bool hidden;

  factory DatedEntry.fromJson(Map<String, dynamic> json) => _$DatedEntryFromJson(json);

  Map<String, dynamic> toJson() => _$DatedEntryToJson(this);

  DatedEntry copyWith({
    String? title,
    String? organization,
    String? location,
    YearMonth? startDate,
    YearMonth? endDate,
    String? description,
    String? url,
    bool? hidden,
  }) =>
      DatedEntry(
        id: id,
        title: title ?? this.title,
        organization: organization ?? this.organization,
        location: location ?? this.location,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        description: description ?? this.description,
        url: url ?? this.url,
        hidden: hidden ?? this.hidden,
      );
}

/// A referee entry.
@JsonSerializable()
class Reference {
  const Reference({
    required this.id,
    this.name = '',
    this.position = '',
    this.organization = '',
    this.email = '',
    this.phone = '',
    this.relationship = '',
    this.hidden = false,
  });

  final String id;
  final String name;
  final String position;
  final String organization;
  final String email;
  final String phone;
  final String relationship;
  final bool hidden;

  factory Reference.fromJson(Map<String, dynamic> json) => _$ReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$ReferenceToJson(this);

  Reference copyWith({
    String? name,
    String? position,
    String? organization,
    String? email,
    String? phone,
    String? relationship,
    bool? hidden,
  }) =>
      Reference(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
        organization: organization ?? this.organization,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        relationship: relationship ?? this.relationship,
        hidden: hidden ?? this.hidden,
      );
}

/// A user-defined section, so the app never becomes a cage.
@JsonSerializable(explicitToJson: true)
class CustomSection {
  const CustomSection({
    required this.id,
    this.title = '',
    this.entries = const <DatedEntry>[],
    this.bodyText = '',
    this.useEntries = true,
    this.hidden = false,
  });

  final String id;
  final String title;
  final List<DatedEntry> entries;
  final String bodyText;

  /// `false` renders [bodyText] as a paragraph instead of [entries] as a list.
  final bool useEntries;
  final bool hidden;

  factory CustomSection.fromJson(Map<String, dynamic> json) =>
      _$CustomSectionFromJson(json);

  Map<String, dynamic> toJson() => _$CustomSectionToJson(this);

  CustomSection copyWith({
    String? title,
    List<DatedEntry>? entries,
    String? bodyText,
    bool? useEntries,
    bool? hidden,
  }) =>
      CustomSection(
        id: id,
        title: title ?? this.title,
        entries: entries ?? this.entries,
        bodyText: bodyText ?? this.bodyText,
        useEntries: useEntries ?? this.useEntries,
        hidden: hidden ?? this.hidden,
      );
}

/// Everything that appears inside a CV document.
///
/// This object is stored as a single JSON column. That choice is deliberate:
/// a CV is a *document*, always read and written whole, and free-text
/// document storage keeps duplication, versioning, backup and restore
/// trivial and atomic. Nothing in the analyser needs to query individual
/// bullets through SQL.
@JsonSerializable(explicitToJson: true)
class ResumeContent {
  const ResumeContent({
    this.personal = const PersonalInfo(),
    this.experiences = const <Experience>[],
    this.education = const <Education>[],
    this.skills = const <Skill>[],
    this.languages = const <LanguageSkill>[],
    this.projects = const <Project>[],
    this.certifications = const <Certification>[],
    this.awards = const <Award>[],
    this.publications = const <Publication>[],
    this.volunteering = const <DatedEntry>[],
    this.references = const <Reference>[],
    this.courses = const <DatedEntry>[],
    this.researchExperience = const <DatedEntry>[],
    this.teachingExperience = const <DatedEntry>[],
    this.academicAppointments = const <DatedEntry>[],
    this.conferences = const <DatedEntry>[],
    this.presentations = const <DatedEntry>[],
    this.grants = const <DatedEntry>[],
    this.academicService = const <DatedEntry>[],
    this.memberships = const <DatedEntry>[],
    this.customSections = const <CustomSection>[],
    this.researchInterests = const <String>[],
    this.interests = const <String>[],
    this.digitalSkills = const <String>[],
    this.keySkills = const <String>[],
    this.additionalInfo = '',
    this.militaryService = '',
    this.drivingLicence = '',
  });

  final PersonalInfo personal;

  final List<Experience> experiences;
  final List<Education> education;
  final List<Skill> skills;
  final List<LanguageSkill> languages;
  final List<Project> projects;
  final List<Certification> certifications;
  final List<Award> awards;
  final List<Publication> publications;
  final List<DatedEntry> volunteering;
  final List<Reference> references;
  final List<DatedEntry> courses;

  // Academic collections.
  final List<DatedEntry> researchExperience;
  final List<DatedEntry> teachingExperience;
  final List<DatedEntry> academicAppointments;
  final List<DatedEntry> conferences;
  final List<DatedEntry> presentations;
  final List<DatedEntry> grants;
  final List<DatedEntry> academicService;
  final List<DatedEntry> memberships;

  final List<CustomSection> customSections;

  // Free-text list sections.
  final List<String> researchInterests;
  final List<String> interests;
  final List<String> digitalSkills;
  final List<String> keySkills;
  final String additionalInfo;
  final String militaryService;
  final String drivingLicence;

  factory ResumeContent.fromJson(Map<String, dynamic> json) =>
      _$ResumeContentFromJson(json);

  Map<String, dynamic> toJson() => _$ResumeContentToJson(this);

  static const ResumeContent empty = ResumeContent();

  /// `true` when the document has no user-authored content at all.
  bool get isEmpty =>
      personal.fullName.isEmpty &&
      personal.summary.isEmpty &&
      experiences.isEmpty &&
      education.isEmpty &&
      skills.isEmpty;

  /// Entries for a collection section, addressed by the section vocabulary.
  ///
  /// Returning `List<DatedEntry>` for sections that hold richer types is not
  /// possible, so this accessor is limited to the sections that genuinely
  /// use [DatedEntry]; richer sections have their own typed getters.
  List<DatedEntry> datedEntriesFor(SectionKey key) => switch (key) {
        SectionKey.volunteering => volunteering,
        SectionKey.courses => courses,
        SectionKey.researchExperience => researchExperience,
        SectionKey.teachingExperience => teachingExperience,
        SectionKey.academicAppointments => academicAppointments,
        SectionKey.conferences => conferences,
        SectionKey.presentations => presentations,
        SectionKey.grants => grants,
        SectionKey.academicService => academicService,
        SectionKey.memberships => memberships,
        _ => const <DatedEntry>[],
      };

  /// Replaces the collection backing [key]. Lets the builder's generic list
  /// editor work without a switch over twenty-nine section types.
  ResumeContent withDatedEntries(SectionKey key, List<DatedEntry> entries) =>
      switch (key) {
        SectionKey.volunteering => copyWith(volunteering: entries),
        SectionKey.courses => copyWith(courses: entries),
        SectionKey.researchExperience => copyWith(researchExperience: entries),
        SectionKey.teachingExperience => copyWith(teachingExperience: entries),
        SectionKey.academicAppointments =>
          copyWith(academicAppointments: entries),
        SectionKey.conferences => copyWith(conferences: entries),
        SectionKey.presentations => copyWith(presentations: entries),
        SectionKey.grants => copyWith(grants: entries),
        SectionKey.academicService => copyWith(academicService: entries),
        SectionKey.memberships => copyWith(memberships: entries),
        _ => this,
      };

  /// `true` when [key] holds at least one visible entry, or non-empty body
  /// text for the narrative sections. The builder uses this to decide
  /// whether a section is worth rendering at all.
  bool hasContentFor(SectionKey key) => switch (key) {
        SectionKey.personal => personal.fullName.isNotEmpty,
        SectionKey.summary => personal.summary.trim().isNotEmpty,
        SectionKey.experience => experiences.any((Experience e) => !e.hidden),
        SectionKey.education => education.any((Education e) => !e.hidden),
        SectionKey.skills => skills.isNotEmpty,
        SectionKey.languages => languages.isNotEmpty,
        SectionKey.projects => projects.any((Project p) => !p.hidden),
        SectionKey.certifications =>
          certifications.any((Certification c) => !c.hidden),
        SectionKey.awards => awards.any((Award a) => !a.hidden),
        SectionKey.publications => publications.any((Publication p) => !p.hidden),
        SectionKey.volunteering => volunteering.any((DatedEntry e) => !e.hidden),
        SectionKey.references => references.any((Reference r) => !r.hidden),
        SectionKey.courses => courses.any((DatedEntry e) => !e.hidden),
        SectionKey.researchExperience =>
          researchExperience.any((DatedEntry e) => !e.hidden),
        SectionKey.teachingExperience =>
          teachingExperience.any((DatedEntry e) => !e.hidden),
        SectionKey.academicAppointments =>
          academicAppointments.any((DatedEntry e) => !e.hidden),
        SectionKey.conferences => conferences.any((DatedEntry e) => !e.hidden),
        SectionKey.presentations => presentations.any((DatedEntry e) => !e.hidden),
        SectionKey.grants => grants.any((DatedEntry e) => !e.hidden),
        SectionKey.academicService =>
          academicService.any((DatedEntry e) => !e.hidden),
        SectionKey.memberships => memberships.any((DatedEntry e) => !e.hidden),
        SectionKey.custom => customSections.any((CustomSection s) => !s.hidden),
        SectionKey.researchInterests => researchInterests.isNotEmpty,
        SectionKey.interests => interests.isNotEmpty,
        SectionKey.digitalSkills => digitalSkills.isNotEmpty,
        SectionKey.keySkills => keySkills.isNotEmpty,
        SectionKey.additionalInfo => additionalInfo.trim().isNotEmpty,
        SectionKey.militaryService => militaryService.trim().isNotEmpty,
        SectionKey.drivingLicence => drivingLicence.trim().isNotEmpty,
      };

  ResumeContent copyWith({
    PersonalInfo? personal,
    List<Experience>? experiences,
    List<Education>? education,
    List<Skill>? skills,
    List<LanguageSkill>? languages,
    List<Project>? projects,
    List<Certification>? certifications,
    List<Award>? awards,
    List<Publication>? publications,
    List<DatedEntry>? volunteering,
    List<Reference>? references,
    List<DatedEntry>? courses,
    List<DatedEntry>? researchExperience,
    List<DatedEntry>? teachingExperience,
    List<DatedEntry>? academicAppointments,
    List<DatedEntry>? conferences,
    List<DatedEntry>? presentations,
    List<DatedEntry>? grants,
    List<DatedEntry>? academicService,
    List<DatedEntry>? memberships,
    List<CustomSection>? customSections,
    List<String>? researchInterests,
    List<String>? interests,
    List<String>? digitalSkills,
    List<String>? keySkills,
    String? additionalInfo,
    String? militaryService,
    String? drivingLicence,
  }) =>
      ResumeContent(
        personal: personal ?? this.personal,
        experiences: experiences ?? this.experiences,
        education: education ?? this.education,
        skills: skills ?? this.skills,
        languages: languages ?? this.languages,
        projects: projects ?? this.projects,
        certifications: certifications ?? this.certifications,
        awards: awards ?? this.awards,
        publications: publications ?? this.publications,
        volunteering: volunteering ?? this.volunteering,
        references: references ?? this.references,
        courses: courses ?? this.courses,
        researchExperience: researchExperience ?? this.researchExperience,
        teachingExperience: teachingExperience ?? this.teachingExperience,
        academicAppointments: academicAppointments ?? this.academicAppointments,
        conferences: conferences ?? this.conferences,
        presentations: presentations ?? this.presentations,
        grants: grants ?? this.grants,
        academicService: academicService ?? this.academicService,
        memberships: memberships ?? this.memberships,
        customSections: customSections ?? this.customSections,
        researchInterests: researchInterests ?? this.researchInterests,
        interests: interests ?? this.interests,
        digitalSkills: digitalSkills ?? this.digitalSkills,
        keySkills: keySkills ?? this.keySkills,
        additionalInfo: additionalInfo ?? this.additionalInfo,
        militaryService: militaryService ?? this.militaryService,
        drivingLicence: drivingLicence ?? this.drivingLicence,
      );
}
