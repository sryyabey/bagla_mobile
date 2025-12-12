import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bagla_mobile/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyLinksPage extends StatefulWidget {
  const MyLinksPage({super.key});

  @override
  State<MyLinksPage> createState() => _MyLinksPageState();
}

class _MyLinksPageState extends State<MyLinksPage> {
  static const Color _backgroundColor = Color(0xFFF7F9FC);
  static const Color _primaryColor = Color(0xFF6366F1);

  TextEditingController linkTitleController = TextEditingController();
  TextEditingController linkUrlController = TextEditingController();
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchProfileData(); // artık token null gelmeyecek
      fetchLinkTypesAndColors();
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  Future<void> fetchProfileData() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      debugPrint('⚠️ Token null veya boş!');
      setState(() {
        isLoading = false;
      });
      return;
    }

    debugPrint('🟢 Token bulundu: $token');
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/user/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final data = jsonData['data'];

      setState(() {
        final rawLinks = data['links'];
        links = rawLinks is List
            ? List<Map<String, dynamic>>.from(rawLinks)
            : <Map<String, dynamic>>[];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchLinkTypesAndColors() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        settingsLoading = false;
      });
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('$apiBaseUrl/api/settings/link-types'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$apiBaseUrl/api/settings/colors'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]);

      final linkTypesResponse = responses[0];
      final colorsResponse = responses[1];

      List<Map<String, dynamic>> fetchedLinkTypes = [];
      List<Map<String, dynamic>> fetchedColors = [];

      if (linkTypesResponse.statusCode == 200) {
        final decoded = json.decode(linkTypesResponse.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> ? decoded['data'] : null);
        if (list is List) {
          fetchedLinkTypes = List<Map<String, dynamic>>.from(list);
        } else if (list is Map<String, dynamic>) {
          fetchedLinkTypes = [Map<String, dynamic>.from(list)];
        } else if (decoded is Map<String, dynamic>) {
          fetchedLinkTypes = [decoded];
        }
      }

      if (colorsResponse.statusCode == 200) {
        final decoded = json.decode(colorsResponse.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> ? decoded['data'] : null);
        if (list is List) {
          fetchedColors = List<Map<String, dynamic>>.from(list);
        } else if (list is Map<String, dynamic>) {
          fetchedColors = [Map<String, dynamic>.from(list)];
        } else if (decoded is Map<String, dynamic>) {
          fetchedColors = [decoded];
        }
      }

      if (!mounted) return;
      setState(() {
        linkTypes = fetchedLinkTypes;
        colors = fetchedColors;
        selectedLinkTypeId ??=
            fetchedLinkTypes.isNotEmpty ? fetchedLinkTypes.first['id'] : null;
        selectedColorId ??=
            fetchedColors.isNotEmpty ? fetchedColors.first['id'] : null;
        settingsLoading = false;
      });
    } catch (e) {
      debugPrint('Link tipi veya renk alınamadı: $e');
      if (!mounted) return;
      setState(() {
        settingsLoading = false;
      });
    }
  }

  String _resolveTypeName(dynamic typeId) {
    if (typeId == null) return '';
    final match =
        linkTypes.firstWhere((item) => item['id'] == typeId, orElse: () => {});
    return match['name'] ??
        match['title'] ??
        (match.isNotEmpty ? 'Tip ${match['id']}' : '');
  }

  String? _resolveTypeValue(dynamic typeId) {
    if (typeId == null) return null;
    final match =
        linkTypes.firstWhere((item) => item['id'] == typeId, orElse: () => {});
    return match['type'] ?? match['alias'];
  }

  String _resolveColorName(dynamic colorId) {
    if (colorId == null) return '';
    final match =
        colors.firstWhere((item) => item['id'] == colorId, orElse: () => {});
    return match['name'] ??
        match['title'] ??
        match['color'] ??
        (match.isNotEmpty ? 'Renk ${match['id']}' : '');
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final cleaned = hex.replaceAll('#', '');
    final buffer = StringBuffer();
    if (cleaned.length == 6) buffer.write('ff');
    buffer.write(cleaned);
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Widget _buildColorDropdownItem(Map<String, dynamic> color) {
    final name = color['name'] ?? color['title'] ?? 'Renk';
    final code = color['color']?.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _parseColor(code),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }

  String getPlaceholderForType(String? type) {
    switch (type) {
      case 'whatsapp':
      case 'phone':
      case 'sms':
        return '+15xxxxxxxxx';
      case 'email':
        return 'xxx@sample.com';
      case 'telegram':
        return 'https://t.me/username';
      default:
        return 'https://example.com';
    }
  }

  Widget _sectionCard({
    required Widget child,
    String? title,
    String? subtitle,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
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
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
            )
          else if (title != null)
            const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> createLink() async {
    final token = await _getToken();
    final typeId = selectedLinkTypeId;
    final colorId = selectedColorId;

    if (token == null || token.isEmpty || typeId == null || colorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link eklemek için token, tip ve renk gerekli.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type_id': typeId,
          'title': linkTitleController.text,
          'url': linkUrlController.text,
          'color_id': colorId,
        }),
      );

      debugPrint('Create status: ${response.statusCode}');
      debugPrint('Create body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchProfileData();
        linkTitleController.clear();
        linkUrlController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link eklendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        final message = decoded['message'] ??
            (decoded['errors'] != null ? decoded['errors'].toString() : null) ??
            'Link eklenemedi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link eklenirken hata oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Future<void> deleteLink(int id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token bulunamadı.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      deletingIds.add(id);
    });

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/links/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('Delete status: ${response.statusCode}');
      debugPrint('Delete body: ${response.body}');

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchProfileData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link silindi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        final message = decoded['message'] ??
            (decoded['errors'] != null ? decoded['errors'].toString() : null) ??
            'Link silinemedi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link silinirken hata oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingIds.remove(id);
        });
      }
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
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token bulunamadı.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/links/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type_id': typeId,
          'title': title,
          'url': url,
          'color_id': colorId,
        }),
      );

      debugPrint('Update status: ${response.statusCode}');
      debugPrint('Update body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        await fetchProfileData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        final message = decoded['message'] ??
            (decoded['errors'] != null ? decoded['errors'].toString() : null) ??
            'Link güncellenemedi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link güncellenirken hata oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _persistOrder() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;

    setState(() {
      isSavingOrder = true;
    });

    try {
      final orders = <Map<String, dynamic>>[];
      for (int i = 0; i < links.length; i++) {
        final id = links[i]['id'];
        if (id == null) continue;
        orders.add({'id': id, 'order': i});
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/links/reorder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'orders': orders}),
      );

      debugPrint('Reorder status: ${response.statusCode}');
      debugPrint('Reorder body: ${response.body}');
    } catch (e) {
      debugPrint('Order update failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSavingOrder = false;
        });
      }
    }
  }

  void _openEditSheet(Map<String, dynamic> link) {
    final id = link['id'];
    if (id == null) return;

    final titleController =
        TextEditingController(text: link['title']?.toString() ?? '');
    final urlController =
        TextEditingController(text: link['url']?.toString() ?? '');

    int? typeId = link['type_id'] ??
        link['typeId'] ??
        (link['type'] != null ? link['type']['id'] : null);
    int? colorId = link['color_id'] ??
        link['colorId'] ??
        (link['color'] != null ? link['color']['id'] : null);

    // Eğer dropdown listeleri boşsa mevcut tip/renkleri tek seferlik ekle ki dropdown doğru çalışsın.
    if (linkTypes.isEmpty && typeId != null) {
      setState(() {
        linkTypes = [
          {'id': typeId, 'name': 'Tip #$typeId', 'type': link['type']}
        ];
      });
    }
    if (colors.isEmpty && colorId != null) {
      setState(() {
        colors = [
          {'id': colorId, 'name': 'Renk #$colorId', 'color': link['color']}
        ];
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final modalFilteredTypes = linkTypes.where((type) {
                final name = (type['name'] ?? type['title'] ?? '')
                    .toString()
                    .toLowerCase();
                return name.contains(typeSearchQuery);
              }).toList();
              final modalEffectiveTypeValue =
                  modalFilteredTypes.any((t) => t['id'] == typeId)
                      ? typeId
                      : null;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Link Düzenle',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Link tipi ara',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          typeSearchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: modalEffectiveTypeValue,
                      items: modalFilteredTypes.isNotEmpty
                          ? modalFilteredTypes
                              .map(
                                (type) => DropdownMenuItem<int>(
                                  value: type['id'],
                                  child: Text(
                                      type['name'] ?? type['title'] ?? 'Tip'),
                                ),
                              )
                              .toList()
                          : const [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text('Sonuç bulunamadı'),
                              ),
                            ],
                      onChanged: modalFilteredTypes.isEmpty
                          ? null
                          : (value) {
                              setModalState(() {
                                typeId = value;
                              });
                            },
                      decoration: const InputDecoration(labelText: 'Link Tipi'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Başlık'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: 'URL',
                        hintText: getPlaceholderForType(
                          _resolveTypeValue(typeId) ?? 'link',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: colorId,
                      items: colors
                          .map(
                            (color) => DropdownMenuItem<int>(
                              value: color['id'],
                              child: _buildColorDropdownItem(color),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          colorId = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Renk'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (typeId == null || colorId == null)
                            ? null
                            : () {
                                Navigator.pop(context);
                                updateLink(
                                  id: id,
                                  title: titleController.text,
                                  url: urlController.text,
                                  typeId: typeId!,
                                  colorId: colorId!,
                                );
                              },
                        child: const Text('Güncelle'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLinkForm() {
    if (settingsLoading) {
      return _sectionCard(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredTypes = linkTypes.where((type) {
      final name =
          (type['name'] ?? type['title'] ?? '').toString().toLowerCase();
      return name.contains(typeSearchQuery);
    }).toList();
    final effectiveTypeValue =
        filteredTypes.any((t) => t['id'] == selectedLinkTypeId)
            ? selectedLinkTypeId
            : null;

    return _sectionCard(
      title: 'Yeni Link',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Link tipi ara',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                typeSearchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: effectiveTypeValue,
            items: filteredTypes.isNotEmpty
                ? filteredTypes
                    .map(
                      (type) => DropdownMenuItem<int>(
                        value: type['id'],
                        child:
                            Text(type['name'] ?? type['title'] ?? 'Link Tipi'),
                      ),
                    )
                    .toList()
                : const [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('Sonuç bulunamadı'),
                    ),
                  ],
            onChanged: filteredTypes.isEmpty
                ? null
                : (value) {
                    setState(() {
                      selectedLinkTypeId = value;
                    });
                  },
            decoration: const InputDecoration(labelText: 'Link Tipi'),
          ),
          if (linkTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Link tipi bulunamadı, lütfen ayarları kontrol edin.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: linkTitleController,
            decoration: const InputDecoration(labelText: 'Başlık'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: linkUrlController,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: getPlaceholderForType(
                _resolveTypeValue(selectedLinkTypeId) ?? 'link',
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: selectedColorId,
            items: colors
                .map(
                  (color) => DropdownMenuItem<int>(
                    value: color['id'],
                    child: _buildColorDropdownItem(color),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedColorId = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Renk'),
          ),
          if (colors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Renk listesi bulunamadı.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (isSubmitting ||
                      selectedLinkTypeId == null ||
                      selectedColorId == null)
                  ? null
                  : createLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(isSubmitting ? 'Kaydediliyor...' : 'Link Ekle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link, int index) {
    final typeName = _resolveTypeName(
      link['type_id'] ??
          link['typeId'] ??
          (link['type'] != null ? link['type']['id'] : null),
    );
    final dynamic colorId =
        link['color_id'] ?? link['colorId'] ?? (link['color']?['id']);
    final String colorName = _resolveColorName(colorId);
    final Color colorSwatch = _parseColor(
        link['color']?['color']?.toString() ?? link['color']?.toString());

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.link, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  link['url'] ?? '',
                  style: const TextStyle(color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                if (typeName.isNotEmpty || colorName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (typeName.isNotEmpty)
                          Chip(
                            label: Text(typeName),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        if (colorName.isNotEmpty)
                          Chip(
                            avatar: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: colorSwatch,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.black12, width: 1),
                              ),
                            ),
                            label: Text(colorName),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _openEditSheet(link),
              ),
              deletingIds.contains(link['id'])
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: link['id'] == null
                          ? null
                          : () => deleteLink(link['id']),
                    ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList() {
    if (links.isEmpty) {
      return Center(
        child: _sectionCard(
          title: 'Henüz link yok',
          subtitle: 'Yeni link ekleyerek başla',
          child: const SizedBox.shrink(),
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
      itemBuilder: (context, index) {
        final link = links[index];
        return Container(
          key: ValueKey(link['id'] ?? index),
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildLinkCard(link, index),
        );
      },
    );
  }

  Widget _debugStatus() {
    if (isLoading) return const SizedBox.shrink();

    List<String> errors = [];

    if (links.isEmpty) {
      errors.add("⚠️ API'den hiç link gelmedi.");
    }
    if (linkTypes.isEmpty) {
      errors.add("⚠️ Link tipleri boş geldi.");
    }
    if (colors.isEmpty) {
      errors.add("⚠️ Renk listesi boş geldi.");
    }

    if (errors.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      title: 'Eksik veriler',
      subtitle: 'API’den beklenen listeler gelmedi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errors
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  e,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Linklerim',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildReorderableList(),
                    ),
                  ),
                  if (isSavingOrder)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('Sıralama kaydediliyor...'),
                    ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              showForm = !showForm;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(showForm ? Icons.close : Icons.add),
                          label:
                              Text(showForm ? 'Formu Gizle' : 'Yeni Link Ekle'),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: showForm
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: _buildLinkForm(),
                                )
                              : const SizedBox.shrink(),
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
