import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallStatus {
  idle,
  connecting,
  connected,
  ended,
  failed,
}

enum CallType {
  audio,
  video,
}

class CallState {
  final CallStatus status;
  final CallType callType;
  final String? roomId;
  final String? conversationId;
  final String? callerId;
  final String? callerName;
  final MediaStream? localStream;
  final List<MediaStream> remoteStreams;
  final bool isMuted;
  final bool isVideoOff;
  final String? error;
  final Duration? duration;

  const CallState({
    this.status = CallStatus.idle,
    this.callType = CallType.audio,
    this.roomId,
    this.conversationId,
    this.callerId,
    this.callerName,
    this.localStream,
    this.remoteStreams = const [],
    this.isMuted = false,
    this.isVideoOff = false,
    this.error,
    this.duration,
  });

  CallState copyWith({
    CallStatus? status,
    CallType? callType,
    String? roomId,
    String? conversationId,
    String? callerId,
    String? callerName,
    MediaStream? localStream,
    List<MediaStream>? remoteStreams,
    bool? isMuted,
    bool? isVideoOff,
    String? error,
    Duration? duration,
  }) {
    return CallState(
      status: status ?? this.status,
      callType: callType ?? this.callType,
      roomId: roomId ?? this.roomId,
      conversationId: conversationId ?? this.conversationId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      localStream: localStream ?? this.localStream,
      remoteStreams: remoteStreams ?? this.remoteStreams,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      error: error ?? this.error,
      duration: duration ?? this.duration,
    );
  }

  bool get isInCall => status == CallStatus.connected || status == CallStatus.connecting;
  bool get isVideoCall => callType == CallType.video;
}