import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'login_page.dart';
import 'pages/themes.dart';
import 'pages/myLinks.dart';
import 'pages/profile.dart';
import 'pages/support.dart';
import 'pages/working_preferences.dart';
import 'pages/appointments.dart';
import 'pages/sms_templates.dart';
import 'pages/calendar.dart';
import 'pages/sms_packs.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboardData;

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

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
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
        });
      } else {
        String message = 'Dashboard alınamadı (HTTP ${response.statusCode}).';
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
        _error = 'Dashboard alınamadı: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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

  Future<void> _openWhatsAppSupport() async {
    const phone = '902589110241';
    final uri = Uri.parse('https://wa.me/$phone');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack('WhatsApp açılamadı.');
      }
    } catch (e) {
      _showSnack('WhatsApp açılamadı: $e');
    }
  }

  Future<void> _shareBioSystem(String link) async {
    try {
      await Share.share(link, subject: 'Bagla bio link');
    } catch (e) {
      _showSnack('Paylaşım başarısız: $e');
    }
  }

  void _showQrModal(String link) {
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
              const Text(
                'Bio Link QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareBioSystem(link);
                },
                icon: const Icon(Icons.share),
                label: const Text('Paylaş'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color? color}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (color ?? Colors.blueAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _heroSection(Map<String, dynamic>? packInfo, String totalClicks) {
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
            color: Colors.indigo.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yönetim Paneli',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Linklerini ve randevularını tek yerden yönet.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniPill('Toplam Tıklama', totalClicks, Icons.visibility),
              const SizedBox(width: 10),
              _miniPill('Kalan SMS', remainingSms, Icons.sms),
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
          color: Colors.white.withOpacity(0.14),
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
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bio Sayfanız',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  style: const TextStyle(color: Colors.blue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  _showSnack('Bağlantı kopyalandı.', success: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _shareBioSystem(link),
                icon: const Icon(Icons.share),
                label: const Text('Paylaş'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showQrModal(link),
                icon: const Icon(Icons.qr_code),
                label: const Text('QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackInfo(Map<String, dynamic>? packInfo) {
    if (packInfo == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paket Bilgisi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bolt, color: Colors.orange),
            title: Text(packInfo['pack_name']?.toString() ?? '-'),
            subtitle: const Text('Paket adı'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline),
            title: Text(packInfo['activated_at']?.toString() ?? '-'),
            subtitle: const Text('Başlangıç'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_off_outlined),
            title: Text(packInfo['expired_at']?.toString() ?? '-'),
            subtitle: const Text('Bitiş'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyClicks(Map<String, dynamic>? dailyClicks) {
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
      return const Text('Henüz tıklama verisi yok.');
    }

    final limitedLabels = labels.take(5).toList();
    return Column(
      children: List.generate(limitedLabels.length, (index) {
        final label = limitedLabels[index];
        final value = index < values.length ? values[index] : '-';
        return ListTile(
          dense: true,
          leading: const Icon(Icons.bar_chart),
          title: Text(label),
          trailing: Text(value.toString()),
        );
      }),
    );
  }

  Widget _buildTopLinks(List<dynamic>? topLinks) {
    if (topLinks == null || topLinks.isEmpty) {
      return const Text('Henüz bağlantı tıklaması yok.');
    }
    return Column(
      children: topLinks.map((link) {
        final map = link as Map<String, dynamic>;
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(map['title']?.toString() ?? '-'),
          trailing: Text('${map['clicks'] ?? 0}'),
        );
      }).toList(),
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
    if (apptInfo == null) {
      return const Text('Bugün için randevu verisi yok.');
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bugünkü Randevular',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$todayCount bugün',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Text('Bugün için randevu bulunamadı.')
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.event_available,
                          color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name?.isNotEmpty == true
                                ? name!
                                : 'Müşteri #${appt['customer_id'] ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtDate(appt['date']?.toString())} • ${_fmtTime(appt['time']?.toString())}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CalendarPage(),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Takvim'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppointmentsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Randevular'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardBody() {
    final data = _dashboardData ?? {};
    final packInfo = data['pack_info'] is Map<String, dynamic>
        ? data['pack_info'] as Map<String, dynamic>
        : null;
    final totalClicks = data['total_clicks']?.toString() ?? '0';
    final remainingSms =
        packInfo != null ? (packInfo['remaining_sms'] ?? 0).toString() : '0';
    final appointmentInfo = data['appointment_info'] is Map<String, dynamic>
        ? data['appointment_info'] as Map<String, dynamic>
        : null;

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _heroSection(packInfo, totalClicks),
          _buildBioCard(data['bio_page']?.toString()),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Toplam Tıklama', totalClicks, Icons.visibility),
              const SizedBox(width: 12),
              _buildStatCard('Kalan SMS', remainingSms, Icons.sms),
            ],
          ),
          const SizedBox(height: 16),
          _buildPackInfo(packInfo),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTodayAppointments(context, appointmentInfo),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Günlük Tıklamalar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDailyClicks(data['daily_clicks']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Çok Tıklanan Linkler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildTopLinks(data['top_links'] as List<dynamic>?),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Yönetim Paneli',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: 'WhatsApp Destek',
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
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yönetim Paneli',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Randevu ve iletişimlerinizi buradan yönetin',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Anasayfa'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardPage(),
                  ),
                );
              },
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemesPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Randevular'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Haftalık Takvim'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalendarPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('SMS Paketleri'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmsPacksPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Çalışma Saatleri'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkingPreferencesPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('SMS Şablonları'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmsTemplatesPage(),
                  ),
                );
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
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('authToken');

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
                      child: Column(
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
                            onPressed: _fetchDashboard,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildDashboardBody(),
      ),
    );
  }
}
