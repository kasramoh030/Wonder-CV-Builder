import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/choice_card.dart';

/// Step 1 — what the product is and, more importantly, what it does *not* do.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({required this.l10n, required this.onNext, super.key});

  final AppLocalizations l10n;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.lgAll,
            ),
            child: Icon(
              Icons.description_rounded,
              size: 40,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(l10n.onboardingWelcomeTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.onboardingWelcomeBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _AssuranceRow(
            icon: Icons.wifi_off_rounded,
            title: l10n.onboardingOfflineTitle,
            body: l10n.onboardingOfflineBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          _AssuranceRow(
            icon: Icons.lock_outline_rounded,
            title: l10n.onboardingPrivateTitle,
            body: l10n.onboardingPrivateBody,
          ),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            child: Text(l10n.onboardingGetStarted),
          ),
        ],
      ),
    );
  }
}

class _AssuranceRow extends StatelessWidget {
  const _AssuranceRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 2 — interface language. Changing this switches the whole app,
/// including direction, before anything else has been configured.
class LanguageStep extends StatelessWidget {
  const LanguageStep({
    required this.l10n,
    required this.selected,
    required this.onSelected,
    required this.onNext,
    super.key,
  });

  final AppLocalizations l10n;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.onboardingChooseLanguage, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xl),
          for (final Locale locale in AppLocalizations.supportedLocales)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ChoiceCard(
                title: AppLocalizations.ofCode(locale.languageCode).languageName,
                subtitle: locale.languageCode.toUpperCase(),
                leading: Text(
                  AppLocalizations.ofCode(locale.languageCode).languageCodeShort,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                selected: selected == locale.languageCode,
                onTap: () => onSelected(locale.languageCode),
              ),
            ),
          const Spacer(),
          FilledButton(onPressed: onNext, child: Text(l10n.continueLabel)),
        ],
      ),
    );
  }
}

/// Step 3 — document type and industry, which together decide the default
/// section set.
class CvTypeStep extends StatelessWidget {
  const CvTypeStep({
    required this.l10n,
    required this.selected,
    required this.industry,
    required this.onSelected,
    required this.onIndustrySelected,
    required this.onNext,
    super.key,
  });

  final AppLocalizations l10n;
  final CvType selected;
  final Industry industry;
  final ValueChanged<CvType> onSelected;
  final ValueChanged<Industry> onIndustrySelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.onboardingWhatCreating, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.onboardingWhatCreatingHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final CvType type in CvType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ChoiceCard(
                      title: cvTypeLabel(l10n, type),
                      selected: selected == type,
                      compact: true,
                      onTap: () => onSelected(type),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.industryLabel, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final Industry item in Industry.values)
                      ChoiceChip(
                        label: Text(industryLabel(l10n, item)),
                        selected: industry == item,
                        onSelected: (_) => onIndustrySelected(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onNext, child: Text(l10n.continueLabel)),
        ],
      ),
    );
  }
}

/// Step 4 — the target market, which is the single most consequential
/// answer in the whole flow.
class RegionStep extends StatelessWidget {
  const RegionStep({
    required this.l10n,
    required this.selected,
    required this.onSelected,
    required this.onFinish,
    super.key,
  });

  final AppLocalizations l10n;
  final RegionCode selected;
  final ValueChanged<RegionCode> onSelected;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.onboardingWhereApplying, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.onboardingWhereApplyingHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final RegionCode region in RegionCode.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ChoiceCard(
                      title: regionLabel(l10n, region),
                      subtitle: regionHint(l10n, region),
                      leading: Text(
                        regionFlag(region),
                        style: const TextStyle(fontSize: 22),
                      ),
                      selected: selected == region,
                      onTap: () => onSelected(region),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onFinish,
            child: Text(l10n.onboardingCreateFirstCv),
          ),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Label resolvers — shared with the rest of the app so a CV type is named
// identically everywhere it appears.
// ─────────────────────────────────────────────────────────────────────────────

String cvTypeLabel(AppLocalizations l10n, CvType type) => switch (type) {
      CvType.jobResume => l10n.cvTypeJobResume,
      CvType.professionalCv => l10n.cvTypeProfessionalCv,
      CvType.academicCv => l10n.cvTypeAcademicCv,
      CvType.studentResume => l10n.cvTypeStudentResume,
      CvType.internshipResume => l10n.cvTypeInternshipResume,
      CvType.graduateResume => l10n.cvTypeGraduateResume,
      CvType.scholarshipCv => l10n.cvTypeScholarshipCv,
      CvType.researchCv => l10n.cvTypeResearchCv,
      CvType.phdCv => l10n.cvTypePhdCv,
      CvType.europass => l10n.cvTypeEuropass,
      CvType.atsResume => l10n.cvTypeAts,
    };

String regionLabel(AppLocalizations l10n, RegionCode region) => switch (region) {
      RegionCode.iran => l10n.regionIran,
      RegionCode.europe => l10n.regionEurope,
      RegionCode.germany => l10n.regionGermany,
      RegionCode.unitedKingdom => l10n.regionUnitedKingdom,
      RegionCode.unitedStates => l10n.regionUnitedStates,
      RegionCode.international => l10n.regionInternational,
    };

/// One-line explanation of what a market expects, shown under the region
/// name. Deliberately descriptive rather than prescriptive — the app never
/// claims a format is mandatory in any country.
String regionHint(AppLocalizations l10n, RegionCode region) => switch (region) {
      RegionCode.iran => 'A4 · Persian or English · photo common',
      RegionCode.europe => 'A4 · multi-country · Europass-style available',
      RegionCode.germany => 'A4 · German or English · Lebenslauf conventions',
      RegionCode.unitedKingdom => 'A4 · two pages · no photo',
      RegionCode.unitedStates => 'US Letter · one page · no photo, no personal details',
      RegionCode.international => 'A4 · neutral defaults that travel well',
    };

String regionFlag(RegionCode region) => switch (region) {
      RegionCode.iran => '🇮🇷',
      RegionCode.europe => '🇪🇺',
      RegionCode.germany => '🇩🇪',
      RegionCode.unitedKingdom => '🇬🇧',
      RegionCode.unitedStates => '🇺🇸',
      RegionCode.international => '🌍',
    };

String industryLabel(AppLocalizations l10n, Industry industry) => switch (industry) {
      Industry.softwareEngineering => 'Software Engineering',
      Industry.dataScience => 'Data Science',
      Industry.aiMl => 'AI / Machine Learning',
      Industry.cybersecurity => 'Cybersecurity',
      Industry.engineering => 'Engineering',
      Industry.medicine => 'Medicine',
      Industry.finance => 'Finance',
      Industry.accounting => 'Accounting',
      Industry.marketing => 'Marketing',
      Industry.sales => 'Sales',
      Industry.design => 'Design',
      Industry.education => 'Education',
      Industry.research => 'Research',
      Industry.legal => 'Legal',
      Industry.hospitality => 'Hospitality',
      Industry.manufacturing => 'Manufacturing',
      Industry.other => 'Other',
    };
