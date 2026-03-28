import 'package:trendpulse/l10n/app_localizations.dart';

/// Localized display name for a backend source id (`reddit`, `youtube`, `x`, …).
String sourcePlatformLabel(String source, AppLocalizations l10n) {
  switch (source.toLowerCase()) {
    case 'reddit':
      return l10n.platformReddit;
    case 'youtube':
      return l10n.platformYouTube;
    case 'x':
    case 'twitter':
      return l10n.platformX;
    default:
      return source;
  }
}
