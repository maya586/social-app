import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../data/chat_provider.dart';
import '../domain/message.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../call/presentation/call_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  
  const ChatPage({super.key, required this.conversationId});
  
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isUploading = false;
  String? _currentUserId;
  StreamSubscription? _wsSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _listenToWebSocket();
  }
  
  void _listenToWebSocket() {
    _wsSubscription = WebSocketService().messages.listen((message) {
      final event = message['event'] as String?;
      
      if (event == 'message:new') {
        final rawData = message['data'];
        Map<String, dynamic>? data;
        if (rawData is Map<String, dynamic>) {
          data = rawData;
        } else if (rawData is String) {
          try {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (e) {}
        }
        if (data != null) {
          final msgConversationId = data['conversation_id']?.toString();
          final senderId = data['sender_id']?.toString();
          
          if (msgConversationId == widget.conversationId) {
            if (senderId != null && senderId != _currentUserId) {
              final newMessage = Message.fromJson(data);
              ref.read(messagesProvider(widget.conversationId).notifier).addMessage(newMessage);
              _scrollToBottom();
            }
          }
        }
      } else if (event == 'call:offer') {
        final rawData = message['data'];
        Map<String, dynamic>? data;
        if (rawData is Map<String, dynamic>) {
          data = rawData;
        } else if (rawData is String) {
          try {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (e) {}
        }
        if (data != null) {
          _showIncomingCall(data);
        }
      }
    });
  }
  
  void _showIncomingCall(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    final isVideo = data['is_video'] as bool? ?? false;
    final callerName = data['caller_name'] as String? ?? '用户';
    
    if (roomId == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('来电'),
        content: Text('$callerName 邀请您${isVideo ? '视频' : '语音'}通话'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('拒绝', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    roomId: roomId,
                    isVideo: isVideo,
                    isCaller: false,
                    offerData: data,
                  ),
                ),
              );
            },
            child: const Text('接听'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadCurrentUserId() async {
    final userId = await TokenStorage().getUserId();
    setState(() {
      _currentUserId = userId;
    });
  }
  
  Future<void> _pickAndSendImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image == null) return;
    
    setState(() => _isUploading = true);
    
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
        'type': 'image',
      });
      
      final response = await ApiClient().dio.post('/files/upload', data: formData);
      final url = response.data['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: 'image',
        mediaUrl: url,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  Future<void> _takeAndSendPhoto() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (photo == null) return;
    
    setState(() => _isUploading = true);
    
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(photo.path),
        'type': 'image',
      });
      
      final response = await ApiClient().dio.post('/files/upload', data: formData);
      final url = response.data['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: 'image',
        mediaUrl: url,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
      type: 'text',
      content: text,
    );
    
    _messageController.clear();
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _startCall(bool isVideo) {
    final roomId = const Uuid().v4();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallPage(
          roomId: roomId,
          isVideo: isVideo,
          isCaller: true,
          conversationId: widget.conversationId,
        ),
      ),
    );
  }
  
  void _goBack() {
    ref.read(routerProvider.notifier).goHome();
  }
  
  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goBack,
          ),
          title: const Text('聊天', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.white),
              onPressed: () => _startCall(false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () => _startCall(true),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: const Text(
                              '暂无消息\n发送一条消息开始聊天',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                            message: messages[index],
                            currentUserId: _currentUserId,
                            maxWidth: constraints.maxWidth,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (error, stack) => Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Text('加载失败', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(messagesProvider(widget.conversationId)),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                GlassContainer(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  borderRadius: 24,
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: _isUploading ? null : () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => GlassContainer(
                                padding: const EdgeInsets.all(16),
                                borderRadius: 20,
                                child: SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.photo_library, color: Colors.white),
                                        title: const Text('从相册选择', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickAndSendImage();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt, color: Colors.white),
                                        title: const Text('拍照', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _takeAndSendPhoto();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('语音消息需要完整版客户端')),
                            );
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: AppTheme.inputText, fontSize: 16, fontWeight: FontWeight.w500),
                            decoration: AppTheme.glassInputDecoration(
                              hintText: '输入消息...',
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _isUploading ? null : _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String? currentUserId;
  final double maxWidth;
  
  const _MessageBubble({required this.message, this.currentUserId, this.maxWidth = 400});
  
  @override
  Widget build(BuildContext context) {
    final isMe = currentUserId != null && message.senderId == currentUserId;
    final timeFormat = DateFormat('HH:mm');
    final bubbleMaxWidth = maxWidth > 600 ? 450.0 : maxWidth * 0.75;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: bubbleMaxWidth,
        ),
        decoration: BoxDecoration(
          color: isMe 
              ? AppTheme.primaryColor.withOpacity(0.9)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '对方',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (message.type == 'text')
              Text(
                message.content ?? '',
                style: const TextStyle(color: Colors.white),
              )
            else if (message.type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: message.mediaUrl != null
                    ? Image.network(
                        'http://localhost:8080/api/v1${message.mediaUrl}',
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 50),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                    : Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image),
                      ),
              )
            else if (message.type == 'voice')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 8),
                  Text(
                    '${message.duration ?? 0}s',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              message.createdAt != null ? timeFormat.format(message.createdAt!) : '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}