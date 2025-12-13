import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../login_page.dart';
import '../auth.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  int _page = 0;
  final int _pageSize = 10;
  String _statusFilter = 'all';
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token') ?? prefs.getString('authToken');
  }

  Future<void> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bearer_token');
    await prefs.remove('authToken');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oturum süresi doldu, lütfen tekrar giriş yapın.'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(onLocaleChange: (_) {}),
      ),
      (route) => false,
    );
  }

  Future<void> _loadOrders() async {
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
      final response = await _getWithRefresh(
        token,
        (authToken) => http.get(
          Uri.parse('$apiBaseUrl/api/packs/orders'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final list = (data['orders'] as List?) ?? [];
        setState(() {
          _orders = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _page = 0;
        });
      } else {
        setState(() {
          _error = 'Siparişler alınamadı (HTTP ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Siparişler alınırken hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<http.Response?> _getWithRefresh(
      String? token, Future<http.Response> Function(String token) request) async {
    if (token == null || token.isEmpty) {
      await _handleUnauthorized();
      return null;
    }

    var res = await request(token);
    if (res.statusCode != 401) return res;

    if (_retrying) {
      await _handleUnauthorized();
      return null;
    }
    _retrying = true;
    final refreshed = await refreshAccessToken();
    _retrying = false;
    if (refreshed != null) {
      res = await request(refreshed);
      if (res.statusCode != 401) return res;
    }
    await _handleUnauthorized();
    return null;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return Colors.green.shade600;
      case 'pending':
        return Colors.orange.shade700;
      case 'failed':
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> get _pagedOrders {
    final filtered = _filteredOrders;
    final start = _page * _pageSize;
    if (start >= filtered.length) return [];
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_statusFilter == 'all') return _orders;
    return _orders
        .where((o) =>
            (o['payment_status']?.toString().toLowerCase() ?? '') ==
            _statusFilter)
        .toList();
  }

  void _nextPage() {
    if ((_page + 1) * _pageSize < _filteredOrders.length) {
      setState(() => _page += 1);
    }
  }

  void _prevPage() {
    if (_page > 0) {
      setState(() => _page -= 1);
    }
  }

  Widget _buildMobileList() {
    final items = _pagedOrders;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final order = items[index];
        final status = order['payment_status']?.toString() ?? '-';
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _showOrderDetails(order),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order['pack_name']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Chip(
                        backgroundColor: _statusColor(status).withOpacity(0.12),
                        label: Text(
                          status,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: ${order['pack_type'] ?? '-'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    'Tarih: ${_formatDate(order['order_date']?.toString())}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tutar: ${order['total_price'] ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '#${order['id'] ?? '-'}',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İşlem ID: ${order['transaction_id'] ?? '-'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalPages =
        (_filteredOrders.length / _pageSize).ceil() == 0 ? 1 : (_filteredOrders.length / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Sayfa ${_page + 1} / $totalPages'),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Önceki',
            onPressed: _page > 0 ? _prevPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Sonraki',
            onPressed: (_page + 1) * _pageSize < _filteredOrders.length ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final status = order['payment_status']?.toString() ?? '-';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['pack_name']?.toString() ?? 'Sipariş',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Chip(
                    backgroundColor: _statusColor(status).withOpacity(0.12),
                    label: Text(
                      status,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _detailRow('İşlem ID', order['transaction_id']),
              _detailRow('Paket Tipi', order['pack_type']),
              _detailRow('Fiyat', order['price']),
              _detailRow('Vergi', order['tax']),
              _detailRow('Toplam', order['total_price']),
              _detailRow('Tarih', _formatDate(order['order_date']?.toString())),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Flexible(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const statuses = [
      {'key': 'all', 'label': 'Hepsi'},
      {'key': 'paid', 'label': 'Ödendi'},
      {'key': 'pending', 'label': 'Bekliyor'},
      {'key': 'failed', 'label': 'Başarısız'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses.map((item) {
          final selected = _statusFilter == item['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _statusFilter = item['key']!;
                  _page = 0;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Text('Henüz sipariş bulunmuyor.'),
      );
    }

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (!isWide) {
                return Column(
                  children: [
                    Expanded(child: _buildMobileList()),
                    _buildPagination(),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Paket')),
                            DataColumn(label: Text('Tip')),
                            DataColumn(label: Text('Durum')),
                            DataColumn(label: Text('Tutar')),
                            DataColumn(label: Text('Tarih')),
                            DataColumn(label: Text('İşlem ID')),
                          ],
                          rows: _pagedOrders.map((order) {
                            final status = order['payment_status']?.toString() ?? '-';
                            final total = order['total_price']?.toString() ?? '-';
                            final pack = order['pack_name']?.toString() ?? '-';
                            final type = order['pack_type']?.toString() ?? '-';
                            final txn = order['transaction_id']?.toString() ?? '-';
                            final date = _formatDate(order['order_date']?.toString());
                            return DataRow(
                              onSelectChanged: (_) => _showOrderDetails(order),
                              cells: [
                                DataCell(Text(order['id']?.toString() ?? '-')),
                                DataCell(Text(pack)),
                                DataCell(Text(type)),
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(status),
                                    ],
                                  ),
                                ),
                                DataCell(Text(total)),
                                DataCell(Text(date)),
                                DataCell(Text(txn)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  _buildPagination(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
