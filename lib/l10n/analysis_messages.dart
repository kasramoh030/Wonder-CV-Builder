/// The wording behind the analyser's findings.
///
/// The analyser reports stable codes, never sentences. That is what lets the
/// same rule read naturally in English, Persian and German, and what lets a
/// stored report survive a language change. This table is the only place the
/// sentences live.
///
/// Every finding is stored as a pair: the *problem* a reader would recognise,
/// and the *fix* the user can act on. A number with no explanation, or a score
/// with no way to move it, is not useful advice.
library;

/// What is wrong, and what to do about it.
typedef AnalysisAdvice = ({String problem, String fix});

/// One mechanical ATS check: what was tested, and how to satisfy it.
typedef AtsAdvice = ({String label, String fix});

abstract final class AnalysisMessages {
  /// The advice for a recommendation code, in the requested language.
  static AnalysisAdvice recommendation(String languageCode, String code) =>
      (_recommendations[languageCode] ?? _recommendations['en']!)[code] ??
      _fallback;

  /// Whether a code has wording of its own, rather than falling back.
  ///
  /// A rule pack can ship an advisory code this build has never seen; the
  /// caller then uses the pack's own text instead of the generic fallback.
  static bool knows(String languageCode, String code) =>
      (_recommendations[languageCode] ?? _recommendations['en']!)
          .containsKey(code);

  /// The wording for a positive finding.
  static String strength(String languageCode, String code) =>
      (_strengths[languageCode] ?? _strengths['en']!)[code] ?? '';

  /// The label and remedy for a mechanical ATS check.
  static AtsAdvice atsCheck(String languageCode, String code) =>
      (_atsChecks[languageCode] ?? _atsChecks['en']!)[code] ?? _atsFallback;

  /// Substitutes `{name}` placeholders.
  ///
  /// An unknown placeholder is removed rather than left visible: showing a
  /// raw `{count}` to a user is worse than showing a slightly shorter
  /// sentence.
  static String fill(String template, Map<String, String> params) {
    if (params.isEmpty || !template.contains('{')) return template;
    String out = template;
    for (final MapEntry<String, String> entry in params.entries) {
      out = out.replaceAll('{${entry.key}}', entry.value);
    }
    return out.replaceAll(RegExp(r'\{[a-zA-Z]+\}'), '').replaceAll('  ', ' ');
  }

  /// A region's advisory text is already written by the rule pack (and is
  /// reviewed as content); the fallback keeps the screen readable if a pack
  /// ships without one.
  static const AnalysisAdvice _fallback = (
    problem: 'The analyser found something worth a look.',
    fix: 'Open the section named next to this note and check it against the '
        'guidance.',
  );

  static const AtsAdvice _atsFallback = (
    label: 'Layout check',
    fix: 'Keep the layout simple: one column, standard headings, no graphics.',
  );

  static const Map<String, Map<String, AnalysisAdvice>> _recommendations =
      <String, Map<String, AnalysisAdvice>>{
    'en': _enRecommendations,
    'fa': _faRecommendations,
    'de': _deRecommendations,
  };

  static const Map<String, Map<String, String>> _strengths =
      <String, Map<String, String>>{
    'en': _enStrengths,
    'fa': _faStrengths,
    'de': _deStrengths,
  };

  static const Map<String, Map<String, AtsAdvice>> _atsChecks =
      <String, Map<String, AtsAdvice>>{
    'en': _enAtsChecks,
    'fa': _faAtsChecks,
    'de': _deAtsChecks,
  };

  // ─────────────────────────────────────────────────────────────────────────
  // English
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, AnalysisAdvice> _enRecommendations =
      <String, AnalysisAdvice>{
    'content.missingName': (
      problem: 'The document has no name on it.',
      fix: 'Add your full name at the top of the page so a reader knows whose '
          'CV this is.',
    ),
    'content.missingContact': (
      problem: 'There is no complete way to contact you.',
      fix: 'Add an email address and a phone number. Use the international '
          'prefix on the phone number if you are applying abroad.',
    ),
    'content.missingEmail': (
      problem: 'There is no email address.',
      fix: 'Add an address you actually check. On paper it is the only way '
          'back to you.',
    ),
    'content.missingPhone': (
      problem: 'There is no phone number.',
      fix: 'Add a phone number, with the country code when you apply outside '
          'your own country.',
    ),
    'content.missingHeadline': (
      problem: 'There is no job title or headline under your name.',
      fix: 'Say in one line what you do — for example "Backend Developer" or '
          '"Marketing Analyst" — matching the role you are applying for.',
    ),
    'content.missingSummary': (
      problem: 'There is no professional summary.',
      fix: 'Write two or three lines: what you do, your strongest area, and '
          'what you are looking for next.',
    ),
    'content.noExperience': (
      problem: 'The experience section is empty.',
      fix: 'Add your roles — internships, part-time work and volunteering '
          'count — with dates and what you were responsible for.',
    ),
    'content.noEducation': (
      problem: 'The education section is empty.',
      fix: 'Add your degree or course, the institution and the years. If you '
          'are still studying, say so and give the expected date.',
    ),
    'content.noSkills': (
      problem: 'No skills are listed.',
      fix: 'List between five and twelve skills you could be asked about in '
          'an interview, most relevant first.',
    ),
    'content.noLanguages': (
      problem: 'No languages are listed.',
      fix: 'Add the languages you work in with your honest level in each.',
    ),
    'content.academicNoPublications': (
      problem: 'An academic document with no publications listed.',
      fix: 'Add your publications, or describe your research activity under '
          'research experience if nothing is published yet.',
    ),
    'structure.tooFewSections': (
      problem: 'Only {count} section headings were found.',
      fix: 'Readers scan headings first. Three or four clear sections make a '
          'CV navigable — add the ones your document is missing.',
    ),
    'structure.experienceMissingDates': (
      problem: '{count} role(s) have no dates.',
      fix: 'Give every role a start date and an end date, or mark it as your '
          'current position.',
    ),
    'structure.currentRoleHasEndDate': (
      problem: '{count} current role(s) also carry an end date.',
      fix: 'Mark the role as ongoing instead of giving it an end date; a '
          'reader may otherwise think you have already left.',
    ),
    'structure.experienceOrder': (
      problem: 'The roles are not in reverse-chronological order.',
      fix: 'Put the most recent role first. Newest on top is the convention '
          'in every market this app covers.',
    ),
    'structure.employmentGap': (
      problem: 'There is a period between two roles with nothing in it.',
      fix: 'A gap is not a defect. If the time was planned — study, family, '
          'travel — one short line about it answers the question before it is '
          'asked.',
    ),
    'structure.tooLong': (
      problem: 'The document runs to about {pages} pages; the usual guidance '
          'for this market is {ideal} pages.',
      fix: 'Cut duties that repeat between roles and keep the achievements '
          'that show a result.',
    ),
    'content.noBullets': (
      problem: 'Responsibilities are written as paragraphs rather than as '
          'bullet points.',
      fix: 'Break each role into three to five short bullets. A block of text '
          'is skipped.',
    ),
    'content.weakVerbOpeners': (
      problem: '{percent}% of your bullets open without a strong verb.',
      fix: 'Start with what you did: "led", "built", "reduced", "shipped", '
          '"coordinated". Keep it to what you genuinely did.',
    ),
    'content.lowQuantification': (
      problem: 'Only {percent}% of your bullets carry a measurable result.',
      fix: 'Add a number wherever you have one — time saved, users reached, '
          'budget handled, percentage improved. Never invent a figure.',
    ),
    'content.fillerPhrases': (
      problem: 'Empty phrases appear in the text, such as: {phrases}.',
      fix: 'Delete them and start the sentence with the action itself. They '
          'take space and say nothing.',
    ),
    'content.bulletTooLong': (
      problem: 'The longest bullet is about {words} words.',
      fix: 'One line is a bullet; two is a limit. Anything longer belongs in '
          'the section above or in an interview.',
    ),
    'content.bulletTooShort': (
      problem: 'A bullet is only one or two words long.',
      fix: 'A single word reads as a keyword rather than as evidence. Say '
          'what you did and what changed.',
    ),
    'content.repeatedWords': (
      problem: 'Some words repeat more than the rest: {words}.',
      fix: 'Check whether a repeated word is always the right word. This is a '
          'prompt to look, not a rule to obey.',
    ),
    'content.summaryTooShort': (
      problem: 'The summary is only {words} words long.',
      fix: 'Two or three full lines give a reader a reason to keep reading.',
    ),
    'content.summaryTooLong': (
      problem: 'The summary runs to {words} words.',
      fix: 'Trim it to the part a recruiter needs in the first ten seconds.',
    ),
    'content.fewSkills': (
      problem: 'Only {count} skills are listed.',
      fix: 'Add the tools and methods you would be comfortable being asked '
          'about. Five to twelve is a useful range.',
    ),
    'content.skillDump': (
      problem: '{count} skills are listed, which reads as a keyword dump.',
      fix: 'Keep the ones that matter for this application and drop the rest. '
          'A shorter, relevant list is stronger.',
    ),
    'language.firstPerson': (
      problem: 'The first person ("I", "my") appears {count} times.',
      fix: 'A CV usually drops the pronoun: "Led the migration" rather than '
          '"I led the migration".',
    ),
    'language.cliches': (
      problem: '{count} clichés were found, such as "hard-working" or "team '
          'player".',
      fix: 'Replace the claim with the evidence that made you want to write '
          'it.',
    ),
    'language.shoutingLine': (
      problem: 'A line is written in capitals.',
      fix: 'Capitalised words read as shouting and are harder to scan. Use '
          'capital letters for the heading and normal case for the text.',
    ),
    'language.veryLittleText': (
      problem: 'The document contains only {words} words.',
      fix: 'There is not enough here for an employer to judge. Describe your '
          'roles, the tools you used and what changed because of your work.',
    ),
    'ats.decorativeTemplate': (
      problem: 'This template is built for looks rather than for parsing.',
      fix: 'Consider an ATS-safe template for online applications: one '
          'column, standard headings, no photo, no graphics.',
    ),
    'ats.photoInAtsDocument': (
      problem: 'A photo in a document that is likely to be parsed by software.',
      fix: 'Remove the photo for online applications. Where a photo is '
          'expected, keep it — that is a different market and a different '
          'document.',
    ),
    'ats.twoColumns': (
      problem: 'The layout uses two columns.',
      fix: 'Some parsers read a two-column page line by line and mix the '
          'columns together. Use one column for the version you upload.',
    ),
    'ats.manyCustomSections': (
      problem: 'The document has {count} headings that are not standard '
          'section names.',
      fix: 'Standard headings ("Experience", "Education", "Skills") are '
          'recognised as they are. Custom names are not.',
    ),
    'ats.symbolHeavy': (
      problem: 'The text uses symbols where a plain separator would do.',
      fix: 'Replace decorative bullets and arrows with a normal hyphen or '
          'full stop.',
    ),
    'regional.missingRequiredSection': (
      problem: 'This market usually expects a {section} section, and it is '
          'not in the document.',
      fix: 'Add the section if you have anything to put in it. Nothing is '
          'added on your behalf.',
    ),
    'regional.discouragedSection': (
      problem: 'A {section} section is unusual for this market.',
      fix: 'It is not wrong, just less expected. Keep it if it helps your '
          'application.',
    ),
    'regional.photoNotExpected': (
      problem: 'The document includes a photo, which this market does not '
          'usually expect.',
      fix: 'Switch the photo off for this market unless the employer asks for '
          'one.',
    ),
    'regional.personalDetailsNotExpected': (
      problem: 'Personal details such as date of birth or marital status are '
          'shown, which this market does not usually expect.',
      fix: 'Turn the sensitive fields off. They are off by default and were '
          'switched on manually.',
    ),
    'regional.shorterThanExpected': (
      problem: 'The document is shorter than the {min} pages this market '
          'usually produces.',
      fix: 'Add detail where you have it — projects, courses, achievements — '
          'rather than padding what is already there.',
    ),
    'regional.photoForbidden': (
      problem: 'A photo is included, which this market treats as unusual.',
      fix: 'Remove the photo for this application.',
    ),
    'regional.personalDetails': (
      problem: 'Personal details are included that this market does not '
          'usually expect.',
      fix: 'Turn the sensitive fields off unless the employer requires them.',
    ),
    'regional.atsStrictMarket': (
      problem: 'Applications in this market are often screened by software.',
      fix: 'A simpler layout parses more reliably: one column, standard '
          'headings, no graphics.',
    ),
    'regional.paperOverride': (
      problem: 'The paper size does not match the usual size for this market.',
      fix: 'Switch the paper size so the document prints without scaling.',
    ),
    'jobMatch.missingKeywords': (
      problem: 'The advert asks for {count} term(s) your CV never uses: '
          '{keywords}.',
      fix: 'Check each one honestly. Only add a term if you genuinely have '
          'that experience — inventing a skill is discovered in the '
          'interview.',
    ),
    'jobMatch.strongKeywordOverlap': (
      problem: 'Nothing to fix here.',
      fix: 'The CV already covers {percent}% of the advert\'s terminology.',
    ),
    'jobMatch.skillGap': (
      problem: 'The advert asks for {skill}, which the CV does not show.',
      fix: 'Add it only if you have real experience with it. If you do not, '
          'that is a gap to close before applying, not a line to write.',
    ),
  };

  static const Map<String, String> _enStrengths = <String, String>{
    'content.goodQuantification': 'Most bullet points state a measurable '
        'result.',
    'content.strongVerbOpeners': 'Bullets open with strong, specific verbs.',
    'structure.wellStructured': 'The document has enough headings to be '
        'scanned quickly.',
    'language.noFiller': 'No filler phrases were found.',
    'content.contactComplete': 'The contact details are complete and '
        'reachable.',
    'jobMatch.strongOverlap': 'The vocabulary overlaps well with the advert.',
  };

  static const Map<String, AtsAdvice> _enAtsChecks = <String, AtsAdvice>{
    'ats.singleColumn': (
      label: 'Single column layout',
      fix: 'Use one column for documents you upload; two columns can be '
          'interleaved by a parser.',
    ),
    'ats.standardHeadings': (
      label: 'Standard section headings',
      fix: 'Name sections "Experience", "Education", "Skills" rather than '
          'invented titles.',
    ),
    'ats.searchableText': (
      label: 'Selectable, searchable text',
      fix: 'Export the PDF from the app rather than scanning a printout.',
    ),
    'ats.noPhoto': (
      label: 'No photo in an ATS document',
      fix: 'Remove the photo from the version you upload.',
    ),
    'ats.standardFont': (
      label: 'Standard, embedded font',
      fix: 'Choose one of the bundled fonts; unusual fonts may not be '
          'embedded.',
    ),
    'ats.contactInBody': (
      label: 'Contact details in the body of the page',
      fix: 'Keep contact details as normal text, not inside a header, footer '
          'or text box.',
    ),
    'ats.noTables': (
      label: 'No tables or text boxes',
      fix: 'Use headings and paragraphs; a table can be read out of order.',
    ),
    'ats.plainBullets': (
      label: 'Plain bullet characters',
      fix: 'Use the standard bullet or hyphen instead of icons and arrows.',
    ),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // فارسی
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, AnalysisAdvice> _faRecommendations =
      <String, AnalysisAdvice>{
    'content.missingName': (
      problem: 'نامی روی رزومه نوشته نشده است.',
      fix: 'نام و نام خانوادگی خود را در بالای صفحه بنویسید تا خواننده '
          'بداند این سند متعلق به کیست.',
    ),
    'content.missingContact': (
      problem: 'راه کاملی برای تماس با شما وجود ندارد.',
      fix: 'ایمیل و شماره تلفن را اضافه کنید. اگر به خارج از کشور درخواست '
          'می‌دهید، شماره را با کد کشور بنویسید.',
    ),
    'content.missingEmail': (
      problem: 'ایمیل نوشته نشده است.',
      fix: 'ایمیلی بنویسید که مرتب آن را بررسی می‌کنید؛ روی کاغذ تنها راه '
          'بازگشت به شما همین است.',
    ),
    'content.missingPhone': (
      problem: 'شماره تلفن نوشته نشده است.',
      fix: 'شماره تلفن را با کد کشور (برای درخواست‌های بین‌المللی) اضافه کنید.',
    ),
    'content.missingHeadline': (
      problem: 'عنوان شغلی یا تیتر زیر نام وجود ندارد.',
      fix: 'در یک خط بنویسید چه کاری انجام می‌دهید — مثلاً «برنامه‌نویس '
          'بک‌اند» — هم‌راستا با شغلی که برای آن درخواست می‌دهید.',
    ),
    'content.missingSummary': (
      problem: 'خلاصه حرفه‌ای نوشته نشده است.',
      fix: 'دو تا سه خط بنویسید: چه کاری انجام می‌دهید، قوی‌ترین حوزه‌تان '
          'و اینکه چه چیزی را دنبال می‌کنید.',
    ),
    'content.noExperience': (
      problem: 'بخش سوابق کاری خالی است.',
      fix: 'تجربه‌های خود را اضافه کنید؛ کارآموزی، کار پاره‌وقت و کار '
          'داوطلبانه هم حساب می‌شود — با تاریخ و مسئولیت‌ها.',
    ),
    'content.noEducation': (
      problem: 'بخش تحصیلات خالی است.',
      fix: 'مدرک یا رشته، نام مؤسسه و سال‌ها را بنویسید. اگر هنوز مشغول '
          'تحصیل هستید، تاریخ پایان مورد انتظار را ذکر کنید.',
    ),
    'content.noSkills': (
      problem: 'مهارتی فهرست نشده است.',
      fix: 'پنج تا دوازده مهارت بنویسید که در مصاحبه درباره‌شان از شما '
          'پرسیده می‌شود؛ مرتبط‌ترین‌ها اول.',
    ),
    'content.noLanguages': (
      problem: 'زبانی فهرست نشده است.',
      fix: 'زبان‌هایی که با آن‌ها کار می‌کنید و سطح واقعی‌تان در هر کدام را '
          'بنویسید.',
    ),
    'content.academicNoPublications': (
      problem: 'سند دانشگاهی است اما مقاله‌ای در آن نیامده.',
      fix: 'مقاله‌های خود را اضافه کنید یا اگر هنوز چیزی چاپ نشده، فعالیت '
          'پژوهشی‌تان را در بخش تجربه پژوهشی بنویسید.',
    ),
    'structure.tooFewSections': (
      problem: 'تنها {count} سرصفحه بخش پیدا شد.',
      fix: 'خواننده اول سرصفحه‌ها را می‌بیند؛ سه یا چهار بخش روشن، رزومه را '
          'خواندنی می‌کند. بخش‌های جامانده را اضافه کنید.',
    ),
    'structure.experienceMissingDates': (
      problem: '{count} مورد از سوابق تاریخ ندارد.',
      fix: 'برای هر سابقه تاریخ شروع و پایان بنویسید، یا آن را شغل فعلی '
          'علامت بزنید.',
    ),
    'structure.currentRoleHasEndDate': (
      problem: '{count} شغل فعلی تاریخ پایان هم دارد.',
      fix: 'شغل فعلی را «تاکنون» علامت بزنید تا خواننده تصور نکند آن را ترک '
          'کرده‌اید.',
    ),
    'structure.experienceOrder': (
      problem: 'سوابق به ترتیب از جدید به قدیم مرتب نشده‌اند.',
      fix: 'جدیدترین سابقه را اول بنویسید؛ در همه بازارهایی که این برنامه '
          'پشتیبانی می‌کند همین رسم است.',
    ),
    'structure.employmentGap': (
      problem: 'بین دو سابقه، بازه‌ای خالی وجود دارد.',
      fix: 'فاصله افتادن ایراد نیست. اگر این زمان برنامه‌ریزی‌شده بوده '
          '(تحصیل، خانواده، سفر) یک خط کوتاه درباره‌اش کافی است.',
    ),
    'structure.tooLong': (
      problem: 'سند حدود {pages} صفحه شده است؛ راهنمای معمول این بازار '
          '{ideal} صفحه است.',
      fix: 'مسئولیت‌های تکراری را حذف کنید و دستاوردهایی را نگه دارید که '
          'نتیجه نشان می‌دهند.',
    ),
    'content.noBullets': (
      problem: 'مسئولیت‌ها به شکل پاراگراف نوشته شده‌اند، نه فهرست نقطه‌ای.',
      fix: 'هر سابقه را به سه تا پنج بولت کوتاه بشکنید؛ متن پیوسته خوانده '
          'نمی‌شود.',
    ),
    'content.weakVerbOpeners': (
      problem: '{percent}٪ بولت‌ها با فعل ضعیف شروع می‌شوند.',
      fix: 'با کاری که کرده‌اید شروع کنید: «رهبری کردم»، «ساختم»، «کاهش '
          'دادم» — فقط همان کاری که واقعاً انجام داده‌اید.',
    ),
    'content.lowQuantification': (
      problem: 'تنها {percent}٪ بولت‌ها نتیجه‌ای قابل اندازه‌گیری دارند.',
      fix: 'هرجا عدد دارید بنویسید: زمان صرفه‌جویی‌شده، تعداد کاربر، بودجه. '
          'هیچ عددی را از خود نسازید.',
    ),
    'content.fillerPhrases': (
      problem: 'عبارت‌های خالی در متن هست، مانند: {phrases}.',
      fix: 'آن‌ها را حذف کنید و جمله را با خودِ عمل شروع کنید؛ فضا می‌گیرند '
          'و چیزی نمی‌گویند.',
    ),
    'content.bulletTooLong': (
      problem: 'بلندترین بولت حدود {words} کلمه است.',
      fix: 'یک خط بولت است و دو خط سقف آن؛ بیشتر از آن جای دیگری دارد.',
    ),
    'content.bulletTooShort': (
      problem: 'یک بولت فقط یکی دو کلمه است.',
      fix: 'یک کلمه شبیه کلیدواژه است، نه شاهد. بنویسید چه کردید و چه چیزی '
          'تغییر کرد.',
    ),
    'content.repeatedWords': (
      problem: 'بعضی واژه‌ها بیش از بقیه تکرار شده‌اند: {words}.',
      fix: 'بررسی کنید آیا واژه تکرارشده همیشه درست است؛ این یادآوری برای '
          'نگاه کردن است، نه قاعده‌ای برای اطاعت.',
    ),
    'content.summaryTooShort': (
      problem: 'خلاصه تنها {words} کلمه است.',
      fix: 'دو تا سه خط کامل به خواننده دلیلی برای ادامه دادن می‌دهد.',
    ),
    'content.summaryTooLong': (
      problem: 'خلاصه {words} کلمه شده است.',
      fix: 'آن را به همان بخشی محدود کنید که کارفرما در ده ثانیه اول لازم '
          'دارد.',
    ),
    'content.fewSkills': (
      problem: 'فقط {count} مهارت فهرست شده است.',
      fix: 'ابزارها و روش‌هایی را بنویسید که در مصاحبه درباره‌شان راحت '
          'هستید؛ پنج تا دوازده مورد کافی است.',
    ),
    'content.skillDump': (
      problem: '{count} مهارت فهرست شده که شبیه انبار کلیدواژه است.',
      fix: 'مهارت‌های مرتبط با همین درخواست را نگه دارید و بقیه را بردارید؛ '
          'فهرست کوتاه‌تر و مرتبط‌تر قوی‌تر است.',
    ),
    'language.firstPerson': (
      problem: 'اول‌شخص («من»، «مال من») {count} بار به کار رفته است.',
      fix: 'در رزومه معمولاً ضمیر حذف می‌شود: «مهاجرت را رهبری کردم» به‌جای '
          '«من مهاجرت را رهبری کردم».',
    ),
    'language.cliches': (
      problem: '{count} کلیشه پیدا شد، مانند «سخت‌کوش» یا «کار تیمی».',
      fix: 'جای ادعا، شاهدی را بنویسید که باعث شد این جمله را بنویسید.',
    ),
    'language.shoutingLine': (
      problem: 'یک خط با حروف بزرگ نوشته شده است.',
      fix: 'متن با حروف بزرگ شبیه فریاد زدن است و سخت‌تر خوانده می‌شود؛ '
          'حروف بزرگ را برای سرصفحه نگه دارید.',
    ),
    'language.veryLittleText': (
      problem: 'سند تنها {words} کلمه دارد.',
      fix: 'این مقدار برای قضاوت کارفرما کافی نیست. سوابق، ابزارها و '
          'نتیجه‌ای که کارتان ساخته را بنویسید.',
    ),
    'ats.decorativeTemplate': (
      problem: 'این قالب برای ظاهر طراحی شده، نه برای خوانده شدن با نرم‌افزار.',
      fix: 'برای درخواست‌های آنلاین قالبی سازگار با ATS انتخاب کنید: یک '
          'ستون، سرصفحه‌های استاندارد، بدون عکس و گرافیک.',
    ),
    'ats.photoInAtsDocument': (
      problem: 'در سندی که احتمالاً نرم‌افزار آن را می‌خواند، عکس وجود دارد.',
      fix: 'برای درخواست آنلاین عکس را بردارید. اگر بازار عکس می‌خواهد، '
          'نگهش دارید؛ آن بازار و آن سند فرق دارد.',
    ),
    'ats.twoColumns': (
      problem: 'چیدمان دو ستونی است.',
      fix: 'بعضی نرم‌افزارها صفحه دو ستونی را خط‌به‌خط می‌خوانند و ستون‌ها را '
          'قاطی می‌کنند؛ برای فایل ارسالی یک ستون بگذارید.',
    ),
    'ats.manyCustomSections': (
      problem: 'سند {count} سرصفحه دارد که نام استاندارد بخش‌ها نیست.',
      fix: 'سرصفحه‌های استاندارد («سوابق کاری»، «تحصیلات»، «مهارت‌ها») '
          'شناخته می‌شوند؛ نام‌های خودساخته نه.',
    ),
    'ats.symbolHeavy': (
      problem: 'در متن به‌جای جداکننده ساده از نماد استفاده شده است.',
      fix: 'نقطه‌های تزئینی و فلش‌ها را با خط تیره یا نقطه معمولی عوض کنید.',
    ),
    'regional.missingRequiredSection': (
      problem: 'این بازار معمولاً بخش «{section}» را انتظار دارد و در سند '
          'نیست.',
      fix: 'اگر محتوایی برای آن دارید، بخش را اضافه کنید. هیچ چیزی از طرف '
          'شما اضافه نمی‌شود.',
    ),
    'regional.discouragedSection': (
      problem: 'بخش «{section}» برای این بازار غیرمعمول است.',
      fix: 'اشتباه نیست، فقط کمتر انتظار می‌رود. اگر به درخواست شما کمک '
          'می‌کند نگهش دارید.',
    ),
    'regional.photoNotExpected': (
      problem: 'سند عکس دارد، در حالی که این بازار معمولاً عکس نمی‌خواهد.',
      fix: 'برای این بازار عکس را خاموش کنید، مگر آنکه کارفرما بخواهد.',
    ),
    'regional.personalDetailsNotExpected': (
      problem: 'اطلاعات شخصی مثل تاریخ تولد یا وضعیت تأهل نمایش داده می‌شود '
          'که در این بازار معمول نیست.',
      fix: 'فیلدهای حساس را خاموش کنید؛ این فیلدها به‌صورت پیش‌فرض خاموش '
          'هستند و دستی روشن شده‌اند.',
    ),
    'regional.shorterThanExpected': (
      problem: 'سند کوتاه‌تر از {min} صفحه‌ای است که این بازار معمولاً '
          'می‌بیند.',
      fix: 'هرجا اطلاعات دارید جزئیات اضافه کنید — پروژه، دوره، دستاورد — نه '
          'اینکه متن موجود را پر کنید.',
    ),
    'regional.photoForbidden': (
      problem: 'عکس در سند هست، در حالی که این بازار آن را غیرمعمول می‌داند.',
      fix: 'برای این درخواست عکس را بردارید.',
    ),
    'regional.personalDetails': (
      problem: 'اطلاعات شخصی‌ای در سند هست که این بازار معمولاً انتظار ندارد.',
      fix: 'فیلدهای حساس را خاموش کنید، مگر آنکه کارفرما لازم بداند.',
    ),
    'regional.atsStrictMarket': (
      problem: 'در این بازار درخواست‌ها اغلب با نرم‌افزار غربال می‌شوند.',
      fix: 'چیدمان ساده‌تر مطمئن‌تر خوانده می‌شود: یک ستون، سرصفحه‌های '
          'استاندارد، بدون گرافیک.',
    ),
    'regional.paperOverride': (
      problem: 'اندازه کاغذ با اندازه معمول این بازار یکی نیست.',
      fix: 'اندازه کاغذ را عوض کنید تا سند بدون مقیاس‌شدن چاپ شود.',
    ),
    'jobMatch.missingKeywords': (
      problem: 'آگهی {count} اصطلاح می‌خواهد که در رزومه شما نیست: {keywords}.',
      fix: 'هرکدام را صادقانه بررسی کنید. فقط اگر واقعاً آن تجربه را دارید '
          'اضافه کنید؛ مهارت ساختگی در مصاحبه معلوم می‌شود.',
    ),
    'jobMatch.strongKeywordOverlap': (
      problem: 'چیزی برای اصلاح نیست.',
      fix: 'رزومه شما {percent}٪ از اصطلاحات آگهی را پوشش می‌دهد.',
    ),
    'jobMatch.skillGap': (
      problem: 'آگهی «{skill}» می‌خواهد و در رزومه دیده نمی‌شود.',
      fix: 'فقط اگر تجربه واقعی دارید اضافه کنید. اگر ندارید، این فاصله‌ای '
          'است که باید پیش از درخواست پر شود، نه خطی که نوشته شود.',
    ),
  };

  static const Map<String, String> _faStrengths = <String, String>{
    'content.goodQuantification': 'بیشتر بولت‌ها نتیجه‌ای قابل اندازه‌گیری '
        'را بیان می‌کنند.',
    'content.strongVerbOpeners': 'بولت‌ها با فعل‌های قوی و مشخص شروع می‌شوند.',
    'structure.wellStructured': 'سرصفحه‌ها برای مرور سریع سند کافی است.',
    'language.noFiller': 'عبارت خالی و بی‌محتوا پیدا نشد.',
    'content.contactComplete': 'اطلاعات تماس کامل و قابل استفاده است.',
    'jobMatch.strongOverlap': 'واژگان رزومه با آگهی همپوشانی خوبی دارد.',
  };

  static const Map<String, AtsAdvice> _faAtsChecks = <String, AtsAdvice>{
    'ats.singleColumn': (
      label: 'چیدمان یک‌ستونی',
      fix: 'برای فایل ارسالی یک ستون بگذارید؛ نرم‌افزار ممکن است ستون‌های '
          'دو ستون را قاطی کند.',
    ),
    'ats.standardHeadings': (
      label: 'سرصفحه‌های استاندارد',
      fix: 'بخش‌ها را «سوابق کاری»، «تحصیلات»، «مهارت‌ها» نام بگذارید، نه '
          'عنوان‌های ساختگی.',
    ),
    'ats.searchableText': (
      label: 'متن قابل انتخاب و جست‌وجو',
      fix: 'فایل PDF را از همین برنامه بگیرید، نه از اسکن کاغذ.',
    ),
    'ats.noPhoto': (
      label: 'بدون عکس در سند ATS',
      fix: 'در نسخه‌ای که بارگذاری می‌کنید عکس را بردارید.',
    ),
    'ats.standardFont': (
      label: 'قلم استاندارد و جاگذاری‌شده',
      fix: 'یکی از قلم‌های همراه برنامه را انتخاب کنید؛ قلم نامعمول ممکن است '
          'جاگذاری نشود.',
    ),
    'ats.contactInBody': (
      label: 'اطلاعات تماس در متن صفحه',
      fix: 'اطلاعات تماس را متن معمولی بگذارید، نه داخل سرصفحه/پاصفحه یا '
          'کادر متنی.',
    ),
    'ats.noTables': (
      label: 'بدون جدول و کادر متنی',
      fix: 'از سرصفحه و پاراگراف استفاده کنید؛ محتوای جدول ممکن است '
          'بی‌ترتیب خوانده شود.',
    ),
    'ats.plainBullets': (
      label: 'نشانه‌های ساده فهرست',
      fix: 'به‌جای آیکون و فلش از همان نقطه یا خط تیره معمولی استفاده کنید.',
    ),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Deutsch
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, AnalysisAdvice> _deRecommendations =
      <String, AnalysisAdvice>{
    'content.missingName': (
      problem: 'Auf dem Dokument steht kein Name.',
      fix: 'Schreiben Sie Ihren vollständigen Namen oben auf die Seite, damit '
          'klar ist, von wem der Lebenslauf stammt.',
    ),
    'content.missingContact': (
      problem: 'Es fehlt eine vollständige Kontaktmöglichkeit.',
      fix: 'Ergänzen Sie E-Mail-Adresse und Telefonnummer. Bei Bewerbungen ins '
          'Ausland mit Ländervorwahl.',
    ),
    'content.missingEmail': (
      problem: 'Es fehlt eine E-Mail-Adresse.',
      fix: 'Nennen Sie eine Adresse, die Sie regelmäßig lesen — auf Papier ist '
          'sie der einzige Rückweg zu Ihnen.',
    ),
    'content.missingPhone': (
      problem: 'Es fehlt eine Telefonnummer.',
      fix: 'Ergänzen Sie die Nummer, bei Bewerbungen außerhalb Ihres Landes '
          'mit Ländervorwahl.',
    ),
    'content.missingHeadline': (
      problem: 'Unter dem Namen steht keine Positionsbezeichnung.',
      fix: 'Sagen Sie in einer Zeile, was Sie tun — etwa „Backend-Entwickler“ '
          '— passend zur ausgeschriebenen Stelle.',
    ),
    'content.missingSummary': (
      problem: 'Es fehlt eine Kurzprofil.',
      fix: 'Schreiben Sie zwei bis drei Zeilen: was Sie tun, wo Ihre größte '
          'Stärke liegt und was Sie als Nächstes suchen.',
    ),
    'content.noExperience': (
      problem: 'Der Abschnitt Berufserfahrung ist leer.',
      fix: 'Tragen Sie Ihre Stationen ein — Praktika, Teilzeit und Ehrenamt '
          'zählen ebenfalls — mit Zeitraum und Verantwortung.',
    ),
    'content.noEducation': (
      problem: 'Der Abschnitt Ausbildung ist leer.',
      fix: 'Ergänzen Sie Abschluss, Einrichtung und Jahre. Wenn Sie noch '
          'studieren, nennen Sie das voraussichtliche Ende.',
    ),
    'content.noSkills': (
      problem: 'Es sind keine Kenntnisse aufgeführt.',
      fix: 'Listen Sie fünf bis zwölf Kenntnisse, über die Sie im Gespräch '
          'gefragt werden möchten — die relevantesten zuerst.',
    ),
    'content.noLanguages': (
      problem: 'Es sind keine Sprachen aufgeführt.',
      fix: 'Nennen Sie die Sprachen, in denen Sie arbeiten, mit Ihrem '
          'ehrlichen Niveau.',
    ),
    'content.academicNoPublications': (
      problem: 'Ein wissenschaftliches Dokument ohne Publikationen.',
      fix: 'Ergänzen Sie Ihre Publikationen, oder beschreiben Sie Ihre '
          'Forschung unter Forschungserfahrung, falls noch nichts '
          'veröffentlicht ist.',
    ),
    'structure.tooFewSections': (
      problem: 'Es wurden nur {count} Abschnittsüberschriften gefunden.',
      fix: 'Überschriften werden zuerst gelesen. Drei oder vier klare '
          'Abschnitte machen den Lebenslauf lesbar.',
    ),
    'structure.experienceMissingDates': (
      problem: '{count} Station(en) haben keinen Zeitraum.',
      fix: 'Geben Sie jeder Station Beginn und Ende, oder markieren Sie sie '
          'als aktuelle Position.',
    ),
    'structure.currentRoleHasEndDate': (
      problem: '{count} aktuelle Position(en) haben auch ein Enddatum.',
      fix: 'Markieren Sie die Position als laufend; sonst liest es sich, als '
          'hätten Sie die Stelle bereits verlassen.',
    ),
    'structure.experienceOrder': (
      problem: 'Die Stationen sind nicht in umgekehrter zeitlicher Reihenfolge.',
      fix: 'Die neueste Station gehört nach oben — das ist in allen hier '
          'unterstützten Märkten üblich.',
    ),
    'structure.employmentGap': (
      problem: 'Zwischen zwei Stationen liegt eine Lücke.',
      fix: 'Eine Lücke ist kein Fehler. War die Zeit geplant — Studium, '
          'Familie, Reisen — beantwortet ein kurzer Satz die Frage vorab.',
    ),
    'structure.tooLong': (
      problem: 'Das Dokument umfasst etwa {pages} Seiten; üblich sind in '
          'diesem Markt {ideal} Seiten.',
      fix: 'Streichen Sie wiederholte Tätigkeiten und behalten Sie die '
          'Ergebnisse, die etwas belegen.',
    ),
    'content.noBullets': (
      problem: 'Aufgaben stehen als Fließtext statt als Stichpunkte.',
      fix: 'Teilen Sie jede Station in drei bis fünf kurze Punkte; ein '
          'Textblock wird übersprungen.',
    ),
    'content.weakVerbOpeners': (
      problem: '{percent}% Ihrer Stichpunkte beginnen ohne starkes Verb.',
      fix: 'Beginnen Sie mit dem, was Sie getan haben: „leitete“, „baute“, '
          '„senkte“, „koordinierte“ — nur wenn es zutrifft.',
    ),
    'content.lowQuantification': (
      problem: 'Nur {percent}% Ihrer Stichpunkte nennen ein messbares '
          'Ergebnis.',
      fix: 'Ergänzen Sie eine Zahl, wo Sie eine haben — gesparte Zeit, '
          'erreichte Nutzer, verwaltetes Budget. Erfinden Sie keine Zahlen.',
    ),
    'content.fillerPhrases': (
      problem: 'Es stehen leere Wendungen im Text, etwa: {phrases}.',
      fix: 'Streichen Sie sie und beginnen Sie mit der Handlung selbst; sie '
          'kosten Platz und sagen nichts.',
    ),
    'content.bulletTooLong': (
      problem: 'Der längste Stichpunkt hat etwa {words} Wörter.',
      fix: 'Eine Zeile ist ein Stichpunkt, zwei sind die Grenze. Mehr gehört '
          'in das Gespräch.',
    ),
    'content.bulletTooShort': (
      problem: 'Ein Stichpunkt besteht nur aus ein oder zwei Wörtern.',
      fix: 'Ein Wort wirkt wie ein Schlagwort, nicht wie ein Beleg. Sagen Sie, '
          'was Sie getan haben und was sich dadurch änderte.',
    ),
    'content.repeatedWords': (
      problem: 'Einige Wörter wiederholen sich häufiger: {words}.',
      fix: 'Prüfen Sie, ob das wiederholte Wort immer das richtige ist. Das '
          'ist ein Hinweis zum Nachsehen, keine Regel.',
    ),
    'content.summaryTooShort': (
      problem: 'Das Kurzprofil hat nur {words} Wörter.',
      fix: 'Zwei bis drei volle Zeilen geben einen Grund weiterzulesen.',
    ),
    'content.summaryTooLong': (
      problem: 'Das Kurzprofil umfasst {words} Wörter.',
      fix: 'Kürzen Sie auf das, was in den ersten zehn Sekunden gebraucht '
          'wird.',
    ),
    'content.fewSkills': (
      problem: 'Es sind nur {count} Kenntnisse aufgeführt.',
      fix: 'Ergänzen Sie Werkzeuge und Methoden, bei denen Sie sicher '
          'antworten können. Fünf bis zwölf sind ein guter Bereich.',
    ),
    'content.skillDump': (
      problem: '{count} Kenntnisse wirken wie eine Schlagwortliste.',
      fix: 'Behalten Sie die für diese Bewerbung relevanten und streichen Sie '
          'den Rest. Kürzer und passend ist stärker.',
    ),
    'language.firstPerson': (
      problem: 'Die Ich-Form erscheint {count} Mal.',
      fix: 'Im Lebenslauf entfällt das Pronomen: „Leitete die Migration“ statt '
          '„Ich leitete die Migration“.',
    ),
    'language.cliches': (
      problem: '{count} Floskeln wurden gefunden, etwa „teamfähig“ oder '
          '„belastbar“.',
      fix: 'Ersetzen Sie die Behauptung durch den Beleg, der Sie dazu bewogen '
          'hat.',
    ),
    'language.shoutingLine': (
      problem: 'Eine Zeile ist in Großbuchstaben geschrieben.',
      fix: 'Großbuchstaben wirken wie Rufen und sind schwerer zu lesen. Nur '
          'die Überschrift darf groß sein.',
    ),
    'language.veryLittleText': (
      problem: 'Das Dokument enthält nur {words} Wörter.',
      fix: 'Das reicht für eine Beurteilung nicht. Beschreiben Sie Stationen, '
          'Werkzeuge und was sich durch Ihre Arbeit geändert hat.',
    ),
    'ats.decorativeTemplate': (
      problem: 'Diese Vorlage ist auf Aussehen optimiert, nicht auf '
          'maschinelles Auslesen.',
      fix: 'Für Online-Bewerbungen eignet sich eine ATS-freundliche Vorlage: '
          'eine Spalte, Standardüberschriften, kein Foto, keine Grafik.',
    ),
    'ats.photoInAtsDocument': (
      problem: 'Ein Foto in einem Dokument, das wahrscheinlich maschinell '
          'gelesen wird.',
      fix: 'Entfernen Sie das Foto für die Online-Bewerbung. Wo ein Foto '
          'erwartet wird, bleibt es — das ist ein anderer Markt.',
    ),
    'ats.twoColumns': (
      problem: 'Das Layout ist zweispaltig.',
      fix: 'Manche Programme lesen zweispaltige Seiten zeilenweise und '
          'vermischen die Spalten. Nutzen Sie eine Spalte für den Upload.',
    ),
    'ats.manyCustomSections': (
      problem: 'Das Dokument hat {count} Überschriften, die keine '
          'Standardabschnitte sind.',
      fix: 'Standardüberschriften („Berufserfahrung“, „Ausbildung“, '
          '„Kenntnisse“) werden erkannt, eigene Bezeichnungen nicht.',
    ),
    'ats.symbolHeavy': (
      problem: 'Im Text stehen Symbole, wo ein einfaches Trennzeichen reicht.',
      fix: 'Ersetzen Sie Zierpunkte und Pfeile durch Bindestrich oder Punkt.',
    ),
    'regional.missingRequiredSection': (
      problem: 'In diesem Markt wird üblicherweise ein Abschnitt „{section}“ '
          'erwartet; er fehlt.',
      fix: 'Ergänzen Sie den Abschnitt, wenn Sie Inhalte dafür haben. Es wird '
          'nichts in Ihrem Namen hinzugefügt.',
    ),
    'regional.discouragedSection': (
      problem: 'Ein Abschnitt „{section}“ ist in diesem Markt unüblich.',
      fix: 'Falsch ist er nicht, nur weniger erwartet. Behalten Sie ihn, wenn '
          'er Ihrer Bewerbung hilft.',
    ),
    'regional.photoNotExpected': (
      problem: 'Das Dokument enthält ein Foto, das in diesem Markt meist '
          'nicht erwartet wird.',
      fix: 'Schalten Sie das Foto für diesen Markt ab, sofern der Betrieb '
          'keines verlangt.',
    ),
    'regional.personalDetailsNotExpected': (
      problem: 'Persönliche Angaben wie Geburtsdatum oder Familienstand sind '
          'sichtbar, was in diesem Markt unüblich ist.',
      fix: 'Schalten Sie die sensiblen Felder ab; sie sind standardmäßig aus '
          'und wurden manuell eingeschaltet.',
    ),
    'regional.shorterThanExpected': (
      problem: 'Das Dokument ist kürzer als die in diesem Markt üblichen '
          '{min} Seiten.',
      fix: 'Ergänzen Sie Details, die Sie haben — Projekte, Kurse, Erfolge — '
          'statt Vorhandenes zu strecken.',
    ),
    'regional.photoForbidden': (
      problem: 'Ein Foto ist enthalten, das in diesem Markt als unüblich gilt.',
      fix: 'Entfernen Sie das Foto für diese Bewerbung.',
    ),
    'regional.personalDetails': (
      problem: 'Es sind persönliche Angaben enthalten, die dieser Markt '
          'üblicherweise nicht erwartet.',
      fix: 'Schalten Sie die sensiblen Felder ab, sofern der Betrieb sie '
          'nicht verlangt.',
    ),
    'regional.atsStrictMarket': (
      problem: 'Bewerbungen werden in diesem Markt häufig maschinell '
          'vorgefiltert.',
      fix: 'Ein einfacheres Layout wird zuverlässiger gelesen: eine Spalte, '
          'Standardüberschriften, keine Grafik.',
    ),
    'regional.paperOverride': (
      problem: 'Das Papierformat entspricht nicht dem üblichen Format dieses '
          'Marktes.',
      fix: 'Wechseln Sie das Format, damit ohne Skalierung gedruckt wird.',
    ),
    'jobMatch.missingKeywords': (
      problem: 'Die Anzeige verlangt {count} Begriffe, die im Lebenslauf '
          'fehlen: {keywords}.',
      fix: 'Prüfen Sie jeden ehrlich. Ergänzen Sie nur, was Sie wirklich '
          'können — erfundene Kenntnisse fallen im Gespräch auf.',
    ),
    'jobMatch.strongKeywordOverlap': (
      problem: 'Hier gibt es nichts zu korrigieren.',
      fix: 'Der Lebenslauf deckt bereits {percent}% der Begriffe aus der '
          'Anzeige ab.',
    ),
    'jobMatch.skillGap': (
      problem: 'Die Anzeige verlangt {skill}, was der Lebenslauf nicht zeigt.',
      fix: 'Ergänzen Sie es nur bei echter Erfahrung. Sonst ist es eine Lücke '
          'zum Schließen, keine Zeile zum Schreiben.',
    ),
  };

  static const Map<String, String> _deStrengths = <String, String>{
    'content.goodQuantification': 'Die meisten Stichpunkte nennen ein '
        'messbares Ergebnis.',
    'content.strongVerbOpeners': 'Die Stichpunkte beginnen mit starken, '
        'konkreten Verben.',
    'structure.wellStructured': 'Es gibt genug Überschriften für einen '
        'schnellen Überblick.',
    'language.noFiller': 'Es wurden keine Floskeln gefunden.',
    'content.contactComplete': 'Die Kontaktdaten sind vollständig und '
        'erreichbar.',
    'jobMatch.strongOverlap': 'Die Begriffe decken sich gut mit der Anzeige.',
  };

  static const Map<String, AtsAdvice> _deAtsChecks = <String, AtsAdvice>{
    'ats.singleColumn': (
      label: 'Einspaltiges Layout',
      fix: 'Nutzen Sie für Uploads eine Spalte; Programme können zwei Spalten '
          'vermischen.',
    ),
    'ats.standardHeadings': (
      label: 'Standard-Überschriften',
      fix: 'Nennen Sie Abschnitte „Berufserfahrung“, „Ausbildung“, '
          '„Kenntnisse“ statt eigener Titel.',
    ),
    'ats.searchableText': (
      label: 'Auswählbarer, durchsuchbarer Text',
      fix: 'Erzeugen Sie das PDF in dieser App statt einen Ausdruck zu '
          'scannen.',
    ),
    'ats.noPhoto': (
      label: 'Kein Foto im ATS-Dokument',
      fix: 'Entfernen Sie das Foto aus der Version, die Sie hochladen.',
    ),
    'ats.standardFont': (
      label: 'Standardschrift, eingebettet',
      fix: 'Wählen Sie eine der mitgelieferten Schriften; ungewöhnliche '
          'Schriften werden oft nicht eingebettet.',
    ),
    'ats.contactInBody': (
      label: 'Kontaktdaten im Seitentext',
      fix: 'Kontaktdaten als normalen Text halten, nicht in Kopf-, Fußzeile '
          'oder Textfeld.',
    ),
    'ats.noTables': (
      label: 'Keine Tabellen oder Textfelder',
      fix: 'Überschriften und Absätze nutzen; Tabellen werden manchmal in '
          'falscher Reihenfolge gelesen.',
    ),
    'ats.plainBullets': (
      label: 'Einfache Aufzählungszeichen',
      fix: 'Statt Symbolen und Pfeilen den normalen Punkt oder Bindestrich '
          'verwenden.',
    ),
  };
}
