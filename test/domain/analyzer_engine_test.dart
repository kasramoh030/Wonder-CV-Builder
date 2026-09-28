import 'package:cv_pro/domain/analysis/analyzer_engine.dart';
import 'package:cv_pro/domain/analysis/cv_text_index.dart';
import 'package:cv_pro/domain/analysis/job_description_analyzer.dart';
import 'package:cv_pro/domain/entities/analysis_report.dart';
import 'package:cv_pro/domain/entities/job_description.dart';
import 'package:cv_pro/domain/entities/regional_profile.dart';
import 'package:cv_pro/domain/entities/resume.dart';
import 'package:cv_pro/domain/entities/resume_content.dart';
import 'package:cv_pro/domain/entities/year_month.dart';
import 'package:cv_pro/domain/enums/cv_type.dart';
import 'package:cv_pro/domain/enums/document_options.dart';
import 'package:cv_pro/domain/enums/industry.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/enums/section_key.dart';
import 'package:cv_pro/domain/templates/resume_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures are built the way a real user's data arrives, so the analyser is
/// tested against the same shapes the database produces.
Resume resumeWith({
  required ResumeContent content,
  CvType cvType = CvType.professionalCv,
  RegionCode region = RegionCode.international,
  PaperSize paperSize = PaperSize.a4,
  String templateId = 'professional',
  List<SectionKey> hidden = const <SectionKey>[],
}) =>
    Resume(
      id: 'r1',
      title: 'Test CV',
      content: content,
      cvType: cvType,
      region: region,
      paperSize: paperSize,
      templateId: templateId,
      hiddenSections: hidden,
    );

ResumeContent strongContent() => ResumeContent(
      personal: const PersonalInfo(
        firstName: 'Layla',
        lastName: 'Hassani',
        jobTitle: 'Senior Backend Engineer',
        email: 'layla@example.com',
        phone: '+44 7700 900123',
        city: 'London',
        country: 'United Kingdom',
        summary: 'Backend engineer with nine years building payment systems '
            'in Go and Python. Cut settlement latency by 62% across a '
            'platform handling three million transactions a day, and led a '
            'team of six through a migration to Kubernetes.',
      ),
      experiences: <Experience>[
        const Experience(
          id: 'e1',
          company: 'Monzo',
          jobTitle: 'Senior Backend Engineer',
          location: 'London',
          startDate: YearMonth(2021, 3),
          isCurrent: true,
          responsibilities: <String>[],
          achievements: <String>[
            'Reduced settlement latency 62% by rewriting the ledger service in Go',
            'Led a team of six engineers through a Kubernetes migration',
            'Designed an idempotency layer that eliminated 1,400 duplicate payments a month',
          ],
          technologies: <String>['Go', 'PostgreSQL', 'Kubernetes'],
        ),
        const Experience(
          id: 'e2',
          company: 'Revolut',
          jobTitle: 'Backend Engineer',
          location: 'London',
          startDate: YearMonth(2018, 6),
          endDate: YearMonth(2021, 2),
          achievements: <String>[
            'Built a fraud-scoring service that processed 40 million requests a day',
            'Cut infrastructure spend by £180,000 a year',
            'Mentored four junior engineers to mid level',
          ],
          technologies: <String>['Python', 'AWS'],
        ),
      ],
      education: <Education>[
        const Education(
          id: 'ed1',
          institution: 'University of Tehran',
          degree: 'BSc',
          fieldOfStudy: 'Computer Engineering',
          startDate: YearMonth(2014, 9),
          endDate: YearMonth(2018, 6),
        ),
      ],
      skills: const <Skill>[
        Skill(id: 's1', name: 'Go', level: SkillLevel.expert),
        Skill(id: 's2', name: 'Python', level: SkillLevel.advanced),
        Skill(id: 's3', name: 'PostgreSQL', level: SkillLevel.advanced),
        Skill(id: 's4', name: 'Kubernetes', level: SkillLevel.advanced),
        Skill(id: 's5', name: 'Distributed systems', level: SkillLevel.expert),
        Skill(id: 's6', name: 'Observability', level: SkillLevel.advanced),
      ],
      languages: const <LanguageSkill>[
        LanguageSkill(id: 'l1', language: 'English', level: LanguageLevel.fluent),
        LanguageSkill(id: 'l2', language: 'Persian', level: LanguageLevel.native),
      ],
    );

const RegionalProfile neutral = RegionalProfile(id: 'international');

void main() {
  final AnalyzerEngine engine = AnalyzerEngine();
  const ResumeTemplate defaultTemplate = ResumeTemplates.professional;

  test('a strong CV scores well and produces no critical findings', () {
    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: strongContent()),
      profile: neutral,
      template: defaultTemplate,
    ));

    expect(report.totalScore, greaterThanOrEqualTo(75));
    expect(report.countOf(IssuePriority.critical), 0);
    expect(report.stats.bulletCount, 6);
    expect(report.stats.actionVerbRatio, greaterThan(0.8));
    expect(report.stats.quantifiedRatio, greaterThan(0.6));
    expect(report.strengths, isNotEmpty);
    expect(report.engineVersion, AnalyzerEngine.engineVersion);
  });

  test('an empty CV fails loudly instead of scoring zero silently', () {
    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: ResumeContent.empty),
      profile: neutral,
      template: defaultTemplate,
    ));

    expect(report.totalScore, lessThan(50));
    final List<String> codes = report.recommendations
        .map((Recommendation r) => r.code)
        .toList();
    expect(codes, contains('content.missingName'));
    expect(codes, contains('content.missingContact'));
    expect(codes, contains('content.noExperience'));
    expect(codes, contains('content.noSkills'));
  });

  test('every recommendation carries a priority and a category', () {
    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: ResumeContent.empty),
      profile: neutral,
      template: defaultTemplate,
    ));

    for (final Recommendation r in report.recommendations) {
      expect(r.code, isNotEmpty);
      expect(IssuePriority.values, contains(r.priority));
      expect(RecommendationCategory.values, contains(r.category));
    }
    // Sorted output puts critical findings first, which is what the UI shows.
    final List<Recommendation> sorted = report.sortedRecommendations;
    expect(sorted.first.priority, IssuePriority.critical);
  });

  test('weak writing is detected by pattern, not by opinion about content', () {
    final Resume weak = resumeWith(
      content: ResumeContent(
        personal: const PersonalInfo(
          firstName: 'Ali',
          lastName: 'Rad',
          email: 'ali@example.com',
          summary: 'Hard worker.',
        ),
        experiences: <Experience>[
          const Experience(
            id: 'e1',
            company: 'Somewhere',
            jobTitle: 'Engineer',
            startDate: YearMonth(2020, 1),
            responsibilities: <String>[
              'Responsible for the backend',
              'Worked on various things',
              'Helped with the migration',
            ],
          ),
        ],
        skills: const <Skill>[Skill(id: 's1', name: 'Python')],
      ),
    );

    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: weak,
      profile: neutral,
      template: defaultTemplate,
    ));
    final List<String> codes =
        report.recommendations.map((Recommendation r) => r.code).toList();

    expect(codes, contains('content.fillerPhrases'));
    expect(codes, contains('content.weakVerbOpeners'));
    expect(codes, contains('content.lowQuantification'));
    expect(codes, contains('content.fewSkills'));
  });

  test('the region changes what the analyser expects', () {
    // Same CV, two markets: the US one is judged against its one-page
    // convention and stricter ATS weight.
    final Resume resume = resumeWith(
      content: strongContent(),
      region: RegionCode.unitedStates,
      paperSize: PaperSize.usLetter,
    );
    const RegionalProfile us = RegionalProfile(
      id: 'united_states',
      paperSize: PaperSize.usLetter,
      page: PageGuidance(min: 1, max: 2, idealMax: 1),
      ats: AtsPolicy(strictness: AtsStrictness.high),
      sections: SectionPolicy(
        order: <SectionKey>[SectionKey.summary, SectionKey.experience],
        required: <SectionKey>[SectionKey.experience],
      ),
    );

    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resume,
      profile: us,
      template: defaultTemplate,
    ));

    expect(report.regionId, 'united_states');
    expect(report.dimension(ScoreKind.ats), isNotNull);
    // The ATS dimension is weighted more heavily in a strict market.
    expect(
      report.dimension(ScoreKind.ats)!.weight,
      greaterThan(report.dimension(ScoreKind.language)!.weight),
    );
  });

  test('a required regional section is reported when missing', () {
    const RegionalProfile germany = RegionalProfile(
      id: 'germany',
      sections: SectionPolicy(
        required: <SectionKey>[SectionKey.education],
        order: <SectionKey>[SectionKey.experience, SectionKey.education],
      ),
    );
    final Resume noEducation = resumeWith(
      content: ResumeContent(
        personal: const PersonalInfo(firstName: 'Anna', lastName: 'Muster'),
        experiences: <Experience>[
          const Experience(
            id: 'e1',
            company: 'SAP',
            jobTitle: 'Developer',
            startDate: YearMonth(2019, 1),
            isCurrent: true,
            achievements: <String>['Delivered 3 releases on schedule'],
          ),
        ],
      ),
      region: RegionCode.germany,
    );

    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: noEducation,
      profile: germany,
      template: defaultTemplate,
    ));

    expect(
      report.recommendations
          .any((Recommendation r) => r.code == 'regional.missingRequiredSection'),
      isTrue,
    );
    expect(report.regionId, 'germany');
  });

  test('a photo in a market that discourages one is flagged', () {
    final Resume withPhoto = resumeWith(
      content: ResumeContent(
        personal: const PersonalInfo(
          firstName: 'John',
          lastName: 'Smith',
          email: 'john@example.com',
          photoPath: '/tmp/photo.jpg',
          showPhoto: true,
        ),
      ),
      region: RegionCode.unitedStates,
    );

    const RegionalProfile us = RegionalProfile(
      id: 'united_states',
      photo: PhotoPolicy(policy: PhotoExpectation.discouraged),
    );

    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: withPhoto,
      profile: us,
      template: defaultTemplate,
    ));

    expect(
      report.recommendations
          .any((Recommendation r) => r.code == 'regional.photoNotExpected'),
      isTrue,
    );
    expect(
      report.atsChecks.firstWhere((AtsCheck c) => c.code == 'ats.noPhoto').passed,
      isFalse,
    );
  });

  test('regional advisories become recommendations with their own priority', () {
    const RegionalProfile iran = RegionalProfile(
      id: 'iran',
      dateSystem: DateSystem.jalali,
      dateSystemOptions: <DateSystem>[DateSystem.gregorian, DateSystem.jalali],
      advisories: <RegionalAdvisory>[
        RegionalAdvisory(
          code: 'iran.calendarConsistency',
          severity: 'medium',
          text: 'Keep one calendar system throughout.',
        ),
        RegionalAdvisory(code: 'iran.note', severity: 'info', text: 'Just a note.'),
      ],
    );

    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: strongContent(), region: RegionCode.iran),
      profile: iran,
      template: defaultTemplate,
    ));

    final Iterable<Recommendation> regional = report.recommendations
        .where((Recommendation r) => r.category == RecommendationCategory.regional);
    expect(regional.any((Recommendation r) => r.code == 'iran.calendarConsistency'),
        isTrue);
    // An "info" advisory has no priority, so it never becomes a finding.
    expect(regional.any((Recommendation r) => r.code == 'iran.note'), isFalse);
  });

  test('a decorative template lowers the ATS dimension without other noise', () {
    final ResumeTemplate decorative = ResumeTemplates.byId('creative');
    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: strongContent()),
      profile: neutral,
      template: decorative,
    ));

    final ScoreDimension ats = report.dimension(ScoreKind.ats)!;
    final ScoreDimension structure = report.dimension(ScoreKind.structure)!;
    expect(ats.score, lessThan(100));
    expect(structure.score, greaterThan(60));
  });

  test('the job-match dimension only exists when an advert was analysed', () {
    final AnalysisReport withoutAdvert = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: strongContent()),
      profile: neutral,
      template: defaultTemplate,
    ));
    expect(withoutAdvert.dimension(ScoreKind.jobMatch), isNull);

    final JobDescription advert = JobDescriptionAnalyzer().parse(
      rawText: 'Senior Backend Engineer\n\nRequirements:\n'
          '- 5 years of experience with Go and PostgreSQL\n'
          '- Kubernetes in production\n'
          '- Strong communication skills',
    );
    final JobMatchReport match = JobDescriptionAnalyzer().match(
      advert: advert,
      cv: CvTextIndex.of(resumeWith(content: strongContent())),
    );

    final AnalysisReport withAdvert = engine.analyse(AnalysisRequest(
      resume: resumeWith(content: strongContent()),
      profile: neutral,
      template: defaultTemplate,
      jobMatch: match,
    ));
    expect(withAdvert.dimension(ScoreKind.jobMatch), isNotNull);
    expect(withAdvert.keywords, isNotNull);
  });

  test('resume stats always agree with the document they describe', () {
    final Resume resume = resumeWith(content: strongContent());
    final AnalysisReport report = engine.analyse(AnalysisRequest(
      resume: resume,
      profile: neutral,
      template: defaultTemplate,
    ));

    expect(report.stats.bulletCount, CvTextIndex.of(resume).bullets.length);
    expect(report.stats.estimatedPages, greaterThanOrEqualTo(1));
    expect(report.stats.wordCount, greaterThan(80));
  });
}
