import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @facebookLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get facebookLogin;

  /// No description provided for @googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleLogin;

  /// No description provided for @onboardTitle1.
  ///
  /// In en, this message translates to:
  /// **'Build your bio link & share'**
  String get onboardTitle1;

  /// No description provided for @onboardDesc1.
  ///
  /// In en, this message translates to:
  /// **'Launch a single bio link, add socials and share it everywhere with QR or one tap.'**
  String get onboardDesc1;

  /// No description provided for @onboardTitle2.
  ///
  /// In en, this message translates to:
  /// **'Appointments + SMS alerts'**
  String get onboardTitle2;

  /// No description provided for @onboardDesc2.
  ///
  /// In en, this message translates to:
  /// **'Book appointments, send confirmations by SMS, and keep the whole schedule in one place.'**
  String get onboardDesc2;

  /// No description provided for @onboardTitle3.
  ///
  /// In en, this message translates to:
  /// **'Bio link is free to start'**
  String get onboardTitle3;

  /// No description provided for @onboardDesc3.
  ///
  /// In en, this message translates to:
  /// **'Begin free, publish your bio link instantly, upgrade only when you need extras.'**
  String get onboardDesc3;

  /// No description provided for @menuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// No description provided for @myLinks.
  ///
  /// In en, this message translates to:
  /// **'My Links'**
  String get myLinks;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themes;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get exit;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get dashboardTitle;

  /// No description provided for @dashboardHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your links and appointments in one place.'**
  String get dashboardHeroSubtitle;

  /// No description provided for @dashboardDrawerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your appointments and contacts here'**
  String get dashboardDrawerSubtitle;

  /// No description provided for @dashboardTopClicks.
  ///
  /// In en, this message translates to:
  /// **'Total Clicks'**
  String get dashboardTopClicks;

  /// No description provided for @dashboardRemainingSms.
  ///
  /// In en, this message translates to:
  /// **'Remaining SMS'**
  String get dashboardRemainingSms;

  /// No description provided for @dashboardBioPage.
  ///
  /// In en, this message translates to:
  /// **'Your Bio Page'**
  String get dashboardBioPage;

  /// No description provided for @dashboardLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get dashboardLinkCopied;

  /// No description provided for @dashboardShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get dashboardShare;

  /// No description provided for @dashboardDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get dashboardDownload;

  /// No description provided for @dashboardQr.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get dashboardQr;

  /// No description provided for @dashboardPackageInfo.
  ///
  /// In en, this message translates to:
  /// **'Package Info'**
  String get dashboardPackageInfo;

  /// No description provided for @dashboardPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package name'**
  String get dashboardPackageName;

  /// No description provided for @dashboardStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dashboardStart;

  /// No description provided for @dashboardEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get dashboardEnd;

  /// No description provided for @dashboardDailyClicks.
  ///
  /// In en, this message translates to:
  /// **'Daily Clicks'**
  String get dashboardDailyClicks;

  /// No description provided for @dashboardTopLinks.
  ///
  /// In en, this message translates to:
  /// **'Top Clicked Links'**
  String get dashboardTopLinks;

  /// No description provided for @dashboardNoClicks.
  ///
  /// In en, this message translates to:
  /// **'No click data yet.'**
  String get dashboardNoClicks;

  /// No description provided for @dashboardNoLinkClicks.
  ///
  /// In en, this message translates to:
  /// **'No link clicks yet.'**
  String get dashboardNoLinkClicks;

  /// No description provided for @dashboardTodayAppointments.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Appointments'**
  String get dashboardTodayAppointments;

  /// No description provided for @dashboardTodayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} today'**
  String dashboardTodayCount(Object count);

  /// No description provided for @dashboardNoAppointmentsData.
  ///
  /// In en, this message translates to:
  /// **'No appointment data for today.'**
  String get dashboardNoAppointmentsData;

  /// No description provided for @dashboardNoAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments for today.'**
  String get dashboardNoAppointments;

  /// No description provided for @dashboardCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer #{id}'**
  String dashboardCustomerFallback(Object id);

  /// No description provided for @dashboardCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get dashboardCalendar;

  /// No description provided for @dashboardAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get dashboardAppointments;

  /// No description provided for @dashboardHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dashboardHome;

  /// No description provided for @dashboardWeeklyCalendar.
  ///
  /// In en, this message translates to:
  /// **'Weekly Calendar'**
  String get dashboardWeeklyCalendar;

  /// No description provided for @dashboardSmsPacks.
  ///
  /// In en, this message translates to:
  /// **'SMS Packs'**
  String get dashboardSmsPacks;

  /// No description provided for @dashboardOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get dashboardOrders;

  /// No description provided for @dashboardWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get dashboardWorkingHours;

  /// No description provided for @dashboardSmsTemplates.
  ///
  /// In en, this message translates to:
  /// **'SMS Templates'**
  String get dashboardSmsTemplates;

  /// No description provided for @dashboardRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dashboardRetry;

  /// No description provided for @dashboardNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection.'**
  String get dashboardNoInternet;

  /// No description provided for @dashboardSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found. Please log in again.'**
  String get dashboardSessionMissing;

  /// No description provided for @dashboardLoadFailedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Dashboard could not be loaded (HTTP {status}).'**
  String dashboardLoadFailedWithStatus(Object status);

  /// No description provided for @dashboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Dashboard could not be loaded: {error}'**
  String dashboardLoadFailed(Object error);

  /// No description provided for @dashboardQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Bio Link QR'**
  String get dashboardQrTitle;

  /// No description provided for @dashboardShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String dashboardShareFailed(Object error);

  /// No description provided for @dashboardQrDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'QR could not be downloaded: {error}'**
  String dashboardQrDownloadFailed(Object error);

  /// No description provided for @dashboardWhatsAppFailed.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get dashboardWhatsAppFailed;

  /// No description provided for @dashboardWhatsAppFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened: {error}'**
  String dashboardWhatsAppFailedWithError(Object error);

  /// No description provided for @dashboardShareBio.
  ///
  /// In en, this message translates to:
  /// **'Bagla bio link'**
  String get dashboardShareBio;

  /// No description provided for @dashboardWhatsappSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get dashboardWhatsappSupport;

  /// No description provided for @appointmentManagement.
  ///
  /// In en, this message translates to:
  /// **'Appointment Management'**
  String get appointmentManagement;

  /// No description provided for @appointmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your daily appointments and create new ones quickly.'**
  String get appointmentSubtitle;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @quickAppointment.
  ///
  /// In en, this message translates to:
  /// **'Quick Appointment'**
  String get quickAppointment;

  /// No description provided for @showFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get showFilter;

  /// No description provided for @hideFilter.
  ///
  /// In en, this message translates to:
  /// **'Hide filter'**
  String get hideFilter;

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh List'**
  String get refreshList;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get statusRescheduled;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNoShow;

  /// No description provided for @customerPreview.
  ///
  /// In en, this message translates to:
  /// **'Customer Preview'**
  String get customerPreview;

  /// No description provided for @recentAppointments.
  ///
  /// In en, this message translates to:
  /// **'Recent Appointments'**
  String get recentAppointments;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @timeSelect.
  ///
  /// In en, this message translates to:
  /// **'Time (choose)'**
  String get timeSelect;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @disableSms.
  ///
  /// In en, this message translates to:
  /// **'Disable SMS'**
  String get disableSms;

  /// No description provided for @smsOffForAppointment.
  ///
  /// In en, this message translates to:
  /// **'SMS is disabled for this appointment.'**
  String get smsOffForAppointment;

  /// No description provided for @disableReminder.
  ///
  /// In en, this message translates to:
  /// **'Disable Reminder'**
  String get disableReminder;

  /// No description provided for @reminderOffForAppointment.
  ///
  /// In en, this message translates to:
  /// **'Reminder notification is disabled for this appointment.'**
  String get reminderOffForAppointment;

  /// No description provided for @rescheduleAppointment.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Appointment'**
  String get rescheduleAppointment;

  /// No description provided for @editAppointment.
  ///
  /// In en, this message translates to:
  /// **'Edit Appointment'**
  String get editAppointment;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @quickAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Appointment'**
  String get quickAppointmentTitle;

  /// No description provided for @quickAppointmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill customer and appointment info on one screen and save quickly.'**
  String get quickAppointmentSubtitle;

  /// No description provided for @customerInfo.
  ///
  /// In en, this message translates to:
  /// **'Customer Info'**
  String get customerInfo;

  /// No description provided for @appointmentInfo.
  ///
  /// In en, this message translates to:
  /// **'Appointment Info'**
  String get appointmentInfo;

  /// No description provided for @getAvailableTimes.
  ///
  /// In en, this message translates to:
  /// **'Get Available Times'**
  String get getAvailableTimes;

  /// No description provided for @setWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Set Working Hours'**
  String get setWorkingHours;

  /// No description provided for @sendSms.
  ///
  /// In en, this message translates to:
  /// **'Send SMS'**
  String get sendSms;

  /// No description provided for @doNotSendSms.
  ///
  /// In en, this message translates to:
  /// **'Do not send SMS'**
  String get doNotSendSms;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @doNotSendReminder.
  ///
  /// In en, this message translates to:
  /// **'Do not send reminder'**
  String get doNotSendReminder;

  /// No description provided for @googleLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleLoginButton;

  /// No description provided for @googleConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get googleConnecting;

  /// No description provided for @createAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Create account with email'**
  String get createAccountEmail;

  /// No description provided for @appointmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsTitle;

  /// No description provided for @appointmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet.'**
  String get appointmentsEmpty;

  /// No description provided for @appointmentsFetchFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch appointments (HTTP {status}).'**
  String appointmentsFetchFailedStatus(Object status);

  /// No description provided for @appointmentsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch appointments: {error}'**
  String appointmentsFetchFailed(Object error);

  /// No description provided for @calendarSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found.'**
  String get calendarSessionMissing;

  /// No description provided for @calendarFetchFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Weekly calendar could not be loaded (HTTP {status}).'**
  String calendarFetchFailedStatus(Object status);

  /// No description provided for @calendarFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Weekly calendar could not be loaded: {error}'**
  String calendarFetchFailed(Object error);

  /// No description provided for @calendarUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response format.'**
  String get calendarUnexpected;

  /// No description provided for @calendarClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get calendarClosed;

  /// No description provided for @calendarCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get calendarCustomer;

  /// No description provided for @calendarWorkingHoursPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please set your working hours.'**
  String get calendarWorkingHoursPrompt;

  /// No description provided for @calendarWorkingHoursButton.
  ///
  /// In en, this message translates to:
  /// **'Set working hours'**
  String get calendarWorkingHoursButton;

  /// No description provided for @calendarSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please log in again.'**
  String get calendarSessionExpired;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calendarPrev;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calendarNext;

  /// No description provided for @calendarLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get calendarLoading;

  /// No description provided for @calendarNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this week.'**
  String get calendarNoData;

  /// No description provided for @dayMonShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMonShort;

  /// No description provided for @dayTueShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTueShort;

  /// No description provided for @dayWedShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWedShort;

  /// No description provided for @dayThuShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThuShort;

  /// No description provided for @dayFriShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFriShort;

  /// No description provided for @daySatShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySatShort;

  /// No description provided for @daySunShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySunShort;

  /// No description provided for @dayMonFull.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMonFull;

  /// No description provided for @dayTueFull.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTueFull;

  /// No description provided for @dayWedFull.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWedFull;

  /// No description provided for @dayThuFull.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThuFull;

  /// No description provided for @dayFriFull.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFriFull;

  /// No description provided for @daySatFull.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySatFull;

  /// No description provided for @daySunFull.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySunFull;

  /// No description provided for @calendarTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get calendarTimeLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be saved.'**
  String get profileSaveError;

  /// No description provided for @profileSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found. Please log in again.'**
  String get profileSessionMissing;

  /// No description provided for @profileFetchFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be loaded (HTTP {status}).'**
  String profileFetchFailedStatus(Object status);

  /// No description provided for @profileFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be loaded: {error}'**
  String profileFetchFailed(Object error);

  /// No description provided for @profileAvatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Avatar must be smaller than 3MB.'**
  String get profileAvatarTooLarge;

  /// No description provided for @profileAvatarInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Please upload JPG, PNG, or WEBP.'**
  String get profileAvatarInvalidFormat;

  /// No description provided for @profileAvatarPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Avatar could not be prepared: {error}'**
  String profileAvatarPrepareFailed(Object error);

  /// No description provided for @profileUpdateFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Update failed.'**
  String get profileUpdateFailedGeneric;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be updated: {error}'**
  String profileUpdateFailed(Object error);

  /// No description provided for @profilePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'New password and confirmation do not match.'**
  String get profilePasswordMismatch;

  /// No description provided for @profilePasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get profilePasswordUpdated;

  /// No description provided for @profilePasswordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Password could not be updated.'**
  String get profilePasswordUpdateFailed;

  /// No description provided for @profilePasswordUpdateFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Password could not be updated: {error}'**
  String profilePasswordUpdateFailedWithError(Object error);

  /// No description provided for @profileAvatarUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload Avatar'**
  String get profileAvatarUpload;

  /// No description provided for @profileNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Name not set'**
  String get profileNameMissing;

  /// No description provided for @profileUsernamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'@user'**
  String get profileUsernamePlaceholder;

  /// No description provided for @profileInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInfoTitle;

  /// No description provided for @profileFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileFieldName;

  /// No description provided for @profileFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileFieldUsername;

  /// No description provided for @profileFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get profileFieldDescription;

  /// No description provided for @profileFieldFooter.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get profileFieldFooter;

  /// No description provided for @profileSeoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'SEO'**
  String get profileSeoSectionTitle;

  /// No description provided for @profileSeoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Title, description and keywords'**
  String get profileSeoSubtitle;

  /// No description provided for @profileSeoTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileSeoTitleLabel;

  /// No description provided for @profileSeoDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get profileSeoDescriptionLabel;

  /// No description provided for @profileSeoKeywordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get profileSeoKeywordsLabel;

  /// No description provided for @profileSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileSaving;

  /// No description provided for @profilePasswordSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get profilePasswordSectionTitle;

  /// No description provided for @profilePasswordUpdatedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully'**
  String get profilePasswordUpdatedSubtitle;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get profileConfirmPassword;

  /// No description provided for @profileChangePasswordSaving.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get profileChangePasswordSaving;

  /// No description provided for @profileChangePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get profileChangePasswordButton;

  /// No description provided for @profileSmsCount.
  ///
  /// In en, this message translates to:
  /// **'SMS: {count}'**
  String profileSmsCount(Object count);

  /// No description provided for @myLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'My Links'**
  String get myLinksTitle;

  /// No description provided for @myLinksNewLink.
  ///
  /// In en, this message translates to:
  /// **'New Link'**
  String get myLinksNewLink;

  /// No description provided for @myLinksSearchType.
  ///
  /// In en, this message translates to:
  /// **'Search link type'**
  String get myLinksSearchType;

  /// No description provided for @myLinksNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get myLinksNoResults;

  /// No description provided for @myLinksLinkType.
  ///
  /// In en, this message translates to:
  /// **'Link Type'**
  String get myLinksLinkType;

  /// No description provided for @myLinksTypeMissing.
  ///
  /// In en, this message translates to:
  /// **'No link types found, please check settings.'**
  String get myLinksTypeMissing;

  /// No description provided for @myLinksTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get myLinksTitleLabel;

  /// No description provided for @myLinksUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get myLinksUrlLabel;

  /// No description provided for @myLinksColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get myLinksColorLabel;

  /// No description provided for @myLinksColorMissing.
  ///
  /// In en, this message translates to:
  /// **'No color list found.'**
  String get myLinksColorMissing;

  /// No description provided for @myLinksAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add Link'**
  String get myLinksAddLink;

  /// No description provided for @myLinksSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get myLinksSaving;

  /// No description provided for @myLinksCreateRequired.
  ///
  /// In en, this message translates to:
  /// **'Token, type, and color are required to add a link.'**
  String get myLinksCreateRequired;

  /// No description provided for @myLinksCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Link added.'**
  String get myLinksCreateSuccess;

  /// No description provided for @myLinksCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Link could not be added.'**
  String get myLinksCreateFailed;

  /// No description provided for @myLinksCreateError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while adding the link.'**
  String get myLinksCreateError;

  /// No description provided for @myLinksTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'Token not found.'**
  String get myLinksTokenMissing;

  /// No description provided for @myLinksDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Link deleted.'**
  String get myLinksDeleteSuccess;

  /// No description provided for @myLinksDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Link could not be deleted.'**
  String get myLinksDeleteFailed;

  /// No description provided for @myLinksDeleteError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while deleting the link.'**
  String get myLinksDeleteError;

  /// No description provided for @myLinksUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Link updated.'**
  String get myLinksUpdateSuccess;

  /// No description provided for @myLinksUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Link could not be updated.'**
  String get myLinksUpdateFailed;

  /// No description provided for @myLinksUpdateError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while updating the link.'**
  String get myLinksUpdateError;

  /// No description provided for @myLinksEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Link'**
  String get myLinksEditTitle;

  /// No description provided for @myLinksUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get myLinksUpdateButton;

  /// No description provided for @myLinksTypeFallback.
  ///
  /// In en, this message translates to:
  /// **'Type #{id}'**
  String myLinksTypeFallback(Object id);

  /// No description provided for @myLinksColorFallback.
  ///
  /// In en, this message translates to:
  /// **'Color #{id}'**
  String myLinksColorFallback(Object id);

  /// No description provided for @myLinksNoLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get myLinksNoLinksTitle;

  /// No description provided for @myLinksNoLinksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start by adding a new link'**
  String get myLinksNoLinksSubtitle;

  /// No description provided for @myLinksDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing data'**
  String get myLinksDebugTitle;

  /// No description provided for @myLinksDebugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expected lists were not returned from API'**
  String get myLinksDebugSubtitle;

  /// No description provided for @myLinksDebugNoLinks.
  ///
  /// In en, this message translates to:
  /// **'⚠️ No links returned from API.'**
  String get myLinksDebugNoLinks;

  /// No description provided for @myLinksDebugNoTypes.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Link types returned empty.'**
  String get myLinksDebugNoTypes;

  /// No description provided for @myLinksDebugNoColors.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Color list returned empty.'**
  String get myLinksDebugNoColors;

  /// No description provided for @myLinksOrderSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving order...'**
  String get myLinksOrderSaving;

  /// No description provided for @myLinksShowForm.
  ///
  /// In en, this message translates to:
  /// **'Add New Link'**
  String get myLinksShowForm;

  /// No description provided for @myLinksHideForm.
  ///
  /// In en, this message translates to:
  /// **'Hide Form'**
  String get myLinksHideForm;

  /// No description provided for @themesTitle.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themesTitle;

  /// No description provided for @themesSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found. Please log in again.'**
  String get themesSessionMissing;

  /// No description provided for @themesSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get themesSessionExpired;

  /// No description provided for @themesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Themes could not be loaded: {error}'**
  String themesLoadFailed(Object error);

  /// No description provided for @themesPreviewError.
  ///
  /// In en, this message translates to:
  /// **'There was a problem loading the preview.'**
  String get themesPreviewError;

  /// No description provided for @themesSelectTheme.
  ///
  /// In en, this message translates to:
  /// **'Please select a theme.'**
  String get themesSelectTheme;

  /// No description provided for @themesSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Theme updated.'**
  String get themesSaveSuccess;

  /// No description provided for @themesSaveFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Theme could not be updated (HTTP {status}).'**
  String themesSaveFailedStatus(Object status);

  /// No description provided for @themesSaveError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while saving the theme: {error}'**
  String themesSaveError(Object error);

  /// No description provided for @themesRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get themesRefreshTooltip;

  /// No description provided for @themesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get themesRetry;

  /// No description provided for @themesListTitle.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themesListTitle;

  /// No description provided for @themesNoThemes.
  ///
  /// In en, this message translates to:
  /// **'No themes available.'**
  String get themesNoThemes;

  /// No description provided for @themesLivePreview.
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get themesLivePreview;

  /// No description provided for @themesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get themesSaving;

  /// No description provided for @themesSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Theme'**
  String get themesSaveButton;

  /// No description provided for @themesPreviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select a theme to preview.'**
  String get themesPreviewPlaceholder;

  /// No description provided for @themesFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themesFallbackName;

  /// No description provided for @smsPacksTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS Packs'**
  String get smsPacksTitle;

  /// No description provided for @smsPacksSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found. Please log in again.'**
  String get smsPacksSessionMissing;

  /// No description provided for @smsPacksSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please log in again.'**
  String get smsPacksSessionExpired;

  /// No description provided for @smsPacksLoadFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Packages could not be fetched (HTTP {status}).'**
  String smsPacksLoadFailedStatus(Object status);

  /// No description provided for @smsPacksLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Packages could not be fetched: {error}'**
  String smsPacksLoadFailed(Object error);

  /// No description provided for @smsPacksCountriesFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Countries could not be fetched (HTTP {status}).'**
  String smsPacksCountriesFailedStatus(Object status);

  /// No description provided for @smsPacksCountriesFailed.
  ///
  /// In en, this message translates to:
  /// **'Countries could not be fetched: {error}'**
  String smsPacksCountriesFailed(Object error);

  /// No description provided for @smsPacksCitiesFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Cities could not be fetched (HTTP {status}).'**
  String smsPacksCitiesFailedStatus(Object status);

  /// No description provided for @smsPacksCitiesFailed.
  ///
  /// In en, this message translates to:
  /// **'Cities could not be fetched: {error}'**
  String smsPacksCitiesFailed(Object error);

  /// No description provided for @smsPacksDistrictsFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Districts could not be fetched (HTTP {status}).'**
  String smsPacksDistrictsFailedStatus(Object status);

  /// No description provided for @smsPacksDistrictsFailed.
  ///
  /// In en, this message translates to:
  /// **'Districts could not be fetched: {error}'**
  String smsPacksDistrictsFailed(Object error);

  /// No description provided for @smsPacksAddressesFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Addresses could not be fetched (HTTP {status}).'**
  String smsPacksAddressesFailedStatus(Object status);

  /// No description provided for @smsPacksAddressesFailed.
  ///
  /// In en, this message translates to:
  /// **'Addresses could not be fetched: {error}'**
  String smsPacksAddressesFailed(Object error);

  /// No description provided for @smsPacksContentMissing.
  ///
  /// In en, this message translates to:
  /// **'Content not found.'**
  String get smsPacksContentMissing;

  /// No description provided for @smsPacksContract.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get smsPacksContract;

  /// No description provided for @smsPacksClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get smsPacksClose;

  /// No description provided for @smsPacksFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get smsPacksFeatures;

  /// No description provided for @smsPacksPlanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get smsPacksPlanMonthly;

  /// No description provided for @smsPacksPlanAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get smsPacksPlanAnnual;

  /// No description provided for @smsPacksSelectPack.
  ///
  /// In en, this message translates to:
  /// **'Please select a pack.'**
  String get smsPacksSelectPack;

  /// No description provided for @smsPacksSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Please select a country.'**
  String get smsPacksSelectCountry;

  /// No description provided for @smsPacksSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Please select a city.'**
  String get smsPacksSelectCity;

  /// No description provided for @smsPacksSelectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Please select a district.'**
  String get smsPacksSelectDistrict;

  /// No description provided for @smsPacksNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty.'**
  String get smsPacksNameRequired;

  /// No description provided for @smsPacksLastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name cannot be empty.'**
  String get smsPacksLastNameRequired;

  /// No description provided for @smsPacksPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone cannot be empty.'**
  String get smsPacksPhoneRequired;

  /// No description provided for @smsPacksAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address cannot be empty.'**
  String get smsPacksAddressRequired;

  /// No description provided for @smsPacksAgreementRequired.
  ///
  /// In en, this message translates to:
  /// **'You must accept the purchase agreement.'**
  String get smsPacksAgreementRequired;

  /// No description provided for @smsPacksPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order created, redirecting to payment.'**
  String get smsPacksPurchaseSuccess;

  /// No description provided for @smsPacksPurchaseFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed (HTTP {status}).'**
  String smsPacksPurchaseFailedStatus(Object status);

  /// No description provided for @smsPacksPurchaseError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during purchase: {error}'**
  String smsPacksPurchaseError(Object error);

  /// No description provided for @smsPacksPaymentStartInvalid.
  ///
  /// In en, this message translates to:
  /// **'Payment page could not be opened, invalid response.'**
  String get smsPacksPaymentStartInvalid;

  /// No description provided for @smsPacksPaymentStartFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be started (HTTP {status}).'**
  String smsPacksPaymentStartFailedStatus(Object status);

  /// No description provided for @smsPacksPaymentStartError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while starting payment: {error}'**
  String smsPacksPaymentStartError(Object error);

  /// No description provided for @smsPacksPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment is being confirmed, please wait.'**
  String get smsPacksPaymentPending;

  /// No description provided for @smsPacksPaymentVerify403.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be verified (403).'**
  String get smsPacksPaymentVerify403;

  /// No description provided for @smsPacksPaymentVerify404.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found (404).'**
  String get smsPacksPaymentVerify404;

  /// No description provided for @smsPacksPaymentVerifyFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be verified (HTTP {status}).'**
  String smsPacksPaymentVerifyFailedStatus(Object status);

  /// No description provided for @smsPacksPaymentVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be verified: {error}'**
  String smsPacksPaymentVerifyError(Object error);

  /// No description provided for @smsPacksPaymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get smsPacksPaymentSuccessTitle;

  /// No description provided for @smsPacksPaymentPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get smsPacksPaymentPendingTitle;

  /// No description provided for @smsPacksPaymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get smsPacksPaymentFailedTitle;

  /// No description provided for @smsPacksPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get smsPacksPaymentLabel;

  /// No description provided for @smsPacksPackLabel.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get smsPacksPackLabel;

  /// No description provided for @smsPacksTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get smsPacksTypeLabel;

  /// No description provided for @smsPacksAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get smsPacksAmountLabel;

  /// No description provided for @smsPacksInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice No'**
  String get smsPacksInvoiceLabel;

  /// No description provided for @smsPacksPaymentVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment...'**
  String get smsPacksPaymentVerifying;

  /// No description provided for @smsPacksGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get smsPacksGoHome;

  /// No description provided for @smsPacksRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get smsPacksRetry;

  /// No description provided for @smsPacksStepPack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get smsPacksStepPack;

  /// No description provided for @smsPacksStepInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get smsPacksStepInfo;

  /// No description provided for @smsPacksStepSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get smsPacksStepSummary;

  /// No description provided for @smsPacksStepPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get smsPacksStepPayment;

  /// No description provided for @smsPacksNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get smsPacksNext;

  /// No description provided for @smsPacksBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get smsPacksBack;

  /// No description provided for @smsPacksBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get smsPacksBuy;

  /// No description provided for @smsPacksDetails.
  ///
  /// In en, this message translates to:
  /// **'See Features'**
  String get smsPacksDetails;

  /// No description provided for @smsPacksSelectButton.
  ///
  /// In en, this message translates to:
  /// **'Select Pack'**
  String get smsPacksSelectButton;

  /// No description provided for @smsPacksSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get smsPacksSelected;

  /// No description provided for @smsPacksRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get smsPacksRefresh;

  /// No description provided for @smsPacksSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get smsPacksSavedAddresses;

  /// No description provided for @smsPacksNewAddress.
  ///
  /// In en, this message translates to:
  /// **'New Address'**
  String get smsPacksNewAddress;

  /// No description provided for @smsPacksAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Address Title'**
  String get smsPacksAddressTitle;

  /// No description provided for @smsPacksFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get smsPacksFirstName;

  /// No description provided for @smsPacksLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get smsPacksLastName;

  /// No description provided for @smsPacksCompany.
  ///
  /// In en, this message translates to:
  /// **'Company (optional)'**
  String get smsPacksCompany;

  /// No description provided for @smsPacksEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get smsPacksEmail;

  /// No description provided for @smsPacksCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get smsPacksCountry;

  /// No description provided for @smsPacksCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get smsPacksCity;

  /// No description provided for @smsPacksDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get smsPacksDistrict;

  /// No description provided for @smsPacksPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get smsPacksPhone;

  /// No description provided for @smsPacksIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity No (optional)'**
  String get smsPacksIdentity;

  /// No description provided for @smsPacksTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax No (optional)'**
  String get smsPacksTaxNumber;

  /// No description provided for @smsPacksTaxOffice.
  ///
  /// In en, this message translates to:
  /// **'Tax Office'**
  String get smsPacksTaxOffice;

  /// No description provided for @smsPacksAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get smsPacksAddress;

  /// No description provided for @smsPacksPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get smsPacksPaymentMethod;

  /// No description provided for @smsPacksNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get smsPacksNote;

  /// No description provided for @smsPacksNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note or special requests to add to invoice'**
  String get smsPacksNoteHint;

  /// No description provided for @smsPacksAgreementTitle.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the purchase agreement.'**
  String get smsPacksAgreementTitle;

  /// No description provided for @smsPacksSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Summary'**
  String get smsPacksSummaryTitle;

  /// No description provided for @smsPacksSummaryPurchaseInfo.
  ///
  /// In en, this message translates to:
  /// **'Purchase Information'**
  String get smsPacksSummaryPurchaseInfo;

  /// No description provided for @smsPacksSmsLabel.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get smsPacksSmsLabel;

  /// No description provided for @smsPacksCompanyLabel.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get smsPacksCompanyLabel;

  /// No description provided for @smsPacksBuyerLabel.
  ///
  /// In en, this message translates to:
  /// **'Name Surname'**
  String get smsPacksBuyerLabel;

  /// No description provided for @smsPacksEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get smsPacksEmailLabel;

  /// No description provided for @smsPacksCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get smsPacksCountryLabel;

  /// No description provided for @smsPacksCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get smsPacksCityLabel;

  /// No description provided for @smsPacksDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get smsPacksDistrictLabel;

  /// No description provided for @smsPacksPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get smsPacksPhoneLabel;

  /// No description provided for @smsPacksTaxNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax No'**
  String get smsPacksTaxNumberLabel;

  /// No description provided for @smsPacksTaxOfficeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Office'**
  String get smsPacksTaxOfficeLabel;

  /// No description provided for @smsPacksIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity No'**
  String get smsPacksIdentityLabel;

  /// No description provided for @smsPacksAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get smsPacksAddressLabel;

  /// No description provided for @smsPacksNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get smsPacksNoteLabel;

  /// No description provided for @smsPacksSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get smsPacksSubmitLabel;

  /// No description provided for @smsPacksNoPacksForType.
  ///
  /// In en, this message translates to:
  /// **'No packs available for this type.'**
  String get smsPacksNoPacksForType;

  /// No description provided for @smsPacksPriceWithTax.
  ///
  /// In en, this message translates to:
  /// **'Incl. VAT ₺{price}'**
  String smsPacksPriceWithTax(Object price);

  /// No description provided for @smsPacksSmsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} SMS'**
  String smsPacksSmsCount(Object count);

  /// No description provided for @smsPacksSelectPackForSummary.
  ///
  /// In en, this message translates to:
  /// **'Please select a pack to see the summary.'**
  String get smsPacksSelectPackForSummary;

  /// No description provided for @smsPacksRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get smsPacksRefreshing;

  /// No description provided for @smsPacksSavedAddressesLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get smsPacksSavedAddressesLabel;

  /// No description provided for @smsPacksSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get smsPacksSelectAddress;

  /// No description provided for @smsPacksPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get smsPacksPlanLabel;

  /// No description provided for @smsPacksPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get smsPacksPriceLabel;

  /// No description provided for @smsPacksVatIncluded.
  ///
  /// In en, this message translates to:
  /// **'VAT Included'**
  String get smsPacksVatIncluded;

  /// No description provided for @smsPacksSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get smsPacksSubmitting;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @ordersSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please log in again.'**
  String get ordersSessionExpired;

  /// No description provided for @ordersSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session not found. Please log in again.'**
  String get ordersSessionMissing;

  /// No description provided for @ordersFetchFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Orders could not be fetched (HTTP {status}).'**
  String ordersFetchFailedStatus(Object status);

  /// No description provided for @ordersFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Orders could not be fetched: {error}'**
  String ordersFetchFailed(Object error);

  /// No description provided for @ordersRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ordersRetry;

  /// No description provided for @ordersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get ordersEmpty;

  /// No description provided for @ordersFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersFilterAll;

  /// No description provided for @ordersFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ordersFilterPaid;

  /// No description provided for @ordersFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersFilterPending;

  /// No description provided for @ordersFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get ordersFilterFailed;

  /// No description provided for @ordersPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get ordersPrev;

  /// No description provided for @ordersNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get ordersNext;

  /// No description provided for @ordersPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {current} / {total}'**
  String ordersPageLabel(Object current, Object total);

  /// No description provided for @ordersPack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get ordersPack;

  /// No description provided for @ordersType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get ordersType;

  /// No description provided for @ordersStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get ordersStatus;

  /// No description provided for @ordersAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get ordersAmount;

  /// No description provided for @ordersDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ordersDate;

  /// No description provided for @ordersTxnId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get ordersTxnId;

  /// No description provided for @ordersPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get ordersPrice;

  /// No description provided for @ordersTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get ordersTax;

  /// No description provided for @ordersTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ordersTotal;

  /// No description provided for @ordersDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get ordersDetailTitle;

  /// No description provided for @ordersStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ordersStatusPaid;

  /// No description provided for @ordersStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersStatusPending;

  /// No description provided for @ordersStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get ordersStatusFailed;

  /// No description provided for @ordersStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ordersStatusCancelled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
