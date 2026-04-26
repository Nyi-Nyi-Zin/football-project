import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  /// Connect to the WebSocket server
  Stream<Map<String, dynamic>> connect() {
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    _connectInternal();
    return _controller!.stream;
  }

  void _connectInternal() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConstants.wsOddsUrl),
      );

      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(decoded);
          } catch (e) {
            debugPrint('[WebSocket] Error decoding message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        debugPrint('[WebSocket] Attempting reconnection...');
        _connectInternal();
      }
    });
  }

  /// Send a message through the WebSocket
  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _reconnectTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close();
    _controller?.close();
  }

  bool get isConnected => _isConnected;
}
