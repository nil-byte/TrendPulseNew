abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double mld = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // Editorial radius: sharp angles with pill exception for chips/badges
  static const double radiusNone = 0;
  static const double radiusXs = 2;
  static const double radiusSm = 4;
  static const double radiusMd = 6;
  static const double radiusPill = 999;

  // Page-level conventions
  static const double pageHorizontal = lg;
  static const double pageSectionGap = xxl;
  static const double sectionInnerGap = lg;
  static const double listItemGap = md;

  // Legacy aliases (deprecated — migrate to radius*)
  @Deprecated('Use radiusNone instead')
  static const double borderRadiusSm = 0;
  @Deprecated('Use radiusXs instead')
  static const double borderRadiusMd = 2;
  @Deprecated('Use radiusSm instead')
  static const double borderRadiusLg = 4;
  @Deprecated('Use radiusMd instead')
  static const double borderRadiusXl = 8;
  @Deprecated('Use radiusPill instead')
  static const double borderRadiusFull = 999;
}
