import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../network/api_config.dart';
import '../storage/token_storage.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  WebSocketService._internal();
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  
  Future<void> connect() async {
    if (_isConnected) return;
    
    final token = await TokenStorage().getAccessToken();
    final userId = await TokenStorage().getUserId();
    
    if (token == null || userId == null) return;
    
    final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token&user_id=$userId');
    _channel = WebSocketChannel.connect(uri);
    
    _channel!.stream.listen(
      (data) {
        try {
          final message = json.decode(data) as Map<String, dynamic>;
          _messageController.add(message);
        } catch (e) {
          // Ignore parse errors
        }
      },
      onError: (error) {
        _isConnected = false;
        _reconnect();
      },
      onDone: () {
        _isConnected = false;
        _reconnect();
      },
    );
    
    _isConnected = true;
    _startHeartbeat();
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        send({'event': 'ping'});
      }
    });
  }
  
  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      connect();
    });
  }
  
  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode(data));
    }
  }
  
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
  }
}