import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/resume_repository.dart';

/// The "delete all data" action, in one place.
///
/// A wipe that only empties the database is a wipe that lies: the exports the
/// user generated are still readable in the app's documents directory, and the
/// file picker's cache still holds copies of whatever they imported. Both are
/// the user's data, so both go. Keeping the whole action here — rather than
/// spread between a button, a repository and a service — is what stops the
/// sentence on the confirmation dialog and the code that follows it from
/// drifting apart.
class DataWipeService {
  const DataWipeService();

  Future<void> wipe(ResumeRepository repository) async {
    final List<Future<void>> cleanup = <Future<void>>[
      repository.deleteEverything(),
      _deleteExports(),
      _clearPickerCache(),
    ];
    await Future.wait(cleanup);
  }

  /// Removes the generated PDFs.
  ///
  /// The `exports` directory holds only files this app wrote, so removing it
  /// whole is the honest reading of "delete all data" — the alternative,
  /// reading each path out of the database first, leaves behind any file whose
  /// record was already deleted.
  static Future<void> _deleteExports() async {
    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory exports = Directory('${documents.path}/exports');
      if (exports.existsSync()) {
        await exports.delete(recursive: true);
      }
    } on Object {
      // A file that will not delete is not a reason to keep the CVs: the
      // database half of the wipe must not be rolled back by a locked file.
      // The worst case is an orphaned PDF in a directory no other app can
      // read, and the user is told the data was deleted because it was.
    }
  }

  static Future<void> _clearPickerCache() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } on Object {
      // The platform cache is the picker's business; failing to clear it must
      // not fail the wipe.
    }
  }
}
