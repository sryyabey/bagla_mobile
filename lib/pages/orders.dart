import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token') ?? prefs.getString('authToken');
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
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/packs/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

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
    final start = _page * _pageSize;
    if (start >= _orders.length) return [];
    final end = (start + _pageSize).clamp(0, _orders.length);
    return _orders.sublist(start, end);
  }

  void _nextPage() {
    if ((_page + 1) * _pageSize < _orders.length) {
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
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalPages =
        (_orders.length / _pageSize).ceil() == 0 ? 1 : (_orders.length / _pageSize).ceil();
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
            onPressed: (_page + 1) * _pageSize < _orders.length ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
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

    return LayoutBuilder(
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
