import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordController {
  final void Function(Duration)? onRecordTick;
  final void Function(String)? onRecordComplete;
  final void Function(String)? onError;

  final AudioRecorder _recorder = AudioRecorder();
  just_audio.AudioPlayer? _audioPlayer;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  bool _isRecording = false;

  VoiceRecordController({
    this.onRecordTick,
    this.onRecordComplete,
    this.onError,
  }) {
    _audioPlayer = just_audio.AudioPlayer();
  }

  bool get isRecording => _isRecording;
  Duration get currentDuration => _currentDuration;

  Future<void> startRecording() async {
    if (_isRecording) return;

    // Request permission
    final micStatus = await Permission.microphone.request();

    if (micStatus.isPermanentlyDenied) {
      // Optionally: open settings
      await openAppSettings();
      return;
    }

    if (!micStatus.isGranted) {
      onError?.call("Microphone permission not granted.");
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        onError?.call("Microphone permission not granted.");
        return;
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _isRecording = true;
      _currentDuration = Duration.zero;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentDuration += const Duration(seconds: 1);
        onRecordTick?.call(_currentDuration);
      });
    } catch (e) {
      onError?.call("Failed to start recording: $e");
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();
      _timer?.cancel();
      _isRecording = false;

      if (onRecordComplete != null && path != null) {
        onRecordComplete!(path);
      }
    } catch (e) {
      _isRecording = false;
      onError?.call("Failed to stop recording: $e");
    }
  }

  Future<void> playRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        onError?.call("File does not exist: $filePath");
        return;
      }

      final size = await file.length();
      if (size <= 0) {
        onError?.call("Recording is empty or corrupt.");
        return;
      }

      await _audioPlayer!.setFilePath(filePath);
      await _audioPlayer!.play();
    } catch (e) {
      onError?.call("Playback error: $e");
    }
  }

  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<String>> getAllRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = await dir.list().toList();

    return files
        .where((f) =>
            f is File && (f.path.endsWith('.m4a') || f.path.endsWith('.wav')))
        .map((f) => f.path)
        .toList();
  }

  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _audioPlayer?.dispose();
  }
}
