import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/date_display.dart';
import '../../../domain/entities/year_month.dart';
import '../../../domain/enums/document_options.dart';
import '../../../l10n/app_localizations.dart';

/// A labelled text field.
///
/// Uses `initialValue` rather than a controller owned by the parent: the
/// document in memory is the single source of truth, and the field's own
/// element keeps the caret while the user types. Rebuilds from the analyser or
/// the preview therefore never steal focus mid-sentence.
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.multiline = false,
    this.keyboardType,
    this.hint,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool multiline;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        maxLines: multiline ? null : 1,
        minLines: multiline ? 4 : 1,
        keyboardType: multiline ? TextInputType.multiline : keyboardType,
        textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: multiline,
          suffixText: value.trim().isEmpty ? l10n.optional : null,
        ),
      ),
    );
  }
}

/// A list of short strings edited as one item per line.
///
/// Bullet points in a CV are lines; making the user press an "add" button for
/// every one of them is friction with no benefit. The parser is forgiving: a
/// line that is only whitespace disappears, and a leading dash or bullet the
/// user pasted in is stripped rather than stored.
class EditorLinesField extends StatelessWidget {
  const EditorLinesField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? hint;

  static List<String> parse(String text) => text
      .split('\n')
      .map((String line) => line.replaceFirst(RegExp(r'^\s*[-•*\u2022]\s*'), '').trim())
      .where((String line) => line.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => EditorTextField(
        label: label,
        hint: hint,
        value: value.join('\n'),
        multiline: true,
        onChanged: (String text) => onChanged(parse(text)),
      );
}

/// A month-and-year picker.
///
/// A CV dates things to the month, and a full date picker invites a precision
/// nobody has. The dialog offers a year list wide enough for a career and
/// twelve months, plus a clear action so an end date can be removed again.
class YearMonthField extends StatelessWidget {
  const YearMonthField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.dateSystem,
    this.clearable = true,
    super.key,
  });

  final String label;
  final YearMonth? value;
  final ValueChanged<YearMonth?> onChanged;
  final DateSystem dateSystem;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;
    final ThemeData theme = Theme.of(context);
    final String display = value == null
        ? l10n.none
        : DateDisplay.monthYear(
            value!,
            system: dateSystem,
            languageCode: languageCode,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(
              Icons.event_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          child: Text(
            display,
            style: value == null
                ? theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                : theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  /// Opens the picker.
  ///
  /// Three outcomes are possible — a date, "clear", and "cancel" — so the
  /// dialog returns a sentinel for the clear case rather than collapsing it
  /// into the `null` that a dismissed route also returns. Collapsing them
  /// silently deleted end dates when a user tapped outside the dialog.
  static const YearMonth _cleared = YearMonth(0);

  Future<void> _pick(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;
    final int currentYear = DateTime.now().year;
    YearMonth draft = value ?? YearMonth(currentYear, DateTime.now().month);

    final YearMonth? result = await showDialog<YearMonth>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text(label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<int>(
                initialValue: draft.year,
                decoration: InputDecoration(labelText: l10n.fieldYear),
                items: <DropdownMenuItem<int>>[
                  for (int year = currentYear + 1; year >= 1955; year--)
                    DropdownMenuItem<int>(
                      value: year,
                      child: Text(
                        DateDisplay.toLocalDigits('$year', languageCode),
                      ),
                    ),
                ],
                onChanged: (int? year) => setState(() {
                  if (year != null) draft = YearMonth(year, draft.month);
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: draft.month ?? 1,
                decoration: InputDecoration(labelText: l10n.fieldMonth),
                items: <DropdownMenuItem<int>>[
                  for (int month = 1; month <= 12; month++)
                    DropdownMenuItem<int>(
                      value: month,
                      child: Text(
                        DateDisplay.monthName(month, dateSystem, languageCode),
                      ),
                    ),
                ],
                onChanged: (int? month) => setState(() {
                  if (month != null) draft = YearMonth(draft.year, month);
                }),
              ),
            ],
          ),
          actions: <Widget>[
            if (clearable)
              TextButton(
                onPressed: () => Navigator.of(context).pop(_cleared),
                child: Text(l10n.clear),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    onChanged(result.year == 0 ? null : result);
  }
}

/// A labelled switch, used for the few boolean fields a record has.
class EditorSwitchField extends StatelessWidget {
  const EditorSwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );
}

/// A labelled dropdown over one of the model's enums.
class EditorChoiceField<T> extends StatelessWidget {
  const EditorChoiceField({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: <DropdownMenuItem<T>>[
            for (final T item in values)
              DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
          ],
          onChanged: (T? next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

/// A single record in a list: title, supporting line, and the actions that
/// reorder or remove it.
class EntryTile extends StatelessWidget {
  const EntryTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: (subtitle == null || subtitle!.trim().isEmpty)
            ? null
            : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing ??
            PopupMenuButton<String>(
              tooltip: l10n.edit,
              onSelected: (String action) {
                switch (action) {
                  case 'up':
                    onMoveUp?.call();
                  case 'down':
                    onMoveDown?.call();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'up',
                  enabled: onMoveUp != null,
                  child: Text(l10n.builderDragToReorder),
                ),
                PopupMenuItem<String>(
                  value: 'down',
                  enabled: onMoveDown != null,
                  child: Text(l10n.builderSectionOrder),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  enabled: onDelete != null,
                  child: Text(l10n.delete),
                ),
              ],
            ),
      ),
    );
  }
}
