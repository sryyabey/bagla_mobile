import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import '../auth.dart';
import '../main_tabs_page.dart';

// ─── Link tipi meta verisi ────────────────────────────────────────────────────

class _LinkMeta {
  final String title;
  final Color color;
  final IconData icon;
  const _LinkMeta(this.title, this.color, this.icon);
}

const Map<int, _LinkMeta> _kLinkTypes = {
  1:  _LinkMeta('Facebook',    Color(0xFF1877F2), Icons.facebook_outlined),
  2:  _LinkMeta('Instagram',   Color(0xFFE1306C), Icons.camera_alt_outlined),
  3:  _LinkMeta('Twitter / X', Color(0xFF000000), Icons.alternate_email),
  4:  _LinkMeta('LinkedIn',    Color(0xFF0077B5), Icons.work_outline),
  5:  _LinkMeta('YouTube',     Color(0xFFFF0000), Icons.play_circle_outline),
  6:  _LinkMeta('TikTok',      Color(0xFF010101), Icons.music_note_outlined),
  9:  _LinkMeta('E-posta',     Color(0xFF6B7280), Icons.email_outlined),
  10: _LinkMeta('Telefon',     Color(0xFF10B981), Icons.phone_outlined),
  11: _LinkMeta('WhatsApp',    Color(0xFF25D366), Icons.chat_outlined),
  12: _LinkMeta('Telegram',    Color(0xFF2CA5E0), Icons.send_outlined),
  13: _LinkMeta('Konum',       Color(0xFFEA4335), Icons.location_on_outlined),
  14: _LinkMeta('Web Sitesi',  Color(0xFF3B82F6), Icons.language_outlined),
  32: _LinkMeta('Zoom',        Color(0xFF2D8CFF), Icons.video_call_outlined),
  39: _LinkMeta('Threads',     Color(0xFF000000), Icons.tag_outlined),
};

// ─── Sayfa ───────────────────────────────────────────────────────────────────

class AiProfilePage extends StatefulWidget {
  const AiProfilePage({super.key});

  @override
  State<AiProfilePage> createState() => _AiProfilePageState();
}

class _AiProfilePageState extends State<AiProfilePage>
    with TickerProviderStateMixin {
  // ── Renkler ─────────────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF6366F1);
  static const Color _bg        = Color(0xFFF3F4F8);
  static const Color _darkBg    = Color(0xFF0D0B1E);
  static const Color _darkCard  = Color(0xFF1A1730);
  static const Color _aiAccent  = Color(0xFFA78BFA);

  // ── Animasyon ────────────────────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  late final TabController _tabController;

  // ── Yükleme durumu ──────────────────────────────────────────────────────────
  bool _loading  = true;
  String? _error;

  // ── AI Üret form ────────────────────────────────────────────────────────────
  final _generateFormKey = GlobalKey<FormState>();
  List<String> _professions = [];
  String? _selectedProfession;
  final _uzmanlikCtrl    = TextEditingController();
  final _hedefKitleCtrl  = TextEditingController();
  final _deneyimCtrl     = TextEditingController();
  final _basariCtrl      = TextEditingController();
  final _ekNotCtrl       = TextEditingController();
  String _selectedTon    = 'samimi';
  static const List<String> _tonOptions = ['samimi', 'profesyonel', 'sıcak'];
  static const Map<String, (String, String, String)> _tonMeta = {
    // key: (emoji, label, açıklama)
    'samimi':       ('😊', 'Samimi',       'Sıcak, doğal bir dil'),
    'profesyonel':  ('💼', 'Profesyonel',  'Resmi, güven veren'),
    'sıcak':        ('🤝', 'Sıcak',        'Empati odaklı, yakın'),
  };

  // ── Üretilen / düzenlenebilir çıktı ─────────────────────────────────────────
  final _descCtrl        = TextEditingController();
  final _footerCtrl      = TextEditingController();
  final _seoTitleCtrl    = TextEditingController();
  final _seoDescCtrl     = TextEditingController();
  final _seoKeywordsCtrl = TextEditingController();

  int  _remainingGenerations = 0;
  bool _generating           = false;
  bool _generateSuccess      = false;
  bool _saving               = false;
  Map<String, String> _fieldErrors = {};

  // ── Üretim animasyonu ────────────────────────────────────────────────────────
  int    _msgIndex  = 0;
  Timer? _msgTimer;
  late final AnimationController _successCtrl;
  late final Animation<double>   _successScale;

  AppLocalizations get loc => AppLocalizations.of(context);
  List<String> get _generatingMsgs => [
    loc.aiProfileMsgAnalyzing,
    loc.aiProfileMsgPreparing,
    loc.aiProfileMsgSelecting,
    loc.aiProfileMsgSeo,
    loc.aiProfileMsgFinalizing,
  ];

  // ── Tema ────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _themes = [];
  int?    _selectedThemeId;
  int?    _savedThemeId;      // son başarıyla kaydedilen tema
  int?    _userId;
  String? _userSlug;
  bool    _savingTheme       = false;
  WebViewController? _previewController;
  bool    _previewLoading    = false;
  String? _previewUrl;
  String? _previewError;
  String? _previewLastVisitedUrl;

  // ── Linkler ─────────────────────────────────────────────────────────────────
  // type_id → {url, title, is_active}
  final Map<int, Map<String, dynamic>> _linkState = {};
  List<int> _linkOrder = [];   // aktif linklerin görüntülenme sırası
  bool _savingLinks = false;

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowCtrl.dispose();
    _successCtrl.dispose();
    _msgTimer?.cancel();
    _uzmanlikCtrl.dispose();
    _hedefKitleCtrl.dispose();
    _deneyimCtrl.dispose();
    _basariCtrl.dispose();
    _ekNotCtrl.dispose();
    _descCtrl.dispose();
    _footerCtrl.dispose();
    _seoTitleCtrl.dispose();
    _seoDescCtrl.dispose();
    _seoKeywordsCtrl.dispose();
    super.dispose();
  }

  // ─── API: GET /api/ai-profile ────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });

    try {
      final res = await authGet(
        Uri.parse('$apiBaseUrl/api/ai-profile'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final root = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (root['data'] as Map?)?.cast<String, dynamic>() ?? root;

        final profile     = (data['profile']        as Map?)?.cast<String, dynamic>() ?? {};
        final seo         = (data['seo']            as Map?)?.cast<String, dynamic>() ?? {};
        // existing_links may be a List (empty) or a Map (keyed by type_id)
        final rawLinksRaw = data['existing_links'];
        final rawLinks    = rawLinksRaw is Map
            ? rawLinksRaw.cast<String, dynamic>()
            : <String, dynamic>{};
        final themes      = (data['themes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final currentTheme = data['current_theme_id'] as int?;
        final remaining   = data['remaining_generations'] as int? ?? 0;
        final professions = (data['professions'] as List? ?? []).map((e) => e.toString()).toList();

        // link state'i kur
        final newLinkState = <int, Map<String, dynamic>>{};
        rawLinks.forEach((key, val) {
          final m = Map<String, dynamic>.from(val as Map);
          final tid = m['type_id'] as int? ?? int.tryParse(key) ?? 0;
          newLinkState[tid] = {
            'url':       m['url']?.toString() ?? '',
            'title':     m['title']?.toString() ?? (_kLinkTypes[tid]?.title ?? ''),
            'is_active': m['is_active'] as bool? ?? false,
          };
        });

        // Paralel olarak user_id + username'i de çek
        int? userId;
        String? userSlug;
        try {
          final profileRes = await authGet(
            Uri.parse('$apiBaseUrl/api/user/profile'),
            headers: {'Accept': 'application/json'},
          );
          if (profileRes.statusCode == 200) {
            final pd = jsonDecode(profileRes.body) as Map<String, dynamic>;
            final pd2 = (pd['data'] as Map?)?.cast<String, dynamic>() ?? pd;
            userId   = pd2['id'] as int? ?? pd2['user_id'] as int?;
            userSlug = pd2['username']?.toString() ?? pd2['slug']?.toString();
          }
        } catch (_) {}

        setState(() {
          _professions           = professions;
          _themes                = themes;
          _selectedThemeId       = currentTheme;
          _savedThemeId          = currentTheme;
          _remainingGenerations  = remaining;
          _userId                = userId;
          _userSlug              = userSlug;
          _linkState
            ..clear()
            ..addAll(newLinkState);
          // Aktif linkleri önce, sonra pasifler
          _linkOrder = [
            ...newLinkState.keys.where((id) => newLinkState[id]!['is_active'] == true),
            ...newLinkState.keys.where((id) => newLinkState[id]!['is_active'] != true),
            ..._kLinkTypes.keys.where((id) => !newLinkState.containsKey(id)),
          ];

          _descCtrl.text   = profile['description']?.toString() ?? '';
          _footerCtrl.text = profile['footer']?.toString() ?? '';
          _seoTitleCtrl.text    = seo['title']?.toString() ?? '';
          _seoDescCtrl.text     = seo['description']?.toString() ?? '';
          _seoKeywordsCtrl.text = seo['keywords']?.toString() ?? '';
        });

        _updatePreview();
      } else {
        setState(() { _error = loc.aiProfileFetchError(res.statusCode); });
      }
    } catch (e, st) {
      debugPrint('[AiProfilePage] _loadData error: $e\n$st');
      setState(() { _error = loc.aiProfileConnectionError(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── API: POST /api/ai-profile/generate ─────────────────────────────────────

  Future<void> _generateWithAI() async {
    if (!_generateFormKey.currentState!.validate()) return;

    // Mesaj döngüsü başlat
    setState(() { _generating = true; _generateSuccess = false; _fieldErrors = {}; _msgIndex = 0; });
    _msgTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _generatingMsgs.length);
    });

    try {
      final res = await authPost(
        Uri.parse('$apiBaseUrl/api/ai-profile/generate'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'meslek':       _selectedProfession,
          'uzmanlik':     _uzmanlikCtrl.text.trim(),
          'deneyim':      int.tryParse(_deneyimCtrl.text.trim()) ?? 0,
          'hedef_kitle':  _hedefKitleCtrl.text.trim(),
          'ton':          _selectedTon,
          'basari':       _basariCtrl.text.trim(),
          'ek_not':       _ekNotCtrl.text.trim(),
        }),
      );

      final root = _tryDecode(res.body);
      final body = (root?['data'] as Map?)?.cast<String, dynamic>() ?? root;

      if (res.statusCode == 200 && body != null) {
        _msgTimer?.cancel();
        setState(() {
          _descCtrl.text        = body['description']?.toString() ?? '';
          _footerCtrl.text      = body['footer']?.toString() ?? '';
          _seoTitleCtrl.text    = body['seo_title']?.toString() ?? '';
          _seoDescCtrl.text     = body['seo_description']?.toString() ?? '';
          _seoKeywordsCtrl.text = body['seo_keywords']?.toString() ?? '';
          _remainingGenerations = body['remaining_generations'] as int? ?? _remainingGenerations - 1;
          _generateSuccess = true;
          _generating = false;
        });
        _successCtrl.forward(from: 0);
        // 1.8 saniye başarı göster, sonra overlay kapat
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) setState(() { _generateSuccess = false; });
      } else if (res.statusCode == 429) {
        final msg = body?['error']?.toString() ?? root?['message']?.toString() ?? 'Günlük AI limitine ulaştınız.';
        final rem = body?['remaining_generations'] as int? ?? 0;
        setState(() => _remainingGenerations = rem);
        _snack(msg);
      } else if (res.statusCode == 422 && body != null) {
        final errors = (body['errors'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _fieldErrors = errors.map((k, v) {
            final msgs = v is List ? v.join(' ') : v.toString();
            return MapEntry(k, msgs);
          });
        });
        _snack(loc.aiProfileValidationErrors);
      } else {
        _snack(root?['message']?.toString() ?? loc.aiProfileGenerateHttpError(res.statusCode));
      }
    } catch (e) {
      _snack(loc.aiProfileConnectionError(e));
    } finally {
      _msgTimer?.cancel();
      if (mounted) setState(() { _generating = false; _generateSuccess = false; });
    }
  }

  // ─── API: POST /api/ai-profile/save ─────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (_descCtrl.text.trim().length < 20) {
      _snack(loc.aiProfileSaveBioMin);
      return;
    }
    setState(() { _saving = true; _fieldErrors = {}; });

    try {
      final res = await authPost(
        Uri.parse('$apiBaseUrl/api/ai-profile/save'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'description':     _descCtrl.text.trim(),
          'footer':          _footerCtrl.text.trim(),
          'seo_title':       _seoTitleCtrl.text.trim(),
          'seo_description': _seoDescCtrl.text.trim(),
          'seo_keywords':    _seoKeywordsCtrl.text.trim(),
        }),
      );

      final body = _tryDecode(res.body);
      if (res.statusCode == 200) {
        _snack(body?['message']?.toString() ?? loc.aiProfileSaveSuccess);
        // Sadece Profil tab'ındayken Linkler'e geç
        if (_tabController.index == 0) _tabController.animateTo(1);
      } else if (res.statusCode == 422 && body != null) {
        final errors = (body['errors'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _fieldErrors = errors.map((k, v) {
            final msgs = v is List ? v.join(' ') : v.toString();
            return MapEntry(k, msgs);
          });
        });
        _snack(loc.aiProfileValidationErrors);
      } else {
        _snack(body?['message']?.toString() ?? loc.aiProfileSaveHttpError(res.statusCode));
      }
    } catch (e) {
      _snack(loc.aiProfileConnectionError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── API: POST /api/ai-profile/theme ────────────────────────────────────────

  Future<void> _saveTheme(int themeId) async {
    setState(() { _selectedThemeId = themeId; _savingTheme = true; });
    _updatePreview();

    try {
      final res = await authPost(
        Uri.parse('$apiBaseUrl/api/ai-profile/theme'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'theme_id': themeId}),
      );

      final body = _tryDecode(res.body);
      if (res.statusCode == 200) {
        setState(() => _savedThemeId = themeId);
        _snack(body?['message']?.toString() ?? loc.aiProfileThemeApplied);
      } else {
        _snack(body?['message']?.toString() ?? loc.aiProfileThemeHttpError(res.statusCode));
      }
    } catch (e) {
      _snack(loc.aiProfileConnectionError(e));
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  // ─── WebView önizleme ────────────────────────────────────────────────────────

  String? _buildPreviewUrl() {
    if (_userId == null || _selectedThemeId == null) return null;
    return Uri.parse('https://bagla.app/bio-pages/preview/$_userId')
        .replace(queryParameters: {'theme': _selectedThemeId!.toString()})
        .toString();
  }

  void _updatePreview() {
    final url = _buildPreviewUrl();
    if (url == null) {
      setState(() {
        _previewUrl        = null;
        _previewController = null;
        _previewError      = null;
        _previewLoading    = false;
        _previewLastVisitedUrl = null;
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (u) {
          if (mounted) setState(() { _previewLastVisitedUrl = u; });
        },
        onNavigationRequest: (req) {
          if (mounted) setState(() { _previewLastVisitedUrl = req.url; });
          return NavigationDecision.navigate;
        },
        onPageFinished: (u) {
          if (mounted) setState(() { _previewLoading = false; _previewLastVisitedUrl = u; });
        },
        onWebResourceError: (err) {
          final failUrl = err.url ?? _previewLastVisitedUrl ?? url;
          if (mounted) { setState(() {
            _previewLoading = false;
            _previewLastVisitedUrl = failUrl;
            _previewError = 'Önizleme yüklenemedi.\n${err.description}';
          }); }
        },
      ))
      ..loadRequest(Uri.parse(url));

    setState(() {
      _previewUrl        = url;
      _previewController = controller;
      _previewLoading    = true;
      _previewError      = null;
      _previewLastVisitedUrl = url;
    });
  }

  // ─── API: POST /api/ai-profile/links ────────────────────────────────────────

  Future<void> _saveLinks() async {
    setState(() => _savingLinks = true);

    final links         = <Map<String, dynamic>>[];
    final deactivateIds = <int>[];

    // Sıraya göre işle (aktif linkler önce ve kullanıcı sıralamasında)
    final orderedIds = _linkOrder.isNotEmpty
        ? _linkOrder
        : _linkState.keys.toList();

    for (final typeId in orderedIds) {
      final data   = _linkState[typeId];
      if (data == null) continue;
      final url    = (data['url'] as String? ?? '').trim();
      final active = data['is_active'] as bool? ?? false;
      final title  = data['title'] as String? ?? _kLinkTypes[typeId]?.title ?? '';

      if (url.isNotEmpty && active) {
        links.add({'type_id': typeId, 'url': url, 'title': title});
      } else if (!active) {
        deactivateIds.add(typeId);
      }
    }

    try {
      final res = await authPost(
        Uri.parse('$apiBaseUrl/api/ai-profile/links'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'links': links, 'deactivate_ids': deactivateIds}),
      );

      final body = _tryDecode(res.body);
      if (res.statusCode == 200) {
        _snack(body?['message']?.toString() ?? loc.aiProfileLinksSaved);
      } else {
        _snack(body?['message']?.toString() ?? loc.aiProfileLinksHttpError(res.statusCode));
      }
    } catch (e) {
      _snack(loc.aiProfileConnectionError(e));
    } finally {
      if (mounted) setState(() => _savingLinks = false);
    }
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────────────

  Map<String, dynamic>? _tryDecode(String body) {
    try { return jsonDecode(body) as Map<String, dynamic>?; } catch (_) { return null; }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputDeco(String label, {String? errorText, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText:  hint,
      errorText: errorText,
      labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      errorStyle: const TextStyle(fontSize: 11),
      filled:    true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // Normal kart (Çıktı, SEO, Linkler)
  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E1E2D))),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // AI kart — koyu gradient kenarlık
  Widget _aiCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(18.5),
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  void _openBioPreview() {
    if (_userSlug == null) {
      _snack('Kullanıcı bilgisi henüz yüklenmedi.');
      return;
    }
    final url = 'https://bagla.app/@$_userSlug';
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle + başlık
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.preview_outlined,
                              color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bio Sayfası Önizleme',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          color: const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: WebViewWidget(controller: ctrl)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? _buildLoadingScreen()
          : _error != null
              ? _buildError()
              : _buildMain(),
    );
  }

  Widget _buildMainContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: _darkBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 19, color: Colors.white),
            onPressed: () => Navigator.of(context).canPop()
                ? Navigator.of(context).pop()
                : Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainTabsPage(initialIndex: 0)), (_) => false),
          ),
          actions: const [],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildAppBarHero(),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
            indicatorColor: _aiAccent,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            tabs: [
              Tab(text: loc.aiProfileTabProfile),
              Tab(text: loc.aiProfileTabLinks),
              Tab(text: loc.aiProfileTabTheme),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildLinksTab(),
          _buildThemeTab(),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Stack(
      children: [
        _buildMainContent(),
        if (_generating || _generateSuccess) _buildGeneratingOverlay(),
        // save reminder removed — profile tab has a persistent save bar
      ],
    );
  }


  Widget _buildGeneratingOverlay() {
    final isSuccess = _generateSuccess;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: (_generating || _generateSuccess) ? 1.0 : 0.0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: isSuccess ? _buildSuccessContent() : _buildGeneratingContent(),
        ),
      ),
    );
  }

  Widget _buildGeneratingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dönen parlayan halka
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF9333EA), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: _glowAnim.value * 0.8),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 28),

        // Değişen mesaj
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            _generatingMsgs[_msgIndex],
            key: ValueKey(_msgIndex),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          loc.aiProfileMsgWait,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 28),

        // Üç nokta
        _buildDots(),
      ],
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        final v = _glowAnim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final scale = i == 0
                ? v
                : i == 1
                    ? (v + 0.3).clamp(0.5, 1.0)
                    : (v + 0.6).clamp(0.5, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _aiAccent.withValues(alpha: scale),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSuccessContent() {
    return ScaleTransition(
      scale: _successScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            loc.aiProfileGenerateSuccess,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.aiProfileGenerateSuccessHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkBg, Color(0xFF1A0E3A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 40, color: _aiAccent),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: _aiAccent, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(loc.aiProfileLoading,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0B1E), Color(0xFF1E1050), Color(0xFF2D1060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Dekoratif ışık noktaları
          Positioned(top: 30, right: 40,
            child: _glowDot(20, _aiAccent.withValues(alpha: 0.15))),
          Positioned(top: 60, right: 100,
            child: _glowDot(10, Colors.white.withValues(alpha: 0.06))),
          Positioned(top: 15, left: 60,
            child: _glowDot(8, _aiAccent.withValues(alpha: 0.1))),
          Positioned(bottom: 60, right: 30,
            child: _glowDot(14, const Color(0xFF9333EA).withValues(alpha: 0.2))),
          Positioned(bottom: 50, left: 30,
            child: _glowDot(6, Colors.white.withValues(alpha: 0.07))),

          // İçerik
          Positioned(
            left: 0, right: 0, bottom: 52,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: _aiAccent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(20),
                    color: _aiAccent.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: _aiAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(loc.aiProfileAiBadge,
                          style: TextStyle(color: _aiAccent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(loc.aiProfileTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(loc.aiProfileSubtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowDot(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ─── Hata ekranı ─────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      color: _bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                child: Text(loc.aiProfileRetry, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 1: Profil ───────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGenerateForm(),
                _buildBioPreviewButton(),
                _buildOutputSection(),
                _buildSeoSection(),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_saving || _generating) ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? loc.aiProfileSaving : loc.aiProfileSave),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateForm() {
    final canGenerate = _remainingGenerations > 0;

    return _aiCard(
      child: Form(
        key: _generateFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + hak sayacı
            Row(
              children: [
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
                      ),
                      boxShadow: canGenerate ? [
                        BoxShadow(
                          color: _primary.withValues(alpha: _glowAnim.value * 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ] : [],
                    ),
                    child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.aiProfileGenerateTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(loc.aiProfileGenerateSubtitle,
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                    ],
                  ),
                ),
                // Kalan hak pill
                _buildRemainingPill(),
              ],
            ),
            const SizedBox(height: 20),

            // Meslek
            _aiDropdown(
              label: loc.aiProfileFieldProfession,
              value: _selectedProfession,
              items: _professions,
              error: _fieldErrors['meslek'],
              onChanged: (v) => setState(() => _selectedProfession = v),
              validator: (v) => (v == null || v.isEmpty) ? loc.aiProfileFieldProfessionError : null,
            ),
            const SizedBox(height: 12),

            _aiField(_uzmanlikCtrl, loc.aiProfileFieldExpertise,
                hint: loc.aiProfileFieldExpertiseHint,
                error: _fieldErrors['uzmanlik'],
                validator: (v) => v!.trim().isEmpty ? loc.aiProfileFieldExpertiseError : null),
            const SizedBox(height: 12),

            _aiField(_hedefKitleCtrl, loc.aiProfileFieldAudience,
                hint: loc.aiProfileFieldAudienceHint,
                error: _fieldErrors['hedef_kitle'],
                validator: (v) => v!.trim().isEmpty ? loc.aiProfileFieldAudienceError : null),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _aiField(_deneyimCtrl, loc.aiProfileFieldExperience,
                    hint: loc.aiProfileFieldExperienceHint,
                    error: _fieldErrors['deneyim'],
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 50) return loc.aiProfileFieldExperienceError;
                      return null;
                    }),
              ),
            ]),
            const SizedBox(height: 12),
            _buildTonCards(),
            const SizedBox(height: 12),

            _aiField(_basariCtrl, loc.aiProfileFieldAchievement,
                hint: loc.aiProfileFieldAchievementHint,
                error: _fieldErrors['basari']),
            const SizedBox(height: 12),

            _aiField(_ekNotCtrl, loc.aiProfileFieldNote,
                hint: loc.aiProfileFieldNoteHint,
                maxLines: 2,
                error: _fieldErrors['ek_not']),
            const SizedBox(height: 20),

            // Generate butonu
            _buildGenerateButton(canGenerate),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingPill() {
    // Toplam hak sabit 5 kabul ediyoruz; API'den gelen remaining üzerinden dolu/boş hesapla
    const total = 5;
    final used  = (total - _remainingGenerations).clamp(0, total);
    final has   = _remainingGenerations > 0;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: has
              ? _primary.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: has
                ? _aiAccent.withValues(alpha: _glowAnim.value * 0.6)
                : Colors.orange.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nokta indikatörleri
            ...List.generate(total, (i) {
              final filled = i < (total - used);
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? _aiAccent.withValues(alpha: _glowAnim.value * 0.4 + 0.6)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              );
            }),
            const SizedBox(width: 5),
            Text(
              has ? '$_remainingGenerations' : '0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: has ? _aiAccent : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(bool canGenerate) {
    if (!canGenerate) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(loc.aiProfileGenerateLocked,
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => GestureDetector(
        onTap: _generating ? null : _generateWithAI,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF9333EA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: _glowAnim.value * 0.5),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_generating)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                _generating ? loc.aiProfileGenerating : loc.aiProfileGenerateButton,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Koyu tema input field
  Widget _aiField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    String? error,
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFF87171)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _aiAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
        ),
      ),
    );
  }

  // Koyu tema dropdown
  Widget _aiDropdown({
    required String label,
    required String? value,
    required List<String> items,
    String? error,
    String Function(String)? displayText,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF1E1B3A),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFF87171)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _aiAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
        ),
      ),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.4)),
      items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Text(displayText != null ? displayText(i) : i,
            style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildBioPreviewButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: _openBioPreview,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0E1A), Color(0xFF1E1050), Color(0xFF2D1060)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _aiAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _aiAccent.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.preview_outlined,
                    color: _aiAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dönüşüm Sayfam',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Takipçileri randevuya dönüştür',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _aiAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _aiAccent.withValues(alpha: 0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Görüntüle',
                      style: TextStyle(
                        color: _aiAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: _aiAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutputSection() {
    return _card(
      title: loc.aiProfileTabProfile,
      icon: Icons.person_outline,
      child: Column(
        children: [
          TextFormField(
            controller: _descCtrl,
            maxLines: null,
            decoration: _inputDeco(loc.aiProfileFieldBio,
                errorText: _fieldErrors['description']),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _footerCtrl,
            decoration: _inputDeco(loc.aiProfileFieldFooter,
                errorText: _fieldErrors['footer']),
          ),
        ],
      ),
    );
  }

  Widget _buildSeoSection() {
    return _card(
      title: loc.aiProfileSectionSeo,
      icon: Icons.search_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Google Önizlemesi ──────────────────────────────────────────
          _buildGooglePreview(),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // ── Alanlar ───────────────────────────────────────────────────
          TextFormField(
            controller: _seoTitleCtrl,
            maxLength: 70,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(loc.aiProfileFieldSeoTitle,
                errorText: _fieldErrors['seo_title']),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _seoDescCtrl,
            maxLines: 3,
            maxLength: 170,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(loc.aiProfileFieldSeoDesc,
                errorText: _fieldErrors['seo_description']),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _seoKeywordsCtrl,
            maxLength: 300,
            decoration: _inputDeco(loc.aiProfileFieldSeoKeywords,
                errorText: _fieldErrors['seo_keywords']),
          ),
        ],
      ),
    );
  }

  Widget _buildGooglePreview() {
    final rawTitle = _seoTitleCtrl.text.trim();
    final rawDesc  = _seoDescCtrl.text.trim();
    final slug     = _userSlug ?? 'kullanici';
    final url      = 'bagla.app/$slug';

    // Karakter sınırlarına göre kes (Google'ın piksel bazlı kesme yerine
    // karakter tahmini: ~60 karakter başlık, ~155 açıklama)
    const titleMax = 60;
    const descMax  = 155;
    final title    = rawTitle.isEmpty
        ? 'Sayfa Başlığı'
        : rawTitle.length > titleMax
            ? '${rawTitle.substring(0, titleMax)}...'
            : rawTitle;
    final desc     = rawDesc.isEmpty
        ? 'Meta açıklama buraya gelecek. Sayfanızı arama sonuçlarında nasıl tanıtmak istediğinizi yazın.'
        : rawDesc.length > descMax
            ? '${rawDesc.substring(0, descMax)}...'
            : rawDesc;

    final titleLen  = rawTitle.length;
    final descLen   = rawDesc.length;

    Color _barColor(int len, int max) {
      final ratio = len / max;
      if (ratio < 0.5) return const Color(0xFF9CA3AF);
      if (ratio <= 1.0) return const Color(0xFF10B981);
      return const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiket
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('G',
                  style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
            const SizedBox(width: 8),
            const Text('Google Arama Önizlemesi',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
          ],
        ),
        const SizedBox(height: 10),

        // Önizleme kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Favicon + URL
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(Icons.link,
                        color: Colors.white, size: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('bagla.app',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF202124),
                                fontWeight: FontWeight.w500)),
                        Text(url,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5F6368)),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Başlık (mavi, tıklanabilir görünüm)
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A0DAB),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),

              // Açıklama
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF4D5156),
                  fontSize: 12,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Karakter sayaçları
        Row(
          children: [
            _seoCounter('Başlık', titleLen, 60, _barColor(titleLen, 60)),
            const SizedBox(width: 12),
            _seoCounter('Açıklama', descLen, 155, _barColor(descLen, 155)),
          ],
        ),
        const SizedBox(height: 10),

        // SEO Skoru Badge
        _buildSeoScoreBadge(titleLen, descLen, _seoKeywordsCtrl.text.trim()),
      ],
    );
  }

  Widget _buildSeoScoreBadge(int titleLen, int descLen, String keywords) {
    int score = 0;
    // Başlık: 30-60 ideal
    if (titleLen >= 30 && titleLen <= 60) score += 2;
    else if (titleLen > 0) score += 1;
    // Açıklama: 80-155 ideal
    if (descLen >= 80 && descLen <= 155) score += 2;
    else if (descLen > 0) score += 1;
    // Keywords: var mı
    if (keywords.isNotEmpty) score += 2;

    final (label, color, icon) = switch (score) {
      0     => ('Zayıf',     const Color(0xFF9CA3AF), Icons.signal_cellular_0_bar),
      1 || 2 => ('Orta',    const Color(0xFFF59E0B), Icons.signal_cellular_alt_1_bar),
      3 || 4 => ('İyi',     const Color(0xFF10B981), Icons.signal_cellular_alt_2_bar),
      _      => ('Mükemmel', const Color(0xFF6366F1), Icons.signal_cellular_alt),
    };

    return Row(
      children: [
        const Text('SEO Skoru:',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seoCounter(String label, int len, int max, Color barColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280))),
              const Spacer(),
              Text('$len / $max',
                  style: TextStyle(
                      fontSize: 11,
                      color: barColor,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (len / max).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Tema ─────────────────────────────────────────────────────────────

  Widget _buildThemeTab() {
    if (_themes.isEmpty) {
      return Center(
        child: Text(
          loc.aiProfileThemeNoPreview,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    final selectedName = _themes
        .firstWhere((t) => t['id'] == _selectedThemeId,
            orElse: () => _themes.first)['name']
        ?.toString() ?? '';

    return Column(
      children: [
        // ── Üst bilgi + progress ──────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _savingTheme ? 3 : 0,
          child: const LinearProgressIndicator(
            color: _primary,
            backgroundColor: Color(0xFFE5E7EB),
          ),
        ),

        // ── Otomatik kayıt bilgisi ────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _savedThemeId == _selectedThemeId && !_savingTheme
                    ? Row(
                        key: const ValueKey('saved'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '"$selectedName" aktif',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('info'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_outlined,
                              size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Text(
                            'Temaya tıklayınca otomatik kaydedilir',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // ── ChoiceChip satırı ─────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _themes.map((theme) {
                  final id         = theme['id'] as int?;
                  final name       = theme['name']?.toString() ?? '';
                  final isSelected = id != null && id == _selectedThemeId;
                  final isSaved    = id != null && id == _savedThemeId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name),
                          if (isSaved && !_savingTheme) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle,
                                size: 12, color: Color(0xFF10B981)),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: _savingTheme || id == null
                          ? null
                          : (_) => _saveTheme(id),
                      selectedColor: _primary.withValues(alpha: 0.15),
                      backgroundColor: const Color(0xFFF3F4F6),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? _primary
                            : const Color(0xFF374151),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? _primary
                            : Colors.transparent,
                        width: isSelected ? 1.5 : 0,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE5E7EB)),

        // ── Canlı önizleme ────────────────────────────────────────────────
        Expanded(child: _buildWebViewPreview()),

        // ── Alt aksiyon çubuğu ────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Profil & Linkler'e dön
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.link_outlined, size: 16),
                    label: const Text('Linklerimi Düzenle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Tamamla → Dashboard
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const MainTabsPage(initialIndex: 0)),
                        (_) => false),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Tamamlandı'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebViewPreview() {
    if (_previewUrl == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _userId == null
                  ? loc.aiProfileThemeNoUser
                  : loc.aiProfileThemeNoPreview,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: Stack(
              children: [
                if (_previewController != null)
                  WebViewWidget(controller: _previewController!),
                if (_previewLoading)
                  Container(
                    color: const Color(0xFFF9FAFB),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: _primary, strokeWidth: 2),
                          SizedBox(height: 12),
                          Text('Önizleme yükleniyor...',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                if (_previewError != null && !_previewLoading)
                  Container(
                    color: const Color(0xFFFFF7F7),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_outlined,
                                color: Colors.redAccent, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'Önizleme yüklenemedi',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _updatePreview,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Link şablonları ─────────────────────────────────────────────────────────

  static const List<({String name, String emoji, List<int> activeIds})> _kLinkTemplates = [
    (
      name: 'Diyetisyen',
      emoji: '🥗',
      activeIds: [2, 11, 5, 10, 9, 14], // Instagram, WhatsApp, YouTube, Telefon, E-posta, Web
    ),
    (
      name: 'Psikolog',
      emoji: '🧠',
      activeIds: [2, 4, 9, 11, 32, 14], // Instagram, LinkedIn, E-posta, WhatsApp, Zoom, Web
    ),
    (
      name: 'Fizyoterapist',
      emoji: '💪',
      activeIds: [2, 11, 5, 10, 9, 13], // Instagram, WhatsApp, YouTube, Telefon, E-posta, Konum
    ),
    (
      name: 'Kişisel Antrenör',
      emoji: '🏋️',
      activeIds: [2, 6, 5, 11, 10, 9], // Instagram, TikTok, YouTube, WhatsApp, Telefon, E-posta
    ),
    (
      name: 'Güzellik Uzmanı',
      emoji: '💅',
      activeIds: [2, 6, 11, 10, 1, 9], // Instagram, TikTok, WhatsApp, Telefon, Facebook, E-posta
    ),
    (
      name: 'Koç & Danışman',
      emoji: '🎯',
      activeIds: [4, 2, 5, 32, 9, 14], // LinkedIn, Instagram, YouTube, Zoom, E-posta, Web
    ),
  ];

  void _applyLinkTemplate(List<int> activeIds) {
    setState(() {
      for (final id in _kLinkTypes.keys) {
        _linkState.putIfAbsent(id, () => {
          'url': '', 'title': _kLinkTypes[id]!.title, 'is_active': false,
        });
        _linkState[id]!['is_active'] = activeIds.contains(id);
      }
      // Aktifler şablon sırasında önce, pasifler sonra
      _linkOrder = [
        ...activeIds.where((id) => _kLinkTypes.containsKey(id)),
        ..._kLinkTypes.keys.where((id) => !activeIds.contains(id)),
      ];
    });
  }

  Widget _buildLinkTemplatesBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6366F1)),
              SizedBox(width: 6),
              Text(
                'Mesleğine göre hızlı seç',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _kLinkTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _kLinkTemplates[i];
                return GestureDetector(
                  onTap: () => _applyLinkTemplate(t.activeIds),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          t.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 3: Linkler ──────────────────────────────────────────────────────────

  Widget _buildLinksTab() {
    // _linkOrder yoksa başlat
    if (_linkOrder.isEmpty) {
      _linkOrder = [
        ..._kLinkTypes.keys.where((id) =>
            _linkState[id]?['is_active'] == true),
        ..._kLinkTypes.keys.where((id) =>
            _linkState[id]?['is_active'] != true),
      ];
    }

    return Column(
      children: [
        // Şablon seçici
        _buildLinkTemplatesBar(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),

        // Bilgi çubuğu
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator,
                  size: 16, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              const Text(
                'Aktif linkleri sürükle-bırak ile sırala',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),

        // Sıralanabilir liste
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: _linkOrder.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final tid = _linkOrder.removeAt(oldIdx);
                _linkOrder.insert(newIdx, tid);
              });
            },
            proxyDecorator: (child, idx, anim) => Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              shadowColor: _primary.withValues(alpha: 0.3),
              child: child,
            ),
            itemBuilder: (context, idx) {
              final tid = _linkOrder[idx];
              if (!_kLinkTypes.containsKey(tid)) {
                return const SizedBox.shrink(key: ValueKey('skip'));
              }
              return _buildLinkRow(tid,
                  key: ValueKey('link_$tid'));
            },
          ),
        ),

        // Kaydet butonu
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _savingLinks ? null : _saveLinks,
                icon: _savingLinks
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_savingLinks
                    ? loc.aiProfileLinksSaving
                    : loc.aiProfileLinksSave),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(int typeId, {Key? key}) {
    final meta   = _kLinkTypes[typeId]!;
    final data   = _linkState.putIfAbsent(typeId, () => {
      'url': '', 'title': meta.title, 'is_active': false,
    });
    final active = data['is_active'] as bool? ?? false;
    final ctrl   = _getLinkCtrl(typeId, data['url']?.toString() ?? '');

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? meta.color.withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8, right: 12, top: 2, bottom: 2),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle_rounded,
                    size: 18,
                    color: const Color(0xFFD1D5DB)),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: meta.color.withValues(alpha: active ? 1.0 : 0.15),
                  child: Icon(meta.icon, size: 16,
                      color: active ? Colors.white : meta.color.withValues(alpha: 0.6)),
                ),
              ],
            ),
            title: Text(meta.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? const Color(0xFF1E1E2D) : const Color(0xFF9CA3AF),
                )),
            trailing: Switch(
              value: active,
              activeThumbColor: meta.color,
              onChanged: (v) {
                setState(() => _linkState[typeId]!['is_active'] = v);
              },
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: ctrl,
                onChanged: (v) => _linkState[typeId]!['url'] = v,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: _linkHint(typeId),
                  hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: meta.color),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Her typeId için controller cache
  final Map<int, TextEditingController> _linkCtrls = {};

  TextEditingController _getLinkCtrl(int typeId, String initialUrl) {
    if (!_linkCtrls.containsKey(typeId)) {
      _linkCtrls[typeId] = TextEditingController(text: initialUrl);
    }
    return _linkCtrls[typeId]!;
  }

  // ── Ton kartları ─────────────────────────────────────────────────────────────

  Widget _buildTonCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.aiProfileFieldTone,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: _tonOptions.map((ton) {
            final meta      = _tonMeta[ton]!;
            final isSelected = _selectedTon == ton;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTon = ton),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _aiAccent
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(meta.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(meta.$2,
                          style: TextStyle(
                            color: isSelected ? _aiAccent : Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 2),
                      Text(meta.$3,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _linkHint(int typeId) {
    switch (typeId) {
      case 1:  return 'https://facebook.com/kullanici';
      case 2:  return 'https://instagram.com/kullanici';
      case 3:  return 'https://x.com/kullanici';
      case 4:  return 'https://linkedin.com/in/kullanici';
      case 5:  return 'https://youtube.com/@kanal';
      case 6:  return 'https://tiktok.com/@kullanici';
      case 9:  return 'mailto:ornek@email.com';
      case 10: return 'tel:+905321234567';
      case 11: return 'https://wa.me/905321234567';
      case 12: return '@kullanici_adi';
      case 13: return 'https://maps.google.com/?q=...';
      case 14: return 'https://siteniz.com';
      case 32: return 'https://zoom.us/j/toplanti-id';
      case 39: return 'https://threads.net/@kullanici';
      default: return 'https://...';
    }
  }
}
