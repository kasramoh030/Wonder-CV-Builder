import 'package:json_annotation/json_annotation.dart';

import '../enums/document_options.dart';
import '../enums/industry.dart';
import '../enums/region_code.dart';

part 'app_settings.g.dart';

/// Everything the user can configure about the app itself.
///
/// Kept separate from CV content: settings live in `SharedPreferences`
/// (tiny, synchronous, and readable before the first frame) while documents
/// live in the database.
@JsonSerializable()
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'en',
    this.defaultRegion = RegionCode.international,
    this.defaultCvType,
    this.defaultIndustry = Industry.other,
    this.defaultPaperSize = PaperSize.a4,
    this.dateSystem = DateSystem.gregorian,
    this.documentFontFamily = 'Inter',
    this.lastOpenedResumeId,
    this.aiProviderId = 'openai',
    this.aiModel = '',
    this.aiConsentGranted = false,
    this.analyticsEnabled = false,
  });

  // ── Onboarding ───────────────────────────────────────────────────────────
  final bool onboardingCompleted;

  /// The CV type chosen during onboarding, reused as the default for the
  /// first "Create CV" flow so the user is not asked twice.
  final String? defaultCvType;

  // ── Presentation ─────────────────────────────────────────────────────────
  final AppThemeMode themeMode;
  final String languageCode;

  // ── Document defaults ────────────────────────────────────────────────────
  final RegionCode defaultRegion;
  final Industry defaultIndustry;
  final PaperSize defaultPaperSize;
  final DateSystem dateSystem;
  final String documentFontFamily;

  /// Resume most recently opened, used to restore context on cold start.
  final String? lastOpenedResumeId;

  // ── Optional online features ─────────────────────────────────────────────
  /// Identifier of the configured AI provider. The API key itself is *never*
  /// stored here — it lives in the platform keystore.
  final String aiProviderId;
  final String aiModel;

  /// Explicit, revocable consent for sending text to a remote provider.
  /// Reset to false whenever the user deletes all data.
  final bool aiConsentGranted;

  /// Reserved. Defaults to off and is not wired to any third-party SDK in
  /// this build — a privacy-first product ships with telemetry disabled.
  final bool analyticsEnabled;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    bool? onboardingCompleted,
    AppThemeMode? themeMode,
    String? languageCode,
    RegionCode? defaultRegion,
    String? defaultCvType,
    Industry? defaultIndustry,
    PaperSize? defaultPaperSize,
    DateSystem? dateSystem,
    String? documentFontFamily,
    String? lastOpenedResumeId,
    String? aiProviderId,
    String? aiModel,
    bool? aiConsentGranted,
    bool? analyticsEnabled,
    bool clearLastOpened = false,
    bool clearDefaultCvType = false,
  }) =>
      AppSettings(
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
        defaultRegion: defaultRegion ?? this.defaultRegion,
        defaultCvType: clearDefaultCvType ? null : (defaultCvType ?? this.defaultCvType),
        defaultIndustry: defaultIndustry ?? this.defaultIndustry,
        defaultPaperSize: defaultPaperSize ?? this.defaultPaperSize,
        dateSystem: dateSystem ?? this.dateSystem,
        documentFontFamily: documentFontFamily ?? this.documentFontFamily,
        lastOpenedResumeId:
            clearLastOpened ? null : (lastOpenedResumeId ?? this.lastOpenedResumeId),
        aiProviderId: aiProviderId ?? this.aiProviderId,
        aiModel: aiModel ?? this.aiModel,
        aiConsentGranted: aiConsentGranted ?? this.aiConsentGranted,
        analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      );
}
