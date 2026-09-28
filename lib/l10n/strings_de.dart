import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// German strings.
///
/// Section names follow the vocabulary German recruiters expect on a
/// Lebenslauf (Berufserfahrung, Ausbildung, Kenntnisse) so that a CV built
/// here reads natively to a German hiring manager.
class StringsDe extends AppLocalizations {
  const StringsDe();

  @override
  Locale get locale => const Locale('de');

  @override
  String get languageName => 'Deutsch';

  @override
  String get languageCodeShort => 'DE';

  // ── App-wide ─────────────────────────────────────────────────────────────
  @override
  String get appName => 'CV Pro';
  @override
  String get appTagline => 'Internationaler Lebenslauf-Editor';
  @override
  String get continueLabel => 'Weiter';
  @override
  String get back => 'Zurück';
  @override
  String get next => 'Weiter';
  @override
  String get skip => 'Überspringen';
  @override
  String get done => 'Fertig';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get save => 'Speichern';
  @override
  String get saveAndClose => 'Speichern & schließen';
  @override
  String get delete => 'Löschen';
  @override
  String get duplicate => 'Duplizieren';
  @override
  String get rename => 'Umbenennen';
  @override
  String get edit => 'Bearbeiten';
  @override
  String get close => 'Schließen';
  @override
  String get retry => 'Erneut versuchen';
  @override
  String get search => 'Suchen';
  @override
  String get clear => 'Leeren';
  @override
  String get confirm => 'Bestätigen';
  @override
  String get optional => 'Optional';
  @override
  String get required => 'Pflichtfeld';
  @override
  String get none => 'Keine';
  @override
  String get all => 'Alle';
  @override
  String get yes => 'Ja';
  @override
  String get no => 'Nein';
  @override
  String get loading => 'Wird geladen…';
  @override
  String get somethingWentWrong => 'Etwas ist schiefgelaufen';
  @override
  String get tryAgain => 'Erneut versuchen';

  // ── Onboarding ───────────────────────────────────────────────────────────
  @override
  String get onboardingWelcomeTitle => 'Ein Lebenslauf, der überall ankommt';
  @override
  String get onboardingWelcomeBody =>
      'Erstelle professionelle Lebensläufe für Iran, Europa, Deutschland, Großbritannien, die USA und internationale Arbeitgeber – ATS-tauglich und sauber gesetzt.';
  @override
  String get onboardingPrivateTitle => 'Datenschutz von Anfang an';
  @override
  String get onboardingPrivateBody =>
      'Dein Lebenslauf verlässt dein Gerät nur, wenn du ihn teilst. Kein Konto, keine Anmeldung, kein Tracking.';
  @override
  String get onboardingOfflineTitle => 'Funktioniert ohne Internet';
  @override
  String get onboardingOfflineBody =>
      'Schreiben, analysieren und als hochwertiges PDF exportieren – vollständig offline. Das Internet wird nur für den optionalen KI-Assistenten genutzt.';
  @override
  String get onboardingGetStarted => 'Loslegen';
  @override
  String get onboardingChooseLanguage => 'Sprache wählen';
  @override
  String get onboardingWhatCreating => 'Was erstellst du?';
  @override
  String get onboardingWhatCreatingHint =>
      'Das bestimmt, welche Abschnitte vorgeschlagen werden und wie der Lebenslauf aufgebaut ist.';
  @override
  String get onboardingWhereApplying => 'Wo bewirbst du dich?';
  @override
  String get industryLabel => 'Branche';
  @override
  String get onboardingWhereApplyingHint =>
      'Jeder Markt hat eigene Konventionen für Foto, persönliche Angaben, Länge und Papierformat. Du kannst das später ändern.';
  @override
  String get onboardingAllSetTitle => 'Alles bereit';
  @override
  String get onboardingAllSetBody =>
      'Erstelle jetzt deinen ersten Lebenslauf oder beginne mit einem wiederverwendbaren Masterprofil.';
  @override
  String get onboardingCreateFirstCv => 'Ersten Lebenslauf erstellen';

  // ── Dashboard ────────────────────────────────────────────────────────────
  @override
  String get dashboardTitle => 'Übersicht';
  @override
  String get myCvs => 'Meine Lebensläufe';
  @override
  String get masterProfile => 'Masterprofil';
  @override
  String get masterProfileSubtitle =>
      'Daten einmal hinterlegen und in jedem Lebenslauf nutzen';
  @override
  String get cvAnalyzer => 'Lebenslauf-Analyse';
  @override
  String get cvAnalyzerSubtitle => 'Struktur, ATS und Sprache bewerten';
  @override
  String get jobAnalyzer => 'Stellenabgleich';
  @override
  String get jobAnalyzerSubtitle => 'Lebenslauf mit einer Stellenanzeige vergleichen';
  @override
  String get templates => 'Vorlagen';
  @override
  String get templatesSubtitle => 'Zwölf Layouts für jeden Markt';
  @override
  String get recentDocuments => 'Letzte Dokumente';
  @override
  String get createNewCv => 'Neuen Lebenslauf erstellen';
  @override
  String get noCvsTitle => 'Noch kein Lebenslauf';
  @override
  String get noCvsBody =>
      'Erstelle deinen ersten Lebenslauf – dauert etwa fünf Minuten und funktioniert vollständig offline.';
  @override
  String get noRecentDocuments => 'Exportierte PDFs erscheinen hier';
  @override
  String get updatedOn => 'Aktualisiert';
  @override
  String get createdOn => 'Erstellt';
  @override
  String get documentsCount => 'Dokumente';
  @override
  String get cvsCount => 'Lebensläufe';

  // ── CV types ─────────────────────────────────────────────────────────────
  @override
  String get cvTypeJobResume => 'Bewerbungs-Lebenslauf';
  @override
  String get cvTypeProfessionalCv => 'Professioneller CV';
  @override
  String get cvTypeAcademicCv => 'Akademischer CV';
  @override
  String get cvTypeStudentResume => 'Studierenden-Lebenslauf';
  @override
  String get cvTypeInternshipResume => 'Praktikums-Lebenslauf';
  @override
  String get cvTypeGraduateResume => 'Absolventen-Lebenslauf';
  @override
  String get cvTypeScholarshipCv => 'Stipendien-CV';
  @override
  String get cvTypeResearchCv => 'Forschungs-CV';
  @override
  String get cvTypePhdCv => 'Promotions-CV';
  @override
  String get cvTypeEuropass => 'CV im Europass-Stil';
  @override
  String get cvTypeAts => 'ATS-Lebenslauf';

  // ── Regions ──────────────────────────────────────────────────────────────
  @override
  String get regionIran => 'Iran';
  @override
  String get regionEurope => 'Europa';
  @override
  String get regionGermany => 'Deutschland';
  @override
  String get regionUnitedKingdom => 'Vereinigtes Königreich';
  @override
  String get regionUnitedStates => 'Vereinigte Staaten';
  @override
  String get regionInternational => 'International';

  // ── Sections ─────────────────────────────────────────────────────────────
  @override
  String get presentLabel => 'heute';

  @override
  String get sectionPersonal => 'Persönliche Daten';
  @override
  String get sectionSummary => 'Profil';
  @override
  String get sectionExperience => 'Berufserfahrung';
  @override
  String get sectionEducation => 'Ausbildung';
  @override
  String get sectionSkills => 'Kenntnisse & Fähigkeiten';
  @override
  String get sectionLanguages => 'Sprachkenntnisse';
  @override
  String get sectionProjects => 'Projekte';
  @override
  String get sectionCertifications => 'Zertifikate';
  @override
  String get sectionAwards => 'Auszeichnungen';
  @override
  String get sectionPublications => 'Publikationen';
  @override
  String get sectionVolunteering => 'Ehrenamt';
  @override
  String get sectionReferences => 'Referenzen';
  @override
  String get sectionCustom => 'Eigener Abschnitt';
  @override
  String get sectionCourses => 'Weiterbildungen';
  @override
  String get sectionInterests => 'Interessen';
  @override
  String get sectionMilitaryService => 'Wehrdienst';
  @override
  String get sectionDrivingLicence => 'Führerschein';
  @override
  String get sectionResearchInterests => 'Forschungsschwerpunkte';
  @override
  String get sectionResearchExperience => 'Forschungserfahrung';
  @override
  String get sectionTeachingExperience => 'Lehrerfahrung';
  @override
  String get sectionConferences => 'Konferenzen';
  @override
  String get sectionGrants => 'Drittmittel';
  @override
  String get sectionAcademicService => 'Akademische Gremienarbeit';
  @override
  String get sectionMemberships => 'Mitgliedschaften';
  @override
  String get sectionAcademicAppointments => 'Akademische Positionen';
  @override
  String get sectionPresentations => 'Vorträge';
  @override
  String get sectionAdditionalInfo => 'Weitere Angaben';
  @override
  String get sectionDigitalSkills => 'Digitale Kompetenzen';
  @override
  String get sectionAchievements => 'Erfolge';
  @override
  String get sectionKeySkills => 'Kernkompetenzen';

  // ── Builder ──────────────────────────────────────────────────────────────
  @override
  String get builderTitle => 'Editor';
  @override
  String get builderSectionOrder => 'Reihenfolge der Abschnitte';
  @override
  String get builderSectionOrderHint =>
      'Zum Sortieren ziehen. Die Reihenfolge gilt für Vorschau und PDF.';
  @override
  String get builderAddSection => 'Abschnitt hinzufügen';
  @override
  String get builderRemoveSection => 'Abschnitt entfernen';
  @override
  String get builderDragToReorder => 'Zum Sortieren ziehen';
  @override
  String get builderUnsavedChanges => 'Nicht gespeicherte Änderungen';
  @override
  String get builderSaved => 'Gespeichert';
  @override
  String get builderAutosaved => 'Automatisch gespeichert';
  @override
  String get builderEmptySectionHint => 'Noch leer – füge den ersten Eintrag hinzu.';
  @override
  String get builderAddItem => 'Eintrag hinzufügen';
  @override
  String get builderPreview => 'Vorschau';
  @override
  String get builderPreviewHint => 'Live-Vorschau aktualisiert sich beim Tippen';
  @override
  String get builderProgress => 'Fortschritt';
  @override
  String get builderCompleteness => 'Vollständigkeit';

  // ── Fields ───────────────────────────────────────────────────────────────
  @override
  String get fieldFirstName => 'Vorname';
  @override
  String get fieldLastName => 'Nachname';
  @override
  String get fieldFullName => 'Vollständiger Name';
  @override
  String get fieldJobTitle => 'Berufsbezeichnung';
  @override
  String get fieldEmail => 'E-Mail';
  @override
  String get fieldPhone => 'Telefon';
  @override
  String get fieldCity => 'Stadt';
  @override
  String get fieldProvince => 'Bundesland / Provinz';
  @override
  String get fieldCountry => 'Land';
  @override
  String get fieldLinkedIn => 'LinkedIn';
  @override
  String get fieldGitHub => 'GitHub';
  @override
  String get fieldWebsite => 'Webseite';
  @override
  String get fieldPhoto => 'Foto';
  @override
  String get fieldSummary => 'Zusammenfassung';
  @override
  String get fieldCompany => 'Unternehmen';
  @override
  String get fieldLocation => 'Ort';
  @override
  String get fieldStartDate => 'Beginn';
  @override
  String get fieldEndDate => 'Ende';
  @override
  String get fieldCurrentlyWorkHere => 'Aktuell hier beschäftigt';
  @override
  String get fieldResponsibilities => 'Aufgaben';
  @override
  String get fieldAchievements => 'Erfolge';
  @override
  String get fieldTechnologies => 'Technologien';
  @override
  String get fieldUniversity => 'Institution';
  @override
  String get fieldDegree => 'Abschluss';
  @override
  String get fieldFieldOfStudy => 'Studienfach';
  @override
  String get fieldGpa => 'Note / GPA';
  @override
  String get fieldDescription => 'Beschreibung';
  @override
  String get fieldSkillName => 'Kenntnis';
  @override
  String get fieldSkillLevel => 'Niveau';
  @override
  String get fieldLanguage => 'Sprache';
  @override
  String get fieldLanguageLevel => 'Niveau';
  @override
  String get fieldProjectName => 'Projektname';
  @override
  String get fieldProjectUrl => 'Projekt-URL';
  @override
  String get fieldProjectRepo => 'Repository';
  @override
  String get fieldCertificateName => 'Zertifikat';
  @override
  String get fieldOrganization => 'Ausstellende Stelle';
  @override
  String get fieldDate => 'Datum';
  @override
  String get fieldCredentialId => 'Zertifikats-ID';
  @override
  String get fieldVerificationUrl => 'Prüf-URL';
  @override
  String get fieldTitle => 'Titel';
  @override
  String get fieldSubtitle => 'Untertitel';
  @override
  String get fieldPublisher => 'Zeitschrift / Verlag';
  @override
  String get fieldMonth => 'Monat';
  @override
  String get fieldYear => 'Jahr';
  @override
  String get fieldCategory => 'Kategorie';
  @override
  String get fieldRelationship => 'Verhältnis';
  @override
  String get fieldAuthors => 'Autoren';
  @override
  String get fieldDoi => 'DOI';
  @override
  String get fieldReferenceName => 'Name';
  @override
  String get fieldReferenceTitle => 'Position';
  @override
  String get fieldReferenceEmail => 'E-Mail';
  @override
  String get fieldReferencePhone => 'Telefon';
  @override
  String get fieldCustomSectionTitle => 'Abschnittstitel';
  @override
  String get fieldNationalId => 'Personalausweisnummer';
  @override
  String get fieldBirthDate => 'Geburtsdatum';
  @override
  String get fieldGender => 'Geschlecht';
  @override
  String get fieldNationality => 'Staatsangehörigkeit';
  @override
  String get fieldMaritalStatus => 'Familienstand';
  @override
  String get sensitiveFieldNotice =>
      'Standardmäßig ausgeblendet. Nur aktivieren, wenn der Zielmarkt es erwartet.';

  // ── Skills & levels ──────────────────────────────────────────────────────
  @override
  String get skillLevelBeginner => 'Grundkenntnisse';
  @override
  String get skillLevelIntermediate => 'Fortgeschritten';
  @override
  String get skillLevelAdvanced => 'Sehr gut';
  @override
  String get skillLevelExpert => 'Experte';
  @override
  String get languageLevelBeginner => 'Grundkenntnisse';
  @override
  String get languageLevelIntermediate => 'Mittelstufe';
  @override
  String get languageLevelAdvanced => 'Fortgeschritten';
  @override
  String get languageLevelFluent => 'Fließend';
  @override
  String get languageLevelNative => 'Muttersprache';

  // ── Preview & export ─────────────────────────────────────────────────────
  @override
  String get previewTitle => 'Vorschau';
  @override
  String get previewZoomIn => 'Vergrößern';
  @override
  String get previewZoomOut => 'Verkleinern';
  @override
  String get previewFitToScreen => 'An Bildschirm anpassen';
  @override
  String get previewPageOf => 'Seite';
  @override
  String get exportTitle => 'Export';
  @override
  String get exportSavePdf => 'PDF speichern';
  @override
  String get exportOpenPdf => 'PDF öffnen';
  @override
  String get exportSharePdf => 'PDF teilen';
  @override
  String get exportPrint => 'Drucken';
  @override
  String get exportJson => 'Als JSON exportieren';
  @override
  String get exportJsonHint =>
      'Ein übertragbares Backup, das du auf einem anderen Gerät importieren kannst. Nichts wird hochgeladen.';
  @override
  String get exportGenerating => 'PDF wird erstellt…';
  @override
  String get exportSuccess => 'PDF gespeichert';
  @override
  String get exportFailed => 'PDF konnte nicht erstellt werden';
  @override
  String get exportPaperSize => 'Papierformat';
  @override
  String get paperA4 => 'A4 (210 × 297 mm)';
  @override
  String get paperLetter => 'US Letter (8,5 × 11 Zoll)';
  @override
  String get pdfWarningPhotoMissing => 'Ihr Foto ist dieser Datei nicht beigefügt.';
  @override
  String get pdfWarningPhotoWithAts => 'Dieser Markt erwartet kein Foto in einem ATS-erfassten Lebenslauf.';
  @override
  String get pdfWarningLongerThanConvention => 'Länger als für diesen Markt üblich.';
  @override
  String get exportFileName => 'Dateiname';
  @override
  String get exportIncludeLinks => 'Klickbare Links einfügen';

  // ── Analyzer ─────────────────────────────────────────────────────────────
  @override
  String get analyzerTitle => 'Lebenslauf-Analyse';
  @override
  String get analyzerRunAnalysis => 'Analyse starten';
  @override
  String get analyzerRerun => 'Erneut analysieren';
  @override
  String get analyzerScoreTitle => 'Qualität';
  @override
  String get analyzerScoreStructure => 'Struktur';
  @override
  String get analyzerScoreContent => 'Inhalt';
  @override
  String get analyzerScoreAts => 'ATS-Kompatibilität';
  @override
  String get analyzerScoreLanguage => 'Sprache';
  @override
  String get analyzerScoreJobMatch => 'Stellenabgleich';
  @override
  String get analyzerRecommendations => 'Empfehlungen';
  @override
  String get analyzerNoIssuesTitle => 'Keine kritischen Probleme gefunden';
  @override
  String get analyzerNoIssuesBody =>
      'Dein Lebenslauf besteht die automatischen Prüfungen. Ein menschlicher Blick lohnt sich trotzdem.';
  @override
  String get analyzerRunFirstTitle => 'Noch keine Analyse';
  @override
  String get analyzerRunFirstBody =>
      'Starte die Offline-Analyse, um Struktur, Inhalt, ATS-Kompatibilität und Sprache zu bewerten.';
  @override
  String get analyzerOfflineBadge => 'Offline-Analyse';
  @override
  String get analyzerOnlineBadge => 'KI-gestützte Analyse';
  @override
  String get analyzerDisclaimer =>
      'Diese Analyse basiert auf üblichen Lebenslauf-Konventionen, ATS-Praktiken, dem gewählten Zielmarkt und den vom Nutzer gemachten Angaben. Sie garantiert weder eine Anstellung noch eine Studienzulassung noch die Annahme durch ein ATS.';
  @override
  String get analyzerKeywordsFound => 'Gefundene Schlagwörter';
  @override
  String get analyzerKeywordsMissing => 'Fehlende Schlagwörter';
  @override
  String get analyzerKeywordHonestyNote =>
      'Ergänze ein Schlagwort nur, wenn du diese Erfahrung tatsächlich hast.';
  @override
  String get analyzerStrengths => 'Stärken';
  @override
  String get analyzerImprovements => 'Verbesserungen';
  @override
  String get priorityCritical => 'Kritisch';
  @override
  String get priorityHigh => 'Hoch';
  @override
  String get priorityMedium => 'Mittel';
  @override
  String get priorityLow => 'Niedrig';

  // ── Job description ──────────────────────────────────────────────────────
  @override
  String get jobDescriptionTitle => 'Stellenbeschreibung';
  @override
  String get jobDescriptionHint => 'Vollständige Anzeige hier einfügen';
  @override
  String get jobAnalyze => 'Analysieren';
  @override
  String get jobPasteDescription => 'Stellenanzeige zum Vergleich einfügen';
  @override
  String get jobRequiredSkills => 'Erforderliche Kenntnisse';
  @override
  String get jobPreferredSkills => 'Wünschenswerte Kenntnisse';
  @override
  String get jobResponsibilities => 'Aufgaben';
  @override
  String get jobQualifications => 'Qualifikationen';
  @override
  String get jobSoftSkills => 'Soziale Kompetenzen';
  @override
  String get jobSeniority => 'Erfahrungsstufe';
  @override
  String get jobNoDescriptionTitle => 'Noch keine Anzeige';
  @override
  String get jobNoDescriptionBody =>
      'Füge eine Stellenanzeige ein – wir extrahieren die Schlagwörter und zeigen, was im Lebenslauf fehlt.';
  @override
  String get jobMatchTitle => 'Übereinstimmung';
  @override
  String get jobMatchSkills => 'Kenntnisse';
  @override
  String get jobMatchExperience => 'Erfahrung';
  @override
  String get jobMatchEducation => 'Ausbildung';
  @override
  String get jobMatchKeywords => 'Schlagwörter';
  @override
  String get jobMatchSeniority => 'Erfahrungsstufe';
  @override
  String get jobMatchDomain => 'Fachbereich';

  // ── AI ───────────────────────────────────────────────────────────────────
  @override
  String get aiTitle => 'KI-Assistent';
  @override
  String get aiAssistant => 'Assistent';
  @override
  String get aiImproveSection => 'Diesen Abschnitt verbessern';
  @override
  String get aiRewrite => 'Umformulieren';
  @override
  String get aiImproveSummary => 'Profil verbessern';
  @override
  String get aiImproveExperience => 'Berufserfahrung verbessern';
  @override
  String get aiWriteAchievement => 'Erfolg formulieren';
  @override
  String get aiFixGrammar => 'Grammatik korrigieren';
  @override
  String get aiSuggest => 'Vorschlagen';
  @override
  String get aiSuggestion => 'Vorschlag';
  @override
  String get aiAccept => 'Übernehmen';
  @override
  String get aiEdit => 'Bearbeiten';
  @override
  String get aiReject => 'Verwerfen';
  @override
  String get aiRegenerate => 'Neu erzeugen';
  @override
  String get aiOriginal => 'Dein Text';
  @override
  String get aiProposed => 'Vorschlag';
  @override
  String get aiNoFabricationNotice =>
      'Der Assistent darf nur umstrukturieren und umformulieren, was du geschrieben hast. Er erfindet niemals Arbeitgeber, Daten, Abschlüsse oder Zahlen.';
  @override
  String get aiNeedsInfoTitle => 'Mehr Details nötig';
  @override
  String get aiQuestionImproveRevenue =>
      'Hat dies Umsatz, Leistung, Effizienz, Engagement oder ein anderes messbares Ergebnis verbessert? Wenn du die Zahl kennst, ergänze sie – sonst lassen wir sie weg.';
  @override
  String get aiConsentTitle => 'Diesen Text an den KI-Anbieter senden?';
  @override
  String get aiConsentBody =>
      'Dies ist eine Online-Funktion. Nur der ausgewählte Text wird an den von dir konfigurierten Anbieter gesendet – niemals dein gesamter Lebenslauf, deine Dateien oder deine Identität.';
  @override
  String get aiConsentAccept => 'Senden und verbessern';
  @override
  String get aiConsentDecline => 'Jetzt nicht';
  @override
  String get aiOfflineNotice =>
      'Du bist offline. KI-Funktionen benötigen eine Verbindung.';
  @override
  String get aiNoKeyTitle => 'Kein KI-Anbieter konfiguriert';
  @override
  String get aiNoKeyBody =>
      'Hinterlege in den Einstellungen einen eigenen API-Schlüssel, um Umformulierung und erweiterte Analyse zu aktivieren. Alles andere funktioniert ohne.';
  @override
  String get aiOpenSettings => 'Einstellungen öffnen';
  @override
  String get aiProvider => 'Anbieter';
  @override
  String get aiApiKey => 'API-Schlüssel';
  @override
  String get aiApiKeyHint => 'Im Gerätespeicher abgelegt';
  @override
  String get aiApiKeyStoredSecurely =>
      'Dein Schlüssel liegt im Android Keystore. Er ist nie in der App enthalten und wird nur an den von dir gewählten Anbieter gesendet.';
  @override
  String get aiModel => 'Modell';
  @override
  String get aiTestConnection => 'Verbindung testen';
  @override
  String get aiConnectionOk => 'Verbindung erfolgreich';
  @override
  String get aiConnectionFailed => 'Verbindung fehlgeschlagen';

  // ── Import ───────────────────────────────────────────────────────────────
  @override
  String get importTitle => 'Bestehenden Lebenslauf importieren';
  @override
  String get importFromPdf => 'PDF-Dokument';
  @override
  String get importFromDocx => 'Word-Dokument (.docx)';
  @override
  String get importFromTxt => 'Reiner Text (.txt)';
  @override
  String get importFromImage => 'Foto oder Scan';
  @override
  String get importReviewTitle => 'Importierte Daten prüfen';
  @override
  String get importReviewBody =>
      'Prüfe, was gefunden wurde, bevor gespeichert wird. Erst nach deiner Bestätigung wird geschrieben.';
  @override
  String get importConfirmImport => 'Diese Daten importieren';
  @override
  String get importNothingFound =>
      'Wir konnten in dieser Datei keine strukturierten Angaben finden.';
  @override
  String get importOcrUnavailableTitle => 'Texterkennung nicht verfügbar';
  @override
  String get importOcrUnavailableBody =>
      'In diesem Build ist keine On-Device-OCR konfiguriert. PDF, DOCX und TXT lassen sich weiterhin importieren, oder du gibst die Daten manuell ein.';
  @override
  String get importParsingTitle => 'Dokument wird gelesen…';
  @override
  String get importParsingBody => 'Dies geschieht vollständig auf deinem Gerät.';

  // ── Network & privacy ────────────────────────────────────────────────────
  @override
  String get statusOffline => 'Offline';
  @override
  String get statusOnline => 'Online';
  @override
  String get statusLocal => 'Auf diesem Gerät';
  @override
  String get offlineBannerTitle => 'Du bist offline';
  @override
  String get offlineBannerBody =>
      'Dein Lebenslauf ist sicher auf deinem Gerät gespeichert.';
  @override
  String get continueOffline => 'Offline fortsetzen';
  @override
  String get privacyTitle => 'Datenschutz & Daten';
  @override
  String get privacyLocalFirst => 'Local-First';
  @override
  String get privacyLocalFirstBody =>
      'Jeder Lebenslauf, jede Vorlagenwahl und jede Analyse liegt in einer Datenbank auf diesem Gerät.';
  @override
  String get privacyNoAccount => 'Kein Konto nötig';
  @override
  String get privacyNoAccountBody =>
      'Du musst dich nie registrieren oder anmelden, um einen Lebenslauf zu erstellen.';
  @override
  String get privacyDeleteAllTitle => 'Alle Daten löschen';
  @override
  String get privacyDeleteAllBody =>
      'Entfernt alle Lebensläufe, das Masterprofil, Exporte und Einstellungen von diesem Gerät. Nicht rückgängig zu machen.';
  @override
  String get privacyDeleteAllConfirm => 'Alles löschen';
  @override
  String get privacyExportData => 'Alle Daten exportieren';
  @override
  String get privacyExportDataBody =>
      'Erstellt eine einzelne JSON-Datei mit allen auf diesem Gerät gespeicherten Daten.';
  @override
  String get privacyDataDeleted => 'Alle Daten gelöscht';

  // ── Settings ─────────────────────────────────────────────────────────────
  @override
  String get settingsTitle => 'Einstellungen';
  @override
  String get settingsAppearance => 'Darstellung';
  @override
  String get settingsTheme => 'Design';
  @override
  String get settingsThemeSystem => 'System';
  @override
  String get settingsThemeLight => 'Hell';
  @override
  String get settingsThemeDark => 'Dunkel';
  @override
  String get settingsLanguage => 'Sprache';
  @override
  String get settingsDefaultRegion => 'Standard-Zielmarkt';
  @override
  String get settingsDefaultPaperSize => 'Standard-Papierformat';
  @override
  String get settingsDateSystem => 'Kalendersystem';
  @override
  String get dateSystemGregorian => 'Gregorianisch';
  @override
  String get dateSystemJalali => 'Persisch (Jalali)';
  @override
  String get settingsDocumentFont => 'Dokumentschrift';
  @override
  String get settingsAbout => 'Über';
  @override
  String get settingsVersion => 'Version';
  @override
  String get settingsLicences => 'Open-Source-Lizenzen';
  @override
  String get settingsLicencesBody =>
      'Die mitgelieferten Schriften stehen unter der SIL Open Font License 1.1.';
  @override
  String get settingsResetOnboarding => 'Einführung erneut anzeigen';

  // ── Templates ────────────────────────────────────────────────────────────
  @override
  String get templatesTitle => 'Vorlagen';
  @override
  String get templatesSearch => 'Vorlagen suchen';
  @override
  String get templatesAllCategories => 'Alle';
  @override
  String get templatesCategoryProfessional => 'Professionell';
  @override
  String get templatesCategoryModern => 'Modern';
  @override
  String get templatesCategoryAcademic => 'Akademisch';
  @override
  String get templatesCategoryRegional => 'Regional';
  @override
  String get templatesCategoryCreative => 'Kreativ';
  @override
  String get templatesAtsSafe => 'ATS-tauglich';
  @override
  String get templatesAtsSafeBody =>
      'Einspaltig, Standardüberschriften, keine Tabellen, keine Grafiken, vollständig extrahierbarer Text.';
  @override
  String get templatesApply => 'Diese Vorlage verwenden';
  @override
  String get templatesApplied => 'Vorlage angewendet';
  @override
  String get templatesPreviewHint => 'Tippen, um mit eigenen Inhalten zu prüfen';
  @override
  String get templatesPremium => 'Premium';
  @override
  String get templatesFree => 'Kostenlos';
  @override
  String get templatesSingleColumn => 'Einspaltig';
  @override
  String get templatesTwoColumn => 'Zweispaltig';
  @override
  String get templatesPageRecommendation => 'Empfohlene Länge';

  // ── Errors ───────────────────────────────────────────────────────────────
  @override
  String get errorCvNotFound => 'Dieser Lebenslauf existiert nicht mehr.';
  @override
  String get errorStorageFailure => 'Speichern in der lokalen Datenbank fehlgeschlagen.';
  @override
  String get errorExportFailure =>
      'Export fehlgeschlagen. Prüfe freien Speicher und versuche es erneut.';
  @override
  String get errorFileTooLarge => 'Diese Datei ist zu groß für den Import.';
  @override
  String get errorUnsupportedFormat => 'Nicht unterstütztes Dateiformat.';
  @override
  String get errorInvalidJsonBackup => 'Diese Backup-Datei ist ungültig.';
  @override
  String get errorNoPdfApp => 'Auf diesem Gerät ist keine PDF-App installiert.';

  // ── Units ────────────────────────────────────────────────────────────────
  @override
  String get unitPage => 'Seite';
  @override
  String get unitPages => 'Seiten';
  @override
  String get unitWords => 'Wörter';
  @override
  String get unitCharacters => 'Zeichen';
  @override
  String get unitBullets => 'Stichpunkte';
  @override
  String get statsQuantified => 'mit Zahl';
}
