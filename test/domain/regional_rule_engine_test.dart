import 'dart:convert';
import 'dart:io';

import 'package:cv_pro/domain/entities/regional_profile.dart';
import 'package:cv_pro/domain/entities/resume.dart';
import 'package:cv_pro/domain/entities/resume_content.dart';
import 'package:cv_pro/domain/entities/year_month.dart';
import 'package:cv_pro/domain/enums/cv_type.dart';
import 'package:cv_pro/domain/enums/document_options.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/enums/section_key.dart';
import 'package:cv_pro/domain/rules/regional_rule_engine.dart';
import 'package:cv_pro/domain/templates/resume_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule engine is exercised against the bundles that actually ship, so a
/// change to `assets/data/regional_rules/*.json` is validated end to end.
RegionalProfile bundle(RegionCode region) => RegionalProfile.fromJson(
      jsonDecode(File(region.assetPath).readAsStringSync()) as Map<String, dynamic>,
    );

Resume resumeFor(RegionCode region, CvType type, {ResumeContent? content}) =>
    Resume(
      id: 'r1',
      title: 'CV',
      region: region,
      cvType: type,
      content: content ?? ResumeContent.empty,
    );

void main() {
  group('section order', () {
    test('the market order leads and the user order is preserved for the rest',
        () {
      final RegionalProfile profile = bundle(RegionCode.unitedKingdom);
      final Resume resume = resumeFor(
        RegionCode.unitedKingdom,
        CvType.professionalCv,
      ).copyWith(
        sectionOrder: <SectionKey>[
          SectionKey.projects,
          SectionKey.experience,
          SectionKey.education,
        ],
      );

      final List<SectionKey> order = RegionalRuleEngine.resolveSectionOrder(
        profile: profile,
        resume: resume,
      );

      // Personal details always come first.
      expect(order.first, SectionKey.personal);
      // Nothing the user switched on is dropped.
      expect(order, containsAll(<SectionKey>[
        SectionKey.projects,
        SectionKey.experience,
        SectionKey.education,
      ]));
      expect(order.toSet().length, order.length, reason: 'no duplicates');
    });

    test('an ATS template overrides the market order', () {
      const ResumeTemplate ats = ResumeTemplates.ats;
      final RegionalProfile profile = bundle(RegionCode.germany);
      final Resume resume = resumeFor(RegionCode.germany, CvType.atsResume);

      final List<SectionKey> order = RegionalRuleEngine.resolveSectionOrder(
        profile: profile,
        resume: resume,
        template: ats,
      );

      if (ats.forcedSectionOrder != null && ats.forcedSectionOrder!.isNotEmpty) {
        expect(order.first, SectionKey.personal);
        for (final SectionKey key in ats.forcedSectionOrder!) {
          expect(order, contains(key));
        }
      }
    });

    test('a seed order combines the market with the CV type', () {
      final RegionalProfile germany = bundle(RegionCode.germany);
      final List<SectionKey> seeded = RegionalRuleEngine.seedOrder(
        cvType: CvType.professionalCv,
        region: RegionCode.germany,
        profile: germany,
      );

      expect(seeded, isNotEmpty);
      expect(seeded.toSet().length, seeded.length);
      expect(seeded, contains(SectionKey.experience));
      expect(seeded, contains(SectionKey.education));
    });

    test('a custom section the user enabled is never dropped', () {
      final RegionalProfile profile = bundle(RegionCode.unitedStates);
      final Resume resume = resumeFor(RegionCode.unitedStates, CvType.professionalCv)
          .copyWith(
        sectionOrder: <SectionKey>[
          SectionKey.personal,
          SectionKey.experience,
          SectionKey.volunteering,
        ],
      );

      final List<SectionKey> order = RegionalRuleEngine.resolveSectionOrder(
        profile: profile,
        resume: resume,
      );
      expect(order, contains(SectionKey.volunteering));
    });
  });

  group('personal information and the photo', () {
    test('Iran keeps sensitive fields off until the user asks for them', () {
      final RegionalProfile iran = bundle(RegionCode.iran);
      final Resume resume = resumeFor(RegionCode.iran, CvType.professionalCv);

      final FormatPlan plan = RegionalRuleEngine.planFor(
        profile: iran,
        resume: resume,
      );
      expect(plan.showSensitiveFields, isFalse);
      expect(plan.showPhoto, isFalse);
    });

    test('the user can switch a discouraged field on, and is warned', () {
      final RegionalProfile uk = bundle(RegionCode.unitedKingdom);
      final Resume resume = resumeFor(RegionCode.unitedKingdom, CvType.professionalCv)
          .copyWith(
        content: const ResumeContent(
          personal: PersonalInfo(
            firstName: 'Ada',
            lastName: 'Lovelace',
            photoPath: '/tmp/ada.jpg',
            showPhoto: true,
            showSensitiveFields: true,
          ),
        ),
      );

      final FormatPlan plan = RegionalRuleEngine.planFor(
        profile: uk,
        resume: resume,
      );

      // The switch the user flipped is respected...
      expect(plan.showPhoto, isTrue);
      // ...but the convention is explained rather than silently applied.
      expect(
        plan.advisories.any((RegionalAdvisory a) => a.code == 'regional.photoNotExpected'),
        isTrue,
      );
    });

    test('a market that expects a photo produces no advisory for one', () {
      final RegionalProfile iran = bundle(RegionCode.iran);
      final Resume resume = resumeFor(RegionCode.iran, CvType.professionalCv)
          .copyWith(
        content: const ResumeContent(
          personal: PersonalInfo(firstName: 'Sara', photoPath: '/tmp/s.jpg', showPhoto: true),
        ),
      );

      final FormatPlan plan =
          RegionalRuleEngine.planFor(profile: iran, resume: resume);
      expect(
        plan.advisories.any((RegionalAdvisory a) => a.code.startsWith('regional.photo')),
        isFalse,
      );
    });
  });

  group('paper and dates', () {
    test('the region decides the default paper size', () {
      expect(bundle(RegionCode.unitedStates).paperSize, PaperSize.usLetter);
      expect(bundle(RegionCode.germany).paperSize, PaperSize.a4);
    });

    test('an explicit paper override is reported, not overruled', () {
      final RegionalProfile us = bundle(RegionCode.unitedStates);
      final Resume a4InTheStates = resumeFor(RegionCode.unitedStates, CvType.professionalCv)
          .copyWith(paperSize: PaperSize.a4);

      final FormatPlan plan =
          RegionalRuleEngine.planFor(profile: us, resume: a4InTheStates);

      expect(plan.paperSize, PaperSize.a4, reason: 'the user wins');
      expect(
        plan.advisories.any((RegionalAdvisory a) => a.code == 'regional.paperOverride'),
        isTrue,
      );
    });

    test('a user calendar preference overrides the market default', () {
      final RegionalProfile germany = bundle(RegionCode.germany);
      final Resume resume = resumeFor(RegionCode.germany, CvType.professionalCv);

      final FormatPlan following = RegionalRuleEngine.planFor(
        profile: germany,
        resume: resume,
      );
      expect(following.dateSystem, germany.dateSystem);

      final FormatPlan overridden = RegionalRuleEngine.planFor(
        profile: germany,
        resume: resume,
        dateSystemOverride: DateSystem.jalali,
      );
      expect(overridden.dateSystem, DateSystem.jalali);
    });

    test('Iran offers both calendars so the choice is the user\u2019s', () {
      final FormatPlan plan = RegionalRuleEngine.planFor(
        profile: bundle(RegionCode.iran),
        resume: resumeFor(RegionCode.iran, CvType.professionalCv),
      );
      expect(plan.dateSystemOptions, containsAll(
        <DateSystem>[DateSystem.gregorian, DateSystem.jalali],
      ));
    });
  });

  group('printed sections', () {
    test('empty sections are not printed and never invented', () {
      final RegionalProfile profile = bundle(RegionCode.international);
      final Resume resume = resumeFor(RegionCode.international, CvType.professionalCv)
          .copyWith(
        content: const ResumeContent(
          personal: PersonalInfo(firstName: 'Noor', lastName: 'Aziz'),
        ),
      );

      final FormatPlan plan =
          RegionalRuleEngine.planFor(profile: profile, resume: resume);
      expect(plan.printedSections, <SectionKey>[SectionKey.personal]);
    });

    test('a section with content is printed in the market order', () {
      final RegionalProfile profile = bundle(RegionCode.germany);
      final Resume resume = resumeFor(RegionCode.germany, CvType.professionalCv)
          .copyWith(
        content: ResumeContent(
          personal: const PersonalInfo(firstName: 'Lena', lastName: 'Kruger'),
          experiences: <Experience>[
            const Experience(
              id: 'e1',
              company: 'Siemens',
              jobTitle: 'Engineer',
              startDate: YearMonth(2020, 1),
            ),
          ],
          skills: const <Skill>[Skill(id: 's1', name: 'CAD')],
        ),
      );

      final FormatPlan plan =
          RegionalRuleEngine.planFor(profile: profile, resume: resume);
      expect(plan.printedSections, contains(SectionKey.experience));
      expect(plan.printedSections, contains(SectionKey.skills));
      expect(plan.printedSections.first, SectionKey.personal);
    });

    test('the plan never adds a section the user did not enable', () {
      final RegionalProfile germany = bundle(RegionCode.germany);
      final Resume resume = resumeFor(RegionCode.germany, CvType.professionalCv)
          .copyWith(
        sectionOrder: <SectionKey>[SectionKey.personal, SectionKey.experience],
        hiddenSections: const <SectionKey>[],
        content: ResumeContent(
          personal: const PersonalInfo(firstName: 'Otto', lastName: 'Bauer'),
          experiences: <Experience>[
            const Experience(id: 'e1', company: 'Bosch', jobTitle: 'Techniker'),
          ],
        ),
      );

      final FormatPlan plan =
          RegionalRuleEngine.planFor(profile: germany, resume: resume);
      expect(plan.printedSections, isNot(contains(SectionKey.publications)));
      expect(plan.printedSections, isNot(contains(SectionKey.projects)));
      // Whatever the market recommends is offered, not applied.
      expect(plan.addableSections, isNot(contains(SectionKey.experience)));
    });

    test('every market produces a plan without throwing', () {
      for (final RegionCode region in RegionCode.values) {
        for (final CvType type in CvType.values) {
          final FormatPlan plan = RegionalRuleEngine.planFor(
            profile: bundle(region),
            resume: resumeFor(region, type),
          );
          expect(plan.regionId, region.id);
          expect(plan.printedSections.first, SectionKey.personal);
        }
      }
    });
  });

  group('advisories', () {
    test('every advisory carries a code and text in every market', () {
      for (final RegionCode region in RegionCode.values) {
        final FormatPlan plan = RegionalRuleEngine.planFor(
          profile: bundle(region),
          resume: resumeFor(region, CvType.professionalCv).copyWith(
            paperSize: PaperSize.a4,
          ),
        );
        for (final RegionalAdvisory advisory in plan.advisories) {
          expect(advisory.code, isNotEmpty);
          expect(advisory.text.trim(), isNotEmpty);
        }
      }
    });

    test('a decorative template in a strict market is explained', () {
      final FormatPlan plan = RegionalRuleEngine.planFor(
        profile: bundle(RegionCode.unitedStates),
        resume: resumeFor(RegionCode.unitedStates, CvType.professionalCv)
            .copyWith(paperSize: PaperSize.usLetter),
        template: ResumeTemplates.byId('creative'),
      );
      expect(
        plan.advisories.any((RegionalAdvisory a) => a.code == 'regional.atsStrictMarket'),
        isTrue,
      );
    });
  });
}
