import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/repositories/resume_repository.dart';
import '../../domain/entities/resume.dart';
import '../../domain/rules/regional_rule_engine.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import '../../pdf/resume_pdf_builder.dart';
import '../builder/builder_providers.dart';
import '../export/pdf_export_service.dart';

/// Paginated preview of the generated PDF.
///
/// Rendered by the same engine that produces the exported file, so what the
/// user approves here is byte-for-byte what they send to an employer. The
/// renderer's own warnings — a photo the market does not expect, a length
/// beyond the regional convention — are shown above the page rather than
/// silently dropped, because those are exactly the things a candidate wants to
/// know before sending.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Resume?> document =
        ref.watch(resumeEditorProvider(resumeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.previewTitle),
        actions: <Widget>[
          if (document.valueOrNull != null)
            _PreviewActions(resumeId: resumeId, document: document.value!),
        ],
      ),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(l10n.errorStorageFailure)),
        data: (Resume? resume) {
          if (resume == null) {
            return Center(child: Text(l10n.errorCvNotFound));
          }
          return _PreviewBody(resumeId: resumeId, document: resume);
        },
      ),
    );
  }
}

/// Renders once, then shows the page together with anything the renderer
/// wants the user to know.
///
/// The render happens here rather than inside [PdfPreview] so the warnings it
/// produced can be displayed: "your photo is not in this file" is exactly the
/// kind of thing a candidate should learn before sending the CV, and the
/// preview is where they are looking.
class _PreviewBody extends ConsumerStatefulWidget {
  const _PreviewBody({required this.resumeId, required this.document});

  final String resumeId;
  final Resume document;

  @override
  ConsumerState<_PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends ConsumerState<_PreviewBody> {
  Future<ResumePdfResult>? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first render needs the interface language, which is only readable
    // once the inherited widgets are available — hence here rather than in
    // initState. It runs once per screen: the document cannot change while
    // the preview is open.
    _result ??= _render();
  }

  Future<ResumePdfResult> _render() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FormatPlan plan = ref.read(formatPlanProvider(widget.document));
    return ref.read(pdfExportServiceProvider).render(
          resume: widget.document,
          plan: plan,
          template: ResumeTemplates.byId(widget.document.templateId),
          l10n: l10n,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FormatPlan plan = ref.watch(formatPlanProvider(widget.document));
    final PdfExportService service = ref.watch(pdfExportServiceProvider);

    return FutureBuilder<ResumePdfResult>(
      future: _result,
      builder: (BuildContext context, AsyncSnapshot<ResumePdfResult> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(l10n.errorExportFailure));
        }
        final ResumePdfResult? result = snapshot.data;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: <Widget>[
            if (result.warnings.isNotEmpty)
              _WarningStrip(warnings: result.warnings),
            Expanded(
              child: PdfPreview(
                // The bytes were produced above; the preview widget only
                // rasterises them for the screen.
                build: (PdfPageFormat format) async => result.bytes,
                initialPageFormat: PdfPageFormat(
                  plan.paperSize.widthPt,
                  plan.paperSize.heightPt,
                ),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: service.fileNameFor(widget.document),
                allowPrinting: false,
                allowSharing: false,
                useActions: false,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The renderer's warnings, phrased as facts rather than as errors.
class _WarningStrip extends StatelessWidget {
  const _WarningStrip({required this.warnings});

  final List<PdfRenderWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    String textFor(PdfRenderWarning warning) => switch (warning.code) {
          'pdf.photoMissing' => l10n.pdfWarningPhotoMissing,
          'pdf.photoWithAts' => l10n.pdfWarningPhotoWithAts,
          'pdf.longerThanConvention' => <String>[
              l10n.pdfWarningLongerThanConvention,
              if (warning.params['pages'] != null)
                '${warning.params['pages']}/${warning.params['ideal'] ?? '—'}',
            ].join(' '),
          _ => warning.code,
        };

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final PdfRenderWarning warning in warnings)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    textFor(warning),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewActions extends ConsumerWidget {
  const _PreviewActions({required this.resumeId, required this.document});

  final String resumeId;
  final Resume document;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        onSelected: (String action) => _run(context, ref, action),
        itemBuilder: (BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          return <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'share',
              child: Text(l10n.exportSharePdf),
            ),
            PopupMenuItem<String>(
              value: 'save',
              child: Text(l10n.exportSavePdf),
            ),
            PopupMenuItem<String>(
              value: 'print',
              child: Text(l10n.exportPrint),
            ),
          ];
        },
      );

  Future<void> _run(BuildContext context, WidgetRef ref, String action) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PdfExportService service = ref.read(pdfExportServiceProvider);
    final FormatPlan plan = ref.read(formatPlanProvider(document));
    final ResumeRepository repository = ref.read(resumeRepositoryProvider);

    try {
      final ResumePdfResult result = await service.render(
        resume: document,
        plan: plan,
        template: ResumeTemplates.byId(document.templateId),
        l10n: l10n,
      );
      final String fileName = service.fileNameFor(document);

      switch (action) {
        case 'share':
          await service.share(result, fileName);
        case 'save':
          final File file = await service.save(result, fileName);
          await repository.recordExport(
            resumeId: resumeId,
            fileName: fileName,
            filePath: file.path,
            format: 'pdf',
            byteSize: result.byteSize,
            pageCount: result.pageCount,
            paperSize: plan.paperSize.id,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.exportSuccess)),
          );
        case 'print':
          await service.print(result, fileName);
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed)),
      );
    }
  }
}
