import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/repositories/resume_repository.dart';
import '../../domain/entities/resume.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/section_key.dart';
import '../../domain/rules/regional_rule_engine.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import '../../pdf/pdf_fonts.dart';
import '../../pdf/resume_pdf_builder.dart';
import '../export/pdf_export_service.dart';
import '../templates/widgets/template_card.dart';
import 'builder_providers.dart';
import 'builder_sections.dart';
import 'section_editor_screen.dart';

/// The editor.
///
/// The document is edited through [resumeEditorProvider], which keeps a
/// working copy and writes it back as the user types. Everything the screen
/// shows about the document — the section order, the conventions of the target
/// market, the PDF — is derived from that one object, so the preview can never
/// disagree with the form.
class BuilderScreen extends ConsumerWidget {
  const BuilderScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Resume?> document =
        ref.watch(resumeEditorProvider(resumeId));

    return document.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(title: Text(l10n.builderTitle)),
        body: Center(child: Text(l10n.errorStorageFailure)),
      ),
      data: (Resume? resume) => resume == null
          ? Scaffold(
              appBar: AppBar(title: Text(l10n.builderTitle)),
              body: Center(child: Text(l10n.errorCvNotFound)),
            )
          : _BuilderView(resumeId: resumeId, document: resume),
    );
  }
}

class _BuilderView extends ConsumerStatefulWidget {
  const _BuilderView({required this.resumeId, required this.document});

  final String resumeId;
  final Resume document;

  @override
  ConsumerState<_BuilderView> createState() => _BuilderViewState();
}

class _BuilderViewState extends ConsumerState<_BuilderView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ResumeEditor get _editor =>
      ref.read(resumeEditorProvider(widget.resumeId).notifier);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Resume resume = widget.document;
    final FormatPlan plan = ref.watch(formatPlanProvider(resume));

    return Scaffold(
      appBar: AppBar(
        title: Text(resume.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                constraints.maxWidth < 780
                    ? TabBar(
                        controller: _tabs,
                        tabs: <Widget>[
                          Tab(text: l10n.builderTitle),
                          Tab(text: l10n.templatesTitle),
                          Tab(text: l10n.previewTitle),
                        ],
                      )
                    : const SizedBox.shrink(),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.analyzerTitle,
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push(AppRoutes.analyserPath(widget.resumeId)),
          ),
          _ExportMenu(resumeId: widget.resumeId, document: resume, plan: plan),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // A tablet or a desktop window shows the form and the finished page
          // side by side, because that is the whole point of a builder: type
          // on the left, watch the page on the right.
          if (constraints.maxWidth >= 780) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: _EditorPane(
                    resumeId: widget.resumeId,
                    resume: resume,
                    plan: plan,
                    tabIndex: 0,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 6,
                  child: _PreviewPane(
                    resumeId: widget.resumeId,
                    resume: resume,
                    plan: plan,
                  ),
                ),
              ],
            );
          }
          return TabBarView(
            controller: _tabs,
            children: <Widget>[
              _EditorPane(
                resumeId: widget.resumeId,
                resume: resume,
                plan: plan,
                tabIndex: 0,
              ),
              _EditorPane(
                resumeId: widget.resumeId,
                resume: resume,
                plan: plan,
                tabIndex: 1,
              ),
              _PreviewPane(
                resumeId: widget.resumeId,
                resume: resume,
                plan: plan,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _editor.flush();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.builderSaved)),
          );
        },
        icon: const Icon(Icons.check_rounded),
        label: Text(l10n.save),
      ),
    );
  }
}

// ── editor pane ────────────────────────────────────────────────────────────

class _EditorPane extends ConsumerWidget {
  const _EditorPane({
    required this.resumeId,
    required this.resume,
    required this.plan,
    required this.tabIndex,
  });

  final String resumeId;
  final Resume resume;
  final FormatPlan plan;
  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tabIndex == 1) {
      return _DesignPane(resumeId: resumeId, resume: resume, plan: plan);
    }
    return _SectionsPane(resumeId: resumeId, resume: resume, plan: plan);
  }
}

class _SectionsPane extends ConsumerWidget {
  const _SectionsPane({
    required this.resumeId,
    required this.resume,
    required this.plan,
  });

  final String resumeId;
  final Resume resume;
  final FormatPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SectionKey> visible = resume.effectiveSections;
    final List<SectionKey> suggested = plan.addableSections
        .where((SectionKey k) => !visible.contains(k))
        .toList(growable: false);
    final int filled =
        visible.where((SectionKey k) => resume.content.hasContentFor(k)).length;

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        TextField(
          controller: null,
          onChanged:
              ref.read(resumeEditorProvider(resumeId).notifier).setTitle,
          decoration: InputDecoration(
            labelText: l10n.builderTitle,
            helperText: l10n.builderAutosaved,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: LinearProgressIndicator(
                value: visible.isEmpty ? 0 : filled / visible.length,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${l10n.builderProgress} '
              '${visible.isEmpty ? 0 : (filled * 100 ~/ visible.length)}%',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (suggested.isNotEmpty) ...<Widget>[
          Text(l10n.builderAddSection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final SectionKey key in suggested)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(sectionTitle(key, l10n)),
                  onPressed: () =>
                      _openSection(context, ref, key, enable: true),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(l10n.builderSectionOrder, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          // onReorderItem already reports the index the item lands on, so
          // the old "shrink the target when moving down" dance is not needed.
          onReorderItem:
              ref.read(resumeEditorProvider(resumeId).notifier).moveSection,
          itemBuilder: (BuildContext context, int index) {
            final SectionKey key = visible[index];
            final bool hasContent = resume.content.hasContentFor(key);
            return Card(
              key: ValueKey<String>('section-${key.id}'),
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: Icon(
                  hasContent
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: hasContent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(sectionTitle(key, l10n)),
                subtitle: hasContent ? null : Text(l10n.builderEmptySectionHint),
                onTap: () => _openSection(context, ref, key),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.builderRemoveSection,
                      icon: const Icon(Icons.visibility_off_outlined),
                      onPressed: () => ref
                          .read(resumeEditorProvider(resumeId).notifier)
                          .toggleSection(key),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openSection(
    BuildContext context,
    WidgetRef ref,
    SectionKey key, {
    bool enable = false,
  }) {
    if (enable) {
      ref.read(resumeEditorProvider(resumeId).notifier).toggleSection(key);
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SectionEditorScreen(
          resumeId: resumeId,
          sectionKey: key,
        ),
      ),
    );
  }
}

// ── design pane ────────────────────────────────────────────────────────────

class _DesignPane extends ConsumerWidget {
  const _DesignPane({
    required this.resumeId,
    required this.resume,
    required this.plan,
  });

  final String resumeId;
  final Resume resume;
  final FormatPlan plan;

  static const List<String> _palette = <String>[
    '#4F46E5',
    '#0F766E',
    '#B91C1C',
    '#B45309',
    '#1D4ED8',
    '#374151',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ResumeEditor editor =
        ref.read(resumeEditorProvider(resumeId).notifier);
    final List<ResumeTemplate> templates = ref.watch(templatesProvider);

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        Text(l10n.templatesTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final ResumeTemplate template in templates)
          // A plain tile rather than a radio: the whole row is the target,
          // and the selected template is marked with a check instead of a
          // control the user has to aim at.
          ListTile(
            onTap: () => editor.setTemplate(template.id),
            leading: Icon(
              resume.templateId == template.id
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: resume.templateId == template.id
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            title: Text(templateName(l10n, template)),
            subtitle: Text(
              template.isAtsSafe ? l10n.templatesAtsSafe : l10n.templatesFree,
            ),
            trailing: template.premium
                ? Chip(label: Text(l10n.templatesPremium))
                : null,
          ),
        const Divider(height: AppSpacing.xxl),
        Text(l10n.settingsAppearance, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (final String hex in _palette)
              InkWell(
                onTap: () => editor.setAccentColor(hex),
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _parse(hex),
                  child: resume.accentColorHex == hex
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String?>(
          initialValue: resume.fontFamily,
          decoration: InputDecoration(labelText: l10n.settingsDocumentFont),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.settingsThemeSystem),
            ),
            for (final String family in <String>[
              PdfFonts.persianFamily,
              ...PdfFonts.latinFamilies,
            ])
              DropdownMenuItem<String?>(value: family, child: Text(family)),
          ],
          onChanged: editor.setFontFamily,
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<PaperSize>(
          segments: <ButtonSegment<PaperSize>>[
            ButtonSegment<PaperSize>(
              value: PaperSize.a4,
              label: Text(l10n.paperA4),
            ),
            ButtonSegment<PaperSize>(
              value: PaperSize.usLetter,
              label: Text(l10n.paperLetter),
            ),
          ],
          selected: <PaperSize>{plan.paperSize},
          onSelectionChanged: (Set<PaperSize> selection) =>
              editor.setPaperSize(selection.first),
        ),
      ],
    );
  }

  static Color _parse(String hex) {
    final String value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

// ── preview pane ───────────────────────────────────────────────────────────

class _PreviewPane extends ConsumerWidget {
  const _PreviewPane({
    required this.resumeId,
    required this.resume,
    required this.plan,
  });

  final String resumeId;
  final Resume resume;
  final FormatPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PdfExportService service = ref.watch(pdfExportServiceProvider);
    final ResumeTemplate template = ResumeTemplates.byId(resume.templateId);

    if (resume.content.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screen,
          child: Text(
            l10n.builderPreviewHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return PdfPreview(
      build: (PdfPageFormat format) async => (await service.render(
        resume: resume,
        plan: plan,
        template: template,
        l10n: l10n,
      ))
          .bytes,
      initialPageFormat: PdfPageFormat(
        plan.paperSize.widthPt,
        plan.paperSize.heightPt,
      ),
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: service.fileNameFor(resume),
    );
  }
}

// ── export menu ────────────────────────────────────────────────────────────

class _ExportMenu extends ConsumerWidget {
  const _ExportMenu({
    required this.resumeId,
    required this.document,
    required this.plan,
  });

  final String resumeId;
  final Resume document;
  final FormatPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (String action) => _run(context, ref, action),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'fullPreview',
          child: Text(l10n.previewTitle),
        ),
        PopupMenuItem<String>(value: 'share', child: Text(l10n.exportSharePdf)),
        PopupMenuItem<String>(value: 'save', child: Text(l10n.exportSavePdf)),
        PopupMenuItem<String>(value: 'print', child: Text(l10n.exportPrint)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(value: 'version', child: Text(l10n.duplicate)),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String action) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ResumeRepository repository = ref.read(resumeRepositoryProvider);
    final PdfExportService service = ref.read(pdfExportServiceProvider);

    switch (action) {
      case 'fullPreview':
        if (context.mounted) {
          await context.push(AppRoutes.previewPath(resumeId));
        }
        return;
      case 'version':
        await repository.snapshot(
          document,
          label: DateTime.now().toIso8601String(),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.builderSaved)),
        );
        return;
    }

    // Everything below needs bytes, so the working copy is flushed first:
    // exporting a document with the last keystroke missing is a bug users
    // notice immediately.
    await ref.read(resumeEditorProvider(resumeId).notifier).flush();
    if (!context.mounted) return;

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
