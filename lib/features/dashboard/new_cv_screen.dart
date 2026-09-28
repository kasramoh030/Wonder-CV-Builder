import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/rules/regional_rules_repository.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/resume.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_steps.dart';
import '../settings/settings_providers.dart';

/// Two questions, then the editor.
///
/// These are exactly the answers that change what the document *is* — the CV
/// type decides which sections are offered, the market decides the section
/// order, the photo rule, the paper and the date convention. Everything else
/// can be changed later from inside the builder, so asking more here would be
/// asking for the sake of asking.
class NewCvScreen extends ConsumerStatefulWidget {
  const NewCvScreen({super.key});

  @override
  ConsumerState<NewCvScreen> createState() => _NewCvScreenState();
}

class _NewCvScreenState extends ConsumerState<NewCvScreen> {
  int _step = 0;
  bool _creating = false;

  CvType _cvType = CvType.professionalCv;
  Industry _industry = Industry.other;
  RegionCode _region = RegionCode.international;

  @override
  void initState() {
    super.initState();
    // The answers the user already gave during onboarding are the defaults
    // here: creating the next CV should not ask again what was asked once.
    final AppSettings settings =
        ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
    _industry = settings.defaultIndustry;
    _region = settings.defaultRegion;
    if (settings.defaultCvType != null) {
      _cvType = CvType.fromId(settings.defaultCvType!);
    }
  }

  Future<void> _finish() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;

    setState(() => _creating = true);
    try {
      // The paper size is the market's, not a guess: a US employer expects
      // Letter, everyone else A4, and the user can override it in the builder.
      final Resume resume =
          await ref.read(resumeRepositoryProvider).create(
                title: l10n.createNewCv,
                region: _region,
                cvType: _cvType,
                industry: _industry,
                languageCode: settings.languageCode,
                templateId: ResumeTemplates.recommended(
                  region: _region,
                  cvType: _cvType,
                ).first.id,
                paperSize:
                    ref.read(regionalProfileOrNeutralProvider(_region)).paperSize,
              );

      if (!mounted) return;
      // The wizard's answers become the defaults for the next document.
      await ref.read(settingsProvider.notifier).setDefaultRegion(_region);
      await ref.read(settingsProvider.notifier).setDefaultIndustry(_industry);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.builderPath(resume.id));
    } on Object {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorStorageFailure)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (_creating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.loading),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createNewCv),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.cancel,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _step == 0
            ? CvTypeStep(
                l10n: l10n,
                selected: _cvType,
                industry: _industry,
                onSelected: (CvType type) => setState(() => _cvType = type),
                onIndustrySelected: (Industry industry) =>
                    setState(() => _industry = industry),
                onNext: () => setState(() => _step = 1),
              )
            : RegionStep(
                l10n: l10n,
                selected: _region,
                onSelected: (RegionCode region) =>
                    setState(() => _region = region),
                onFinish: _finish,
              ),
      ),
    );
  }
}
