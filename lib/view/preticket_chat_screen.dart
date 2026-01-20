import 'dart:async';
import 'dart:convert';

import 'package:fiberlux_new_app/models/preticket_chat.dart';
import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/services/preticket_historial.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/SessionProvider.dart';
import '../services/fcm_service.dart';
import '../services/preticket_local_store.dart';

class PreticketChatScreen extends StatefulWidget {
  final int preticketId;
  final String? ticketCode; // opcional, para mostrar en el AppBar
  final String? serviciosAfectados; // 👈 NUEVO: lista tipo "ID1, ID2, ID3"

  const PreticketChatScreen({
    Key? key,
    required this.preticketId,
    this.ticketCode,
    this.serviciosAfectados, // 👈 NUEVO
  }) : super(key: key);

  @override
  State<PreticketChatScreen> createState() => _PreticketChatScreenState();
}

class _PreticketChatScreenState extends State<PreticketChatScreen> {
  late WebSocketChannel _channel;
  StreamSubscription? _wsSub;

  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  int? _myUserId;
  String _myName = 'Yo';
  bool _sending = false;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();

    final session = context.read<SessionProvider>();
    _myUserId = session.userId;
    _myName = session.displayName ?? session.nombre ?? 'Yo';

    _initChat();
  }

  /// Paso 1: cargar historial local
  /// Paso 2: abrir WebSocket
  /// Paso 3: sincronizar con la API (GET) en segundo plano
  Future<void> _initChat() async {
    await _loadStoredMessages(); // offline-first
    _initWebSocket();
    _syncFromApi(); // 🔁 no espero, corre en background con try/catch
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Transforma la lista "raw" (Map) en la lista de _ChatMessage
  List<_ChatMessage> _mapRawToMessages(List<Map<String, dynamic>> rawList) {
    final List<_ChatMessage> restored = [];

    for (final data in rawList) {
      final authorId = _asInt(data['user_id'] ?? data['author_id']);

      DateTime? createdAt;
      final createdStr = data['created_at']?.toString();
      if (createdStr != null && createdStr.isNotEmpty) {
        try {
          createdAt = DateTime.parse(createdStr);
        } catch (_) {}
      }

      restored.add(
        _ChatMessage(
          id: _asInt(data['id']),
          text: data['message']?.toString() ?? '',
          authorId: authorId,
          authorName:
              data['username']?.toString() ??
              data['author_username']?.toString() ??
              '',
          createdAt: createdAt,
          isMine: _myUserId != null && authorId == _myUserId,
        ),
      );
    }

    // Orden opcional por fecha (por si el raw viene mezclado)
    restored.sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

    return restored;
  }

  /// Carga historial guardado en SharedPreferences para este preticket
  Future<void> _loadStoredMessages() async {
    final rawList = await PreticketLocalStore.loadRaw(widget.preticketId);
    if (!mounted) return;

    final restored = _mapRawToMessages(rawList);

    setState(() {
      _messages.clear();
      _messages.addAll(restored);
    });

    _scrollToBottom();
  }

  /// Sincroniza contra la API GET:
  ///   GET /api/v1/client/preticket-message/mobile/list/{preticketId}/
  ///
  /// Usa PreticketChatService, que a su vez:
  ///   - lee local
  ///   - llama al backend
  ///   - normaliza y guarda en PreticketLocalStore
  ///   - devuelve la lista final mergeada y ordenada
  Future<void> _syncFromApi() async {
    try {
      final session = context.read<SessionProvider>();

      // ⬇️ AHORA usamos getMessages y viene tipado
      final List<PreticketMessage> apiMessages =
          await PreticketChatService.getMessages(
            preticketId: widget.preticketId,
            token: session.accessToken,
          );

      if (!mounted) return;

      // Mapeamos PreticketMessage -> _ChatMessage
      final mapped =
          apiMessages.map((m) {
            final fullName = '${m.firstName} ${m.lastName}'.trim();
            final displayName = fullName.isNotEmpty ? fullName : m.username;

            return _ChatMessage(
              id: m.id,
              text: m.message,
              authorId: m.authorId,
              authorName: displayName,
              createdAt: m.createdAt,
              isMine: _myUserId != null && m.authorId == _myUserId,
            );
          }).toList()..sort((a, b) {
            final da = a.createdAt;
            final db = b.createdAt;
            if (da == null && db == null) return 0;
            if (da == null) return -1;
            if (db == null) return 1;
            return da.compareTo(db);
          });

      setState(() {
        _messages
          ..clear()
          ..addAll(mapped);
      });

      _scrollToBottom();
    } catch (e, st) {
      debugPrint('❌ Error sincronizando historial de chat: $e\n$st');
    }
  }

  void _initWebSocket() {
    final uri = Uri.parse(
      'wss://arcus.fiberlux.pe:8080/ws/client/${widget.preticketId}/',
    );
    debugPrint('🔌 Abriendo WS principal de chat: $uri');

    try {
      _channel = IOWebSocketChannel.connect(uri);

      _wsSub = _channel.stream.listen(
        _onWsData,
        onError: (e) {
          debugPrint('❌ WS chat error en stream: $e');
          if (mounted) {
            setState(() => _wsConnected = false);
          }
        },
        onDone: () {
          debugPrint('🔌 WS chat cerrado');
          if (mounted) {
            setState(() => _wsConnected = false);
          }
        },
      );

      setState(() => _wsConnected = true);
    } catch (e) {
      debugPrint('❌ Error abriendo WS de chat: $e');
      setState(() => _wsConnected = false);
    }
  }

  /// Callback de datos del WebSocket
  void _onWsData(dynamic raw) async {
    debugPrint('📥 WS chat raw: $raw');

    try {
      // El backend manda: { "type": "message", "data": { ... } }
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      if (msg['type'] != 'message') return;

      final data = Map<String, dynamic>.from(msg['data'] as Map);

      // Aseguramos preticket para el storage
      data['preticket'] ??= widget.preticketId;

      final authorId = _asInt(data['user_id'] ?? data['author_id']);
      final text = data['message']?.toString() ?? '';

      DateTime? createdAt;
      final createdStr = data['created_at']?.toString();
      if (createdStr != null && createdStr.isNotEmpty) {
        try {
          createdAt = DateTime.parse(createdStr);
        } catch (_) {}
      }

      final chatMsg = _ChatMessage(
        id: _asInt(data['id']),
        text: text,
        authorId: authorId,
        authorName:
            data['username']?.toString() ??
            data['author_username']?.toString() ??
            '',
        createdAt: createdAt,
        isMine: _myUserId != null && authorId == _myUserId,
      );

      setState(() {
        _messages.add(chatMsg);
      });

      // 💾 Persistimos también en local (para cuando no estés en el chat)
      await PreticketLocalStore.appendRaw(widget.preticketId, data);

      _scrollToBottom();
    } catch (e, st) {
      debugPrint('💥 Error parseando mensaje WS: $e\n$st');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    if (_myUserId == null || _myUserId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el ID de usuario')),
      );
      return;
    }

    context.read<NotificationsProvider>().registerLocalSentPreticketMessage(
          preticketId: widget.preticketId,
          text: text,
        );

    setState(() => _sending = true);

    try {
      final session = context.read<SessionProvider>();
      final uri = Uri.parse(
        'https://arcus.fiberlux.pe:8080/api/v1/client/preticket-message/send',
      );

      String? deviceToken = FcmService.instance.lastToken;
      deviceToken ??= await FirebaseMessaging.instance.getToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (session.accessToken != null)
          'Authorization': 'Bearer ${session.accessToken}',
      };

      final payload = {
        'preticket': widget.preticketId,
        // 👇 IMPORTANTE: aquí va user_id, como en el ejemplo que ya probaron
        'user_id': _myUserId,
        'message': text,
      };

      if (deviceToken != null && deviceToken.isNotEmpty) {
        payload['sender_device_token'] = deviceToken;
      }

      final body = jsonEncode(payload);

      debugPrint('📤 [API] Enviando mensaje: $body');

      final resp = await http.post(uri, headers: headers, body: body);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _inputCtrl.clear();
        _scrollToBottom();
        // El mensaje llegará por WS → se guardará y se verá en pantalla
      } else {
        debugPrint('❌ Error HTTP chat: ${resp.statusCode} - ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar el mensaje (${resp.statusCode})'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error enviando mensaje: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar mensaje: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel.sink.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF8B4A9C);

    // 👇 Obtener el primer ID de servicio (si hay varios separados por coma)
    String? firstServiceId;
    final serviciosStr = widget.serviciosAfectados;
    if (serviciosStr != null && serviciosStr.trim().isNotEmpty) {
      final parts = serviciosStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        firstServiceId = parts.first; // 👈 el primero que se muestra
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: brand),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: brand, size: 22),
            const SizedBox(width: 8),
            Text(
              // 👇 Prioridad: ID Servicio > ticketCode > texto genérico
              firstServiceId != null
                  ? 'Servicio $firstServiceId'
                  : (widget.ticketCode != null
                        ? 'Chat T-0011036'
                        : 'Chat del ticket'),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _wsConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _wsConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _wsConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
        elevation: 0.4,
      ),
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  final m = _messages[index];

                  final isMine = m.isMine;
                  final align = isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft;

                  final bubbleColor = isMine ? brand : Colors.white;
                  final textColor = isMine ? Colors.white : Colors.black87;

                  return Align(
                    alignment: align,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: Card(
                        color: bubbleColor,
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMine ? 14 : 2),
                            bottomRight: Radius.circular(isMine ? 2 : 14),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Text(
                                  m.authorName.isEmpty
                                      ? 'Operador'
                                      : m.authorName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withOpacity(0.85),
                                  ),
                                ),
                              if (!isMine) const SizedBox(height: 2),
                              Text(
                                m.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(m.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Input
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: brand,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: brand,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final int? id;
  final String text;
  final int? authorId;
  final String authorName;
  final DateTime? createdAt;
  final bool isMine;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.isMine,
  });
}
