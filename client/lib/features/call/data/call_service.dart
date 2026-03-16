import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import '../domain/call_state.dart';

final callServiceProvider = StateNotifierProvider<CallService, CallState>((ref) {
  return CallService();
});

class CallService extends StateNotifier<CallState> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = [];
  String? _roomId;
  String? _currentUserId;
  
  CallService() : super(const CallState());
  
  Future<void> createCall(String conversationId, CallType type) async {
    state = state.copyWith(status: CallStatus.connecting, callType: type);
    
    try {
      final response = await ApiClient().dio.post('/calls/create', data: {
        'conversation_id': conversationId,
        'type': type == CallType.audio ? 'audio' : 'video',
      });
      
      _roomId = response.data['room_id'];
      
      await _initializePeerConnection();
      
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      WebSocketService().send({
        'event': 'call:offer',
        'data': {
          'room_id': _roomId,
          'offer': offer.toMap(),
        },
      });
      
      state = state.copyWith(
        status: CallStatus.connecting,
        roomId: _roomId,
      );
    } catch (e) {
      state = state.copyWith(status: CallStatus.failed, error: e.toString());
    }
  }
  
  Future<void> joinCall(String roomId) async {
    state = state.copyWith(status: CallStatus.connecting);
    _roomId = roomId;
    
    try {
      await ApiClient().dio.post('/calls/join', data: {'room_id': roomId});
      
      await _initializePeerConnection();
      
      state = state.copyWith(status: CallStatus.connected, roomId: roomId);
    } catch (e) {
      state = state.copyWith(status: CallStatus.failed, error: e.toString());
    }
  }
  
  Future<void> _initializePeerConnection() async {
    final config = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };
    
    _peerConnection = await createPeerConnection(config);
    
    _peerConnection!.onIceCandidate = (candidate) {
      if (_roomId != null) {
        WebSocketService().send({
          'event': 'call:ice-candidate',
          'data': {
            'room_id': _roomId,
            'candidate': candidate.toMap(),
          },
        });
      }
    };
    
    _peerConnection!.onTrack = (event) {
      if (event.track != null && event.streams.isNotEmpty) {
        _remoteStreams.add(event.streams[0]);
        state = state.copyWith(remoteStreams: List.from(_remoteStreams));
      }
    };
    
    _peerConnection!.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          this.state = this.state.copyWith(status: CallStatus.connected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          endCall();
          break;
        default:
          break;
      }
    };
    
    await _getUserMedia();
  }
  
  Future<void> _getUserMedia() async {
    final constraints = {
      'audio': true,
      'video': state.callType == CallType.video,
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    
    for (final track in _localStream!.getTracks()) {
      _peerConnection!.addTrack(track, _localStream!);
    }
    
    state = state.copyWith(localStream: _localStream);
  }
  
  void handleOffer(Map<String, dynamic> data) async {
    try {
      final offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      
      await _peerConnection?.setRemoteDescription(offer);
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      WebSocketService().send({
        'event': 'call:answer',
        'data': {
          'room_id': _roomId,
          'answer': answer.toMap(),
        },
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  void handleAnswer(Map<String, dynamic> data) async {
    try {
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      
      await _peerConnection?.setRemoteDescription(answer);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  void handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMlineIndex'],
      );
      
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  void toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
        state = state.copyWith(isMuted: !audioTrack.enabled);
      }
    }
  }
  
  void toggleVideo() {
    if (_localStream != null && state.callType == CallType.video) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        state = state.copyWith(isVideoOff: !videoTrack.enabled);
      }
    }
  }
  
  void switchCamera() {
    if (_localStream != null && state.callType == CallType.video) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.switchCamera();
      }
    }
  }
  
  Future<void> endCall() async {
    if (_roomId != null) {
      try {
        await ApiClient().dio.delete('/calls/$_roomId');
      } catch (e) {
        // Ignore errors when ending call
      }
    }
    
    await _localStream?.dispose();
    await _peerConnection?.close();
    
    _localStream = null;
    _peerConnection = null;
    _remoteStreams.clear();
    _roomId = null;
    
    state = const CallState(status: CallStatus.ended);
  }
  
  void reset() {
    state = const CallState();
  }
}