import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'arabic_presentation_forms.dart';

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

    return _restoreReadingOrder(_tidy(out.toString()));
  }

  // ── Reading order and script ─────────────────────────────────────────────

  /// The presentation forms a shaped Arabic-script letter can take.
  ///
  /// Generated — see `arabic_presentation_forms.dart` and
  /// `tools/generate_arabic_table.py` — from Unicode's own compatibility
  /// decompositions, so it cannot lose a range to a hand-set boundary. It used
  /// to have one, and the Farsi-yeh forms that sat above it came back as
  /// unreadable forms in an imported Persian CV.
  static final Map<int, String> _arabicForms = arabicPresentationForms;

  /// Turns what a PDF stores back into what the user typed.
  ///
  /// A PDF does not hold text, it holds glyphs: already shaped (each Arabic
  /// letter replaced by the form that joins with its neighbours) and already
  /// ordered the way the line is painted, which for a right-to-left line is
  /// the reverse of the way it is read. That is what a reader needs and
  /// exactly what an importer must undo — without this step an imported
  /// Persian CV reads "ﺍﺭاس" where the user wrote "سارا", and every keyword
  /// and analysis check afterwards operates on the wrong characters.
  static String _restoreReadingOrder(String text) =>
      text.split('\n').map(_restoreReadingOrderFor).join('\n');

  static String _restoreReadingOrderFor(String line) {
    final String folded = _foldArabicForms(line);
    if (!_isRightToLeftLine(folded)) return folded;

    final List<int> runes = folded.runes.toList().reversed.toList();

    // A number reads left to right even inside a right-to-left line, so each
    // run of digits is turned back the right way round after the reversal.
    int index = 0;
    while (index < runes.length) {
      if (!_isDigit(runes[index])) {
        index++;
        continue;
      }
      int end = index;
      while (end < runes.length && _isDigit(runes[end])) {
        end++;
      }
      runes.replaceRange(index, end, runes.sublist(index, end).reversed);
      index = end;
    }

    return String.fromCharCodes(runes);
  }

  static String _foldArabicForms(String text) {
    bool needsFolding = false;
    for (final int rune in text.runes) {
      if (_arabicForms.containsKey(rune)) {
        needsFolding = true;
        break;
      }
    }
    if (!needsFolding) return text;

    final StringBuffer out = StringBuffer();
    for (final int rune in text.runes) {
      out.write(_arabicForms[rune] ?? String.fromCharCode(rune));
    }
    return out.toString();
  }

  static final Map<int, String> _arabicForms = <int, String>{
    for (final (int first, int count, String base) in _arabicFormRuns)
      for (int code = first; code < first + count; code++) code: base,
  };

  /// Whether a line should be read from the other end.
  ///
  /// True only when every character in it is Arabic script, punctuation,
  /// whitespace or an Arabic-Indic digit. A line with Latin letters or ASCII
  /// digits is mixed, and a mixed line's visual order comes from two
  /// directions interleaved — reversing it would corrupt the Latin half of
  /// almost every Persian CV, so it is left as the file painted it.
  static bool _isRightToLeftLine(String line) {
    bool sawArabic = false;
    for (final int rune in line.runes) {
      if (_isLatinLetter(rune) || (rune >= 0x30 && rune <= 0x39)) return false;
      if (_isArabicScript(rune)) sawArabic = true;
    }
    return sawArabic;
  }

  static bool _isArabicScript(int rune) =>
      (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF) ||
      (rune >= 0xFB50 && rune <= 0xFEFF);

  static bool _isLatinLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A) ||
      (rune >= 0xC0 && rune <= 0x24F);

  static bool _isDigit(int rune) =>
      (rune >= 0x30 && rune <= 0x39) ||
      (rune >= 0x0660 && rune <= 0x0669) ||
      (rune >= 0x06F0 && rune <= 0x06F9);

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
