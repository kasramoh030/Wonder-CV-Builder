import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Persian (Farsi) strings — right-to-left.
///
/// Terminology follows what Iranian recruiters and HR portals actually use
/// (رزومه، سوابق کاری، تحصیلات) rather than literal translations of the
/// English source strings.
class StringsFa extends AppLocalizations {
  const StringsFa();

  @override
  Locale get locale => const Locale('fa');

  @override
  String get languageName => 'فارسی';

  @override
  String get languageCodeShort => 'فا';

  // ── App-wide ─────────────────────────────────────────────────────────────
  @override
  String get appName => 'سی‌وی پرو';
  @override
  String get appTagline => 'سازنده رزومه و سی‌وی بین‌المللی';
  @override
  String get continueLabel => 'ادامه';
  @override
  String get back => 'بازگشت';
  @override
  String get next => 'بعدی';
  @override
  String get skip => 'رد کردن';
  @override
  String get done => 'تمام';
  @override
  String get cancel => 'انصراف';
  @override
  String get save => 'ذخیره';
  @override
  String get saveAndClose => 'ذخیره و بستن';
  @override
  String get delete => 'حذف';
  @override
  String get duplicate => 'کپی';
  @override
  String get rename => 'تغییر نام';
  @override
  String get edit => 'ویرایش';
  @override
  String get close => 'بستن';
  @override
  String get retry => 'تلاش دوباره';
  @override
  String get search => 'جست‌وجو';
  @override
  String get clear => 'پاک کردن';
  @override
  String get confirm => 'تأیید';
  @override
  String get optional => 'اختیاری';
  @override
  String get required => 'الزامی';
  @override
  String get none => 'هیچ‌کدام';
  @override
  String get all => 'همه';
  @override
  String get yes => 'بله';
  @override
  String get no => 'خیر';
  @override
  String get loading => 'در حال بارگذاری…';
  @override
  String get somethingWentWrong => 'خطایی رخ داد';
  @override
  String get tryAgain => 'تلاش دوباره';

  // ── Onboarding ───────────────────────────────────────────────────────────
  @override
  String get onboardingWelcomeTitle => 'رزومه‌ای بساز که همه‌جا کار کند';
  @override
  String get onboardingWelcomeBody =>
      'برای ایران، اروپا، آلمان، بریتانیا، آمریکا و کارفرمایان بین‌المللی رزومه و سی‌وی حرفه‌ای بساز — سازگار با سیستم‌های ATS و با صفحه‌آرایی تمیز.';
  @override
  String get onboardingPrivateTitle => 'حریم خصوصی، از پایه';
  @override
  String get onboardingPrivateBody =>
      'رزومه‌ات تا وقتی خودت نخواهی از دستگاهت خارج نمی‌شود. بدون حساب کاربری، بدون ثبت‌نام، بدون ردیابی.';
  @override
  String get onboardingOfflineTitle => 'بدون اینترنت هم کار می‌کند';
  @override
  String get onboardingOfflineBody =>
      'نوشتن، تحلیل و خروجی PDF با کیفیت چاپ، کاملاً آفلاین. اینترنت فقط برای دستیار هوش مصنوعی اختیاری استفاده می‌شود.';
  @override
  String get onboardingGetStarted => 'شروع کنیم';
  @override
  String get onboardingChooseLanguage => 'زبان را انتخاب کنید';
  @override
  String get onboardingWhatCreating => 'چه چیزی می‌سازید؟';
  @override
  String get onboardingWhatCreatingHint =>
      'این انتخاب تعیین می‌کند چه بخش‌هایی پیشنهاد شود و ساختار سی‌وی چگونه باشد.';
  @override
  String get onboardingWhereApplying => 'برای کجا اقدام می‌کنید؟';
  @override
  String get industryLabel => 'حوزه فعالیت';
  @override
  String get onboardingWhereApplyingHint =>
      'هر بازار قواعد خودش را دارد: عکس، اطلاعات شخصی، طول رزومه و اندازه کاغذ. بعداً هم می‌توانید تغییر دهید.';
  @override
  String get onboardingAllSetTitle => 'همه چیز آماده است';
  @override
  String get onboardingAllSetBody =>
      'همین حالا اولین سی‌وی را بسازید، یا با یک «پروفایل مادر» شروع کنید که همه سی‌وی‌ها از آن تغذیه می‌شوند.';
  @override
  String get onboardingCreateFirstCv => 'ساخت اولین سی‌وی';

  // ── Dashboard ────────────────────────────────────────────────────────────
  @override
  String get dashboardTitle => 'میزکار';
  @override
  String get myCvs => 'سی‌وی‌های من';
  @override
  String get masterProfile => 'پروفایل مادر';
  @override
  String get masterProfileSubtitle =>
      'اطلاعاتت را یک‌بار وارد کن و در همه سی‌وی‌ها استفاده کن';
  @override
  String get cvAnalyzer => 'تحلیل سی‌وی';
  @override
  String get cvAnalyzerSubtitle => 'امتیاز ساختار، ATS و زبان';
  @override
  String get jobAnalyzer => 'تطبیق با آگهی شغل';
  @override
  String get jobAnalyzerSubtitle => 'رزومه‌ات را با متن آگهی مقایسه کن';
  @override
  String get templates => 'قالب‌ها';
  @override
  String get templatesSubtitle => 'دوازده چیدمان برای هر بازار';
  @override
  String get recentDocuments => 'اسناد اخیر';
  @override
  String get createNewCv => 'ساخت سی‌وی جدید';
  @override
  String get noCvsTitle => 'هنوز سی‌وی‌ای نساخته‌اید';
  @override
  String get noCvsBody =>
      'اولین سی‌وی‌تان را بسازید — حدود پنج دقیقه وقت می‌برد و کامل آفلاین کار می‌کند.';
  @override
  String get noRecentDocuments => 'فایل‌های PDF خروجی اینجا نمایش داده می‌شوند';
  @override
  String get updatedOn => 'آخرین ویرایش';
  @override
  String get createdOn => 'تاریخ ایجاد';
  @override
  String get documentsCount => 'اسناد';
  @override
  String get cvsCount => 'سی‌وی';

  // ── CV types ─────────────────────────────────────────────────────────────
  @override
  String get cvTypeJobResume => 'رزومه شغلی';
  @override
  String get cvTypeProfessionalCv => 'سی‌وی حرفه‌ای';
  @override
  String get cvTypeAcademicCv => 'سی‌وی دانشگاهی';
  @override
  String get cvTypeStudentResume => 'رزومه دانشجویی';
  @override
  String get cvTypeInternshipResume => 'رزومه کارآموزی';
  @override
  String get cvTypeGraduateResume => 'رزومه فارغ‌التحصیلی';
  @override
  String get cvTypeScholarshipCv => 'سی‌وی بورسیه';
  @override
  String get cvTypeResearchCv => 'سی‌وی پژوهشی';
  @override
  String get cvTypePhdCv => 'سی‌وی دکتری';
  @override
  String get cvTypeEuropass => 'سی‌وی به سبک یوروپس';
  @override
  String get cvTypeAts => 'رزومه ATS';

  // ── Regions ──────────────────────────────────────────────────────────────
  @override
  String get regionIran => 'ایران';
  @override
  String get regionEurope => 'اروپا';
  @override
  String get regionGermany => 'آلمان';
  @override
  String get regionUnitedKingdom => 'بریتانیا';
  @override
  String get regionUnitedStates => 'آمریکا';
  @override
  String get regionInternational => 'بین‌المللی';

  // ── Sections ─────────────────────────────────────────────────────────────
  @override
  String get presentLabel => 'تاکنون';

  @override
  String get sectionPersonal => 'اطلاعات شخصی';
  @override
  String get sectionSummary => 'خلاصه حرفه‌ای';
  @override
  String get sectionExperience => 'سوابق کاری';
  @override
  String get sectionEducation => 'تحصیلات';
  @override
  String get sectionSkills => 'مهارت‌ها';
  @override
  String get sectionLanguages => 'زبان‌ها';
  @override
  String get sectionProjects => 'پروژه‌ها';
  @override
  String get sectionCertifications => 'گواهی‌نامه‌ها';
  @override
  String get sectionAwards => 'افتخارات و جوایز';
  @override
  String get sectionPublications => 'مقالات و انتشارات';
  @override
  String get sectionVolunteering => 'فعالیت‌های داوطلبانه';
  @override
  String get sectionReferences => 'معرف‌ها';
  @override
  String get sectionCustom => 'بخش دلخواه';
  @override
  String get sectionCourses => 'دوره‌ها و آموزش‌ها';
  @override
  String get sectionInterests => 'علاقه‌مندی‌ها';
  @override
  String get sectionMilitaryService => 'وضعیت نظام وظیفه';
  @override
  String get sectionDrivingLicence => 'گواهینامه رانندگی';
  @override
  String get sectionResearchInterests => 'حوزه‌های پژوهشی';
  @override
  String get sectionResearchExperience => 'سوابق پژوهشی';
  @override
  String get sectionTeachingExperience => 'سوابق تدریس';
  @override
  String get sectionConferences => 'کنفرانس‌ها';
  @override
  String get sectionGrants => 'گرنت و حمایت مالی';
  @override
  String get sectionAcademicService => 'خدمات دانشگاهی';
  @override
  String get sectionMemberships => 'عضویت‌های حرفه‌ای';
  @override
  String get sectionAcademicAppointments => 'سمت‌های دانشگاهی';
  @override
  String get sectionPresentations => 'ارائه‌ها';
  @override
  String get sectionAdditionalInfo => 'اطلاعات تکمیلی';
  @override
  String get sectionDigitalSkills => 'مهارت‌های دیجیتال';
  @override
  String get sectionAchievements => 'دستاوردها';
  @override
  String get sectionKeySkills => 'مهارت‌های کلیدی';

  // ── Builder ──────────────────────────────────────────────────────────────
  @override
  String get builderTitle => 'ویرایشگر سی‌وی';
  @override
  String get builderSectionOrder => 'ترتیب بخش‌ها';
  @override
  String get builderSectionOrderHint =>
      'برای جابه‌جایی بکشید. ترتیب روی پیش‌نمایش و PDF اثر می‌گذارد.';
  @override
  String get builderAddSection => 'افزودن بخش';
  @override
  String get builderRemoveSection => 'حذف بخش';
  @override
  String get builderDragToReorder => 'برای جابه‌جایی بکشید';
  @override
  String get builderUnsavedChanges => 'تغییرات ذخیره‌نشده';
  @override
  String get builderSaved => 'ذخیره شد';
  @override
  String get builderAutosaved => 'ذخیره خودکار شد';
  @override
  String get builderEmptySectionHint => 'هنوز چیزی اینجا نیست — اولین مورد را اضافه کنید.';
  @override
  String get builderAddItem => 'افزودن مورد';
  @override
  String get builderPreview => 'پیش‌نمایش';
  @override
  String get builderPreviewHint => 'پیش‌نمایش همزمان با تایپ به‌روز می‌شود';
  @override
  String get builderProgress => 'پیشرفت';
  @override
  String get builderCompleteness => 'کامل بودن';

  // ── Fields ───────────────────────────────────────────────────────────────
  @override
  String get fieldFirstName => 'نام';
  @override
  String get fieldLastName => 'نام خانوادگی';
  @override
  String get fieldFullName => 'نام و نام خانوادگی';
  @override
  String get fieldJobTitle => 'عنوان شغلی';
  @override
  String get fieldEmail => 'ایمیل';
  @override
  String get fieldPhone => 'شماره تماس';
  @override
  String get fieldCity => 'شهر';
  @override
  String get fieldProvince => 'استان';
  @override
  String get fieldCountry => 'کشور';
  @override
  String get fieldLinkedIn => 'لینکدین';
  @override
  String get fieldGitHub => 'گیت‌هاب';
  @override
  String get fieldWebsite => 'وب‌سایت';
  @override
  String get fieldPhoto => 'عکس';
  @override
  String get fieldSummary => 'خلاصه';
  @override
  String get fieldCompany => 'شرکت';
  @override
  String get fieldLocation => 'محل';
  @override
  String get fieldStartDate => 'تاریخ شروع';
  @override
  String get fieldEndDate => 'تاریخ پایان';
  @override
  String get fieldCurrentlyWorkHere => 'همین حالا اینجا مشغولم';
  @override
  String get fieldResponsibilities => 'شرح وظایف';
  @override
  String get fieldAchievements => 'دستاوردها';
  @override
  String get fieldTechnologies => 'فناوری‌ها';
  @override
  String get fieldUniversity => 'دانشگاه / مؤسسه';
  @override
  String get fieldDegree => 'مقطع';
  @override
  String get fieldFieldOfStudy => 'رشته تحصیلی';
  @override
  String get fieldGpa => 'معدل';
  @override
  String get fieldDescription => 'توضیحات';
  @override
  String get fieldSkillName => 'مهارت';
  @override
  String get fieldSkillLevel => 'سطح';
  @override
  String get fieldLanguage => 'زبان';
  @override
  String get fieldLanguageLevel => 'سطح تسلط';
  @override
  String get fieldProjectName => 'نام پروژه';
  @override
  String get fieldProjectUrl => 'نشانی پروژه';
  @override
  String get fieldProjectRepo => 'مخزن کد';
  @override
  String get fieldCertificateName => 'گواهی‌نامه';
  @override
  String get fieldOrganization => 'مرجع صدور';
  @override
  String get fieldDate => 'تاریخ';
  @override
  String get fieldCredentialId => 'شناسه گواهی';
  @override
  String get fieldVerificationUrl => 'نشانی راستی‌آزمایی';
  @override
  String get fieldTitle => 'عنوان';
  @override
  String get fieldSubtitle => 'زیرعنوان';
  @override
  String get fieldPublisher => 'نشریه / ناشر';
  @override
  String get fieldMonth => 'ماه';
  @override
  String get fieldYear => 'سال';
  @override
  String get fieldCategory => 'دسته‌بندی';
  @override
  String get fieldRelationship => 'نسبت';
  @override
  String get fieldAuthors => 'نویسندگان';
  @override
  String get fieldDoi => 'شناسه DOI';
  @override
  String get fieldReferenceName => 'نام';
  @override
  String get fieldReferenceTitle => 'سمت';
  @override
  String get fieldReferenceEmail => 'ایمیل';
  @override
  String get fieldReferencePhone => 'تلفن';
  @override
  String get fieldCustomSectionTitle => 'عنوان بخش';
  @override
  String get fieldNationalId => 'کد ملی';
  @override
  String get fieldBirthDate => 'تاریخ تولد';
  @override
  String get fieldGender => 'جنسیت';
  @override
  String get fieldNationality => 'تابعیت';
  @override
  String get fieldMaritalStatus => 'وضعیت تأهل';
  @override
  String get sensitiveFieldNotice =>
      'به‌صورت پیش‌فرض پنهان است. فقط اگر بازار هدف انتظار دارد آن را فعال کنید.';

  // ── Skills & levels ──────────────────────────────────────────────────────
  @override
  String get skillLevelBeginner => 'مبتدی';
  @override
  String get skillLevelIntermediate => 'متوسط';
  @override
  String get skillLevelAdvanced => 'پیشرفته';
  @override
  String get skillLevelExpert => 'حرفه‌ای';
  @override
  String get languageLevelBeginner => 'مبتدی';
  @override
  String get languageLevelIntermediate => 'متوسط';
  @override
  String get languageLevelAdvanced => 'پیشرفته';
  @override
  String get languageLevelFluent => 'روان';
  @override
  String get languageLevelNative => 'زبان مادری';

  // ── Preview & export ─────────────────────────────────────────────────────
  @override
  String get previewTitle => 'پیش‌نمایش';
  @override
  String get previewZoomIn => 'بزرگ‌نمایی';
  @override
  String get previewZoomOut => 'کوچک‌نمایی';
  @override
  String get previewFitToScreen => 'تناسب با صفحه';
  @override
  String get previewPageOf => 'صفحه';
  @override
  String get exportTitle => 'خروجی';
  @override
  String get exportSavePdf => 'ذخیره PDF';
  @override
  String get exportOpenPdf => 'باز کردن PDF';
  @override
  String get exportSharePdf => 'اشتراک‌گذاری PDF';
  @override
  String get exportPrint => 'چاپ';
  @override
  String get exportJson => 'خروجی JSON';
  @override
  String get exportJsonHint =>
      'یک نسخه پشتیبان قابل انتقال که در دستگاه دیگر وارد می‌کنید. هیچ چیزی آپلود نمی‌شود.';
  @override
  String get exportGenerating => 'در حال ساخت PDF…';
  @override
  String get exportSuccess => 'PDF ذخیره شد';
  @override
  String get exportFailed => 'ساخت PDF ممکن نشد';
  @override
  String get exportPaperSize => 'اندازه کاغذ';
  @override
  String get paperA4 => 'A4 (۲۱۰ × ۲۹۷ میلی‌متر)';
  @override
  String get paperLetter => 'US Letter (۸.۵ × ۱۱ اینچ)';
  @override
  String get pdfWarningPhotoMissing => 'عکس شما به این فایل پیوست نشده است.';
  @override
  String get pdfWarningPhotoWithAts => 'این بازار برای رزومهٔ خوانده‌شده با ATS عکس انتظار ندارد.';
  @override
  String get pdfWarningLongerThanConvention => 'بلندتر از طول معمول برای این بازار.';
  @override
  String get exportFileName => 'نام فایل';
  @override
  String get exportIncludeLinks => 'درج لینک‌های قابل کلیک';

  // ── Analyzer ─────────────────────────────────────────────────────────────
  @override
  String get analyzerTitle => 'تحلیل سی‌وی';
  @override
  String get analyzerRunAnalysis => 'اجرای تحلیل';
  @override
  String get analyzerRerun => 'تحلیل دوباره';
  @override
  String get analyzerScoreTitle => 'کیفیت سی‌وی';
  @override
  String get analyzerScoreStructure => 'ساختار';
  @override
  String get analyzerScoreContent => 'محتوا';
  @override
  String get analyzerScoreAts => 'سازگاری با ATS';
  @override
  String get analyzerScoreLanguage => 'زبان';
  @override
  String get analyzerScoreJobMatch => 'تطبیق با شغل';
  @override
  String get analyzerRecommendations => 'پیشنهادها';
  @override
  String get analyzerNoIssuesTitle => 'مشکل بازدارنده‌ای پیدا نشد';
  @override
  String get analyzerNoIssuesBody =>
      'سی‌وی شما از بررسی‌های خودکار ما عبور کرد. با این حال بازبینی انسانی هم ارزشمند است.';
  @override
  String get analyzerRunFirstTitle => 'هنوز تحلیلی انجام نشده';
  @override
  String get analyzerRunFirstBody =>
      'تحلیل آفلاین را اجرا کنید تا ساختار، محتوا، سازگاری با ATS و زبان ارزیابی شود.';
  @override
  String get analyzerOfflineBadge => 'تحلیل آفلاین';
  @override
  String get analyzerOnlineBadge => 'تحلیل تقویت‌شده با هوش مصنوعی';
  @override
  String get analyzerDisclaimer =>
      'این تحلیل بر پایه عرف‌های رایج رزومه‌نویسی، شیوه‌های سیستم‌های ATS، بازار هدف انتخاب‌شده و اطلاعاتی است که خود شما وارد کرده‌اید. این تحلیل تضمینی برای استخدام، پذیرش دانشگاهی یا عبور از ATS نیست.';
  @override
  String get analyzerKeywordsFound => 'کلیدواژه‌های موجود';
  @override
  String get analyzerKeywordsMissing => 'کلیدواژه‌های غایب';
  @override
  String get analyzerKeywordHonestyNote =>
      'فقط اگر واقعاً آن تجربه را دارید، کلیدواژه را اضافه کنید.';
  @override
  String get analyzerStrengths => 'نقاط قوت';
  @override
  String get analyzerImprovements => 'زمینه‌های بهبود';
  @override
  String get priorityCritical => 'بحرانی';
  @override
  String get priorityHigh => 'زیاد';
  @override
  String get priorityMedium => 'متوسط';
  @override
  String get priorityLow => 'کم';

  // ── Job description ──────────────────────────────────────────────────────
  @override
  String get jobDescriptionTitle => 'شرح شغل';
  @override
  String get jobDescriptionHint => 'متن کامل آگهی را اینجا بچسبانید';
  @override
  String get jobAnalyze => 'تحلیل کن';
  @override
  String get jobPasteDescription => 'برای مقایسه، متن آگهی استخدام را بچسبانید';
  @override
  String get jobRequiredSkills => 'مهارت‌های الزامی';
  @override
  String get jobPreferredSkills => 'مهارت‌های ترجیحی';
  @override
  String get jobResponsibilities => 'مسئولیت‌ها';
  @override
  String get jobQualifications => 'شرایط احراز';
  @override
  String get jobSoftSkills => 'مهارت‌های نرم';
  @override
  String get jobSeniority => 'سطح ارشدیت';
  @override
  String get jobNoDescriptionTitle => 'هنوز آگهی‌ای وارد نشده';
  @override
  String get jobNoDescriptionBody =>
      'متن آگهی را بچسبانید؛ کلیدواژه‌ها را استخراج می‌کنیم و نشان می‌دهیم چه چیزی در رزومه شما کم است.';
  @override
  String get jobMatchTitle => 'میزان تطبیق با این موقعیت';
  @override
  String get jobMatchSkills => 'تطبیق مهارت';
  @override
  String get jobMatchExperience => 'تطبیق تجربه';
  @override
  String get jobMatchEducation => 'تطبیق تحصیلات';
  @override
  String get jobMatchKeywords => 'تطبیق کلیدواژه';
  @override
  String get jobMatchSeniority => 'تطبیق سطح';
  @override
  String get jobMatchDomain => 'تطبیق حوزه';

  // ── AI ───────────────────────────────────────────────────────────────────
  @override
  String get aiTitle => 'دستیار هوش مصنوعی';
  @override
  String get aiAssistant => 'دستیار';
  @override
  String get aiImproveSection => 'بهبود این بخش';
  @override
  String get aiRewrite => 'بازنویسی';
  @override
  String get aiImproveSummary => 'بهبود خلاصه';
  @override
  String get aiImproveExperience => 'بهبود سوابق کاری';
  @override
  String get aiWriteAchievement => 'نوشتن دستاورد';
  @override
  String get aiFixGrammar => 'اصلاح دستور زبان';
  @override
  String get aiSuggest => 'پیشنهاد بده';
  @override
  String get aiSuggestion => 'پیشنهاد';
  @override
  String get aiAccept => 'بپذیر';
  @override
  String get aiEdit => 'ویرایش';
  @override
  String get aiReject => 'رد کن';
  @override
  String get aiRegenerate => 'تولید دوباره';
  @override
  String get aiOriginal => 'متن شما';
  @override
  String get aiProposed => 'متن پیشنهادی';
  @override
  String get aiNoFabricationNotice =>
      'دستیار فقط می‌تواند نوشته شما را بازساختاردهی و بازنویسی کند. هرگز شرکت، تاریخ، مدرک یا عدد از خود نمی‌سازد.';
  @override
  String get aiNeedsInfoTitle => 'به جزئیات بیشتری نیاز است';
  @override
  String get aiQuestionImproveRevenue =>
      'آیا این کار به درآمد، عملکرد، کارایی، تعامل یا نتیجه قابل اندازه‌گیری دیگری کمک کرد؟ اگر عدد را می‌دانید اضافه کنید؛ در غیر این صورت آن را حذف می‌کنیم.';
  @override
  String get aiConsentTitle => 'این متن به سرویس هوش مصنوعی ارسال شود؟';
  @override
  String get aiConsentBody =>
      'این یک قابلیت آنلاین است. تنها متن انتخاب‌شده برای سرویسی که خودتان تنظیم کرده‌اید ارسال می‌شود — نه کل رزومه، نه فایل‌ها و نه اطلاعات هویتی شما.';
  @override
  String get aiConsentAccept => 'ارسال و بهبود بده';
  @override
  String get aiConsentDecline => 'فعلاً نه';
  @override
  String get aiOfflineNotice => 'آفلاین هستید. قابلیت‌های هوش مصنوعی به اتصال نیاز دارند.';
  @override
  String get aiNoKeyTitle => 'سرویس هوش مصنوعی تنظیم نشده';
  @override
  String get aiNoKeyBody =>
      'برای فعال‌سازی بازنویسی و تحلیل پیشرفته، کلید API خودتان را در تنظیمات وارد کنید. بقیه بخش‌های اپ بدون آن هم کار می‌کنند.';
  @override
  String get aiOpenSettings => 'رفتن به تنظیمات';
  @override
  String get aiProvider => 'سرویس‌دهنده';
  @override
  String get aiApiKey => 'کلید API';
  @override
  String get aiApiKeyHint => 'در کلیدخانه دستگاه ذخیره می‌شود';
  @override
  String get aiApiKeyStoredSecurely =>
      'کلید شما در کلیدخانه اندروید نگهداری می‌شود. هرگز داخل بسته اپ قرار نمی‌گیرد و تنها به سرویسی که خودتان انتخاب کرده‌اید ارسال می‌شود.';
  @override
  String get aiModel => 'مدل';
  @override
  String get aiTestConnection => 'آزمایش اتصال';
  @override
  String get aiConnectionOk => 'اتصال موفق بود';
  @override
  String get aiConnectionFailed => 'اتصال برقرار نشد';

  // ── Import ───────────────────────────────────────────────────────────────
  @override
  String get importTitle => 'ورود سی‌وی موجود';
  @override
  String get importFromPdf => 'سند PDF';
  @override
  String get importFromDocx => 'سند ورد (‎.docx)';
  @override
  String get importFromTxt => 'متن ساده (‎.txt)';
  @override
  String get importFromImage => 'عکس یا اسکن';
  @override
  String get importReviewTitle => 'بازبینی اطلاعات واردشده';
  @override
  String get importReviewBody =>
      'پیش از ذخیره، آنچه پیدا کرده‌ایم را بررسی کنید. تا تأیید نکنید چیزی نوشته نمی‌شود.';
  @override
  String get importConfirmImport => 'این اطلاعات را وارد کن';
  @override
  String get importNothingFound => 'در این فایل اطلاعات ساختارمند پیدا نکردیم.';
  @override
  String get importOcrUnavailableTitle => 'تشخیص متن در دسترس نیست';
  @override
  String get importOcrUnavailableBody =>
      'در این نسخه موتور OCR روی‌دستگاه فعال نشده است. همچنان می‌توانید فایل PDF، DOCX و TXT وارد کنید یا اطلاعات را دستی وارد کنید.';
  @override
  String get importParsingTitle => 'در حال خواندن سند…';
  @override
  String get importParsingBody => 'این کار کاملاً روی دستگاه شما انجام می‌شود.';

  // ── Network & privacy ────────────────────────────────────────────────────
  @override
  String get statusOffline => 'آفلاین';
  @override
  String get statusOnline => 'آنلاین';
  @override
  String get statusLocal => 'روی این دستگاه';
  @override
  String get offlineBannerTitle => 'آفلاین هستید';
  @override
  String get offlineBannerBody => 'رزومه‌ات با خیال راحت روی دستگاهت ذخیره شده است.';
  @override
  String get continueOffline => 'ادامه به‌صورت آفلاین';
  @override
  String get privacyTitle => 'حریم خصوصی و داده‌ها';
  @override
  String get privacyLocalFirst => 'اولویت با داده محلی';
  @override
  String get privacyLocalFirstBody =>
      'هر رزومه، انتخاب قالب و تحلیل، در پایگاه‌داده روی همین دستگاه نگهداری می‌شود.';
  @override
  String get privacyNoAccount => 'بدون نیاز به حساب کاربری';
  @override
  String get privacyNoAccountBody =>
      'برای ساخت رزومه هیچ‌گاه نیازی به ثبت‌نام، ورود یا اتصال به سرویس ابری ندارید.';
  @override
  String get privacyDeleteAllTitle => 'حذف همه داده‌ها';
  @override
  String get privacyDeleteAllBody =>
      'همه رزومه‌ها، پروفایل مادر، خروجی‌ها و تنظیمات از این دستگاه پاک می‌شود. این کار قابل بازگشت نیست.';
  @override
  String get privacyDeleteAllConfirm => 'همه را حذف کن';
  @override
  String get privacyExportData => 'خروجی همه داده‌ها';
  @override
  String get privacyExportDataBody =>
      'یک فایل JSON شامل همه داده‌های روی این دستگاه ساخته می‌شود.';
  @override
  String get privacyDataDeleted => 'همه داده‌ها حذف شد';

  // ── Settings ─────────────────────────────────────────────────────────────
  @override
  String get settingsTitle => 'تنظیمات';
  @override
  String get settingsAppearance => 'ظاهر';
  @override
  String get settingsTheme => 'پوسته';
  @override
  String get settingsThemeSystem => 'سیستم';
  @override
  String get settingsThemeLight => 'روشن';
  @override
  String get settingsThemeDark => 'تیره';
  @override
  String get settingsLanguage => 'زبان';
  @override
  String get settingsDefaultRegion => 'بازار هدف پیش‌فرض';
  @override
  String get settingsDefaultPaperSize => 'اندازه کاغذ پیش‌فرض';
  @override
  String get settingsDateSystem => 'تقویم';
  @override
  String get dateSystemGregorian => 'میلادی';
  @override
  String get dateSystemJalali => 'شمسی (جلالی)';
  @override
  String get settingsDocumentFont => 'فونت سند';
  @override
  String get settingsAbout => 'درباره';
  @override
  String get settingsVersion => 'نسخه';
  @override
  String get settingsLicences => 'مجوزهای متن‌باز';
  @override
  String get settingsLicencesBody =>
      'فونت‌های همراه برنامه تحت مجوز SIL Open Font License 1.1 منتشر شده‌اند.';
  @override
  String get settingsResetOnboarding => 'نمایش دوباره معرفی';

  // ── Templates ────────────────────────────────────────────────────────────
  @override
  String get templatesTitle => 'قالب‌ها';
  @override
  String get templatesSearch => 'جست‌وجوی قالب';
  @override
  String get templatesAllCategories => 'همه';
  @override
  String get templatesCategoryProfessional => 'حرفه‌ای';
  @override
  String get templatesCategoryModern => 'مدرن';
  @override
  String get templatesCategoryAcademic => 'دانشگاهی';
  @override
  String get templatesCategoryRegional => 'منطقه‌ای';
  @override
  String get templatesCategoryCreative => 'خلاقانه';
  @override
  String get templatesAtsSafe => 'سازگار با ATS';
  @override
  String get templatesAtsSafeBody =>
      'یک‌ستونه، سرفصل‌های استاندارد، بدون جدول، بدون گرافیک و با متن کاملاً قابل استخراج.';
  @override
  String get templatesApply => 'استفاده از این قالب';
  @override
  String get templatesApplied => 'قالب اعمال شد';
  @override
  String get templatesPreviewHint => 'برای پیش‌نمایش با محتوای خودتان بزنید';
  @override
  String get templatesPremium => 'ویژه';
  @override
  String get templatesFree => 'رایگان';
  @override
  String get templatesSingleColumn => 'یک‌ستونه';
  @override
  String get templatesTwoColumn => 'دوستونه';
  @override
  String get templatesPageRecommendation => 'طول پیشنهادی';

  // ── Errors ───────────────────────────────────────────────────────────────
  @override
  String get errorCvNotFound => 'این سی‌وی دیگر وجود ندارد.';
  @override
  String get errorStorageFailure => 'ذخیره در پایگاه‌داده محلی ممکن نشد.';
  @override
  String get errorExportFailure => 'خروجی گرفتن ناموفق بود. فضای آزاد را بررسی کنید.';
  @override
  String get errorFileTooLarge => 'حجم این فایل برای ورود بیش از حد زیاد است.';
  @override
  String get errorUnsupportedFormat => 'قالب فایل پشتیبانی نمی‌شود.';
  @override
  String get errorInvalidJsonBackup => 'این فایل پشتیبان معتبر نیست.';
  @override
  String get errorNoPdfApp => 'هیچ برنامه‌ای برای نمایش PDF روی این دستگاه نصب نیست.';

  // ── Units ────────────────────────────────────────────────────────────────
  @override
  String get unitPage => 'صفحه';
  @override
  String get unitPages => 'صفحه';
  @override
  String get unitWords => 'واژه';
  @override
  String get unitCharacters => 'نویسه';
  @override
  String get unitBullets => 'بولت';
  @override
  String get statsQuantified => 'دارای عدد';
}
