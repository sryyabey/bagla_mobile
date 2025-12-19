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

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileSaved => 'Profil kaydedildi.';

  @override
  String get profileSaveError => 'Profil kaydedilemedi.';

  @override
  String get profileSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String profileFetchFailedStatus(Object status) {
    return 'Profil alınamadı (HTTP $status).';
  }

  @override
  String profileFetchFailed(Object error) {
    return 'Profil alınamadı: $error';
  }

  @override
  String get profileAvatarTooLarge => 'Avatar 3MB\'tan küçük olmalı.';

  @override
  String get profileAvatarInvalidFormat =>
      'Lütfen JPG, PNG veya WEBP yükleyin.';

  @override
  String profileAvatarPrepareFailed(Object error) {
    return 'Avatar hazırlanamadı: $error';
  }

  @override
  String get profileUpdateFailedGeneric => 'Güncelleme başarısız.';

  @override
  String profileUpdateFailed(Object error) {
    return 'Profil güncellenemedi: $error';
  }

  @override
  String get profilePasswordMismatch => 'Yeni parola ve doğrulama eşleşmiyor.';

  @override
  String get profilePasswordUpdated => 'Parola güncellendi.';

  @override
  String get profilePasswordUpdateFailed => 'Parola güncellenemedi.';

  @override
  String profilePasswordUpdateFailedWithError(Object error) {
    return 'Parola güncellenemedi: $error';
  }

  @override
  String get profileAvatarUpload => 'Avatar Yükle';

  @override
  String get profileNameMissing => 'İsim girilmemiş';

  @override
  String get profileUsernamePlaceholder => '@kullanici';

  @override
  String get profileInfoTitle => 'Profil Bilgileri';

  @override
  String get profileFieldName => 'İsim';

  @override
  String get profileFieldUsername => 'Kullanıcı adı';

  @override
  String get profileFieldDescription => 'Açıklama';

  @override
  String get profileFieldFooter => 'Alt bilgi';

  @override
  String get profileSeoSectionTitle => 'SEO';

  @override
  String get profileSeoSubtitle => 'Başlık, açıklama ve anahtar kelimeler';

  @override
  String get profileSeoTitleLabel => 'Başlık';

  @override
  String get profileSeoDescriptionLabel => 'Açıklama';

  @override
  String get profileSeoKeywordsLabel => 'Anahtar kelimeler';

  @override
  String get profileSaving => 'Kaydediliyor...';

  @override
  String get profilePasswordSectionTitle => 'Parola Güncelle';

  @override
  String get profilePasswordUpdatedSubtitle => 'Başarıyla güncellendi';

  @override
  String get profileCurrentPassword => 'Mevcut parola';

  @override
  String get profileNewPassword => 'Yeni parola';

  @override
  String get profileConfirmPassword => 'Yeni parola tekrar';

  @override
  String get profileChangePasswordSaving => 'Gönderiliyor...';

  @override
  String get profileChangePasswordButton => 'Parolayı Güncelle';

  @override
  String profileSmsCount(Object count) {
    return 'SMS: $count';
  }

  @override
  String get myLinksTitle => 'Linklerim';

  @override
  String get myLinksNewLink => 'Yeni Link';

  @override
  String get myLinksSearchType => 'Link tipi ara';

  @override
  String get myLinksNoResults => 'Sonuç bulunamadı';

  @override
  String get myLinksLinkType => 'Link Tipi';

  @override
  String get myLinksTypeMissing =>
      'Link tipi bulunamadı, lütfen ayarları kontrol edin.';

  @override
  String get myLinksTitleLabel => 'Başlık';

  @override
  String get myLinksUrlLabel => 'URL';

  @override
  String get myLinksColorLabel => 'Renk';

  @override
  String get myLinksColorMissing => 'Renk listesi bulunamadı.';

  @override
  String get myLinksAddLink => 'Link Ekle';

  @override
  String get myLinksSaving => 'Kaydediliyor...';

  @override
  String get myLinksCreateRequired =>
      'Link eklemek için token, tip ve renk gerekli.';

  @override
  String get myLinksCreateSuccess => 'Link eklendi.';

  @override
  String get myLinksCreateFailed => 'Link eklenemedi.';

  @override
  String get myLinksCreateError => 'Link eklenirken hata oluştu.';

  @override
  String get myLinksTokenMissing => 'Token bulunamadı.';

  @override
  String get myLinksDeleteSuccess => 'Link silindi.';

  @override
  String get myLinksDeleteFailed => 'Link silinemedi.';

  @override
  String get myLinksDeleteError => 'Link silinirken hata oluştu.';

  @override
  String get myLinksUpdateSuccess => 'Link güncellendi.';

  @override
  String get myLinksUpdateFailed => 'Link güncellenemedi.';

  @override
  String get myLinksUpdateError => 'Link güncellenirken hata oluştu.';

  @override
  String get myLinksEditTitle => 'Link Düzenle';

  @override
  String get myLinksUpdateButton => 'Güncelle';

  @override
  String myLinksTypeFallback(Object id) {
    return 'Tip #$id';
  }

  @override
  String myLinksColorFallback(Object id) {
    return 'Renk #$id';
  }

  @override
  String get myLinksNoLinksTitle => 'Henüz link yok';

  @override
  String get myLinksNoLinksSubtitle => 'Yeni link ekleyerek başla';

  @override
  String get myLinksDebugTitle => 'Eksik veriler';

  @override
  String get myLinksDebugSubtitle => 'API’den beklenen listeler gelmedi';

  @override
  String get myLinksDebugNoLinks => '⚠️ API\'den hiç link gelmedi.';

  @override
  String get myLinksDebugNoTypes => '⚠️ Link tipleri boş geldi.';

  @override
  String get myLinksDebugNoColors => '⚠️ Renk listesi boş geldi.';

  @override
  String get myLinksOrderSaving => 'Sıralama kaydediliyor...';

  @override
  String get myLinksShowForm => 'Yeni Link Ekle';

  @override
  String get myLinksHideForm => 'Formu Gizle';

  @override
  String get themesTitle => 'Temalar';

  @override
  String get themesSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String get themesSessionExpired =>
      'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';

  @override
  String themesLoadFailed(Object error) {
    return 'Temalar yüklenemedi: $error';
  }

  @override
  String get themesPreviewError => 'Önizleme yüklenirken sorun oluştu.';

  @override
  String get themesSelectTheme => 'Lütfen bir tema seçin.';

  @override
  String get themesSaveSuccess => 'Tema güncellendi.';

  @override
  String themesSaveFailedStatus(Object status) {
    return 'Tema güncellenemedi (HTTP $status).';
  }

  @override
  String themesSaveError(Object error) {
    return 'Tema kaydedilirken hata oluştu: $error';
  }

  @override
  String get themesRefreshTooltip => 'Yenile';

  @override
  String get themesRetry => 'Tekrar Dene';

  @override
  String get themesListTitle => 'Temalar';

  @override
  String get themesNoThemes => 'Kullanılabilir tema bulunamadı.';

  @override
  String get themesLivePreview => 'Canlı Önizleme';

  @override
  String get themesSaving => 'Kaydediliyor...';

  @override
  String get themesSaveButton => 'Temayı Kaydet';

  @override
  String get themesPreviewPlaceholder => 'Önizleme için bir tema seçin.';

  @override
  String get themesFallbackName => 'Tema';
}
