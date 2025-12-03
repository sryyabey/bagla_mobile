import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTickets();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  Future<void> _fetchTickets() async {
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
        Uri.parse('$apiBaseUrl/api/support/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (!mounted) return;
        setState(() {
          _tickets = data is List
              ? List<Map<String, dynamic>>.from(
                  data.map((e) => Map<String, dynamic>.from(e)))
              : <Map<String, dynamic>>[];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Destek kayıtları alınamadı (${response.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Destek kayıtları alınamadı: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createTicket() async {
    if (_creating) return;
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showSnack('Başlık ve mesaj zorunludur.');
      return;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/support/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'message': message,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Destek talebi oluşturuldu.', success: true);
        _titleController.clear();
        _messageController.clear();
        await _fetchTickets();
      } else {
        String message = 'Talep oluşturulamadı (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Talep oluşturulamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
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

  Color _statusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  void _openTicketDetail(int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _TicketDetailSheet(
          ticketId: id,
          tokenGetter: _getToken,
          onUpdated: _fetchTickets,
          statusColor: _statusColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTickets,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildCreateCard(),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _fetchTickets,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              )
            else if (_tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Henüz destek talebiniz yok.'),
                ),
              )
            else
              ..._tickets.map(
                (ticket) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _openTicketDetail(ticket['id'] as int),
                    title: Text(
                      ticket['title']?.toString() ?? 'Başlıksız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                        ticket['status']?.toString())
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ticket['status_label']?.toString() ??
                                    ticket['status']?.toString() ??
                                    '',
                                style: TextStyle(
                                  color: _statusColor(
                                      ticket['status']?.toString()),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ticket['priority']?.toString().toUpperCase() ??
                                  '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mesaj: ${ticket['message_count'] ?? 0} • ${_formatDate(ticket['created_at']?.toString())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni Destek Talebi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mesajınız',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createTicket,
                icon: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_creating ? 'Gönderiliyor...' : 'Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final int ticketId;
  final Future<String?> Function() tokenGetter;
  final Future<void> Function() onUpdated;
  final Color Function(String?) statusColor;

  const _TicketDetailSheet({
    required this.ticketId,
    required this.tokenGetter,
    required this.onUpdated,
    required this.statusColor,
  });

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  bool _replying = false;
  bool _closing = false;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTicket();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _loadTicket() async {
    setState(() {
      _loading = true;
    });

    final token = await widget.tokenGetter();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
      });
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/support/tickets/${widget.ticketId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (!mounted) return;
        setState(() {
          _ticket = Map<String, dynamic>.from(data);
          _loading = false;
        });
      } else {
        _showSnack('Talep alınamadı (${response.statusCode}).');
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      _showSnack('Talep alınamadı: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendReply() async {
    if (_replying) return;
    final message = _replyController.text.trim();
    if (message.isEmpty) {
      _showSnack('Mesaj boş olamaz.');
      return;
    }

    final token = await widget.tokenGetter();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _replying = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            '$apiBaseUrl/api/support/tickets/${widget.ticketId}/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _replyController.clear();
        await widget.onUpdated();
        await _loadTicket();
        _showSnack('Yanıt gönderildi.', success: true);
      } else {
        String msg = 'Yanıt gönderilemedi (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          msg = decoded['message']?.toString() ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Yanıt gönderilemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _replying = false;
        });
      }
    }
  }

  Future<void> _closeTicket() async {
    if (_closing) return;

    final token = await widget.tokenGetter();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _closing = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            '$apiBaseUrl/api/support/tickets/${widget.ticketId}/close'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await widget.onUpdated();
        await _loadTicket();
        _showSnack('Talep kapatıldı.', success: true);
      } else {
        _showSnack('Talep kapatılamadı (${response.statusCode}).');
      }
    } catch (e) {
      _showSnack('Talep kapatılamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _closing = false;
        });
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Destek Detayı',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _ticket == null
                        ? const Center(child: Text('Talep bulunamadı.'))
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 12),
                              const Text(
                                'Mesajlar',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ..._buildMessages(),
                              const SizedBox(height: 12),
                            ],
                          ),
              ),
              if (_ticket != null) _buildReplyArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _ticket?['title']?.toString() ?? 'Başlıksız',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: widget.statusColor(_ticket?['status']?.toString())
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _ticket?['status_label']?.toString() ??
                    _ticket?['status']?.toString() ??
                    '',
                style: TextStyle(
                  color: widget.statusColor(_ticket?['status']?.toString()),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _ticket?['priority']?.toString().toUpperCase() ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(),
            if (_ticket?['status']?.toString() != 'closed')
              TextButton.icon(
                onPressed: _closing ? null : _closeTicket,
                icon: _closing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_closing ? 'Kapatılıyor' : 'Talebi Kapat'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Oluşturulma: ${_formatDate(_ticket?['created_at']?.toString())}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildMessages() {
    final messages = _ticket?['messages'];
    if (messages is! List || messages.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Henüz mesaj yok.'),
        ),
      ];
    }

    return List<Widget>.generate(messages.length, (index) {
      final msg = Map<String, dynamic>.from(messages[index]);
      final sender = msg['sender'] as Map<String, dynamic>?;
      final isOwner = sender?['is_owner'] == true;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isOwner ? Colors.blue : Colors.grey.shade300)
              .withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                (isOwner ? Colors.blue : Colors.grey.shade500).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isOwner ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  sender?['name']?.toString() ??
                      (isOwner ? 'Siz' : 'Destek'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOwner ? Colors.blue : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(msg['created_at']?.toString()),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(msg['message']?.toString() ?? ''),
          ],
        ),
      );
    });
  }

  Widget _buildReplyArea() {
    final isClosed = _ticket?['status']?.toString() == 'closed';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _replyController,
            minLines: 1,
            maxLines: 4,
            enabled: !isClosed,
            decoration: InputDecoration(
              hintText: isClosed
                  ? 'Bu talep kapalı, yeni mesaj gönderemezsiniz.'
                  : 'Mesajınız',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isClosed || _replying ? null : _sendReply,
                  icon: _replying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_replying ? 'Gönderiliyor...' : 'Yanıt Gönder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
