import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config.dart';
import 'login_page.dart';
import 'auth.dart';
import 'pages/themes.dart';
import 'pages/my_links.dart';
import 'pages/customers.dart';
import 'pages/profile.dart';
import 'pages/support.dart';
import 'pages/working_preferences.dart';
import 'pages/appointments.dart';
import 'pages/sms_templates.dart';
import 'pages/calendar.dart';
import 'pages/pack_page_router.dart';
import 'pages/orders.dart';
import 'pages/ai_profile_page.dart';
import 'pages/announcements_page.dart';
import 'pages/blog_page.dart';
import 'widgets/main_nav.dart';
import 'package:in_app_review/in_app_review.dart';

class DashboardPage extends StatefulWidget {
  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  const DashboardPage({
    super.key,
    this.showBottomNav = true,
    this.onTabSelected,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const int _maxDashboardTopLinks = 8;
  static const int _maxDashboardAppointments = 6;
  bool _loading = true;
  String? _error;
  bool _hasDashboardLoaded = false;
  bool _noInternet = false;
  Map<String, dynamic>? _packInfo;
  String _totalClicks = '0';
  String? _bioPageLink;
  Map<String, dynamic>? _dailyClicks;
  List<_DashboardTopLink> _topLinks = const [];
  int _todayAppointmentCount = 0;
  List<_DashboardAppointment> _todayAppointments = const [];
  Map<String, dynamic>? _welcomePromo;
  bool _hasAiProfileContent = false; // true → AI banner gizlenir
  int _unreadAnnouncementCount = 0;
  bool _showRatingCard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _fetchDashboard();
      await _checkRatingPrompt();
    });
  }

  Future<void> _checkRatingPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    final firstOpen = prefs.getString('first_open_date');
    if (firstOpen == null) {
      await prefs.setString(
          'first_open_date', DateTime.now().toIso8601String());
      return;
    }

    final firstDate = DateTime.tryParse(firstOpen);
    if (firstDate == null) return;

    if (DateTime.now().difference(firstDate).inDays < 3) return;

    if (prefs.getBool('rating_declined') == true) return;

    final lastAsked = prefs.getString('rating_last_asked');
    if (lastAsked != null) {
      final lastDate = DateTime.tryParse(lastAsked);
      if (lastDate != null &&
          DateTime.now().difference(lastDate).inDays < 30) return;
    }

    if (mounted) setState(() => _showRatingCard = true);
  }

  Future<void> _declineReview() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rating_declined', true);
    setState(() => _showRatingCard = false);
  }

  void _openRatingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingModal(
        onSubmit: (stars, comment) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'rating_last_asked', DateTime.now().toIso8601String());
          if (mounted) setState(() => _showRatingCard = false);

          // 4+ yıldızda native store rating'i aç
          if (stars >= 4) {
            final inAppReview = InAppReview.instance;
            if (await inAppReview.isAvailable()) {
              await inAppReview.requestReview();
            } else {
              await inAppReview.openStoreListing(appStoreId: appleAppStoreId);
            }
          }
        },
        onDecline: _declineReview,
      ),
    );
  }

  Future<String?> _getToken() async {
    return getAccessToken();
  }

  Future<void> _fetchDashboard({bool force = false}) async {
    final loc = AppLocalizations.of(context);
    if (_hasDashboardLoaded && !force) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _noInternet = false;
    });

    String? nextError;
    bool nextNoInternet = false;
    Map<String, dynamic>? nextParsedData;

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      nextError = loc.dashboardSessionMissing;
    } else {
      try {
        final response = await authGet(
          Uri.parse('$apiBaseUrl/api/dashboard'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'] ?? decoded;
          if (data is Map<String, dynamic>) {
            nextParsedData = data;
          } else if (data is Map) {
            nextParsedData = Map<String, dynamic>.from(data);
          } else {
            nextError = loc.dashboardLoadFailed('Invalid payload');
          }
        } else {
          String message =
              loc.dashboardLoadFailedWithStatus(response.statusCode.toString());
          try {
            final decoded = jsonDecode(response.body);
            message = decoded['message']?.toString() ?? message;
          } catch (_) {}
          nextError = message;
        }
      } catch (e) {
        nextNoInternet = e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        nextError = nextNoInternet
            ? loc.dashboardNoInternet
            : loc.dashboardLoadFailed(e.toString());
      }
    }

    if (!mounted) return;
    setState(() {
      if (nextParsedData != null) {
        _applyDashboardData(nextParsedData);
        _hasDashboardLoaded = true;
      }
      _error = nextError;
      _noInternet = nextNoInternet;
      _loading = false;
    });

    if (token != null && token.isNotEmpty) {
      _fetchActivePack(token);
      _fetchWelcomePromo(token);
    }
  }

  // Paket bilgisi kartı için aktif paketi tek doğruluk kaynağından çek.
  Future<void> _fetchActivePack(String token) async {
    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/packs/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];
        final pack = data is Map ? data['pack'] : null;
        setState(() {
          _packInfo = pack is Map ? Map<String, dynamic>.from(pack) : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchWelcomePromo(String token) async {
    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/welcome'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        // Sunucu hata kodu döndürdüyse (örn. "Welcome form şu an aktif değil") kartı gösterme
        if (decoded['code'] == 'SERVER_ERROR' ||
            decoded['type'] == 'error') return;
        final data = decoded['data'] ?? decoded;
        if (data is Map) {
          setState(() {
            _welcomePromo = Map<String, dynamic>.from(data);
          });
        }
      }
    } catch (_) {}
  }

  void _applyDashboardData(Map<String, dynamic> data) {
    _packInfo = data['pack_info'] is Map<String, dynamic>
        ? data['pack_info'] as Map<String, dynamic>
        : (data['pack_info'] is Map
            ? Map<String, dynamic>.from(data['pack_info'] as Map)
            : null);
    _totalClicks = data['total_clicks']?.toString() ?? '0';
    _bioPageLink = data['bio_page']?.toString();
    final profileDesc = data['profile_description']?.toString() ?? '';
    _hasAiProfileContent = profileDesc.isNotEmpty;
    _unreadAnnouncementCount =
        (data['unread_announcements_count'] as int? ?? 0);
    _dailyClicks = data['daily_clicks'] is Map<String, dynamic>
        ? data['daily_clicks'] as Map<String, dynamic>
        : (data['daily_clicks'] is Map
            ? Map<String, dynamic>.from(data['daily_clicks'] as Map)
            : null);

    final rawTopLinks = data['top_links'] as List?;
    final parsedTopLinks = <_DashboardTopLink>[];
    if (rawTopLinks != null) {
      for (final item in rawTopLinks) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final rawClicks = map['clicks'];
        final clicks = rawClicks is num
            ? rawClicks.toDouble()
            : double.tryParse(rawClicks?.toString() ?? '') ?? 0;
        final title = map['title']?.toString().trim() ?? '';
        parsedTopLinks.add(
          _DashboardTopLink(
            title: title.isNotEmpty ? title : '-',
            clicks: clicks,
          ),
        );
      }
    }
    _topLinks =
        parsedTopLinks.take(_maxDashboardTopLinks).toList(growable: false);

    final apptInfo = data['appointment_info'] as Map?;
    final todayCountRaw =
        apptInfo?['todayAppointments'] ?? apptInfo?['today_appointments'] ?? 0;
    _todayAppointmentCount = int.tryParse(todayCountRaw.toString()) ?? 0;
    final parsedAppointments = <_DashboardAppointment>[];
    final apptList = apptInfo?['appointments'] as List?;
    if (apptList != null) {
      for (final item in apptList) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final customer = map['customer'] is Map
            ? Map<String, dynamic>.from(map['customer'] as Map)
            : null;
        final status = map['appointment_status'] is Map
            ? Map<String, dynamic>.from(map['appointment_status'] as Map)
            : null;
        final customerName = customer?['name']?.toString().trim();
        parsedAppointments.add(
          _DashboardAppointment(
            customerId: map['customer_id']?.toString() ?? '',
            customerName:
                (customerName?.isNotEmpty == true) ? customerName! : null,
            phone: customer?['phone']?.toString() ?? '',
            date: map['date']?.toString(),
            time: map['time']?.toString(),
            statusName: status?['name']?.toString() ??
                status?['alias']?.toString() ??
                '',
          ),
        );
      }
    }
    _todayAppointments = parsedAppointments
        .take(_maxDashboardAppointments)
        .toList(growable: false);
  }

  void _navigateToPage(Widget page, String routeName) {
    // Çekmeceden çık; varsa üst seviye sayfa shell'i için tab değiştir
    Navigator.pop(context);
    if (widget.onTabSelected != null) {
      if (page is DashboardPage) {
        widget.onTabSelected!(0);
        return;
      }
      if (page is AppointmentsPage) {
        widget.onTabSelected!(1);
        return;
      }
      if (page is CalendarPage) {
        widget.onTabSelected!(2);
        return;
      }
      if (page is CustomersPage) {
        widget.onTabSelected!(3);
        return;
      }
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
        settings: RouteSettings(name: routeName),
      ),
    );
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _downloadQr(BuildContext sourceContext, String link) async {
    final loc = AppLocalizations.of(context);
    final origin = _shareOrigin(sourceContext);
    try {
      final painter = QrPainter(
        data: link,
        version: QrVersions.auto,
        gapless: true,
      );
      final imageData =
          await painter.toImageData(600, format: ui.ImageByteFormat.png);
      final bytes = imageData?.buffer.asUint8List();
      if (bytes == null) throw 'Görsel oluşturulamadı';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bagla_qr.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: loc.dashboardShareBio,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      _showSnack(loc.dashboardQrDownloadFailed(e.toString()));
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final loc = AppLocalizations.of(context);
    const phone = '902589110241';
    final uri = Uri.parse('https://wa.me/$phone');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack(loc.dashboardWhatsAppFailed);
      }
    } catch (e) {
      _showSnack(loc.dashboardWhatsAppFailedWithError(e.toString()));
    }
  }

  Future<void> _openBioLink(String link) async {
    final loc = AppLocalizations.of(context);
    final trimmed = link.trim();
    if (trimmed.isEmpty) return;
    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) {
      _showSnack(loc.dashboardLinkOpenFailed);
      return;
    }
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$trimmed');
    }
    if (uri == null) {
      _showSnack(loc.dashboardLinkOpenFailed);
      return;
    }
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack(loc.dashboardLinkOpenFailed);
      }
    } catch (_) {
      _showSnack(loc.dashboardLinkOpenFailed);
    }
  }

  Rect _shareOrigin(BuildContext sourceContext) {
    final box = sourceContext.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (overlayBox is RenderBox && overlayBox.hasSize) {
      return overlayBox.localToGlobal(Offset.zero) & overlayBox.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _shareBioSystem(BuildContext sourceContext, String link) async {
    final loc = AppLocalizations.of(context);
    try {
      final origin = _shareOrigin(sourceContext);
      await Share.share(
        link,
        subject: loc.dashboardShareBio,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      _showSnack(loc.dashboardShareFailed(e.toString()));
    }
  }

  void _showQrModal(String link) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                loc.dashboardQrTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                link,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blue),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        await _shareBioSystem(ctx, link);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      icon: const Icon(Icons.share),
                      label: Text(loc.dashboardShare),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        await _downloadQr(ctx, link);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: Text(loc.dashboardDownload),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTabOrPush(int tabIndex, Widget page) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(tabIndex);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _tabPageForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const AppointmentsPage();
      case 2:
        return const CalendarPage();
      case 3:
      default:
        return const CustomersPage();
    }
  }

  void _navigateFromDrawer({
    int? tabIndex,
    Widget? page,
    String? routeName,
  }) {
    Navigator.pop(context); // close drawer first

    if (tabIndex != null) {
      if (widget.onTabSelected != null) {
        widget.onTabSelected!(tabIndex);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _tabPageForIndex(tabIndex),
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );
      return;
    }

    if (page == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => page,
        settings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  Widget _heroSection(Map<String, dynamic>? packInfo, String totalClicks) {
    final loc = AppLocalizations.of(context);
    final remainingSms =
        packInfo != null ? (packInfo['remaining_sms'] ?? 0).toString() : '0';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.dashboardTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.dashboardHeroSubtitle,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniPill(loc.dashboardTopClicks, totalClicks, Icons.visibility),
              const SizedBox(width: 10),
              _miniPill(loc.dashboardRemainingSms, remainingSms, Icons.sms),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openTabOrPush(1, const AppointmentsPage()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(loc.dashboardAppointments),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openTabOrPush(2, const CalendarPage()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(loc.dashboardCalendar),
                ),
              ),
            ],
          ),
          if (_bioPageLink != null && _bioPageLink!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildHeroBioSection(loc),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroBioSection(AppLocalizations loc) {
    final link = _bioPageLink!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                loc.dashboardBioPage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openBioLink(link),
                  child: Text(
                    link,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _heroBioButton(
                icon: Icons.copy_outlined,
                tooltip: 'Kopyala',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  _showSnack(loc.dashboardLinkCopied, success: true);
                },
              ),
              const SizedBox(width: 6),
              Builder(
                builder: (ctx) => _heroBioButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Paylaş',
                  onTap: () => _shareBioSystem(ctx, link),
                ),
              ),
              const SizedBox(width: 6),
              _heroBioButton(
                icon: Icons.qr_code_outlined,
                tooltip: 'QR Kod',
                onTap: () => _showQrModal(link),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBioButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _miniPill(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPackInfo(Map<String, dynamic>? packInfo) {
    final loc = AppLocalizations.of(context);
    if (packInfo == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.inbox_outlined, color: Colors.blueGrey),
                ),
                const SizedBox(width: 10),
                Text(
                  loc.dashboardPackageInfo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              loc.dashboardNoActivePackage,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => buildPackPageForPlatform()),
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(loc.dashboardBuyPackage),
              ),
            ),
          ],
        ),
      );
    }
    final remainingSms = (packInfo['remaining_sms'] ?? 0).toString();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_offer,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.dashboardPackageInfo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sms, size: 14, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${loc.dashboardRemainingSms}: $remainingSms',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bolt, color: Color(0xFF38BDF8)),
            title: Text(
              packInfo['pack_name']?.toString() ?? '-',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              loc.dashboardPackageName,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.play_circle_outline, color: Color(0xFF34D399)),
            title: Text(
              packInfo['activated_at']?.toString() ?? '-',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              loc.dashboardStart,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.timer_off_outlined, color: Color(0xFFFBBF24)),
            title: Text(
              (packInfo['expired_at'] ??
                      packInfo['expiry_date'] ??
                      packInfo['expires_at'] ??
                      packInfo['ends_at'])
                  ?.toString() ??
                  '-',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              loc.dashboardEnd,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyClicks(Map<String, dynamic>? dailyClicks) {
    final loc = AppLocalizations.of(context);
    final labels =
        (dailyClicks?['labels'] as List?)?.map((e) => e.toString()).toList() ??
            [];
    final datasets = dailyClicks?['datasets'] as List?;
    final firstDataset = datasets != null && datasets.isNotEmpty
        ? datasets.first as Map<String, dynamic>?
        : null;
    final values =
        (firstDataset?['data'] as List?)?.map((e) => e ?? 0).toList() ?? [];

    if (labels.isEmpty || values.isEmpty) {
      return Text(loc.dashboardNoClicks);
    }

    final limitedLabels = labels.take(6).toList();
    final limitedValues = List<double>.generate(
      limitedLabels.length,
      (index) {
        final raw = index < values.length ? values[index] : 0;
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString()) ?? 0;
      },
    );
    final maxValue = limitedValues.isEmpty
        ? 1.0
        : limitedValues
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    return Column(
      children: List.generate(limitedLabels.length, (index) {
        final label = limitedLabels[index];
        final value = limitedValues[index];
        final ratio = (value / maxValue).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: ratio,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopLinks(List<_DashboardTopLink> topLinks) {
    final loc = AppLocalizations.of(context);
    if (topLinks.isEmpty) {
      return Text(loc.dashboardNoLinkClicks);
    }
    final maxClicks = topLinks.isEmpty
        ? 1.0
        : topLinks
            .map((e) => e.clicks)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    return Column(
      children: List.generate(topLinks.length, (index) {
        final link = topLinks[index];
        final value = link.clicks;
        final ratio = (value / maxClicks).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      link.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: ratio,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _fmtDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final d = DateTime.parse(date);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _fmtTime(String? time) {
    if (time == null) return '-';
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time;
  }

  Widget _buildTodayAppointments(
    BuildContext context, {
    required int todayCount,
    required List<_DashboardAppointment> appointments,
  }) {
    final loc = AppLocalizations.of(context);
    if (appointments.isEmpty && todayCount == 0) {
      return Text(loc.dashboardNoAppointmentsData);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              loc.dashboardTodayCount(todayCount.toString()),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (appointments.isEmpty)
          Text(loc.dashboardNoAppointments)
        else
          Column(
            children: appointments.map((appt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _fmtTime(appt.time),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.customerName ??
                                loc.dashboardCustomerFallback(appt.customerId),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDate(appt.date),
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                          ),
                          if (appt.phone.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    appt.phone,
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (appt.statusName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Chip(
                          label: Text(
                            appt.statusName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.blueGrey.shade50,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                _openTabOrPush(2, const CalendarPage());
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(loc.dashboardCalendar),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                _openTabOrPush(1, const AppointmentsPage());
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(loc.dashboardAppointments),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.indigo.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchGroupedProfessions() async {
    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/professions/grouped'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<String?> _showProfessionPicker(
      BuildContext ctx, List<Map<String, dynamic>> groups) async {
    final searchCtrl = TextEditingController();
    String query = '';

    return showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerCtx) {
        return StatefulBuilder(builder: (pickerCtx, setPickerState) {
          final filteredGroups = groups
              .map((g) {
                final profs = (g['professions'] as List<dynamic>)
                    .cast<String>()
                    .where((p) =>
                        p.toLowerCase().contains(query.toLowerCase()))
                    .toList();
                return {'category': g['category'], 'professions': profs};
              })
              .where((g) =>
                  (g['professions'] as List).isNotEmpty)
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(pickerCtx).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Meslek ara...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setPickerState(() => query = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                        onChanged: (v) => setPickerState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredGroups.isEmpty
                          ? const Center(child: Text('Sonuç bulunamadı'))
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: filteredGroups.length,
                              itemBuilder: (_, i) {
                                final group = filteredGroups[i];
                                final profs =
                                    (group['professions'] as List<String>);
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(
                                        group['category'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ...profs.map((p) => ListTile(
                                          dense: true,
                                          title: Text(p),
                                          onTap: () =>
                                              Navigator.of(pickerCtx)
                                                  .pop(p),
                                        )),
                                    const Divider(height: 1),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  Future<void> _submitWelcomeForm({
    required String profession,
    required String city,
    String? instagram,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;
    final body = <String, dynamic>{
      'profession': profession,
      'city': city,
    };
    if (instagram != null && instagram.trim().isNotEmpty) {
      body['instagram'] = instagram.trim();
    }
    final response = await authPost(
      Uri.parse('$apiBaseUrl/api/welcome'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (!mounted) return;
    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() => _welcomePromo = null);
      _showSnack('Paketiniz aktifleştirildi! 🎉', success: true);
    } else {
      String msg = 'Bir hata oluştu.';
      try {
        final decoded = jsonDecode(response.body);
        msg = decoded['message']?.toString() ?? msg;
      } catch (_) {}
      _showSnack(msg);
    }
  }

  void _showWelcomeFormSheet() {
    String selectedProfession = '';
    List<Map<String, dynamic>> professionGroups = [];
    bool loadingProfessions = true;
    final cityCtrl = TextEditingController();
    final igCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (loadingProfessions) {
            loadingProfessions = false;
            _fetchGroupedProfessions().then((groups) {
              if (ctx.mounted) {
                setSheetState(() => professionGroups = groups);
              }
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Yeni Üyelik Hediyeni Al',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Formu doldur, 1 ay ücretsiz 100 SMS paketini hemen aktifleştir.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FormField<String>(
                    validator: (_) => selectedProfession.trim().isEmpty
                        ? 'Zorunlu alan'
                        : null,
                    builder: (fieldState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: professionGroups.isEmpty
                              ? null
                              : () async {
                                  final picked =
                                      await _showProfessionPicker(
                                          ctx, professionGroups);
                                  if (picked != null) {
                                    setSheetState(() =>
                                        selectedProfession = picked);
                                    fieldState.didChange(picked);
                                  }
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Mesleğiniz *',
                              prefixIcon: const Icon(Icons.work_outline),
                              border: const OutlineInputBorder(),
                              errorText: fieldState.errorText,
                              suffixIcon: professionGroups.isEmpty
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.keyboard_arrow_down),
                            ),
                            isEmpty: selectedProfession.isEmpty,
                            child: Text(
                              selectedProfession.isEmpty
                                  ? 'Seçiniz...'
                                  : selectedProfession,
                              style: TextStyle(
                                color: selectedProfession.isEmpty
                                    ? Colors.black38
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Şehir *',
                      hintText: 'ör. İstanbul',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: igCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Instagram (isteğe bağlı)',
                      hintText: '@kullaniciadi',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => submitting = true);
                              Navigator.of(ctx).pop();
                              await _submitWelcomeForm(
                                profession: selectedProfession.trim(),
                                city: cityCtrl.text.trim(),
                                instagram: igCtrl.text.trim().isNotEmpty
                                    ? igCtrl.text.trim()
                                    : null,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch_outlined),
                      label: const Text(
                        'Paketi Aktifleştir',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildWelcomePromoCard() {
    if (_welcomePromo == null) return const SizedBox.shrink();
    final bool alreadyClaimed = _welcomePromo!['completed'] == true ||
        _welcomePromo!['claimed'] == true;
    if (alreadyClaimed) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showWelcomeFormSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42), Color(0xFFFFB347)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            Positioned(
              top: -10,
              right: 10,
              child: Icon(
                Icons.card_giftcard,
                size: 80,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'YENİ ÜYELİK HEDİYESİ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '1 Ay Ücretsiz 100 SMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Seni bekliyor! Hemen formu doldur, paketini aktifleştir.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiProfileBanner() {
    final loc = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _navigateToPage(const AiProfilePage(), 'ai_profile'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D0B1E), Color(0xFF1E1050), Color(0xFF2D1060)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Dekoratif arka plan noktaları
            Positioned(
              top: -8,
              right: 16,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -12,
              right: 60,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9333EA).withValues(alpha: 0.1),
                ),
              ),
            ),
            // İçerik
            Row(
              children: [
                // Sol: AI ikonu
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Orta: Metin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFFA78BFA).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFFA78BFA),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              loc.aiProfileBannerBadge,
                              style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.aiProfileBannerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        loc.aiProfileBannerDesc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Sağ: Ok
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('⭐', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagla\'yı beğeniyor musunuz?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Değerlendirmeniz büyümemize katkı sağlar.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              ElevatedButton(
                onPressed: _openRatingModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Değerlendir',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: _declineReview,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9CA3AF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Kapat',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
        );
        // Geri dönünce sayacı sıfırla (okudular)
        setState(() => _unreadAnnouncementCount = 0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_unreadAnnouncementCount yeni duyurunuz var',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Gör',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowSmsWarning(int remaining, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SMS krediniz azalıyor — $remaining mesaj kaldı.',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => buildPackPageForPlatform())),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Yükle',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final loc = AppLocalizations.of(context);
    return _buildSectionCard(
      icon: Icons.bolt_rounded,
      title: loc.dashboardQuickActions,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _quickActionTile(
            icon: Icons.person_outline,
            label: loc.profileTitle,
            onTap: () => _navigateToPage(const ProfilePage(), 'profile'),
            color: const Color(0xFF4F46E5),
          ),
          _quickActionTile(
            icon: Icons.link_outlined,
            label: loc.myLinks,
            onTap: () => _navigateToPage(const MyLinksPage(), 'my_links'),
            color: const Color(0xFF16A34A),
          ),
          _quickActionTile(
            icon: Icons.sms_outlined,
            label: loc.dashboardSmsTemplates,
            onTap: () => _navigateToPage(
              const SmsTemplatesPage(),
              'sms_templates',
            ),
            color: const Color(0xFFDB2777),
          ),
          _quickActionTile(
            icon: Icons.schedule_outlined,
            label: loc.dashboardWorkingHours,
            onTap: () => _navigateToPage(
              const WorkingPreferencesPage(),
              'working_preferences',
            ),
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    final loc = AppLocalizations.of(context);
    final hiddenAppointments =
        (_todayAppointmentCount - _todayAppointments.length).clamp(0, 9999);
    final remainingSms =
        _packInfo != null ? (_packInfo!['remaining_sms'] ?? 0) as int : 0;
    final lowSms = remainingSms > 0 && remainingSms <= 10;

    return RefreshIndicator(
      onRefresh: () => _fetchDashboard(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1 — Hero
          _heroSection(_packInfo, _totalClicks),
          const SizedBox(height: 12),

          // 2 — Duyurular (okunmamış varsa)
          if (_unreadAnnouncementCount > 0) ...[
            _buildAnnouncementBanner(),
            const SizedBox(height: 12),
          ],

          // 3 — Bugünkü randevular (en kritik günlük bilgi)
          _buildSectionCard(
            icon: Icons.event_available_outlined,
            title: loc.dashboardTodayAppointments,
            child: Column(
              children: [
                _buildTodayAppointments(
                  context,
                  todayCount: _todayAppointmentCount,
                  appointments: _todayAppointments,
                ),
                if (hiddenAppointments > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _openTabOrPush(1, const AppointmentsPage()),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('+${hiddenAppointments.toInt()}'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3 — Welcome promo (yeni kullanıcı)
          _buildWelcomePromoCard(),

          // 4 — SMS uyarısı (kritik, paketi olanlar için)
          if (lowSms) ...[
            _buildLowSmsWarning(remainingSms, loc),
            const SizedBox(height: 12),
          ],

          // 5 — AI profil banner (açıklama/alt bilgi henüz girilmemişse)
          if (!_hasAiProfileContent) ...[
            _buildAiProfileBanner(),
            const SizedBox(height: 12),
          ],

          // 6 — Paket bilgisi
          _buildPackInfo(_packInfo),
          const SizedBox(height: 12),

          // 7 — Hızlı işlemler (sadece sık kullanılanlar)
          _buildQuickActions(),
          const SizedBox(height: 16),

          // 7b — Blog / İçerikler şeridi (web trafiğine yönlendirir)
          const BlogHighlightsStrip(),
          const SizedBox(height: 16),

          // 8 — Değerlendirme kartı (koşulları sağlandığında)
          if (_showRatingCard) ...[
            _buildRatingCard(),
            const SizedBox(height: 12),
          ],

          // 9 — Analitik
          _buildSectionCard(
            icon: Icons.bar_chart_rounded,
            title: loc.dashboardDailyClicks,
            child: _buildDailyClicks(_dailyClicks),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            icon: Icons.link_rounded,
            title: loc.dashboardTopLinks,
            child: Column(
              children: [
                _buildTopLinks(_topLinks),
                if (_topLinks.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _navigateToPage(const MyLinksPage(), 'my_links'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(loc.myLinks),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          loc.dashboardTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: loc.dashboardWhatsappSupport,
            icon: const Icon(Icons.chat, color: Colors.green),
            onPressed: _openWhatsAppSupport,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade900,
                    Colors.indigo.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/mobile_logo.png',
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.dashboardTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.dashboardDrawerSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(loc.dashboardHome),
              onTap: () {
                _navigateFromDrawer(tabIndex: 0, routeName: 'dashboard');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                loc.dashboardMenuMain,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(loc.profile),
              onTap: () {
                _navigateFromDrawer(
                  page: const ProfilePage(),
                  routeName: 'profile',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(loc.customersTitle),
              onTap: () {
                _navigateFromDrawer(tabIndex: 3, routeName: 'customers');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                loc.dashboardMenuManagement,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(loc.myLinks),
              onTap: () {
                _navigateFromDrawer(
                  page: const MyLinksPage(),
                  routeName: 'my_links',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(loc.themes),
              onTap: () {
                _navigateFromDrawer(
                  page: const ThemesPage(),
                  routeName: 'themes',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI Profil'),
              onTap: () {
                _navigateFromDrawer(
                  page: const AiProfilePage(),
                  routeName: 'ai_profile',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text(loc.dashboardSmsPacks),
              onTap: () {
                _navigateFromDrawer(
                  page: buildPackPageForPlatform(),
                  routeName: 'sms_packs',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(loc.dashboardOrders),
              onTap: () {
                _navigateFromDrawer(
                  page: const OrdersPage(),
                  routeName: 'orders',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(loc.dashboardWorkingHours),
              onTap: () {
                _navigateFromDrawer(
                  page: const WorkingPreferencesPage(),
                  routeName: 'working_preferences',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: Text(loc.dashboardSmsTemplates),
              onTap: () {
                _navigateFromDrawer(
                  page: const SmsTemplatesPage(),
                  routeName: 'sms_templates',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Blog'),
              onTap: () {
                _navigateFromDrawer(
                  page: const BlogPage(),
                  routeName: 'blog',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support),
              title: Text(loc.support),
              onTap: () {
                _navigateFromDrawer(
                  page: const SupportPage(),
                  routeName: 'support',
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(loc.exit),
              onTap: () async {
                await clearTokens();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('authToken');
                try {
                  final googleSignIn = GoogleSignIn(
                    scopes: const ['email'],
                    serverClientId: googleWebServerClientId,
                  );
                  await googleSignIn.signOut();
                  await googleSignIn.disconnect();
                } catch (_) {}

                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginPage(
                        onLocaleChange: (locale) {
                          // Gerekirse burada ana uygulamaya locale bilgisi aktarılır
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _noInternet
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off,
                                    size: 64, color: Colors.redAccent),
                                const SizedBox(height: 12),
                                Text(
                                  loc.dashboardNoInternet,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _fetchDashboard(force: true),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(loc.dashboardRetry),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _fetchDashboard(force: true),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(loc.dashboardRetry),
                                ),
                              ],
                            ),
                    ),
                  )
                : _buildDashboardBody(),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? MainNavBar(
              currentIndex: 0,
              onIndexSelected: widget.onTabSelected,
            )
          : null,
    );
  }
}

class _DashboardTopLink {
  const _DashboardTopLink({
    required this.title,
    required this.clicks,
  });

  final String title;
  final double clicks;
}

class _DashboardAppointment {
  const _DashboardAppointment({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.date,
    required this.time,
    required this.statusName,
  });

  final String customerId;
  final String? customerName;
  final String phone;
  final String? date;
  final String? time;
  final String statusName;
}

// ── Rating Modal ──────────────────────────────────────────────────────────────

class _RatingModal extends StatefulWidget {
  final Future<void> Function(int stars, String comment) onSubmit;
  final VoidCallback onDecline;

  const _RatingModal({required this.onSubmit, required this.onDecline});

  @override
  State<_RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<_RatingModal> {
  int _selectedStars = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_selectedStars, _commentCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Emoji + başlık
          const Text('😊', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          const Text(
            'Bagla\'yı nasıl buluyorsunuz?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Deneyiminizi paylaşarak büyümemize katkı sağlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),

          // Yıldızlar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _selectedStars;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 44,
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Yıldız etiketi
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _starLabel(_selectedStars),
              key: ValueKey(_selectedStars),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _selectedStars > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Yorum alanı
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Yorumunuz (isteğe bağlı)...',
              hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
              counterStyle:
                  const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ),
          const SizedBox(height: 20),

          // Butonlar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedStars > 0 && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Değerlendirmeyi Gönder',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              widget.onDecline();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9CA3AF),
            ),
            child: const Text('Şimdi değil',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Çok kötü';
      case 2:
        return 'Kötü';
      case 3:
        return 'Orta';
      case 4:
        return 'İyi';
      case 5:
        return 'Mükemmel!';
      default:
        return 'Puan seçin';
    }
  }
}
