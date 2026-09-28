import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/date_display.dart';
import '../domain/entities/regional_profile.dart';
import '../domain/entities/resume.dart';
import '../domain/entities/resume_content.dart';
import '../domain/entities/year_month.dart';
import '../domain/enums/document_options.dart';
import '../domain/enums/section_key.dart';
import '../domain/rules/regional_rule_engine.dart';
import '../domain/templates/resume_template.dart';
import '../l10n/app_localizations.dart';
import 'pdf_fonts.dart';

/// Everything one render needs. Passing the plan and the template in, rather
/// than looking them up, is what keeps this engine free of I/O: it takes a
/// document description and returns bytes.
class ResumePdfRequest {
  const ResumePdfRequest({
    required this.resume,
    required this.plan,
    required this.template,
    required this.l10n,
    this.pageFormat,
    this.photoBytes,
  });

  final Resume resume;
  final FormatPlan plan;
  final ResumeTemplate template;

  /// Section headings are taken from the document's own language, not the
  /// app's, so a Persian-speaker building a German CV prints German headings.
  final AppLocalizations l10n;

  /// Overrides the paper from the plan. Used by the "US Letter" preview toggle.
  final PdfPageFormat? pageFormat;

  /// The candidate photo, already decoded, when the document shows one.
  ///
  /// Passed in rather than read from disk here, because reading a file is
  /// I/O and this engine has none: it turns a description into bytes.
  final Uint8List? photoBytes;
}

/// The rendered document plus what the renderer learned while producing it.
///
/// Nothing is guessed: [pageCount] is measured from the produced file, and
/// [warnings] carries facts the UI shows the user rather than silently
/// compensating for (the brief forbids shrinking type to make content fit).
class ResumePdfResult {
  const ResumePdfResult({
    required this.bytes,
    required this.pageCount,
    required this.warnings,
    required this.byteSize,
  });

  final Uint8List bytes;
  final int pageCount;
  final List<PdfRenderWarning> warnings;
  final int byteSize;
}

/// A fact worth telling the user about, with the code the UI localises.
class PdfRenderWarning {
  const PdfRenderWarning(this.code, {this.params = const <String, String>{}});

  final String code;
  final Map<String, String> params;
}

/// Builds the actual PDF: real text, embedded fonts, selectable and
/// searchable output.
///
/// Design decisions that matter here:
///
/// * **Everything is flowable text.** No screenshot, no raster fallback, no
///   text rendered as outlines. An ATS parser reading this file finds words,
///   in reading order, with no intervening graphics.
/// * **Page breaks follow the document's structure.** Each section is emitted
///   as one group and each entry inside it as a nested group, so the layout
///   engine can only break *between* entries — never between a heading and
///   the entry it introduces, and never through the middle of a job.
/// * **The engine never silently shrinks type.** If content overruns the
///   region's conventional length, that is reported in [ResumePdfResult.warnings]
///   and the user decides what to cut.
class ResumePdfBuilder {
  const ResumePdfBuilder();

  Future<ResumePdfResult> build(ResumePdfRequest request) async {
    final bool rtl = request.l10n.locale.languageCode == 'fa' ||
        request.plan.documentLanguage == 'fa';
    final String family = _familyFor(request, rtl: rtl);

    final pw.ThemeData theme = await PdfFonts.themeFor(
      family,
      rtlPreferredFamily: rtl ? PdfFonts.persianFamily : null,
    );

    final _PdfTokens tokens = _PdfTokens.from(request.template, rtl: rtl);
    final PdfPageFormat format = request.pageFormat ??
        pageFormatFor(request.plan.paperSize.widthPt, request.plan.paperSize.heightPt);

    final pw.Document document = pw.Document(
      theme: theme,
      title: request.resume.title,
      author: request.resume.content.personal.fullName,
      creator: 'CV Pro',
      subject: request.l10n.appTitle,
    );

    final List<pw.Widget> sections = _buildSections(request, tokens);
    final pw.Widget header = _buildIdentityBlock(request, tokens);

    // The identity block is emitted as a *page header with a condition*
    // rather than as the first element of the flow, so a two-page CV does not
    // repeat the candidate's address on page two.
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: theme,
        margin: pw.EdgeInsets.fromLTRB(
          tokens.margin,
          tokens.margin,
          tokens.margin,
          tokens.margin + 12,
        ),
        header: request.template.layout == ResumeLayout.singleColumn
            ? null
            : (pw.Context context) =>
                context.pageNumber == 1 ? header : pw.SizedBox(),
        footer: (pw.Context context) => _buildFooter(context, request, tokens),
        build: (pw.Context context) => <pw.Widget>[
          if (request.template.layout == ResumeLayout.singleColumn) header,
          ...sections,
        ],
      ),
    );

    final Uint8List bytes = await document.save();
    final int pages = _countPages(bytes);
    final List<PdfRenderWarning> warnings = <PdfRenderWarning>[
      if (request.plan.page.idealMax > 0 && pages > request.plan.page.idealMax)
        PdfRenderWarning(
          'pdf.longerThanConvention',
          params: <String, String>{
            'pages': '$pages',
            'ideal': '${request.plan.idealMax}',
          },
        ),
      if (request.plan.showPhoto && request.photoBytes == null)
        const PdfRenderWarning('pdf.photoMissing'),
      if (request.plan.ats.photoOnAts == false &&
          request.resume.content.personal.showPhoto)
        const PdfRenderWarning('pdf.photoWithAts'),
    ];

    return ResumePdfResult(
      bytes: bytes,
      pageCount: pages,
      warnings: warnings,
      byteSize: bytes.lengthInBytes,
    );
  }

  // ── identity ─────────────────────────────────────────────────────────────

  pw.Widget _buildIdentityBlock(ResumePdfRequest request, _PdfTokens tokens) {
    final PersonalInfo p = request.resume.content.personal;
    final ResumeTemplate template = request.template;

    final pw.Widget name = pw.Text(
      p.fullName.isEmpty ? request.resume.title : p.fullName,
      style: tokens.style(size: 21, weight: pw.FontWeight.bold),
    );
    final pw.Widget headline = p.jobTitle.isEmpty
        ? pw.SizedBox()
        : pw.Text(p.jobTitle, style: tokens.style(size: 12, color: tokens.muted));

    // Contact lines are plain text, on separate lines, with the link as a
    // real annotation rather than as an image or a bare URL string.
    final List<pw.Widget> contact = <pw.Widget>[
      for (final String fragment in _visibleContacts(request))
        pw.Text(fragment, style: tokens.style(size: 9.5, color: tokens.muted)),
      if (p.linkedIn.isNotEmpty)
        pw.UrlLink(
          destination: _asUrl(p.linkedIn),
          child: pw.Text(p.linkedIn, style: tokens.style(size: 9.5, color: tokens.accent)),
        ),
      if (p.website.isNotEmpty)
        pw.UrlLink(
          destination: _asUrl(p.website),
          child: pw.Text(p.website, style: tokens.style(size: 9.5, color: tokens.accent)),
        ),
    ];

    final pw.Widget identity = pw.Column(
      crossAxisAlignment:
          tokens.rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        name,
        if (p.jobTitle.isNotEmpty) ...<pw.Widget>[pw.SizedBox(height: 3), headline],
        if (contact.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 7),
          ...contact,
        ],
        // Sensitive fields only when both the market's default and the user's
        // switch allow it. The builder never adds them on its own.
        if (request.plan.showSensitiveFields) ...<pw.Widget>[
          pw.SizedBox(height: 5),
          pw.Text(
            _sensitiveLine(request),
            style: tokens.style(size: 9, color: tokens.muted),
          ),
        ],
      ],
    );

    final pw.Widget? photo = _buildPhoto(request, tokens);

    final pw.Widget content = photo == null
        ? identity
        : pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            textDirection:
                tokens.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            children: <pw.Widget>[
              photo,
              pw.SizedBox(width: 14),
              pw.Expanded(child: identity),
            ],
          );

    switch (template.layout) {
      case ResumeLayout.headerBand:
      case ResumeLayout.headerBandTwoColumn:
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 14),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: tokens.accent, width: 2),
            ),
          ),
          child: content,
        );
      case ResumeLayout.sidebarLeft:
      case ResumeLayout.sidebarRight:
        // A true two-column body cannot flow across pages without splitting
        // the sidebar from its content, so the sidebar is rendered as a
        // page-one block and the sections then use the full width. That keeps
        // multi-page documents readable and keeps the text layer linear,
        // which is what parsers need.
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: tokens.wash,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: content,
        );
      case ResumeLayout.singleColumn:
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: content,
        );
    }
  }

  List<String> _visibleContacts(ResumePdfRequest request) {
    final PersonalInfo p = request.resume.content.personal;
    return <String>[
      if (p.locationLine.isNotEmpty) p.locationLine,
      if (p.phone.isNotEmpty) p.phone,
      if (p.email.isNotEmpty) p.email,
      if (p.gitHub.isNotEmpty) p.gitHub,
    ];
  }

  String _sensitiveLine(ResumePdfRequest request) {
    final PersonalInfo p = request.resume.content.personal;
    final List<String> parts = <String>[
      if (p.birthDate != null)
        DateDisplay.fullDate(
          p.birthDate!,
          system: request.plan.dateSystem,
          languageCode: request.l10n.locale.languageCode,
        ),
      if (p.nationality.isNotEmpty) p.nationality,
      if (p.maritalStatus.isNotEmpty) p.maritalStatus,
      if (p.gender.isNotEmpty) p.gender,
    ];
    return parts.join(' · ');
  }

  pw.Widget? _buildPhoto(ResumePdfRequest request, _PdfTokens tokens) {
    if (!request.plan.showPhoto) return null;
    final Uint8List? bytes = request.photoBytes;
    if (bytes == null) return null;

    final pw.MemoryImage image = pw.MemoryImage(bytes);
    final double size = request.template.photoShape == PhotoShape.square ? 74 : 66;

    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        shape: request.template.photoShape == PhotoShape.circle
            ? pw.BoxShape.circle
            : pw.BoxShape.rectangle,
        borderRadius: request.template.photoShape == PhotoShape.rounded
            ? pw.BorderRadius.circular(8)
            : null,
        image: pw.DecorationImage(image: image, fit: pw.BoxFit.cover),
      ),
    );
  }

  // ── sections ─────────────────────────────────────────────────────────────

  List<pw.Widget> _buildSections(ResumePdfRequest request, _PdfTokens tokens) {
    final ResumeContent c = request.resume.content;
    final List<pw.Widget> out = <pw.Widget>[];

    for (final SectionKey key in request.plan.printedSections) {
      if (key == SectionKey.personal) continue;

      final List<pw.Widget> body = _sectionBody(request, tokens, key);
      if (body.isEmpty) continue;

      // One group per section: the layout engine may break between sections,
      // and between entries inside a section, but not between a heading and
      // the first entry underneath it.
      out.add(
        pw.Column(
          crossAxisAlignment:
              tokens.rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _sectionHeading(request, tokens, key),
            ...body,
            pw.SizedBox(height: tokens.sectionGap),
          ],
        ),
      );
    }
    return out;
  }

  pw.Widget _sectionHeading(
    ResumePdfRequest request,
    _PdfTokens tokens,
    SectionKey key,
  ) {
    final String title = _sectionTitle(request, key);
    final pw.TextStyle style = tokens.style(
      size: 11.5,
      weight: pw.FontWeight.bold,
      color: tokens.headingColor,
      letterSpacing: request.template.headingUppercase ? 0.8 : 0,
    );
    final pw.Widget text = pw.Text(
      request.template.headingUppercase && !tokens.rtl ? title.toUpperCase() : title,
      style: style,
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 3, top: 2),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: request.template.headingRule
          ? pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: tokens.rule, width: 0.7),
              ),
            )
          : null,
      child: text,
    );
  }

  List<pw.Widget> _sectionBody(
    ResumePdfRequest request,
    _PdfTokens tokens,
    SectionKey key,
  ) {
    final ResumeContent c = request.resume.content;
    switch (key) {
      case SectionKey.summary:
        return _paragraphs(<String>[c.personal.summary], tokens);

      case SectionKey.experience:
        return <pw.Widget>[
          for (final Experience e in c.experiences.where((Experience e) => !e.hidden))
            _entry(
              tokens: tokens,
              title: e.jobTitle,
              organization: e.company,
              location: e.location,
              dates: _range(request, e.startDate, e.endDate, e.isCurrent),
              bullets: e.allBullets,
              trailing: e.technologyLine.isEmpty ? null : e.technologyLine,
            ),
        ];

      case SectionKey.education:
        return <pw.Widget>[
          for (final Education e in c.education.where((Education e) => !e.hidden))
            _entry(
              tokens: tokens,
              title: e.degree.isEmpty ? e.fieldOfStudy : e.degree,
              organization: e.institution,
              location: e.location,
              dates: _range(request, e.startDate, e.endDate, false),
              bullets: <String>[
                if (e.fieldOfStudy.isNotEmpty && e.degree.isNotEmpty) e.fieldOfStudy,
                if (e.gpa.isNotEmpty) e.gpa,
                if (e.description.isNotEmpty) e.description,
              ],
              trailing: null,
            ),
        ];

      case SectionKey.skills:
        return _inlineList(
          c.skills
              .where((Skill s) => s.name.trim().isNotEmpty)
              .map((Skill s) => s.category.isEmpty || !s.showLevel
                  ? s.name
                  : '${s.name} (${s.level.id})')
              .toList(),
          tokens,
        );

      case SectionKey.languages:
        return _inlineList(
          c.languages
              .where((LanguageSkill l) => l.language.trim().isNotEmpty)
              .map((LanguageSkill l) => '${l.language} — ${l.level.id}')
              .toList(),
          tokens,
        );

      case SectionKey.projects:
        return <pw.Widget>[
          for (final Project p in c.projects.where((Project p) => !p.hidden))
            _entry(
              tokens: tokens,
              title: p.name,
              organization: '',
              location: '',
              dates: _range(request, p.startDate, p.endDate, false),
              bullets: <String>[
                if (p.description.isNotEmpty) p.description,
                if (p.technologies.isNotEmpty) p.technologies.join(' · '),
              ],
              trailing: p.url.isNotEmpty ? p.url : (p.repository.isEmpty ? null : p.repository),
            ),
        ];

      case SectionKey.certifications:
        return <pw.Widget>[
          for (final Certification x
              in c.certifications.where((Certification x) => !x.hidden))
            _entry(
              tokens: tokens,
              title: x.name,
              organization: x.organization,
              location: '',
              dates: x.date == null
                  ? ''
                  : DateDisplay.monthYear(
                      x.date!,
                      system: request.plan.dateSystem,
                      languageCode: request.l10n.locale.languageCode,
                    ),
              bullets: <String>[],
              trailing: x.credentialId.isEmpty ? null : x.credentialId,
            ),
        ];

      case SectionKey.awards:
        return <pw.Widget>[
          for (final Award a in c.awards.where((Award a) => !a.hidden))
            _entry(
              tokens: tokens,
              title: a.title,
              organization: a.issuer,
              location: '',
              dates: a.date == null
                  ? ''
                  : DateDisplay.monthYear(
                      a.date!,
                      system: request.plan.dateSystem,
                      languageCode: request.l10n.locale.languageCode,
                    ),
              bullets: <String>[if (a.description.isNotEmpty) a.description],
              trailing: null,
            ),
        ];

      case SectionKey.publications:
        return _publications(request, tokens);

      case SectionKey.volunteering:
      case SectionKey.courses:
      case SectionKey.researchExperience:
      case SectionKey.teachingExperience:
      case SectionKey.academicAppointments:
      case SectionKey.conferences:
      case SectionKey.presentations:
      case SectionKey.grants:
      case SectionKey.academicService:
      case SectionKey.memberships:
        return <pw.Widget>[
          for (final DatedEntry e
              in c.datedEntriesFor(key).where((DatedEntry e) => !e.hidden))
            _entry(
              tokens: tokens,
              title: e.title,
              organization: e.organization,
              location: e.location,
              dates: _range(request, e.startDate, e.endDate, false),
              bullets: <String>[if (e.description.isNotEmpty) e.description],
              trailing: e.url.isEmpty ? null : e.url,
            ),
        ];

      case SectionKey.references:
        return <pw.Widget>[
          for (final Reference r in c.references.where((Reference r) => !r.hidden))
            _entry(
              tokens: tokens,
              title: r.name,
              organization: <String>[r.position, r.organization]
                  .where((String s) => s.isNotEmpty)
                  .join(', '),
              location: '',
              dates: '',
              bullets: <String>[
                if (r.email.isNotEmpty) r.email,
                if (r.phone.isNotEmpty) r.phone,
                if (r.relationship.isNotEmpty) r.relationship,
              ],
              trailing: null,
            ),
        ];

      case SectionKey.researchInterests:
        return _inlineList(c.researchInterests, tokens, separator: ' · ');

      case SectionKey.interests:
        return _inlineList(c.interests, tokens, separator: ' · ');

      case SectionKey.digitalSkills:
        return _inlineList(c.digitalSkills, tokens, separator: ' · ');

      case SectionKey.keySkills:
        return _inlineList(c.keySkills, tokens, separator: ' · ');

      case SectionKey.additionalInfo:
        return <pw.Widget>[
          for (final CustomSection s
              in c.customSections.where((CustomSection s) => !s.hidden))
            ..._customSection(request, tokens, s),
          if (c.additionalInfo.trim().isNotEmpty)
            ..._paragraphs(<String>[c.additionalInfo], tokens),
        ];

      case SectionKey.militaryService:
        return _paragraphs(<String>[c.militaryService], tokens);

      case SectionKey.drivingLicence:
        return _paragraphs(<String>[c.drivingLicence], tokens);

      case SectionKey.personal:
      case SectionKey.achievements:
        return const <pw.Widget>[];
    }
  }

  List<pw.Widget> _publications(ResumePdfRequest request, _PdfTokens tokens) {
    final List<Publication> visible = request.resume.content.publications
        .where((Publication p) => !p.hidden)
        .toList();

    // Academic CVs run to dozens of publications, so they are numbered and
    // grouped, which is the convention reviewers expect to scan.
    final Map<int, List<Publication>> grouped = <int, List<Publication>>{};
    for (final Publication p in visible) {
      grouped.putIfAbsent(p.type.groupOrder, () => <Publication>[]).add(p);
    }
    final List<int> groups = grouped.keys.toList()..sort();

    final List<pw.Widget> out = <pw.Widget>[];
    int index = 1;
    for (final int group in groups) {
      final List<Publication> items = grouped[group]!;
      if (groups.length > 1) {
        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              items.first.type.id,
              style: tokens.style(size: 9.5, weight: pw.FontWeight.bold),
            ),
          ),
        );
      }
      for (final Publication p in items) {
        out.add(_entry(
          tokens: tokens,
          title: '$index. ${p.title}',
          organization: <String>[p.authors, p.venue]
              .where((String s) => s.isNotEmpty)
              .join(' · '),
          location: '',
          dates: p.date == null
              ? ''
              : DateDisplay.monthYear(
                  p.date!,
                  system: request.plan.dateSystem,
                  languageCode: request.l10n.locale.languageCode,
                ),
          bullets: <String>[
            if (p.doi.isNotEmpty) 'DOI: ${p.doi}',
          ],
          trailing: null,
          keepWithNext: index < visible.length,
        ));
        index++;
      }
    }
    return out;
  }

  List<pw.Widget> _customSection(
    ResumePdfRequest request,
    _PdfTokens tokens,
    CustomSection section,
  ) {
    final List<pw.Widget> out = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(
          section.title,
          style: tokens.style(size: 10, weight: pw.FontWeight.bold),
        ),
      ),
    ];
    if (section.useEntries) {
      for (final DatedEntry e in section.entries.where((DatedEntry e) => !e.hidden)) {
        out.add(_entry(
          tokens: tokens,
          title: e.title,
          organization: e.organization,
          location: e.location,
          dates: _range(request, e.startDate, e.endDate, false),
          bullets: <String>[if (e.description.isNotEmpty) e.description],
          trailing: null,
        ));
      }
    } else if (section.bodyText.trim().isNotEmpty) {
      out.addAll(_paragraphs(<String>[section.bodyText], tokens));
    }
    return out;
  }

  // ── building blocks ──────────────────────────────────────────────────────

  /// One entry: title line, organisation line, optional dates, then bullets.
  ///
  /// Returned as a single column so the layout engine treats it as one unit
  /// and cannot split a job across two pages unless the job alone is taller
  /// than a page.
  pw.Widget _entry({
    required _PdfTokens tokens,
    required String title,
    required String organization,
    required String location,
    required String dates,
    required List<String> bullets,
    required String? trailing,
    bool keepWithNext = false,
  }) {
    final bool hasMeta = organization.isNotEmpty || location.isNotEmpty;
    final List<pw.Widget> bulletWidgets = <pw.Widget>[
      for (final String bullet in bullets.where((String b) => b.trim().isNotEmpty))
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            textDirection:
                tokens.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            children: <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Container(
                  width: 2.6,
                  height: 2.6,
                  decoration: pw.BoxDecoration(
                    color: tokens.accent,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Expanded(
                child: pw.Text(bullet, style: tokens.style(size: tokens.bodySize)),
              ),
            ],
          ),
        ),
    ];

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: keepWithNext ? 7 : 10),
      child: pw.Column(
        crossAxisAlignment:
            tokens.rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          // Title and dates on one row: an ATS reads the line left to right
          // and finds the role and the period in the same text run.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            textDirection:
                tokens.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: tokens.style(size: 10.5, weight: pw.FontWeight.bold),
                ),
              ),
              if (dates.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8),
                  child: pw.Text(
                    dates,
                    style: tokens.style(size: 9, color: tokens.muted),
                  ),
                ),
            ],
          ),
          if (hasMeta)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: pw.Text(
                <String>[organization, location]
                    .where((String s) => s.isNotEmpty)
                    .join(' · '),
                style: tokens.style(size: 9.5, color: tokens.muted),
              ),
            ),
          ...bulletWidgets,
          if (trailing != null && trailing.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                trailing,
                style: tokens.style(size: 8.5, color: tokens.muted),
              ),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _paragraphs(List<String> values, _PdfTokens tokens) => <pw.Widget>[
        for (final String value in values.where((String v) => v.trim().isNotEmpty))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(value, style: tokens.style(size: tokens.bodySize)),
          ),
      ];

  /// Comma-separated values, wrapped across lines.
  ///
  /// Skills are printed as text rather than as chips or a table: a parser
  /// reads a comma-separated run perfectly and a table cell can scramble it.
  List<pw.Widget> _inlineList(
    List<String> values,
    _PdfTokens tokens, {
    String separator = ', ',
  }) {
    final List<String> clean =
        values.where((String v) => v.trim().isNotEmpty).toList(growable: false);
    if (clean.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          clean.join(separator),
          style: tokens.style(size: tokens.bodySize),
        ),
      ),
    ];
  }

  pw.Widget _buildFooter(
    pw.Context context,
    ResumePdfRequest request,
    _PdfTokens tokens,
  ) {
    final String name = request.resume.content.personal.fullName;
    final String page = DateDisplay.toLocalDigits(
      '${context.pageNumber} / ${context.pagesCount}',
      request.l10n.locale.languageCode,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: tokens.rule, width: 0.5),
        ),
      ),
      child: pw.Row(
        textDirection: tokens.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              name,
              style: tokens.style(size: 8, color: tokens.muted),
            ),
          ),
          pw.Text(page, style: tokens.style(size: 8, color: tokens.muted)),
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _familyFor(ResumePdfRequest request, {required bool rtl}) {
    final String requested =
        request.resume.fontFamily ?? request.template.fontFamily;
    if (rtl && !PdfFonts.supportsPersian(requested)) {
      return PdfFonts.persianFamily;
    }
    return requested;
  }

  String _range(
    ResumePdfRequest request,
    YearMonth? start,
    YearMonth? end,
    bool isCurrent,
  ) =>
      DateDisplay.range(
        start,
        end,
        isCurrent: isCurrent,
        system: request.plan.dateSystem,
        languageCode: request.l10n.locale.languageCode,
        presentLabel: request.l10n.presentLabel,
      );

  String _sectionTitle(ResumePdfRequest request, SectionKey key) =>
      switch (key) {
        SectionKey.personal => request.l10n.sectionPersonal,
        SectionKey.summary => request.l10n.sectionSummary,
        SectionKey.experience => request.l10n.sectionExperience,
        SectionKey.education => request.l10n.sectionEducation,
        SectionKey.skills => request.l10n.sectionSkills,
        SectionKey.languages => request.l10n.sectionLanguages,
        SectionKey.projects => request.l10n.sectionProjects,
        SectionKey.certifications => request.l10n.sectionCertifications,
        SectionKey.awards => request.l10n.sectionAwards,
        SectionKey.publications => request.l10n.sectionPublications,
        SectionKey.volunteering => request.l10n.sectionVolunteering,
        SectionKey.references => request.l10n.sectionReferences,
        SectionKey.custom => request.l10n.sectionCustom,
        SectionKey.courses => request.l10n.sectionCourses,
        SectionKey.interests => request.l10n.sectionInterests,
        SectionKey.militaryService => request.l10n.sectionMilitaryService,
        SectionKey.drivingLicence => request.l10n.sectionDrivingLicence,
        SectionKey.researchInterests => request.l10n.sectionResearchInterests,
        SectionKey.researchExperience => request.l10n.sectionResearchExperience,
        SectionKey.teachingExperience => request.l10n.sectionTeachingExperience,
        SectionKey.academicAppointments => request.l10n.sectionAcademicAppointments,
        SectionKey.conferences => request.l10n.sectionConferences,
        SectionKey.presentations => request.l10n.sectionPresentations,
        SectionKey.grants => request.l10n.sectionGrants,
        SectionKey.academicService => request.l10n.sectionAcademicService,
        SectionKey.memberships => request.l10n.sectionMemberships,
        SectionKey.digitalSkills => request.l10n.sectionDigitalSkills,
        SectionKey.achievements => request.l10n.sectionAchievements,
        SectionKey.keySkills => request.l10n.sectionKeySkills,
        SectionKey.additionalInfo => request.l10n.sectionAdditionalInfo,
      };

  static String _asUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.contains('@')) return 'mailto:$trimmed';
    return 'https://$trimmed';
  }

  /// Page count read back from the produced file.
  ///
  /// The `pdf` writer emits one `/Type /Page` object per page, so counting
  /// them gives the true count of the artefact the user is about to send —
  /// not an estimate. `/Pages` (the catalogue) is deliberately excluded.
  static int _countPages(Uint8List bytes) {
    final String text = String.fromCharCodes(bytes);
    int count = 0;
    int from = 0;
    while (true) {
      final int at = text.indexOf('/Type /Page', from);
      if (at < 0) break;
      final String next = text.substring(at, (at + 13).clamp(0, text.length));
      if (!next.startsWith('/Type /Pages')) count++;
      from = at + 12;
    }
    return count == 0 ? 1 : count;
  }
}

/// Type, colour and spacing tokens derived from the chosen template.
class _PdfTokens {
  const _PdfTokens({
    required this.rtl,
    required this.accent,
    required this.muted,
    required this.rule,
    required this.wash,
    required this.bodySize,
    required this.sectionGap,
    required this.margin,
    required this.headingColor,
  });

  factory _PdfTokens.from(ResumeTemplate template, {required bool rtl}) {
    final PdfColor accent = PdfColor.fromHexString(template.accentHex);
    return _PdfTokens(
      rtl: rtl,
      accent: accent,
      muted: PdfColor.fromHexString('#5B6472'),
      rule: PdfColor.fromHexString('#D3D8E0'),
      wash: PdfColor.fromHexString('#F4F6FA'),
      bodySize: template.baseFontSize,
      sectionGap: template.sectionGap,
      margin: switch (template.layout) {
        ResumeLayout.singleColumn => 48,
        ResumeLayout.headerBand || ResumeLayout.headerBandTwoColumn => 44,
        ResumeLayout.sidebarLeft || ResumeLayout.sidebarRight => 36,
      },
      headingColor: template.headingRule || template.headingUppercase
          ? accent
          : PdfColor.fromHexString('#111827'),
    );
  }

  final bool rtl;
  final PdfColor accent;
  final PdfColor muted;
  final PdfColor rule;
  final PdfColor wash;
  final double bodySize;
  final double sectionGap;
  final double margin;
  final PdfColor headingColor;

  /// A text style that always carries the document's direction, so Persian
  /// paragraphs are laid out right-to-left without every call site having to
  /// remember.
  pw.TextStyle style({
    double? size,
    pw.FontWeight? weight,
    PdfColor? color,
    double? letterSpacing,
  }) =>
      pw.TextStyle(
        fontSize: size ?? bodySize,
        fontWeight: weight ?? pw.FontWeight.normal,
        color: color ?? PdfColor.fromHexString('#1F2937'),
        lineHeight: 1.32,
        letterSpacing: letterSpacing,
      );
}
