import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/template_card.dart';

final StateProvider<TemplateCategory?> templateFilterProvider =
    StateProvider<TemplateCategory?>((Ref ref) => null);

/// The template gallery.
///
/// Shows a miniature *wireframe* of each layout rather than a screenshot:
/// the preview is drawn from the same [ResumeLayout] value the PDF engine
/// uses, so the thumbnail can never drift out of sync with the real output.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TemplateCategory? filter = ref.watch(templateFilterProvider);

    final List<ResumeTemplate> visible = filter == null
        ? ResumeTemplates.all
        : ResumeTemplates.all
            .where((ResumeTemplate t) => t.category == filter)
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.templatesTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(l10n.templatesAllCategories),
                    selected: filter == null,
                    onSelected: (_) =>
                        ref.read(templateFilterProvider.notifier).state = null,
                  ),
                ),
                for (final TemplateCategory category in TemplateCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(templateCategoryLabel(l10n, category)),
                      selected: filter == category,
                      onSelected: (_) => ref
                          .read(templateFilterProvider.notifier)
                          .state = filter == category ? null : category,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.62,
              ),
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int index) => TemplateCard(
                template: visible[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String templateCategoryLabel(AppLocalizations l10n, TemplateCategory category) =>
    switch (category) {
      TemplateCategory.professional => l10n.templatesCategoryProfessional,
      TemplateCategory.modern => l10n.templatesCategoryModern,
      TemplateCategory.academic => l10n.templatesCategoryAcademic,
      TemplateCategory.regional => l10n.templatesCategoryRegional,
      TemplateCategory.creative => l10n.templatesCategoryCreative,
    };
