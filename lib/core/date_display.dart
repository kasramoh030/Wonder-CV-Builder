import '../domain/entities/year_month.dart';
import '../domain/enums/document_options.dart';

/// Conversion between the Gregorian and Jalali (Solar Hijri) calendars.
///
/// The app stores dates as ISO Gregorian and only converts for display, so a
/// user who switches calendar systems never rewrites their data — and a CV
/// exported in Jalali can be re-exported in Gregorian without loss.
///
/// The algorithm is the standard arithmetic one (`jalaali-js`): a table of
/// year breaks, an arithmetic leap rule, and day-number conversion. It is
/// valid for the years this app can display (1900–2200 Gregorian) and is
/// exact across the whole range, unlike the 33-year cycle approximation that
/// drifts by a day every few centuries.
abstract final class JalaliDate {
  static const List<int> _breaks = <int>[
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097,
    2192, 2262, 2324, 2394, 2456, 3178,
  ];

  /// Truncated division and remainder, matching the reference implementation.
  static int _div(int a, int b) => a ~/ b;
  static int _mod(int a, int b) => a - (a ~/ b) * b;

  /// `[leap, gregorianYear, marchDay]` for a Jalali year.
  static List<int> _jalCal(int jy) {
    final int bl = _breaks.length;
    final int gy = jy + 621;
    int leapJ = -14;
    int jp = _breaks[0];
    int jump = 0;

    if (jy < jp || jy >= _breaks[bl - 1]) {
      // Outside the supported range the arithmetic still produces a value;
      // callers never reach here because YearMonth rejects years outside
      // 1900–2200.
      return <int>[0, gy, 20];
    }

    for (int i = 1; i < bl; i++) {
      final int jm = _breaks[i];
      jump = jm - jp;
      if (jy < jm) break;
      leapJ = leapJ + _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
      jp = jm;
    }
    int n = jy - jp;
    leapJ = leapJ + _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
    if (_mod(jump, 33) == 4 && jump - n == 4) leapJ += 1;

    final int leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
    final int march = 20 + leapJ - leapG;

    if (jump - n < 6) {
      n = n - jump + _div(jump + 4, 33) * 33;
    }
    int leap = _mod(_mod(n + 1, 33) - 1, 4);
    if (leap == -1) leap = 4;

    return <int>[leap, gy, march];
  }

  /// Julian day number for a Gregorian date.
  static int _g2d(int gy, int gm, int gd) {
    int d = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
        _div(153 * _mod(gm + 9, 12) + 2, 5) +
        gd -
        34840408;
    d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752;
    return d;
  }

  /// Gregorian `[year, month, day]` for a Julian day number.
  static List<int> _d2g(int jdn) {
    int j = 4 * jdn + 139361631;
    j = j + _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
    final int i = _div(_mod(j, 1461), 4) * 5 + 308;
    final int gd = _div(_mod(i, 153), 5) + 1;
    final int gm = _mod(_div(i, 153), 12) + 1;
    final int gy = _div(j, 1461) - 100100 + _div(8 - gm, 6);
    return <int>[gy, gm, gd];
  }

  /// Converts a Jalali date to a Julian day number.
  static int _j2d(int jy, int jm, int jd) {
    final List<int> r = _jalCal(jy);
    return _g2d(r[1], 3, r[2]) + (jm - 1) * 31 - _div(jm, 7) * (jm - 7) + jd - 1;
  }

  /// Jalali `[year, month, day]` for a Gregorian date.
  static List<int> fromGregorian(int gy, int gm, int gd) {
    final int jdn = _g2d(gy, gm, gd);
    int jy = _d2g(jdn)[0] - 621;
    final List<int> r = _jalCal(jy);
    final int jdn1f = _g2d(r[1], 3, r[2]);
    int k = jdn - jdn1f;

    if (k >= 0) {
      if (k <= 185) return <int>[jy, 1 + _div(k, 31), _mod(k, 31) + 1];
      k -= 186;
    } else {
      jy -= 1;
      k += 179;
      if (r[0] == 1) k += 1;
    }
    return <int>[jy, 7 + _div(k, 30), _mod(k, 30) + 1];
  }

  /// Gregorian `[year, month, day]` for a Jalali date.
  static List<int> toGregorian(int jy, int jm, int jd) =>
      _d2g(_j2d(jy, jm, jd));

  /// `true` when the given Jalali year is a leap year (366 days).
  static bool isLeapJalaliYear(int jy) => _jalCal(jy)[0] == 0;

  /// Number of days in a Jalali month. The first six months have 31 days, the
  /// next five 30, and Esfand has 29 or 30.
  static int daysInJalaliMonth(int jy, int jm) {
    if (jm <= 6) return 31;
    if (jm <= 11) return 30;
    return isLeapJalaliYear(jy) ? 30 : 29;
  }
}

/// Formats dates for display and for print, in either calendar and in any of
/// the three interface languages.
abstract final class DateDisplay {
  static const List<String> _gregorianEn = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];
  static const List<String> _gregorianDe = <String>[
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
    'September', 'Oktober', 'November', 'Dezember',
  ];
  static const List<String> _jalaliFa = <String>[
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان',
    'آذر', 'دی', 'بهمن', 'اسفند',
  ];
  static const List<String> _jalaliEn = <String>[
    'Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar',
    'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand',
  ];

  /// Month name for a calendar system and interface language.
  static String monthName(int month, DateSystem system, String languageCode) {
    final int index = (month - 1).clamp(0, 11);
    if (system == DateSystem.jalali) {
      return languageCode == 'fa' ? _jalaliFa[index] : _jalaliEn[index];
    }
    return switch (languageCode) {
      'de' => _gregorianDe[index],
      'fa' => _gregorianEn[index],
      _ => _gregorianEn[index],
    };
  }

  /// `Mar 2021`, `مارس ۲۰۲۱`, `مهر ۱۴۰۰`.
  static String monthYear(
    YearMonth value, {
    required DateSystem system,
    required String languageCode,
    bool short = false,
  }) {
    if (system == DateSystem.jalali) {
      final List<int> j = JalaliDate.fromGregorian(value.year, value.month ?? 1, 1);
      final String name = monthName(j[1], system, languageCode);
      return '$name ${toLocalDigits('${j[0]}', languageCode)}';
    }
    if (value.month == null) {
      return toLocalDigits('${value.year}', languageCode);
    }
    final String name = monthName(value.month!, system, languageCode);
    final String display = short ? name.substring(0, 3) : name;
    return '$display ${toLocalDigits('${value.year}', languageCode)}';
  }

  /// `Mar 2021 – Present`, `Mar 2021 – Feb 2023`, or a single date.
  static String range(
    YearMonth? start,
    YearMonth? end, {
    required bool isCurrent,
    required DateSystem system,
    required String languageCode,
    String? presentLabel,
  }) {
    const String separator = ' – ';
    final String from = start == null
        ? ''
        : monthYear(start, system: system, languageCode: languageCode);
    final String to = isCurrent
        ? (presentLabel ?? 'Present')
        : end == null
            ? ''
            : monthYear(end, system: system, languageCode: languageCode);

    if (from.isEmpty && to.isEmpty) return '';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from$separator$to';
  }

  /// Full date, for the CV header line (`14 March 2022`) or a signature block.
  static String fullDate(
    YearMonth value, {
    required DateSystem system,
    required String languageCode,
  }) {
    if (system == DateSystem.jalali) {
      final List<int> j =
          JalaliDate.fromGregorian(value.year, value.month ?? 1, value.day ?? 1);
      return '${toLocalDigits('${j[2]}', languageCode)} '
          '${monthName(j[1], system, languageCode)} '
          '${toLocalDigits('${j[0]}', languageCode)}';
    }
    return '${toLocalDigits('${value.day ?? 1}', languageCode)} '
        '${monthName(value.month ?? 1, system, languageCode)} '
        '${toLocalDigits('${value.year}', languageCode)}';
  }

  /// Persian documents are printed with Persian digits; German and English
  /// ones with ASCII digits. The user's own locale decides, not the market,
  /// because the reader is the user.
  static String toLocalDigits(String input, String languageCode) {
    if (languageCode != 'fa') return input;
    final StringBuffer out = StringBuffer();
    for (final int rune in input.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        out.writeCharCode(rune - 0x30 + 0x06F0);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// A two-digit year for the compact `2021 – 23` form used in tight rows.
  static String shortYear(int year, String languageCode) =>
      toLocalDigits('${year % 100}'.padLeft(2, '0'), languageCode);
}
