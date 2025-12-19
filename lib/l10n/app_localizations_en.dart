// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get facebookLogin => 'Continue with Facebook';

  @override
  String get googleLogin => 'Continue with Google';

  @override
  String get onboardTitle1 => 'Build your bio link & share';

  @override
  String get onboardDesc1 =>
      'Launch a single bio link, add socials and share it everywhere with QR or one tap.';

  @override
  String get onboardTitle2 => 'Appointments + SMS alerts';

  @override
  String get onboardDesc2 =>
      'Book appointments, send confirmations by SMS, and keep the whole schedule in one place.';

  @override
  String get onboardTitle3 => 'Bio link is free to start';

  @override
  String get onboardDesc3 =>
      'Begin free, publish your bio link instantly, upgrade only when you need extras.';

  @override
  String get menuTitle => 'Menu';

  @override
  String get myLinks => 'My Links';

  @override
  String get themes => 'Themes';

  @override
  String get profile => 'Profile';

  @override
  String get support => 'Support';

  @override
  String get exit => 'Logout';

  @override
  String get loginButton => 'Login';

  @override
  String get dashboardTitle => 'Admin Panel';

  @override
  String get dashboardHeroSubtitle =>
      'Manage your links and appointments in one place.';

  @override
  String get dashboardDrawerSubtitle =>
      'Manage your appointments and contacts here';

  @override
  String get dashboardTopClicks => 'Total Clicks';

  @override
  String get dashboardRemainingSms => 'Remaining SMS';

  @override
  String get dashboardBioPage => 'Your Bio Page';

  @override
  String get dashboardLinkCopied => 'Link copied.';

  @override
  String get dashboardShare => 'Share';

  @override
  String get dashboardDownload => 'Download';

  @override
  String get dashboardQr => 'QR';

  @override
  String get dashboardPackageInfo => 'Package Info';

  @override
  String get dashboardPackageName => 'Package name';

  @override
  String get dashboardStart => 'Start';

  @override
  String get dashboardEnd => 'End';

  @override
  String get dashboardDailyClicks => 'Daily Clicks';

  @override
  String get dashboardTopLinks => 'Top Clicked Links';

  @override
  String get dashboardNoClicks => 'No click data yet.';

  @override
  String get dashboardNoLinkClicks => 'No link clicks yet.';

  @override
  String get dashboardTodayAppointments => 'Today\'s Appointments';

  @override
  String dashboardTodayCount(Object count) {
    return '$count today';
  }

  @override
  String get dashboardNoAppointmentsData => 'No appointment data for today.';

  @override
  String get dashboardNoAppointments => 'No appointments for today.';

  @override
  String dashboardCustomerFallback(Object id) {
    return 'Customer #$id';
  }

  @override
  String get dashboardCalendar => 'Calendar';

  @override
  String get dashboardAppointments => 'Appointments';

  @override
  String get dashboardHome => 'Home';

  @override
  String get dashboardWeeklyCalendar => 'Weekly Calendar';

  @override
  String get dashboardSmsPacks => 'SMS Packs';

  @override
  String get dashboardOrders => 'Orders';

  @override
  String get dashboardWorkingHours => 'Working Hours';

  @override
  String get dashboardSmsTemplates => 'SMS Templates';

  @override
  String get dashboardRetry => 'Retry';

  @override
  String get dashboardNoInternet => 'Please check your internet connection.';

  @override
  String get dashboardSessionMissing =>
      'Session not found. Please log in again.';

  @override
  String dashboardLoadFailedWithStatus(Object status) {
    return 'Dashboard could not be loaded (HTTP $status).';
  }

  @override
  String dashboardLoadFailed(Object error) {
    return 'Dashboard could not be loaded: $error';
  }

  @override
  String get dashboardQrTitle => 'Bio Link QR';

  @override
  String dashboardShareFailed(Object error) {
    return 'Share failed: $error';
  }

  @override
  String dashboardQrDownloadFailed(Object error) {
    return 'QR could not be downloaded: $error';
  }

  @override
  String get dashboardWhatsAppFailed => 'WhatsApp could not be opened.';

  @override
  String dashboardWhatsAppFailedWithError(Object error) {
    return 'WhatsApp could not be opened: $error';
  }

  @override
  String get dashboardShareBio => 'Bagla bio link';

  @override
  String get dashboardWhatsappSupport => 'WhatsApp Support';

  @override
  String get appointmentManagement => 'Appointment Management';

  @override
  String get appointmentSubtitle =>
      'Track your daily appointments and create new ones quickly.';

  @override
  String get refresh => 'Refresh';

  @override
  String get today => 'Today';

  @override
  String get total => 'Total';

  @override
  String get quickAppointment => 'Quick Appointment';

  @override
  String get showFilter => 'Filter';

  @override
  String get hideFilter => 'Hide filter';

  @override
  String get refreshList => 'Refresh List';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusRescheduled => 'Rescheduled';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoShow => 'No-show';

  @override
  String get customerPreview => 'Customer Preview';

  @override
  String get recentAppointments => 'Recent Appointments';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get date => 'Date';

  @override
  String get timeSelect => 'Time (choose)';

  @override
  String get note => 'Note';

  @override
  String get disableSms => 'Disable SMS';

  @override
  String get smsOffForAppointment => 'SMS is disabled for this appointment.';

  @override
  String get disableReminder => 'Disable Reminder';

  @override
  String get reminderOffForAppointment =>
      'Reminder notification is disabled for this appointment.';

  @override
  String get rescheduleAppointment => 'Reschedule Appointment';

  @override
  String get editAppointment => 'Edit Appointment';

  @override
  String get status => 'Status';

  @override
  String get save => 'Save';

  @override
  String get quickAppointmentTitle => 'Quick Appointment';

  @override
  String get quickAppointmentSubtitle =>
      'Fill customer and appointment info on one screen and save quickly.';

  @override
  String get customerInfo => 'Customer Info';

  @override
  String get appointmentInfo => 'Appointment Info';

  @override
  String get getAvailableTimes => 'Get Available Times';

  @override
  String get setWorkingHours => 'Set Working Hours';

  @override
  String get sendSms => 'Send SMS';

  @override
  String get doNotSendSms => 'Do not send SMS';

  @override
  String get sendReminder => 'Send Reminder';

  @override
  String get doNotSendReminder => 'Do not send reminder';

  @override
  String get googleLoginButton => 'Sign in with Google';

  @override
  String get googleConnecting => 'Connecting...';

  @override
  String get createAccountEmail => 'Create account with email';

  @override
  String get appointmentsTitle => 'Appointments';

  @override
  String get appointmentsEmpty => 'No appointments yet.';

  @override
  String appointmentsFetchFailedStatus(Object status) {
    return 'Could not fetch appointments (HTTP $status).';
  }

  @override
  String appointmentsFetchFailed(Object error) {
    return 'Could not fetch appointments: $error';
  }

  @override
  String get calendarSessionMissing => 'Session not found.';

  @override
  String calendarFetchFailedStatus(Object status) {
    return 'Weekly calendar could not be loaded (HTTP $status).';
  }

  @override
  String calendarFetchFailed(Object error) {
    return 'Weekly calendar could not be loaded: $error';
  }

  @override
  String get calendarUnexpected => 'Unexpected response format.';

  @override
  String get calendarClosed => 'Closed';

  @override
  String get calendarCustomer => 'Customer';

  @override
  String get calendarWorkingHoursPrompt => 'Please set your working hours.';

  @override
  String get calendarWorkingHoursButton => 'Set working hours';

  @override
  String get calendarSessionExpired => 'Session expired, please log in again.';

  @override
  String get calendarTitle => 'Weekly Calendar';

  @override
  String get calendarPrev => 'Previous';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarLoading => 'Loading...';

  @override
  String get calendarNoData => 'No data for this week.';

  @override
  String get dayMonShort => 'Mon';

  @override
  String get dayTueShort => 'Tue';

  @override
  String get dayWedShort => 'Wed';

  @override
  String get dayThuShort => 'Thu';

  @override
  String get dayFriShort => 'Fri';

  @override
  String get daySatShort => 'Sat';

  @override
  String get daySunShort => 'Sun';

  @override
  String get dayMonFull => 'Monday';

  @override
  String get dayTueFull => 'Tuesday';

  @override
  String get dayWedFull => 'Wednesday';

  @override
  String get dayThuFull => 'Thursday';

  @override
  String get dayFriFull => 'Friday';

  @override
  String get daySatFull => 'Saturday';

  @override
  String get daySunFull => 'Sunday';

  @override
  String get calendarTimeLabel => 'Time';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileSaveError => 'Profile could not be saved.';

  @override
  String get profileSessionMissing => 'Session not found. Please log in again.';

  @override
  String profileFetchFailedStatus(Object status) {
    return 'Profile could not be loaded (HTTP $status).';
  }

  @override
  String profileFetchFailed(Object error) {
    return 'Profile could not be loaded: $error';
  }

  @override
  String get profileAvatarTooLarge => 'Avatar must be smaller than 3MB.';

  @override
  String get profileAvatarInvalidFormat => 'Please upload JPG, PNG, or WEBP.';

  @override
  String profileAvatarPrepareFailed(Object error) {
    return 'Avatar could not be prepared: $error';
  }

  @override
  String get profileUpdateFailedGeneric => 'Update failed.';

  @override
  String profileUpdateFailed(Object error) {
    return 'Profile could not be updated: $error';
  }

  @override
  String get profilePasswordMismatch =>
      'New password and confirmation do not match.';

  @override
  String get profilePasswordUpdated => 'Password updated.';

  @override
  String get profilePasswordUpdateFailed => 'Password could not be updated.';

  @override
  String profilePasswordUpdateFailedWithError(Object error) {
    return 'Password could not be updated: $error';
  }

  @override
  String get profileAvatarUpload => 'Upload Avatar';

  @override
  String get profileNameMissing => 'Name not set';

  @override
  String get profileUsernamePlaceholder => '@user';

  @override
  String get profileInfoTitle => 'Profile Information';

  @override
  String get profileFieldName => 'Name';

  @override
  String get profileFieldUsername => 'Username';

  @override
  String get profileFieldDescription => 'Description';

  @override
  String get profileFieldFooter => 'Footer';

  @override
  String get profileSeoSectionTitle => 'SEO';

  @override
  String get profileSeoSubtitle => 'Title, description and keywords';

  @override
  String get profileSeoTitleLabel => 'Title';

  @override
  String get profileSeoDescriptionLabel => 'Description';

  @override
  String get profileSeoKeywordsLabel => 'Keywords';

  @override
  String get profileSaving => 'Saving...';

  @override
  String get profilePasswordSectionTitle => 'Update Password';

  @override
  String get profilePasswordUpdatedSubtitle => 'Updated successfully';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileConfirmPassword => 'Confirm new password';

  @override
  String get profileChangePasswordSaving => 'Sending...';

  @override
  String get profileChangePasswordButton => 'Update Password';

  @override
  String profileSmsCount(Object count) {
    return 'SMS: $count';
  }

  @override
  String get myLinksTitle => 'My Links';

  @override
  String get myLinksNewLink => 'New Link';

  @override
  String get myLinksSearchType => 'Search link type';

  @override
  String get myLinksNoResults => 'No results found';

  @override
  String get myLinksLinkType => 'Link Type';

  @override
  String get myLinksTypeMissing =>
      'No link types found, please check settings.';

  @override
  String get myLinksTitleLabel => 'Title';

  @override
  String get myLinksUrlLabel => 'URL';

  @override
  String get myLinksColorLabel => 'Color';

  @override
  String get myLinksColorMissing => 'No color list found.';

  @override
  String get myLinksAddLink => 'Add Link';

  @override
  String get myLinksSaving => 'Saving...';

  @override
  String get myLinksCreateRequired =>
      'Token, type, and color are required to add a link.';

  @override
  String get myLinksCreateSuccess => 'Link added.';

  @override
  String get myLinksCreateFailed => 'Link could not be added.';

  @override
  String get myLinksCreateError => 'An error occurred while adding the link.';

  @override
  String get myLinksTokenMissing => 'Token not found.';

  @override
  String get myLinksDeleteSuccess => 'Link deleted.';

  @override
  String get myLinksDeleteFailed => 'Link could not be deleted.';

  @override
  String get myLinksDeleteError => 'An error occurred while deleting the link.';

  @override
  String get myLinksUpdateSuccess => 'Link updated.';

  @override
  String get myLinksUpdateFailed => 'Link could not be updated.';

  @override
  String get myLinksUpdateError => 'An error occurred while updating the link.';

  @override
  String get myLinksEditTitle => 'Edit Link';

  @override
  String get myLinksUpdateButton => 'Update';

  @override
  String myLinksTypeFallback(Object id) {
    return 'Type #$id';
  }

  @override
  String myLinksColorFallback(Object id) {
    return 'Color #$id';
  }

  @override
  String get myLinksNoLinksTitle => 'No links yet';

  @override
  String get myLinksNoLinksSubtitle => 'Start by adding a new link';

  @override
  String get myLinksDebugTitle => 'Missing data';

  @override
  String get myLinksDebugSubtitle =>
      'Expected lists were not returned from API';

  @override
  String get myLinksDebugNoLinks => '⚠️ No links returned from API.';

  @override
  String get myLinksDebugNoTypes => '⚠️ Link types returned empty.';

  @override
  String get myLinksDebugNoColors => '⚠️ Color list returned empty.';

  @override
  String get myLinksOrderSaving => 'Saving order...';

  @override
  String get myLinksShowForm => 'Add New Link';

  @override
  String get myLinksHideForm => 'Hide Form';
}
