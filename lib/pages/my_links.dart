import 'dart:convert';
import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:bagla_mobile/main_tabs_page.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
class _T {
  // Backgrounds
  static const bg = Color(0xFFF5F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF9FAFB);

  // Borders
  static const border = Color(0xFFE8EAF0);

  // Accent
  static const accent = Color(0xFF5B5FD9);
  static const accentLight = Color(0xFFEEEEFF);
  static const accentMid = Color(0xFFABADF0);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFFB0B7C3);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFEF4444);
  static const dangerBg = Color(0xFFFEF2F2);
}

class MyLinksPage extends StatefulWidget {
  const MyLinksPage({super.key});

  @override
  State<MyLinksPage> createState() => _MyLinksPageState();
}

class _MyLinksPageState extends State<MyLinksPage>
    with SingleTickerProviderStateMixin {
  AppLocalizations get loc => AppLocalizations.of(context);

  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  List<Map<String, dynamic>> links = [];
  List<Map<String, dynamic>> linkTypes = [];
  List<Map<String, dynamic>> colors = [];

  int? selectedLinkTypeId;
  int? selectedColorId;

  bool settingsLoading = true;
  bool isSubmitting = false;
  Set<int> deletingIds = {};
  bool isLoading = true;
  bool showForm = false;
  bool isSavingOrder = false;
  String typeSearchQuery = '';

  late final AnimationController _formAnimCtrl;
  late final Animation<double> _formAnim;

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabsPage(initialIndex: 0)),
      (_) => false,
    );
  }

  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      _goHome();
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _formAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _formAnim = CurvedAnimation(parent: _formAnimCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchProfileData();
      fetchLinkTypesAndColors();
    });
  }

  @override
  void dispose() {
    _formAnimCtrl.dispose();
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    return getAccessToken();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> fetchProfileData() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    final response = await authGet(
      Uri.parse('$apiBaseUrl/api/user/profile'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      setState(() {
        final raw = data['links'];
        links = raw is List
            ? List<Map<String, dynamic>>.from(raw)
            : <Map<String, dynamic>>[];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchLinkTypesAndColors() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() => settingsLoading = false);
      return;
    }

    try {
      final responses = await Future.wait([
        authGet(Uri.parse('$apiBaseUrl/api/settings/link-types'),
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
        authGet(Uri.parse('$apiBaseUrl/api/settings/colors'),
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
      ]);

      List<Map<String, dynamic>> decodeResponse(http.Response r) {
        if (r.statusCode != 200) return [];
        final d = json.decode(r.body);
        final list = d is List ? d : (d is Map<String, dynamic> ? d['data'] : null);
        if (list is List) return List<Map<String, dynamic>>.from(list);
        if (list is Map<String, dynamic>) return [Map<String, dynamic>.from(list)];
        if (d is Map<String, dynamic>) return [d];
        return [];
      }

      if (!mounted) return;
      final ft = decodeResponse(responses[0]);
      final fc = decodeResponse(responses[1]);

      setState(() {
        linkTypes = ft;
        colors = fc;
        selectedLinkTypeId ??= ft.isNotEmpty ? ft.first['id'] : null;
        selectedColorId ??= fc.isNotEmpty ? fc.first['id'] : null;
        settingsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => settingsLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _resolveTypeName(dynamic typeId) {
    if (typeId == null) return '';
    final m = linkTypes.firstWhere((t) => t['id'] == typeId, orElse: () => {});
    return m['name'] ?? m['title'] ?? (m.isNotEmpty ? loc.myLinksTypeFallback(m['id']) : '');
  }

  String? _resolveTypeValue(dynamic typeId) {
    if (typeId == null) return null;
    final m = linkTypes.firstWhere((t) => t['id'] == typeId, orElse: () => {});
    return m['type'] ?? m['alias'];
  }

  String _resolveColorName(dynamic colorId) {
    if (colorId == null) return '';
    final m = colors.firstWhere((c) => c['id'] == colorId, orElse: () => {});
    return m['name'] ?? m['title'] ?? m['color'] ?? '';
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return _T.textMuted;
    final cleaned = hex.replaceAll('#', '');
    final buf = StringBuffer();
    if (cleaned.length == 6) buf.write('ff');
    buf.write(cleaned);
    try {
      return Color(int.parse(buf.toString(), radix: 16));
    } catch (_) {
      return _T.textMuted;
    }
  }

  String _getPlaceholder(String? type) {
    switch (type) {
      case 'whatsapp': case 'phone': case 'sms': return '+15xxxxxxxxx';
      case 'email': return 'xxx@sample.com';
      case 'telegram': return 'https://t.me/username';
      default: return 'https://example.com';
    }
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: error ? _T.dangerBg : _T.successBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: error ? _T.danger.withValues(alpha: 0.4) : _T.success.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? _T.danger : _T.success,
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: error ? _T.danger : _T.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> createLink() async {
    final token = await _getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty || selectedLinkTypeId == null || selectedColorId == null) {
      _snack(loc.myLinksCreateRequired, error: true);
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final r = await authPost(
        Uri.parse('$apiBaseUrl/api/links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type_id': selectedLinkTypeId,
          'title': _titleCtrl.text,
          'url': _urlCtrl.text,
          'color_id': selectedColorId,
        }),
      );
      if (!mounted) return;
      if (r.statusCode == 200 || r.statusCode == 201) {
        await fetchProfileData();
        if (!mounted) return;
        _titleCtrl.clear();
        _urlCtrl.clear();
        setState(() => showForm = false);
        _formAnimCtrl.reverse();
        _snack(loc.myLinksCreateSuccess);
      } else {
        final d = jsonDecode(r.body);
        _snack(d['message'] ?? d['errors']?.toString() ?? loc.myLinksCreateFailed, error: true);
      }
    } catch (_) {
      if (mounted) _snack(loc.myLinksCreateError, error: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> deleteLink(int id) async {
    final token = await _getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _snack(loc.myLinksTokenMissing, error: true);
      return;
    }

    setState(() => deletingIds.add(id));
    try {
      final r = await authDelete(
        Uri.parse('$apiBaseUrl/api/links/$id'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (r.statusCode == 200 || r.statusCode == 204) {
        await fetchProfileData();
        if (mounted) _snack(loc.myLinksDeleteSuccess);
      } else {
        final d = jsonDecode(r.body);
        _snack(d['message'] ?? loc.myLinksDeleteFailed, error: true);
      }
    } catch (_) {
      if (mounted) _snack(loc.myLinksDeleteError, error: true);
    } finally {
      if (mounted) setState(() => deletingIds.remove(id));
    }
  }

  Future<void> updateLink({
    required int id,
    required String title,
    required String url,
    required int typeId,
    required int colorId,
  }) async {
    final token = await _getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _snack(loc.myLinksTokenMissing, error: true);
      return;
    }

    final r = await authPut(
      Uri.parse('$apiBaseUrl/api/links/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'type_id': typeId, 'title': title, 'url': url, 'color_id': colorId}),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      await fetchProfileData();
      if (mounted) _snack(loc.myLinksUpdateSuccess);
    } else {
      final d = jsonDecode(r.body);
      _snack(d['message'] ?? loc.myLinksUpdateFailed, error: true);
    }
  }

  Future<void> _persistOrder() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;
    setState(() => isSavingOrder = true);
    try {
      final orders = [
        for (int i = 0; i < links.length; i++)
          if (links[i]['id'] != null) {'id': links[i]['id'], 'order': i}
      ];
      await authPost(
        Uri.parse('$apiBaseUrl/api/links/reorder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'orders': orders}),
      );
    } catch (_) {}
    if (mounted) setState(() => isSavingOrder = false);
  }

  // ── Edit sheet ────────────────────────────────────────────────────────────

  void _openEditSheet(Map<String, dynamic> link) {
    final id = link['id'];
    if (id == null) return;

    final titleCtrl = TextEditingController(text: link['title']?.toString() ?? '');
    final urlCtrl = TextEditingController(text: link['url']?.toString() ?? '');
    int? typeId = link['type_id'] ?? link['typeId'] ?? (link['type'] != null ? link['type']['id'] : null);
    int? colorId = link['color_id'] ?? link['colorId'] ?? (link['color']?['id']);
    String localQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = linkTypes.where((t) {
            final n = (t['name'] ?? t['title'] ?? '').toString().toLowerCase();
            return n.contains(localQuery);
          }).toList();
          final effectiveType = filtered.any((t) => t['id'] == typeId) ? typeId : null;

          return Container(
            decoration: const BoxDecoration(
              color: _T.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _T.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    loc.myLinksEditTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _T.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MinimalField(
                    hint: loc.myLinksSearchType,
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) => setModal(() => localQuery = v.toLowerCase()),
                  ),
                  const SizedBox(height: 10),
                  _MinimalDropdown<int>(
                    label: loc.myLinksLinkType,
                    value: effectiveType,
                    items: filtered.isEmpty
                        ? [DropdownMenuItem(value: null, child: Text(loc.myLinksNoResults, style: const TextStyle(color: _T.textMuted)))]
                        : filtered.map((t) => DropdownMenuItem<int>(
                              value: t['id'],
                              child: Text(t['name'] ?? t['title'] ?? ''),
                            )).toList(),
                    onChanged: filtered.isEmpty ? null : (v) => setModal(() => typeId = v),
                  ),
                  const SizedBox(height: 10),
                  _MinimalField(
                    controller: titleCtrl,
                    hint: loc.myLinksTitleLabel,
                    prefixIcon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 10),
                  _MinimalField(
                    controller: urlCtrl,
                    hint: loc.myLinksUrlLabel,
                    placeholder: _getPlaceholder(_resolveTypeValue(typeId) ?? 'link'),
                    prefixIcon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 10),
                  _MinimalDropdown<int>(
                    label: loc.myLinksColorLabel,
                    value: colorId,
                    items: colors.map((c) {
                      final code = c['color']?.toString();
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Row(children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _parseColor(code),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _T.border),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(c['name'] ?? c['title'] ?? ''),
                        ]),
                      );
                    }).toList(),
                    onChanged: (v) => setModal(() => colorId = v),
                  ),
                  const SizedBox(height: 20),
                  _PrimaryButton(
                    label: loc.myLinksUpdateButton,
                    disabled: typeId == null || colorId == null,
                    onTap: () {
                      Navigator.pop(ctx);
                      updateLink(
                        id: id,
                        title: titleCtrl.text,
                        url: urlCtrl.text,
                        typeId: typeId!,
                        colorId: colorId!,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Link card ─────────────────────────────────────────────────────────────

  Widget _buildLinkCard(Map<String, dynamic> link, int index) {
    final typeId = link['type_id'] ?? link['typeId'] ?? (link['type']?['id']);
    final colorId = link['color_id'] ?? link['colorId'] ?? (link['color']?['id']);
    final typeName = _resolveTypeName(typeId);
    final colorName = _resolveColorName(colorId);
    final colorSwatch = _parseColor(link['color']?['color']?.toString() ?? link['color']?.toString());
    final isDeleting = deletingIds.contains(link['id']);

    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.drag_indicator_rounded,
                  color: _T.textMuted, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _T.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.link_rounded, color: _T.accent, size: 18),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _T.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  link['url'] ?? '',
                  style: const TextStyle(fontSize: 12, color: _T.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (typeName.isNotEmpty || colorName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (typeName.isNotEmpty)
                          _TagPill(label: typeName),
                        if (colorName.isNotEmpty)
                          _ColorPill(label: colorName, color: colorSwatch),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: Icons.edit_outlined,
                color: _T.textSecondary,
                onTap: () => _openEditSheet(link),
              ),
              const SizedBox(height: 4),
              isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _T.danger),
                    )
                  : _IconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: _T.danger,
                      onTap: link['id'] == null ? null : () => deleteLink(link['id']),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Link form ─────────────────────────────────────────────────────────────

  Widget _buildLinkForm() {
    if (settingsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2)),
      );
    }

    final filtered = linkTypes.where((t) {
      final n = (t['name'] ?? t['title'] ?? '').toString().toLowerCase();
      return n.contains(typeSearchQuery);
    }).toList();
    final effectiveType = filtered.any((t) => t['id'] == selectedLinkTypeId)
        ? selectedLinkTypeId
        : null;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Link',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _T.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _MinimalField(
            hint: loc.myLinksSearchType,
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => setState(() => typeSearchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 10),
          _MinimalDropdown<int>(
            label: loc.myLinksLinkType,
            value: effectiveType,
            items: filtered.isEmpty
                ? [DropdownMenuItem(value: null, child: Text(loc.myLinksNoResults, style: const TextStyle(color: _T.textMuted)))]
                : filtered.map((t) => DropdownMenuItem<int>(
                      value: t['id'],
                      child: Text(t['name'] ?? t['title'] ?? ''),
                    )).toList(),
            onChanged: filtered.isEmpty ? null : (v) => setState(() => selectedLinkTypeId = v),
          ),
          const SizedBox(height: 10),
          _MinimalField(
            controller: _titleCtrl,
            hint: loc.myLinksTitleLabel,
            prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: 10),
          _MinimalField(
            controller: _urlCtrl,
            hint: loc.myLinksUrlLabel,
            placeholder: _getPlaceholder(_resolveTypeValue(selectedLinkTypeId) ?? 'link'),
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: 10),
          _MinimalDropdown<int>(
            label: loc.myLinksColorLabel,
            value: selectedColorId,
            items: colors.map((c) {
              final code = c['color']?.toString();
              return DropdownMenuItem<int>(
                value: c['id'],
                child: Row(children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _parseColor(code),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _T.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(c['name'] ?? c['title'] ?? ''),
                ]),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedColorId = v),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: isSubmitting ? loc.myLinksSaving : loc.myLinksAddLink,
            loading: isSubmitting,
            disabled: isSubmitting || selectedLinkTypeId == null || selectedColorId == null,
            onTap: createLink,
          ),
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: _T.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off_rounded, color: _T.accentMid, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              loc.myLinksNoLinksTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _T.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.myLinksNoLinksSubtitle,
              style: const TextStyle(fontSize: 13, color: _T.textSecondary),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: links.length,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = links.removeAt(oldIndex);
          links.insert(newIndex, item);
        });
        await _persistOrder();
      },
      itemBuilder: (_, i) => Container(
        key: ValueKey(links[i]['id'] ?? i),
        margin: const EdgeInsets.only(bottom: 10),
        child: _buildLinkCard(links[i], i),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _T.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _AppBarBtn(icon: Icons.arrow_back_rounded, onTap: _goBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip),
        title: const Text(
          'My Links',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
          ),
        ),
        actions: [
          if (isSavingOrder)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
                ),
              ),
            ),
          _AppBarBtn(icon: Icons.home_outlined, onTap: _goHome, tooltip: loc.dashboardHome),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.border),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2),
              )
            : Column(
                children: [
                  // Link list
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildList(),
                    ),
                  ),

                  // Bottom bar
                  Container(
                    decoration: const BoxDecoration(
                      color: _T.surface,
                      border: Border(top: BorderSide(color: _T.border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle button
                        GestureDetector(
                          onTap: () {
                            setState(() => showForm = !showForm);
                            if (showForm) {
                              _formAnimCtrl.forward();
                            } else {
                              _formAnimCtrl.reverse();
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: showForm ? _T.accentLight : _T.accent,
                              borderRadius: BorderRadius.circular(13),
                              border: showForm
                                  ? Border.all(color: _T.accentMid.withValues(alpha: 0.5))
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedRotation(
                                  turns: showForm ? 0.125 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: showForm ? _T.accent : Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  showForm ? loc.myLinksHideForm : loc.myLinksShowForm,
                                  style: TextStyle(
                                    color: showForm ? _T.accent : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Animated form
                        SizeTransition(
                          sizeFactor: _formAnim,
                          axisAlignment: -1,
                          child: _buildLinkForm(),
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

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  const _AppBarBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 20, color: _T.textSecondary),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _T.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: _T.textSecondary, fontWeight: FontWeight.w500),
        ),
      );
}

class _ColorPill extends StatelessWidget {
  const _ColorPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _T.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _T.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}

class _MinimalField extends StatelessWidget {
  const _MinimalField({
    this.controller,
    required this.hint,
    this.placeholder,
    this.prefixIcon,
    this.onChanged,
  });
  final TextEditingController? controller;
  final String hint;
  final String? placeholder;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _T.textPrimary),
        decoration: InputDecoration(
          labelText: hint,
          hintText: placeholder,
          labelStyle: const TextStyle(fontSize: 13, color: _T.textSecondary),
          hintStyle: const TextStyle(fontSize: 13, color: _T.textMuted),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: _T.textMuted)
              : null,
          filled: true,
          fillColor: _T.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.accent, width: 1.5),
          ),
        ),
      );
}

class _MinimalDropdown<T> extends StatelessWidget {
  const _MinimalDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _T.textPrimary),
        dropdownColor: _T.surface,
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: _T.textMuted),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: _T.textSecondary),
          filled: true,
          fillColor: _T.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _T.accent, width: 1.5),
          ),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: disabled ? _T.border : _T.accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: _T.accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: disabled ? _T.textSecondary : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );
}
