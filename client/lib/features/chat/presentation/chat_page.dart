import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../data/chat_provider.dart';
import '../domain/message.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';

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
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
  
  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    
    return Scaffold(
      appBar: AppBar(
title: const Text('聊天'),
        actions: [
           IconButton(
             icon: const Icon(Icons.phone),
             onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('通话功能需要完整版客户端')),
               );
             },
           ),
           IconButton(
             icon: const Icon(Icons.videocam),
             onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('通话功能需要完整版客户端')),
               );
             },
           ),
         ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('暂无消息'));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: messages[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _isUploading ? null : () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('从相册选择'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickAndSendImage();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('拍照'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _takeAndSendPhoto();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('语音消息需要完整版客户端')),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isUploading ? null : _sendMessage,
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

class _MessageBubble extends StatelessWidget {
  final Message message;
  
  const _MessageBubble({required this.message});
  
  @override
  Widget build(BuildContext context) {
    final isMe = true; // TODO: Check if message is from current user
    final timeFormat = DateFormat('HH:mm');
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.type == 'text')
              Text(
                message.content ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
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
                  Icon(Icons.play_arrow, color: isMe ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    '${message.duration ?? 0}s',
                    style: TextStyle(color: isMe ? Colors.white : Colors.black),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              timeFormat.format(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}