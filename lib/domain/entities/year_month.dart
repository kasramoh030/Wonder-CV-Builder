import 'package:json_annotation/json_annotation.dart';

part 'year_month.g.dart';

/// A calendar month with an *optional* day component.
///
/// CVs are written in months and years far more often than exact days
/// ("March 2019 – present"), and forcing a full date would corrupt the data
/// the moment a user only knows the year. [day] therefore stays null unless
/// the user explicitly provides it.
@JsonSerializable()
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, [this.month, this.day]);

  /// Four-digit Gregorian year.
  final int year;

  /// 1–12, or null when only the year is known.
  final int? month;

  /// 1–31, or null when only the month is known.
  final int? day;

  factory YearMonth.fromJson(Map<String, dynamic> json) => _$YearMonthFromJson(json);

  Map<String, dynamic> toJson() => _$YearMonthToJson(this);

  /// Parses `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
  static YearMonth? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final List<String> parts = raw.trim().split(RegExp('[-/.]'));
    if (parts.isEmpty) return null;
    final int? year = int.tryParse(parts[0]);
    if (year == null || year < 1900 || year > 2200) return null;
    int? month;
    int? day;
    if (parts.length > 1) {
      month = int.tryParse(parts[1]);
      if (month != null && (month < 1 || month > 12)) month = null;
    }
    if (parts.length > 2) {
      day = int.tryParse(parts[2]);
      if (day != null && (day < 1 || day > 31)) day = null;
    }
    return YearMonth(year, month, day);
  }

  /// ISO-ish canonical form: `2019`, `2019-03` or `2019-03-14`.
  String get iso {
    final String base = year.toString().padLeft(4, '0');
    if (month == null) return base;
    final String m = month.toString().padLeft(2, '0');
    if (day == null) return '$base-$m';
    return '$base-$m-${day.toString().padLeft(2, '0')}';
  }

  /// Sortable numeric key — safe across nulls.
  int get sortKey => year * 10000 + (month ?? 0) * 100 + (day ?? 0);

  bool get hasDay => day != null;

  @override
  int compareTo(YearMonth other) => sortKey.compareTo(other.sortKey);

  bool operator >(YearMonth other) => sortKey > other.sortKey;
  bool operator <(YearMonth other) => sortKey < other.sortKey;
  bool operator >=(YearMonth other) => sortKey >= other.sortKey;
  bool operator <=(YearMonth other) => sortKey <= other.sortKey;

  @override
  bool operator ==(Object other) =>
      other is YearMonth &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}
