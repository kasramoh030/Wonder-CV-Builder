import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../domain/enums/document_options.dart';
import '../../../domain/templates/resume_template.dart';
import '../../../l10n/app_localizations.dart';
import 'template_wireframe.dart';

/// One entry in the template gallery.
class TemplateCard extends StatelessWidget {
  const TemplateCard({required this.template, this.onTap, this.selected = false, super.key});

  final ResumeTemplate template;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = templateName(l10n, template);

    return Semantics(
      label: '$name. ${templateAtsLabel(l10n, template.atsSafety)}',
      button: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: TemplateWireframe(template: template),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        templateAtsLabel(l10n, template.atsSafety),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (template.premium) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              l10n.templatesPremium,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

String templateName(AppLocalizations l10n, ResumeTemplate template) =>
    switch (template.id) {
      'professional' => 'Professional',
      'modern' => 'Modern',
      'minimal' => 'Minimal',
      'executive' => 'Executive',
      'ats' => 'ATS',
      'academic' => 'Academic',
      'european' => 'European',
      'europass' => 'Europass-style',
      'german' => 'German Lebenslauf',
      'uk' => 'UK CV',
      'us_resume' => 'US Resume',
      'creative' => 'Creative',
      _ => template.id,
    };

String templateAtsLabel(AppLocalizations l10n, AtsSafety safety) =>
    switch (safety) {
      AtsSafety.atsSafe => l10n.templatesAtsSafe,
      AtsSafety.atsFriendly => l10n.templatesCategoryProfessional,
      AtsSafety.decorative => l10n.templatesCategoryCreative,
    };

String templateLayoutLabel(AppLocalizations l10n, ResumeTemplate template) =>
    template.isSingleColumn
        ? l10n.templatesSingleColumn
        : l10n.templatesTwoColumn;
