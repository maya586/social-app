import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../data/call_service.dart';
import '../domain/call_state.dart';

class CallPage extends ConsumerStatefulWidget {
  final String conversationId;
  final CallType callType;
  final String? callerName;
  
  const CallPage({
    super.key,
    required this.conversationId,
    required this.callType,
    this.callerName,
  });
  
  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _showParticipants = false;
  
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callServiceProvider.notifier).createCall(
        widget.conversationId,
        widget.callType,
      );
    });
    
    _startDurationTimer();
  }
  
  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
  
  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _duration += const Duration(seconds: 1);
        });
      }
    });
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callServiceProvider);
    final callService = ref.read(callServiceProvider.notifier);
    
    return WillPopScope(
      onWillPop: () async {
        await callService.endCall();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildVideoView(callState),
              _buildControls(callState, callService),
              _buildTopBar(callState),
              _buildParticipantsPanel(callState),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVideoView(CallState callState) {
    if (callState.callType == CallType.audio) {
      return _buildAudioCallView(callState);
    }
    
    final remoteCount = callState.remoteStreams.length;
    
    if (remoteCount <= 1) {
      return _buildOneOnOneVideoView(callState);
    }
    
    return _buildGroupVideoView(callState);
  }
  
  Widget _buildAudioCallView(CallState callState) {
    final participantCount = callState.remoteStreams.length + 1;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.callerName?.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.callerName ?? '通话中',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$participantCount 人通话 · ${_formatDuration(_duration)}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOneOnOneVideoView(CallState callState) {
    return Stack(
      children: [
        if (callState.remoteStreams.isNotEmpty)
          Positioned.fill(
            child: RTCVideoView(
              RTCVideoRenderer()..srcObject = callState.remoteStreams.first,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        if (callState.localStream != null)
          Positioned(
            right: 16,
            top: 80,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  RTCVideoRenderer()..srcObject = callState.localStream,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildGroupVideoView(CallState callState) {
    final allStreams = <MediaStream?>[
      callState.localStream,
      ...callState.remoteStreams,
    ];
    
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: allStreams.length > 4 ? 3 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: allStreams.length,
            itemBuilder: (context, index) {
              final stream = allStreams[index];
              final isLocal = index == 0;
              
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: stream != null
                      ? RTCVideoView(
                          RTCVideoRenderer()..srcObject = stream,
                          mirror: isLocal,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                isLocal ? '我' : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildTopBar(CallState callState) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                await ref.read(callServiceProvider.notifier).endCall();
                if (mounted) Navigator.pop(context);
              },
            ),
            const Spacer(),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControls(CallState callState, CallService callService) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: callState.isMuted ? Icons.mic_off : Icons.mic,
            label: callState.isMuted ? '取消静音' : '静音',
            isActive: !callState.isMuted,
            onPressed: callService.toggleMute,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: '结束',
            backgroundColor: Colors.red,
            onPressed: () async {
              await callService.endCall();
              if (mounted) Navigator.pop(context);
            },
          ),
          if (callState.callType == CallType.video)
            _buildControlButton(
              icon: callState.isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: callState.isVideoOff ? '开启视频' : '关闭视频',
              isActive: !callState.isVideoOff,
              onPressed: callService.toggleVideo,
            ),
          if (callState.callType == CallType.video)
            _buildControlButton(
              icon: Icons.switch_camera,
              label: '切换',
              onPressed: callService.switchCamera,
            ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = true,
    Color? backgroundColor,
    VoidCallback? onPressed,
  }) {
    final bgColor = backgroundColor ?? (isActive ? Colors.white24 : Colors.grey);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
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
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
  
  Widget _buildParticipantsPanel(CallState callState) {
    final participantCount = callState.remoteStreams.length + 1;
    
    return Positioned(
      bottom: 120,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showParticipants = !_showParticipants),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$participantCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IncomingCallDialog extends StatelessWidget {
  final String callerName;
  final CallType callType;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  
  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onReject,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  callerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              callType == CallType.video ? '视频通话邀请' : '语音通话邀请',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_end),
                  label: const Text('拒绝'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onReject,
                ),
                ElevatedButton.icon(
                  icon: Icon(callType == CallType.video ? Icons.videocam : Icons.call),
                  label: const Text('接听'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}