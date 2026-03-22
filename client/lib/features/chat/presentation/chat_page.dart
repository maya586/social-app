import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../data/chat_provider.dart';
import '../domain/message.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/online_status_provider.dart';
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
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isUploading = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentUserId;
  String? _otherUserId;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _playingMessageId;
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
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentUserId() async {
    final userId = await TokenStorage().getUserId();
    setState(() {
      _currentUserId = userId;
    });
    
    try {
      final response = await ApiClient().dio.get('/conversations/${widget.conversationId}');
      final data = response.data['data'] ?? response.data;
      setState(() {
        _otherUserId = data['other_user_id']?.toString();
      });
    } catch (e) {
      print('Failed to load conversation: $e');
    }
  }
  
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      setState(() => _isUploading = true);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
      });
      
      final response = await ApiClient().dio.post('/files/upload?type=image', data: formData);
      final url = response.data['data']['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: 'image',
        mediaUrl: url,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  Future<void> _takeAndSendPhoto() async {
    try {
      XFile? photo;
      
      if (Platform.isWindows || Platform.isLinux) {
        final typeGroup = XTypeGroup(
          label: 'images',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        );
        photo = await openFile(acceptedTypeGroups: [typeGroup]);
      } else {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
      }
      
      if (photo == null) return;
      
      setState(() => _isUploading = true);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(photo.path),
      });
      
      final response = await ApiClient().dio.post('/files/upload?type=image', data: formData);
      final url = response.data['data']['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: 'image',
        mediaUrl: url,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  Future<void> _pickAndSendFile() async {
    try {
      final XFile? file = await openFile();
      if (file == null) return;
      
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件大小不能超过50MB')),
          );
        }
        return;
      }
      
      setState(() => _isUploading = true);
      
      final fileName = p.basename(file.path);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      
      String fileType = 'file';
      if (mimeType.startsWith('image/')) {
        fileType = 'image';
      } else if (mimeType.startsWith('video/')) {
        fileType = 'video';
      } else if (mimeType.startsWith('audio/')) {
        fileType = 'audio';
      }
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      
      final response = await ApiClient().dio.post('/files/upload?type=$fileType', data: formData);
      final url = response.data['data']['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: fileType,
        mediaUrl: url,
        content: fileName,
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
  
  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能录音')),
          );
        }
        return;
      }
      
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordingDuration++);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null && _recordingDuration > 0) {
        _sendVoiceMessage(path, _recordingDuration);
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送语音失败: $e')),
        );
      }
    }
  }
  
  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }
  
  Future<void> _sendVoiceMessage(String filePath, int duration) async {
    try {
      setState(() => _isUploading = true);
      
      final file = File(filePath);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });
      
      final response = await ApiClient().dio.post('/files/upload?type=voice', data: formData);
      final url = response.data['data']['url'];
      
      ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
        type: 'voice',
        mediaUrl: url,
        duration: duration,
      );
      
      await file.delete();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送语音失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  Future<void> _playVoiceMessage(String url, String messageId) async {
    try {
      if (_isPlaying && _playingMessageId == messageId) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _playingMessageId = null;
        });
        return;
      }
      
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _playingMessageId = null;
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      await _audioPlayer.setUrl('${ApiConfig.baseUrl}$url');
      await _audioPlayer.play();
      
      setState(() {
        _isPlaying = true;
        _playingMessageId = messageId;
      });
      
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playingMessageId = null;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
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
  
  Future<void> _deleteMessage(String messageId) async {
    try {
      await ref.read(messagesProvider(widget.conversationId).notifier).deleteMessage(messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息已删除')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final message = e.response?.data?['message'] ?? e.message ?? '未知错误';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
  
  bool _canPreviewFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    const previewableExtensions = [
      '.txt', '.json', '.xml', '.log', '.md', '.csv',
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp',
      '.mp3', '.wav', '.ogg', '.m4a', '.aac',
      '.mp4', '.webm',
    ];
    return previewableExtensions.contains(ext);
  }

  Future<void> _showFilePreview(String mediaUrl, String fileName, String messageId) async {
    final ext = p.extension(fileName).toLowerCase();
    
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
      _showImagePreview(mediaUrl);
    } else if (['.mp3', '.wav', '.ogg', '.m4a', '.aac'].contains(ext)) {
      _showAudioPreview(mediaUrl, fileName, messageId);
    } else if (['.txt', '.json', '.xml', '.log', '.md', '.csv'].contains(ext)) {
      _showTextPreview(mediaUrl, fileName);
    } else if (['.mp4', '.webm'].contains(ext)) {
      _showVideoPreview(mediaUrl, fileName);
    } else {
      _showDownloadConfirmDialog(mediaUrl, fileName);
    }
  }

  void _showImagePreview(String mediaUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            onSecondaryTapDown: (details) {
              final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
              final position = RelativeRect.fromRect(
                Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
                Offset.zero & overlay.size,
              );
              
              showMenu<String>(
                context: context,
                position: position,
                items: [
                  const PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, color: Colors.white),
                        SizedBox(width: 8),
                        Text('下载图片', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value == 'download') {
                  Navigator.pop(context);
                  final fileName = mediaUrl.split('/').last;
                  _downloadFile(mediaUrl, fileName);
                }
              });
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Listener(
                onPointerDown: (event) {
                  if (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus) {
                  }
                },
                child: GestureDetector(
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.grey[900],
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.download, color: Colors.white),
                              title: const Text('下载图片', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                                final fileName = mediaUrl.split('/').last;
                                _downloadFile(mediaUrl, fileName);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        '${ApiConfig.baseUrl}$mediaUrl',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, color: Colors.white, size: 50);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAudioPreview(String mediaUrl, String fileName, String messageId) {
    showDialog(
      context: context,
      builder: (context) => _AudioPreviewDialog(
        mediaUrl: mediaUrl,
        fileName: fileName,
      ),
    );
  }

  Future<void> _showTextPreview(String mediaUrl, String fileName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.description, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: const SizedBox(
          width: 400,
          height: 300,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );

    try {
      final response = await ApiClient().dio.get(
        '${ApiConfig.baseUrl}$mediaUrl',
        options: Options(responseType: ResponseType.plain),
      );
      
      String content = response.data.toString();
      if (content.length > 10000) {
        content = content.substring(0, 10000) + '\n\n... (内容过长，已截断)';
      }

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                const Icon(Icons.description, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadFile(mediaUrl, fileName);
                },
                child: const Text('下载'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('预览失败: $e')),
        );
        _showDownloadConfirmDialog(mediaUrl, fileName);
      }
    }
  }

  void _showVideoPreview(String mediaUrl, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
              ),
            ),
            const SizedBox(height: 16),
            const Text('视频预览功能开发中', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadFile(mediaUrl, fileName);
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  void _showDownloadConfirmDialog(String mediaUrl, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('下载文件', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('无法预览此文件类型', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 8),
            Text('文件名: $fileName', style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadFile(mediaUrl, fileName);
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String mediaUrl, String fileName) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法访问下载目录')),
          );
        }
        return;
      }
      
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      int counter = 1;
      var finalPath = filePath;
      while (await file.exists()) {
        final ext = p.extension(fileName);
        final name = p.basenameWithoutExtension(fileName);
        finalPath = '${directory.path}/${name}_$counter$ext';
        counter++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在下载...')),
        );
      }
      
      final response = await ApiClient().dio.get(
        '${ApiConfig.baseUrl}$mediaUrl',
        options: Options(responseType: ResponseType.bytes),
      );
      
      final newFile = File(finalPath);
      await newFile.writeAsBytes(response.data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件已保存到: $finalPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
  
  void _startCall(bool isVideo) async {
    if (_otherUserId == null) {
      await _loadCurrentUserId();
      if (_otherUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取对方信息，请稍后重试')),
          );
        }
        return;
      }
    }
    
    final onlineStatus = ref.read(onlineStatusProvider);
    final isOnline = onlineStatus[_otherUserId] ?? false;
    
    if (!isOnline) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('无法通话', style: TextStyle(color: Colors.white)),
          content: const Text('对方当前不在线，无法发起通话', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
      return;
    }
    
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
                            onDelete: _deleteMessage,
                            onPlayVoice: _playVoiceMessage,
                            onDownloadFile: _downloadFile,
                            onPreviewFile: _showFilePreview,
                            isPlaying: _isPlaying,
                            playingMessageId: _playingMessageId,
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
                                      if (Platform.isWindows || Platform.isLinux) ...[
                                        ListTile(
                                          leading: const Icon(Icons.image, color: Colors.white),
                                          title: const Text('选择图片', style: TextStyle(color: Colors.white)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _takeAndSendPhoto();
                                          },
                                        ),
                                      ] else ...[
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
                                      ListTile(
                                        leading: const Icon(Icons.attach_file, color: Colors.white),
                                        title: const Text('发送文件', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickAndSendFile();
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
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: _isRecording ? Colors.red : Colors.white,
                          ),
                          onPressed: _isRecording ? _stopRecording : null,
                        ),
                        GestureDetector(
                          onLongPressStart: _isRecording ? null : (_) => _startRecording(),
                          onLongPressEnd: _isRecording ? (details) {
                            if (details.localPosition.dy < -50) {
                              _cancelRecording();
                            } else {
                              _stopRecording();
                            }
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isRecording 
                                  ? '松开发送，上滑取消 (${_recordingDuration}s)'
                                  : '按住说话',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
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
  final Function(String)? onDelete;
  final Function(String, String)? onPlayVoice;
  final Function(String, String)? onDownloadFile;
  final Function(String, String, String)? onPreviewFile;
  final bool isPlaying;
  final String? playingMessageId;
  
  const _MessageBubble({
    required this.message,
    this.currentUserId,
    this.maxWidth = 400,
    this.onDelete,
    this.onPlayVoice,
    this.onDownloadFile,
    this.onPreviewFile,
    this.isPlaying = false,
    this.playingMessageId,
  });
  
  void _showImagePreview(BuildContext context, String? mediaUrl) {
    if (mediaUrl == null) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                '${ApiConfig.baseUrl}$mediaUrl',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.white, size: 50);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isMe = currentUserId != null && message.senderId == currentUserId;
    final timeFormat = DateFormat('HH:mm');
    final bubbleMaxWidth = maxWidth > 600 ? 450.0 : maxWidth * 0.75;
    
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (isMe && onDelete != null) {
          _showContextMenu(context, details, message.id);
        }
      },
      child: Align(
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
              GestureDetector(
                onTap: () => _showImagePreview(context, message.mediaUrl),
                onDoubleTap: () => _showImagePreview(context, message.mediaUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: message.mediaUrl != null
                      ? Container(
                          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                          child: Image.network(
                            '${ApiConfig.baseUrl}${message.mediaUrl}',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 150,
                                height: 150,
                                color: Colors.grey[300],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image, size: 50),
                                    Text('加载失败', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 150,
                                height: 150,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                ),
              )
            else if (message.type == 'video')
              GestureDetector(
                onTap: () {
                  if (message.mediaUrl != null && onPreviewFile != null) {
                    onPreviewFile!(message.mediaUrl!, message.content ?? 'video', message.id);
                  }
                },
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        message.content ?? '视频',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            else if (message.type == 'audio')
              GestureDetector(
                onTap: () {
                  if (message.mediaUrl != null && onPreviewFile != null) {
                    onPreviewFile!(message.mediaUrl!, message.content ?? 'audio', message.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.audiotrack, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        message.content ?? '音频',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.play_arrow, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              )
            else if (message.type == 'file')
              GestureDetector(
                onTap: () {
                  if (message.mediaUrl != null && onPreviewFile != null) {
                    onPreviewFile!(message.mediaUrl!, message.content ?? 'file', message.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.content ?? '文件',
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.visibility, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              )
            else if (message.type == 'voice')
              GestureDetector(
                onTap: () {
                  if (message.mediaUrl != null && onPlayVoice != null) {
                    onPlayVoice!(message.mediaUrl!, message.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying && playingMessageId == message.id 
                            ? Icons.pause 
                            : Icons.play_arrow, 
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${message.duration ?? 0}s',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
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
    ),
    );
  }
  
  void _showContextMenu(BuildContext context, TapDownDetails details, String messageId) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    
    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('删除消息'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
        onDelete?.call(messageId);
      }
    });
  }
}

class _AudioPreviewDialog extends StatefulWidget {
  final String mediaUrl;
  final String fileName;
  
  const _AudioPreviewDialog({
    required this.mediaUrl,
    required this.fileName,
  });
  
  @override
  State<_AudioPreviewDialog> createState() => _AudioPreviewDialogState();
}

class _AudioPreviewDialogState extends State<_AudioPreviewDialog> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
  }
  
  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.setUrl('${ApiConfig.baseUrl}${widget.mediaUrl}');
      setState(() => _isLoading = false);
      
      _audioPlayer.durationStream.listen((duration) {
        if (mounted) setState(() => _duration = duration ?? Duration.zero);
      });
      
      _audioPlayer.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      });
      
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            setState(() => _isPlaying = false);
            _audioPlayer.seek(Duration.zero);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          const Icon(Icons.audiotrack, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.fileName, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 64,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (_isPlaying) {
                            _audioPlayer.pause();
                          } else {
                            _audioPlayer.play();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: _position.inMilliseconds.toDouble(),
                        max: _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                        activeColor: AppTheme.primaryColor,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70)),
                          Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}