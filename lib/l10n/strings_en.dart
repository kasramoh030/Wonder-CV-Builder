import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// English (source) strings.
class StringsEn extends AppLocalizations {
  const StringsEn();

  @override
  Locale get locale => const Locale('en');

  @override
  String get languageName => 'English';

  @override
  String get languageCodeShort => 'EN';

  // ── App-wide ─────────────────────────────────────────────────────────────
  @override
  String get appName => 'CV Pro';
  @override
  String get appTagline => 'International CV & Resume Builder';
  @override
  String get continueLabel => 'Continue';
  @override
  String get back => 'Back';
  @override
  String get next => 'Next';
  @override
  String get skip => 'Skip';
  @override
  String get done => 'Done';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get saveAndClose => 'Save & close';
  @override
  String get delete => 'Delete';
  @override
  String get duplicate => 'Duplicate';
  @override
  String get rename => 'Rename';
  @override
  String get edit => 'Edit';
  @override
  String get close => 'Close';
  @override
  String get retry => 'Retry';
  @override
  String get search => 'Search';
  @override
  String get clear => 'Clear';
  @override
  String get confirm => 'Confirm';
  @override
  String get optional => 'Optional';
  @override
  String get required => 'Required';
  @override
  String get none => 'None';
  @override
  String get all => 'All';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get loading => 'Loading…';
  @override
  String get somethingWentWrong => 'Something went wrong';
  @override
  String get tryAgain => 'Try again';

  // ── Onboarding ───────────────────────────────────────────────────────────
  @override
  String get onboardingWelcomeTitle => 'Build a CV that travels';
  @override
  String get onboardingWelcomeBody =>
      'Create professional CVs and resumes for Iran, Europe, Germany, the UK, the US and international employers — ATS-ready and beautifully typeset.';
  @override
  String get onboardingPrivateTitle => 'Private by design';
  @override
  String get onboardingPrivateBody =>
      'Your CV never leaves your device unless you choose to share it. No account, no sign-up, no tracking.';
  @override
  String get onboardingOfflineTitle => 'Works without internet';
  @override
  String get onboardingOfflineBody =>
      'Write, analyse and export a high-quality PDF entirely offline. The internet is only used for the optional AI assistant.';
  @override
  String get onboardingGetStarted => 'Get started';
  @override
  String get onboardingChooseLanguage => 'Choose your language';
  @override
  String get onboardingWhatCreating => 'What are you creating?';
  @override
  String get onboardingWhatCreatingHint =>
      'This shapes the sections we suggest and how your CV is structured.';
  @override
  String get onboardingWhereApplying => 'Where are you applying?';
  @override
  String get industryLabel => 'Industry';
  @override
  String get onboardingWhereApplyingHint =>
      'Each market has its own conventions for photos, personal details, length and paper size. You can change this later.';
  @override
  String get onboardingAllSetTitle => 'You are all set';
  @override
  String get onboardingAllSetBody =>
      'Create your first CV now, or start with a reusable Master Profile that every CV can draw from.';
  @override
  String get onboardingCreateFirstCv => 'Create my first CV';

  // ── Dashboard ────────────────────────────────────────────────────────────
  @override
  String get dashboardTitle => 'Dashboard';
  @override
  String get myCvs => 'My CVs';
  @override
  String get masterProfile => 'Master Profile';
  @override
  String get masterProfileSubtitle =>
      'Store your details once and reuse them in every CV';
  @override
  String get cvAnalyzer => 'CV Analyzer';
  @override
  String get cvAnalyzerSubtitle => 'Structure, ATS and language scoring';
  @override
  String get jobAnalyzer => 'Job Match';
  @override
  String get jobAnalyzerSubtitle => 'Compare your CV against a job advert';
  @override
  String get templates => 'Templates';
  @override
  String get templatesSubtitle => 'Twelve layouts for every market';
  @override
  String get recentDocuments => 'Recent documents';
  @override
  String get createNewCv => 'Create new CV';
  @override
  String get noCvsTitle => 'No CVs yet';
  @override
  String get noCvsBody =>
      'Create your first CV — it takes about five minutes and works completely offline.';
  @override
  String get noRecentDocuments => 'Exported PDFs will show up here';
  @override
  String get updatedOn => 'Updated';
  @override
  String get createdOn => 'Created';
  @override
  String get documentsCount => 'Documents';
  @override
  String get cvsCount => 'CVs';

  // ── CV types ─────────────────────────────────────────────────────────────
  @override
  String get cvTypeJobResume => 'Job Resume';
  @override
  String get cvTypeProfessionalCv => 'Professional CV';
  @override
  String get cvTypeAcademicCv => 'Academic CV';
  @override
  String get cvTypeStudentResume => 'Student Resume';
  @override
  String get cvTypeInternshipResume => 'Internship Resume';
  @override
  String get cvTypeGraduateResume => 'Graduate Resume';
  @override
  String get cvTypeScholarshipCv => 'Scholarship CV';
  @override
  String get cvTypeResearchCv => 'Research CV';
  @override
  String get cvTypePhdCv => 'PhD CV';
  @override
  String get cvTypeEuropass => 'Europass-style CV';
  @override
  String get cvTypeAts => 'ATS Resume';

  // ── Regions ──────────────────────────────────────────────────────────────
  @override
  String get regionIran => 'Iran';
  @override
  String get regionEurope => 'Europe';
  @override
  String get regionGermany => 'Germany';
  @override
  String get regionUnitedKingdom => 'United Kingdom';
  @override
  String get regionUnitedStates => 'United States';
  @override
  String get regionInternational => 'International';

  // ── Sections ─────────────────────────────────────────────────────────────
  @override
  String get sectionPersonal => 'Personal information';
  @override
  String get sectionSummary => 'Professional summary';
  @override
  String get sectionExperience => 'Work experience';
  @override
  String get sectionEducation => 'Education';
  @override
  String get sectionSkills => 'Skills';
  @override
  String get sectionLanguages => 'Languages';
  @override
  String get sectionProjects => 'Projects';
  @override
  String get sectionCertifications => 'Certifications';
  @override
  String get sectionAwards => 'Awards & honours';
  @override
  String get sectionPublications => 'Publications';
  @override
  String get sectionVolunteering => 'Volunteering';
  @override
  String get sectionReferences => 'References';
  @override
  String get sectionCustom => 'Custom section';
  @override
  String get sectionCourses => 'Courses & training';
  @override
  String get sectionInterests => 'Interests';
  @override
  String get sectionMilitaryService => 'Military service';
  @override
  String get sectionDrivingLicence => 'Driving licence';
  @override
  String get sectionResearchInterests => 'Research interests';
  @override
  String get sectionResearchExperience => 'Research experience';
  @override
  String get sectionTeachingExperience => 'Teaching experience';
  @override
  String get sectionConferences => 'Conferences';
  @override
  String get sectionGrants => 'Grants & funding';
  @override
  String get sectionAcademicService => 'Academic service';
  @override
  String get sectionMemberships => 'Professional memberships';
  @override
  String get sectionAcademicAppointments => 'Academic appointments';
  @override
  String get sectionPresentations => 'Presentations';
  @override
  String get sectionAdditionalInfo => 'Additional information';
  @override
  String get sectionDigitalSkills => 'Digital skills';
  @override
  String get sectionAchievements => 'Achievements';
  @override
  String get sectionKeySkills => 'Key skills';

  // ── Builder ──────────────────────────────────────────────────────────────
  @override
  String get builderTitle => 'CV builder';
  @override
  String get builderSectionOrder => 'Section order';
  @override
  String get builderSectionOrderHint =>
      'Drag to reorder. The order affects both the preview and the PDF.';
  @override
  String get builderAddSection => 'Add section';
  @override
  String get builderRemoveSection => 'Remove section';
  @override
  String get builderDragToReorder => 'Drag to reorder';
  @override
  String get builderUnsavedChanges => 'Unsaved changes';
  @override
  String get builderSaved => 'Saved';
  @override
  String get builderAutosaved => 'Autosaved';
  @override
  String get builderEmptySectionHint => 'Nothing here yet — add your first entry.';
  @override
  String get builderAddItem => 'Add entry';
  @override
  String get builderPreview => 'Preview';
  @override
  String get builderPreviewHint => 'Live preview updates as you type';
  @override
  String get builderProgress => 'Progress';
  @override
  String get builderCompleteness => 'Completeness';

  // ── Fields ───────────────────────────────────────────────────────────────
  @override
  String get fieldFirstName => 'First name';
  @override
  String get fieldLastName => 'Last name';
  @override
  String get fieldFullName => 'Full name';
  @override
  String get fieldJobTitle => 'Job title';
  @override
  String get fieldEmail => 'Email';
  @override
  String get fieldPhone => 'Phone';
  @override
  String get fieldCity => 'City';
  @override
  String get fieldProvince => 'Province';
  @override
  String get fieldCountry => 'Country';
  @override
  String get fieldLinkedIn => 'LinkedIn';
  @override
  String get fieldGitHub => 'GitHub';
  @override
  String get fieldWebsite => 'Website';
  @override
  String get fieldPhoto => 'Photo';
  @override
  String get fieldSummary => 'Summary';
  @override
  String get fieldCompany => 'Company';
  @override
  String get fieldLocation => 'Location';
  @override
  String get fieldStartDate => 'Start date';
  @override
  String get fieldEndDate => 'End date';
  @override
  String get fieldCurrentlyWorkHere => 'I currently work here';
  @override
  String get fieldResponsibilities => 'Responsibilities';
  @override
  String get fieldAchievements => 'Achievements';
  @override
  String get fieldTechnologies => 'Technologies';
  @override
  String get fieldUniversity => 'Institution';
  @override
  String get fieldDegree => 'Degree';
  @override
  String get fieldFieldOfStudy => 'Field of study';
  @override
  String get fieldGpa => 'GPA / grade';
  @override
  String get fieldDescription => 'Description';
  @override
  String get fieldSkillName => 'Skill';
  @override
  String get fieldSkillLevel => 'Level';
  @override
  String get fieldLanguage => 'Language';
  @override
  String get fieldLanguageLevel => 'Proficiency';
  @override
  String get fieldProjectName => 'Project name';
  @override
  String get fieldProjectUrl => 'Project URL';
  @override
  String get fieldProjectRepo => 'Repository';
  @override
  String get fieldCertificateName => 'Certificate';
  @override
  String get fieldOrganization => 'Issuing organisation';
  @override
  String get fieldDate => 'Date';
  @override
  String get fieldCredentialId => 'Credential ID';
  @override
  String get fieldVerificationUrl => 'Verification URL';
  @override
  String get fieldTitle => 'Title';
  @override
  String get fieldSubtitle => 'Subtitle';
  @override
  String get fieldPublisher => 'Journal / publisher';
  @override
  String get fieldDoi => 'DOI';
  @override
  String get fieldReferenceName => 'Name';
  @override
  String get fieldReferenceTitle => 'Position';
  @override
  String get fieldReferenceEmail => 'Email';
  @override
  String get fieldReferencePhone => 'Phone';
  @override
  String get fieldCustomSectionTitle => 'Section title';
  @override
  String get fieldNationalId => 'National ID';
  @override
  String get fieldBirthDate => 'Date of birth';
  @override
  String get fieldGender => 'Gender';
  @override
  String get fieldNationality => 'Nationality';
  @override
  String get fieldMaritalStatus => 'Marital status';
  @override
  String get sensitiveFieldNotice =>
      'Hidden by default. Only enable this if the target market expects it.';

  // ── Skills & levels ──────────────────────────────────────────────────────
  @override
  String get skillLevelBeginner => 'Beginner';
  @override
  String get skillLevelIntermediate => 'Intermediate';
  @override
  String get skillLevelAdvanced => 'Advanced';
  @override
  String get skillLevelExpert => 'Expert';
  @override
  String get languageLevelBeginner => 'Beginner';
  @override
  String get languageLevelIntermediate => 'Intermediate';
  @override
  String get languageLevelAdvanced => 'Advanced';
  @override
  String get languageLevelFluent => 'Fluent';
  @override
  String get languageLevelNative => 'Native';

  // ── Preview & export ─────────────────────────────────────────────────────
  @override
  String get previewTitle => 'Preview';
  @override
  String get previewZoomIn => 'Zoom in';
  @override
  String get previewZoomOut => 'Zoom out';
  @override
  String get previewFitToScreen => 'Fit to screen';
  @override
  String get previewPageOf => 'Page';
  @override
  String get exportTitle => 'Export';
  @override
  String get exportSavePdf => 'Save PDF';
  @override
  String get exportOpenPdf => 'Open PDF';
  @override
  String get exportSharePdf => 'Share PDF';
  @override
  String get exportPrint => 'Print';
  @override
  String get exportJson => 'Export as JSON';
  @override
  String get exportJsonHint =>
      'A portable backup you can import on another device. Nothing is uploaded.';
  @override
  String get exportGenerating => 'Generating PDF…';
  @override
  String get exportSuccess => 'PDF saved';
  @override
  String get exportFailed => 'Could not create the PDF';
  @override
  String get exportPaperSize => 'Paper size';
  @override
  String get paperA4 => 'A4 (210 × 297 mm)';
  @override
  String get paperLetter => 'US Letter (8.5 × 11 in)';
  @override
  String get exportFileName => 'File name';
  @override
  String get exportIncludeLinks => 'Include clickable links';

  // ── Analyzer ─────────────────────────────────────────────────────────────
  @override
  String get analyzerTitle => 'CV analysis';
  @override
  String get analyzerRunAnalysis => 'Run analysis';
  @override
  String get analyzerRerun => 'Run again';
  @override
  String get analyzerScoreTitle => 'CV quality';
  @override
  String get analyzerScoreStructure => 'Structure';
  @override
  String get analyzerScoreContent => 'Content';
  @override
  String get analyzerScoreAts => 'ATS compatibility';
  @override
  String get analyzerScoreLanguage => 'Language';
  @override
  String get analyzerScoreJobMatch => 'Job match';
  @override
  String get analyzerRecommendations => 'Recommendations';
  @override
  String get analyzerNoIssuesTitle => 'No blocking issues found';
  @override
  String get analyzerNoIssuesBody =>
      'Your CV passes the checks we can run automatically. A human review is still worth it.';
  @override
  String get analyzerRunFirstTitle => 'No analysis yet';
  @override
  String get analyzerRunFirstBody =>
      'Run the offline analysis to score structure, content, ATS compatibility and language.';
  @override
  String get analyzerOfflineBadge => 'Offline analysis';
  @override
  String get analyzerOnlineBadge => 'AI-enhanced analysis';
  @override
  String get analyzerDisclaimer =>
      'This analysis is based on common resume conventions, ATS practices, the selected target market, and the information provided by the user. It does not guarantee employment, university admission, or ATS acceptance.';
  @override
  String get analyzerKeywordsFound => 'Found keywords';
  @override
  String get analyzerKeywordsMissing => 'Missing keywords';
  @override
  String get analyzerKeywordHonestyNote =>
      'Only add a keyword if you genuinely have that experience.';
  @override
  String get analyzerStrengths => 'Strengths';
  @override
  String get analyzerImprovements => 'Improvements';
  @override
  String get priorityCritical => 'Critical';
  @override
  String get priorityHigh => 'High';
  @override
  String get priorityMedium => 'Medium';
  @override
  String get priorityLow => 'Low';

  // ── Job description ──────────────────────────────────────────────────────
  @override
  String get jobDescriptionTitle => 'Job description';
  @override
  String get jobDescriptionHint => 'Paste the full advert here';
  @override
  String get jobAnalyze => 'Analyse';
  @override
  String get jobPasteDescription => 'Paste a job advert to compare against';
  @override
  String get jobRequiredSkills => 'Required skills';
  @override
  String get jobPreferredSkills => 'Preferred skills';
  @override
  String get jobResponsibilities => 'Responsibilities';
  @override
  String get jobQualifications => 'Qualifications';
  @override
  String get jobSoftSkills => 'Soft skills';
  @override
  String get jobSeniority => 'Seniority';
  @override
  String get jobNoDescriptionTitle => 'No job advert yet';
  @override
  String get jobNoDescriptionBody =>
      'Paste a job advert and we will extract the keywords, then show what is missing from your CV.';
  @override
  String get jobMatchTitle => 'Match with this role';
  @override
  String get jobMatchSkills => 'Skills match';
  @override
  String get jobMatchExperience => 'Experience match';
  @override
  String get jobMatchEducation => 'Education match';
  @override
  String get jobMatchKeywords => 'Keyword match';
  @override
  String get jobMatchSeniority => 'Seniority match';
  @override
  String get jobMatchDomain => 'Domain match';

  // ── AI ───────────────────────────────────────────────────────────────────
  @override
  String get aiTitle => 'AI assistant';
  @override
  String get aiAssistant => 'Assistant';
  @override
  String get aiImproveSection => 'Improve this section';
  @override
  String get aiRewrite => 'Rewrite';
  @override
  String get aiImproveSummary => 'Improve summary';
  @override
  String get aiImproveExperience => 'Improve experience';
  @override
  String get aiWriteAchievement => 'Write an achievement';
  @override
  String get aiFixGrammar => 'Fix grammar';
  @override
  String get aiSuggest => 'Suggest';
  @override
  String get aiSuggestion => 'Suggestion';
  @override
  String get aiAccept => 'Accept';
  @override
  String get aiEdit => 'Edit';
  @override
  String get aiReject => 'Reject';
  @override
  String get aiRegenerate => 'Regenerate';
  @override
  String get aiOriginal => 'Your text';
  @override
  String get aiProposed => 'Proposed';
  @override
  String get aiNoFabricationNotice =>
      'The assistant may only restructure and rephrase what you wrote. It will never invent employers, dates, qualifications or numbers.';
  @override
  String get aiNeedsInfoTitle => 'More detail needed';
  @override
  String get aiQuestionImproveRevenue =>
      'Did this improve revenue, performance, efficiency, engagement or another measurable outcome? If you know the number, add it — otherwise we will leave it out.';
  @override
  String get aiConsentTitle => 'Send this text to the AI provider?';
  @override
  String get aiConsentBody =>
      'This is an online feature. The selected text will be sent to the provider you configured. Only the text shown below is sent — never your whole CV, your files, or your identity.';
  @override
  String get aiConsentAccept => 'Send and improve';
  @override
  String get aiConsentDecline => 'Not now';
  @override
  String get aiOfflineNotice => 'You are offline. AI features need a connection.';
  @override
  String get aiNoKeyTitle => 'No AI provider configured';
  @override
  String get aiNoKeyBody =>
      'Add your own API key in Settings to enable rewriting and advanced analysis. Everything else in the app keeps working without it.';
  @override
  String get aiOpenSettings => 'Open settings';
  @override
  String get aiProvider => 'Provider';
  @override
  String get aiApiKey => 'API key';
  @override
  String get aiApiKeyHint => 'Stored in the device keystore';
  @override
  String get aiApiKeyStoredSecurely =>
      'Your key is kept in the Android keystore. It is never bundled in the app and never sent anywhere except the provider you choose.';
  @override
  String get aiModel => 'Model';
  @override
  String get aiTestConnection => 'Test connection';
  @override
  String get aiConnectionOk => 'Connection successful';
  @override
  String get aiConnectionFailed => 'Connection failed';

  // ── Import ───────────────────────────────────────────────────────────────
  @override
  String get importTitle => 'Import an existing CV';
  @override
  String get importFromPdf => 'PDF document';
  @override
  String get importFromDocx => 'Word document (.docx)';
  @override
  String get importFromTxt => 'Plain text (.txt)';
  @override
  String get importFromImage => 'Photo or scan';
  @override
  String get importReviewTitle => 'Review imported data';
  @override
  String get importReviewBody =>
      'Check what we found before saving. Nothing is written to your CV until you confirm.';
  @override
  String get importConfirmImport => 'Import these details';
  @override
  String get importNothingFound => 'We could not find structured details in this file.';
  @override
  String get importOcrUnavailableTitle => 'Text recognition is not available';
  @override
  String get importOcrUnavailableBody =>
      'This build does not include an on-device OCR engine configured. You can still import PDF, DOCX and TXT files, or type the details in manually.';
  @override
  String get importParsingTitle => 'Reading your document…';
  @override
  String get importParsingBody => 'This happens entirely on your device.';

  // ── Network & privacy ────────────────────────────────────────────────────
  @override
  String get statusOffline => 'Offline';
  @override
  String get statusOnline => 'Online';
  @override
  String get statusLocal => 'On this device';
  @override
  String get offlineBannerTitle => 'You are offline';
  @override
  String get offlineBannerBody => 'Your CV is safely saved on your device.';
  @override
  String get continueOffline => 'Continue offline';
  @override
  String get privacyTitle => 'Privacy & data';
  @override
  String get privacyLocalFirst => 'Local-first';
  @override
  String get privacyLocalFirstBody =>
      'Every CV, template choice and analysis lives in an encrypted-at-rest database on this device.';
  @override
  String get privacyNoAccount => 'No account required';
  @override
  String get privacyNoAccountBody =>
      'You never need to sign up, sign in, or connect a cloud service to build a CV.';
  @override
  String get privacyDeleteAllTitle => 'Delete all data';
  @override
  String get privacyDeleteAllBody =>
      'Removes every CV, the master profile, exports and settings from this device. This cannot be undone.';
  @override
  String get privacyDeleteAllConfirm => 'Delete everything';
  @override
  String get privacyExportData => 'Export all data';
  @override
  String get privacyExportDataBody =>
      'Creates a single JSON file containing everything stored on this device.';
  @override
  String get privacyDataDeleted => 'All data deleted';

  // ── Settings ─────────────────────────────────────────────────────────────
  @override
  String get settingsTitle => 'Settings';
  @override
  String get settingsAppearance => 'Appearance';
  @override
  String get settingsTheme => 'Theme';
  @override
  String get settingsThemeSystem => 'System';
  @override
  String get settingsThemeLight => 'Light';
  @override
  String get settingsThemeDark => 'Dark';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsDefaultRegion => 'Default target market';
  @override
  String get settingsDefaultPaperSize => 'Default paper size';
  @override
  String get settingsDateSystem => 'Date system';
  @override
  String get dateSystemGregorian => 'Gregorian';
  @override
  String get dateSystemJalali => 'Persian (Jalali)';
  @override
  String get settingsDocumentFont => 'Document font';
  @override
  String get settingsAbout => 'About';
  @override
  String get settingsVersion => 'Version';
  @override
  String get settingsLicences => 'Open-source licences';
  @override
  String get settingsLicencesBody =>
      'Bundled fonts are licensed under the SIL Open Font License 1.1.';
  @override
  String get settingsResetOnboarding => 'Show onboarding again';

  // ── Templates ────────────────────────────────────────────────────────────
  @override
  String get templatesTitle => 'Templates';
  @override
  String get templatesSearch => 'Search templates';
  @override
  String get templatesAllCategories => 'All';
  @override
  String get templatesCategoryProfessional => 'Professional';
  @override
  String get templatesCategoryModern => 'Modern';
  @override
  String get templatesCategoryAcademic => 'Academic';
  @override
  String get templatesCategoryRegional => 'Regional';
  @override
  String get templatesCategoryCreative => 'Creative';
  @override
  String get templatesAtsSafe => 'ATS-safe';
  @override
  String get templatesAtsSafeBody =>
      'Single column, standard headings, no tables, no graphics and fully extractable text.';
  @override
  String get templatesApply => 'Use this template';
  @override
  String get templatesApplied => 'Template applied';
  @override
  String get templatesPreviewHint => 'Tap to preview with your own content';
  @override
  String get templatesPremium => 'Premium';
  @override
  String get templatesFree => 'Free';
  @override
  String get templatesSingleColumn => 'Single column';
  @override
  String get templatesTwoColumn => 'Two column';
  @override
  String get templatesPageRecommendation => 'Recommended length';

  // ── Errors ───────────────────────────────────────────────────────────────
  @override
  String get errorCvNotFound => 'That CV no longer exists.';
  @override
  String get errorStorageFailure => 'Could not save to the local database.';
  @override
  String get errorExportFailure => 'Export failed. Check free space and try again.';
  @override
  String get errorFileTooLarge => 'That file is too large to import.';
  @override
  String get errorUnsupportedFormat => 'Unsupported file format.';
  @override
  String get errorInvalidJsonBackup => 'That backup file is not valid.';
  @override
  String get errorNoPdfApp => 'No PDF viewer is installed on this device.';

  // ── Units ────────────────────────────────────────────────────────────────
  @override
  String get unitPage => 'page';
  @override
  String get unitPages => 'pages';
  @override
  String get unitWords => 'words';
  @override
  String get unitCharacters => 'characters';
}
