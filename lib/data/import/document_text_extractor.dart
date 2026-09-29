import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// The file kinds the importer understands.
enum ImportFormat { pdf, docx, txt, image, unknown }

/// A failure the user can be told about.
///
/// The code is a stable identifier resolved to a localised sentence by the
/// screen, the same way analyser findings work.
class ImportFailure implements Exception {
  const ImportFailure(this.code);

  final String code;

  @override
  String toString() => 'ImportFailure($code)';
}

/// Turns a file the user picked into plain text.
///
/// Everything here runs on the device: DOCX is unzipped and read, PDF streams
/// are inflated and their text operators decoded, plain text is read as it is.
/// Images are refused rather than guessed at — optical character recognition
/// needs a native model that this build does not ship, and inventing text from
/// a picture would be worse than saying so.
abstract final class DocumentTextExtractor {
  /// Refuse absurd files before spending memory on them. A CV is never 25 MB.
  static const int maxBytes = 25 * 1024 * 1024;

  static ImportFormat formatFor(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0) return ImportFormat.unknown;
    return switch (fileName.substring(dot + 1).toLowerCase()) {
      'pdf' => ImportFormat.pdf,
      'docx' => ImportFormat.docx,
      'txt' || 'text' || 'md' || 'rtf' => ImportFormat.txt,
      'png' || 'jpg' || 'jpeg' || 'webp' || 'heic' || 'heif' || 'bmp' =>
        ImportFormat.image,
      _ => ImportFormat.unknown,
    };
  }

  /// Reads [file] and returns its text.
  ///
  /// Throws [ImportFailure] with a localisable code when the file cannot be
  /// read, is too large, or is a format this build cannot parse.
  static Future<String> extract(File file, ImportFormat format) async {
    if (format == ImportFormat.image) {
      throw const ImportFailure('importOcrUnavailable');
    }
    if (format == ImportFormat.unknown) {
      throw const ImportFailure('errorUnsupportedFormat');
    }
    final int length = await file.length();
    if (length > maxBytes) {
      throw const ImportFailure('errorFileTooLarge');
    }
    final Uint8List bytes = await file.readAsBytes();

    final String text = switch (format) {
      ImportFormat.pdf => PdfTextExtractor().extract(bytes),
      ImportFormat.docx => DocxTextExtractor().extract(bytes),
      ImportFormat.txt => _decodeTextFile(bytes),
      ImportFormat.image || ImportFormat.unknown =>
        throw const ImportFailure('errorUnsupportedFormat'),
    };

    if (text.trim().length < 20) {
      throw const ImportFailure('importNothingFound');
    }
    return text;
  }

  /// Plain text in any of the three languages the app speaks.
  ///
  /// UTF-8 first, because that is what everything modern writes; a fallback to
  /// Latin-1 never throws, which keeps an old Windows export readable instead
  /// of failing the import outright.
  static String _decodeTextFile(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
}

/// Reads `word/document.xml` out of a DOCX container.
class DocxTextExtractor {
  static const String _documentPath = 'word/document.xml';

  String extract(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } on Object {
      throw const ImportFailure('errorUnsupportedFormat');
    }

    ArchiveFile? entry;
    for (final ArchiveFile candidate in archive.files) {
      if (candidate.name == _documentPath) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      throw const ImportFailure('errorUnsupportedFormat');
    }

    final String xmlSource = utf8.decode(
      entry.content as List<int>,
      allowMalformed: true,
    );

    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlSource);
    } on XmlException {
      throw const ImportFailure('errorUnsupportedFormat');
    }

    final StringBuffer out = StringBuffer();
    // Paragraph and line breaks are structure: without them every field of a
    // CV ends up on one line and the section detection has nothing to work
    // with.
    for (final XmlNode node in document.descendants) {
      if (node is! XmlElement) continue;
      switch (node.name.local) {
        case 't':
          out.write(node.innerText);
        case 'tab':
          out.write('  ');
        case 'br':
          out.write('\n');
        case 'p':
          // A paragraph is emitted when the walk leaves it; the closing tag is
          // enough of a boundary for text extraction.
          break;
      }
    }
    // Paragraph boundaries: walk again to place the newlines in order.
    return _withParagraphBreaks(document, out.toString());
  }

  /// Inserts a newline after every `w:p` in document order.
  static String _withParagraphBreaks(XmlDocument document, String fallback) {
    final StringBuffer out = StringBuffer();
    void visit(XmlNode node) {
      if (node is XmlElement) {
        if (node.name.local == 'p') {
          String paragraph = '';
          for (final XmlElement text
              in node.descendants.whereType<XmlElement>()) {
            if (text.name.local == 't') paragraph += text.innerText;
            if (text.name.local == 'tab') paragraph += '  ';
            if (text.name.local == 'br') paragraph += '\n';
          }
          if (paragraph.trim().isNotEmpty) {
            out.writeln(paragraph.trim());
          }
          return;
        }
        for (final XmlNode child in node.children) {
          visit(child);
        }
      }
    }

    visit(document.rootElement);
    final String text = out.toString();
    return text.trim().isEmpty ? fallback : text;
  }
}

/// Best-effort text recovery from a PDF.
///
/// This is not a general PDF library; it is the subset that matters for
/// importing a CV: inflate the content streams, run the text operators, and
/// map the string bytes back to characters — through the document's own
/// `ToUnicode` maps when it has them, which is what makes text written with an
/// embedded subset font come back as words rather than as glyph numbers.
///
/// The import screen always asks the user to review the result, so an
/// imperfect extraction costs a correction, not a wrong CV.
class PdfTextExtractor {
  /// File-wide fallback: every `ToUnicode` entry found anywhere in the file.
  ///
  /// Used when a stream cannot be attributed to a font — an object stream, or
  /// a file whose resources are assembled in a way this parser does not
  /// follow. It is a fallback rather than the primary path because merging
  /// every font's map is wrong as soon as two subset fonts both use code 1:
  /// the last font read wins, and half the page comes out as garbage.
  final Map<int, String> _toUnicode = <int, String>{};

  /// Character maps keyed by the object number of the `ToUnicode` stream.
  final Map<int, Map<int, String>> _cmapObjects = <int, Map<int, String>>{};

  /// Font object number → the character map it declares.
  final Map<int, Map<int, String>> _fontCmaps = <int, Map<int, String>>{};

  /// The object index for the file currently being read.
  _PdfObjects _objects = _PdfObjects.empty();

  /// The map of the font selected by the most recent `Tf` operator.
  Map<int, String>? _activeCmap;

  String extract(Uint8List bytes) {
    // PDF syntax is byte-oriented; Latin-1 keeps a one-to-one mapping between
    // byte offsets and string indices, so offsets found here stay valid.
    final String source = latin1.decode(bytes, allowInvalid: true);
    final _PdfObjects objects = _PdfObjects.of(source);
    _objects = objects;

    _readCharacterMaps(objects, bytes);
    _readFontResources(objects);

    final Map<int, Map<String, int>> contentFonts =
        _contentStreamFonts(objects);

    final StringBuffer out = StringBuffer();
    for (final _PdfObject object in objects.all) {
      final String? content = _streamTextOf(object, bytes);
      if (content == null || content.trim().isEmpty) continue;

      final String text = _operators(
        content,
        contentFonts[object.number] ?? const <String, int>{},
      );
      if (text.trim().isNotEmpty) out.write(text);
    }

    return _tidy(out.toString());
  }

  // ── Object index ─────────────────────────────────────────────────────────

  /// Reads every `ToUnicode` CMap in the file.
  ///
  /// The stream is inflated first: a CMap written by a modern producer is a
  /// compressed stream, so searching the raw bytes of the file for
  /// `beginbfchar` finds nothing at all — which is exactly the bug that made
  /// imported PDFs come back as a page of garbage.
  void _readCharacterMaps(_PdfObjects objects, Uint8List bytes) {
    for (final _PdfObject object in objects.all) {
      final String? stream = _streamTextOf(object, bytes);
      final String candidate = stream ?? object.body;
      if (!candidate.contains('beginbfchar') &&
          !candidate.contains('beginbfrange')) {
        continue;
      }
      final Map<int, String> map = _parseCmap(candidate);
      if (map.isEmpty) continue;
      _cmapObjects[object.number] = map;
      // The merged map is a fallback, so an earlier entry is kept: with two
      // subsets in play, whichever font the file happens to list first is no
      // worse a guess than whichever it lists last.
      for (final MapEntry<int, String> entry in map.entries) {
        _toUnicode.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  /// Resolves each font object to the character map it points at.
  void _readFontResources(_PdfObjects objects) {
    for (final _PdfObject object in objects.all) {
      final int? mapObject = _referenceAfter(object.body, '/ToUnicode');
      if (mapObject == null) continue;
      final Map<int, String>? map = _cmapObjects[mapObject];
      if (map != null) _fontCmaps[object.number] = map;
    }
  }

  /// Maps each content stream to the fonts its page's resources expose.
  ///
  /// A page object names a resource dictionary, which names fonts by a short
  /// token (`/F1`) that the content stream's `Tf` operator selects. Following
  /// that chain is what makes multi-font extraction correct; when it cannot be
  /// followed, the caller falls back to the merged map.
  Map<int, Map<String, int>> _contentStreamFonts(_PdfObjects objects) {
    final Map<int, Map<String, int>> result = <int, Map<String, int>>{};
    for (final _PdfObject page in objects.all) {
      if (!page.body.contains('/Contents')) continue;
      final List<int> contents = _contentReferences(page.body);
      if (contents.isEmpty) continue;
      final Map<String, int> fonts = _fontResourcesOf(page.body);
      for (final int number in contents) {
        result[number] = fonts;
      }
    }
    return result;
  }

  static List<int> _contentReferences(String body) {
    final List<int> numbers = <int>[];
    final RegExpMatch? single =
        RegExp(r'/Contents\s+(\d+)\s+\d+\s+R').firstMatch(body);
    if (single != null) numbers.add(int.parse(single.group(1)!));
    final RegExpMatch? array =
        RegExp(r'/Contents\s*\[([^\]]*)\]', dotAll: true).firstMatch(body);
    if (array != null) {
      for (final RegExpMatch reference
          in RegExp(r'(\d+)\s+\d+\s+R').allMatches(array.group(1)!)) {
        numbers.add(int.parse(reference.group(1)!));
      }
    }
    return numbers;
  }

  Map<String, int> _fontResourcesOf(String pageBody) {
    String scope = pageBody;
    final int? resources = _referenceAfter(pageBody, '/Resources');
    if (resources != null) {
      scope = _objects.byNumber(resources)?.body ?? pageBody;
    }

    final RegExpMatch? font =
        RegExp(r'/Font\s*(\d+\s+\d+\s+R|<<)').firstMatch(scope);
    if (font == null) return const <String, int>{};

    String dictionary;
    if (font.group(1) == '<<') {
      final int close = scope.indexOf('>>', font.end);
      dictionary = scope.substring(font.end, close < 0 ? scope.length : close);
    } else {
      final int? object =
          int.tryParse(RegExp(r'\d+').firstMatch(font.group(1)!)!.group(0)!);
      dictionary = object == null ? '' : (_objects.byNumber(object)?.body ?? '');
    }

    final Map<String, int> fonts = <String, int>{};
    for (final RegExpMatch entry
        in RegExp(r'/([A-Za-z0-9_.+-]+)\s+(\d+)\s+\d+\s+R')
            .allMatches(dictionary)) {
      fonts[entry.group(1)!] = int.parse(entry.group(2)!);
    }
    return fonts;
  }

  static int? _referenceAfter(String body, String token) {
    final RegExpMatch? match =
        RegExp('${RegExp.escape(token)}\\s+(\\d+)\\s+\\d+\\s+R').firstMatch(body);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  /// The decoded text of an object's stream, or `null` when it has none or
  /// when the stream cannot hold text (an image, a font program).
  String? _streamTextOf(_PdfObject object, Uint8List bytes) {
    final int start = object.body.indexOf('stream');
    if (start < 0) return null;
    final int end = object.body.indexOf('endstream', start);
    if (end < 0) return null;

    final String dictionary = object.body.substring(0, start);
    if (dictionary.contains('/Image') ||
        dictionary.contains('DCTDecode') ||
        dictionary.contains('JPXDecode') ||
        dictionary.contains('CCITTFaxDecode') ||
        dictionary.contains('FontFile')) {
      return null;
    }

    int from = object.byteStart + start + 6;
    if (from < bytes.length && bytes[from] == 13) from++;
    if (from < bytes.length && bytes[from] == 10) from++;
    final int to = object.byteStart + end;
    if (to <= from || to > bytes.length) return null;

    final Uint8List raw = Uint8List.sublistView(bytes, from, to);
    final List<int> data =
        dictionary.contains('FlateDecode') ? _inflate(raw) : raw;
    if (data.isEmpty) return null;
    return latin1.decode(data, allowInvalid: true);
  }

  /// Inflates a stream, or returns nothing when it is not deflate data.
  ///
  /// A stream can also be an image or a font program; those simply produce no
  /// text and are skipped rather than treated as an error.
  static List<int> _inflate(Uint8List data) {
    try {
      return zlib.decode(data);
    } on Object {
      return const <int>[];
    }
  }

  // ── ToUnicode CMaps ──────────────────────────────────────────────────────

  Map<int, String> _parseCmap(String text) {
    final Map<int, String> map = <int, String>{};
    final RegExp cmap = RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true);
    final RegExp range = RegExp(r'beginbfrange(.*?)endbfrange', dotAll: true);

    for (final RegExpMatch match in cmap.allMatches(text)) {
      for (final RegExpMatch pair
          in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
              .allMatches(match.group(1)!)) {
        final int code = int.parse(pair.group(1)!, radix: 16);
        map[code] = _fromUtf16Hex(pair.group(2)!);
      }
    }
    for (final RegExpMatch match in range.allMatches(text)) {
      for (final RegExpMatch entry in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
      ).allMatches(match.group(1)!)) {
        final int low = int.parse(entry.group(1)!, radix: 16);
        final int high = int.parse(entry.group(2)!, radix: 16);
        final int target = int.parse(entry.group(3)!, radix: 16);
        for (int code = low; code <= high && code - low < 512; code++) {
          map[code] = String.fromCharCode(target + (code - low));
        }
      }
    }
    return map;
  }

  static String _fromUtf16Hex(String hex) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i + 3 < hex.length; i += 4) {
      final int unit = int.parse(hex.substring(i, i + 4), radix: 16);
      if (unit != 0) out.writeCharCode(unit);
    }
    return out.toString();
  }

  // ── Content stream text operators ────────────────────────────────────────

  String _operators(String content, Map<String, int> fonts) {
    final StringBuffer out = StringBuffer();
    final List<String> pending = <String>[];
    String pendingName = '';
    _activeCmap = null;
    int i = 0;

    while (i < content.length) {
      final int code = content.codeUnitAt(i);
      final String ch = content[i];

      if (ch == '(') {
        final (String value, int next) = _literalString(content, i);
        pending.add(value);
        i = next;
        continue;
      }
      // A name token, which is the operand a `Tf` uses to choose a font.
      if (ch == '/') {
        int j = i + 1;
        while (j < content.length &&
            !_isDelimiter(content.codeUnitAt(j)) &&
            content[j] != '/') {
          j++;
        }
        pendingName = content.substring(i + 1, j);
        i = j;
        continue;
      }
      if (ch == '<' && i + 1 < content.length && content[i + 1] != '<') {
        final int close = content.indexOf('>', i);
        if (close < 0) break;
        pending.add(_hexString(content.substring(i + 1, close)));
        i = close + 1;
        continue;
      }
      if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
          ch == "'" ||
          ch == '"') {
        int j = i;
        while (j < content.length &&
            !_isDelimiter(content.codeUnitAt(j))) {
          j++;
        }
        final String operator = content.substring(i, j);
        switch (operator) {
          case 'Tj':
          case 'TJ':
          case "'":
          case '"':
            out.write(pending.join());
            pending.clear();
          case 'Td':
          case 'TD':
          case 'T*':
          case 'TL':
          case 'ET':
          case 'BT':
            pending.clear();
            out.write('\n');
          case 'Tf':
            pending.clear();
            final int? font = fonts[pendingName];
            _activeCmap = font == null ? null : _fontCmaps[font];
        }
        i = j;
        continue;
      }
      i++;
    }
    return out.toString();
  }

  static bool _isDelimiter(int code) =>
      code == 32 ||
      code == 10 ||
      code == 13 ||
      code == 9 ||
      code == 40 ||
      code == 41 ||
      code == 60 ||
      code == 62 ||
      code == 91 ||
      code == 93 ||
      code == 47 ||
      code == 123 ||
      code == 125;

  /// Parses a `( ... )` string, honouring escapes and nested parentheses.
  (String, int) _literalString(String source, int start) {
    final List<int> bytes = <int>[];
    int i = start + 1;
    int depth = 1;
    while (i < source.length) {
      final String ch = source[i];
      if (ch == r'\') {
        i++;
        if (i >= source.length) break;
        final String escape = source[i];
        switch (escape) {
          case 'n':
            bytes.add(10);
          case 'r':
            bytes.add(13);
          case 't':
            bytes.add(9);
          case 'b':
            bytes.add(8);
          case 'f':
            bytes.add(12);
          case '(':
            bytes.add(40);
          case ')':
            bytes.add(41);
          case r'\':
            bytes.add(92);
          default:
            if (RegExp(r'[0-7]').hasMatch(escape)) {
              String octal = escape;
              while (octal.length < 3 &&
                  i + 1 < source.length &&
                  RegExp(r'[0-7]').hasMatch(source[i + 1])) {
                i++;
                octal += source[i];
              }
              bytes.add(int.parse(octal, radix: 8) & 0xFF);
            } else {
              bytes.add(escape.codeUnitAt(0));
            }
        }
        i++;
        continue;
      }
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) {
          i++;
          break;
        }
      }
      bytes.add(source.codeUnitAt(i));
      i++;
    }
    return (_decodeBytes(bytes), i);
  }

  String _hexString(String hex) {
    final StringBuffer cleaned = StringBuffer();
    for (int i = 0; i < hex.length; i++) {
      final String ch = hex[i];
      if (ch.trim().isEmpty) continue;
      cleaned.write(ch);
    }
    String digits = cleaned.toString();
    if (digits.length.isOdd) digits = '${digits}0';
    final List<int> bytes = <int>[];
    for (int i = 0; i + 1 < digits.length; i += 2) {
      bytes.add(int.tryParse(digits.substring(i, i + 2), radix: 16) ?? 0);
    }
    return _decodeBytes(bytes);
  }

  /// Turns a PDF string's bytes into characters.
  ///
  /// Three shapes occur in practice: a two-byte identity encoding used with
  /// embedded fonts, single-byte WinAnsi text, and single-byte text from a
  /// subset font whose glyph ids are meaningless without the mapping — the
  /// last one is why the mapping is consulted first.
  String _decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final Map<int, String>? cmap = _activeCmap;
    if (cmap != null && cmap.isNotEmpty) {
      return _decodeWithCmap(bytes, cmap);
    }

    // No font map: fall back to the merged one, and to the shapes an
    // unmapped string can take.
    final String merged = _decodeWithMerge(bytes);
    if (merged.isNotEmpty) return merged;
    return _decodeWithCmap(bytes, _toUnicode);
  }

  /// Decodes with one font's map, choosing the code width by coverage.
  ///
  /// The old heuristic — "two-byte if every high byte is zero" — fails on a
  /// subset with more than 255 glyphs, where the codes legitimately exceed
  /// one byte, and mis-decodes a small subset whose codes all happen to be
  /// low. Trying both and keeping the reading that the map actually covers is
  /// both simpler and correct in more cases.
  String _decodeWithCmap(List<int> bytes, Map<int, String> cmap) {
    if (cmap.isEmpty) return '';

    final bool twoBytePossible = bytes.length.isEven && bytes.length >= 2;
    int singleHits = 0;
    for (final int byte in bytes) {
      if (cmap.containsKey(byte)) singleHits++;
    }
    int doubleHits = 0;
    if (twoBytePossible) {
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        if (cmap.containsKey((bytes[i] << 8) | bytes[i + 1])) doubleHits++;
      }
    }

    final int pairs = bytes.length ~/ 2;
    final bool twoByte = twoBytePossible &&
        doubleHits > 0 &&
        (singleHits == 0 || doubleHits * bytes.length >= singleHits * pairs);

    final StringBuffer out = StringBuffer();
    if (twoByte) {
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final int code = (bytes[i] << 8) | bytes[i + 1];
        out.write(cmap[code] ?? _fallbackChar(code));
      }
      return out.toString();
    }

    for (final int byte in bytes) {
      out.write(cmap[byte] ?? _winAnsi(byte));
    }
    return out.toString();
  }

  /// Decoding without a font context, for streams whose resources could not
  /// be resolved: the merged map first, then WinAnsi.
  String _decodeWithMerge(List<int> bytes) {
    final StringBuffer out = StringBuffer();
    bool anyMapped = false;

    // Two-byte identity encoding with a zero high byte in every pair, which
    // is what an unmapped embedded font's strings look like on the wire.
    bool twoByte = bytes.length.isEven && bytes.length >= 2;
    if (twoByte) {
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        if (bytes[i] != 0) {
          twoByte = false;
          break;
        }
      }
    }

    if (twoByte) {
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final int code = (bytes[i] << 8) | bytes[i + 1];
        final String? mapped = _toUnicode[code];
        if (mapped != null) anyMapped = true;
        out.write(mapped ?? _fallbackChar(code));
      }
      return anyMapped ? out.toString() : '';
    }

    for (final int byte in bytes) {
      final String? mapped = _toUnicode[byte];
      if (mapped != null) {
        anyMapped = true;
        out.write(mapped);
      } else {
        out.write(_winAnsi(byte));
      }
    }
    return anyMapped ? out.toString() : '';
  }

  static String _fallbackChar(int code) =>
      code >= 32 && code < 0x3000 ? String.fromCharCode(code) : '';

  /// WinAnsi differs from Latin-1 only in the 0x80–0x9F block, which is where
  /// the typographic characters a CV actually uses live.
  static String _winAnsi(int byte) {
    const Map<int, String> special = <int, String>{
      0x82: '‚',
      0x84: '„',
      0x85: '…',
      0x86: '†',
      0x87: '‡',
      0x8b: '‹',
      0x91: '‘',
      0x92: '’',
      0x93: '“',
      0x94: '”',
      0x95: '•',
      0x96: '–',
      0x97: '—',
      0x98: '˜',
      0x99: '™',
      0x9b: '›',
      0xa0: ' ',
    };
    final String? replacement = special[byte];
    if (replacement != null) return replacement;
    if (byte >= 32 && byte != 127) return String.fromCharCode(byte);
    return ' ';
  }

  /// Collapses the newline noise the operator scan produces while keeping
  /// paragraph breaks intact.
  static String _tidy(String input) {
    return input
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .split('\n')
        .map((String line) => line.trim())
        .join('\n')
        .trim();
  }
}

/// One `N 0 obj … endobj` section of a file, indexed by byte offset.
///
/// Text extraction needs this: content streams reference fonts by object
/// number, and following that reference is what separates correct extraction
/// from a merged guess.
class _PdfObject {
  const _PdfObject({
    required this.number,
    required this.body,
    required this.byteStart,
  });

  final int number;

  /// Everything between `obj` and `endobj`.
  final String body;

  /// The byte offset of [body] in the file, so stream data — which has to be
  /// inflated from the original bytes — can be located.
  final int byteStart;
}

class _PdfObjects {
  const _PdfObjects(this.all);

  const _PdfObjects.empty() : all = const <_PdfObject>[];

  final List<_PdfObject> all;

  factory _PdfObjects.of(String source) {
    final List<_PdfObject> objects = <_PdfObject>[];
    for (final RegExpMatch match
        in RegExp(r'(?:^|[\s>\]])(\d+)\s+\d+\s+obj\b').allMatches(source)) {
      final int start = match.end;
      final int end = source.indexOf('endobj', start);
      if (end < 0) continue;
      objects.add(
        _PdfObject(
          number: int.parse(match.group(1)!),
          body: source.substring(start, end),
          byteStart: start,
        ),
      );
    }
    return _PdfObjects(objects);
  }

  _PdfObject? byNumber(int number) {
    for (final _PdfObject object in all) {
      if (object.number == number) return object;
    }
    return null;
  }
}
