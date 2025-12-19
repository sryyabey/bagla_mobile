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

  @override
  String get smsPacksTitle => 'SMS Paketleri';

  @override
  String get smsPacksSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String get smsPacksSessionExpired =>
      'Oturum süresi doldu, lütfen tekrar giriş yapın.';

  @override
  String smsPacksLoadFailedStatus(Object status) {
    return 'Paketler alınamadı (HTTP $status).';
  }

  @override
  String smsPacksLoadFailed(Object error) {
    return 'Paketler alınamadı: $error';
  }

  @override
  String smsPacksCountriesFailedStatus(Object status) {
    return 'Ülkeler alınamadı (HTTP $status).';
  }

  @override
  String smsPacksCountriesFailed(Object error) {
    return 'Ülkeler alınamadı: $error';
  }

  @override
  String smsPacksCitiesFailedStatus(Object status) {
    return 'Şehirler alınamadı (HTTP $status).';
  }

  @override
  String smsPacksCitiesFailed(Object error) {
    return 'Şehirler alınamadı: $error';
  }

  @override
  String smsPacksDistrictsFailedStatus(Object status) {
    return 'İlçeler alınamadı (HTTP $status).';
  }

  @override
  String smsPacksDistrictsFailed(Object error) {
    return 'İlçeler alınamadı: $error';
  }

  @override
  String smsPacksAddressesFailedStatus(Object status) {
    return 'Adresler alınamadı (HTTP $status).';
  }

  @override
  String smsPacksAddressesFailed(Object error) {
    return 'Adresler alınamadı: $error';
  }

  @override
  String get smsPacksContentMissing => 'İçerik bulunamadı.';

  @override
  String get smsPacksContract => 'Sözleşme';

  @override
  String get smsPacksClose => 'Kapat';

  @override
  String get smsPacksFeatures => 'Özellikler';

  @override
  String get smsPacksPlanMonthly => 'Aylık';

  @override
  String get smsPacksPlanAnnual => 'Yıllık';

  @override
  String get smsPacksSelectPack => 'Lütfen bir paket seçin.';

  @override
  String get smsPacksSelectCountry => 'Lütfen ülke seçin.';

  @override
  String get smsPacksSelectCity => 'Lütfen şehir seçin.';

  @override
  String get smsPacksSelectDistrict => 'Lütfen ilçe seçin.';

  @override
  String get smsPacksNameRequired => 'Ad alanı boş bırakılamaz.';

  @override
  String get smsPacksLastNameRequired => 'Soyad alanı boş bırakılamaz.';

  @override
  String get smsPacksPhoneRequired => 'Telefon alanı boş bırakılamaz.';

  @override
  String get smsPacksAddressRequired => 'Adres alanı boş bırakılamaz.';

  @override
  String get smsPacksAgreementRequired =>
      'Satın alma sözleşmesini onaylamalısınız.';

  @override
  String get smsPacksPurchaseSuccess =>
      'Siparişiniz oluşturuldu, ödeme ekranına yönlendiriliyorsunuz.';

  @override
  String smsPacksPurchaseFailedStatus(Object status) {
    return 'Satın alma başarısız (HTTP $status).';
  }

  @override
  String smsPacksPurchaseError(Object error) {
    return 'Satın alma sırasında hata oluştu: $error';
  }

  @override
  String get smsPacksPaymentStartInvalid =>
      'Ödeme sayfası açılamadı, geçersiz yanıt.';

  @override
  String smsPacksPaymentStartFailedStatus(Object status) {
    return 'Ödeme başlatılamadı (HTTP $status).';
  }

  @override
  String smsPacksPaymentStartError(Object error) {
    return 'Ödeme başlatılırken hata oluştu: $error';
  }

  @override
  String get smsPacksPaymentPending => 'Ödeme onaylanıyor, lütfen bekleyin.';

  @override
  String get smsPacksPaymentVerify403 => 'Ödeme doğrulanamadı (403).';

  @override
  String get smsPacksPaymentVerify404 => 'İşlem bulunamadı (404).';

  @override
  String smsPacksPaymentVerifyFailedStatus(Object status) {
    return 'Ödeme doğrulanamadı (HTTP $status).';
  }

  @override
  String smsPacksPaymentVerifyError(Object error) {
    return 'Ödeme doğrulanamadı: $error';
  }

  @override
  String get smsPacksPaymentSuccessTitle => 'Ödeme Başarılı';

  @override
  String get smsPacksPaymentPendingTitle => 'Ödeme Bekliyor';

  @override
  String get smsPacksPaymentFailedTitle => 'Ödeme Başarısız';

  @override
  String get smsPacksPaymentLabel => 'Ödeme';

  @override
  String get smsPacksPackLabel => 'Paket';

  @override
  String get smsPacksTypeLabel => 'Tip';

  @override
  String get smsPacksAmountLabel => 'Tutar';

  @override
  String get smsPacksInvoiceLabel => 'Fatura No';

  @override
  String get smsPacksPaymentVerifying => 'Ödeme doğrulanıyor...';

  @override
  String get smsPacksGoHome => 'Ana sayfaya dön';

  @override
  String get smsPacksRetry => 'Tekrar Dene';

  @override
  String get smsPacksStepPack => 'Paket';

  @override
  String get smsPacksStepInfo => 'Bilgiler';

  @override
  String get smsPacksStepSummary => 'Özet';

  @override
  String get smsPacksStepPayment => 'Ödeme';

  @override
  String get smsPacksNext => 'Devam';

  @override
  String get smsPacksBack => 'Geri';

  @override
  String get smsPacksBuy => 'Satın Al';

  @override
  String get smsPacksDetails => 'Özellikleri Gör';

  @override
  String get smsPacksSelectButton => 'Paketi Seç';

  @override
  String get smsPacksSelected => 'Seçildi';

  @override
  String get smsPacksRefresh => 'Yenile';

  @override
  String get smsPacksSavedAddresses => 'Kayıtlı Adresler';

  @override
  String get smsPacksNewAddress => 'Yeni Adres';

  @override
  String get smsPacksAddressTitle => 'Adres Başlığı';

  @override
  String get smsPacksFirstName => 'Ad';

  @override
  String get smsPacksLastName => 'Soyad';

  @override
  String get smsPacksCompany => 'Şirket Adı (opsiyonel)';

  @override
  String get smsPacksEmail => 'E-posta';

  @override
  String get smsPacksCountry => 'Ülke';

  @override
  String get smsPacksCity => 'Şehir';

  @override
  String get smsPacksDistrict => 'İlçe';

  @override
  String get smsPacksPhone => 'Telefon';

  @override
  String get smsPacksIdentity => 'Kimlik No (opsiyonel)';

  @override
  String get smsPacksTaxNumber => 'Vergi No (opsiyonel)';

  @override
  String get smsPacksTaxOffice => 'Vergi Dairesi';

  @override
  String get smsPacksAddress => 'Adres';

  @override
  String get smsPacksPaymentMethod => 'Ödeme Yöntemi';

  @override
  String get smsPacksNote => 'Not';

  @override
  String get smsPacksNoteHint => 'Faturaya eklenecek not veya özel talepler';

  @override
  String get smsPacksAgreementTitle =>
      'Satın alma sözleşmesini okudum, onaylıyorum.';

  @override
  String get smsPacksSummaryTitle => 'Satın Alma Özeti';

  @override
  String get smsPacksSummaryPurchaseInfo => 'Satın Alma Bilgileri';

  @override
  String get smsPacksSmsLabel => 'SMS';

  @override
  String get smsPacksCompanyLabel => 'Şirket';

  @override
  String get smsPacksBuyerLabel => 'Ad Soyad';

  @override
  String get smsPacksEmailLabel => 'E-posta';

  @override
  String get smsPacksCountryLabel => 'Ülke';

  @override
  String get smsPacksCityLabel => 'Şehir';

  @override
  String get smsPacksDistrictLabel => 'İlçe';

  @override
  String get smsPacksPhoneLabel => 'Telefon';

  @override
  String get smsPacksTaxNumberLabel => 'Vergi No';

  @override
  String get smsPacksTaxOfficeLabel => 'Vergi Dairesi';

  @override
  String get smsPacksIdentityLabel => 'Kimlik No';

  @override
  String get smsPacksAddressLabel => 'Adres';

  @override
  String get smsPacksNoteLabel => 'Not';

  @override
  String get smsPacksSubmitLabel => 'Gönder';

  @override
  String get smsPacksNoPacksForType => 'Bu tipte paket bulunamadı.';

  @override
  String smsPacksPriceWithTax(Object price) {
    return 'KDV\'li ₺$price';
  }

  @override
  String smsPacksSmsCount(Object count) {
    return '$count SMS';
  }

  @override
  String get smsPacksSelectPackForSummary =>
      'Özet için önce paket seçmelisiniz.';

  @override
  String get smsPacksRefreshing => 'Yenileniyor...';

  @override
  String get smsPacksSavedAddressesLabel => 'Kayıtlı Adresler';

  @override
  String get smsPacksSelectAddress => 'Seç';

  @override
  String get smsPacksPlanLabel => 'Plan';

  @override
  String get smsPacksPriceLabel => 'Fiyat';

  @override
  String get smsPacksVatIncluded => 'KDV Dahil';

  @override
  String get smsPacksSubmitting => 'Gönderiliyor...';

  @override
  String get ordersTitle => 'Siparişler';

  @override
  String get ordersSessionExpired =>
      'Oturum süresi doldu, lütfen tekrar giriş yapın.';

  @override
  String get ordersSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String ordersFetchFailedStatus(Object status) {
    return 'Siparişler alınamadı (HTTP $status).';
  }

  @override
  String ordersFetchFailed(Object error) {
    return 'Siparişler alınamadı: $error';
  }

  @override
  String get ordersRetry => 'Tekrar Dene';

  @override
  String get ordersEmpty => 'Henüz sipariş bulunmuyor.';

  @override
  String get ordersFilterAll => 'Hepsi';

  @override
  String get ordersFilterPaid => 'Ödendi';

  @override
  String get ordersFilterPending => 'Bekliyor';

  @override
  String get ordersFilterFailed => 'Başarısız';

  @override
  String get ordersPrev => 'Önceki';

  @override
  String get ordersNext => 'Sonraki';

  @override
  String ordersPageLabel(Object current, Object total) {
    return 'Sayfa $current / $total';
  }

  @override
  String get ordersPack => 'Paket';

  @override
  String get ordersType => 'Tip';

  @override
  String get ordersStatus => 'Durum';

  @override
  String get ordersAmount => 'Tutar';

  @override
  String get ordersDate => 'Tarih';

  @override
  String get ordersTxnId => 'İşlem ID';

  @override
  String get ordersPrice => 'Fiyat';

  @override
  String get ordersTax => 'Vergi';

  @override
  String get ordersTotal => 'Toplam';

  @override
  String get ordersDetailTitle => 'Sipariş';

  @override
  String get ordersStatusPaid => 'Ödendi';

  @override
  String get ordersStatusPending => 'Bekliyor';

  @override
  String get ordersStatusFailed => 'Başarısız';

  @override
  String get ordersStatusCancelled => 'İptal edildi';

  @override
  String get workingPrefsTitle => 'Çalışma Saatleri';

  @override
  String get workingPrefsSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String workingPrefsLoadFailedStatus(Object status) {
    return 'Çalışma saatleri alınamadı (HTTP $status).';
  }

  @override
  String workingPrefsLoadFailed(Object error) {
    return 'Çalışma saatleri alınamadı: $error';
  }

  @override
  String get workingPrefsSaveSuccess => 'Kaydedildi.';

  @override
  String workingPrefsSaveFailedStatus(Object status) {
    return 'Kaydedilemedi (HTTP $status).';
  }

  @override
  String workingPrefsSaveFailed(Object error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get workingPrefsRetry => 'Tekrar Dene';

  @override
  String get workingPrefsFirstSessionTitle => 'İlk randevu oturum sayısı';

  @override
  String get workingPrefsSelect => 'Seçiniz';

  @override
  String workingPrefsSessionOption(Object count) {
    return '$count Oturum';
  }

  @override
  String get workingPrefsDaySubtitle => 'Çalışma durumu ve saat aralıkları';

  @override
  String get workingPrefsWorking => 'Çalışıyor';

  @override
  String get workingPrefsAddSlot => 'Saat aralığı ekle';

  @override
  String get workingPrefsStart => 'Başlangıç';

  @override
  String get workingPrefsEnd => 'Bitiş';

  @override
  String get workingPrefsPeriod => 'Periyot (dakika)';

  @override
  String get workingPrefsDelete => 'Sil';

  @override
  String get workingPrefsSaving => 'Kaydediliyor...';

  @override
  String get workingPrefsSave => 'Kaydet';

  @override
  String get workingPrefsHolidaysTitle => 'Tatil Günleri';

  @override
  String get workingPrefsHolidaysEmpty => 'Henüz tatil eklenmedi.';

  @override
  String get workingPrefsHolidayAdd => 'Tatil ekle';

  @override
  String get workingPrefsHolidayStart => 'Başlangıç';

  @override
  String get workingPrefsHolidayEnd => 'Bitiş';

  @override
  String get workingPrefsHolidayReason => 'Açıklama (isteğe bağlı)';

  @override
  String get smsTemplatesTitle => 'SMS Şablonları';

  @override
  String get smsTemplatesSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String smsTemplatesFetchFailedStatus(Object status) {
    return 'Şablonlar alınamadı (HTTP $status).';
  }

  @override
  String smsTemplatesFetchFailed(Object error) {
    return 'Şablonlar alınamadı: $error';
  }

  @override
  String get smsTemplatesUpdated => 'SMS şablonları güncellendi.';

  @override
  String smsTemplatesSaveFailedStatus(Object status) {
    return 'Kaydedilemedi (HTTP $status).';
  }

  @override
  String smsTemplatesSaveFailed(Object error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get smsTemplatesSelect => 'Seçiniz';

  @override
  String get smsTemplatesNotFound => 'Şablon bulunamadı';

  @override
  String get smsTemplatesCustomerTemplates => 'Müşteri SMS Şablonları';

  @override
  String smsTemplatesSelectionId(Object id) {
    return 'Seçim ID: $id';
  }

  @override
  String get smsTemplatesMain => 'Ana Mesaj';

  @override
  String get smsTemplatesReminder => 'Hatırlatma';

  @override
  String get smsTemplatesCancel => 'İptal';

  @override
  String get smsTemplatesUpdate => 'Güncelleme';

  @override
  String get smsTemplatesSave => 'Kaydet';

  @override
  String get smsTemplatesSaving => 'Kaydediliyor...';

  @override
  String get smsTemplatesRefresh => 'Yenile';

  @override
  String smsTemplatesFallbackTitle(Object id) {
    return 'Şablon #$id';
  }

  @override
  String get supportTitle => 'Destek';

  @override
  String get supportSessionMissing =>
      'Oturum bulunamadı. Lütfen tekrar giriş yapın.';

  @override
  String supportFetchFailedStatus(Object status) {
    return 'Destek kayıtları alınamadı (HTTP $status).';
  }

  @override
  String supportFetchFailed(Object error) {
    return 'Destek kayıtları alınamadı: $error';
  }

  @override
  String get supportCreateValidation => 'Başlık ve mesaj zorunludur.';

  @override
  String get supportCreateSuccess => 'Destek talebi oluşturuldu.';

  @override
  String supportCreateFailedStatus(Object status) {
    return 'Talep oluşturulamadı (HTTP $status).';
  }

  @override
  String supportCreateFailed(Object error) {
    return 'Talep oluşturulamadı: $error';
  }

  @override
  String get supportRetry => 'Tekrar dene';

  @override
  String get supportEmpty => 'Henüz destek talebiniz yok.';

  @override
  String get supportRefresh => 'Yenile';

  @override
  String get supportNewTicket => 'Yeni Destek Talebi';

  @override
  String get supportTitleLabel => 'Başlık';

  @override
  String get supportMessageLabel => 'Mesajınız';

  @override
  String get supportSending => 'Gönderiliyor...';

  @override
  String get supportSend => 'Gönder';

  @override
  String get supportTickets => 'Destek Kayıtları';

  @override
  String get supportMessagesCount => 'Mesaj';

  @override
  String get supportTicketDetail => 'Destek Detayı';

  @override
  String get supportTicketNotFound => 'Talep bulunamadı.';

  @override
  String get supportMessages => 'Mesajlar';

  @override
  String get supportStatusClosing => 'Kapatılıyor';

  @override
  String get supportCloseTicket => 'Talebi Kapat';

  @override
  String supportCreatedAt(Object date) {
    return 'Oluşturulma: $date';
  }

  @override
  String get supportSenderYou => 'Siz';

  @override
  String get supportSenderSupport => 'Destek';

  @override
  String get supportNoMessages => 'Henüz mesaj yok.';

  @override
  String get supportReplyPlaceholder => 'Mesajınız';

  @override
  String get supportReplyClosed =>
      'Bu talep kapalı, yeni mesaj gönderemezsiniz.';

  @override
  String get supportReplySending => 'Gönderiliyor...';

  @override
  String get supportReplySend => 'Yanıt Gönder';

  @override
  String get supportReplyEmpty => 'Mesaj boş olamaz.';

  @override
  String get supportReplySuccess => 'Yanıt gönderildi.';

  @override
  String supportReplyFailedStatus(Object status) {
    return 'Yanıt gönderilemedi (HTTP $status).';
  }

  @override
  String supportReplyFailed(Object error) {
    return 'Yanıt gönderilemedi: $error';
  }

  @override
  String get supportCloseSuccess => 'Talep kapatıldı.';

  @override
  String supportCloseFailedStatus(Object status) {
    return 'Talep kapatılamadı (HTTP $status).';
  }

  @override
  String supportCloseFailed(Object error) {
    return 'Talep kapatılamadı: $error';
  }

  @override
  String supportMessagesMeta(Object count, Object date) {
    return '$count mesaj • $date';
  }

  @override
  String get supportStatusOpen => 'Açık';

  @override
  String get supportStatusPending => 'Beklemede';

  @override
  String get supportStatusClosed => 'Kapalı';

  @override
  String get supportPriority => 'Öncelik';
}
