import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cv_pro/data/import/document_text_extractor.dart';
import 'package:cv_pro/domain/entities/regional_profile.dart';
import 'package:cv_pro/domain/entities/resume.dart';
import 'package:cv_pro/domain/entities/resume_content.dart';
import 'package:cv_pro/domain/entities/year_month.dart';
import 'package:cv_pro/domain/enums/cv_type.dart';
import 'package:cv_pro/domain/enums/document_options.dart';
import 'package:cv_pro/domain/enums/proficiency.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/rules/regional_rule_engine.dart';
import 'package:cv_pro/domain/templates/resume_template.dart';
import 'package:cv_pro/features/export/pdf_export_service.dart';
import 'package:cv_pro/l10n/app_localizations.dart';
import 'package:cv_pro/pdf/resume_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PDF engine is the part of this app a user cannot work around: a CV that
/// will not open, or whose Persian text comes out as boxes, is a failed
/// product no matter how good the editor is.
///
/// So these tests render real documents through the real engine, with the real
/// bundled fonts, and then read the bytes back through the same extractor the
/// importer uses — which means the text assertions only pass if the text is
/// genuinely in the file, selectable and searchable, rather than a picture of
/// text that merely looks right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppLocalizations en = AppLocalizations.ofCode('en');
  final AppLocalizations fa = AppLocalizations.ofCode('fa');
  final AppLocalizations de = AppLocalizations.ofCode('de');

  RegionalProfile profileOf(RegionCode region) => RegionalProfile.fromJson(
        jsonDecode(File(region.assetPath).readAsStringSync())
            as Map<String, dynamic>,
      );

  Resume buildResume({
    required RegionCode region,
    required CvType cvType,
    required ResumeContent content,
    String title = 'Test CV',
    String templateId = 'professional',
    PaperSize paperSize = PaperSize.a4,
    String languageCode = 'en',
  }) =>
      Resume(
        id: 'pdf-test',
        title: title,
        region: region,
        cvType: cvType,
        languageCode: languageCode,
        templateId: templateId,
        paperSize: paperSize,
        content: content,
      );

  Future<ResumePdfResult> render(
    Resume resume,
    RegionCode region,
    AppLocalizations l10n,
  ) async {
    final RegionalProfile profile = profileOf(region);
    final ResumeTemplate template = ResumeTemplates.byId(resume.templateId);
    final FormatPlan plan = RegionalRuleEngine.planFor(
      profile: profile,
      resume: resume,
      template: template,
    );
    return const ResumePdfBuilder().build(
      ResumePdfRequest(
        resume: resume,
        plan: plan,
        template: template,
        l10n: l10n,
      ),
    );
  }

  /// Renders, proves the result is a real PDF, and returns its text.
  Future<String> renderAndRead(
    Resume resume,
    RegionCode region,
    AppLocalizations l10n, {
    int? expectPages,
  }) async {
    final ResumePdfResult result = await render(resume, region, l10n);

    expect(
      result.bytes.length,
      greaterThan(1000),
      reason: 'a real document, not a stub',
    );
    expect(result.bytes.length, result.byteSize);
    expect(
      String.fromCharCodes(result.bytes.take(5)),
      '%PDF-',
      reason: 'the file must actually be a PDF',
    );
    if (expectPages != null) {
      expect(result.pageCount, expectPages, reason: 'page count');
    }
    return PdfTextExtractor().extract(Uint8List.fromList(result.bytes));
  }

  // ── Reading the extracted text ───────────────────────────────────────────
  //
  // Two properties of a real PDF make naive `contains('a b c')` assertions
  // wrong rather than merely brittle:
  //
  //  * a line break can fall between any two words, because the renderer
  //    decides where to wrap;
  //  * a right-to-left run is drawn in visual order, so Persian can legitimately
  //    come out of the file reversed.
  //
  // The helpers below accept those two facts without weakening what is being
  // tested: the characters must genuinely be in the file, in a real font, with
  // a working ToUnicode map — which is precisely what fails when a PDF shows
  // boxes or holds a bitmap.

  String squash(String value) => value.replaceAll(RegExp(r'\s+'), '');

  String reverse(String value) =>
      String.fromCharCodes(value.runes.toList().reversed);

  /// Folds the Arabic presentation forms back onto their base letters.
  ///
  /// dart_pdf shapes Arabic by substituting a presentation form for each
  /// letter (its own `font/arabic.dart` table), so text read back out of a
  /// correctly rendered Persian CV can contain U+FB50–U+FEFF even though the
  /// source contained ordinary letters. Folding those forms back is what keeps
  /// the assertion about "is the Persian text really in the file" rather than
  /// about which shaping strategy the renderer chose. Forms that are truly
  /// missing from a file — because it holds an image, or because the ToUnicode
  /// map is broken — still produce nothing to match.
  const Map<String, List<int>> arabicShapes = <String, List<int>>{
    'ا': <int>[0x0627, 0xFE8E],
    'آ': <int>[0x0622, 0xFE82],
    'أ': <int>[0x0623, 0xFE84],
    'ؤ': <int>[0x0624, 0xFE86],
    'إ': <int>[0x0625, 0xFE88],
    'ئ': <int>[0x0626, 0xFE8A, 0xFE8B, 0xFE8C],
    'ب': <int>[0x0628, 0xFE90, 0xFE91, 0xFE92],
    'ة': <int>[0x0629, 0xFE94],
    'ت': <int>[0x062A, 0xFE96, 0xFE97, 0xFE98],
    'ث': <int>[0x062B, 0xFE9A, 0xFE9B, 0xFE9C],
    'ج': <int>[0x062C, 0xFE9E, 0xFE9F, 0xFEA0],
    'ح': <int>[0x062D, 0xFEA2, 0xFEA3, 0xFEA4],
    'خ': <int>[0x062E, 0xFEA6, 0xFEA7, 0xFEA8],
    'د': <int>[0x062F, 0xFEAA],
    'ذ': <int>[0x0630, 0xFEAC],
    'ر': <int>[0x0631, 0xFEAE],
    'ز': <int>[0x0632, 0xFEB0],
    'س': <int>[0x0633, 0xFEB2, 0xFEB3, 0xFEB4],
    'ش': <int>[0x0634, 0xFEB6, 0xFEB7, 0xFEB8],
    'ص': <int>[0x0635, 0xFEBA, 0xFEBB, 0xFEBC],
    'ض': <int>[0x0636, 0xFEBE, 0xFEBF, 0xFEC0],
    'ط': <int>[0x0637, 0xFEC2, 0xFEC3, 0xFEC4],
    'ظ': <int>[0x0638, 0xFEC6, 0xFEC7, 0xFEC8],
    'ع': <int>[0x0639, 0xFECA, 0xFECB, 0xFECC],
    'غ': <int>[0x063A, 0xFECE, 0xFECF, 0xFED0],
    'ف': <int>[0x0641, 0xFED2, 0xFED3, 0xFED4],
    'ق': <int>[0x0642, 0xFED6, 0xFED7, 0xFED8],
    'ك': <int>[0x0643, 0xFEDA, 0xFEDB, 0xFEDC],
    'ل': <int>[0x0644, 0xFEDE, 0xFEDF, 0xFEE0],
    'م': <int>[0x0645, 0xFEE2, 0xFEE3, 0xFEE4],
    'ن': <int>[0x0646, 0xFEE6, 0xFEE7, 0xFEE8],
    'ه': <int>[0x0647, 0xFEEA, 0xFEEB, 0xFEEC],
    'و': <int>[0x0648, 0xFEEE],
    'ى': <int>[0x0649, 0xFEF0],
    'ي': <int>[0x064A, 0xFEF2, 0xFEF3, 0xFEF4],
    'ی': <int>[0x06CC, 0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF],
    'پ': <int>[0x067E, 0xFB56, 0xFB57, 0xFB58, 0xFB59],
    'چ': <int>[0x0686, 0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D],
    'ژ': <int>[0x0698, 0xFB8A, 0xFB8B],
    'گ': <int>[0x06AF, 0xFB92, 0xFB93, 0xFB94, 0xFB95],
    'ک': <int>[0x06A9, 0xFB8E, 0xFB8F, 0xFB90, 0xFB91],
    'لا': <int>[0xFEF5, 0xFEF6, 0xFEF7, 0xFEF8, 0xFEF9, 0xFEFA, 0xFEFB, 0xFEFC],
  };

  final Map<int, String> presentationForms = <int, String>{};
  for (final MapEntry<String, List<int>> entry in arabicShapes.entries) {
    for (final int form in entry.value) {
      presentationForms[form] = entry.key;
    }
  }

  String normalize(String value) {
    final StringBuffer out = StringBuffer();
    for (final int rune in value.runes) {
      out.write(presentationForms[rune] ?? String.fromCharCode(rune));
    }
    return out.toString();
  }

  void expectText(String haystack, String needle, {String? because}) {
    final String flat = normalize(squash(haystack));
    final String direct = normalize(squash(needle));
    if (flat.contains(direct)) return;
    final String flipped = normalize(squash(reverse(needle)));
    if (flat.contains(flipped)) return;
    fail(
      'expected to find "$needle" in the PDF text${because == null ? '' : ' ($because)'}.\n'
      'Neither the logical nor the visual order was present.\n'
      'Extracted (first 400 characters): ${flat.length > 400 ? flat.substring(0, 400) : flat}',
    );
  }

  // ── Content used by the tests ────────────────────────────────────────────

  ResumeContent englishContent({int roles = 2}) => ResumeContent(
        personal: const PersonalInfo(
          firstName: 'Sara',
          lastName: 'Ahmadi',
          jobTitle: 'Backend Developer',
          email: 'sara.ahmadi@example.com',
          phone: '+44 7700 900123',
          city: 'London',
          country: 'United Kingdom',
          linkedIn: 'linkedin.com/in/saraahmadi',
          summary: 'Backend developer with six years of experience building '
              'payment systems that handle millions of transactions a day.',
        ),
        experiences: <Experience>[
          for (int i = 0; i < roles; i++)
            Experience(
              id: 'exp-$i',
              jobTitle: 'Senior Backend Developer',
              company: 'Northwind Payments',
              location: 'London, UK',
              startDate: YearMonth(2021 - i * 3, 3),
              endDate: i == 0 ? null : YearMonth(2021 - i * 3, 2),
              isCurrent: i == 0,
              responsibilities: <String>[
                'Designed the ledger service that now settles four million '
                    'transactions per day.',
                'Cut the ninety-ninth percentile payment latency from eight '
                    'hundred milliseconds to under two hundred.',
                'Mentored four engineers and ran the on-call rotation.',
              ],
              technologies: <String>['Dart', 'PostgreSQL', 'Kafka'],
            ),
        ],
        education: const <Education>[
          Education(
            id: 'edu-1',
            institution: 'University of Edinburgh',
            degree: 'BSc (Hons) Computer Science',
            fieldOfStudy: 'Computer Science',
            location: 'Edinburgh, UK',
            startDate: YearMonth(2012, 9),
            endDate: YearMonth(2016, 6),
          ),
        ],
        skills: const <Skill>[
          Skill(id: 's1', name: 'Dart', level: SkillLevel.expert),
          Skill(id: 's2', name: 'PostgreSQL', level: SkillLevel.advanced),
          Skill(id: 's3', name: 'Kafka', level: SkillLevel.advanced),
          Skill(id: 's4', name: 'Kubernetes', level: SkillLevel.intermediate),
        ],
        languages: const <LanguageSkill>[
          LanguageSkill(
            id: 'l1',
            language: 'English',
            level: LanguageLevel.native,
          ),
          LanguageSkill(
            id: 'l2',
            language: 'German',
            level: LanguageLevel.intermediate,
          ),
        ],
      );

  ResumeContent persianContent() => ResumeContent(
        personal: const PersonalInfo(
          firstName: 'سارا',
          lastName: 'احمدی',
          jobTitle: 'برنامه‌نویس بک‌اند',
          email: 'sara@example.com',
          phone: '+98 912 000 0000',
          city: 'تهران',
          country: 'ایران',
          summary: 'برنامه‌نویس بک‌اند با شش سال تجربه در ساخت سامانه‌های '
              'پرداخت که روزانه میلیون‌ها تراکنش را پردازش می‌کنند.',
        ),
        experiences: <Experience>[
          Experience(
            id: 'exp-fa',
            jobTitle: 'برنامه‌نویس ارشد بک‌اند',
            company: 'شرکت پرداخت شمال',
            location: 'تهران، ایران',
            startDate: const YearMonth(2021, 3),
            isCurrent: true,
            responsibilities: const <String>[
              'طراحی سرویس دفتر کل که روزانه میلیون‌ها تراکنش را تسویه می‌کند.',
              'کاهش تأخیر پرداخت و افزایش پایداری سامانه.',
            ],
          ),
        ],
        education: const <Education>[
          Education(
            id: 'edu-fa',
            institution: 'دانشگاه تهران',
            degree: 'کارشناسی مهندسی کامپیوتر',
            startDate: YearMonth(2012, 9),
            endDate: YearMonth(2016, 6),
          ),
        ],
        skills: const <Skill>[
          Skill(id: 's-fa-1', name: 'دارت'),
          Skill(id: 's-fa-2', name: 'پستگرس'),
        ],
      );

  ResumeContent germanContent() => ResumeContent(
        personal: const PersonalInfo(
          firstName: 'Jonas',
          lastName: 'Müller',
          jobTitle: 'Softwareentwickler',
          email: 'jonas.mueller@example.de',
          phone: '+49 30 1234567',
          city: 'Berlin',
          country: 'Deutschland',
          summary: 'Softwareentwickler mit sechs Jahren Erfahrung im Aufbau '
              'von Zahlungssystemen.',
        ),
        experiences: <Experience>[
          Experience(
            id: 'exp-de',
            jobTitle: 'Senior Softwareentwickler',
            company: 'Nordwind Zahlungssysteme GmbH',
            location: 'Berlin',
            startDate: const YearMonth(2021, 3),
            isCurrent: true,
            responsibilities: const <String>[
              'Entwicklung des Hauptbuchdienstes für vier Millionen '
                  'Transaktionen pro Tag.',
              'Reduzierung der Zahlungslatenz und Erhöhung der Stabilität.',
            ],
          ),
        ],
        education: const <Education>[
          Education(
            id: 'edu-de',
            institution: 'Technische Universität München',
            degree: 'B.Sc. Informatik',
            startDate: YearMonth(2012, 10),
            endDate: YearMonth(2016, 9),
          ),
        ],
        skills: const <Skill>[
          Skill(id: 's-de-1', name: 'Dart'),
          Skill(id: 's-de-2', name: 'PostgreSQL'),
        ],
      );

  // ── Tests ────────────────────────────────────────────────────────────────

  group('a one-page CV', () {
    test('renders as a valid single-page PDF with searchable text', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.unitedKingdom,
          cvType: CvType.professionalCv,
          content: englishContent(roles: 1),
        ),
        RegionCode.unitedKingdom,
        en,
        expectPages: 1,
      );

      expectText(text, 'Sara Ahmadi');
      expectText(text, 'Backend Developer');
      expectText(text, 'sara.ahmadi@example.com');
      expectText(text, 'Northwind Payments');
      expectText(text, 'University of Edinburgh');
      expectText(text, 'Kafka');
    });

    test('keeps a phone number intact', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.unitedKingdom,
          cvType: CvType.professionalCv,
          content: englishContent(roles: 1),
        ),
        RegionCode.unitedKingdom,
        en,
      );
      final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
      expect(digits, contains('447700900123'));
    });
  });

  group('a multi-page CV', () {
    test('spills onto another page instead of shrinking the text', () async {
      final ResumePdfResult result = await render(
        buildResume(
          region: RegionCode.international,
          cvType: CvType.professionalCv,
          content: englishContent(roles: 6),
        ),
        RegionCode.international,
        en,
      );

      expect(
        result.pageCount,
        greaterThan(1),
        reason: 'six roles do not fit on one page, and the engine must add a '
            'page rather than shrink the type to fit',
      );
    });

    test('content from the first role survives the page break', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.international,
          cvType: CvType.professionalCv,
          content: englishContent(roles: 4),
        ),
        RegionCode.international,
        en,
      );
      expectText(text, 'Sara Ahmadi');
      expectText(text, 'Mentored four engineers');
      expectText(text, 'University of Edinburgh');
    });
  });

  group('language and script', () {
    test('Persian text comes back out of the PDF as Persian', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.iran,
          cvType: CvType.professionalCv,
          content: persianContent(),
          languageCode: 'fa',
        ),
        RegionCode.iran,
        fa,
      );

      expectText(text, 'سارا', because: 'the first name');
      expectText(text, 'احمدی', because: 'the family name');
      expectText(text, 'شرکت پرداخت شمال', because: 'the employer');
      expectText(text, 'دانشگاه تهران', because: 'the university');
    });

    test('German diacritics survive', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.germany,
          cvType: CvType.professionalCv,
          content: germanContent(),
          languageCode: 'de',
        ),
        RegionCode.germany,
        de,
      );

      expectText(text, 'Nordwind Zahlungssysteme', because: 'the employer');
      expectText(text, 'Softwareentwickler', because: 'the job title');
      expectText(text, 'Müller', because: 'the surname keeps its umlaut');
    });

    test('the headings follow the document, not the app', () async {
      // A Persian speaker applying in Germany gets German headings, because
      // the person reading the PDF is a German recruiter.
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.germany,
          cvType: CvType.professionalCv,
          content: germanContent(),
          languageCode: 'de',
        ),
        RegionCode.germany,
        de,
      );
      final String flat = squash(text).toLowerCase();
      expect(
        flat.contains('berufserfahrung') ||
            flat.contains('ausbildung') ||
            flat.contains('kenntnisse'),
        isTrue,
        reason: 'expected at least one German section heading, got: '
            '${flat.length > 300 ? flat.substring(0, 300) : flat}',
      );
    });
  });

  group('paper size', () {
    test('the United States gets US Letter, not A4', () async {
      final ResumePdfResult result = await render(
        buildResume(
          region: RegionCode.unitedStates,
          cvType: CvType.jobResume,
          content: englishContent(roles: 1),
          templateId: 'ats',
          paperSize: PaperSize.usLetter,
        ),
        RegionCode.unitedStates,
        en,
      );

      // The media box is the only proof that the paper choice reached the
      // renderer, rather than merely being stored on the document.
      final String raw = latin1.decode(result.bytes, allowInvalid: true);
      final RegExp letter = RegExp(
        r'/MediaBox\s*\[\s*0(\.0+)?\s+0(\.0+)?\s+612(\.\d+)?\s+792(\.\d+)?',
      );
      final RegExp a4 = RegExp(
        r'/MediaBox\s*\[\s*0(\.0+)?\s+0(\.0+)?\s+595(\.\d+)?\s+84[12](\.\d+)?',
      );
      expect(letter.hasMatch(raw), isTrue, reason: 'no US Letter media box');
      expect(a4.hasMatch(raw), isFalse, reason: 'A4 media box in a US document');
    });

    test('an A4 document carries no US Letter media box', () async {
      final ResumePdfResult result = await render(
        buildResume(
          region: RegionCode.germany,
          cvType: CvType.professionalCv,
          content: germanContent(),
          languageCode: 'de',
        ),
        RegionCode.germany,
        de,
      );
      final String raw = latin1.decode(result.bytes, allowInvalid: true);
      expect(
        RegExp(r'/MediaBox\s*\[\s*0(\.0+)?\s+0(\.0+)?\s+612').hasMatch(raw),
        isFalse,
      );
    });
  });

  group('the engine never silently drops content', () {
    test('every bullet the user wrote appears in the PDF', () async {
      final ResumeContent content = englishContent(roles: 2);
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.unitedKingdom,
          cvType: CvType.professionalCv,
          content: content,
        ),
        RegionCode.unitedKingdom,
        en,
      );

      for (final Experience role in content.experiences) {
        for (final String bullet in role.responsibilities) {
          final String tail =
              bullet.length > 40 ? bullet.substring(bullet.length - 30) : bullet;
          expectText(text, tail, because: 'this bullet must be printed: $bullet');
        }
      }
    });

    test('an empty document still produces a file that opens', () async {
      final String text = await renderAndRead(
        buildResume(
          region: RegionCode.international,
          cvType: CvType.professionalCv,
          content: ResumeContent.empty,
        ),
        RegionCode.international,
        en,
        expectPages: 1,
      );
      expect(text.length, lessThan(500), reason: 'nothing to print, no padding');
    });
  });

  group('the export service', () {
    test('names the file after the candidate, never the id', () {
      final Resume resume = buildResume(
        region: RegionCode.unitedKingdom,
        cvType: CvType.professionalCv,
        content: englishContent(roles: 1),
      );
      expect(const PdfExportService().fileNameFor(resume), 'Sara_Ahmadi.pdf');
    });

    test('falls back to the title, then to CV', () {
      final Resume untitled = buildResume(
        region: RegionCode.unitedKingdom,
        cvType: CvType.professionalCv,
        content: ResumeContent.empty,
        title: 'My CV',
      );
      expect(const PdfExportService().fileNameFor(untitled), 'My_CV.pdf');

      final Resume nameless = buildResume(
        region: RegionCode.unitedKingdom,
        cvType: CvType.professionalCv,
        content: ResumeContent.empty,
        title: '',
      );
      expect(const PdfExportService().fileNameFor(nameless), 'CV.pdf');
    });

    test('a name that is hostile to file systems is sanitised', () {
      final Resume resume = buildResume(
        region: RegionCode.international,
        cvType: CvType.professionalCv,
        content: const ResumeContent(
          personal: PersonalInfo(firstName: 'Ana', lastName: 'Maria /Smith:'),
        ),
      );
      final String name = const PdfExportService().fileNameFor(resume);
      expect(name, endsWith('.pdf'));
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
    });
  });
}
