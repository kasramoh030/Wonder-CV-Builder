import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/templates/resume_template.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_steps.dart';
import 'settings_providers.dart';
import 'widgets/settings_section.dart';

/// Settings are grouped by the question the user is asking, not by the
/// module that implements them: how it looks, what it produces, and what it
/// does with their data.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: AppSpacing.screen,
        children: <Widget>[
          SettingsSection(
            title: l10n.settingsAppearance,
            children: <Widget>[
              SettingsTile(
                icon: Icons.brightness_6_outlined,
                title: l10n.settingsTheme,
                subtitle: themeModeLabel(l10n, settings.themeMode),
                trailing: SegmentedButton<AppThemeMode>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<AppThemeMode>>[
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                      tooltip: l10n.settingsThemeSystem,
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined, size: 18),
                      tooltip: l10n.settingsThemeLight,
                    ),
                    ButtonSegment<AppThemeMode>(
                      value: AppThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined, size: 18),
                      tooltip: l10n.settingsThemeDark,
                    ),
                  ],
                  selected: <AppThemeMode>{settings.themeMode},
                  onSelectionChanged: (Set<AppThemeMode> selection) =>
                      controller.setThemeMode(selection.first),
                ),
              ),
              SettingsTile(
                icon: Icons.translate_rounded,
                title: l10n.settingsLanguage,
                subtitle: l10n.languageName,
                trailing: DropdownButton<String>(
                  value: settings.languageCode,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String>>[
                    for (final Locale locale in AppLocalizations.supportedLocales)
                      DropdownMenuItem<String>(
                        value: locale.languageCode,
                        child: Text(
                          AppLocalizations.ofCode(locale.languageCode).languageName,
                        ),
                      ),
                  ],
                  onChanged: (String? code) {
                    if (code != null) controller.setLanguage(code);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.exportTitle,
            children: <Widget>[
              SettingsTile(
                icon: Icons.public_rounded,
                title: l10n.settingsDefaultRegion,
                subtitle: regionLabel(l10n, settings.defaultRegion),
                trailing: _RegionPicker(
                  value: settings.defaultRegion,
                  onChanged: controller.setDefaultRegion,
                ),
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                title: l10n.settingsDefaultPaperSize,
                subtitle: settings.defaultPaperSize == PaperSize.a4
                    ? l10n.paperA4
                    : l10n.paperLetter,
                trailing: DropdownButton<PaperSize>(
                  value: settings.defaultPaperSize,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<PaperSize>>[
                    const DropdownMenuItem<PaperSize>(
                      value: PaperSize.a4,
                      child: Text('A4'),
                    ),
                    const DropdownMenuItem<PaperSize>(
                      value: PaperSize.usLetter,
                      child: Text('Letter'),
                    ),
                  ],
                  onChanged: (PaperSize? size) {
                    if (size != null) controller.setDefaultPaperSize(size);
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.edit_calendar_outlined,
                title: l10n.settingsDateSystem,
                subtitle: settings.dateSystem == DateSystem.gregorian
                    ? l10n.dateSystemGregorian
                    : l10n.dateSystemJalali,
                trailing: DropdownButton<DateSystem>(
                  value: settings.dateSystem,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<DateSystem>>[
                    DropdownMenuItem<DateSystem>(
                      value: DateSystem.gregorian,
                      child: Text(l10n.dateSystemGregorian),
                    ),
                    DropdownMenuItem<DateSystem>(
                      value: DateSystem.jalali,
                      child: Text(l10n.dateSystemJalali),
                    ),
                  ],
                  onChanged: (DateSystem? system) {
                    if (system != null) controller.setDateSystem(system);
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.text_fields_rounded,
                title: l10n.settingsDocumentFont,
                subtitle: settings.documentFontFamily,
                trailing: DropdownButton<String>(
                  value: _knownFont(settings.documentFontFamily),
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String>>[
                    for (final String family in _documentFonts)
                      DropdownMenuItem<String>(
                        value: family,
                        child: Text(family),
                      ),
                  ],
                  onChanged: (String? family) {
                    if (family != null) controller.setDocumentFont(family);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.privacyTitle,
            children: <Widget>[
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: l10n.privacyLocalFirst,
                subtitle: l10n.privacyLocalFirstBody,
              ),
              SettingsTile(
                icon: Icons.person_off_outlined,
                title: l10n.privacyNoAccount,
                subtitle: l10n.privacyNoAccountBody,
              ),
              SettingsTile(
                icon: Icons.restart_alt_rounded,
                title: l10n.settingsResetOnboarding,
                onTap: controller.restartOnboarding,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.settingsAbout,
            children: <Widget>[
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: l10n.settingsVersion,
                subtitle: '1.0.0 (1)',
              ),
              SettingsTile(
                icon: Icons.font_download_outlined,
                title: l10n.settingsLicences,
                subtitle: l10n.settingsLicencesBody,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Guards against a font family stored by a future version that this build
  /// does not know about, which would otherwise crash the dropdown.
  static String _knownFont(String family) =>
      _documentFonts.contains(family) ? family : _documentFonts.first;

  static const List<String> _documentFonts = <String>[
    'Inter',
    'Vazirmatn',
    'Lato',
    'Noto Sans',
    'Open Sans',
  ];
}

class _RegionPicker extends StatelessWidget {
  const _RegionPicker({required this.value, required this.onChanged});

  final RegionCode value;
  final ValueChanged<RegionCode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DropdownButton<RegionCode>(
      value: value,
      underline: const SizedBox.shrink(),
      items: <DropdownMenuItem<RegionCode>>[
        for (final RegionCode region in RegionCode.values)
          DropdownMenuItem<RegionCode>(
            value: region,
            child: Text(regionLabel(l10n, region)),
          ),
      ],
      onChanged: (RegionCode? region) {
        if (region != null) onChanged(region);
      },
    );
  }
}

String themeModeLabel(AppLocalizations l10n, AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => l10n.settingsThemeSystem,
      AppThemeMode.light => l10n.settingsThemeLight,
      AppThemeMode.dark => l10n.settingsThemeDark,
    };

/// Exposed so the template gallery can show a template's default font as a
/// human-readable value.
String templateFontLabel(ResumeTemplate template) => template.fontFamily;
