import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/date_display.dart';
import '../../data/rules/regional_rules_repository.dart';
import '../../domain/entities/resume.dart';
import '../../domain/entities/resume_content.dart';
import '../../domain/entities/year_month.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/section_key.dart';
import '../../l10n/app_localizations.dart';
import 'builder_providers.dart';
import 'builder_sections.dart';
import 'entry_specs.dart';
import 'widgets/editor_fields.dart';

/// Edits one section of one document.
///
/// Every section is edited here: the screen switches on the section's *shape*
/// (personal details, prose, chips, records, user-named sections) rather than
/// on its identity, so the thirty section keys in the vocabulary need five
/// code paths between them.
class SectionEditorScreen extends ConsumerWidget {
  const SectionEditorScreen({
    required this.resumeId,
    required this.sectionKey,
    super.key,
  });

  final String resumeId;
  final SectionKey sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Resume?> resume = ref.watch(resumeEditorProvider(resumeId));

    return Scaffold(
      appBar: AppBar(title: Text(sectionTitle(sectionKey, l10n))),
      body: resume.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(l10n.somethingWentWrong)),
        data: (Resume? document) {
          if (document == null) {
            return Center(child: Text(l10n.errorCvNotFound));
          }
          return _SectionBody(
            resumeId: resumeId,
            document: document,
            sectionKey: sectionKey,
          );
        },
      ),
    );
  }
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({
    required this.resumeId,
    required this.document,
    required this.sectionKey,
  });

  final String resumeId;
  final Resume document;
  final SectionKey sectionKey;

  void _edit(WidgetRef ref, ResumeContent Function(ResumeContent) change) {
    ref.read(resumeEditorProvider(resumeId).notifier).editContent(change);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ResumeContent content = document.content;
    final DateSystem dateSystem =
        ref.watch(regionalProfileOrNeutralProvider(document.region)).dateSystem;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return switch (formKindFor(sectionKey)) {
      SectionFormKind.personal => _PersonalForm(
          personal: content.personal,
          resumeId: resumeId,
          showSensitive: ref
              .watch(formatPlanProvider(document))
              .showSensitiveFields,
        ),
      SectionFormKind.narrative => ListView(
          padding: AppSpacing.screen,
          children: <Widget>[
            EditorTextField(
              label: sectionTitle(sectionKey, AppLocalizations.of(context)),
              hint: sectionHint(sectionKey, AppLocalizations.of(context)),
              value: narrativeOf(content, sectionKey),
              multiline: true,
              onChanged: (String value) =>
                  _edit(ref, (ResumeContent c) => withNarrative(c, sectionKey, value)),
            ),
          ],
        ),
      SectionFormKind.strings => _StringListForm(
          title: sectionTitle(sectionKey, AppLocalizations.of(context)),
          values: stringListOf(content, sectionKey) ?? const <String>[],
          onChanged: (List<String> values) => _edit(
            ref,
            (ResumeContent c) => withStringList(c, sectionKey, values),
          ),
        ),
      SectionFormKind.custom => _CustomSectionsForm(
          resumeId: resumeId,
          sections: content.customSections,
          dateSystem: dateSystem,
        ),
      SectionFormKind.entries => _RecordList(
          resumeId: resumeId,
          spec: entrySpecFor(sectionKey, l10n)!,
          entries: entrySpecFor(sectionKey, l10n)!.read(content),
          dateSystem: dateSystem,
        ),
    };
  }
}

// ── personal details ───────────────────────────────────────────────────────

class _PersonalForm extends ConsumerWidget {
  const _PersonalForm({
    required this.personal,
    required this.resumeId,
    required this.showSensitive,
  });

  final PersonalInfo personal;
  final String resumeId;
  final bool showSensitive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    void patch(PersonalInfo Function(PersonalInfo) change) => ref
        .read(resumeEditorProvider(resumeId).notifier)
        .editContent((ResumeContent c) =>
            c.copyWith(personal: change(c.personal)));

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        EditorTextField(
          label: l10n.fieldFirstName,
          value: personal.firstName,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(firstName: v)),
        ),
        EditorTextField(
          label: l10n.fieldLastName,
          value: personal.lastName,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(lastName: v)),
        ),
        EditorTextField(
          label: l10n.fieldJobTitle,
          value: personal.jobTitle,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(jobTitle: v)),
        ),
        EditorTextField(
          label: l10n.fieldEmail,
          value: personal.email,
          keyboardType: TextInputType.emailAddress,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(email: v)),
        ),
        EditorTextField(
          label: l10n.fieldPhone,
          value: personal.phone,
          keyboardType: TextInputType.phone,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(phone: v)),
        ),
        EditorTextField(
          label: l10n.fieldCity,
          value: personal.city,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(city: v)),
        ),
        EditorTextField(
          label: l10n.fieldProvince,
          value: personal.province,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(province: v)),
        ),
        EditorTextField(
          label: l10n.fieldCountry,
          value: personal.country,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(country: v)),
        ),
        EditorTextField(
          label: l10n.fieldLinkedIn,
          value: personal.linkedIn,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(linkedIn: v)),
        ),
        EditorTextField(
          label: l10n.fieldGitHub,
          value: personal.gitHub,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(gitHub: v)),
        ),
        EditorTextField(
          label: l10n.fieldWebsite,
          value: personal.website,
          onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(website: v)),
        ),
        EditorSwitchField(
          label: l10n.fieldPhoto,
          value: personal.showPhoto,
          onChanged: (bool v) => patch((PersonalInfo p) => p.copyWith(showPhoto: v)),
        ),
        if (showSensitive) ...<Widget>[
          const Divider(height: AppSpacing.xxl),
          Text(
            l10n.sensitiveFieldNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorTextField(
            label: l10n.fieldNationalId,
            value: personal.nationalId,
            onChanged: (String v) =>
                patch((PersonalInfo p) => p.copyWith(nationalId: v)),
          ),
          EditorTextField(
            label: l10n.fieldGender,
            value: personal.gender,
            onChanged: (String v) => patch((PersonalInfo p) => p.copyWith(gender: v)),
          ),
          EditorTextField(
            label: l10n.fieldNationality,
            value: personal.nationality,
            onChanged: (String v) =>
                patch((PersonalInfo p) => p.copyWith(nationality: v)),
          ),
          EditorTextField(
            label: l10n.fieldMaritalStatus,
            value: personal.maritalStatus,
            onChanged: (String v) =>
                patch((PersonalInfo p) => p.copyWith(maritalStatus: v)),
          ),
        ],
      ],
    );
  }
}

// ── chip lists ─────────────────────────────────────────────────────────────

class _StringListForm extends StatefulWidget {
  const _StringListForm({
    required this.title,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_StringListForm> createState() => _StringListFormState();
}

class _StringListFormState extends State<_StringListForm> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final String value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onChanged(<String>[...widget.values, value]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (String _) => _add(),
                decoration: InputDecoration(
                  labelText: widget.title,
                  hintText: l10n.builderAddItem,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.builderAddItem,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (widget.values.isEmpty)
          Text(
            l10n.builderEmptySectionHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String value in widget.values)
              InputChip(
                label: Text(value),
                onDeleted: () => widget.onChanged(
                  widget.values.where((String v) => v != value).toList(
                        growable: false,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── records ────────────────────────────────────────────────────────────────

class _RecordList extends ConsumerWidget {
  const _RecordList({
    required this.resumeId,
    required this.spec,
    required this.entries,
    required this.dateSystem,
  });

  final String resumeId;
  final EntrySpec spec;
  final List<Object> entries;
  final DateSystem dateSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;

    void write(List<Object> next) => ref
        .read(resumeEditorProvider(resumeId).notifier)
        .editContent((ResumeContent c) => spec.write(c, next));

    void move(int from, int to) {
      if (to < 0 || to >= entries.length) return;
      final List<Object> next = entries.toList();
      final Object moved = next.removeAt(from);
      next.insert(to, moved);
      write(next);
    }

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              l10n.builderEmptySectionHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (int index = 0; index < entries.length; index++)
          Builder(
            builder: (BuildContext context) {
              final Object entry = entries[index];
              final EntryRange? range = spec.range?.call(entry);
              final String? subtitle = spec.subtitle?.call(entry);
              final String dates = range == null
                  ? ''
                  : _rangeLabel(range, dateSystem, languageCode, l10n);
              final String supporting = <String>[
                if (subtitle != null && subtitle.trim().isNotEmpty) subtitle,
                if (dates.isNotEmpty) dates,
              ].join(' · ');

              return EntryTile(
                title: spec.title(entry),
                subtitle: supporting,
                onTap: () => _editEntry(
                  context,
                  ref,
                  index,
                  entry,
                  write,
                ),
                onMoveUp: index == 0 ? null : () => move(index, index - 1),
                onMoveDown: index == entries.length - 1
                    ? null
                    : () => move(index, index + 1),
                onDelete: () => write(
                  entries.where((Object e) => e != entry).toList(growable: false),
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: () => _editEntry(
            context,
            ref,
            entries.length,
            spec.create(),
            write,
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.builderAddItem),
        ),
      ],
    );
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    int index,
    Object entry,
    void Function(List<Object>) write,
  ) async {
    final Object? edited = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _RecordEditor(
        spec: spec,
        entry: entry,
        dateSystem: dateSystem,
      ),
    );
    if (edited == null) return;
    // Nothing typed, nothing stored: an untouched new record disappears
    // instead of leaving an empty card behind.
    if (index >= entries.length && _isBlank(spec, edited)) return;

    final List<Object> next = entries.toList();
    if (index >= next.length) {
      next.add(edited);
    } else {
      next[index] = edited;
    }
    write(next);
  }
}

/// The sheet that edits one record, built from its field description.
class _RecordEditor extends StatefulWidget {
  const _RecordEditor({
    required this.spec,
    required this.entry,
    required this.dateSystem,
  });

  final EntrySpec spec;
  final Object entry;
  final DateSystem dateSystem;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late Object _draft = widget.entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EntrySpec spec = widget.spec;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screen.left,
        right: AppSpacing.screen.right,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              spec.title(_draft),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final EntryField field in spec.fields) _field(field),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _field(EntryField field) => switch (field) {
        TextEntryField f => EditorTextField(
            label: f.label,
            value: f.read(_draft),
            multiline: f.multiline,
            onChanged: (String value) =>
                setState(() => _draft = f.write(_draft, value)),
          ),
        LinesEntryField f => EditorLinesField(
            label: f.label,
            value: f.read(_draft),
            onChanged: (List<String> value) =>
                setState(() => _draft = f.write(_draft, value)),
          ),
        DateEntryField f => YearMonthField(
            label: f.label,
            value: f.read(_draft),
            dateSystem: widget.dateSystem,
            onChanged: (YearMonth? value) =>
                setState(() => _draft = f.write(_draft, value)),
          ),
        SwitchEntryField f => EditorSwitchField(
            label: f.label,
            value: f.read(_draft),
            onChanged: (bool value) =>
                setState(() => _draft = f.write(_draft, value)),
          ),
        ChoiceEntryField f => EditorChoiceField<Object?>(
            label: f.label,
            value: f.read(_draft),
            values: f.values,
            labelOf: f.labelOf,
            onChanged: (Object? value) =>
                setState(() => _draft = f.write(_draft, value)),
          ),
      };
}

// ── user-named sections ────────────────────────────────────────────────────

class _CustomSectionsForm extends ConsumerWidget {
  const _CustomSectionsForm({
    required this.resumeId,
    required this.sections,
    required this.dateSystem,
  });

  final String resumeId;
  final List<CustomSection> sections;
  final DateSystem dateSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    void write(List<CustomSection> next) => ref
        .read(resumeEditorProvider(resumeId).notifier)
        .editContent((ResumeContent c) => c.copyWith(customSections: next));

    return ListView(
      padding: AppSpacing.screen,
      children: <Widget>[
        for (int index = 0; index < sections.length; index++)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  EditorTextField(
                    label: l10n.fieldCustomSectionTitle,
                    value: sections[index].title,
                    onChanged: (String value) {
                      final List<CustomSection> next = sections.toList();
                      next[index] = next[index].copyWith(title: value);
                      write(next);
                    },
                  ),
                  EditorSwitchField(
                    label: l10n.builderAddItem,
                    value: sections[index].useEntries,
                    onChanged: (bool value) {
                      final List<CustomSection> next = sections.toList();
                      next[index] = next[index].copyWith(useEntries: value);
                      write(next);
                    },
                  ),
                  if (!sections[index].useEntries)
                    EditorTextField(
                      label: l10n.fieldDescription,
                      value: sections[index].bodyText,
                      multiline: true,
                      onChanged: (String value) {
                        final List<CustomSection> next = sections.toList();
                        next[index] = next[index].copyWith(bodyText: value);
                        write(next);
                      },
                    ),
                  if (sections[index].useEntries)
                    _RecordList(
                      resumeId: resumeId,
                      entries: sections[index].entries.cast<Object>(),
                      dateSystem: dateSystem,
                      spec: _customSectionSpec(l10n, sections[index]),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => write(
                        sections
                            .where((CustomSection s) => s.id != sections[index].id)
                            .toList(growable: false),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l10n.delete),
                    ),
                  ),
                ],
              ),
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: () => write(<CustomSection>[
            ...sections,
            CustomSection(id: const Uuid().v4(), title: l10n.sectionCustom),
          ]),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.builderAddSection),
        ),
      ],
    );
  }
}

/// Records inside a user-named section.
///
/// These are plain dated entries: the user named the section, so the app has
/// no opinion about what belongs in it, and every field is optional.
EntrySpec _customSectionSpec(AppLocalizations l10n, CustomSection section) =>
    EntrySpec(
      read: (ResumeContent c) => c.customSections
          .where((CustomSection s) => s.id == section.id)
          .expand((CustomSection s) => s.entries)
          .cast<Object>()
          .toList(growable: false),
      write: (ResumeContent c, List<Object> entries) => c.copyWith(
        customSections: c.customSections
            .map((CustomSection s) => s.id == section.id
                ? s.copyWith(entries: entries.cast<DatedEntry>())
                : s)
            .toList(growable: false),
      ),
      create: () => DatedEntry(id: const Uuid().v4()),
      title: (Object e) => (e as DatedEntry).title,
      subtitle: (Object e) => (e as DatedEntry).organization,
      fields: <EntryField>[
        textOf<DatedEntry>(l10n.fieldTitle, (DatedEntry e) => e.title,
            (DatedEntry e, String v) => e.copyWith(title: v)),
        textOf<DatedEntry>(l10n.fieldDescription, (DatedEntry e) => e.description,
            (DatedEntry e, String v) => e.copyWith(description: v),
            multiline: true),
      ],
    );

String _rangeLabel(
  EntryRange range,
  DateSystem system,
  String languageCode,
  AppLocalizations l10n,
) {
  final String start = range.start == null
      ? ''
      : _one(range.start!, system, languageCode);
  final String end = range.isCurrent
      ? l10n.presentLabel
      : range.end == null
          ? ''
          : _one(range.end!, system, languageCode);
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return '$start – $end';
}

String _one(YearMonth value, DateSystem system, String languageCode) =>
    DateDisplay.monthYear(value, system: system, languageCode: languageCode);

/// `true` when every editable field of a record is still empty.
///
/// Used to drop a record the user opened and left untouched: an entry with no
/// text prints as nothing, but it still counts against the section in the
/// builder and would be exported in the JSON backup.
bool _isBlank(EntrySpec spec, Object entry) => spec.fields.every(
      (EntryField field) => switch (field) {
        TextEntryField f => f.read(entry).trim().isEmpty,
        LinesEntryField f =>
          f.read(entry).every((String line) => line.trim().isEmpty),
        DateEntryField f => f.read(entry) == null,
        // A switch or a choice always holds a value, so it cannot, on its
        // own, make a record worth keeping.
        SwitchEntryField() => true,
        ChoiceEntryField() => true,
      },
    );
