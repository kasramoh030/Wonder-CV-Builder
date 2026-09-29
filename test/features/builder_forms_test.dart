import 'package:cv_pro/domain/entities/resume.dart';
import 'package:cv_pro/domain/entities/resume_content.dart';
import 'package:cv_pro/domain/entities/year_month.dart';
import 'package:cv_pro/domain/enums/cv_type.dart';
import 'package:cv_pro/domain/enums/document_options.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/enums/section_key.dart';
import 'package:cv_pro/features/builder/builder_sections.dart';
import 'package:cv_pro/features/builder/entry_specs.dart';
import 'package:cv_pro/features/builder/widgets/editor_fields.dart';
import 'package:cv_pro/features/export/pdf_export_service.dart';
import 'package:cv_pro/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The builder edits thirty section keys with five editor shapes and twelve
/// record descriptions. These tests hold that arrangement together: a section
/// without an editor, a field whose reader and writer disagree, or a record
/// type that cannot be created would all be invisible until a user hit them.
void main() {
  final AppLocalizations l10n = AppLocalizations.ofCode('en');

  group('section mapping', () {
    test('every section has a title and an editor shape', () {
      for (final SectionKey key in SectionKey.values) {
        expect(sectionTitle(key, l10n), isNotEmpty, reason: key.id);
        expect(sectionHint(key, l10n), isNotEmpty, reason: key.id);
      }
    });

    test('every record section has a description', () {
      final List<SectionKey> recordSections = SectionKey.values
          .where((SectionKey k) => formKindFor(k) == SectionFormKind.entries)
          .toList(growable: false);

      // The builder offers entries for exactly these; a new collection section
      // must be added to entrySpecFor rather than rendering an empty pane.
      expect(recordSections, isNotEmpty);
      for (final SectionKey key in recordSections) {
        expect(entrySpecFor(key, l10n), isNotNull, reason: key.id);
      }
    });

    test('non-record sections have no record description', () {
      for (final SectionKey key in <SectionKey>[
        SectionKey.personal,
        SectionKey.summary,
        SectionKey.interests,
        SectionKey.custom,
      ]) {
        expect(entrySpecFor(key, l10n), isNull, reason: key.id);
      }
    });
  });

  group('narrative sections', () {
    test('a written body is read back from the right field', () {
      ResumeContent content = ResumeContent.empty;
      for (final SectionKey key in <SectionKey>[
        SectionKey.summary,
        SectionKey.additionalInfo,
        SectionKey.militaryService,
        SectionKey.drivingLicence,
      ]) {
        content = withNarrative(content, key, 'text for ${key.id}');
        expect(narrativeOf(content, key), 'text for ${key.id}');
        expect(content.hasContentFor(key), isTrue, reason: key.id);
      }
      // Each body lands in its own field: writing four narratives must not
      // leave three of them overwriting each other.
      expect(content.personal.summary, 'text for summary');
      expect(content.additionalInfo, 'text for additional_info');
      expect(content.militaryService, 'text for military_service');
      expect(content.drivingLicence, 'text for driving_licence');
    });
  });

  group('chip sections', () {
    test('short string lists round-trip', () {
      ResumeContent content = ResumeContent.empty;
      for (final SectionKey key in <SectionKey>[
        SectionKey.interests,
        SectionKey.researchInterests,
        SectionKey.digitalSkills,
        SectionKey.keySkills,
      ]) {
        content = withStringList(content, key, <String>['a', 'b']);
        expect(stringListOf(content, key), <String>['a', 'b'], reason: key.id);
      }
    });

    test('a non-chip section has no string list', () {
      expect(stringListOf(ResumeContent.empty, SectionKey.summary), isNull);
    });
  });

  group('record descriptions', () {
    test('every field reader and writer agree', () {
      for (final SectionKey key in SectionKey.values) {
        final EntrySpec? spec = entrySpecFor(key, l10n);
        if (spec == null) continue;

        Object entry = spec.create();
        for (final EntryField field in spec.fields) {
          switch (field) {
            case TextEntryField f:
              final String before = f.read(entry);
              entry = f.write(entry, '$before written');
              expect(f.read(entry), contains('written'), reason: '${key.id}/${f.label}');
            case LinesEntryField f:
              entry = f.write(entry, <String>['first', 'second']);
              expect(f.read(entry), <String>['first', 'second'],
                  reason: '${key.id}/${f.label}');
            case DateEntryField f:
              const YearMonth date = YearMonth(2024, 6);
              entry = f.write(entry, date);
              expect(f.read(entry)?.year, 2024, reason: '${key.id}/${f.label}');
              entry = f.write(entry, null);
              expect(f.read(entry), isNull, reason: '${key.id}/${f.label}');
            case SwitchEntryField f:
              entry = f.write(entry, !f.read(entry));
              expect(f.read(entry), isTrue, reason: '${key.id}/${f.label}');
            case ChoiceEntryField f:
              expect(f.values, isNotEmpty, reason: '${key.id}/${f.label}');
              final Object? second = f.values.length > 1 ? f.values[1] : f.values.first;
              entry = f.write(entry, second);
              expect(f.read(entry), second, reason: '${key.id}/${f.label}');
          }
        }
      }
    });

    test('a created record is written into the document it belongs to', () {
      for (final SectionKey key in SectionKey.values) {
        final EntrySpec? spec = entrySpecFor(key, l10n);
        if (spec == null) continue;

        final List<Object> before = spec.read(ResumeContent.empty);
        expect(before, isEmpty, reason: '${key.id} starts empty');

        final ResumeContent after =
            spec.write(ResumeContent.empty, <Object>[spec.create()]);
        expect(spec.read(after).length, 1, reason: '${key.id} kept the record');
      }
    });

    test('the same record type is shared by the sections that use it', () {
      // Awards and achievements are one collection in the model, so adding
      // one must be visible from both sections rather than from neither.
      final ResumeContent content = ResumeContent.empty.copyWith(
        awards: const <Award>[Award(id: 'a', title: 'Prize')],
      );
      expect(content.hasContentFor(SectionKey.awards), isTrue);
      expect(content.hasContentFor(SectionKey.achievements), isTrue);
    });
  });

  group('bullet parsing', () {
    test('strips pasted bullets and drops blank lines', () {
      expect(
        EditorLinesField.parse('- led the migration\n\n• cut build time\nplain line'),
        <String>['led the migration', 'cut build time', 'plain line'],
      );
    });

    test('keeps a mid-sentence dash', () {
      expect(
        EditorLinesField.parse('reduced cost by 30% — permanently'),
        <String>['reduced cost by 30% — permanently'],
      );
    });
  });

  group('export file names', () {
    const PdfExportService service = PdfExportService();

    test('uses the candidate name, not the database id', () {
      final Resume resume = _resume(fullName: 'Sara Ahmadi', title: 'My CV');
      expect(service.fileNameFor(resume), 'Sara_Ahmadi.pdf');
    });

    test('removes characters a file system rejects', () {
      final Resume resume = _resume(fullName: 'Ana /López\\: 2', title: 'CV');
      expect(service.fileNameFor(resume), 'Ana_López_2.pdf');
    });

    test('falls back to the document title, then to CV', () {
      expect(
        service.fileNameFor(_resume(fullName: '', title: 'Backend CV')),
        'Backend_CV.pdf',
      );
      expect(service.fileNameFor(_resume(fullName: '', title: '  ')), 'CV.pdf');
    });
  });
}

/// A minimal document: the name is what the export file name is built from,
/// so the name is given as one string and split the way the model stores it.
Resume _resume({required String fullName, required String title}) {
  final List<String> parts = fullName
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  return Resume(
    id: 'r1',
    title: title,
    region: RegionCode.international,
    cvType: CvType.professionalCv,
    paperSize: PaperSize.a4,
    content: ResumeContent.empty.copyWith(
      personal: ResumeContent.empty.personal.copyWith(
        firstName: parts.isEmpty ? '' : parts.first,
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      ),
    ),
  );
}
