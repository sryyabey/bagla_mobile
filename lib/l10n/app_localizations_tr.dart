// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get loginTitle => 'Giriş Yap';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get facebookLogin => 'Facebook ile devam et';

  @override
  String get googleLogin => 'Google ile devam et';

  @override
  String get onboardTitle1 => 'Biyolinkini hazırla ve paylaş';

  @override
  String get onboardDesc1 =>
      'Tüm sosyal linklerini tek biyolinkte topla, QR ile paylaş ve her yerde görün.';

  @override
  String get onboardTitle2 => 'Randevu + SMS ile takip et';

  @override
  String get onboardDesc2 =>
      'Randevu al, otomatik SMS gönder; takvimini ve bildirimleri tek ekrandan yönet.';

  @override
  String get onboardTitle3 => 'Biyolink ücretsiz başlar';

  @override
  String get onboardDesc3 =>
      'Ücretsiz başla, biyolinkini anında yayınla; ihtiyaç oldukça paketleri aç.';

  @override
  String get menuTitle => 'Menü';

  @override
  String get myLinks => 'Linklerim';

  @override
  String get themes => 'Temalar';

  @override
  String get profile => 'Profil';

  @override
  String get support => 'Destek';

  @override
  String get exit => 'Çıkış';

  @override
  String get loginButton => 'Giriş';

  @override
  String get dashboardTitle => 'Yönetim Paneli';

  @override
  String get dashboardHeroSubtitle =>
      'Linklerini ve randevularını tek yerden yönet.';

  @override
  String get dashboardDrawerSubtitle =>
      'Randevu ve iletişimlerinizi buradan yönetin';

  @override
  String get dashboardTopClicks => 'Toplam Tıklama';

  @override
  String get dashboardRemainingSms => 'Kalan SMS';

  @override
  String get dashboardBioPage => 'Bio Sayfanız';

  @override
  String get dashboardLinkCopied => 'Bağlantı kopyalandı.';

  @override
  String get dashboardShare => 'Paylaş';

  @override
  String get dashboardDownload => 'İndir';

  @override
  String get dashboardQr => 'QR';

  @override
  String get dashboardPackageInfo => 'Paket Bilgisi';

  @override
  String get dashboardPackageName => 'Paket adı';

  @override
  String get dashboardStart => 'Başlangıç';

  @override
  String get dashboardEnd => 'Bitiş';

  @override
  String get dashboardDailyClicks => 'Günlük Tıklamalar';

  @override
  String get dashboardTopLinks => 'En Çok Tıklanan Linkler';

  @override
  String get dashboardNoClicks => 'Henüz tıklama verisi yok.';

  @override
  String get dashboardNoLinkClicks => 'Henüz bağlantı tıklaması yok.';

  @override
  String get dashboardTodayAppointments => 'Bugünkü Randevular';

  @override
  String dashboardTodayCount(Object count) {
    return '$count bugün';
  }

  @override
  String get dashboardNoAppointmentsData => 'Bugün için randevu verisi yok.';

  @override
  String get dashboardNoAppointments => 'Bugün için randevu bulunamadı.';

  @override
  String dashboardCustomerFallback(Object id) {
    return 'Müşteri #$id';
  }

  @override
  String get dashboardCalendar => 'Takvim';

  @override
  String get dashboardAppointments => 'Randevular';

  @override
  String get dashboardHome => 'Anasayfa';

  @override
  String get dashboardWeeklyCalendar => 'Haftalık Takvim';

  @override
  String get dashboardSmsPacks => 'SMS Paketleri';

  @override
  String get dashboardOrders => 'Siparişler';

  @override
  String get dashboardWorkingHours => 'Çalışma Saatleri';

  @override
  String get dashboardSmsTemplates => 'SMS Şablonları';

  @override
  String get dashboardRetry => 'Tekrar Dene';

  @override
  String get dashboardNoInternet => 'İnternet bağlantınızı kontrol ediniz.';

  @override
  String get dashboardSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String dashboardLoadFailedWithStatus(Object status) {
    return 'Dashboard alınamadı (HTTP $status).';
  }

  @override
  String dashboardLoadFailed(Object error) {
    return 'Dashboard alınamadı: $error';
  }

  @override
  String get dashboardQrTitle => 'Bio Link QR';

  @override
  String dashboardShareFailed(Object error) {
    return 'Paylaşım başarısız: $error';
  }

  @override
  String dashboardQrDownloadFailed(Object error) {
    return 'QR indirilemedi: $error';
  }

  @override
  String get dashboardWhatsAppFailed => 'WhatsApp açılamadı.';

  @override
  String dashboardWhatsAppFailedWithError(Object error) {
    return 'WhatsApp açılamadı: $error';
  }

  @override
  String get dashboardShareBio => 'Bagla bio link';

  @override
  String get dashboardWhatsappSupport => 'WhatsApp Destek';

  @override
  String get appointmentManagement => 'Randevu Yönetimi';

  @override
  String get appointmentSubtitle =>
      'Günlük randevularını takip et, hızlıca yeni randevu oluştur.';

  @override
  String get refresh => 'Yenile';

  @override
  String get today => 'Bugün';

  @override
  String get total => 'Toplam';

  @override
  String get quickAppointment => 'Hızlı Randevu';

  @override
  String get showFilter => 'Filtrele';

  @override
  String get hideFilter => 'Filtreyi Gizle';

  @override
  String get refreshList => 'Listeyi Yenile';

  @override
  String get statusPending => 'Beklemede';

  @override
  String get statusConfirmed => 'Onaylandı';

  @override
  String get statusRescheduled => 'Yeniden Planlandı';

  @override
  String get statusCompleted => 'Tamamlandı';

  @override
  String get statusCancelled => 'İptal';

  @override
  String get statusNoShow => 'Gelmedi';

  @override
  String get customerPreview => 'Müşteri Önizleme';

  @override
  String get recentAppointments => 'Son Randevular';

  @override
  String get reschedule => 'Yeniden Randevu Ver';

  @override
  String get date => 'Tarih';

  @override
  String get timeSelect => 'Saat (seçim yapınız)';

  @override
  String get note => 'Not';

  @override
  String get disableSms => 'SMS gönderme';

  @override
  String get smsOffForAppointment => 'Bu randevu için SMS gönderimi kapalı.';

  @override
  String get disableReminder => 'Hatırlatma Gönderme';

  @override
  String get reminderOffForAppointment =>
      'Bu randevu için hatırlatma bildirimi kapalı.';

  @override
  String get rescheduleAppointment => 'Yeniden Randevu Oluştur';

  @override
  String get editAppointment => 'Randevu Düzenle';

  @override
  String get status => 'Durum';

  @override
  String get save => 'Kaydet';

  @override
  String get quickAppointmentTitle => 'Hızlı Randevu';

  @override
  String get quickAppointmentSubtitle =>
      'Müşteri ve randevu bilgilerini tek ekranda doldurup kaydedin.';

  @override
  String get customerInfo => 'Müşteri Bilgisi';

  @override
  String get appointmentInfo => 'Randevu Bilgisi';

  @override
  String get getAvailableTimes => 'Uygun Saatleri Getir';

  @override
  String get setWorkingHours => 'Çalışma Saatlerinizi Ayarlayın';

  @override
  String get sendSms => 'SMS Gönderme';

  @override
  String get doNotSendSms => 'SMS gönderilmesin';

  @override
  String get sendReminder => 'Hatırlatma Gönderme';

  @override
  String get doNotSendReminder => 'Hatırlatıcı Gönderilmesin';

  @override
  String get googleLoginButton => 'Google ile giriş';

  @override
  String get googleConnecting => 'Bağlanıyor...';

  @override
  String get createAccountEmail => 'E-posta ile hesap oluştur';

  @override
  String get appointmentsTitle => 'Randevular';

  @override
  String get appointmentsEmpty => 'Henüz randevu yok.';

  @override
  String appointmentsFetchFailedStatus(Object status) {
    return 'Randevular alınamadı (HTTP $status).';
  }

  @override
  String appointmentsFetchFailed(Object error) {
    return 'Randevular alınamadı: $error';
  }

  @override
  String get calendarSessionMissing => 'Oturum bulunamadı.';

  @override
  String calendarFetchFailedStatus(Object status) {
    return 'Haftalık takvim alınamadı (HTTP $status).';
  }

  @override
  String calendarFetchFailed(Object error) {
    return 'Haftalık takvim alınamadı: $error';
  }

  @override
  String get calendarUnexpected => 'Beklenmedik yanıt formatı.';

  @override
  String get calendarClosed => 'Kapalı';

  @override
  String get calendarCustomer => 'Müşteri';

  @override
  String get calendarWorkingHoursPrompt =>
      'Lütfen çalışma saatlerinizi ayarlayınız.';

  @override
  String get calendarWorkingHoursButton => 'Çalışma saati ayarla';

  @override
  String get calendarSessionExpired =>
      'Oturum süresi doldu, lütfen tekrar giriş yapın.';

  @override
  String get calendarTitle => 'Haftalık Takvim';

  @override
  String get calendarPrev => 'Önceki';

  @override
  String get calendarToday => 'Bugün';

  @override
  String get calendarNext => 'Sonraki';

  @override
  String get calendarLoading => 'Yükleniyor...';

  @override
  String get calendarNoData => 'Bu hafta için veri yok.';

  @override
  String get dayMonShort => 'Pzt';

  @override
  String get dayTueShort => 'Sal';

  @override
  String get dayWedShort => 'Çar';

  @override
  String get dayThuShort => 'Per';

  @override
  String get dayFriShort => 'Cum';

  @override
  String get daySatShort => 'Cmt';

  @override
  String get daySunShort => 'Paz';

  @override
  String get dayMonFull => 'Pazartesi';

  @override
  String get dayTueFull => 'Salı';

  @override
  String get dayWedFull => 'Çarşamba';

  @override
  String get dayThuFull => 'Perşembe';

  @override
  String get dayFriFull => 'Cuma';

  @override
  String get daySatFull => 'Cumartesi';

  @override
  String get daySunFull => 'Pazar';

  @override
  String get calendarTimeLabel => 'Saat';
}
