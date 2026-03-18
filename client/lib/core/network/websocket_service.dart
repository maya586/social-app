import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/api_config.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  WebSocketService._internal();
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  bool _isConnected = false;
  String? _lastSyncTimestamp;
  
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
          _handleMessage(message);
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
    _requestSync();
  }
  
  void _handleMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    
    switch (event) {
      case 'message:new':
        _messageController.add(message);
        break;
      case 'message:read':
        _messageController.add(message);
        break;
      case 'sync:ack':
        // Sync acknowledged
        break;
      case 'user:status':
        _messageController.add(message);
        break;
      case 'call:offer':
      case 'call:answer':
      case 'call:ice-candidate':
      case 'call:join':
      case 'call:leave':
      case 'call:end':
        _messageController.add(message);
        break;
      default:
        _messageController.add(message);
    }
  }
  
  Future<void> _requestSync() async {
    try {
      // Fetch conversations with recent messages
      final response = await ApiClient().dio.get('/conversations?limit=20');
      final conversations = response.data as List?;
      
      if (conversations != null) {
        for (final conv in conversations) {
          final convId = conv['id'];
          // Fetch recent messages for each conversation
          await ApiClient().dio.get('/messages/conversation/$convId?limit=10');
        }
      }
      
      send({'event': 'sync', 'last_sync': _lastSyncTimestamp});
    } catch (e) {
      // Ignore sync errors
    }
  }
  
  void setLastSyncTimestamp(String timestamp) {
    _lastSyncTimestamp = timestamp;
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
    _syncTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
  }
}