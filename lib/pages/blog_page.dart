import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../main_tabs_page.dart';

// ── Renkler ───────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kBg = Color(0xFFF3F4F8);
const _kInk = Color(0xFF1E1E2D);
const _kMuted = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);

// Kategori slug'ına göre sabit renk (görsel ayrım için).
const List<Color> _kCatColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFFEC4899), // pink
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // violet
];

Color _colorForSlug(String? slug) {
  if (slug == null || slug.isEmpty) return _kAccent;
  return _kCatColors[slug.hashCode.abs() % _kCatColors.length];
}

// ── Modeller ──────────────────────────────────────────────────────────────────

class BlogCategory {
  final String name;
  final String slug;
  final int postsCount;

  const BlogCategory({
    required this.name,
    required this.slug,
    this.postsCount = 0,
  });

  factory BlogCategory.fromJson(Map<String, dynamic> j) => BlogCategory(
        name: j['name']?.toString() ?? '',
        slug: j['slug']?.toString() ?? '',
        postsCount: (j['posts_count'] as num?)?.toInt() ?? 0,
      );
}

class BlogPostCard {
  final int id;
  final String title;
  final String? excerpt;
  final String? thumbnail;
  final String? categoryName;
  final String? categorySlug;
  final String webUrl;
  final DateTime? publishedAt;

  const BlogPostCard({
    required this.id,
    required this.title,
    this.excerpt,
    this.thumbnail,
    this.categoryName,
    this.categorySlug,
    required this.webUrl,
    this.publishedAt,
  });

  factory BlogPostCard.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map?;
    return BlogPostCard(
      id: (j['id'] as num).toInt(),
      title: j['title']?.toString() ?? '',
      excerpt: j['excerpt']?.toString(),
      thumbnail: j['thumbnail']?.toString(),
      categoryName: cat?['name']?.toString(),
      categorySlug: cat?['slug']?.toString(),
      webUrl: j['web_url']?.toString() ?? '',
      publishedAt: DateTime.tryParse(j['published_at']?.toString() ?? ''),
    );
  }
}

// ── API ───────────────────────────────────────────────────────────────────────

class BlogApi {
  static Future<List<BlogCategory>> categories() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/blog/categories'),
      headers: const {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return [];
    final data = (jsonDecode(res.body)['data'] as List? ?? []);
    return data
        .map((e) => BlogCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Sayfalı yazı listesi. `hasMore` ile birlikte döner.
  static Future<({List<BlogPostCard> items, bool hasMore})> posts({
    String? categorySlug,
    int page = 1,
    int perPage = 10,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (categorySlug != null && categorySlug.isNotEmpty) 'category': categorySlug,
    };
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/blog').replace(queryParameters: qp),
      headers: const {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      return (items: <BlogPostCard>[], hasMore: false);
    }
    final decoded = jsonDecode(res.body);
    final data = (decoded['data'] as List? ?? []);
    final hasMore = decoded['meta']?['has_more'] == true;
    final items = data
        .map((e) => BlogPostCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (items: items, hasMore: hasMore);
  }
}

// ── WebView (web sayfasını app içinde açar → trafik web'e gider) ───────────────

class BlogWebViewPage extends StatefulWidget {
  final String url;
  final String title;
  const BlogWebViewPage({super.key, required this.url, required this.title});

  @override
  State<BlogWebViewPage> createState() => _BlogWebViewPageState();
}

class _BlogWebViewPageState extends State<BlogWebViewPage> {
  late final WebViewController _wc;
  bool _loading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: _kBorder,
                  valueColor: const AlwaysStoppedAnimation(_kAccent),
                )
              : const Divider(height: 1, color: _kBorder),
        ),
      ),
      body: WebViewWidget(controller: _wc),
    );
  }
}

void openBlogPost(BuildContext context, BlogPostCard post) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlogWebViewPage(url: post.webUrl, title: post.title),
    ),
  );
}

// ── Ortak: thumbnail / placeholder ────────────────────────────────────────────

Widget _thumb(BlogPostCard post, {double? width, double? height, double radius = 12}) {
  final color = _colorForSlug(post.categorySlug);
  final placeholder = Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(Icons.article_outlined, color: color.withValues(alpha: 0.6), size: 28),
  );

  if (post.thumbnail == null || post.thumbnail!.isEmpty) return placeholder;

  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.network(
      post.thumbnail!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (ctx, child, prog) =>
          prog == null ? child : placeholder,
    ),
  );
}

String _fmtDate(DateTime? dt) {
  if (dt == null) return '';
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

Widget _categoryBadge(BlogPostCard post) {
  if (post.categoryName == null) return const SizedBox.shrink();
  final color = _colorForSlug(post.categorySlug);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      post.categoryName!,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

// ── Dashboard şeridi (yatay, kendi verisini çeker) ────────────────────────────

class BlogHighlightsStrip extends StatefulWidget {
  const BlogHighlightsStrip({super.key});

  @override
  State<BlogHighlightsStrip> createState() => _BlogHighlightsStripState();
}

class _BlogHighlightsStripState extends State<BlogHighlightsStrip> {
  List<BlogPostCard> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await BlogApi.posts(perPage: 6);
      if (mounted) setState(() { _items = res.items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.menu_book_rounded, size: 17, color: _kAccent),
              ),
              const SizedBox(width: 10),
              const Text('İçerikler',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BlogPage())),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Tümünü gör',
                    style: TextStyle(
                        color: _kAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
        // Yatay kayan kartlar
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _HighlightCard(post: _items[i]),
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final BlogPostCard post;
  const _HighlightCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openBlogPost(context, post),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(post, width: 220, height: 110, radius: 0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _categoryBadge(post),
                    const SizedBox(height: 7),
                    Flexible(
                      child: Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: _kInk),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tam Blog sayfası (kategori filtreli + sonsuz kaydırma) ────────────────────

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final _scroll = ScrollController();

  List<BlogCategory> _categories = [];
  final List<BlogPostCard> _posts = [];
  String? _activeSlug; // null = Tümü

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final cats = await BlogApi.categories();
    if (mounted) setState(() => _categories = cats);
    await _loadFirstPage();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _posts.clear();
    });
    try {
      final res = await BlogApi.posts(categorySlug: _activeSlug, page: 1);
      setState(() {
        _posts.addAll(res.items);
        _hasMore = res.hasMore;
      });
    } catch (_) {
      setState(() => _error = 'İçerikler yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final res = await BlogApi.posts(categorySlug: _activeSlug, page: next);
      setState(() {
        _page = next;
        _posts.addAll(res.items);
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // sessizce geç; kullanıcı tekrar kaydırınca yeniden dener
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectCategory(String? slug) {
    if (slug == _activeSlug) return;
    setState(() => _activeSlug = slug);
    _loadFirstPage();
  }

  // Drawer'dan pushReplacement ile gelindiğinde stack'te alt rota kalmaz;
  // pop edilemiyorsa ana ekrana (dashboard sekmesine) dön.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainTabsPage(initialIndex: 0),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Blog',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: _categoryChips(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _posts.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _loadFirstPage,
                      child: ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (i >= _posts.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          return _BlogListCard(post: _posts[i]);
                        },
                      ),
                    ),
    );
  }

  Widget _categoryChips() {
    return Container(
      height: 57,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _chip('Tümü', null),
          for (final c in _categories) _chip(c.name, c.slug),
        ],
      ),
    );
  }

  Widget _chip(String label, String? slug) {
    final active = slug == _activeSlug;
    final color = slug == null ? _kAccent : _colorForSlug(slug);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _selectCategory(slug),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? color : color.withValues(alpha: 0.25)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyView() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.menu_book_outlined, size: 52, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Center(
            child: Text('Bu kategoride henüz içerik yok',
                style: TextStyle(color: _kMuted, fontWeight: FontWeight.w500)),
          ),
        ],
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadFirstPage, child: const Text('Tekrar dene')),
          ],
        ),
      );
}

class _BlogListCard extends StatelessWidget {
  final BlogPostCard post;
  const _BlogListCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openBlogPost(context, post),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(post, width: double.infinity, height: 160, radius: 0),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _categoryBadge(post),
                      const Spacer(),
                      if (post.publishedAt != null)
                        Text(_fmtDate(post.publishedAt),
                            style: const TextStyle(color: _kMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    post.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: _kInk),
                  ),
                  if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, height: 1.5, color: Color(0xFF6B7280)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Devamını oku',
                          style: TextStyle(
                              color: _colorForSlug(post.categorySlug),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 15, color: _colorForSlug(post.categorySlug)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
