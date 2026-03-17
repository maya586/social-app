import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../data/call_service.dart';
import '../../../core/network/api_config.dart';

class CallPage extends ConsumerStatefulWidget {
  final String roomId;
  final bool isVideo;
  final bool isCaller;
  
  const CallPage({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
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
  Duration _callDuration = Duration.zero;
  
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
      _remoteRenderer.srcObject = stream;
      setState(() => _isConnected = true);
    };
    
    _callService.onCallEnded = () {
      Navigator.of(context).pop();
    };
    
    _callService.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    };
    
    if (widget.isCaller) {
      await _callService.startCall(widget.roomId, widget.isVideo, ApiConfig.wsUrl);
    } else {
      await _callService.joinCall(widget.roomId, widget.isVideo, ApiConfig.wsUrl);
    }
    
    _localRenderer.srcObject = _callService.localStream;
    
    setState(() {});
    
    Future.delayed(const Duration(seconds: 1), () {
      if (_isConnected) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }
  
  @override
  void dispose() {
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isConnected ? '通话中' : '正在连接...',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  if (_isConnected) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_callDuration),
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ],
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => _endCall(),
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
                if (widget.isVideo)
                  _buildControlButton(
                    icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                    label: _isCameraEnabled ? '关闭摄像头' : '开启摄像头',
                    onPressed: () {
                      setState(() => _isCameraEnabled = !_isCameraEnabled);
                      _callService.toggleCamera(_isCameraEnabled);
                    },
                  ),
                if (widget.isVideo)
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    label: '切换摄像头',
                    onPressed: () => _callService.switchCamera(),
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
            color: backgroundColor ?? Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  void _endCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束通话'),
        content: const Text('确定要结束通话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}