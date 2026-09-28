import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Temporary scaffold used by screens whose controller layer has not landed
/// yet.
///
/// It is intentionally obvious — an app that ships this widget to a user is
/// an app with a bug, and a placeholder that looks finished is how
/// unfinished features reach production.
class UnderConstruction extends StatelessWidget {
  const UnderConstruction({
    required this.title,
    this.subtitle,
    this.icon = Icons.construction_rounded,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppLocalizations.of(context).loading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
