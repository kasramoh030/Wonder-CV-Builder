import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/regional_profile.dart';
import '../../domain/enums/region_code.dart';

/// Loads the bundled regional rule bundles.
///
/// The rules are content, not code: every market the app supports is one JSON
/// file under `assets/data/regional_rules/`, and adding Canada or Australia
/// means adding a file plus a [RegionCode] value — no change to the analyzer,
/// the PDF engine or this class. That is what makes the rule set extensible
/// without a release of the whole engine.
///
/// Loading never throws. A missing, unreadable or malformed bundle degrades to
/// the neutral international profile so the offline path (create CV → analyze →
/// export PDF) keeps working on a device where, for whatever reason, one asset
/// did not ship.
class RegionalRulesRepository {
  RegionalRulesRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Parsed bundles, keyed by region. Regional rules are immutable once
  /// shipped, so a map is enough — the cache lives as long as the provider
  /// container that owns this repository.
  final Map<RegionCode, RegionalProfile> _cache = <RegionCode, RegionalProfile>{};

  /// In-flight loads, so a burst of parallel requests for the same region
  /// reads the asset once.
  final Map<RegionCode, Future<RegionalProfile>> _inFlight =
      <RegionCode, Future<RegionalProfile>>{};

  /// The bundle for [region], read from the asset store on first use.
  Future<RegionalProfile> load(RegionCode region) {
    final RegionalProfile? cached = _cache[region];
    if (cached != null) return Future<RegionalProfile>.value(cached);

    return _inFlight.putIfAbsent(region, () async {
      try {
        final String raw = await _bundle.loadString(region.assetPath);
        final RegionalProfile profile = RegionalProfile.parse(raw);
        _cache[region] = profile;
        return profile;
      } on Object catch (error, stack) {
        // A missing asset is a packaging bug, not a user-facing failure. Log
        // it in debug builds and hand back the neutral profile.
        assert(() {
          debugPrint('RegionalRulesRepository: ${region.assetPath} failed: $error');
          debugPrintStack(stackTrace: stack);
          return true;
        }());
        final RegionalProfile fallback = const RegionalProfile(id: 'international');
        _cache[region] = fallback;
        return fallback;
      } finally {
        _inFlight.remove(region);
      }
    });
  }

  /// The bundle for [region], synchronous if it has already been read.
  ///
  /// Widgets and the analyzer call this after a first [load]; before that they
  /// receive the neutral profile rather than a spinner, because every rule
  /// field has a sensible neutral default.
  RegionalProfile cached(RegionCode region) =>
      _cache[region] ?? const RegionalProfile(id: 'international');

  /// Every bundled market, for the analyzer's "what differs" explainers.
  Future<List<RegionalProfile>> loadAll() => Future.wait(
        RegionCode.values.map(load),
      );

  /// Drops cached rules. Used by tests and by the "reset app data" flow.
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

/// Assets for the regional bundles are read from the app bundle in production
/// and from a fixture bundle in tests.
final Provider<RegionalRulesRepository> regionalRulesRepositoryProvider =
    Provider<RegionalRulesRepository>((Ref ref) => RegionalRulesRepository());

/// The rules for the user's current default market, resolved asynchronously.
///
/// Screens that can render a sensible neutral state immediately should read
/// [regionalProfileOrNeutralProvider] instead and let this one settle in the
/// background.
final FutureProviderFamily<RegionalProfile, RegionCode> regionalProfileProvider =
    FutureProvider.family<RegionalProfile, RegionCode>(
  (Ref ref, RegionCode region) => ref.watch(regionalRulesRepositoryProvider).load(region),
);

/// The already-parsed rules for [region], or the neutral profile.
final ProviderFamily<RegionalProfile, RegionCode> regionalProfileOrNeutralProvider =
    Provider.family<RegionalProfile, RegionCode>(
  (Ref ref, RegionCode region) =>
      ref.watch(regionalRulesRepositoryProvider).cached(region),
);

/// Where the international (neutral) bundle lives, for callers that want an
/// explicit fallback instead of an implicit one.
const String kNeutralRegionalRulesAsset = 'assets/data/regional_rules/international.json';
