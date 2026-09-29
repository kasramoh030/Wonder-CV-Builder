import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_providers.dart';
import 'onboarding_steps.dart';

/// Four short steps, then straight into the dashboard.
///
/// The brief asks for a *short* onboarding, so every screen here earns its
/// place: language (so the rest is readable), document type and target
/// market (both of which change which sections the builder offers), and a
/// closing screen that creates the first CV. No account, no tour, no
/// permission prompts.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  // Collected answers, persisted in one write when the user finishes so an
  // abandoned onboarding leaves no partial state behind.
  String _languageCode = 'en';
  CvType _cvType = CvType.professionalCv;
  RegionCode _region = RegionCode.international;
  Industry _industry = Industry.other;

  static const int _stepCount = 4;

  @override
  void initState() {
    super.initState();
    // Start in the language the user is most likely to read, derived from
    // the device locale rather than assumed.
    final Locale device = WidgetsBinding.instance.platformDispatcher.locale;
    _languageCode = AppLocalizations.supportedLocales
            .any((Locale l) => l.languageCode == device.languageCode)
        ? device.languageCode
        : 'en';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: AppMotion.page,
      curve: AppMotion.emphasized,
    );
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding(
          languageCode: _languageCode,
          region: _region,
          cvTypeId: _cvType.id,
          industry: _industry,
        );
    // The router watches settings and redirects to the dashboard, so no
    // imperative navigation is needed here.
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.ofCode(_languageCode);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ProgressHeader(
              index: _index,
              total: _stepCount,
              onSkip: _finish,
              skipLabel: l10n.skip,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  WelcomeStep(l10n: l10n, onNext: () => _goTo(1)),
                  LanguageStep(
                    l10n: l10n,
                    selected: _languageCode,
                    onSelected: (String code) => setState(() => _languageCode = code),
                    onNext: () => _goTo(2),
                  ),
                  CvTypeStep(
                    l10n: l10n,
                    selected: _cvType,
                    industry: _industry,
                    onSelected: (CvType type) => setState(() => _cvType = type),
                    onIndustrySelected: (Industry industry) =>
                        setState(() => _industry = industry),
                    onNext: () => _goTo(3),
                  ),
                  RegionStep(
                    l10n: l10n,
                    selected: _region,
                    onSelected: (RegionCode region) => setState(() => _region = region),
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.index,
    required this.total,
    required this.onSkip,
    required this.skipLabel,
  });

  final int index;
  final int total;
  final VoidCallback onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: TweenAnimationBuilder<double>(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                tween: Tween<double>(begin: 0, end: (index + 1) / total),
                builder: (BuildContext context, double value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton(onPressed: onSkip, child: Text(skipLabel)),
        ],
      ),
    );
  }
}
