import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/resume_repository.dart';
import '../../domain/entities/resume.dart';
import '../../domain/entities/resume_content.dart';
import '../../domain/enums/cv_type.dart';
import '../../domain/enums/document_options.dart';
import '../../domain/enums/region_code.dart';
import '../../domain/enums/section_key.dart';

/// The document being edited, held in memory while the builder is open.
///
/// Why a working copy instead of writing every keystroke to the database:
///
/// * the editor stays responsive, because a save is a debounced background
///   write rather than a transaction per character;
/// * an accidental tap is undoable until the screen is left;
/// * the analyser and the preview read the *same* object the user is looking
///   at, so a score never describes a stale draft.
///
/// The database remains the source of truth: [flush] is awaited before the
/// app can be backgrounded, before an export, and before the screen closes.
final AsyncNotifierProviderFamily<ResumeEditor, Resume?, String>
    resumeEditorProvider =
    AsyncNotifierProvider.family<ResumeEditor, Resume?, String>(ResumeEditor.new);

class ResumeEditor extends FamilyAsyncNotifier<Resume?, String> {
  Timer? _debounce;
  bool _dirty = false;

  /// How long typing pauses before the document is written.
  ///
  /// Long enough to coalesce a sentence, short enough that a crash loses at
  /// most a few seconds of work.
  static const Duration _saveDelay = Duration(milliseconds: 700);

  @override
  Future<Resume?> build(String resumeId) async {
    ref.onDispose(() {
      _debounce?.cancel();
      // The screen is going away; whatever is pending must reach the disk.
      if (_dirty) {
        unawaited(_write());
      }
    });

    final Resume? resume =
        await ref.read(resumeRepositoryProvider).findById(resumeId);
    if (resume != null) {
      unawaited(ref.read(resumeRepositoryProvider).touch(resumeId));
    }
    return resume;
  }

  /// `true` while there are unsaved changes, for the "saving…" indicator.
  bool get isDirty => _dirty;

  /// Applies [change] to the working copy and schedules a write.
  void edit(Resume Function(Resume current) change) {
    final Resume? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData<Resume?>(change(current));
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, _write);
  }

  /// Applies [change] to the document's content — the common case, since
  /// almost every edit in the builder is to a section.
  void editContent(ResumeContent Function(ResumeContent current) change) =>
      edit((Resume r) => r.copyWith(content: change(r.content)));

  // ── document settings ────────────────────────────────────────────────────

  void setTitle(String title) => edit((Resume r) => r.copyWith(title: title));

  void setRegion(RegionCode region) => edit((Resume r) => r.copyWith(region: region));

  void setCvType(CvType type) => edit((Resume r) => r.copyWith(cvType: type));

  void setPaperSize(PaperSize size) =>
      edit((Resume r) => r.copyWith(paperSize: size));

  void setTemplate(String templateId) =>
      edit((Resume r) => r.copyWith(templateId: templateId));

  void setAccentColor(String? hex) => edit(
        (Resume r) => hex == null
            ? r.copyWith(clearAccentColor: true)
            : r.copyWith(accentColorHex: hex),
      );

  void setFontFamily(String? family) => edit(
        (Resume r) => family == null
            ? r.copyWith(clearFontFamily: true)
            : r.copyWith(fontFamily: family),
      );

  void setBaseFontSize(double size) =>
      edit((Resume r) => r.copyWith(baseFontSize: size));

  // ── section structure ────────────────────────────────────────────────────

  /// Switches a section on or off.
  ///
  /// Switching a section on appends it to the order rather than inserting it
  /// at a guessed position: the user's chosen order is theirs, and the
  /// analyser will say where convention would put it instead of moving it.
  void toggleSection(SectionKey key) {
    edit((Resume r) {
      final List<SectionKey> current = r.effectiveSections.toList();
      if (current.contains(key)) {
        current.remove(key);
      } else {
        current.add(key);
      }
      final List<SectionKey> hidden = r.hiddenSections.toList()
        ..removeWhere((SectionKey k) => k == key);
      if (!current.contains(key)) hidden.add(key);
      return r.copyWith(sectionOrder: current, hiddenSections: hidden);
    });
  }

  void moveSection(int from, int to) {
    edit((Resume r) {
      final List<SectionKey> order = r.effectiveSections.toList();
      if (from < 0 || from >= order.length) return r;
      final int target = to.clamp(0, order.length - 1);
      final SectionKey moved = order.removeAt(from);
      order.insert(target, moved);
      return r.copyWith(sectionOrder: order);
    });
  }

  // ── persistence ──────────────────────────────────────────────────────────

  /// Writes immediately. Awaited before exporting or leaving the editor.
  Future<void> flush() async {
    _debounce?.cancel();
    await _write();
  }

  Future<void> _write() async {
    final Resume? current = state.valueOrNull;
    if (current == null) return;
    final ResumeRepository repository = ref.read(resumeRepositoryProvider);
    try {
      await repository.save(current);
      _dirty = false;
    } on Object {
      // A failed background write must not lose the user's work: the state
      // stays dirty so the next edit, or the next flush, tries again.
      _dirty = true;
    }
  }

  /// Saves a named version of the current document.
  Future<void> snapshot(String label, {String note = ''}) async {
    final Resume? current = state.valueOrNull;
    if (current == null) return;
    await flush();
    await ref.read(resumeRepositoryProvider).snapshot(current, label: label, note: note);
  }
}
