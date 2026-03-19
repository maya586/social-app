import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../../../core/network/websocket_service.dart';
import '../../../core/storage/token_storage.dart';

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentRoomId;
  String? _currentUserId;
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  bool _isInitialized = false;
  bool _isEnded = false;
  
  static bool useTurnServer = false;
  
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onError;
  Function()? onConnected;
  
  Future<bool> checkPermissions(bool video) async {
    var microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) {
      microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        onError?.call('需要麦克风权限才能通话');
        return false;
      }
    }
    
    if (video) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          onError?.call('需要摄像头权限才能视频通话');
          return false;
        }
      }
    }
    return true;
  }
  
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _currentUserId = await TokenStorage().getUserId();
      _remoteDescriptionSet = false;
      _pendingCandidates.clear();
      _isEnded = false;
      await _createPeerConnection();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Initialize error: $e');
      onError?.call('初始化通话失败: $e');
      return false;
    }
  }
  
  Future<void> _createPeerConnection() async {
    Map<String, dynamic> config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
      ],
      'iceCandidatePoolSize': 20,
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all',
    };
    
    if (useTurnServer) {
      config['iceServers'].addAll([
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ]);
    }
    
    _peerConnection = await createPeerConnection(config);
    
    _peerConnection?.onIceCandidate = (candidate) {
      if (_currentRoomId != null && candidate.candidate != null && !_isEnded) {
        try {
          WebSocketService().send({
            'event': 'call:ice-candidate',
            'data': {
              'room_id': _currentRoomId,
              'candidate': {
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              },
            },
          });
        } catch (e) {
          print('Error sending ICE candidate: $e');
        }
      }
    };
    
    _peerConnection?.onIceGatheringState = (state) {
      print('ICE gathering state: $state');
    };
    
    _peerConnection?.onIceConnectionState = (state) {
      print('ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onConnected?.call();
      }
      if (!_isEnded && (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed)) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isEnded && _peerConnection != null) {
            final currentState = _peerConnection?.iceConnectionState;
            if (currentState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                currentState == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              print('ICE connection lost, ending call');
              onCallEnded?.call();
            }
          }
        });
      }
    };
    
    _peerConnection?.onTrack = (event) {
      print('onTrack: ${event.track.kind}, streams: ${event.streams.length}');
      if (event.streams.isNotEmpty && !_isEnded) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(event.streams[0]);
      } else if (event.track.kind == 'audio' || event.track.kind == 'video') {
        print('Received ${event.track.kind} track without stream');
      }
    };
    
    _peerConnection?.onAddStream = (stream) {
      print('onAddStream: ${stream.id}');
      if (!_isEnded) {
        _remoteStream = stream;
        onRemoteStream?.call(stream);
      }
    };
    
    _peerConnection?.onConnectionState = (state) {
      print('Peer connection state: $state');
    };
    
    _peerConnection?.onAddTrack = (stream, track) {
      print('onAddTrack: ${track.kind}');
      if (!_isEnded) {
        _remoteStream = stream;
        onRemoteStream?.call(stream);
      }
    };
  }
  
  Future<bool> startCall(String roomId, bool video, String conversationId) async {
    try {
      _currentRoomId = roomId;
      _remoteDescriptionSet = false;
      _isEnded = false;
      
      _localStream = await _getUserMedia(video);
      if (_localStream == null) {
        onError?.call('无法获取本地媒体流');
        return false;
      }
      
      print('Local stream obtained: ${_localStream!.id}');
      print('Audio tracks: ${_localStream!.getAudioTracks().length}');
      print('Video tracks: ${_localStream!.getVideoTracks().length}');
      
      for (var track in _localStream!.getTracks()) {
        print('Adding track: ${track.kind}');
        _peerConnection?.addTrack(track, _localStream!);
      }
      
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': video,
      });
      await _peerConnection!.setLocalDescription(offer);
      print('Local description set');
      
      WebSocketService().send({
        'event': 'call:offer',
        'data': {
          'room_id': roomId,
          'conversation_id': conversationId,
          'is_video': video,
          'type': 'offer',
          'sdp': offer.sdp,
        },
      });
      
      print('Offer sent');
      return true;
    } catch (e) {
      print('startCall error: $e');
      onError?.call('发起通话失败: $e');
      return false;
    }
  }
  
  Future<bool> answerCall(String roomId, bool video, Map<String, dynamic> offerData) async {
    try {
      _currentRoomId = roomId;
      _remoteDescriptionSet = false;
      _isEnded = false;
      
      final sdp = offerData['sdp'] as String?;
      if (sdp == null) {
        onError?.call('无效的通话请求');
        return false;
      }
      
      _localStream = await _getUserMedia(video);
      if (_localStream == null) {
        onError?.call('无法获取本地媒体流');
        return false;
      }
      
      print('Local stream obtained: ${_localStream!.id}');
      
      for (var track in _localStream!.getTracks()) {
        print('Adding track: ${track.kind}');
        _peerConnection?.addTrack(track, _localStream!);
      }
      
      print('Setting remote description...');
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteDescriptionSet = true;
      print('Remote offer set');
      
      _addPendingCandidates();
      
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': video,
      });
      await _peerConnection!.setLocalDescription(answer);
      print('Local answer set');
      
      WebSocketService().send({
        'event': 'call:answer',
        'data': {
          'room_id': roomId,
          'type': 'answer',
          'sdp': answer.sdp,
          'target_user_id': offerData['sender_id'],
        },
      });
      
      print('Answer sent');
      return true;
    } catch (e) {
      print('answerCall error: $e');
      onError?.call('接听通话失败: $e');
      return false;
    }
  }
  
  Future<void> handleSignal(Map<String, dynamic> message) async {
    try {
      final event = message['event'];
      final rawData = message['data'];
      
      if (rawData == null || _isEnded) return;
      
      Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        try {
          data = jsonDecode(rawData) as Map<String, dynamic>;
        } catch (e) {
          print('Failed to decode signal data: $e');
          return;
        }
      }
      
      if (data == null) return;
      if (data['sender_id'] == _currentUserId) return;
      
      print('Handling signal: $event');
      
      if (event == 'call:answer') {
        final sdp = data['sdp'] as String?;
        if (sdp != null && _peerConnection != null && !_isEnded) {
          print('Setting remote answer');
          try {
            await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
            _remoteDescriptionSet = true;
            _addPendingCandidates();
          } catch (e) {
            print('Error setting remote answer: $e');
          }
        }
      }
      
      if (event == 'call:ice-candidate') {
        final c = data['candidate'];
        if (c != null && !_isEnded) {
          Map<String, dynamic> cm;
          if (c is Map<String, dynamic>) {
            cm = c;
          } else if (c is String) {
            try {
              cm = jsonDecode(c) as Map<String, dynamic>;
            } catch (e) {
              print('Failed to decode candidate: $e');
              return;
            }
          } else {
            return;
          }
          
          if (_remoteDescriptionSet && _peerConnection != null) {
            try {
              final candidate = RTCIceCandidate(
                cm['candidate'],
                cm['sdpMid'],
                cm['sdpMLineIndex'],
              );
              await _peerConnection!.addCandidate(candidate);
              print('ICE candidate added');
            } catch (e) {
              print('Error adding ICE candidate: $e');
            }
          } else {
            _pendingCandidates.add(cm);
            print('ICE candidate cached (${_pendingCandidates.length})');
          }
        }
      }
      
      if (event == 'call:end' || event == 'call:leave') {
        if (!_isEnded) {
          onCallEnded?.call();
        }
      }
    } catch (e) {
      print('handleSignal error: $e');
    }
  }
  
  void _addPendingCandidates() async {
    if (_peerConnection == null) return;
    print('Adding ${_pendingCandidates.length} pending candidates');
    for (var cm in _pendingCandidates) {
      try {
        final candidate = RTCIceCandidate(
          cm['candidate'],
          cm['sdpMid'],
          cm['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
        print('Pending candidate added');
      } catch (e) {
        print('Error adding pending candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }
  
  Future<MediaStream?> _getUserMedia(bool video) async {
    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': video ? {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        } : false,
      };
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      print('Got media stream: audio=${stream.getAudioTracks().length}, video=${stream.getVideoTracks().length}');
      return stream;
    } catch (e) {
      onError?.call('无法获取媒体设备: $e');
      return null;
    }
  }
  
  void toggleMicrophone(bool enabled) {
    for (var track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = enabled;
    }
  }
  
  void notifyCallEnd() {
    if (_currentRoomId != null && !_isEnded) {
      try {
        WebSocketService().send({
          'event': 'call:end',
          'data': {'room_id': _currentRoomId},
        });
      } catch (e) {
        print('Error sending call:end: $e');
      }
    }
  }
  
  Future<void> endCall() async {
    _isEnded = true;
    
    try {
      for (var track in _localStream?.getTracks() ?? []) {
        track.stop();
      }
      await _localStream?.dispose();
    } catch (e) {
      print('Error disposing local stream: $e');
    }
    _localStream = null;
    _remoteStream = null;
    
    try {
      await _peerConnection?.close();
    } catch (e) {
      print('Error closing peer connection: $e');
    }
    _peerConnection = null;
    _currentRoomId = null;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    _isInitialized = false;
  }
  
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}