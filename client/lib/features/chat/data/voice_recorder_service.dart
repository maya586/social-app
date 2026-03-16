import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final voiceRecorderProvider = StateNotifierProvider<VoiceRecorderService, VoiceRecorderState>((ref) {
  return VoiceRecorderService();
});

enum RecordingStatus {
  idle,
  recording,
  paused,
  stopped,
}

class VoiceRecorderState {
  final RecordingStatus status;
  final String? filePath;
  final Duration duration;
  final double amplitude;
  final String? error;

  const VoiceRecorderState({
    this.status = RecordingStatus.idle,
    this.filePath,
    this.duration = Duration.zero,
    this.amplitude = 0,
    this.error,
  });

  VoiceRecorderState copyWith({
    RecordingStatus? status,
    String? filePath,
    Duration? duration,
    double? amplitude,
    String? error,
  }) {
    return VoiceRecorderState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      error: error ?? this.error,
    );
  }

  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get hasRecording => filePath != null && status == RecordingStatus.stopped;
}

class VoiceRecorderService extends StateNotifier<VoiceRecorderState> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _durationTimer;
  Timer? _amplitudeTimer;
  String? _currentFilePath;

  VoiceRecorderService() : super(const VoiceRecorderState());

  Future<bool> checkPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    try {
      if (state.isRecording) return;

      final hasPermission = await checkPermission();
      if (!hasPermission) {
        state = state.copyWith(error: '未获得录音权限');
        return;
      }

      final directory = await getTemporaryDirectory();
      _currentFilePath = '${directory.path}/voice_${Uuid().v4()}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentFilePath!,
      );

      state = state.copyWith(
        status: RecordingStatus.recording,
        filePath: _currentFilePath,
        duration: Duration.zero,
      );

      _startDurationTimer();
      _startAmplitudeTimer();
    } catch (e) {
      state = state.copyWith(error: '启动录音失败: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      if (!state.isRecording) return;

      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();

      final path = await _recorder.stop();
      
      state = state.copyWith(
        status: RecordingStatus.stopped,
        filePath: path,
      );
    } catch (e) {
      state = state.copyWith(error: '停止录音失败: $e');
    }
  }

  Future<void> cancelRecording() async {
    try {
      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();

      await _recorder.stop();

      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      state = const VoiceRecorderState();
    } catch (e) {
      state = state.copyWith(error: '取消录音失败: $e');
    }
  }

  Future<void> playRecording() async {
    try {
      if (state.filePath == null) return;

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
      ));

      await _player.setFilePath(state.filePath!);
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: '播放失败: $e');
    }
  }

  Future<void> stopPlaying() async {
    await _player.stop();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (state.isRecording) {
        state = state.copyWith(
          duration: state.duration + const Duration(milliseconds: 100),
        );
      }
    });
  }

  void _startAmplitudeTimer() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (state.isRecording) {
        try {
          final amplitude = await _recorder.getAmplitude();
          state = state.copyWith(amplitude: amplitude.current);
        } catch (e) {
          // 忽略振幅获取错误
        }
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void reset() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    state = const VoiceRecorderState();
  }
}