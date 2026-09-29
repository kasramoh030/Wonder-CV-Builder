import 'package:flutter/widgets.dart';

/// Layout tokens.
///
/// Spacing follows a 4dp base grid. Using named steps instead of raw numbers
/// keeps rhythm consistent across the ~60 screens of the builder.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard horizontal gutter for phone layouts.
  static const EdgeInsets gutter = EdgeInsets.symmetric(horizontal: lg);

  /// Gutter plus vertical breathing room, used by most scroll views.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(lg, lg, lg, xxxl);

  /// Comfortable padding for cards and list tiles.
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Corner radii.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens. Durations are short enough to feel instant on low-end
/// hardware while still reading as intentional.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration page = Duration(milliseconds: 300);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuint;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}
