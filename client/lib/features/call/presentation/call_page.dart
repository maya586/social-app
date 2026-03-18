import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../data/call_service.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';

class CallPage extends ConsumerStatefulWidget {
  final String roomId;
  final bool isVideo;
  final bool isCaller;
  final String? conversationId;
  final Map<String, dynamic>? offerData;
  
  const CallPage({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
    this.conversationId,
    this.offerData,
  });
  
  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  final _callService = CallService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _isMicrophoneEnabled = true;
  bool _isCameraEnabled = true;
  bool _isConnected = false;
  bool _dialogShown = false;
  Duration _callDuration = Duration.zero;
  StreamSubscription? _wsSubscription;
  Timer? _durationTimer;
  
  @override
  void initState() {
    super.initState();
    _initCall();
  }
  
  Future<void> _initCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _callService.initialize();
    
    _callService.onRemoteStream = (stream) {
      if (mounted) {
        _remoteRenderer.srcObject = stream;
        setState(() => _isConnected = true);
        _startDurationTimer();
      }
    };
    
    _callService.onConnected = () {
      if (mounted) {
        setState(() => _isConnected = true);
        _startDurationTimer();
      }
    };
    
    _callService.onCallEnded = () {
      if (mounted && !_dialogShown) {
        _showCallEndedDialog('通话已结束');
      }
    };
    
    _callService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    };
    
    _wsSubscription = WebSocketService().messages.listen((message) {
      final event = message['event'] as String?;
      if (event?.startsWith('call:') == true) {
        _callService.handleSignal(message);
      }
    });
    
    if (widget.isCaller) {
      await _callService.startCall(widget.roomId, widget.isVideo, widget.conversationId ?? '');
    } else if (widget.offerData != null) {
      await _callService.answerCall(widget.roomId, widget.isVideo, widget.offerData!);
    }
    
    _localRenderer.srcObject = _callService.localStream;
    setState(() {});
  }
  
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }
  
  void _showCallEndedDialog(String reason) {
    if (_dialogShown) return;
    _dialogShown = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('通话结束', style: TextStyle(color: Colors.white)),
        content: Text(reason, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('确定', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _durationTimer?.cancel();
    _wsSubscription?.cancel();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _callService.endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.isVideo) ...[
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
            Positioned(
              top: 60,
              right: 20,
              child: Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),
          ] else ...[
            Container(
              decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isConnected ? '通话中' : '正在连接...',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    if (_isConnected) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(_callDuration),
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => _showEndCallDialog(),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                  label: _isMicrophoneEnabled ? '静音' : '取消静音',
                  onPressed: () {
                    setState(() => _isMicrophoneEnabled = !_isMicrophoneEnabled);
                    _callService.toggleMicrophone(_isMicrophoneEnabled);
                  },
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  label: '挂断',
                  backgroundColor: Colors.red,
                  onPressed: _endCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}';
  }
  
  void _showEndCallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('结束通话', style: TextStyle(color: Colors.white)),
        content: const Text('确定要结束通话吗？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _endCall() {
    _dialogShown = true;
    _callService.notifyCallEnd();
    Navigator.pop(context);
  }
}