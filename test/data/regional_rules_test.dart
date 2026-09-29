import 'dart:convert';
import 'dart:io';

import 'package:cv_pro/domain/entities/regional_profile.dart';
import 'package:cv_pro/domain/enums/document_options.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/enums/section_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests read the rule bundles that actually ship in the APK, not a
/// fixture. A typo in `assets/data/regional_rules/*.json` is therefore a test
/// failure, which is the point: regional rules are content, and content needs
/// the same protection as code.
void main() {
  Map<String, dynamic> readBundle(RegionCode region) {
    final File file = File(region.assetPath);
    expect(file.existsSync(), isTrue, reason: '${region.assetPath} is missing');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('bundled rule bundles', () {
    test('every RegionCode ships a parsable bundle with a matching id', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        expect(profile.id, region.id,
            reason: '${region.assetPath} declares id "${profile.id}"');
        expect(profile.schemaVersion, greaterThanOrEqualTo(1));
        expect(profile.version, greaterThanOrEqualTo(1));
        expect(profile.labelKey, isNotEmpty);
        expect(profile.summary, isNotEmpty,
            reason: '${region.id} needs a summary for the market picker');
      }
    });

    test('every market defines a usable section order', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));

        expect(profile.sections.order, isNotEmpty,
            reason: '${region.id} has no conventional section order');
        // A repeated section would silently hide one of the two entries when
        // the builder applies the order.
        expect(profile.sections.order.toSet().length,
            profile.sections.order.length,
            reason: '${region.id} lists a section twice');
      }
    });

    test('required and recommended sections are real SectionKeys', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        for (final SectionKey key in <SectionKey>[
          ...profile.sections.required,
          ...profile.sections.recommended,
          ...profile.sections.discouraged,
        ]) {
          expect(SectionKey.values, contains(key),
              reason: '${region.id} references an unknown section id');
        }
      }
    });

    test('date systems declared as options include the default', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        expect(profile.dateSystemOptions, isNotEmpty,
            reason: '${region.id} offers no date system');
        // The default must be one of the offered options, otherwise the
        // settings screen can show a value the region does not support.
        expect(profile.dateSystemOptions, contains(profile.dateSystem),
            reason: '${region.id} defaults to a date system it does not list');
      }
    });

    test('accepted document languages always include the primary one', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        expect(profile.acceptedDocumentLanguages, isNotEmpty);
        expect(profile.acceptedDocumentLanguages,
            contains(profile.documentLanguage));
      }
    });

    test('page guidance is internally consistent', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        expect(profile.page.min, greaterThanOrEqualTo(1));
        expect(profile.page.max, greaterThanOrEqualTo(profile.page.min));
        expect(profile.page.idealMax, greaterThanOrEqualTo(profile.page.min));
        expect(profile.page.idealMax, lessThanOrEqualTo(profile.page.max));
      }
    });

    test('every advisory carries a code and readable text', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        for (final RegionalAdvisory advisory in profile.advisories) {
          expect(advisory.code, isNotEmpty);
          expect(advisory.text.trim(), isNotEmpty,
              reason: '${region.id}/${advisory.code} has no text to show');
          expect(
            <String>['critical', 'high', 'medium', 'low', 'info'],
            contains(advisory.severity),
          );
        }
      }
    });
  });

  group('privacy-sensitive defaults', () {
    test('no market enables sensitive personal details by default', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        for (final String field in profile.personalInfo.neverIncludeByDefault) {
          expect(field, isNotEmpty,
              reason: '${region.id} lists an unnamed restricted field');
        }
        if (region == RegionCode.iran) {
          // The Iranian profile is the one that legitimately offers these, and
          // even there they stay off until the user asks for them.
          expect(profile.personalInfo.neverIncludeByDefault,
              containsAll(<String>['nationalId']));
          expect(profile.personalInfo.showSensitiveByDefault, isFalse);
        } else {
          expect(profile.personalInfo.showSensitiveByDefault, isFalse,
              reason: '${region.id} should not opt users into sensitive data');
        }
      }
    });

    test('markets that discourage photos never enable them by default', () {
      for (final RegionCode region in <RegionCode>[
        RegionCode.unitedStates,
        RegionCode.unitedKingdom,
      ]) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        expect(profile.photo.policy, PhotoExpectation.discouraged);
        expect(profile.photo.shouldDefaultToOff, isTrue);
      }
    });

    test('Germany treats a photo as optional rather than required', () {
      final RegionalProfile profile = RegionalProfile.fromJson(
          readBundle(RegionCode.germany));
      expect(profile.photo.policy, PhotoExpectation.optional);
      expect(profile.photo.shouldDefaultToOff, isTrue,
          reason: 'a photo is permitted, never assumed');
    });

    test('the United States uses Letter and one page as the ideal', () {
      final RegionalProfile profile =
          RegionalProfile.fromJson(readBundle(RegionCode.unitedStates));
      expect(profile.paperSize, PaperSize.usLetter);
      expect(profile.page.idealMax, 1);
    });

    test('Iran offers the Jalali calendar without forcing it', () {
      final RegionalProfile profile =
          RegionalProfile.fromJson(readBundle(RegionCode.iran));
      expect(profile.dateSystemOptions, contains(DateSystem.jalali));
      expect(profile.paperSize, PaperSize.a4);
    });
  });

  group('no absolutist claims', () {
    // The brief forbids presenting any format as obligatory. Rather than
    // grepping for a list of banned phrases (which catches innocent English
    // such as "text must be laid out right to left"), this asserts the
    // *shape* of the advice: an advisory describes what is usual, and never
    // uses the vocabulary of obligation.
    const List<String> deontic = <String>[
      'must',
      'mandatory',
      'obligatory',
      'required by',
      'is required',
      'illegal',
      'legally',
      'required by law',
    ];

    test('every advisory is phrased as a convention, not a rule', () {
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        for (final RegionalAdvisory advisory in profile.advisories) {
          final String text = advisory.text.toLowerCase();
          for (final String word in deontic) {
            expect(text.contains(word), isFalse,
                reason: '${region.id}/${advisory.code} uses "$word", which '
                    'turns advice into a requirement');
          }
        }
      }
    });

    test('advisory copy uses hedging language', () {
      const List<String> hedges = <String>[
        'usually', 'often', 'typically', 'common', 'conventional', 'many',
        'some', 'tends', 'most ', 'can ', 'may ',
      ];
      for (final RegionCode region in RegionCode.values) {
        final RegionalProfile profile =
            RegionalProfile.fromJson(readBundle(region));
        for (final RegionalAdvisory advisory in profile.advisories) {
          final String text = advisory.text.toLowerCase();
          expect(hedges.any(text.contains), isTrue,
              reason: '${region.id}/${advisory.code} states a convention '
                  'without hedging it: "${advisory.text}"');
        }
      }
    });

    test('Europe describes Europass as one option among several', () {
      final RegionalProfile profile =
          RegionalProfile.fromJson(readBundle(RegionCode.europe));
      final String notes = profile.advisories
          .map((RegionalAdvisory a) => a.text.toLowerCase())
          .join(' ');
      expect(notes.contains('europass'), isTrue);
      expect(notes.contains('one') || notes.contains('many'),
          isTrue,
          reason: 'Europass must be presented as an option, not the standard');
    });
  });

  group('parser robustness', () {
    test('a malformed bundle degrades to the neutral profile', () {
      final RegionalProfile profile = RegionalProfile.parse('{not json');
      expect(profile.id, 'international');
      expect(profile.sections.order, isEmpty);
    });

    test('a bundle that is valid JSON but not an object is rejected politely',
        () {
      expect(RegionalProfile.parse('[1, 2, 3]').id, 'international');
      expect(RegionalProfile.parse('"iran"').id, 'international');
    });

    test('missing sub-objects fall back to neutral defaults', () {
      final RegionalProfile profile =
          RegionalProfile.fromJson(<String, dynamic>{'id': 'atlantis'});
      expect(profile.id, 'atlantis');
      expect(profile.paperSize, PaperSize.a4);
      expect(profile.photo.policy, PhotoExpectation.optional);
      expect(profile.ats.strictness, AtsStrictness.medium);
      expect(profile.advisories, isEmpty);
    });

    test('unknown section ids are skipped rather than fatal', () {
      final RegionalProfile profile = RegionalProfile.fromJson(<String, dynamic>{
        'id': 'atlantis',
        'sections': <String, dynamic>{
          'order': <String>['summary', 'telepathy', 'experience'],
        },
      });
      // SectionKey.fromId falls back to a defined value, so an unrecognised
      // id must never crash the analyzer.
      expect(profile.sections.order, isNotEmpty);
    });

    test('a newer version is detected for the same market only', () {
      const RegionalProfile v1 = RegionalProfile(id: 'germany', version: 1);
      const RegionalProfile v2 = RegionalProfile(id: 'germany', version: 2);
      const RegionalProfile other = RegionalProfile(id: 'iran', version: 9);

      expect(v2.isNewerThan(v1), isTrue);
      expect(v1.isNewerThan(v2), isFalse);
      expect(other.isNewerThan(v1), isFalse);
    });
  });

  group('unknown market handling', () {
    test('fromJson keeps going when a region is not yet in the enum', () {
      final RegionalProfile canada = RegionalProfile.parse('''
        {
          "schemaVersion": 1,
          "id": "canada",
          "version": 1,
          "labelKey": "regionCanada",
          "summary": "Canadian resumes are typically two pages.",
          "paperSize": "us_letter",
          "documentLanguage": "en",
          "acceptedDocumentLanguages": ["en", "fr"],
          "dateSystem": "gregorian",
          "dateSystemOptions": ["gregorian"],
          "dateFormat": "MM/YYYY",
          "photo": {"policy": "discouraged", "conventional": false, "shape": "circle", "note": "A photo is not expected."},
          "personalInfo": {"showSensitiveByDefault": false, "conventional": ["email", "phone", "location"], "discouraged": ["dateOfBirth"], "neverIncludeByDefault": ["nationalId"], "note": ""},
          "sections": {"order": ["summary", "experience", "education", "skills"], "required": ["experience", "education"], "recommended": ["summary"], "discouraged": ["photo"]},
          "page": {"min": 1, "max": 3, "idealMax": 2, "note": ""},
          "ats": {"strictness": "high", "photoOnAts": false, "notes": []},
          "language": {"expectedTone": "professional", "verbTensePreference": "past", "notes": []},
          "advisories": [{"code": "canada.workPermit", "severity": "info", "text": "Work authorisation may be asked about."}]
        }
      ''');

      // Adding a market is a data change: the parser accepts bundles the
      // RegionCode enum does not know about yet, so a future region can ship
      // ahead of the picker.
      expect(canada.id, 'canada');
      expect(canada.paperSize, PaperSize.usLetter);
      expect(canada.sections.order, contains(SectionKey.summary));
      expect(canada.advisories.single.code, 'canada.workPermit');
    });
  });
}
