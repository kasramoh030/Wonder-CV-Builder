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
import 'package:cv_pro/domain/enums/proficiency.dart';
import 'package:cv_pro/domain/enums/region_code.dart';
import 'package:cv_pro/domain/enums/section_key.dart';
import 'package:cv_pro/domain/templates/resume_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures are built the way a real user's data arrives, so the analyser is
/// exercised against the same shapes the database produces.
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

const ResumeContent strongContent = ResumeContent(
  personal: PersonalInfo(
    firstName: 'Layla',
    lastName: 'Hassani',
    jobTitle: 'Senior Backend Engineer',
    email: 'layla@example.com',
    phone: '+44 7700 900123',
    city: 'London',
    country: 'United Kingdom',
    summary: 'Backend engineer with nine years building payment systems in Go '
        'and Python. Cut settlement latency by 62% across a platform handling '
        'three million transactions a day, and led a team of six through a '
        'migration to Kubernetes.',
  ),
  experiences: <Experience>[
    Experience(
      id: 'e1',
      company: 'Monzo',
      jobTitle: 'Senior Backend Engineer',
      location: 'London',
      startDate: YearMonth(2021, 3),
      isCurrent: true,
      achievements: <String>[
        'Reduced settlement latency 62% by rewriting the ledger service in Go',
        'Led a team of six engineers through a Kubernetes migration',
        'Designed an idempotency layer that removed 1400 duplicate payments a month',
      ],
      technologies: <String>['Go', 'PostgreSQL', 'Kubernetes'],
    ),
    Experience(
      id: 'e2',
      company: 'Revolut',
      jobTitle: 'Backend Engineer',
      location: 'London',
      startDate: YearMonth(2018, 6),
      endDate: YearMonth(2021, 2),
      achievements: <String>[
        'Built a fraud-scoring service that processed 40 million requests a day',
        'Cut infrastructure spend by 180000 pounds a year',
        'Mentored four junior engineers to mid level',
      ],
      technologies: <String>['Python', 'AWS'],
    ),
  ],
  education: <Education>[
    Education(
      id: 'ed1',
      institution: 'University of Tehran',
      degree: 'BSc',
      fieldOfStudy: 'Computer Engineering',
      startDate: YearMonth(2014, 9),
      endDate: YearMonth(2018, 6),
    ),
  ],
  skills: <Skill>[
    Skill(id: 's1', name: 'Go', level: SkillLevel.expert),
    Skill(id: 's2', name: 'Python', level: SkillLevel.advanced),
    Skill(id: 's3', name: 'PostgreSQL', level: SkillLevel.advanced),
    Skill(id: 's4', name: 'Kubernetes', level: SkillLevel.advanced),
    Skill(id: 's5', name: 'Distributed systems', level: SkillLevel.expert),
    Skill(id: 's6', name: 'Observability', level: SkillLevel.advanced),
  ],
  languages: <LanguageSkill>[
    LanguageSkill(id: 'l1', language: 'English', level: LanguageLevel.fluent),
    LanguageSkill(id: 'l2', language: 'Persian', level: LanguageLevel.native),
  ],
);

const RegionalProfile neutral = RegionalProfile(id: 'international');

void main() {
  final AnalyzerEngine engine = AnalyzerEngine();
  const ResumeTemplate defaultTemplate = ResumeTemplates.professional;

  AnalysisReport analyse(
    Resume resume, {
    RegionalProfile profile = neutral,
    ResumeTemplate template = defaultTemplate,
    JobMatchReport? jobMatch,
  }) =>
      engine.analyse(AnalysisRequest(
        resume: resume,
        profile: profile,
        template: template,
        jobMatch: jobMatch,
      ));

  List<String> codesOf(AnalysisReport report) =>
      report.recommendations.map((Recommendation r) => r.code).toList();

  test('a strong CV scores well and produces no critical findings', () {
    final AnalysisReport report =
        analyse(resumeWith(content: strongContent));

    expect(report.totalScore, greaterThanOrEqualTo(75));
    expect(report.countOf(IssuePriority.critical), 0);
    expect(report.stats.bulletCount, 6);
    expect(report.stats.actionVerbRatio, greaterThan(0.8));
    expect(report.stats.quantifiedRatio, greaterThan(0.6));
    expect(report.strengths, isNotEmpty);
    expect(report.engineVersion, AnalyzerEngine.engineVersion);
    expect(report.source, AnalysisSource.offline);
  });

  test('an empty CV fails loudly instead of scoring zero silently', () {
    final AnalysisReport report =
        analyse(resumeWith(content: ResumeContent.empty));

    expect(report.totalScore, lessThan(50));
    expect(
      codesOf(report),
      containsAll(<String>[
        'content.missingName',
        'content.missingContact',
        'content.noExperience',
        'content.noSkills',
      ]),
    );
  });

  test('every recommendation carries a priority and a category', () {
    final AnalysisReport report =
        analyse(resumeWith(content: ResumeContent.empty));

    for (final Recommendation r in report.recommendations) {
      expect(r.code, isNotEmpty);
      expect(IssuePriority.values, contains(r.priority));
      expect(RecommendationCategory.values, contains(r.category));
    }
    // Sorted output puts the most consequential finding first.
    expect(report.sortedRecommendations.first.priority, IssuePriority.critical);
  });

  test('weak writing is detected by pattern, not by opinion about content', () {
    const ResumeContent weak = ResumeContent(
      personal: PersonalInfo(
        firstName: 'Ali',
        lastName: 'Rad',
        email: 'ali@example.com',
        summary: 'Hard worker.',
      ),
      experiences: <Experience>[
        Experience(
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
      skills: <Skill>[Skill(id: 's1', name: 'Python')],
    );

    final AnalysisReport report = analyse(resumeWith(content: weak));
    final List<String> codes = codesOf(report);

    expect(codes, contains('content.fillerPhrases'));
    expect(codes, contains('content.weakVerbOpeners'));
    expect(codes, contains('content.lowQuantification'));
    expect(codes, contains('content.fewSkills'));
  });

  test('the region changes what the analyser expects and how it weights', () {
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

    final AnalysisReport report = analyse(
      resumeWith(
        content: strongContent,
        region: RegionCode.unitedStates,
        paperSize: PaperSize.usLetter,
      ),
      profile: us,
    );

    expect(report.regionId, 'united_states');
    final ScoreDimension ats = report.dimension(ScoreKind.ats)!;
    final ScoreDimension language = report.dimension(ScoreKind.language)!;
    // An ATS-heavy market weights that dimension more heavily.
    expect(ats.weight, greaterThan(language.weight));
  });

  test('a required regional section is reported when it is missing', () {
    const RegionalProfile germany = RegionalProfile(
      id: 'germany',
      sections: SectionPolicy(
        required: <SectionKey>[SectionKey.education],
        order: <SectionKey>[SectionKey.experience, SectionKey.education],
      ),
    );
    const ResumeContent noEducation = ResumeContent(
      personal: PersonalInfo(firstName: 'Anna', lastName: 'Muster'),
      experiences: <Experience>[
        Experience(
          id: 'e1',
          company: 'SAP',
          jobTitle: 'Developer',
          startDate: YearMonth(2019, 1),
          isCurrent: true,
          achievements: <String>['Delivered 3 releases on schedule'],
        ),
      ],
    );

    final AnalysisReport report = analyse(
      resumeWith(content: noEducation, region: RegionCode.germany),
      profile: germany,
    );

    expect(
      codesOf(report),
      contains('regional.missingRequiredSection'),
    );
    expect(report.regionId, 'germany');
  });

  test('a photo in a market that discourages one is flagged', () {
    const ResumeContent withPhoto = ResumeContent(
      personal: PersonalInfo(
        firstName: 'John',
        lastName: 'Smith',
        email: 'john@example.com',
        photoPath: '/tmp/photo.jpg',
        showPhoto: true,
      ),
    );
    const RegionalProfile us = RegionalProfile(
      id: 'united_states',
      photo: PhotoPolicy(policy: PhotoExpectation.discouraged),
    );

    final AnalysisReport report = analyse(
      resumeWith(content: withPhoto, region: RegionCode.unitedStates),
      profile: us,
    );

    expect(codesOf(report), contains('regional.photoNotExpected'));
    expect(
      report.atsChecks.firstWhere((AtsCheck c) => c.code == 'ats.noPhoto').passed,
      isFalse,
    );
  });

  test('regional advisories become findings, info-level ones do not', () {
    const RegionalProfile iran = RegionalProfile(
      id: 'iran',
      dateSystem: DateSystem.jalali,
      advisories: <RegionalAdvisory>[
        RegionalAdvisory(
          code: 'iran.calendarConsistency',
          severity: 'medium',
          text: 'Keep one calendar system throughout the document.',
        ),
        RegionalAdvisory(
          code: 'iran.note',
          severity: 'info',
          text: 'For your information.',
        ),
      ],
    );

    final AnalysisReport report = analyse(
      resumeWith(content: strongContent, region: RegionCode.iran),
      profile: iran,
    );
    final Iterable<Recommendation> regional = report.recommendations
        .where((Recommendation r) => r.category == RecommendationCategory.regional);

    expect(
      regional.any((Recommendation r) => r.code == 'iran.calendarConsistency'),
      isTrue,
    );
    // An advisory with no priority is informational: it stays out of the
    // recommendation list rather than being given a made-up severity.
    expect(regional.any((Recommendation r) => r.code == 'iran.note'), isFalse);
  });

  test('a decorative template costs ATS points without hurting structure', () {
    final AnalysisReport report = analyse(
      resumeWith(content: strongContent),
      template: ResumeTemplates.byId('creative'),
    );

    expect(report.dimension(ScoreKind.ats)!.score, lessThan(100));
    expect(report.dimension(ScoreKind.structure)!.score, greaterThan(60));
  });

  test('the job-match dimension only exists when an advert was analysed', () {
    final AnalysisReport withoutAdvert =
        analyse(resumeWith(content: strongContent));
    expect(withoutAdvert.dimension(ScoreKind.jobMatch), isNull);
    expect(withoutAdvert.keywords, isNull);

    final JobDescription advert = JobDescriptionAnalyzer().parse(
      rawText: 'Senior Backend Engineer\n\nRequirements:\n'
          '- 5 years of experience with Go and PostgreSQL\n'
          '- Kubernetes in production\n'
          '- Strong communication skills',
    );
    final JobMatchReport match = JobDescriptionAnalyzer().match(
      advert: advert,
      cv: CvTextIndex.of(resumeWith(content: strongContent)),
    );

    final AnalysisReport withAdvert = analyse(
      resumeWith(content: strongContent),
      jobMatch: match,
    );
    expect(withAdvert.dimension(ScoreKind.jobMatch), isNotNull);
    expect(withAdvert.keywords, isNotNull);
    expect(codesOf(withAdvert), contains('jobMatch.strongKeywordOverlap'));
  });

  test('resume stats always describe the document they measured', () {
    final Resume resume = resumeWith(content: strongContent);
    final AnalysisReport report = analyse(resume);

    expect(report.stats.bulletCount, CvTextIndex.of(resume).bullets.length);
    expect(report.stats.estimatedPages, greaterThanOrEqualTo(1));
    expect(report.stats.wordCount, greaterThan(80));
  });

  test('the analyser never writes content on the user\u2019s behalf', () {
    final AnalysisReport report =
        analyse(resumeWith(content: ResumeContent.empty));

    // Every finding is a description of what is missing, with no proposed
    // replacement text anywhere in the payload.
    for (final Recommendation r in report.recommendations) {
      for (final String value in r.params.values) {
        expect(value.toLowerCase(), isNot(contains('add ')));
      }
    }
  });
}
