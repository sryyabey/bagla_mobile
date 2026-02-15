import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
import 'pages/sms_packs.dart';
import 'pages/orders.dart';
import 'widgets/main_nav.dart';

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
  bool get _isIosStorefront => !kIsWeb && Platform.isIOS;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboardData;
  bool _hasDashboardLoaded = false;
  bool _noInternet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboard();
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token') ?? prefs.getString('authToken');
  }

  Future<void> _fetchDashboard({bool force = false}) async {
    final loc = AppLocalizations.of(context);
    if (_hasDashboardLoaded && !force) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _noInternet = false;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = loc.dashboardSessionMissing;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        setState(() {
          _dashboardData = Map<String, dynamic>.from(data);
          _hasDashboardLoaded = true;
        });
      } else {
        String message =
            loc.dashboardLoadFailedWithStatus(response.statusCode.toString());
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        setState(() {
          _error = message;
        });
      }
    } catch (e) {
      setState(() {
        _noInternet = e is SocketException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup');
        _error = _noInternet
            ? loc.dashboardNoInternet
            : loc.dashboardLoadFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
      if (page is ProfilePage) {
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
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
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
        ],
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

  Widget _buildBioCard(String? link) {
    final loc = AppLocalizations.of(context);
    if (link == null || link.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.dashboardBioPage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  _showSnack(loc.dashboardLinkCopied, success: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Builder(
                builder: (buttonContext) => ElevatedButton.icon(
                  onPressed: () => _shareBioSystem(buttonContext, link),
                  icon: const Icon(Icons.share),
                  label: Text(loc.dashboardShare),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showQrModal(link),
                icon: const Icon(Icons.qr_code),
                label: Text(loc.dashboardQr),
              ),
            ],
          ),
        ],
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
              _isIosStorefront
                  ? loc.iosSmsPurchaseRestrictionMessage
                  : 'Aktif paketiniz bulunmuyor. SMS işlemleri için paket alın.',
              style: const TextStyle(color: Colors.black87),
            ),
            if (!_isIosStorefront) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmsPacksPage()),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Paket Al'),
                ),
              ),
            ],
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
              packInfo['expired_at']?.toString() ?? '-',
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
        : limitedValues.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

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

  Widget _buildTopLinks(List<dynamic>? topLinks) {
    final loc = AppLocalizations.of(context);
    if (topLinks == null || topLinks.isEmpty) {
      return Text(loc.dashboardNoLinkClicks);
    }
    final maps = topLinks
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final clicks = maps.map((m) {
      final raw = m['clicks'];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? 0;
    }).toList();
    final maxClicks = clicks.isEmpty
        ? 1.0
        : clicks.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Column(
      children: List.generate(maps.length, (index) {
        final map = maps[index];
        final title = map['title']?.toString().trim();
        final value = clicks[index];
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
                      (title?.isNotEmpty == true) ? title! : '-',
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
      BuildContext context, Map<String, dynamic>? apptInfo) {
    final loc = AppLocalizations.of(context);
    if (apptInfo == null) {
      return Text(loc.dashboardNoAppointmentsData);
    }
    final todayCount =
        apptInfo['todayAppointments'] ?? apptInfo['today_appointments'] ?? 0;
    final list = apptInfo['appointments'] is List
        ? List<Map<String, dynamic>>.from(
            (apptInfo['appointments'] as List)
                .map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];

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
        if (list.isEmpty)
          Text(loc.dashboardNoAppointments)
        else
          Column(
            children: list.map((appt) {
              final customer = appt['customer'] is Map
                  ? appt['customer'] as Map<String, dynamic>
                  : null;
              final status = appt['appointment_status'] is Map
                  ? appt['appointment_status'] as Map<String, dynamic>
                  : null;
              final statusName = status?['name']?.toString() ??
                  status?['alias']?.toString() ??
                  '';
              final name = customer?['name']?.toString();
              final phone = customer?['phone']?.toString() ?? '';
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
                        _fmtTime(appt['time']?.toString()),
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
                            name?.isNotEmpty == true
                                ? name!
                                : loc.dashboardCustomerFallback(
                                    appt['customer_id']?.toString() ?? ''),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDate(appt['date']?.toString()),
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                          if (phone.isNotEmpty)
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
                                    phone,
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
                    if (statusName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Chip(
                          label: Text(
                            statusName,
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
            icon: Icons.palette_outlined,
            label: loc.themes,
            onTap: () => _navigateToPage(const ThemesPage(), 'themes'),
            color: const Color(0xFF0284C7),
          ),
          _quickActionTile(
            icon: Icons.link_outlined,
            label: loc.myLinks,
            onTap: () => _navigateToPage(const MyLinksPage(), 'my_links'),
            color: const Color(0xFF16A34A),
          ),
          _quickActionTile(
            icon: Icons.receipt_long_outlined,
            label: loc.dashboardOrders,
            onTap: () => _navigateToPage(const OrdersPage(), 'orders'),
            color: const Color(0xFFF59E0B),
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
            icon: Icons.support_agent_outlined,
            label: loc.support,
            onTap: () => _navigateToPage(const SupportPage(), 'support'),
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    final loc = AppLocalizations.of(context);
    final data = _dashboardData ?? {};
    final packInfo = data['pack_info'] is Map<String, dynamic>
        ? data['pack_info'] as Map<String, dynamic>
        : null;
    final totalClicks = data['total_clicks']?.toString() ?? '0';
    final appointmentInfo = data['appointment_info'] is Map<String, dynamic>
        ? data['appointment_info'] as Map<String, dynamic>
        : null;

    return RefreshIndicator(
      onRefresh: () => _fetchDashboard(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _heroSection(packInfo, totalClicks),
          _buildBioCard(data['bio_page']?.toString()),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 16),
          _buildPackInfo(packInfo),
          const SizedBox(height: 16),
          _buildSectionCard(
            icon: Icons.event_available_outlined,
            title: loc.dashboardTodayAppointments,
            child: _buildTodayAppointments(context, appointmentInfo),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            icon: Icons.bar_chart_rounded,
            title: loc.dashboardDailyClicks,
            child: _buildDailyClicks(data['daily_clicks']),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            icon: Icons.link_rounded,
            title: loc.dashboardTopLinks,
            child: _buildTopLinks(data['top_links'] as List<dynamic>?),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardPage(),
                  ),
                );
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
                // Profil sayfasına yönlendirme
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(loc.customersTitle),
              onTap: () {
                _navigateToPage(const CustomersPage(), 'customers');
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
                // Linkler sayfasına yönlendirme
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyLinksPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(loc.themes),
              onTap: () {
                // Temalar sayfasına yönlendirme
                _navigateToPage(const ThemesPage(), 'themes');
              },
            ),
            if (!_isIosStorefront)
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(loc.dashboardSmsPacks),
                onTap: () {
                  _navigateToPage(const SmsPacksPage(), 'sms_packs');
                },
              ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(loc.dashboardOrders),
              onTap: () {
                _navigateToPage(const OrdersPage(), 'orders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(loc.dashboardWorkingHours),
              onTap: () {
                _navigateToPage(
                    const WorkingPreferencesPage(), 'working_preferences');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: Text(loc.dashboardSmsTemplates),
              onTap: () {
                _navigateToPage(const SmsTemplatesPage(), 'sms_templates');
              },
            ),
            ListTile(
              leading: const Icon(Icons.support),
              title: Text(loc.support),
              onTap: () {
                // Destek sayfasına yönlendirme
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SupportPage(),
                  ),
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
                    serverClientId:
                        '99910465030-ng2ik9e1hpmbv9dg5530u7jr2e2emrmu.apps.googleusercontent.com',
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
