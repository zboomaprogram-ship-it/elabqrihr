import 'package:flutter/material.dart';

/// Uses Flutter's directional icons with automatic RTL mirroring.
/// Because Icons.arrow_back, Icons.arrow_forward, Icons.chevron_left, and
/// Icons.chevron_right all declare matchTextDirection: true, Flutter automatically
/// mirrors them when Directionality is TextDirection.rtl.
abstract final class RtlNavigation {
  /// Back icon (points right in RTL, left in LTR).
  static IconData backIcon([BuildContext? context]) => Icons.arrow_back;

  /// Forward icon (points left in RTL, right in LTR).
  static IconData forwardIcon([BuildContext? context]) => Icons.arrow_forward;

  /// Chevron pointing toward the reading start edge (right in RTL, left in LTR).
  static IconData chevronStart([BuildContext? context]) => Icons.chevron_left;

  /// Chevron pointing toward the reading end edge (left in RTL, right in LTR); the
  /// standard list-row trailing affordance.
  static IconData chevronEnd([BuildContext? context]) => Icons.chevron_right;
}
