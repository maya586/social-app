import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  
  CallService._internal();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  WebSocketChannel? _signalingChannel;
  String? _currentRoomId;
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onError;
  
  Future<void> initialize() async {
    await _createPeerConnection();
  }
  
  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };
    
    _peerConnection = await createPeerConnection(config);
    
    _peerConnection?.onIceCandidate = (candidate) {
      _sendSignal({
        'type': 'ice_candidate',
        'candidate': candidate.toMap(),
      });
    };
    
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };
    
    _peerConnection?.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    };
  }
  
  Future<MediaStream> _getUserMedia(bool video) async {
    final mediaConstraints = {
      'audio': true,
      'video': video ? {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      } : false,
    };
    
    return await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }
  
  Future<void> startCall(String roomId, bool video, String wsUrl) async {
    try {
      _currentRoomId = roomId;
      
      _localStream = await _getUserMedia(video);
      
      for (var track in _localStream!.getTracks()) {
        _peerConnection?.addTrack(track, _localStream!);
      }
      
      _signalingChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/call/$roomId'),
      );
      
      _signalingChannel?.stream.listen((message) {
        _handleSignal(jsonDecode(message));
      });
      
      final offer = await _peerConnection?.createOffer();
      await _peerConnection?.setLocalDescription(offer!);
      
      _sendSignal({
        'type': 'offer',
        'sdp': offer?.sdp,
      });
    } catch (e) {
      onError?.call('启动通话失败: $e');
    }
  }
  
  Future<void> joinCall(String roomId, bool video, String wsUrl) async {
    try {
      _currentRoomId = roomId;
      
      _localStream = await _getUserMedia(video);
      
      for (var track in _localStream!.getTracks()) {
        _peerConnection?.addTrack(track, _localStream!);
      }
      
      _signalingChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/call/$roomId'),
      );
      
      _signalingChannel?.stream.listen((message) {
        _handleSignal(jsonDecode(message));
      });
    } catch (e) {
      onError?.call('加入通话失败: $e');
    }
  }
  
  void _handleSignal(Map<String, dynamic> data) async {
    switch (data['type']) {
      case 'offer':
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'offer'),
        );
        final answer = await _peerConnection?.createAnswer();
        await _peerConnection?.setLocalDescription(answer!);
        _sendSignal({
          'type': 'answer',
          'sdp': answer?.sdp,
        });
        break;
      case 'answer':
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
        break;
      case 'ice_candidate':
        await _peerConnection?.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
        break;
    }
  }
  
  void _sendSignal(Map<String, dynamic> data) {
    _signalingChannel?.sink.add(jsonEncode(data));
  }
  
  void toggleMicrophone(bool enabled) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = enabled;
    });
  }
  
  void toggleCamera(bool enabled) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }
  
  Future<void> switchCamera() async {
    _localStream?.getVideoTracks().forEach((track) async {
      await Helper.switchCamera(track);
    });
  }
  
  Future<void> endCall() async {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    
    await _peerConnection?.close();
    await _createPeerConnection();
    
    _signalingChannel?.sink.close();
    _signalingChannel = null;
    _currentRoomId = null;
    
    onCallEnded?.call();
  }
  
  MediaStream? get localStream => _localStream;
}