import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../domain/templates/resume_template.dart';

/// Draws a schematic of a template's layout.
///
/// The wireframe is generated from the same [ResumeLayout] the PDF engine
/// consumes, so it is structurally honest: a two-column template previews as
/// two columns, and the ATS template previews as a single text column with
/// no decoration. Bars stand in for text lines — no fake lorem ipsum, which
/// would misrepresent line lengths at this scale.
class TemplateWireframe extends StatelessWidget {
  const TemplateWireframe({required this.template, super.key});

  final ResumeTemplate template;

  @override
  Widget build(BuildContext context) {
    final Color accent = _parseHex(template.accentHex);
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    final Widget body = switch (template.layout) {
      ResumeLayout.singleColumn => _SingleColumn(
          accent: accent,
          ink: ink,
          rule: template.headingRule,
        ),
      ResumeLayout.headerBand => _HeaderBand(
          accent: accent,
          ink: ink,
          rule: template.headingRule,
        ),
      ResumeLayout.sidebarLeft => _Sidebar(
          accent: accent,
          ink: ink,
          mirrored: !rtl,
          photo: template.showPhoto,
        ),
      ResumeLayout.sidebarRight => _Sidebar(
          accent: accent,
          ink: ink,
          mirrored: rtl,
          photo: template.showPhoto,
        ),
      ResumeLayout.headerBandTwoColumn => _HeaderBandTwoColumn(
          accent: accent,
          ink: ink,
        ),
    };

    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: ClipRRect(
        borderRadius: AppRadius.xsAll,
        child: ColoredBox(color: Colors.white, child: body),
      ),
    );
  }

  static Color _parseHex(String hex) {
    final String cleaned = hex.replaceAll('#', '');
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF1F3A5F);
    return Color(0xFF000000 | value);
  }
}

/// A run of grey bars standing in for a paragraph.
class _Lines extends StatelessWidget {
  const _Lines({
    required this.color,
    this.count = 3,
    this.thickness = 3,
  });

  final Color color;
  final int count;
  final double thickness;

  /// Widths of the bars as fractions of the available width. Shorter than
  /// [count]: the sequence repeats, which is what makes a run of bars read
  /// as a paragraph rather than a table.
  static const List<double> _widths = <double>[1, 0.94, 0.68];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 4),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: _widths[i % _widths.length],
              child: Container(
                height: thickness,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(thickness / 2),
                ),
              ),
            ),
          ],
        ],
      );
}

class _HeadingBar extends StatelessWidget {
  const _HeadingBar({required this.color, this.width = 0.42, this.rule = true});

  final Color color;
  final double width;
  final bool rule;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: width,
            child: Container(height: 5, color: color),
          ),
          if (rule) ...<Widget>[
            const SizedBox(height: 3),
            Divider(height: 1, thickness: 0.8, color: color.withValues(alpha: 0.35)),
          ],
        ],
      );
}

class _SingleColumn extends StatelessWidget {
  const _SingleColumn({required this.accent, required this.ink, required this.rule});

  final Color accent;
  final Color ink;
  final bool rule;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 8, width: 90, color: ink.withValues(alpha: 0.85)),
            const SizedBox(height: 4),
            Container(height: 3, width: 60, color: ink.withValues(alpha: 0.35)),
            const SizedBox(height: 10),
            for (int s = 0; s < 4; s++) ...<Widget>[
              _HeadingBar(color: accent, rule: rule),
              const SizedBox(height: 5),
              _Lines(color: ink.withValues(alpha: 0.22), count: s == 0 ? 2 : 3),
              const SizedBox(height: 9),
            ],
          ],
        ),
      );
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.accent, required this.ink, required this.rule});

  final Color accent;
  final Color ink;
  final bool rule;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            color: accent.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 9, width: 80, color: ink.withValues(alpha: 0.85)),
                const SizedBox(height: 4),
                Container(height: 3, width: 110, color: ink.withValues(alpha: 0.35)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int s = 0; s < 4; s++) ...<Widget>[
                    _HeadingBar(color: accent, rule: rule),
                    const SizedBox(height: 5),
                    _Lines(color: ink.withValues(alpha: 0.22)),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.accent,
    required this.ink,
    required this.mirrored,
    required this.photo,
  });

  final Color accent;
  final Color ink;
  final bool mirrored;
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final Widget side = Container(
      width: 34,
      color: accent.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (photo) ...<Widget>[
            Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (int i = 0; i < 6; i++) ...<Widget>[
            Container(height: 3, color: ink.withValues(alpha: 0.28)),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );

    final Widget main = Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 7, width: 60, color: ink.withValues(alpha: 0.85)),
            const SizedBox(height: 3),
            Container(height: 3, width: 44, color: accent),
            const SizedBox(height: 10),
            for (int s = 0; s < 4; s++) ...<Widget>[
              _HeadingBar(color: accent, width: 0.5),
              const SizedBox(height: 4),
              _Lines(color: ink.withValues(alpha: 0.22), count: 3),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: mirrored
          ? <Widget>[main, side]
          : <Widget>[side, main],
    );
  }
}

class _HeaderBandTwoColumn extends StatelessWidget {
  const _HeaderBandTwoColumn({required this.accent, required this.ink});

  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 26,
            color: accent.withValues(alpha: 0.16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 7, width: 70, color: ink.withValues(alpha: 0.85)),
                const SizedBox(height: 3),
                Container(height: 3, width: 50, color: ink.withValues(alpha: 0.35)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int s = 0; s < 4; s++) ...<Widget>[
                          _HeadingBar(color: accent, rule: false),
                          const SizedBox(height: 4),
                          _Lines(color: ink.withValues(alpha: 0.22)),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int s = 0; s < 3; s++) ...<Widget>[
                          _HeadingBar(color: accent, width: 0.7, rule: false),
                          const SizedBox(height: 4),
                          _Lines(
                            color: ink.withValues(alpha: 0.22),
                            count: 4,
                            thickness: 2.5,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
