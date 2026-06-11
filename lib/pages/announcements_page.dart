import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth.dart';
import '../config.dart';

// ── Tip meta ─────────────────────────────────────────────────────────────────

class _TypeMeta {
  final String label;
  final Color color;
  final IconData icon;
  const _TypeMeta(this.label, this.color, this.icon);
}

const Map<String, _TypeMeta> _kTypeMeta = {
  'info':    _TypeMeta('Bilgi',    Color(0xFF3B82F6), Icons.info_outline),
  'warning': _TypeMeta('Uyarı',   Color(0xFFF59E0B), Icons.warning_amber_outlined),
  'promo':   _TypeMeta('Kampanya',Color(0xFFEC4899), Icons.local_offer_outlined),
  'feature': _TypeMeta('Yenilik', Color(0xFF8B5CF6), Icons.auto_awesome_outlined),
  'update':  _TypeMeta('Güncelleme',Color(0xFF10B981),Icons.system_update_outlined),
};

_TypeMeta _meta(String? type) =>
    _kTypeMeta[type] ?? const _TypeMeta('Duyuru', Color(0xFF6B7280), Icons.campaign_outlined);

// ── Model ─────────────────────────────────────────────────────────────────────

class Announcement {
  final int id;
  final String title;
  final String body;
  final String type;
  final String? iosUrl;
  final String? androidUrl;
  bool isRead;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.iosUrl,
    this.androidUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id:          j['id'] as int,
        title:       j['title']?.toString() ?? '',
        body:        j['body']?.toString() ?? '',
        type:        j['type']?.toString() ?? 'info',
        iosUrl:      j['ios_url']?.toString(),
        androidUrl:  j['android_url']?.toString(),
        isRead:      j['is_read'] == true,
        createdAt:   DateTime.tryParse(j['created_at']?.toString() ?? '') ??
                     DateTime.now(),
      );
}

// ── Sayfa ─────────────────────────────────────────────────────────────────────

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<Announcement> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await authGet(
        Uri.parse('$apiBaseUrl/api/announcements'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body)['data'] as List? ?? []);
        setState(() {
          _items = data
              .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      } else {
        setState(() => _error = 'Yüklenemedi (HTTP ${res.statusCode}).');
      }
    } catch (e) {
      setState(() => _error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Announcement item) async {
    if (item.isRead) return;
    setState(() => item.isRead = true);
    try {
      await authPost(
        Uri.parse('$apiBaseUrl/api/announcements/${item.id}/read'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await authPost(
        Uri.parse('$apiBaseUrl/api/announcements/read-all'),
        headers: {'Accept': 'application/json'},
      );
      setState(() {
        for (final a in _items) a.isRead = true;
      });
    } catch (_) {}
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24)   return '${diff.inHours} saat önce';
    if (diff.inDays < 7)     return '${diff.inDays} gün önce';
    return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((a) => !a.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Duyurular',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E1E2D),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tümünü oku',
                  style: TextStyle(
                      color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(_items[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Announcement item) {
    final m = _meta(item.type);
    return GestureDetector(
      onTap: () async {
        await _markRead(item);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _AnnouncementDetailPage(item: item)),
        );
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead
                ? const Color(0xFFE5E7EB)
                : m.color.withValues(alpha: 0.35),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: item.isRead ? 0.02 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(m.icon, size: 18, color: m.color),
            ),
            const SizedBox(width: 12),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(m.label,
                            style: TextStyle(
                                color: m.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text(_fmtDate(item.createdAt),
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF1E1E2D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Okunmamış noktası
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: m.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined, size: 52, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('Henüz duyuru yok',
              style:
                  TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _load, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

// ── Detay sayfası ─────────────────────────────────────────────────────────────

class _AnnouncementDetailPage extends StatefulWidget {
  final Announcement item;
  const _AnnouncementDetailPage({required this.item});

  @override
  State<_AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<_AnnouncementDetailPage> {
  late final WebViewController _wc;
  bool _webLoading = true;

  @override
  void initState() {
    super.initState();
    _wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _webLoading = false);
        },
      ))
      ..loadHtmlString(_html(widget.item.body));
  }

  String _html(String body) => '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: -apple-system, sans-serif; font-size: 15px;
         color: #374151; line-height: 1.7; padding: 0 4px; margin: 0; }
  img  { max-width: 100%; border-radius: 8px; }
  a    { color: #6366F1; }
  p    { margin: 0 0 12px; }
</style></head><body>$body</body></html>''';

  Future<void> _launchStore() async {
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? widget.item.iosUrl
        : widget.item.androidUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final m    = _meta(item.type);
    final isUpdate = item.type == 'update';
    final hasStore = (item.iosUrl?.isNotEmpty ?? false) ||
        (item.androidUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: Text(m.label,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E1E2D),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: Column(
        children: [
          // Başlık kartı
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(m.icon, size: 20, color: m.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1E2D))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_fmtDate(item.createdAt),
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // HTML içerik
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: WebViewWidget(controller: _wc),
                  ),
                ),
                if (_webLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),

          // Store butonu (sadece update tipinde)
          if (isUpdate && hasStore)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _launchStore,
                    icon: const Icon(Icons.system_update_outlined, size: 18),
                    label: const Text('Güncellemeyi İndir',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
