import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/analysis_report.dart';
import '../../domain/entities/job_description.dart';
import '../../domain/entities/resume.dart';
import '../../domain/entities/resume_content.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/enums/section_key.dart';
import '../local/app_database.dart';

/// A saved version of a CV, in domain terms.
///
/// The database rows are never handed to the UI: a generated Drift row is an
/// implementation detail, and exposing it would make every screen depend on
/// the schema.
class ResumeVersionInfo {
  const ResumeVersionInfo({
    required this.id,
    required this.resumeId,
    required this.label,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String resumeId;
  final String label;
  final String note;
  final DateTime createdAt;
}

/// A file the user has exported, so "Recent" can offer to open or share it
/// again without regenerating it.
class ExportedDocumentInfo {
  const ExportedDocumentInfo({
    required this.id,
    required this.resumeId,
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.pageCount,
    required this.paperSize,
    required this.byteSize,
    required this.createdAt,
  });

  final String id;
  final String? resumeId;
  final String fileName;
  final String filePath;
  final String format;
  final int pageCount;
  final String paperSize;
  final int byteSize;
  final DateTime createdAt;
}

/// One entry of the analysis history list.
class AnalysisRecordInfo {
  const AnalysisRecordInfo({
    required this.id,
    required this.totalScore,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final int totalScore;
  final String source;
  final DateTime createdAt;
}

/// One saved job advert.
class JobDescriptionInfo {
  const JobDescriptionInfo({
    required this.id,
    required this.jobTitle,
    required this.company,
    required this.createdAt,
  });

  final String id;
  final String jobTitle;
  final String company;
  final DateTime createdAt;
}

/// Everything a CV library can do, expressed in domain terms.
///
/// The UI depends on this interface and never on Drift, which is what keeps
/// the local database an implementation detail: a future cloud sync would add
/// a second implementation rather than touching a single screen.
abstract interface class ResumeRepository {
  /// Library listing, most recently opened first. Archived CVs are excluded
  /// unless asked for.
  Stream<List<Resume>> watchAll({bool includeArchived = false});

  /// The Master Profile, if the user created one.
  Stream<Resume?> watchMasterProfile();

  Future<Resume?> findById(String id);

  Future<Resume> create({
    required String title,
    required RegionCode region,
    required CvType cvType,
    Industry industry = Industry.other,
    SeniorityLevel seniority = SeniorityLevel.mid,
    String languageCode = 'en',
    String templateId = 'professional',
    PaperSize paperSize = PaperSize.a4,
    List<SectionKey> sectionOrder = const <SectionKey>[],
    ResumeContent? content,
    bool isMasterProfile = false,
  });

  /// Duplicates a document: the content travels, the history does not.
  Future<Resume> duplicate(String id, {String? title});

  Future<void> save(Resume resume);

  /// Soft delete, so an accidental deletion is recoverable.
  Future<void> archive(String id);

  Future<void> restore(String id);

  /// Hard delete, cascading to versions, analyses and job matches.
  Future<void> delete(String id);

  Future<void> touch(String id);

  // ── versions ─────────────────────────────────────────────────────────────
  Stream<List<ResumeVersionInfo>> watchVersions(String resumeId);

  Future<ResumeVersionInfo> snapshot(
    Resume resume, {
    required String label,
    String note = '',
  });

  /// Restores an earlier version.
  ///
  /// The current state is snapshotted first, so restoring is itself
  /// undoable — a version history that can silently destroy work is worse
  /// than no history at all.
  Future<void> restoreVersion(String resumeId, String versionId);

  Future<void> deleteVersion(String versionId);

  // ── analyses and job adverts ─────────────────────────────────────────────
  Future<void> saveAnalysis(String resumeId, AnalysisReport report);

  Future<AnalysisReport?> latestAnalysis(String resumeId);

  Stream<List<AnalysisRecordInfo>> watchAnalysisHistory(String resumeId);

  Future<void> saveJobDescription(JobDescription advert);

  Stream<List<JobDescriptionInfo>> watchJobDescriptions({String? resumeId});

  // ── exports ──────────────────────────────────────────────────────────────
  Future<void> recordExport({
    required String resumeId,
    required String fileName,
    required String filePath,
    required String format,
    required int byteSize,
    required int pageCount,
    required String paperSize,
  });

  Stream<List<ExportedDocumentInfo>> watchExports();

  Future<void> forgetExport(String id);

  // ── maintenance ──────────────────────────────────────────────────────────
  /// Deletes every CV, version, analysis and export record. Backs the
  /// "Delete all data" action the brief requires to be complete and single.
  Future<void> deleteEverything();

  /// The whole library as JSON, for the backup export.
  Future<Map<String, dynamic>> exportLibrary();

  /// Merges a previously exported library back in. Existing ids are replaced.
  Future<int> importLibrary(Map<String, dynamic> payload);
}

/// Drift-backed implementation.
class DriftResumeRepository implements ResumeRepository {
  DriftResumeRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // ── reading ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Resume>> watchAll({bool includeArchived = false}) {
    final SimpleSelectStatement<$ResumesTable, ResumeRow> query =
        _db.select(_db.resumes);
    if (!includeArchived) {
      query.where((Resumes t) => t.archived.equals(false));
    }
    query.orderBy(<OrderClauseGenerator<$ResumesTable>>[
      (Resumes t) => OrderingTerm.desc(t.lastOpenedAt),
      (Resumes t) => OrderingTerm.desc(t.updatedAt),
    ]);
    return query.watch().map(
          (List<ResumeRow> rows) => rows
              .map((ResumeRow row) =>
                  ResumeMapper.fromRow(row, ResumeMapper.contentFromJson(row.contentJson)))
              .toList(growable: false),
        );
  }

  @override
  Stream<Resume?> watchMasterProfile() {
    final SimpleSelectStatement<$ResumesTable, ResumeRow> query =
        _db.select(_db.resumes)
          ..where((Resumes t) => t.isMasterProfile.equals(true))
          ..limit(1);
    return query.watchSingleOrNull().map(
          (ResumeRow? row) => row == null
              ? null
              : ResumeMapper.fromRow(row, ResumeMapper.contentFromJson(row.contentJson)),
        );
  }

  @override
  Future<Resume?> findById(String id) async {
    final ResumeRow? row = await (_db.select(_db.resumes)
          ..where((Resumes t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return ResumeMapper.fromRow(row, ResumeMapper.contentFromJson(row.contentJson));
  }

  // ── writing ──────────────────────────────────────────────────────────────

  @override
  Future<Resume> create({
    required String title,
    required RegionCode region,
    required CvType cvType,
    Industry industry = Industry.other,
    SeniorityLevel seniority = SeniorityLevel.mid,
    String languageCode = 'en',
    String templateId = 'professional',
    PaperSize paperSize = PaperSize.a4,
    List<SectionKey> sectionOrder = const <SectionKey>[],
    ResumeContent? content,
    bool isMasterProfile = false,
  }) async {
    final DateTime now = DateTime.now();
    final Resume resume = Resume(
      id: _uuid.v4(),
      title: title,
      isMasterProfile: isMasterProfile,
      region: region,
      cvType: cvType,
      industry: industry,
      seniority: seniority,
      languageCode: languageCode,
      templateId: templateId,
      paperSize: paperSize,
      sectionOrder: sectionOrder,
      content: content ?? ResumeContent.empty,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
    await _db.into(_db.resumes).insert(ResumeMapper.toCompanion(resume));
    return resume;
  }

  @override
  Future<Resume> duplicate(String id, {String? title}) async {
    final Resume? source = await findById(id);
    if (source == null) {
      throw StateError('No CV with id $id');
    }
    final DateTime now = DateTime.now();
    // Built explicitly rather than with copyWith, because a copy is a new
    // document with a new identity — not the same document with edits.
    final Resume copy = Resume(
      id: _uuid.v4(),
      title: title ?? '${source.title} (copy)',
      isMasterProfile: false,
      region: source.region,
      cvType: source.cvType,
      industry: source.industry,
      seniority: source.seniority,
      languageCode: source.languageCode,
      templateId: source.templateId,
      accentColorHex: source.accentColorHex,
      fontFamily: source.fontFamily,
      paperSize: source.paperSize,
      sectionOrder: source.sectionOrder,
      hiddenSections: source.hiddenSections,
      customSectionTitles: source.customSectionTitles,
      baseFontSize: source.baseFontSize,
      content: source.content,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
    await _db.into(_db.resumes).insert(ResumeMapper.toCompanion(copy));
    return copy;
  }

  @override
  Future<void> save(Resume resume) async {
    final DateTime now = DateTime.now();
    final Resume withTimestamps = Resume(
      id: resume.id,
      title: resume.title,
      isMasterProfile: resume.isMasterProfile,
      region: resume.region,
      cvType: resume.cvType,
      industry: resume.industry,
      seniority: resume.seniority,
      languageCode: resume.languageCode,
      templateId: resume.templateId,
      accentColorHex: resume.accentColorHex,
      fontFamily: resume.fontFamily,
      paperSize: resume.paperSize,
      sectionOrder: resume.sectionOrder,
      hiddenSections: resume.hiddenSections,
      customSectionTitles: resume.customSectionTitles,
      baseFontSize: resume.baseFontSize,
      content: resume.content,
      createdAt: resume.createdAt ?? now,
      updatedAt: now,
      lastOpenedAt: resume.lastOpenedAt,
      archived: resume.archived,
    );
    await _db
        .into(_db.resumes)
        .insertOnConflictUpdate(ResumeMapper.toCompanion(withTimestamps));
  }

  @override
  Future<void> archive(String id) => (_db.update(_db.resumes)
        ..where((Resumes t) => t.id.equals(id)))
      .write(ResumesCompanion(
    archived: const Value<bool>(true),
    updatedAt: Value<DateTime>(DateTime.now()),
  ));

  @override
  Future<void> restore(String id) => (_db.update(_db.resumes)
        ..where((Resumes t) => t.id.equals(id)))
      .write(const ResumesCompanion(archived: Value<bool>(false)));

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.resumes)..where((Resumes t) => t.id.equals(id))).go();
  }

  @override
  Future<void> touch(String id) => (_db.update(_db.resumes)
        ..where((Resumes t) => t.id.equals(id)))
      .write(ResumesCompanion(lastOpenedAt: Value<DateTime>(DateTime.now())));

  // ── versions ─────────────────────────────────────────────────────────────

  @override
  Stream<List<ResumeVersionInfo>> watchVersions(String resumeId) =>
      (_db.select(_db.resumeVersions)
            ..where((ResumeVersions t) => t.resumeId.equals(resumeId))
            ..orderBy(<OrderClauseGenerator<$ResumeVersionsTable>>[
              (ResumeVersions t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch()
          .map((List<ResumeVersionRow> rows) => rows
              .map((ResumeVersionRow row) => ResumeVersionInfo(
                    id: row.id,
                    resumeId: row.resumeId,
                    label: row.label,
                    note: row.note,
                    createdAt: row.createdAt,
                  ))
              .toList(growable: false));

  @override
  Future<ResumeVersionInfo> snapshot(
    Resume resume, {
    required String label,
    String note = '',
  }) async {
    final ResumeVersionInfo info = ResumeVersionInfo(
      id: _uuid.v4(),
      resumeId: resume.id,
      label: label,
      note: note,
      createdAt: DateTime.now(),
    );
    await _db.into(_db.resumeVersions).insert(
          ResumeVersionsCompanion.insert(
            id: info.id,
            resumeId: resume.id,
            label: label,
            note: Value<String>(note),
            contentJson: jsonEncode(resume.content.toJson()),
            metadataJson: Value<String>(jsonEncode(<String, dynamic>{
              'title': resume.title,
              'templateId': resume.templateId,
              'paperSize': resume.paperSize.id,
              'region': resume.region.id,
              'cvType': resume.cvType.id,
              'sectionOrder':
                  resume.sectionOrder.map((SectionKey k) => k.id).toList(),
            })),
            createdAt: info.createdAt,
          ),
        );
    return info;
  }

  @override
  Future<void> restoreVersion(String resumeId, String versionId) async {
    final ResumeVersionRow? version = await (_db.select(_db.resumeVersions)
          ..where((ResumeVersions t) => t.id.equals(versionId)))
        .getSingleOrNull();
    if (version == null) return;

    final Resume? current = await findById(resumeId);
    if (current == null) return;

    await snapshot(
      current,
      label: 'Before restore',
      note: 'Automatic snapshot taken when an earlier version was restored.',
    );

    final Object? decoded = jsonDecode(version.contentJson);
    final ResumeContent restored = decoded is Map<String, dynamic>
        ? ResumeContent.fromJson(decoded)
        : ResumeContent.empty;

    await save(current.copyWith(content: restored));
  }

  @override
  Future<void> deleteVersion(String versionId) =>
      (_db.delete(_db.resumeVersions)..where((ResumeVersions t) => t.id.equals(versionId)))
          .go();

  // ── analyses ─────────────────────────────────────────────────────────────

  @override
  Future<void> saveAnalysis(String resumeId, AnalysisReport report) async {
    await _db.into(_db.analysisRecords).insert(
          AnalysisRecordsCompanion.insert(
            id: report.id.isEmpty ? _uuid.v4() : report.id,
            resumeId: resumeId,
            totalScore: report.totalScore,
            source: Value<String>(report.source.id),
            payloadJson: jsonEncode(report.toJson()),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<AnalysisReport?> latestAnalysis(String resumeId) async {
    final AnalysisRecordRow? row = await (_db.select(_db.analysisRecords)
          ..where((AnalysisRecords t) => t.resumeId.equals(resumeId))
          ..orderBy(<OrderClauseGenerator<$AnalysisRecordsTable>>[
            (AnalysisRecords t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : AnalysisMapper.fromRow(row);
  }

  @override
  Stream<List<AnalysisRecordInfo>> watchAnalysisHistory(String resumeId) =>
      (_db.select(_db.analysisRecords)
            ..where((AnalysisRecords t) => t.resumeId.equals(resumeId))
            ..orderBy(<OrderClauseGenerator<$AnalysisRecordsTable>>[
              (AnalysisRecords t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch()
          .map((List<AnalysisRecordRow> rows) => rows
              .map((AnalysisRecordRow row) => AnalysisRecordInfo(
                    id: row.id,
                    totalScore: row.totalScore,
                    source: row.source,
                    createdAt: row.createdAt,
                  ))
              .toList(growable: false));

  @override
  Future<void> saveJobDescription(JobDescription advert) async {
    await _db.into(_db.jobDescriptions).insert(
          JobDescriptionsCompanion.insert(
            id: advert.id.isEmpty ? _uuid.v4() : advert.id,
            rawText: advert.rawText,
            resumeId: Value<String?>(advert.resumeId),
            jobTitle: Value<String>(advert.jobTitle),
            company: Value<String>(advert.company),
            extractedJson: Value<String>(jsonEncode(advert.requirements.toJson())),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Stream<List<JobDescriptionInfo>> watchJobDescriptions({String? resumeId}) {
    final SimpleSelectStatement<$JobDescriptionsTable, JobDescriptionRow> query =
        _db.select(_db.jobDescriptions);
    if (resumeId != null) {
      query.where((JobDescriptions t) => t.resumeId.equals(resumeId));
    }
    query.orderBy(<OrderClauseGenerator<$JobDescriptionsTable>>[
      (JobDescriptions t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch().map((List<JobDescriptionRow> rows) => rows
        .map((JobDescriptionRow row) => JobDescriptionInfo(
              id: row.id,
              jobTitle: row.jobTitle,
              company: row.company,
              createdAt: row.createdAt,
            ))
        .toList(growable: false));
  }

  // ── exports ──────────────────────────────────────────────────────────────

  @override
  Future<void> recordExport({
    required String resumeId,
    required String fileName,
    required String filePath,
    required String format,
    required int byteSize,
    required int pageCount,
    required String paperSize,
  }) async {
    await _db.into(_db.exportedDocuments).insert(
          ExportedDocumentsCompanion.insert(
            id: _uuid.v4(),
            fileName: fileName,
            filePath: filePath,
            resumeId: Value<String?>(resumeId),
            format: Value<String>(format),
            byteSize: Value<int>(byteSize),
            pageCount: Value<int>(pageCount),
            paperSize: Value<String>(paperSize),
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Stream<List<ExportedDocumentInfo>> watchExports() =>
      (_db.select(_db.exportedDocuments)
            ..orderBy(<OrderClauseGenerator<$ExportedDocumentsTable>>[
              (ExportedDocuments t) => OrderingTerm.desc(t.createdAt),
            ])
            ..limit(50))
          .watch()
          .map((List<ExportedDocumentRow> rows) => rows
              .map((ExportedDocumentRow row) => ExportedDocumentInfo(
                    id: row.id,
                    resumeId: row.resumeId,
                    fileName: row.fileName,
                    filePath: row.filePath,
                    format: row.format,
                    pageCount: row.pageCount,
                    paperSize: row.paperSize,
                    byteSize: row.byteSize,
                    createdAt: row.createdAt,
                  ))
              .toList(growable: false));

  @override
  Future<void> forgetExport(String id) =>
      (_db.delete(_db.exportedDocuments)..where((ExportedDocuments t) => t.id.equals(id)))
          .go();

  // ── maintenance ──────────────────────────────────────────────────────────

  @override
  Future<void> deleteEverything() async {
    await _db.transaction(() async {
      await _db.delete(_db.analysisRecords).go();
      await _db.delete(_db.jobDescriptions).go();
      await _db.delete(_db.exportedDocuments).go();
      await _db.delete(_db.resumeVersions).go();
      await _db.delete(_db.resumes).go();
    });
  }

  @override
  Future<Map<String, dynamic>> exportLibrary() async {
    final List<ResumeRow> resumes = await _db.select(_db.resumes).get();
    final List<ResumeVersionRow> versions =
        await _db.select(_db.resumeVersions).get();
    final List<JobDescriptionRow> adverts =
        await _db.select(_db.jobDescriptions).get();

    return <String, dynamic>{
      'format': 'cvpro.library',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      // The row's own columns already hold the document as JSON, so the
      // backup is a copy rather than a re-serialisation that could drift from
      // the schema.
      'resumes': resumes
          .map((ResumeRow row) => <String, dynamic>{
                'id': row.id,
                'title': row.title,
                'isMasterProfile': row.isMasterProfile,
                'region': row.region,
                'cvType': row.cvType,
                'industry': row.industry,
                'seniority': row.seniority,
                'languageCode': row.languageCode,
                'templateId': row.templateId,
                'paperSize': row.paperSize,
                'accentColorHex': row.accentColorHex,
                'fontFamily': row.fontFamily,
                'baseFontSize': row.baseFontSize,
                'sectionOrder': jsonDecode(row.sectionOrderJson),
                'hiddenSections': jsonDecode(row.hiddenSectionsJson),
                'content': jsonDecode(row.contentJson),
                'archived': row.archived,
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
              })
          .toList(growable: false),
      'versions': versions
          .map((ResumeVersionRow v) => <String, dynamic>{
                'id': v.id,
                'resumeId': v.resumeId,
                'label': v.label,
                'note': v.note,
                'content': jsonDecode(v.contentJson),
                'createdAt': v.createdAt.toIso8601String(),
              })
          .toList(growable: false),
      'jobDescriptions': adverts
          .map((JobDescriptionRow row) => <String, dynamic>{
                'id': row.id,
                'resumeId': row.resumeId,
                'jobTitle': row.jobTitle,
                'company': row.company,
                'rawText': row.rawText,
                'requirements': jsonDecode(row.extractedJson),
              })
          .toList(growable: false),
    };
  }

  @override
  Future<int> importLibrary(Map<String, dynamic> payload) async {
    final Object? resumes = payload['resumes'];
    if (resumes is! List) return 0;

    int imported = 0;
    await _db.transaction(() async {
      for (final Object? entry in resumes) {
        if (entry is! Map) continue;
        final Map<String, dynamic> map = Map<String, dynamic>.from(entry);
        final String? id = map['id'] as String?;
        final String? title = map['title'] as String?;
        if (id == null || title == null) continue;

        final Object? content = map['content'];
        final Resume resume = Resume(
          id: id,
          title: title,
          isMasterProfile: map['isMasterProfile'] as bool? ?? false,
          region: RegionCode.fromId(map['region'] as String? ?? 'international'),
          cvType: CvType.fromId(map['cvType'] as String? ?? 'professional_cv'),
          industry: Industry.fromId(map['industry'] as String? ?? 'other'),
          seniority: SeniorityLevel.fromId(map['seniority'] as String? ?? 'mid'),
          languageCode: map['languageCode'] as String? ?? 'en',
          templateId: map['templateId'] as String? ?? 'professional',
          paperSize: PaperSize.fromId(map['paperSize'] as String? ?? 'a4'),
          sectionOrder: _sections(map['sectionOrder']),
          hiddenSections: _sections(map['hiddenSections']),
          content: content is Map<String, dynamic>
              ? ResumeContent.fromJson(content)
              : ResumeContent.empty,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _db
            .into(_db.resumes)
            .insertOnConflictUpdate(ResumeMapper.toCompanion(resume));
        imported++;
      }
    });
    return imported;
  }

  static List<SectionKey> _sections(Object? value) {
    if (value is! List) return const <SectionKey>[];
    return value
        .whereType<String>()
        .map(SectionKey.fromId)
        .toList(growable: false);
  }
}
