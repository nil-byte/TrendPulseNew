import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration ticker = Duration(milliseconds: 800);
  static const Duration pulse = Duration(milliseconds: 1200);
  static const Duration breathe = Duration(milliseconds: 2000);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve gentle = Curves.easeInOut;
}
