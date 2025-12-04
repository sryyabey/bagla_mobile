import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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

  Future<void> _shareBio(String channel, String link) async {
    Uri uri;
    switch (channel) {
      case 'sms':
        uri = Uri(
          scheme: 'sms',
          queryParameters: {'body': link},
        );
        break;
      case 'whatsapp':
        uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(link)}');
        break;
      case 'telegram':
        uri = Uri.parse(
          'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(link)}',
        );
        break;
      default:
        uri = Uri.parse(link);
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showSnack('Paylaşım açılamadı.');
      }
    } catch (e) {
      _showSnack('Paylaşım açılamadı: $e');
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color? color}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBioCard(String? link) {
    if (link == null || link.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
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
              children: [
                ElevatedButton.icon(
                  onPressed: () => _shareBio('sms', link),
                  icon: const Icon(Icons.sms),
                  label: const Text('SMS'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _shareBio('whatsapp', link),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _shareBio('telegram', link),
                  icon: const Icon(Icons.send),
                  label: const Text('Telegram'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackInfo(Map<String, dynamic>? packInfo) {
    if (packInfo == null) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
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
              leading: const Icon(Icons.bolt, color: Colors.orange),
              title: Text(packInfo['pack_name']?.toString() ?? '-'),
              subtitle: const Text('Paket adı'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(packInfo['activated_at']?.toString() ?? '-'),
              subtitle: const Text('Başlangıç'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.timer_off_outlined),
              title: Text(packInfo['expired_at']?.toString() ?? '-'),
              subtitle: const Text('Bitiş'),
            ),
          ],
        ),
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

    return Column(
      children: List.generate(labels.length, (index) {
        final label = labels[index];
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

  Widget _buildDashboardBody() {
    final data = _dashboardData ?? {};
    final packInfo = data['pack_info'] is Map<String, dynamic>
        ? data['pack_info'] as Map<String, dynamic>
        : null;
    final totalClicks = data['total_clicks']?.toString() ?? '0';
    final remainingSms =
        packInfo != null ? (packInfo['remaining_sms'] ?? 0).toString() : '0';

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
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
      appBar: AppBar(
        title: const Text('Yonetim Paneli'),
        automaticallyImplyLeading:
            true, // bu satırı da ekleyebilirsin ama default true
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.blueAccent, // Drawer başlığı için arka plan rengi
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.menuTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                    ),
                  ),
                ],
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
