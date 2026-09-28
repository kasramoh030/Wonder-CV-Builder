import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/analysis_report.dart';
import '../../domain/entities/job_description.dart';
import '../../domain/entities/resume.dart';
import '../../domain/entities/resume_content.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/enums/section_key.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tables
// ─────────────────────────────────────────────────────────────────────────────

/// One row per CV, including the Master Profile.
///
/// Content is stored as a single JSON document rather than being normalised
/// across a dozen tables. That is a deliberate trade-off:
///
/// * A CV is always read, edited and written **as a whole**, so there is no
///   query that would benefit from normalisation.
/// * Duplicating a CV, snapshotting a version and exporting a backup all
///   become a single row copy instead of a graph traversal.
/// * The document schema can gain a section without a database migration,
///   which matters when the app must keep working on a device that has been
///   offline for a year.
///
/// The columns that *are* projected out (title, region, type, timestamps)
/// are exactly the ones the dashboard sorts, filters and displays.
class Resumes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get isMasterProfile =>
      boolean().withDefault(const Constant(false))();

  TextColumn get region => text().withDefault(const Constant('international'))();
  TextColumn get cvType => text().withDefault(const Constant('professional_cv'))();
  TextColumn get industry => text().withDefault(const Constant('other'))();
  TextColumn get seniority => text().withDefault(const Constant('mid'))();
  TextColumn get languageCode => text().withDefault(const Constant('en'))();

  TextColumn get templateId => text().withDefault(const Constant('professional'))();
  TextColumn get accentColorHex => text().nullable()();
  TextColumn get fontFamily => text().nullable()();
  TextColumn get paperSize => text().withDefault(const Constant('a4'))();
  RealColumn get baseFontSize => real().withDefault(const Constant(10.5))();

  TextColumn get sectionOrderJson => text().withDefault(const Constant('[]'))();
  TextColumn get hiddenSectionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get customSectionTitlesJson =>
      text().withDefault(const Constant('{}'))();

  TextColumn get contentJson => text().withDefault(const Constant('{}'))();

  /// Version of the *document* schema in [contentJson]. Bumped when the
  /// shape of `ResumeContent` changes so the mapper can upgrade old rows.
  IntColumn get documentVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Point-in-time snapshots of a CV, so an experiment never destroys work.
class ResumeVersions extends Table {
  TextColumn get id => text()();
  TextColumn get resumeId => text().references(Resumes, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();

  /// Optional user note explaining why the snapshot was taken.
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get contentJson => text()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Records of every PDF the user has produced, powering "Recent documents".
class ExportedDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get resumeId => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get paperSize => text().withDefault(const Constant('a4'))();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();

  /// `pdf` or `json`. Kept generic so future export formats need no schema
  /// change.
  TextColumn get format => text().withDefault(const Constant('pdf'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Saved analyser output, so a report survives app restarts.
class AnalysisRecords extends Table {
  TextColumn get id => text()();
  TextColumn get resumeId => text().references(Resumes, #id, onDelete: KeyAction.cascade)();
  IntColumn get totalScore => integer()();

  /// `offline` or `online`.
  TextColumn get source => text().withDefault(const Constant('offline'))();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Pasted job adverts and the requirements extracted from them.
class JobDescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get resumeId => text().nullable()();
  TextColumn get jobTitle => text().withDefault(const Constant(''))();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get rawText => text()();

  /// JSON of the extracted requirement sets.
  TextColumn get extractedJson => text().withDefault(const Constant('{}'))();

  /// SHA-256 of [rawText]; lets the app skip re-analysis of an unchanged
  /// advert.
  TextColumn get contentHash => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

// ─────────────────────────────────────────────────────────────────────────────
// Type converters
// ─────────────────────────────────────────────────────────────────────────────

class RegionCodeConverter extends TypeConverter<RegionCode, String> {
  const RegionCodeConverter();
  @override
  RegionCode fromSql(String fromDb) => RegionCode.fromId(fromDb);
  @override
  String toSql(RegionCode value) => value.id;
}

class CvTypeConverter extends TypeConverter<CvType, String> {
  const CvTypeConverter();
  @override
  CvType fromSql(String fromDb) => CvType.fromId(fromDb);
  @override
  String toSql(CvType value) => value.id;
}

class IndustryConverter extends TypeConverter<Industry, String> {
  const IndustryConverter();
  @override
  Industry fromSql(String fromDb) => Industry.fromId(fromDb);
  @override
  String toSql(Industry value) => value.id;
}

/// JSON-encodes a list of [SectionKey] into one column.
class SectionKeyListConverter extends TypeConverter<List<SectionKey>, String> {
  const SectionKeyListConverter();
  @override
  List<SectionKey> fromSql(String fromDb) {
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is! List) return const <SectionKey>[];
    return decoded
        .whereType<String>()
        .map(SectionKey.fromId)
        .toList(growable: false);
  }

  @override
  String toSql(List<SectionKey> value) =>
      jsonEncode(value.map((SectionKey k) => k.id).toList(growable: false));
}

class PaperSizeConverter extends TypeConverter<PaperSize, String> {
  const PaperSizeConverter();
  @override
  PaperSize fromSql(String fromDb) => PaperSize.fromId(fromDb);
  @override
  String toSql(PaperSize value) => value.id;
}

// ─────────────────────────────────────────────────────────────────────────────
// Database
// ─────────────────────────────────────────────────────────────────────────────

/// The single SQLite database behind every offline feature.
///
/// Bumping [schemaVersion] requires an entry in [migration]; drift's test
/// harness (`drift_dev schema dump`) is used in CI to catch a forgotten
/// migration before it reaches a user's device.
@DriftDatabase(
  tables: <Type>[
    Resumes,
    ResumeVersions,
    ExportedDocuments,
    AnalysisRecords,
    JobDescriptions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Test constructor — accepts an already-built executor so tests can run
  /// against an in-memory database.
  AppDatabase.forTesting(super.executor);

  static QueryExecutor _open() => driftDatabase(name: 'cv_pro');

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // Referential integrity is not optional: deleting a CV must delete
          // its versions, analyses and job matches in the same transaction.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Row ↔ domain mapping
// ─────────────────────────────────────────────────────────────────────────────

/// Translates between the [Resumes] row and the [Resume] domain entity.
///
/// Kept as top-level helpers rather than extension methods so the mapping is
/// trivially testable without instantiating a database.
abstract final class ResumeMapper {
  static Resume fromRow(ResumeRow row, ResumeContent content) => Resume(
        id: row.id,
        title: row.title,
        isMasterProfile: row.isMasterProfile,
        region: RegionCode.fromId(row.region),
        cvType: CvType.fromId(row.cvType),
        industry: Industry.fromId(row.industry),
        seniority: SeniorityLevel.fromId(row.seniority),
        languageCode: row.languageCode,
        templateId: row.templateId,
        accentColorHex: row.accentColorHex,
        fontFamily: row.fontFamily,
        paperSize: PaperSize.fromId(row.paperSize),
        sectionOrder: const SectionKeyListConverter().fromSql(row.sectionOrderJson),
        hiddenSections:
            const SectionKeyListConverter().fromSql(row.hiddenSectionsJson),
        customSectionTitles: _decodeStringMap(row.customSectionTitlesJson),
        baseFontSize: row.baseFontSize,
        content: content,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        lastOpenedAt: row.lastOpenedAt,
        archived: row.archived,
      );

  static ResumeContent contentFromJson(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return ResumeContent.empty;
    return ResumeContent.fromJson(decoded);
  }

  static ResumesCompanion toCompanion(Resume resume, {bool insert = false}) {
    final DateTime now = DateTime.now();
    return ResumesCompanion(
      id: Value<String>(resume.id),
      title: Value<String>(resume.title),
      isMasterProfile: Value<bool>(resume.isMasterProfile),
      region: Value<String>(resume.region.id),
      cvType: Value<String>(resume.cvType.id),
      industry: Value<String>(resume.industry.id),
      seniority: Value<String>(resume.seniority.id),
      languageCode: Value<String>(resume.languageCode),
      templateId: Value<String>(resume.templateId),
      accentColorHex: Value<String?>(resume.accentColorHex),
      fontFamily: Value<String?>(resume.fontFamily),
      paperSize: Value<String>(resume.paperSize.id),
      baseFontSize: Value<double>(resume.baseFontSize),
      sectionOrderJson: Value<String>(
        const SectionKeyListConverter().toSql(resume.sectionOrder),
      ),
      hiddenSectionsJson: Value<String>(
        const SectionKeyListConverter().toSql(resume.hiddenSections),
      ),
      customSectionTitlesJson: Value<String>(
        jsonEncode(resume.customSectionTitles),
      ),
      contentJson: Value<String>(jsonEncode(resume.content.toJson())),
      createdAt: Value<DateTime>(resume.createdAt ?? now),
      updatedAt: Value<DateTime>(resume.updatedAt ?? now),
      lastOpenedAt: Value<DateTime?>(resume.lastOpenedAt),
      archived: Value<bool>(resume.archived),
    );
  }

  static Map<String, String> _decodeStringMap(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map) return const <String, String>{};
    return decoded.map(
      (Object? key, Object? value) =>
          MapEntry<String, String>(key.toString(), value.toString()),
    );
  }
}

/// Row ↔ domain mapping for the analyser history table.
abstract final class AnalysisMapper {
  static AnalysisReport fromRow(AnalysisRecord row) {
    final Object? decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      return AnalysisReport.empty();
    }
    return AnalysisReport.fromJson(decoded);
  }
}

/// Row ↔ domain mapping for saved job adverts.
abstract final class JobDescriptionMapper {
  static JobDescription fromRow(JobDescriptionRow row) {
    final Object? decoded = jsonDecode(row.extractedJson);
    final Map<String, dynamic> extracted =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    return JobDescription.fromJson(<String, dynamic>{
      'id': row.id,
      'resumeId': row.resumeId,
      'jobTitle': row.jobTitle,
      'company': row.company,
      'rawText': row.rawText,
      'requirements': extracted,
      'createdAt': row.createdAt.toIso8601String(),
    });
  }
}
