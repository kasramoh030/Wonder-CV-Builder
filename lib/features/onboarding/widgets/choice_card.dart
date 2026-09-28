import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// A selectable row used by every onboarding picker.
///
/// Built as a "radio card" rather than a list of radios because the target
/// here is a phone held one-handed: the whole row is the hit target, which
/// comfortably clears the 48dp minimum.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.compact = false,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool compact;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color border =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final Color background = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : theme.colorScheme.surface;

    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Material(
        color: background,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.mdAll,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: compact ? AppSpacing.md : AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: border,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing ??
                    AnimatedSwitcher(
                      duration: AppMotion.instant,
                      child: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey<String>('selected'),
                              color: theme.colorScheme.primary,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              key: const ValueKey<String>('unselected'),
                              color: theme.colorScheme.outline,
                            ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
