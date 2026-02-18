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
  String get onboardTitle1 => 'Create your bio link page and stand out';

  @override
  String get onboardDesc1 =>
      'Collect all your links on one page, share your bagla.app bio link, and make it easier to get discovered.';

  @override
  String get onboardTitle2 => 'Track your appointments in one place';

  @override
  String get onboardDesc2 =>
      'Plan client appointments, send reminders automatically, and run your day with clarity and control.';

  @override
  String get onboardTitle3 => 'Quick start for independent professionals';

  @override
  String get onboardDesc3 =>
      'Go live in minutes, unlock more as your business grows, and keep everything in bagla.app.';

  @override
  String get menuTitle => 'Menu';

  @override
  String get myLinks => 'My Links';

  @override
  String get customersTitle => 'My Contacts';

  @override
  String get customersSessionMissing =>
      'Session not found. Please log in again.';

  @override
  String customersLoadFailedStatus(Object status) {
    return 'Customers could not be loaded (HTTP $status).';
  }

  @override
  String customersLoadFailed(Object error) {
    return 'Customers could not be loaded: $error';
  }

  @override
  String get customersSearchHint => 'Search contact (name, phone, email)';

  @override
  String get customersRetry => 'Retry';

  @override
  String get customersEmpty => 'No contacts yet.';

  @override
  String get customersLoadMore => 'Load more';

  @override
  String get customersRefresh => 'Refresh';

  @override
  String get customersAdd => 'Add Contact';

  @override
  String get customersEdit => 'Edit Contact';

  @override
  String get customersDelete => 'Delete';

  @override
  String get customersDeleteConfirmTitle => 'Delete contact?';

  @override
  String get customersDeleteConfirmBody =>
      'Are you sure you want to delete this contact?';

  @override
  String get customersCancel => 'Cancel';

  @override
  String get customersSave => 'Save';

  @override
  String get customersSaving => 'Saving...';

  @override
  String get customersName => 'Full Name';

  @override
  String get customersPhone => 'Phone';

  @override
  String get customersEmail => 'Email';

  @override
  String get customersAddress => 'Address';

  @override
  String get customersNotes => 'Notes';

  @override
  String get customersValidation => 'Full Name and Phone are required.';

  @override
  String get customersCreateSuccess => 'Contact created.';

  @override
  String get customersUpdateSuccess => 'Contact updated.';

  @override
  String customersSaveFailedStatus(Object status) {
    return 'Could not be saved (HTTP $status).';
  }

  @override
  String customersSaveFailed(Object error) {
    return 'Could not be saved: $error';
  }

  @override
  String get customersDeleteSuccess => 'Contact deleted.';

  @override
  String customersDeleteFailedStatus(Object status) {
    return 'Contact could not be deleted (HTTP $status).';
  }

  @override
  String customersDeleteFailed(Object error) {
    return 'Contact could not be deleted: $error';
  }

  @override
  String get customersAppointments => 'Appointments';

  @override
  String get customersNoAppointments => 'No appointments for this contact.';

  @override
  String customersAppointmentsLoadFailedStatus(Object status) {
    return 'Appointments could not be loaded (HTTP $status).';
  }

  @override
  String customersAppointmentsLoadFailed(Object error) {
    return 'Appointments could not be loaded: $error';
  }

  @override
  String get customersCreateAppointment => 'Add Appointment';

  @override
  String get customersAppointmentDate => 'Date';

  @override
  String get customersAppointmentTime => 'Time';

  @override
  String get customersAppointmentNote => 'Note';

  @override
  String get customersFirstAppointment => 'First appointment?';

  @override
  String get customersNoSms => 'Do not send SMS';

  @override
  String get customersNoReminder => 'Do not send reminder';

  @override
  String get customersCreateAppointmentSuccess => 'Appointment created.';

  @override
  String get customersCreateAppointmentFailed =>
      'Appointment could not be created.';

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
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardMenuMain => 'MAIN MENU';

  @override
  String get dashboardMenuManagement => 'MANAGEMENT';

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
  String get dashboardLinkOpenFailed => 'Link could not be opened.';

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
  String get quickAppointment => 'Add Appointment';

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
  String get quickAppointmentTitle => 'Add Appointment';

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
  String appointmentsCountLabel(Object count) {
    return '$count records';
  }

  @override
  String get appointmentsFilterSubtitle =>
      'Filter by customer, date and time range';

  @override
  String get appointmentsPackageRequired =>
      'Please purchase a package for appointment actions.';

  @override
  String get appointmentsSessionMissingLogin =>
      'Session not found. Please log in again.';

  @override
  String appointmentsCountriesFetchFailedStatus(Object status) {
    return 'Countries could not be fetched (HTTP $status).';
  }

  @override
  String appointmentsCountriesFetchFailed(Object error) {
    return 'Countries could not be fetched: $error';
  }

  @override
  String appointmentsStatusesFetchFailedStatus(Object status) {
    return 'Statuses could not be fetched (HTTP $status).';
  }

  @override
  String appointmentsStatusesFetchFailed(Object error) {
    return 'Statuses could not be fetched: $error';
  }

  @override
  String get appointmentsInvalidStartTime => 'Invalid start time. Format HH:MM';

  @override
  String get appointmentsInvalidEndTime => 'Invalid end time. Format HH:MM';

  @override
  String get appointmentsRequiredFields =>
      'Name, lastname, country, phone, date and time are required.';

  @override
  String get appointmentsSelectAvailableTime =>
      'Please select an available time.';

  @override
  String get appointmentsCreateSuccess => 'Appointment created.';

  @override
  String appointmentsCreateFailedStatus(Object status) {
    return 'Appointment could not be created (HTTP $status).';
  }

  @override
  String appointmentsCreateFailed(Object error) {
    return 'Appointment could not be created: $error';
  }

  @override
  String get appointmentsEnterDateFirst => 'Enter a date first.';

  @override
  String appointmentsSlotsFetchFailedStatus(Object status) {
    return 'Time slots could not be fetched (HTTP $status).';
  }

  @override
  String appointmentsSlotsFetchFailed(Object error) {
    return 'Time slots could not be fetched: $error';
  }

  @override
  String get appointmentsDateTimeRequired => 'Date and time are required.';

  @override
  String get appointmentsUpdateSuccess => 'Appointment updated.';

  @override
  String appointmentsUpdateFailedStatus(Object status) {
    return 'Appointment could not be updated (HTTP $status).';
  }

  @override
  String appointmentsUpdateFailed(Object error) {
    return 'Appointment could not be updated: $error';
  }

  @override
  String get appointmentsStatusMissing => 'Appointment status not found.';

  @override
  String get appointmentsRebookSuccess => 'New appointment created.';

  @override
  String get appointmentsInfoMissing => 'Appointment info not found.';

  @override
  String appointmentsInfoFetchFailedStatus(Object status) {
    return 'Information could not be fetched (HTTP $status).';
  }

  @override
  String appointmentsInfoFetchFailed(Object error) {
    return 'Information could not be fetched: $error';
  }

  @override
  String get appointmentsNoRecords => 'No records found.';

  @override
  String get appointmentsClose => 'Close';

  @override
  String get appointmentsClear => 'Clear';

  @override
  String get appointmentsCountry => 'Country';

  @override
  String get appointmentsSelectCountry => 'Select country';

  @override
  String get appointmentsFieldName => 'Name';

  @override
  String get appointmentsFieldNameHint => 'e.g. Alex';

  @override
  String get appointmentsFieldLastName => 'Lastname';

  @override
  String get appointmentsFieldLastNameHint => 'e.g. Brown';

  @override
  String get appointmentsFieldNameFilterHint => 'Customer name';

  @override
  String get appointmentsFieldLastNameFilterHint => 'Customer lastname';

  @override
  String get appointmentsFieldPhone => 'Phone';

  @override
  String get appointmentsFieldPhoneHint => 'e.g. 5554443322';

  @override
  String get appointmentsFieldEmailHint => 'Optional';

  @override
  String get appointmentsStatusSelectHint => 'Select status';

  @override
  String get appointmentsStartDate => 'Start Date';

  @override
  String get appointmentsEndDate => 'End Date';

  @override
  String get appointmentsStartTime => 'Start Time';

  @override
  String get appointmentsEndTime => 'End Time';

  @override
  String get appointmentsBuyPackage => 'Buy Package';

  @override
  String get appointmentsFirstAppointment => 'Is this first appointment?';

  @override
  String get appointmentsReminderDisableTitle => 'Do not send reminder';

  @override
  String get appointmentsSubmitting => 'Submitting...';

  @override
  String get appointmentsCustomerPreviewTooltip => 'Customer preview';

  @override
  String get appointmentsRebookTooltip => 'Rebook appointment';

  @override
  String get appointmentsEditTooltip => 'Edit';

  @override
  String get appointmentsHomeTooltip => 'Home';

  @override
  String get iosSmsPurchaseRestrictionMessage =>
      'SMS package purchasing is not supported in the iOS app due to Apple App Store policies.\nPurchases can be completed on the website.';

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
  String calendarSlotsFilled(Object booked, Object total) {
    return '$booked/$total slots filled';
  }

  @override
  String get calendarAddAppointment => 'Add appointment';

  @override
  String get calendarActionNew => 'New';

  @override
  String get calendarActionEdit => 'Edit';

  @override
  String get calendarFetchAvailableSlots => 'Get available slots';

  @override
  String get calendarDateHint => 'Pick from calendar';

  @override
  String get calendarTimeSlotHint => 'Select slot';

  @override
  String get calendarSelectDateFirst => 'Select a date first.';

  @override
  String get calendarDateTimeRequired => 'Date and time are required.';

  @override
  String get calendarCreateSuccess => 'New appointment created.';

  @override
  String get calendarUpdateSuccess => 'Appointment updated.';

  @override
  String get calendarCreateFailed => 'Appointment could not be created';

  @override
  String get calendarUpdateFailed => 'Appointment could not be updated';

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

  @override
  String get themesTitle => 'Themes';

  @override
  String get themesSessionMissing => 'Session not found. Please log in again.';

  @override
  String get themesSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String themesLoadFailed(Object error) {
    return 'Themes could not be loaded: $error';
  }

  @override
  String get themesPreviewError => 'There was a problem loading the preview.';

  @override
  String get themesSelectTheme => 'Please select a theme.';

  @override
  String get themesSaveSuccess => 'Theme updated.';

  @override
  String themesSaveFailedStatus(Object status) {
    return 'Theme could not be updated (HTTP $status).';
  }

  @override
  String themesSaveError(Object error) {
    return 'An error occurred while saving the theme: $error';
  }

  @override
  String get themesRefreshTooltip => 'Refresh';

  @override
  String get themesRetry => 'Retry';

  @override
  String get themesListTitle => 'Themes';

  @override
  String get themesNoThemes => 'No themes available.';

  @override
  String get themesLivePreview => 'Live Preview';

  @override
  String get themesSaving => 'Saving...';

  @override
  String get themesSaveButton => 'Save Theme';

  @override
  String get themesPreviewPlaceholder => 'Select a theme to preview.';

  @override
  String get themesFallbackName => 'Theme';

  @override
  String get smsPacksTitle => 'SMS Packs';

  @override
  String get smsPacksSessionMissing =>
      'Session not found. Please log in again.';

  @override
  String get smsPacksSessionExpired => 'Session expired, please log in again.';

  @override
  String smsPacksLoadFailedStatus(Object status) {
    return 'Packages could not be fetched (HTTP $status).';
  }

  @override
  String smsPacksLoadFailed(Object error) {
    return 'Packages could not be fetched: $error';
  }

  @override
  String smsPacksCountriesFailedStatus(Object status) {
    return 'Countries could not be fetched (HTTP $status).';
  }

  @override
  String smsPacksCountriesFailed(Object error) {
    return 'Countries could not be fetched: $error';
  }

  @override
  String smsPacksCitiesFailedStatus(Object status) {
    return 'Cities could not be fetched (HTTP $status).';
  }

  @override
  String smsPacksCitiesFailed(Object error) {
    return 'Cities could not be fetched: $error';
  }

  @override
  String smsPacksDistrictsFailedStatus(Object status) {
    return 'Districts could not be fetched (HTTP $status).';
  }

  @override
  String smsPacksDistrictsFailed(Object error) {
    return 'Districts could not be fetched: $error';
  }

  @override
  String smsPacksAddressesFailedStatus(Object status) {
    return 'Addresses could not be fetched (HTTP $status).';
  }

  @override
  String smsPacksAddressesFailed(Object error) {
    return 'Addresses could not be fetched: $error';
  }

  @override
  String get smsPacksContentMissing => 'Content not found.';

  @override
  String get smsPacksContract => 'Agreement';

  @override
  String get smsPacksClose => 'Close';

  @override
  String get smsPacksFeatures => 'Features';

  @override
  String get smsPacksPlanMonthly => 'Monthly';

  @override
  String get smsPacksPlanAnnual => 'Annual';

  @override
  String get smsPacksSelectPack => 'Please select a pack.';

  @override
  String get smsPacksSelectCountry => 'Please select a country.';

  @override
  String get smsPacksSelectCity => 'Please select a city.';

  @override
  String get smsPacksSelectDistrict => 'Please select a district.';

  @override
  String get smsPacksNameRequired => 'Name cannot be empty.';

  @override
  String get smsPacksLastNameRequired => 'Last name cannot be empty.';

  @override
  String get smsPacksPhoneRequired => 'Phone cannot be empty.';

  @override
  String get smsPacksAddressRequired => 'Address cannot be empty.';

  @override
  String get smsPacksAgreementRequired =>
      'You must accept the purchase agreement.';

  @override
  String get smsPacksPurchaseSuccess =>
      'Order created, redirecting to payment.';

  @override
  String smsPacksPurchaseFailedStatus(Object status) {
    return 'Purchase failed (HTTP $status).';
  }

  @override
  String smsPacksPurchaseError(Object error) {
    return 'An error occurred during purchase: $error';
  }

  @override
  String get smsPacksPaymentStartInvalid =>
      'Payment page could not be opened, invalid response.';

  @override
  String smsPacksPaymentStartFailedStatus(Object status) {
    return 'Payment could not be started (HTTP $status).';
  }

  @override
  String smsPacksPaymentStartError(Object error) {
    return 'An error occurred while starting payment: $error';
  }

  @override
  String get smsPacksPaymentPending =>
      'Payment is being confirmed, please wait.';

  @override
  String get smsPacksPaymentVerify403 => 'Payment could not be verified (403).';

  @override
  String get smsPacksPaymentVerify404 => 'Transaction not found (404).';

  @override
  String smsPacksPaymentVerifyFailedStatus(Object status) {
    return 'Payment could not be verified (HTTP $status).';
  }

  @override
  String smsPacksPaymentVerifyError(Object error) {
    return 'Payment could not be verified: $error';
  }

  @override
  String get smsPacksPaymentSuccessTitle => 'Payment Successful';

  @override
  String get smsPacksPaymentPendingTitle => 'Payment Pending';

  @override
  String get smsPacksPaymentFailedTitle => 'Payment Failed';

  @override
  String get smsPacksPaymentLabel => 'Payment';

  @override
  String get smsPacksPackLabel => 'Pack';

  @override
  String get smsPacksTypeLabel => 'Type';

  @override
  String get smsPacksAmountLabel => 'Amount';

  @override
  String get smsPacksInvoiceLabel => 'Invoice No';

  @override
  String get smsPacksPaymentVerifying => 'Verifying payment...';

  @override
  String get smsPacksGoHome => 'Go to home';

  @override
  String get smsPacksRetry => 'Retry';

  @override
  String get smsPacksStepPack => 'Pack';

  @override
  String get smsPacksStepInfo => 'Info';

  @override
  String get smsPacksStepSummary => 'Summary';

  @override
  String get smsPacksStepPayment => 'Payment';

  @override
  String get smsPacksNext => 'Next';

  @override
  String get smsPacksBack => 'Back';

  @override
  String get smsPacksBuy => 'Buy';

  @override
  String get smsPacksDetails => 'See Features';

  @override
  String get smsPacksSelectButton => 'Select Pack';

  @override
  String get smsPacksSelected => 'Selected';

  @override
  String get smsPacksRefresh => 'Refresh';

  @override
  String get smsPacksSavedAddresses => 'Saved Addresses';

  @override
  String get smsPacksNewAddress => 'New Address';

  @override
  String get smsPacksAddressTitle => 'Address Title';

  @override
  String get smsPacksFirstName => 'First Name';

  @override
  String get smsPacksLastName => 'Last Name';

  @override
  String get smsPacksCompany => 'Company (optional)';

  @override
  String get smsPacksEmail => 'Email';

  @override
  String get smsPacksCountry => 'Country';

  @override
  String get smsPacksCity => 'City';

  @override
  String get smsPacksDistrict => 'District';

  @override
  String get smsPacksPhone => 'Phone';

  @override
  String get smsPacksIdentity => 'Identity No (optional)';

  @override
  String get smsPacksTaxNumber => 'Tax No (optional)';

  @override
  String get smsPacksTaxOffice => 'Tax Office';

  @override
  String get smsPacksAddress => 'Address';

  @override
  String get smsPacksPaymentMethod => 'Payment Method';

  @override
  String get smsPacksNote => 'Note';

  @override
  String get smsPacksNoteHint => 'Note or special requests to add to invoice';

  @override
  String get smsPacksAgreementTitle =>
      'I have read and accept the purchase agreement.';

  @override
  String get smsPacksSummaryTitle => 'Purchase Summary';

  @override
  String get smsPacksSummaryPurchaseInfo => 'Purchase Information';

  @override
  String get smsPacksSmsLabel => 'SMS';

  @override
  String get smsPacksCompanyLabel => 'Company';

  @override
  String get smsPacksBuyerLabel => 'Name Surname';

  @override
  String get smsPacksEmailLabel => 'Email';

  @override
  String get smsPacksCountryLabel => 'Country';

  @override
  String get smsPacksCityLabel => 'City';

  @override
  String get smsPacksDistrictLabel => 'District';

  @override
  String get smsPacksPhoneLabel => 'Phone';

  @override
  String get smsPacksTaxNumberLabel => 'Tax No';

  @override
  String get smsPacksTaxOfficeLabel => 'Tax Office';

  @override
  String get smsPacksIdentityLabel => 'Identity No';

  @override
  String get smsPacksAddressLabel => 'Address';

  @override
  String get smsPacksNoteLabel => 'Note';

  @override
  String get smsPacksSubmitLabel => 'Submit';

  @override
  String get smsPacksNoPacksForType => 'No packs available for this type.';

  @override
  String smsPacksPriceWithTax(Object price) {
    return 'Incl. VAT ₺$price';
  }

  @override
  String smsPacksSmsCount(Object count) {
    return '$count SMS';
  }

  @override
  String get smsPacksSelectPackForSummary =>
      'Please select a pack to see the summary.';

  @override
  String get smsPacksRefreshing => 'Refreshing...';

  @override
  String get smsPacksSavedAddressesLabel => 'Saved Addresses';

  @override
  String get smsPacksSelectAddress => 'Select';

  @override
  String get smsPacksPlanLabel => 'Plan';

  @override
  String get smsPacksPriceLabel => 'Price';

  @override
  String get smsPacksVatIncluded => 'VAT Included';

  @override
  String get smsPacksSubmitting => 'Submitting...';

  @override
  String get smsPacksAndroidOnlyTitle => 'Purchases in Android App';

  @override
  String get smsPacksAndroidOnlyMessage =>
      'SMS package purchase steps are available only in the Android app. You can view packages on this device.';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersSessionExpired => 'Session expired, please log in again.';

  @override
  String get ordersSessionMissing => 'Session not found. Please log in again.';

  @override
  String ordersFetchFailedStatus(Object status) {
    return 'Orders could not be fetched (HTTP $status).';
  }

  @override
  String ordersFetchFailed(Object error) {
    return 'Orders could not be fetched: $error';
  }

  @override
  String get ordersRetry => 'Retry';

  @override
  String get ordersEmpty => 'No orders yet.';

  @override
  String get ordersFilterAll => 'All';

  @override
  String get ordersFilterPaid => 'Paid';

  @override
  String get ordersFilterPending => 'Pending';

  @override
  String get ordersFilterFailed => 'Failed';

  @override
  String get ordersPrev => 'Previous';

  @override
  String get ordersNext => 'Next';

  @override
  String ordersPageLabel(Object current, Object total) {
    return 'Page $current / $total';
  }

  @override
  String get ordersPack => 'Pack';

  @override
  String get ordersType => 'Type';

  @override
  String get ordersStatus => 'Status';

  @override
  String get ordersAmount => 'Amount';

  @override
  String get ordersDate => 'Date';

  @override
  String get ordersTxnId => 'Transaction ID';

  @override
  String get ordersPrice => 'Price';

  @override
  String get ordersTax => 'Tax';

  @override
  String get ordersTotal => 'Total';

  @override
  String get ordersDetailTitle => 'Order';

  @override
  String get ordersStatusPaid => 'Paid';

  @override
  String get ordersStatusPending => 'Pending';

  @override
  String get ordersStatusFailed => 'Failed';

  @override
  String get ordersStatusCancelled => 'Cancelled';

  @override
  String get workingPrefsTitle => 'Working Hours';

  @override
  String get workingPrefsSessionMissing =>
      'Session not found. Please log in again.';

  @override
  String workingPrefsLoadFailedStatus(Object status) {
    return 'Working hours could not be loaded (HTTP $status).';
  }

  @override
  String workingPrefsLoadFailed(Object error) {
    return 'Working hours could not be loaded: $error';
  }

  @override
  String get workingPrefsSaveSuccess => 'Saved.';

  @override
  String workingPrefsSaveFailedStatus(Object status) {
    return 'Could not be saved (HTTP $status).';
  }

  @override
  String workingPrefsSaveFailed(Object error) {
    return 'Could not be saved: $error';
  }

  @override
  String get workingPrefsRetry => 'Retry';

  @override
  String get workingPrefsFirstSessionTitle => 'First appointment session count';

  @override
  String get workingPrefsSelect => 'Select';

  @override
  String workingPrefsSessionOption(Object count) {
    return '$count Session';
  }

  @override
  String get workingPrefsDaySubtitle => 'Working status and time ranges';

  @override
  String get workingPrefsWorking => 'Working';

  @override
  String get workingPrefsAddSlot => 'Add time slot';

  @override
  String get workingPrefsStart => 'Start';

  @override
  String get workingPrefsEnd => 'End';

  @override
  String get workingPrefsPeriod => 'Period (minutes)';

  @override
  String get workingPrefsDelete => 'Delete';

  @override
  String get workingPrefsSaving => 'Saving...';

  @override
  String get workingPrefsSave => 'Save';

  @override
  String get workingPrefsHolidaysTitle => 'Holidays';

  @override
  String get workingPrefsHolidaysEmpty => 'No holiday added yet.';

  @override
  String get workingPrefsHolidayAdd => 'Add holiday';

  @override
  String get workingPrefsHolidayStart => 'Start';

  @override
  String get workingPrefsHolidayEnd => 'End';

  @override
  String get workingPrefsHolidayReason => 'Reason (optional)';

  @override
  String get smsTemplatesTitle => 'SMS Templates';

  @override
  String get smsTemplatesSessionMissing =>
      'Session not found. Please log in again.';

  @override
  String smsTemplatesFetchFailedStatus(Object status) {
    return 'Templates could not be loaded (HTTP $status).';
  }

  @override
  String smsTemplatesFetchFailed(Object error) {
    return 'Templates could not be loaded: $error';
  }

  @override
  String get smsTemplatesUpdated => 'SMS templates updated.';

  @override
  String smsTemplatesSaveFailedStatus(Object status) {
    return 'Could not be saved (HTTP $status).';
  }

  @override
  String smsTemplatesSaveFailed(Object error) {
    return 'Could not be saved: $error';
  }

  @override
  String get smsTemplatesSelect => 'Select';

  @override
  String get smsTemplatesNotFound => 'No template found';

  @override
  String get smsTemplatesCustomerTemplates => 'Customer SMS Templates';

  @override
  String smsTemplatesSelectionId(Object id) {
    return 'Selection ID: $id';
  }

  @override
  String get smsTemplatesMain => 'Main Message';

  @override
  String get smsTemplatesReminder => 'Reminder';

  @override
  String get smsTemplatesCancel => 'Cancel';

  @override
  String get smsTemplatesUpdate => 'Update';

  @override
  String get smsTemplatesSave => 'Save';

  @override
  String get smsTemplatesSaving => 'Saving...';

  @override
  String get smsTemplatesRefresh => 'Refresh';

  @override
  String smsTemplatesFallbackTitle(Object id) {
    return 'Template #$id';
  }

  @override
  String get smsTemplatesGuideTitle => 'Template Selection';

  @override
  String get smsTemplatesGuideBody =>
      'Select one SMS template for each category.';

  @override
  String get smsTemplatesGuideHint =>
      'Tap cards to select templates. The selected card is highlighted and reflected in the live preview below.';

  @override
  String get smsTemplatesMainDescription =>
      'Message sent when a new appointment is created.';

  @override
  String get smsTemplatesReminderDescription =>
      'Message sent as a reminder before the appointment.';

  @override
  String get smsTemplatesCancelDescription =>
      'Message sent when an appointment is cancelled.';

  @override
  String get smsTemplatesUpdateDescription =>
      'Message sent when appointment date/time is updated.';

  @override
  String get smsTemplatesPreviewTitle => 'Live Preview';

  @override
  String get smsTemplatesPreviewEmpty =>
      'No template selected for this category yet.';

  @override
  String get smsTemplatesSelected => 'Selected';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportSessionMissing => 'Session not found. Please log in again.';

  @override
  String supportFetchFailedStatus(Object status) {
    return 'Support tickets could not be loaded (HTTP $status).';
  }

  @override
  String supportFetchFailed(Object error) {
    return 'Support tickets could not be loaded: $error';
  }

  @override
  String get supportCreateValidation => 'Title and message are required.';

  @override
  String get supportCreateSuccess => 'Support ticket created.';

  @override
  String supportCreateFailedStatus(Object status) {
    return 'Ticket could not be created (HTTP $status).';
  }

  @override
  String supportCreateFailed(Object error) {
    return 'Ticket could not be created: $error';
  }

  @override
  String get supportRetry => 'Retry';

  @override
  String get supportEmpty => 'You don\'t have any support tickets yet.';

  @override
  String get supportRefresh => 'Refresh';

  @override
  String get supportNewTicket => 'New Support Ticket';

  @override
  String get supportTitleLabel => 'Title';

  @override
  String get supportMessageLabel => 'Your message';

  @override
  String get supportSending => 'Sending...';

  @override
  String get supportSend => 'Send';

  @override
  String get supportTickets => 'Support Tickets';

  @override
  String get supportMessagesCount => 'Messages';

  @override
  String get supportTicketDetail => 'Support Detail';

  @override
  String get supportTicketNotFound => 'Ticket not found.';

  @override
  String get supportMessages => 'Messages';

  @override
  String get supportStatusClosing => 'Closing';

  @override
  String get supportCloseTicket => 'Close Ticket';

  @override
  String supportCreatedAt(Object date) {
    return 'Created: $date';
  }

  @override
  String get supportSenderYou => 'You';

  @override
  String get supportSenderSupport => 'Support';

  @override
  String get supportNoMessages => 'No messages yet.';

  @override
  String get supportReplyPlaceholder => 'Your message';

  @override
  String get supportReplyClosed =>
      'This ticket is closed; you cannot send new messages.';

  @override
  String get supportReplySending => 'Sending...';

  @override
  String get supportReplySend => 'Send Reply';

  @override
  String get supportReplyEmpty => 'Message cannot be empty.';

  @override
  String get supportReplySuccess => 'Reply sent.';

  @override
  String supportReplyFailedStatus(Object status) {
    return 'Reply could not be sent (HTTP $status).';
  }

  @override
  String supportReplyFailed(Object error) {
    return 'Reply could not be sent: $error';
  }

  @override
  String get supportCloseSuccess => 'Ticket closed.';

  @override
  String supportCloseFailedStatus(Object status) {
    return 'Ticket could not be closed (HTTP $status).';
  }

  @override
  String supportCloseFailed(Object error) {
    return 'Ticket could not be closed: $error';
  }

  @override
  String supportMessagesMeta(Object count, Object date) {
    return '$count messages • $date';
  }

  @override
  String get supportStatusOpen => 'Open';

  @override
  String get supportStatusPending => 'Pending';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportPriority => 'Priority';

  @override
  String get profileLanguage => 'App Language';

  @override
  String get profileLanguageTurkish => 'Turkish';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileLanguageSaved => 'Language updated.';
}
