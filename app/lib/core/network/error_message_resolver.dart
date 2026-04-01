import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

String resolveUserErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ApiException) {
    final status = error.statusCode;
    if (status == 404) return l10n.errorNotFound;
    if (status == 400 || status == 422) return l10n.errorInvalidRequest;
    if (status != null && status >= 500) return l10n.errorServiceUnavailable;
  }
  final message = error.toString().toLowerCase();
  if (message.contains('timeout') ||
      message.contains('connection') ||
      message.contains('socket')) {
    return l10n.errorNetwork;
  }
  return l10n.errorGeneric;
}
