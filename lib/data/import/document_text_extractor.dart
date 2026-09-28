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
  /// Glyph id → character, merged from every `ToUnicode` CMap in the file.
  final Map<int, String> _toUnicode = <int, String>{};

  String extract(Uint8List bytes) {
    // PDF syntax is byte-oriented; Latin-1 keeps a one-to-one mapping between
    // byte offsets and string indices so offsets found here stay valid.
    final String source = latin1.decode(bytes, allowInvalid: true);

    _readToUnicodeMaps(source);

    final StringBuffer out = StringBuffer();
    int cursor = 0;
    while (true) {
      final int start = source.indexOf('stream', cursor);
      if (start < 0) break;
      final int end = source.indexOf('endstream', start);
      if (end < 0) break;
      cursor = end + 9;

      final int dictionaryStart = source.lastIndexOf('<<', start);
      final String dictionary = dictionaryStart < 0
          ? ''
          : source.substring(dictionaryStart, start);

      int offset = start + 6;
      if (offset < source.length && source.codeUnitAt(offset) == 13) offset++;
      if (offset < source.length && source.codeUnitAt(offset) == 10) offset++;

      final Uint8List raw = Uint8List.sublistView(bytes, offset, end);
      final List<int> data = dictionary.contains('/FlateDecode')
          ? _inflate(raw)
          : raw;
      if (data.isEmpty) continue;

      final String content = latin1.decode(data, allowInvalid: true);
      final String text = _operators(content);
      if (text.trim().isNotEmpty) out.write(text);
    }

    return _tidy(out.toString());
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

  void _readToUnicodeMaps(String source) {
    final RegExp cmap = RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true);
    final RegExp range = RegExp(r'beginbfrange(.*?)endbfrange', dotAll: true);

    for (final RegExpMatch match in cmap.allMatches(source)) {
      for (final RegExpMatch pair in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(match.group(1)!)) {
        final int code = int.parse(pair.group(1)!, radix: 16);
        _toUnicode[code] = _fromUtf16Hex(pair.group(2)!);
      }
    }
    for (final RegExpMatch match in range.allMatches(source)) {
      for (final RegExpMatch entry in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
      ).allMatches(match.group(1)!)) {
        final int low = int.parse(entry.group(1)!, radix: 16);
        final int high = int.parse(entry.group(2)!, radix: 16);
        final int target = int.parse(entry.group(3)!, radix: 16);
        for (int code = low; code <= high && code - low < 512; code++) {
          _toUnicode[code] = String.fromCharCode(target + (code - low));
        }
      }
    }
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

  String _operators(String content) {
    final StringBuffer out = StringBuffer();
    final List<String> pending = <String>[];
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
  static (String, int) _literalString(String source, int start) {
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

    // Two-byte codes with a zero high byte in every pair: what an embedded
    // font's identity encoding looks like on the wire.
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
      final StringBuffer out = StringBuffer();
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final int code = (bytes[i] << 8) | bytes[i + 1];
        out.write(_toUnicode[code] ?? _fallbackChar(code));
      }
      return out.toString();
    }

    final StringBuffer out = StringBuffer();
    for (final int byte in bytes) {
      if (_toUnicode.containsKey(byte)) {
        out.write(_toUnicode[byte]);
      } else {
        out.write(_winAnsi(byte));
      }
    }
    return out.toString();
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
