import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_pro/features/export/library_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backup file is the user's only copy of their work outside the app, so
/// what it is named and what it contains are worth asserting rather than
/// discovering in a support message.
void main() {
  const LibraryBackupService service = LibraryBackupService();

  group('the backup file name', () {
    test('is dated, so two exports never collide', () {
      expect(
        service.fileNameFor(DateTime(2026, 9, 29)),
        'wonder-cv-backup-2026-09-29.json',
      );
    });

    test('pads single-digit months and days', () {
      // A file named 2026-1-5 sorts before 2025-12-31 in every file manager,
      // which is the one thing a dated backup must not do.
      expect(
        service.fileNameFor(DateTime(2026, 1, 5)),
        'wonder-cv-backup-2026-01-05.json',
      );
    });

    test('uses no character a file system rejects', () {
      final String name = service.fileNameFor(DateTime(2026, 12, 31));
      expect(RegExp(r'[\\/:*?"<>|]').hasMatch(name), isFalse);
      expect(name, endsWith('.json'));
    });
  });

  group('the backup payload', () {
    test('is indented UTF-8 JSON that survives Persian', () {
      final Uint8List bytes = service.encode(<String, dynamic>{
        'format': LibraryBackupService.formatId,
        'version': LibraryBackupService.formatVersion,
        'resumes': <dynamic>[
          <String, dynamic>{
            'title': 'رزومه نمونه',
            'content': <String, dynamic>{
              'personal': <String, dynamic>{'firstName': 'سارا', 'lastName': 'احمدی'},
            },
          },
        ],
      });

      final String text = utf8.decode(bytes);
      expect(text, contains('\n  '), reason: 'indented for a person to read');
      final Map<String, dynamic> decoded =
          jsonDecode(text) as Map<String, dynamic>;
      expect(decoded['format'], LibraryBackupService.formatId);
      expect(decoded['resumes'], isA<List<dynamic>>());
      // A backup that mangles the user's own name is worse than no backup.
      expect(text, contains('سارا'));
      expect(text, contains('احمدی'));
    });

    test('keeps the numbers a CV is built from intact', () {
      final Uint8List bytes = service.encode(<String, dynamic>{
        'resumes': <dynamic>[
          <String, dynamic>{'salary': 45000.5, 'years': 6, 'remote': true},
        ],
      });
      final Map<String, dynamic> decoded =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final Map<String, dynamic> row =
          (decoded['resumes'] as List<dynamic>).first as Map<String, dynamic>;
      expect(row['salary'], 45000.5);
      expect(row['years'], 6);
      expect(row['remote'], isTrue);
    });
  });

  group('reading a chosen file', () {
    Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

    test('accepts a backup this app wrote', () {
      final Map<String, dynamic>? payload = LibraryBackupService.parse(
        bytesOf(jsonEncode(<String, dynamic>{
          'format': LibraryBackupService.formatId,
          'version': LibraryBackupService.formatVersion,
          'resumes': <dynamic>[
            <String, dynamic>{'id': 'r1', 'title': 'رزومه من'},
          ],
        })),
      );
      expect(payload, isNotNull);
      expect(LibraryBackupService.documentCount(payload!), 1);
    });

    test('counts only the documents the importer would actually write', () {
      // Entries without an id and a title are skipped by importLibrary, so the
      // confirmation must not promise them either.
      final Map<String, dynamic> payload = <String, dynamic>{
        'format': LibraryBackupService.formatId,
        'resumes': <dynamic>[
          <String, dynamic>{'id': 'r1', 'title': 'One'},
          <String, dynamic>{'id': 'r2'},
          <String, dynamic>{'title': 'Three'},
          'not even an object',
          <String, dynamic>{'id': 'r4', 'title': 'Four'},
        ],
      };
      expect(LibraryBackupService.documentCount(payload), 2);
    });

    test('refuses a file that is not JSON at all', () {
      expect(LibraryBackupService.parse(bytesOf('this is a photo, not a backup')),
          isNull);
    });

    test('refuses JSON that is not an object', () {
      expect(LibraryBackupService.parse(bytesOf('[1, 2, 3]')), isNull);
      expect(LibraryBackupService.parse(bytesOf('"a string"')), isNull);
    });

    test('refuses another app’s JSON, however valid', () {
      expect(
        LibraryBackupService.parse(bytesOf(jsonEncode(<String, dynamic>{
          'format': 'some.other.tool.backup',
          'resumes': <dynamic>[],
        }))),
        isNull,
      );
    });

    test('refuses a backup truncated mid-write', () {
      final String whole = jsonEncode(<String, dynamic>{
        'format': LibraryBackupService.formatId,
        'resumes': <dynamic>[<String, dynamic>{'id': 'r1', 'title': 'One'}],
      });
      expect(
        LibraryBackupService.parse(bytesOf(whole.substring(0, whole.length ~/ 2))),
        isNull,
        reason: 'a device that ran out of power leaves half a file behind',
      );
    });

    test('refuses bytes that are not UTF-8', () {
      expect(
        LibraryBackupService.parse(Uint8List.fromList(<int>[0xff, 0xfe, 0x00, 0x01])),
        isNull,
      );
    });

    test('an empty file is not a backup', () {
      expect(LibraryBackupService.parse(Uint8List(0)), isNull);
    });
  });

  group('recognising a backup', () {
    test('accepts the app’s own format', () {
      expect(
        LibraryBackupService.looksLikeBackup(<String, dynamic>{
          'format': LibraryBackupService.formatId,
          'resumes': <dynamic>[],
        }),
        isTrue,
      );
    });

    test('rejects anything else, so a wrong file is a sentence not a merge',
        () {
      expect(
        LibraryBackupService.looksLikeBackup(<String, dynamic>{
          'format': 'some.other.tool',
          'resumes': <dynamic>[],
        }),
        isFalse,
      );
      expect(
        LibraryBackupService.looksLikeBackup(<String, dynamic>{
          'format': LibraryBackupService.formatId,
        }),
        isFalse,
        reason: 'a backup without a document list is not a backup',
      );
      expect(LibraryBackupService.looksLikeBackup(<String, dynamic>{}), isFalse);
    });
  });
}
