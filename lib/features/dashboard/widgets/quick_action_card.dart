import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// A tappable entry point on the dashboard.
///
/// Two visual weights are supported: [emphasised] for the primary "create"
/// action, and the default for the secondary shortcuts. Both are built to
/// the 88dp minimum height so the dashboard is usable one-handed.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.emphasised = false,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool emphasised;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = emphasised
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final Color foreground =
        emphasised ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;

    return Material(
      color: background,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: emphasised
                  ? theme.colorScheme.primary.withValues(alpha: 0.25)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(icon, size: 22, color: foreground),
                      const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(color: foreground),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withValues(alpha: 0.75),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
