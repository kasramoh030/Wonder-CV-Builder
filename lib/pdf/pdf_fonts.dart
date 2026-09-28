import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A weight the app asks for by name.
///
/// The PDF engine's own [pw.FontWeight] has only `normal` and `bold`: it picks
/// a face per style instead of interpolating a variable axis. Rather than
/// losing the extra weights — which are what a heading looks like in a
/// professionally set CV — the app names the four weights its fonts actually
/// ship in, and this class maps each name to a real file. A heading that wants
/// SemiBold is then rendered with the SemiBold face standing in as that
/// style's *normal* font, so nothing depends on an axis the engine lacks.
enum CvFontWeight {
  regular,
  medium,
  semibold,
  bold;

  /// The engine's own weight, used when a style is described by weight rather
  /// than by face.
  pw.FontWeight get pdfWeight =>
      this == CvFontWeight.bold ? pw.FontWeight.bold : pw.FontWeight.normal;

  /// Heavier than this one, or the same when nothing is heavier.
  CvFontWeight get heavier => switch (this) {
        CvFontWeight.regular => CvFontWeight.medium,
        CvFontWeight.medium => CvFontWeight.semibold,
        CvFontWeight.semibold || CvFontWeight.bold => CvFontWeight.bold,
      };
}

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

  /// The faces each family ships, as asset paths.
  ///
  /// Missing entries are not a gap: Lato, Noto Sans and Open Sans are
  /// two-face families by design, and [closest] resolves a request for a
  /// weight they lack to the nearest face they do have.
  static const Map<String, Map<CvFontWeight, String>> _assets =
      <String, Map<CvFontWeight, String>>{
    'Inter': <CvFontWeight, String>{
      CvFontWeight.regular: 'assets/fonts/inter/Inter-Regular.ttf',
      CvFontWeight.medium: 'assets/fonts/inter/Inter-Medium.ttf',
      CvFontWeight.semibold: 'assets/fonts/inter/Inter-SemiBold.ttf',
      CvFontWeight.bold: 'assets/fonts/inter/Inter-Bold.ttf',
    },
    'Vazirmatn': <CvFontWeight, String>{
      CvFontWeight.regular: 'assets/fonts/vazirmatn/Vazirmatn-Regular.ttf',
      CvFontWeight.medium: 'assets/fonts/vazirmatn/Vazirmatn-Medium.ttf',
      CvFontWeight.semibold: 'assets/fonts/vazirmatn/Vazirmatn-SemiBold.ttf',
      CvFontWeight.bold: 'assets/fonts/vazirmatn/Vazirmatn-Bold.ttf',
    },
    'Lato': <CvFontWeight, String>{
      CvFontWeight.regular: 'assets/fonts/lato/Lato-Regular.ttf',
      CvFontWeight.bold: 'assets/fonts/lato/Lato-Bold.ttf',
    },
    'Noto Sans': <CvFontWeight, String>{
      CvFontWeight.regular: 'assets/fonts/notosans/NotoSans-Regular.ttf',
      CvFontWeight.bold: 'assets/fonts/notosans/NotoSans-Bold.ttf',
    },
    'Open Sans': <CvFontWeight, String>{
      CvFontWeight.regular: 'assets/fonts/opensans/OpenSans-Regular.ttf',
      CvFontWeight.bold: 'assets/fonts/opensans/OpenSans-Bold.ttf',
    },
  };

  /// Families that actually contain Persian glyphs, and so may be used for a
  /// right-to-left document. A Latin-only family is never silently used for
  /// Persian text: the engine picks [persianFamily] instead.
  static const Set<String> rtlCapable = <String>{'Vazirmatn', 'Noto Sans'};

  /// `true` when [family] renders Persian correctly.
  static bool supportsPersian(String family) => rtlCapable.contains(family);

  /// The family a document is really set in; an unknown name means Inter, so
  /// an old document that names a removed family still exports.
  static String resolveFamily(String family) =>
      _assets.containsKey(family) ? family : 'Inter';

  /// Loads one face of one family.
  ///
  /// `rootBundle.load` gives a ByteData that [pw.Font.ttf] embeds verbatim:
  /// the glyphs travel inside the PDF, so the file is portable and its text
  /// stays selectable and searchable on the reviewer's machine.
  static Future<pw.Font> font(
    String family, [
    CvFontWeight weight = CvFontWeight.regular,
  ]) async {
    final Map<CvFontWeight, String> faces = _assets[resolveFamily(family)]!;
    return _load(faces, weight);
  }

  /// The nearest face a family ships to the requested weight.
  ///
  /// Walks outwards from the request — up and down together — so a two-face
  /// family answers a request for Medium with Regular and a request for
  /// SemiBold with Bold, rather than always collapsing to one of the two.
  static CvFontWeight closest(
    Map<CvFontWeight, String> faces,
    CvFontWeight wanted,
  ) {
    final int target = wanted.index;
    for (int distance = 1; distance < CvFontWeight.values.length; distance++) {
      for (final int candidate in <int>[target - distance, target + distance]) {
        if (candidate >= 0 &&
            candidate < CvFontWeight.values.length &&
            faces.containsKey(CvFontWeight.values[candidate])) {
          return CvFontWeight.values[candidate];
        }
      }
    }
    return CvFontWeight.regular;
  }

  /// Loads a complete [pw.ThemeData] for a family.
  ///
  /// [family] is a UI-facing name; unknown names fall back to Inter so an old
  /// document that names a removed family still exports. [rtlPreferredFamily]
  /// is the family to switch to when the document is right-to-left and the
  /// chosen family has no Persian glyphs.
  static Future<pw.ThemeData> themeFor(
    String family, {
    String? rtlPreferredFamily,
  }) async {
    final String base = resolveFamily(family);
    final String resolved = rtlPreferredFamily == null
        ? base
        : (rtlCapable.contains(base) ? base : resolveFamily(rtlPreferredFamily));
    final Map<CvFontWeight, String> faces = _assets[resolved]!;

    final pw.Font regular = await _load(faces, CvFontWeight.regular);
    // Headings are what the reader scans, so the bold face is SemiBold where
    // the family ships it and true Bold otherwise. Body emphasis — a job title
    // against a company name — still reads as heavier than the paragraph.
    final pw.Font bold = await _load(faces, CvFontWeight.semibold);

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
      fontFallback: <pw.Font>[
        // Persian text inside an otherwise Latin document still needs a face
        // that has the glyphs, and vice versa. Both fallbacks are bundled, so
        // this holds on a device with no Persian system font at all.
        if (resolved != persianFamily)
          await _load(_assets[persianFamily]!, CvFontWeight.regular),
        if (resolved != 'Inter') await _load(_assets['Inter']!, CvFontWeight.regular),
      ],
    );
  }

  static Future<pw.Font> _load(
    Map<CvFontWeight, String> faces,
    CvFontWeight weight,
  ) async =>
      pw.Font.ttf(
        await rootBundle.load(faces[weight] ?? faces[closest(faces, weight)]!),
      );
}

/// Page geometry for a paper size, in PostScript points.
///
/// The region profile decides which one, and the user can override it per
/// document: plenty of candidates print a US-style CV on A4 stock at home.
PdfPageFormat pageFormatFor(double widthPt, double heightPt) =>
    PdfPageFormat(widthPt, heightPt, marginAll: 0);
