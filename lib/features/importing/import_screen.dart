import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/import/document_text_extractor.dart';
import '../../data/import/resume_importer.dart';
import '../../domain/entities/resume.dart';
import '../../domain/entities/resume_content.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/enums/section_key.dart';
import '../../l10n/app_localizations.dart';
import '../builder/builder_sections.dart';

/// Import an existing CV.
///
/// The flow is deliberately two steps: read the file, then review what was
/// understood. Nothing is written to the database until the user confirms,
/// because text extraction and section guessing are heuristics — good ones,
/// but the difference between "the parser read this" and "this is what the
/// document says" has to be visible before it becomes a CV.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

enum _Stage { pick, parsing, review, failed }

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Stage _stage = _Stage.pick;
  String _errorCode = '';

  ImportedResume? _draft;
  ResumeContent _content = ResumeContent.empty;
  Map<SectionKey, int> _found = const <SectionKey, int>{};

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _jobTitle = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _pasted = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _firstName,
      _lastName,
      _jobTitle,
      _email,
      _phone,
      _city,
      _country,
      _summary,
      _pasted,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importTitle),
        actions: <Widget>[
          if (_stage == _Stage.review)
            TextButton(
              onPressed: () => setState(() {
                _stage = _Stage.pick;
                _draft = null;
              }),
              child: Text(l10n.cancel),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.pick => _pickView(l10n),
        _Stage.parsing => _parsingView(l10n),
        _Stage.failed => _failureView(l10n),
        _Stage.review => _reviewView(l10n),
      },
    );
  }

  // ── Step 1: choose a file ────────────────────────────────────────────────

  Widget _pickView(AppLocalizations l10n) {
    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        Text(l10n.importTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.importReviewBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _FileButton(
          icon: Icons.picture_as_pdf_outlined,
          label: l10n.importFromPdf,
          onPressed: () => _pickFile(<String>['pdf']),
        ),
        _FileButton(
          icon: Icons.description_outlined,
          label: l10n.importFromDocx,
          onPressed: () => _pickFile(<String>['docx']),
        ),
        _FileButton(
          icon: Icons.text_snippet_outlined,
          label: l10n.importFromTxt,
          onPressed: () => _pickFile(<String>['txt']),
        ),
        _FileButton(
          icon: Icons.image_outlined,
          label: l10n.importFromImage,
          onPressed: _pickImage,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.importFromTxt, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _pasted,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.tonal(
          onPressed: () => _parse(_pasted.text, 'pasted text'),
          child: Text(l10n.importFromTxt),
        ),
      ],
    );
  }

  Future<void> _pickFile(List<String> extensions) async {
    try {
      // file_picker 13 exposes static pickers and returns the file directly;
      // there is no result wrapper to unwrap any more.
      final PlatformFile? picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      final String? path = picked?.path;
      if (picked == null || path == null) return;
      setState(() => _stage = _Stage.parsing);
      final ImportFormat format = DocumentTextExtractor.formatFor(picked.name);
      final String text =
          await DocumentTextExtractor.extract(File(path), format);
      _parse(text, picked.name);
    } on ImportFailure catch (failure) {
      _fail(failure.code);
    } on Object {
      _fail('somethingWentWrong');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      // OCR needs a native recogniser; this build ships none, so the honest
      // answer is that the picture cannot be read here.
      _fail('importOcrUnavailable');
    } on Object {
      _fail('importOcrUnavailable');
    }
  }

  void _fail(String code) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _errorCode = code;
    });
  }

  void _parse(String text, String source) {
    if (text.trim().length < 20) {
      _fail('importNothingFound');
      return;
    }
    final ImportedResume parsed = ResumeImporter.parse(text);
    if (parsed.isEmpty) {
      _fail('importNothingFound');
      return;
    }
    final PersonalInfo personal = parsed.content.personal;
    _firstName.text = personal.firstName;
    _lastName.text = personal.lastName;
    _jobTitle.text = personal.jobTitle;
    _email.text = personal.email;
    _phone.text = personal.phone;
    _city.text = personal.city;
    _country.text = personal.country;
    _summary.text = personal.summary;

    setState(() {
      _draft = parsed;
      _content = parsed.content;
      _found = parsed.found;
      _stage = _Stage.review;
    });
  }

  // ── Step 2: review and confirm ───────────────────────────────────────────

  Widget _parsingView(AppLocalizations l10n) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.importParsingTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.importParsingBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _failureView(AppLocalizations l10n) {
    final bool ocr = _errorCode == 'importOcrUnavailable';
    return EmptyState(
      icon: ocr ? Icons.image_not_supported_outlined : Icons.error_outline_rounded,
      title: switch (_errorCode) {
        'importOcrUnavailable' => l10n.importOcrUnavailableTitle,
        'importNothingFound' => l10n.importNothingFound,
        'errorFileTooLarge' => l10n.errorFileTooLarge,
        'errorUnsupportedFormat' => l10n.errorUnsupportedFormat,
        _ => l10n.somethingWentWrong,
      },
      body: ocr ? l10n.importOcrUnavailableBody : l10n.somethingWentWrong,
      actionLabel: l10n.tryAgain,
      onAction: () => setState(() => _stage = _Stage.pick),
    );
  }

  Widget _reviewView(AppLocalizations l10n) {
    final ImportedResume? draft = _draft;
    if (draft == null) return const SizedBox.shrink();

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        Text(l10n.importReviewTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.importReviewBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _field(l10n.fieldFirstName, _firstName),
        _field(l10n.fieldLastName, _lastName),
        _field(l10n.fieldJobTitle, _jobTitle),
        _field(l10n.fieldEmail, _email),
        _field(l10n.fieldPhone, _phone),
        _field(l10n.fieldCity, _city),
        _field(l10n.fieldCountry, _country),
        _field(l10n.fieldSummary, _summary, lines: 4),
        const SizedBox(height: AppSpacing.lg),
        if (_found.isNotEmpty) _foundCard(l10n),
        const SizedBox(height: AppSpacing.lg),
        if (_content.experiences.isNotEmpty)
          _entryCard(
            l10n.sectionExperience,
            _content.experiences
                .map((Experience e) => (
                      title: e.jobTitle.isEmpty ? l10n.sectionExperience : e.jobTitle,
                      subtitle: e.company,
                    ))
                .toList(growable: false),
            (int index) => setState(() {
              final List<Experience> next =
                  List<Experience>.of(_content.experiences)..removeAt(index);
              _content = _content.copyWith(experiences: next);
            }),
          ),
        if (_content.education.isNotEmpty)
          _entryCard(
            l10n.sectionEducation,
            _content.education
                .map((Education e) => (
                      title: e.degree.isEmpty ? e.institution : e.degree,
                      subtitle: e.institution,
                    ))
                .toList(growable: false),
            (int index) => setState(() {
              final List<Education> next =
                  List<Education>.of(_content.education)..removeAt(index);
              _content = _content.copyWith(education: next);
            }),
          ),
        if (_content.projects.isNotEmpty)
          _entryCard(
            l10n.sectionProjects,
            _content.projects
                .map((Project p) => (title: p.name, subtitle: p.description))
                .toList(growable: false),
            (int index) => setState(() {
              final List<Project> next =
                  List<Project>.of(_content.projects)..removeAt(index);
              _content = _content.copyWith(projects: next);
            }),
          ),
        if (_content.skills.isNotEmpty)
          _chipsCard(
            l10n.sectionSkills,
            _content.skills.map((Skill s) => s.name).toList(growable: false),
            (int index) => setState(() {
              final List<Skill> next = List<Skill>.of(_content.skills)
                ..removeAt(index);
              _content = _content.copyWith(skills: next);
            }),
          ),
        if (_content.languages.isNotEmpty)
          _chipsCard(
            l10n.sectionLanguages,
            _content.languages
                .map((LanguageSkill l) => l.language)
                .toList(growable: false),
            (int index) => setState(() {
              final List<LanguageSkill> next =
                  List<LanguageSkill>.of(_content.languages)..removeAt(index);
              _content = _content.copyWith(languages: next);
            }),
          ),
        if (draft.unrecognisedHeadings.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _chipsCard(
            l10n.sectionCustom,
            draft.unrecognisedHeadings,
            null,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _saving ? null : _confirm,
          icon: const Icon(Icons.check_rounded),
          label: Text(l10n.importConfirmImport),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  Widget _foundCard(AppLocalizations l10n) => Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final MapEntry<SectionKey, int> entry in _found.entries)
                Chip(
                  label: Text('${sectionTitle(entry.key, l10n)} · ${entry.value}'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
            ],
          ),
        ),
      );

  Widget _entryCard(
    String title,
    List<({String title, String subtitle})> entries,
    void Function(int index) onRemove,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (int i = 0; i < entries.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(entries[i].title),
                  subtitle: entries[i].subtitle.isEmpty
                      ? null
                      : Text(
                          entries[i].subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: l10nDelete,
                    onPressed: () => onRemove(i),
                  ),
                ),
            ],
          ),
        ),
      );

  String get l10nDelete => AppLocalizations.of(context).delete;

  Widget _chipsCard(
    String title,
    List<String> values,
    void Function(int index)? onRemove,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (int i = 0; i < values.length; i++)
                    InputChip(
                      label: Text(values[i]),
                      visualDensity: VisualDensity.compact,
                      onDeleted: onRemove == null ? null : () => onRemove(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _confirm() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final PersonalInfo personal = PersonalInfo(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      jobTitle: _jobTitle.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      country: _country.text.trim(),
      summary: _summary.text.trim(),
    );
    final String title = personal.fullName.trim().isEmpty
        ? l10n.importTitle
        : personal.fullName.trim();

    try {
      final Resume created = await ref.read(resumeRepositoryProvider).create(
            title: title,
            region: RegionCode.international,
            cvType: CvType.professionalCv,
            paperSize: PaperSize.a4,
            content: _content.copyWith(personal: personal),
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importConfirmImport)),
      );
      await context.push(AppRoutes.builderPath(created.id));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    }
  }
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label),
          ),
          style: OutlinedButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
          ),
        ),
      );
}
