import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Writes the whole library — every CV, version, saved advert, analysis and
/// export record — into one JSON file, and reads one back.
///
/// The destination is chosen by the user through the system picker rather than
/// fixed by the app. That is the whole point: the app's own directory is
/// private to it, so a backup written there is a backup the user cannot copy
/// off the phone, which is not a backup. The picker needs no storage
/// permission — Android's picker hands back a URI the user chose — so this
/// stays inside the app's one-permission rule (`docs/PERMISSIONS.md`).
///
/// The format is the repository's own `exportLibrary` payload, so the file can
/// be read back by `importLibrary` without a translation step that could drift.
class LibraryBackupService {
  const LibraryBackupService();

  /// The marker `ResumeRepository.importLibrary` looks for.
  static const String formatId = 'cvpro.library';

  /// The format version this build writes.
  static const int formatVersion = 1;

  /// `wonder-cv-backup-2026-09-29.json`.
  ///
  /// Dated rather than fixed, because a user who exports twice should end up
  /// with two files: an overwrite prompt in a file picker is a decision the
  /// user has no information to make, and the date is the information.
  String fileNameFor(DateTime now) {
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return 'wonder-cv-backup-${now.year}-$month-$day.json';
  }

  /// Pretty-printed, because a backup is also the only readable copy a user
  /// has if they ever want to see what the app stored about them. The cost is
  /// bytes; the benefit is a file a person can open.
  Uint8List encode(Map<String, dynamic> payload) => Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
      );

  /// Asks where to put the file and writes it there.
  ///
  /// Returns `true` when a file was saved, `false` when the user cancelled —
  /// cancelling is a normal outcome and not an error, so the caller shows a
  /// confirmation only in the first case.
  Future<bool> save({
    required Map<String, dynamic> payload,
    required DateTime now,
    String? dialogTitle,
  }) async {
    final Uri? target = await FilePicker.saveFile(
      fileName: fileNameFor(now),
      bytes: encode(payload),
      mimeType: 'application/json',
      dialogTitle: dialogTitle,
    );
    return target != null;
  }

  /// True when [payload] looks like a backup this app wrote.
  ///
  /// Checked before importing rather than after: a wrong file should produce a
  /// sentence, not a half-applied merge.
  static bool looksLikeBackup(Map<String, dynamic> payload) =>
      payload['format'] == formatId && payload['resumes'] is List;

  /// Reads a chosen file into a payload, or `null` when it is not one.
  ///
  /// Every way a file can be wrong lands on the same `null`: not UTF-8, not
  /// JSON, JSON that is not an object, an object that is not a backup, or a
  /// backup truncated mid-write by a device that ran out of power. The caller
  /// says one sentence about it and the user's library is untouched, which is
  /// the only acceptable outcome for a restore that half-worked.
  static Map<String, dynamic>? parse(Uint8List bytes) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      return looksLikeBackup(decoded) ? decoded : null;
    } on Object {
      return null;
    }
  }

  /// How many documents the payload carries, for the confirmation the user
  /// reads before anything is written. A count the user cannot verify is a
  /// count they will not read; this one comes from the file itself.
  static int documentCount(Map<String, dynamic> payload) {
    final Object? resumes = payload['resumes'];
    if (resumes is! List) return 0;
    // Entries without an id and a title are skipped by the importer, so they
    // must not be promised here either.
    return resumes
        .whereType<Map<Object?, Object?>>()
        .where((Map<Object?, Object?> row) =>
            row['id'] is String && row['title'] is String)
        .length;
  }

  /// Asks the user for a backup file and returns its payload.
  ///
  /// `null` covers both "the user changed their mind" and "that was not a
  /// backup", because the caller shows nothing for the first and a sentence
  /// for the second — and distinguishing them here would be guessing.
  Future<Map<String, dynamic>?> pickAndRead() async {
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final String? path = picked?.path;
    if (picked == null || path == null) return null;
    final File file = File(path);
    if (!file.existsSync()) return null;
    return parse(await file.readAsBytes());
  }
}
