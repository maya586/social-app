import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_recorder_service.dart';

class VoiceRecordingWidget extends ConsumerStatefulWidget {
  final VoidCallback? onRecordComplete;
  final VoidCallback? onCancel;

  const VoiceRecordingWidget({
    super.key,
    this.onRecordComplete,
    this.onCancel,
  });

  @override
  ConsumerState<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends ConsumerState<VoiceRecordingWidget> {
  @override
  Widget build(BuildContext context) {
    final recorderState = ref.watch(voiceRecorderProvider);

    if (!recorderState.isRecording && !recorderState.isPaused) {
      return _buildRecordButton();
    }

    return _buildRecordingControls(recorderState);
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onLongPressStart: (_) async {
        final service = ref.read(voiceRecorderProvider.notifier);
        final hasPermission = await service.checkPermission();
        if (hasPermission) {
          await service.startRecording();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请授予录音权限')),
            );
          }
        }
      },
      onLongPressEnd: (_) async {
        final service = ref.read(voiceRecorderProvider.notifier);
        await service.stopRecording();
        widget.onRecordComplete?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildRecordingControls(VoiceRecorderState recorderState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAmplitudeIndicator(recorderState.amplitude),
          const SizedBox(width: 12),
          Text(
            _formatDuration(recorderState.duration),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () {
              ref.read(voiceRecorderProvider.notifier).cancelRecording();
              widget.onCancel?.call();
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () async {
              await ref.read(voiceRecorderProvider.notifier).stopRecording();
              widget.onRecordComplete?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmplitudeIndicator(double amplitude) {
    final normalizedAmplitude = ((amplitude + 60) / 60).clamp(0.0, 1.0);
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2 + normalizedAmplitude * 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.mic,
        color: Colors.red,
        size: 20,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class VoiceMessageWidget extends ConsumerStatefulWidget {
  final String audioUrl;
  final Duration? duration;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    this.duration,
  });

  @override
  ConsumerState<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends ConsumerState<VoiceMessageWidget> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration? _audioDuration;
  bool _isPlaying = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.setUrl(widget.audioUrl);
    _audioDuration = _player.duration;
    _positionSubscription = _player.positionStream.listen((position) {
      setState(() => _position = position);
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final displayDuration = widget.duration ?? _audioDuration ?? Duration.zero;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePlayback,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _audioDuration != null && _audioDuration!.inMilliseconds > 0
                          ? _position.inMilliseconds / _audioDuration!.inMilliseconds
                          : 0,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(displayDuration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}