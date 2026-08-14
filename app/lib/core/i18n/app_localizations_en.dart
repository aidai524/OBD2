// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OBD2 App';

  @override
  String get garageTab => 'Garage';

  @override
  String get diagnosticsTab => 'Diagnostics';

  @override
  String get liveDataTab => 'Live Data';

  @override
  String get historyTab => 'History';

  @override
  String get settingsTab => 'Settings';

  @override
  String tabPlaceholder(String tabName) {
    return '$tabName content will be added in a later task.';
  }

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get pageUnavailableMessage => 'This page is unavailable.';

  @override
  String get backToGarageAction => 'Back to Garage';

  @override
  String get startingMessage => 'Starting…';

  @override
  String get startupErrorTitle => 'Unable to start';

  @override
  String get startupErrorMessage => 'The app could not finish starting safely.';

  @override
  String get tryAgainAction => 'Try Again';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');
}
