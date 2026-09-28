import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font families a document may be set in, and the files that back them.
///
/// Every family ships inside the APK, so a CV is rendered identically on a
/// device that has never been online, on a phone whose system fonts do not
/// include Persian, and on a reviewer's desktop. Nothing here reaches the
/// network, and nothing falls back to a font the device happens to have.
abstract final class PdfFonts {
  /// Latin families the user can choose from.
  static const List<String> latinFamilies = <String>[
    'Inter',
    'Lato',
    'Noto Sans',
    'Open Sans',
  ];

  /// The family used for Persian, Arabic and mixed Persian/Latin documents.
  ///
  /// Vazirmatn is not a stylistic choice here: it is one of the few open
  /// families with a complete Arabic-script coverage set that also shapes
  /// correctly in the PDF engine, so a Persian CV never renders as boxes or
  /// as disconnected letters.
  static const String persianFamily = 'Vazirmatn';

  /// Weights available per family, mapped to the asset path.
  static const Map<String, Map<pw.FontWeight, String>> _weights =
      <String, Map<pw.FontWeight, String>>{
    'Inter': <pw.FontWeight, String>{
      pw.FontWeight.normal: 'assets/fonts/inter/Inter-Regular.ttf',
      pw.FontWeight.medium: 'assets/fonts/inter/Inter-Medium.ttf',
      pw.FontWeight.semibold: 'assets/fonts/inter/Inter-SemiBold.ttf',
      pw.FontWeight.bold: 'assets/fonts/inter/Inter-Bold.ttf',
    },
    'Vazirmatn': <pw.FontWeight, String>{
      pw.FontWeight.normal: 'assets/fonts/vazirmatn/Vazirmatn-Regular.ttf',
      pw.FontWeight.medium: 'assets/fonts/vazirmatn/Vazirmatn-Medium.ttf',
      pw.FontWeight.semibold: 'assets/fonts/vazirmatn/Vazirmatn-SemiBold.ttf',
      pw.FontWeight.bold: 'assets/fonts/vazirmatn/Vazirmatn-Bold.ttf',
    },
    'Lato': <pw.FontWeight, String>{
      pw.FontWeight.normal: 'assets/fonts/lato/Lato-Regular.ttf',
      pw.FontWeight.bold: 'assets/fonts/lato/Lato-Bold.ttf',
    },
    'Noto Sans': <pw.FontWeight, String>{
      pw.FontWeight.normal: 'assets/fonts/notosans/NotoSans-Regular.ttf',
      pw.FontWeight.bold: 'assets/fonts/notosans/NotoSans-Bold.ttf',
    },
    'Open Sans': <pw.FontWeight, String>{
      pw.FontWeight.normal: 'assets/fonts/opensans/OpenSans-Regular.ttf',
      pw.FontWeight.bold: 'assets/fonts/opensans/OpenSans-Bold.ttf',
    },
  };

  /// Families that actually contain Persian glyphs, and so may be used for a
  /// right-to-left document. A Latin-only family is never silently used for
  /// Persian text: the engine picks [persianFamily] instead.
  static const Set<String> rtlCapable = <String>{'Vazirmatn', 'Noto Sans'};

  /// The closest available weight to a request, so a family with only two
  /// weights still renders a semibold heading as something sensible.
  static pw.FontWeight resolveWeight(pw.FontWeight requested) {
    if (requested == pw.FontWeight.semibold) return pdfSemibold;
    return requested;
  }

  /// Semibold, falling back to bold on families that do not ship it.
  static const pw.FontWeight pdfSemibold = pw.FontWeight.bold;

  /// Loads a complete [pw.ThemeData] for a family.
  ///
  /// [family] is a UI-facing name; unknown names fall back to Inter so an old
  /// document that names a removed family still exports.
  static Future<pw.ThemeData> themeFor(
    String family, {
    String? rtlPreferredFamily,
  }) async {
    final String base = _existingFamily(family);
    final String resolved = rtlPreferredFamily == null
        ? base
        : (rtlCapable.contains(base) ? base : _existingFamily(rtlPreferredFamily));

    final Map<pw.FontWeight, String> weights = _weights[resolved]!;
    final pw.Font normal = await _font(weights, pw.FontWeight.normal);
    final pw.Font bold = await _font(weights, pw.FontWeight.bold);

    // A family with a single weight still needs a bold face; reusing the
    // regular face with a vector stroke is not something the PDF engine
    // supports, so headings simply render at the same weight rather than
    // failing to embed a font.
    final pw.Font medium = weights.containsKey(pw.FontWeight.medium)
        ? await _font(weights, pw.FontWeight.medium)
        : normal;

    return pw.ThemeData.withFont(
      base: normal,
      bold: bold,
      italic: normal,
      boldItalic: bold,
      fontFallback: <pw.Font>[
        // Persian text inside an otherwise Latin document still needs a face
        // that has the glyphs, and vice versa.
        if (resolved != 'Vazirmatn')
          await _font(_weights['Vazirmatn']!, pw.FontWeight.normal),
        if (resolved != 'Inter') await _font(_weights['Inter']!, pw.FontWeight.normal),
        medium,
      ],
    );
  }

  /// `true` when [family] renders Persian correctly.
  static bool supportsPersian(String family) => rtlCapable.contains(family);

  static String _existingFamily(String family) =>
      _weights.containsKey(family) ? family : 'Inter';

  static Future<pw.Font> _font(
    Map<pw.FontWeight, String> weights,
    pw.FontWeight weight,
  ) async {
    final String path = weights[weight] ??
        weights[pw.FontWeight.normal] ??
        weights.values.first;
    // `rootBundle.load` gives a ByteData that pw.Font.ttf embeds verbatim:
    // the glyphs travel inside the PDF, so the file is portable and its text
    // stays selectable and searchable.
    return pw.Font.ttf(await rootBundle.load(path));
  }
}

/// Page geometry for a paper size, in PostScript points.
///
/// The region profile decides which one, and the user can override it per
/// document: plenty of candidates print a US-style CV on A4 stock at home.
PdfPageFormat pageFormatFor(double widthPt, double heightPt) =>
    PdfPageFormat(widthPt, heightPt, marginAll: 0);
