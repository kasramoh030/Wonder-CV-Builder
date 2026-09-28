import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/resume.dart';
import '../../domain/rules/regional_rule_engine.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import '../../pdf/resume_pdf_builder.dart';

/// Turns a document into PDF bytes, and gets those bytes to the user.
///
/// Everything here is local: the renderer needs no network, the photo is read
/// from the device, and the file is written to the app's own documents
/// directory before the system share sheet is offered it. Nothing about
/// exporting a CV leaves the device.
class PdfExportService {
  const PdfExportService();

  Future<ResumePdfResult> render({
    required Resume resume,
    required FormatPlan plan,
    required ResumeTemplate template,
    required AppLocalizations l10n,
  }) async {
    final Uint8List? photo = await _photoBytes(resume, plan);
    return const ResumePdfBuilder().build(
      ResumePdfRequest(
        resume: resume,
        plan: plan,
        template: template,
        l10n: l10n,
        photoBytes: photo,
      ),
    );
  }

  /// The file name offered to the share sheet and the browser.
  ///
  /// Built from the candidate's name so a recruiter sees "Sara_Ahmadi.pdf"
  /// rather than a database id, and sanitised because a name can legitimately
  /// contain characters a file system will not accept.
  String fileNameFor(Resume resume) {
    final String name = resume.content.personal.fullName.trim().isEmpty
        ? resume.title
        : resume.content.personal.fullName;
    final String safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final String base = safe.isEmpty ? 'CV' : safe;
    return '$base.pdf';
  }

  /// Writes the PDF into the app's documents directory.
  ///
  /// Returns the file so the UI can offer "Open" as well as "Share": a share
  /// sheet is the wrong destination for a user who simply wants to look at
  /// what they made.
  Future<File> save(ResumePdfResult result, String fileName) async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory exports = Directory('${documents.path}/exports');
    if (!exports.existsSync()) {
      await exports.create(recursive: true);
    }
    final File file = File('${exports.path}/$fileName');
    await file.writeAsBytes(result.bytes, flush: true);
    return file;
  }

  Future<void> share(ResumePdfResult result, String fileName) =>
      Printing.sharePdf(bytes: result.bytes, filename: fileName);

  Future<void> print(ResumePdfResult result, String fileName) =>
      Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => result.bytes,
        name: fileName,
      );

  /// Reads the chosen photo, if the plan prints one.
  ///
  /// A missing or unreadable file is not an error: the document is rendered
  /// without the photo and the renderer reports `pdf.photoMissing`, because
  /// losing an export over a deleted image would be worse than a CV without
  /// one. This is also why the path is validated here rather than trusted.
  Future<Uint8List?> _photoBytes(Resume resume, FormatPlan plan) async {
    // `photoPath` is nullable in the model — a document may simply have no
    // photo — so it is normalised here rather than dereferenced later.
    final String path = resume.content.personal.photoPath ?? '';
    if (!plan.showPhoto || path.isEmpty) return null;
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }
}

final Provider<PdfExportService> pdfExportServiceProvider =
    Provider<PdfExportService>((Ref ref) => const PdfExportService());
