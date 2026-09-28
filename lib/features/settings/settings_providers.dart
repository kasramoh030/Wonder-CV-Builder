import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/settings_store.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/industry.dart';
import '../../domain/enums/region_code.dart';

/// The platform preferences instance.
///
/// Resolved once and cached by Riverpod; every consumer awaits the same
/// future, so there is exactly one disk read per process.
final Provider<Future<SharedPreferences>> sharedPreferencesProvider =
    Provider<Future<SharedPreferences>>((Ref ref) => SharedPreferences.getInstance());

final Provider<Future<SettingsStore>> settingsStoreProvider =
    Provider<Future<SettingsStore>>((Ref ref) async {
  final SharedPreferences prefs = await ref.watch(sharedPreferencesProvider);
  return SettingsStore(prefs);
});

/// Reads and mutates [AppSettings].
///
/// Exposed as an [AsyncNotifier] so the first frame can render before the
/// settings have been read from disk, and so writes are serialised behind a
/// single state object rather than scattered `setState` calls.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final SettingsStore store = await ref.watch(settingsStoreProvider);
    return store.read();
  }

  SettingsStore? _store;

  Future<SettingsStore> _resolveStore() async {
    final SettingsStore resolved = _store ?? await ref.read(settingsStoreProvider);
    _store = resolved;
    return resolved;
  }

  /// Applies [mutate] to the current settings, persists, and publishes.
  ///
  /// Named `patch` rather than `update` because `AsyncNotifier` already
  /// defines `update`, with different semantics.
  Future<void> patch(AppSettings Function(AppSettings current) mutate) async {
    final AppSettings current = state.valueOrNull ?? AppSettings.defaults;
    final AppSettings next = mutate(current);
    state = AsyncData<AppSettings>(next);
    final SettingsStore store = await _resolveStore();
    await store.write(next);
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      patch((AppSettings s) => s.copyWith(themeMode: mode));

  Future<void> setLanguage(String languageCode) =>
      patch((AppSettings s) => s.copyWith(languageCode: languageCode));

  Future<void> setDefaultRegion(RegionCode region) =>
      patch((AppSettings s) => s.copyWith(defaultRegion: region));

  Future<void> setDefaultIndustry(Industry industry) =>
      patch((AppSettings s) => s.copyWith(defaultIndustry: industry));

  Future<void> setDefaultPaperSize(PaperSize size) =>
      patch((AppSettings s) => s.copyWith(defaultPaperSize: size));

  Future<void> setDateSystem(DateSystem system) =>
      patch((AppSettings s) => s.copyWith(dateSystem: system));

  Future<void> setDocumentFont(String family) =>
      patch((AppSettings s) => s.copyWith(documentFontFamily: family));

  Future<void> completeOnboarding({
    required String languageCode,
    required RegionCode region,
    required String cvTypeId,
    required Industry industry,
  }) =>
      update(
        (AppSettings s) => s.copyWith(
          onboardingCompleted: true,
          languageCode: languageCode,
          defaultRegion: region,
          defaultCvType: cvTypeId,
          defaultIndustry: industry,
        ),
      );

  Future<void> restartOnboarding() =>
      patch((AppSettings s) => s.copyWith(onboardingCompleted: false));

  Future<void> setLastOpenedResume(String? id) => patch(
        (AppSettings s) => id == null
            ? s.copyWith(clearLastOpened: true)
            : s.copyWith(lastOpenedResumeId: id),
      );

  Future<void> setAiConsent({required bool granted}) =>
      patch((AppSettings s) => s.copyWith(aiConsentGranted: granted));

  Future<void> setAiProvider({required String providerId, String? model}) => patch(
        (AppSettings s) => s.copyWith(
          aiProviderId: providerId,
          aiModel: model ?? s.aiModel,
        ),
      );

  /// Wipes settings back to defaults. Used by "delete all data".
  Future<void> reset() async {
    state = const AsyncData<AppSettings>(AppSettings.defaults);
    final SettingsStore store = await _resolveStore();
    await store.clear();
  }
}

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Convenience selector for the resolved theme mode.
final Provider<AppThemeMode> themeModeProvider = Provider<AppThemeMode>(
  (Ref ref) =>
      ref.watch(settingsProvider).valueOrNull?.themeMode ?? AppThemeMode.system,
);

/// Convenience selector for the UI language.
final Provider<Locale> uiLocaleProvider = Provider<Locale>((Ref ref) {
  final AppSettings settings =
      ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
  return Locale(settings.languageCode);
});
