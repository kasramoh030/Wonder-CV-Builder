import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_fa.dart';

/// Typed, hand-authored localisation layer.
///
/// Why not `gen_l10n` + ARB? Two reasons that matter for this product:
///
/// 1. **Determinism.** The CV builder ships 3 locales × ~700 keys, and the
///    analyser needs to look up *the same* enum label from pure-Dart code that
///    has no [BuildContext]. A plain abstract class can be consumed from the
///    domain layer (`AppLocalizations.ofCode('fa')`) as easily as from a
///    widget, which generated delegates cannot do without a context.
/// 2. **No build-time codegen.** Fewer moving parts between a clean checkout
///    and a signed AAB.
///
/// Adding a locale is a three-line change: add a subclass, register it in
/// [_all], and add it to [supportedLocales].
abstract class AppLocalizations {
  const AppLocalizations();

  /// Locale this bundle serves.
  Locale get locale;

  /// Native name of the language, shown in the language picker.
  String get languageName;

  /// Short display code, e.g. `EN`.
  String get languageCodeShort;

  // ── Framework plumbing ───────────────────────────────────────────────────

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('de'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, AppLocalizations> _all = <String, AppLocalizations>{
    'en': StringsEn(),
    'fa': StringsFa(),
    'de': StringsDe(),
  };

  /// Resolves a bundle from a [Locale], falling back to English.
  static AppLocalizations ofCode(String? code) =>
      _all[code] ?? const StringsEn();

  /// Resolves a bundle from a [BuildContext].
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const StringsEn();

  /// Locale resolution that prefers an exact language match, then English.
  static Locale resolve(Locale? requested, Iterable<Locale> supported) {
    if (requested == null) return const Locale('en');
    for (final Locale candidate in supported) {
      if (candidate.languageCode == requested.languageCode) return candidate;
    }
    return const Locale('en');
  }

  /// `true` when the language is written right-to-left.
  bool get isRtl => locale.languageCode == 'fa';

  /// Text direction implied by the locale.
  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

  // ── App-wide ─────────────────────────────────────────────────────────────
  String get appName;
  String get appTagline;
  String get continueLabel;
  String get back;
  String get next;
  String get skip;
  String get done;
  String get cancel;
  String get save;
  String get saveAndClose;
  String get delete;
  String get duplicate;
  String get rename;
  String get edit;
  String get close;
  String get retry;
  String get search;
  String get clear;
  String get confirm;
  String get optional;
  String get required;
  String get none;
  String get all;
  String get yes;
  String get no;
  String get loading;
  String get somethingWentWrong;
  String get tryAgain;

  // ── Onboarding ───────────────────────────────────────────────────────────
  String get onboardingWelcomeTitle;
  String get onboardingWelcomeBody;
  String get onboardingPrivateTitle;
  String get onboardingPrivateBody;
  String get onboardingOfflineTitle;
  String get onboardingOfflineBody;
  String get onboardingGetStarted;
  String get onboardingChooseLanguage;
  String get onboardingWhatCreating;
  String get onboardingWhatCreatingHint;
  String get onboardingWhereApplying;
  String get onboardingWhereApplyingHint;
  String get industryLabel;
  String get onboardingAllSetTitle;
  String get onboardingAllSetBody;
  String get onboardingCreateFirstCv;

  // ── Dashboard ────────────────────────────────────────────────────────────
  String get dashboardTitle;
  String get myCvs;
  String get masterProfile;
  String get masterProfileSubtitle;
  String get cvAnalyzer;
  String get cvAnalyzerSubtitle;
  String get jobAnalyzer;
  String get jobAnalyzerSubtitle;
  String get templates;
  String get templatesSubtitle;
  String get recentDocuments;
  String get createNewCv;
  String get noCvsTitle;
  String get noCvsBody;
  String get noRecentDocuments;
  String get updatedOn;
  String get createdOn;
  String get documentsCount;
  String get cvsCount;

  // ── CV types ─────────────────────────────────────────────────────────────
  String get cvTypeJobResume;
  String get cvTypeProfessionalCv;
  String get cvTypeAcademicCv;
  String get cvTypeStudentResume;
  String get cvTypeInternshipResume;
  String get cvTypeGraduateResume;
  String get cvTypeScholarshipCv;
  String get cvTypeResearchCv;
  String get cvTypePhdCv;
  String get cvTypeEuropass;
  String get cvTypeAts;

  // ── Regions ──────────────────────────────────────────────────────────────
  String get regionIran;
  String get regionEurope;
  String get regionGermany;
  String get regionUnitedKingdom;
  String get regionUnitedStates;
  String get regionInternational;

  // ── Sections ─────────────────────────────────────────────────────────────
  /// Word printed where an entry is still current, e.g. `Mar 2021 – Present`.
  String get presentLabel;

  String get sectionPersonal;
  String get sectionSummary;
  String get sectionExperience;
  String get sectionEducation;
  String get sectionSkills;
  String get sectionLanguages;
  String get sectionProjects;
  String get sectionCertifications;
  String get sectionAwards;
  String get sectionPublications;
  String get sectionVolunteering;
  String get sectionReferences;
  String get sectionCustom;
  String get sectionCourses;
  String get sectionInterests;
  String get sectionMilitaryService;
  String get sectionDrivingLicence;
  String get sectionResearchInterests;
  String get sectionResearchExperience;
  String get sectionTeachingExperience;
  String get sectionConferences;
  String get sectionGrants;
  String get sectionAcademicService;
  String get sectionMemberships;
  String get sectionAcademicAppointments;
  String get sectionPresentations;
  String get sectionAdditionalInfo;
  String get sectionDigitalSkills;
  String get sectionAchievements;
  String get sectionKeySkills;

  // ── Builder ──────────────────────────────────────────────────────────────
  String get builderTitle;
  String get builderSectionOrder;
  String get builderSectionOrderHint;
  String get builderAddSection;
  String get builderRemoveSection;
  String get builderDragToReorder;
  String get builderUnsavedChanges;
  String get builderSaved;
  String get builderAutosaved;
  String get builderEmptySectionHint;
  String get builderAddItem;
  String get builderPreview;
  String get builderPreviewHint;
  String get builderProgress;
  String get builderCompleteness;

  // ── Fields ───────────────────────────────────────────────────────────────
  String get fieldFirstName;
  String get fieldLastName;
  String get fieldFullName;
  String get fieldJobTitle;
  String get fieldEmail;
  String get fieldPhone;
  String get fieldCity;
  String get fieldProvince;
  String get fieldCountry;
  String get fieldLinkedIn;
  String get fieldGitHub;
  String get fieldWebsite;
  String get fieldPhoto;
  String get fieldSummary;
  String get fieldCompany;
  String get fieldLocation;
  String get fieldStartDate;
  String get fieldEndDate;
  String get fieldCurrentlyWorkHere;
  String get fieldResponsibilities;
  String get fieldAchievements;
  String get fieldTechnologies;
  String get fieldUniversity;
  String get fieldDegree;
  String get fieldFieldOfStudy;
  String get fieldGpa;
  String get fieldDescription;
  String get fieldSkillName;
  String get fieldSkillLevel;
  String get fieldLanguage;
  String get fieldLanguageLevel;
  String get fieldProjectName;
  String get fieldProjectUrl;
  String get fieldProjectRepo;
  String get fieldCertificateName;
  String get fieldOrganization;
  String get fieldDate;
  String get fieldCredentialId;
  String get fieldVerificationUrl;
  String get fieldTitle;
  String get fieldSubtitle;
  String get fieldPublisher;
  String get fieldMonth;
  String get fieldYear;
  String get fieldCategory;
  String get fieldRelationship;
  String get fieldAuthors;
  String get fieldDoi;
  String get fieldReferenceName;
  String get fieldReferenceTitle;
  String get fieldReferenceEmail;
  String get fieldReferencePhone;
  String get fieldCustomSectionTitle;
  String get fieldNationalId;
  String get fieldBirthDate;
  String get fieldGender;
  String get fieldNationality;
  String get fieldMaritalStatus;

  /// Hint shown next to sensitive fields that are hidden by default.
  String get sensitiveFieldNotice;

  // ── Skills & levels ──────────────────────────────────────────────────────
  String get skillLevelBeginner;
  String get skillLevelIntermediate;
  String get skillLevelAdvanced;
  String get skillLevelExpert;
  String get languageLevelBeginner;
  String get languageLevelIntermediate;
  String get languageLevelAdvanced;
  String get languageLevelFluent;
  String get languageLevelNative;

  // ── Preview & export ─────────────────────────────────────────────────────
  String get previewTitle;
  String get previewZoomIn;
  String get previewZoomOut;
  String get previewFitToScreen;
  String get previewPageOf;
  String get exportTitle;
  String get exportSavePdf;
  String get exportOpenPdf;
  String get exportSharePdf;
  String get exportPrint;
  String get exportJson;
  String get exportJsonHint;
  String get exportGenerating;
  String get exportSuccess;
  String get exportFailed;
  String get exportPaperSize;
  String get paperA4;
  String get paperLetter;
  String get pdfWarningPhotoMissing;
  String get pdfWarningPhotoWithAts;
  String get pdfWarningLongerThanConvention;
  String get exportFileName;
  String get exportIncludeLinks;

  // ── Analyzer ─────────────────────────────────────────────────────────────
  String get analyzerTitle;
  String get analyzerRunAnalysis;
  String get analyzerRerun;
  String get analyzerScoreTitle;
  String get analyzerScoreStructure;
  String get analyzerScoreContent;
  String get analyzerScoreAts;
  String get analyzerScoreLanguage;
  String get analyzerScoreJobMatch;
  String get analyzerRecommendations;
  String get analyzerNoIssuesTitle;
  String get analyzerNoIssuesBody;
  String get analyzerRunFirstTitle;
  String get analyzerRunFirstBody;
  String get analyzerOfflineBadge;
  String get analyzerOnlineBadge;
  String get analyzerDisclaimer;
  String get analyzerKeywordsFound;
  String get analyzerKeywordsMissing;
  String get analyzerKeywordHonestyNote;
  String get analyzerStrengths;
  String get analyzerImprovements;
  String get priorityCritical;
  String get priorityHigh;
  String get priorityMedium;
  String get priorityLow;

  // ── Job description ──────────────────────────────────────────────────────
  String get jobDescriptionTitle;
  String get jobDescriptionHint;
  String get jobAnalyze;
  String get jobPasteDescription;
  String get jobRequiredSkills;
  String get jobPreferredSkills;
  String get jobResponsibilities;
  String get jobQualifications;
  String get jobSoftSkills;
  String get jobSeniority;
  String get jobNoDescriptionTitle;
  String get jobNoDescriptionBody;
  String get jobMatchTitle;
  String get jobMatchSkills;
  String get jobMatchExperience;
  String get jobMatchEducation;
  String get jobMatchKeywords;
  String get jobMatchSeniority;
  String get jobMatchDomain;

  // ── AI ───────────────────────────────────────────────────────────────────
  String get aiTitle;
  String get aiAssistant;
  String get aiImproveSection;
  String get aiRewrite;
  String get aiImproveSummary;
  String get aiImproveExperience;
  String get aiWriteAchievement;
  String get aiFixGrammar;
  String get aiSuggest;
  String get aiSuggestion;
  String get aiAccept;
  String get aiEdit;
  String get aiReject;
  String get aiRegenerate;
  String get aiOriginal;
  String get aiProposed;
  String get aiNoFabricationNotice;
  String get aiNeedsInfoTitle;
  String get aiQuestionImproveRevenue;
  String get aiConsentTitle;
  String get aiConsentBody;
  String get aiConsentAccept;
  String get aiConsentDecline;
  String get aiOfflineNotice;
  String get aiNoKeyTitle;
  String get aiNoKeyBody;
  String get aiOpenSettings;
  String get aiProvider;
  String get aiApiKey;
  String get aiApiKeyHint;
  String get aiApiKeyStoredSecurely;
  String get aiModel;
  String get aiTestConnection;
  String get aiConnectionOk;
  String get aiConnectionFailed;

  // ── Import ───────────────────────────────────────────────────────────────
  String get importTitle;
  String get importFromPdf;
  String get importFromDocx;
  String get importFromTxt;
  String get importFromImage;
  String get importReviewTitle;
  String get importReviewBody;
  String get importConfirmImport;
  String get importNothingFound;
  String get importOcrUnavailableTitle;
  String get importOcrUnavailableBody;
  String get importParsingTitle;
  String get importParsingBody;

  // ── Network & privacy ────────────────────────────────────────────────────
  String get statusOffline;
  String get statusOnline;
  String get statusLocal;
  String get offlineBannerTitle;
  String get offlineBannerBody;
  String get continueOffline;
  String get privacyTitle;
  String get privacyLocalFirst;
  String get privacyLocalFirstBody;
  String get privacyNoAccount;
  String get privacyNoAccountBody;
  String get privacyDeleteAllTitle;
  String get privacyDeleteAllBody;
  String get privacyDeleteAllConfirm;
  String get privacyExportData;
  String get privacyExportDataBody;
  String get privacyExportSaved;
  String get privacyRestoreData;
  String get privacyRestoreDataBody;
  String get privacyRestoreConfirm;
  String get privacyRestoreDone;
  String get privacyRestoreInvalid;
  String get privacyDataDeleted;
  String get archiveConfirmTitle;
  String get archiveConfirmBody;
  String get archive;

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settingsTitle;
  String get settingsAppearance;
  String get settingsTheme;
  String get settingsThemeSystem;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsLanguage;
  String get settingsDefaultRegion;
  String get settingsDefaultPaperSize;
  String get settingsDateSystem;
  String get dateSystemGregorian;
  String get dateSystemJalali;
  String get settingsDocumentFont;
  String get settingsAbout;
  String get settingsVersion;
  String get settingsLicences;
  String get settingsLicencesBody;
  String get settingsResetOnboarding;

  // ── Templates ────────────────────────────────────────────────────────────
  String get templatesTitle;
  String get templatesSearch;
  String get templatesAllCategories;
  String get templatesCategoryProfessional;
  String get templatesCategoryModern;
  String get templatesCategoryAcademic;
  String get templatesCategoryRegional;
  String get templatesCategoryCreative;
  String get templatesAtsSafe;
  String get templatesAtsSafeBody;
  String get templatesApply;
  String get templatesApplied;
  String get templatesPreviewHint;
  String get templatesPremium;
  String get templatesFree;
  String get templatesSingleColumn;
  String get templatesTwoColumn;
  String get templatesPageRecommendation;

  // ── Errors ───────────────────────────────────────────────────────────────
  String get errorCvNotFound;
  String get errorStorageFailure;
  String get errorExportFailure;
  String get errorFileTooLarge;
  String get errorUnsupportedFormat;
  String get errorInvalidJsonBackup;
  String get errorNoPdfApp;

  // ── Units ────────────────────────────────────────────────────────────────
  String get unitPage;
  String get unitPages;
  String get unitWords;
  String get unitCharacters;
  String get unitBullets;
  String get statsQuantified;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((Locale l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations.ofCode(locale.languageCode));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
