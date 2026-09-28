import 'package:json_annotation/json_annotation.dart';

/// The hiring market a CV is being written for.
///
/// Regions are *data*, not code: everything that actually differs between
/// them (photo rules, sensitive fields, paper size, date format, expected
/// length, ATS strictness) lives in `assets/data/regional_rules/*.json` and
/// is loaded by the Regional Rules Engine. This enum only names the
/// well-known bundles the app ships with, so the UI can offer them.
///
/// Adding Canada or Australia means adding a JSON file plus one more value
/// here — no core code changes.
enum RegionCode {
  @JsonValue('iran')
  iran,
  @JsonValue('europe')
  europe,
  @JsonValue('germany')
  germany,
  @JsonValue('united_kingdom')
  unitedKingdom,
  @JsonValue('united_states')
  unitedStates,
  @JsonValue('international')
  international;

  /// Asset path of the rule bundle for this region.
  String get assetPath => 'assets/data/regional_rules/$id.json';

  /// Stable snake_case identifier. This — not the Dart name — is what is
  /// written to the database, the JSON backup and the asset path, so
  /// renaming a Dart value never invalidates stored data.
  String get id => switch (this) {
    RegionCode.iran => 'iran',
    RegionCode.europe => 'europe',
    RegionCode.germany => 'germany',
    RegionCode.unitedKingdom => 'united_kingdom',
    RegionCode.unitedStates => 'united_states',
    RegionCode.international => 'international',
  };

  static RegionCode fromId(String id) => RegionCode.values.firstWhere(
        (RegionCode r) => r.id == id,
        orElse: () => RegionCode.international,
      );

  /// Regions that expect a photo on a CV by default.
  ///
  /// This is a *convention hint* surfaced in the UI, never a hard rule —
  /// the authoritative value is `photoPolicy` inside the region's JSON.
  bool get photoConventional =>
      this == RegionCode.iran ||
      this == RegionCode.germany ||
      this == RegionCode.europe;
}
