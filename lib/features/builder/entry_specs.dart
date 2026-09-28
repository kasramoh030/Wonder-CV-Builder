import 'package:uuid/uuid.dart';

import '../../domain/entities/resume_content.dart';
import '../../domain/entities/year_month.dart';
import '../../domain/enums/proficiency.dart';
import '../../domain/enums/section_key.dart';
import '../../l10n/app_localizations.dart';
import 'builder_sections.dart';

/// A single editable field of one record.
///
/// Records are edited through descriptions rather than through eleven bespoke
/// forms. The description is typed at the point where the field is declared
/// (`textOf<Experience>(...)` in, `String` out), so a mismatch between a label
/// and the field behind it is a compile error rather than a runtime surprise.
sealed class EntryField {
  const EntryField(this.label);

  final String label;
}

class TextEntryField extends EntryField {
  const TextEntryField(
    super.label, {
    required this.read,
    required this.write,
    this.multiline = false,
  });

  final String Function(Object entry) read;
  final Object Function(Object entry, String value) write;
  final bool multiline;
}

/// A list of short strings edited as one line per bullet.
class LinesEntryField extends EntryField {
  const LinesEntryField(
    super.label, {
    required this.read,
    required this.write,
  });

  final List<String> Function(Object entry) read;
  final Object Function(Object entry, List<String> value) write;
}

class DateEntryField extends EntryField {
  const DateEntryField(
    super.label, {
    required this.read,
    required this.write,
  });

  final YearMonth? Function(Object entry) read;
  final Object Function(Object entry, YearMonth? value) write;
}

class SwitchEntryField extends EntryField {
  const SwitchEntryField(
    super.label, {
    required this.read,
    required this.write,
  });

  final bool Function(Object entry) read;
  final Object Function(Object entry, bool value) write;
}

/// A fixed set of options, edited as a dropdown.
///
/// The value type is erased to [Object] here on purpose. A generic
/// `ChoiceEntryField<SkillLevel>` would give its [write] the runtime type
/// `(Object, SkillLevel) => Skill`, which is *not* assignable to
/// `(Object, Object?) => Object` — so the moment anything handled all choice
/// fields uniformly, as the editor and the tests do, the cast would fail at
/// runtime. `choiceOf` keeps the typed surface and does the check once.
class ChoiceEntryField extends EntryField {
  const ChoiceEntryField(
    super.label, {
    required this.values,
    required this.labelOf,
    required this.read,
    required this.write,
  });

  final List<Object?> values;
  final String Function(Object? value) labelOf;
  final Object? Function(Object entry) read;
  final Object Function(Object entry, Object? value) write;
}

EntryField textOf<E extends Object>(
  String label,
  String Function(E entry) read,
  E Function(E entry, String value) write, {
  bool multiline = false,
}) =>
    TextEntryField(
      label,
      read: (Object e) => read(e as E),
      write: (Object e, String v) => write(e as E, v),
      multiline: multiline,
    );

EntryField linesOf<E extends Object>(
  String label,
  List<String> Function(E entry) read,
  E Function(E entry, List<String> value) write,
) =>
    LinesEntryField(
      label,
      read: (Object e) => read(e as E),
      write: (Object e, List<String> v) => write(e as E, v),
    );

EntryField dateOf<E extends Object>(
  String label,
  YearMonth? Function(E entry) read,
  E Function(E entry, YearMonth? value) write,
) =>
    DateEntryField(
      label,
      read: (Object e) => read(e as E),
      write: (Object e, YearMonth? v) => write(e as E, v),
    );

EntryField switchOf<E extends Object>(
  String label,
  bool Function(E entry) read,
  E Function(E entry, bool value) write,
) =>
    SwitchEntryField(
      label,
      read: (Object e) => read(e as E),
      write: (Object e, bool v) => write(e as E, v),
    );

EntryField choiceOf<E extends Object, T>(
  String label,
  List<T> values,
  String Function(T value) labelOf,
  T? Function(E entry) read,
  E Function(E entry, T value) write,
) =>
    ChoiceEntryField(
      label,
      values: values.cast<Object?>(),
      labelOf: (Object? value) => value is T ? labelOf(value) : '',
      read: (Object e) => read(e as E),
      // A value of the wrong type is impossible from the dropdown that owns
      // this field; returning the record unchanged is the safe answer if it
      // ever happens.
      write: (Object e, Object? v) => v is T ? write(e as E, v) : e,
    );

/// The date span of a record, for the summary line of an entry tile.
typedef EntryRange = ({YearMonth? start, YearMonth? end, bool isCurrent});

/// Everything the generic list editor needs to know about one kind of record.
class EntrySpec {
  const EntrySpec({
    required this.read,
    required this.write,
    required this.create,
    required this.fields,
    required this.title,
    this.subtitle,
    this.range,
  });

  final List<Object> Function(ResumeContent content) read;
  final ResumeContent Function(ResumeContent content, List<Object> entries) write;
  final Object Function() create;
  final List<EntryField> fields;
  final String Function(Object entry) title;
  final String? Function(Object entry)? subtitle;
  final EntryRange? Function(Object entry)? range;
}

const Uuid _uuid = Uuid();

List<Object> _boxes<E>(List<E> values) => values.cast<Object>();

EntrySpec? entrySpecFor(SectionKey key, AppLocalizations l10n) => switch (key) {
      SectionKey.experience => EntrySpec(
          read: (ResumeContent c) => _boxes(c.experiences),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(experiences: e.cast<Experience>()),
          create: () => Experience(id: _uuid.v4()),
          title: (Object e) => (e as Experience).jobTitle.isEmpty
              ? l10n.sectionExperience
              : e.jobTitle,
          subtitle: (Object e) => (e as Experience).company,
          range: (Object e) {
            final Experience x = e as Experience;
            return (start: x.startDate, end: x.endDate, isCurrent: x.isCurrent);
          },
          fields: <EntryField>[
            textOf<Experience>(l10n.fieldJobTitle, (Experience e) => e.jobTitle,
                (Experience e, String v) => e.copyWith(jobTitle: v)),
            textOf<Experience>(l10n.fieldCompany, (Experience e) => e.company,
                (Experience e, String v) => e.copyWith(company: v)),
            textOf<Experience>(l10n.fieldLocation, (Experience e) => e.location,
                (Experience e, String v) => e.copyWith(location: v)),
            dateOf<Experience>(l10n.fieldStartDate, (Experience e) => e.startDate,
                (Experience e, YearMonth? v) => e.copyWith(startDate: v, clearStart: v == null)),
            dateOf<Experience>(l10n.fieldEndDate, (Experience e) => e.endDate,
                (Experience e, YearMonth? v) => e.copyWith(endDate: v, clearEnd: v == null)),
            switchOf<Experience>(
              l10n.fieldCurrentlyWorkHere,
              (Experience e) => e.isCurrent,
              (Experience e, bool v) => e.copyWith(isCurrent: v),
            ),
            linesOf<Experience>(
              l10n.fieldResponsibilities,
              (Experience e) => e.responsibilities,
              (Experience e, List<String> v) => e.copyWith(responsibilities: v),
            ),
            linesOf<Experience>(
              l10n.fieldAchievements,
              (Experience e) => e.achievements,
              (Experience e, List<String> v) => e.copyWith(achievements: v),
            ),
            linesOf<Experience>(
              l10n.fieldTechnologies,
              (Experience e) => e.technologies,
              (Experience e, List<String> v) => e.copyWith(technologies: v),
            ),
          ],
        ),
      SectionKey.education => EntrySpec(
          read: (ResumeContent c) => _boxes(c.education),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(education: e.cast<Education>()),
          create: () => Education(id: _uuid.v4()),
          title: (Object e) => (e as Education).degree.isEmpty
              ? l10n.sectionEducation
              : e.degree,
          subtitle: (Object e) => (e as Education).institution,
          range: (Object e) {
            final Education x = e as Education;
            return (start: x.startDate, end: x.endDate, isCurrent: false);
          },
          fields: <EntryField>[
            textOf<Education>(l10n.fieldUniversity,
                (Education e) => e.institution,
                (Education e, String v) => e.copyWith(institution: v)),
            textOf<Education>(l10n.fieldDegree, (Education e) => e.degree,
                (Education e, String v) => e.copyWith(degree: v)),
            textOf<Education>(
              l10n.fieldFieldOfStudy,
              (Education e) => e.fieldOfStudy,
              (Education e, String v) => e.copyWith(fieldOfStudy: v),
            ),
            textOf<Education>(l10n.fieldLocation, (Education e) => e.location,
                (Education e, String v) => e.copyWith(location: v)),
            dateOf<Education>(l10n.fieldStartDate, (Education e) => e.startDate,
                (Education e, YearMonth? v) => e.copyWith(startDate: v, clearStart: v == null)),
            dateOf<Education>(l10n.fieldEndDate, (Education e) => e.endDate,
                (Education e, YearMonth? v) => e.copyWith(endDate: v, clearEnd: v == null)),
            textOf<Education>(l10n.fieldGpa, (Education e) => e.gpa,
                (Education e, String v) => e.copyWith(gpa: v)),
            textOf<Education>(
              l10n.fieldDescription,
              (Education e) => e.description,
              (Education e, String v) => e.copyWith(description: v),
              multiline: true,
            ),
          ],
        ),
      SectionKey.skills => EntrySpec(
          read: (ResumeContent c) => _boxes(c.skills),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(skills: e.cast<Skill>()),
          create: () => Skill(id: _uuid.v4()),
          title: (Object e) => (e as Skill).name.isEmpty
              ? l10n.sectionSkills
              : e.name,
          subtitle: (Object e) => (e as Skill).category,
          fields: <EntryField>[
            textOf<Skill>(l10n.fieldSkillName, (Skill e) => e.name,
                (Skill e, String v) => e.copyWith(name: v)),
            choiceOf<Skill, SkillLevel>(
              l10n.fieldSkillLevel,
              SkillLevel.values,
              (SkillLevel v) => _skillLevelLabel(v, l10n),
              (Skill e) => e.level,
              (Skill e, SkillLevel v) => e.copyWith(level: v),
            ),
            textOf<Skill>(l10n.fieldCategory, (Skill e) => e.category,
                (Skill e, String v) => e.copyWith(category: v)),
          ],
        ),
      SectionKey.languages => EntrySpec(
          read: (ResumeContent c) => _boxes(c.languages),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(languages: e.cast<LanguageSkill>()),
          create: () => LanguageSkill(id: _uuid.v4()),
          title: (Object e) => (e as LanguageSkill).language.isEmpty
              ? l10n.sectionLanguages
              : e.language,
          fields: <EntryField>[
            textOf<LanguageSkill>(
              l10n.fieldLanguage,
              (LanguageSkill e) => e.language,
              (LanguageSkill e, String v) => e.copyWith(language: v),
            ),
            choiceOf<LanguageSkill, LanguageLevel>(
              l10n.fieldLanguageLevel,
              LanguageLevel.values,
              (LanguageLevel v) => _languageLevelLabel(v, l10n),
              (LanguageSkill e) => e.level,
              (LanguageSkill e, LanguageLevel v) => e.copyWith(level: v),
            ),
          ],
        ),
      SectionKey.projects => EntrySpec(
          read: (ResumeContent c) => _boxes(c.projects),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(projects: e.cast<Project>()),
          create: () => Project(id: _uuid.v4()),
          title: (Object e) =>
              (e as Project).name.isEmpty ? l10n.sectionProjects : e.name,
          range: (Object e) {
            final Project x = e as Project;
            return (start: x.startDate, end: x.endDate, isCurrent: false);
          },
          fields: <EntryField>[
            textOf<Project>(l10n.fieldProjectName, (Project e) => e.name,
                (Project e, String v) => e.copyWith(name: v)),
            textOf<Project>(
              l10n.fieldDescription,
              (Project e) => e.description,
              (Project e, String v) => e.copyWith(description: v),
              multiline: true,
            ),
            linesOf<Project>(
              l10n.fieldTechnologies,
              (Project e) => e.technologies,
              (Project e, List<String> v) => e.copyWith(technologies: v),
            ),
            textOf<Project>(l10n.fieldProjectUrl, (Project e) => e.url,
                (Project e, String v) => e.copyWith(url: v)),
            textOf<Project>(l10n.fieldProjectRepo, (Project e) => e.repository,
                (Project e, String v) => e.copyWith(repository: v)),
            dateOf<Project>(l10n.fieldStartDate, (Project e) => e.startDate,
                (Project e, YearMonth? v) => e.copyWith(startDate: v, clearStart: v == null)),
            dateOf<Project>(l10n.fieldEndDate, (Project e) => e.endDate,
                (Project e, YearMonth? v) => e.copyWith(endDate: v, clearEnd: v == null)),
          ],
        ),
      SectionKey.certifications => EntrySpec(
          read: (ResumeContent c) => _boxes(c.certifications),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(certifications: e.cast<Certification>()),
          create: () => Certification(id: _uuid.v4()),
          title: (Object e) => (e as Certification).name.isEmpty
              ? l10n.sectionCertifications
              : e.name,
          subtitle: (Object e) => (e as Certification).organization,
          fields: <EntryField>[
            textOf<Certification>(
              l10n.fieldCertificateName,
              (Certification e) => e.name,
              (Certification e, String v) => e.copyWith(name: v),
            ),
            textOf<Certification>(
              l10n.fieldOrganization,
              (Certification e) => e.organization,
              (Certification e, String v) => e.copyWith(organization: v),
            ),
            dateOf<Certification>(
              l10n.fieldDate,
              (Certification e) => e.date,
              (Certification e, YearMonth? v) => e.copyWith(date: v, clearDate: v == null),
            ),
            textOf<Certification>(
              l10n.fieldCredentialId,
              (Certification e) => e.credentialId,
              (Certification e, String v) => e.copyWith(credentialId: v),
            ),
            textOf<Certification>(
              l10n.fieldVerificationUrl,
              (Certification e) => e.verificationUrl,
              (Certification e, String v) => e.copyWith(verificationUrl: v),
            ),
          ],
        ),
      SectionKey.awards || SectionKey.achievements => EntrySpec(
          read: (ResumeContent c) => _boxes(c.awards),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(awards: e.cast<Award>()),
          create: () => Award(id: _uuid.v4()),
          title: (Object e) =>
              (e as Award).title.isEmpty ? sectionTitle(key, l10n) : e.title,
          subtitle: (Object e) => (e as Award).issuer,
          fields: <EntryField>[
            textOf<Award>(l10n.fieldTitle, (Award e) => e.title,
                (Award e, String v) => e.copyWith(title: v)),
            textOf<Award>(l10n.fieldOrganization, (Award e) => e.issuer,
                (Award e, String v) => e.copyWith(issuer: v)),
            dateOf<Award>(l10n.fieldDate, (Award e) => e.date,
                (Award e, YearMonth? v) => e.copyWith(date: v, clearDate: v == null)),
            textOf<Award>(
              l10n.fieldDescription,
              (Award e) => e.description,
              (Award e, String v) => e.copyWith(description: v),
              multiline: true,
            ),
          ],
        ),
      SectionKey.publications => EntrySpec(
          read: (ResumeContent c) => _boxes(c.publications),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(publications: e.cast<Publication>()),
          create: () => Publication(id: _uuid.v4()),
          title: (Object e) => (e as Publication).title.isEmpty
              ? l10n.sectionPublications
              : e.title,
          subtitle: (Object e) => (e as Publication).venue,
          fields: <EntryField>[
            textOf<Publication>(l10n.fieldTitle, (Publication e) => e.title,
                (Publication e, String v) => e.copyWith(title: v)),
            textOf<Publication>(l10n.fieldAuthors, (Publication e) => e.authors,
                (Publication e, String v) => e.copyWith(authors: v)),
            textOf<Publication>(l10n.fieldOrganization,
                (Publication e) => e.venue,
                (Publication e, String v) => e.copyWith(venue: v)),
            dateOf<Publication>(l10n.fieldDate, (Publication e) => e.date,
                (Publication e, YearMonth? v) => e.copyWith(date: v, clearDate: v == null)),
            textOf<Publication>(l10n.fieldDoi, (Publication e) => e.doi,
                (Publication e, String v) => e.copyWith(doi: v)),
            textOf<Publication>(l10n.fieldProjectUrl, (Publication e) => e.url,
                (Publication e, String v) => e.copyWith(url: v)),
          ],
        ),
      SectionKey.references => EntrySpec(
          read: (ResumeContent c) => _boxes(c.references),
          write: (ResumeContent c, List<Object> e) =>
              c.copyWith(references: e.cast<Reference>()),
          create: () => Reference(id: _uuid.v4()),
          title: (Object e) =>
              (e as Reference).name.isEmpty ? l10n.sectionReferences : e.name,
          subtitle: (Object e) => (e as Reference).position,
          fields: <EntryField>[
            textOf<Reference>(l10n.fieldReferenceName, (Reference e) => e.name,
                (Reference e, String v) => e.copyWith(name: v)),
            textOf<Reference>(
              l10n.fieldReferenceTitle,
              (Reference e) => e.position,
              (Reference e, String v) => e.copyWith(position: v),
            ),
            textOf<Reference>(
              l10n.fieldOrganization,
              (Reference e) => e.organization,
              (Reference e, String v) => e.copyWith(organization: v),
            ),
            textOf<Reference>(
              l10n.fieldReferenceEmail,
              (Reference e) => e.email,
              (Reference e, String v) => e.copyWith(email: v),
            ),
            textOf<Reference>(
              l10n.fieldReferencePhone,
              (Reference e) => e.phone,
              (Reference e, String v) => e.copyWith(phone: v),
            ),
            textOf<Reference>(
              l10n.fieldRelationship,
              (Reference e) => e.relationship,
              (Reference e, String v) => e.copyWith(relationship: v),
            ),
          ],
        ),
      SectionKey.volunteering ||
      SectionKey.courses ||
      SectionKey.researchExperience ||
      SectionKey.teachingExperience ||
      SectionKey.academicAppointments ||
      SectionKey.conferences ||
      SectionKey.presentations ||
      SectionKey.grants ||
      SectionKey.academicService ||
      SectionKey.memberships =>
        _datedSpec(key, l10n),
      _ => null,
    };

/// The ten sections that share one record shape.
EntrySpec _datedSpec(SectionKey key, AppLocalizations l10n) => EntrySpec(
      read: (ResumeContent c) => _boxes(c.datedEntriesFor(key)),
      write: (ResumeContent c, List<Object> e) =>
          c.withDatedEntries(key, e.cast<DatedEntry>()),
      create: () => DatedEntry(id: _uuid.v4()),
      title: (Object e) => (e as DatedEntry).title.isEmpty
          ? sectionTitle(key, l10n)
          : e.title,
      subtitle: (Object e) => (e as DatedEntry).organization,
      range: (Object e) {
        final DatedEntry x = e as DatedEntry;
        return (start: x.startDate, end: x.endDate, isCurrent: false);
      },
      fields: <EntryField>[
        textOf<DatedEntry>(l10n.fieldTitle, (DatedEntry e) => e.title,
            (DatedEntry e, String v) => e.copyWith(title: v)),
        textOf<DatedEntry>(l10n.fieldOrganization,
            (DatedEntry e) => e.organization,
            (DatedEntry e, String v) => e.copyWith(organization: v)),
        textOf<DatedEntry>(l10n.fieldLocation, (DatedEntry e) => e.location,
            (DatedEntry e, String v) => e.copyWith(location: v)),
        dateOf<DatedEntry>(l10n.fieldStartDate, (DatedEntry e) => e.startDate,
            (DatedEntry e, YearMonth? v) => e.copyWith(startDate: v, clearStart: v == null)),
        dateOf<DatedEntry>(l10n.fieldEndDate, (DatedEntry e) => e.endDate,
            (DatedEntry e, YearMonth? v) => e.copyWith(endDate: v, clearEnd: v == null)),
        textOf<DatedEntry>(
          l10n.fieldDescription,
          (DatedEntry e) => e.description,
          (DatedEntry e, String v) => e.copyWith(description: v),
          multiline: true,
        ),
        textOf<DatedEntry>(l10n.fieldWebsite, (DatedEntry e) => e.url,
            (DatedEntry e, String v) => e.copyWith(url: v)),
      ],
    );

String _skillLevelLabel(SkillLevel level, AppLocalizations l10n) =>
    switch (level) {
      SkillLevel.beginner => l10n.skillLevelBeginner,
      SkillLevel.intermediate => l10n.skillLevelIntermediate,
      SkillLevel.advanced => l10n.skillLevelAdvanced,
      SkillLevel.expert => l10n.skillLevelExpert,
    };

String _languageLevelLabel(LanguageLevel level, AppLocalizations l10n) =>
    switch (level) {
      LanguageLevel.beginner => l10n.languageLevelBeginner,
      LanguageLevel.intermediate => l10n.languageLevelIntermediate,
      LanguageLevel.advanced => l10n.languageLevelAdvanced,
      LanguageLevel.fluent => l10n.languageLevelFluent,
      LanguageLevel.native => l10n.languageLevelNative,
    };
