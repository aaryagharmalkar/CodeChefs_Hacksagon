// lib/core/utils/audio_helper.dart
//
// Drop-in replacement for your existing stub.
// Records WAV mono 44 100 Hz / 16-bit into the system temp directory.
// The returned path is ready to pass directly to VoiceMlApi.uploadWav().

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission result
// ─────────────────────────────────────────────────────────────────────────────

enum MicPermissionStatus { granted, denied, permanentlyDenied }

// ─────────────────────────────────────────────────────────────────────────────
// AudioRecorderService
// ─────────────────────────────────────────────────────────────────────────────

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _activePath;

  // ── Permission ────────────────────────────────────────────────────────────

  Future<MicPermissionStatus> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermissionStatus.granted;
    if (status.isPermanentlyDenied) return MicPermissionStatus.permanentlyDenied;
    return MicPermissionStatus.denied;
  }

  Future<bool> get hasPermission => Permission.microphone.isGranted;

  // ── Recording lifecycle ───────────────────────────────────────────────────

  /// Starts recording. Returns the destination file path.
  /// Throws [AudioServiceException] on failure.
  Future<String> startRecording() async {
    final granted = await hasPermission;
    if (!granted) {
      throw AudioServiceException(
          'Microphone permission has not been granted.');
    }

    final dir = await getTemporaryDirectory();
    _activePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          bitRate: 705600, // 44 100 × 16 bit × 1 ch
          numChannels: 1,
        ),
        path: _activePath!,
      );
    } catch (e) {
      throw AudioServiceException('Could not start recording: $e');
    }

    return _activePath!;
  }

  /// Stops the active recording. Returns the saved file path.
  /// Throws [AudioServiceException] if nothing was recording.
  Future<String> stopRecording() async {
    final recording = await _recorder.isRecording();
    if (!recording) {
      throw AudioServiceException('stopRecording called with no active session.');
    }

    final saved = await _recorder.stop();
    final resolved = saved ?? _activePath;

    if (resolved == null || !File(resolved).existsSync()) {
      throw AudioServiceException(
          'Recording stopped but the audio file could not be located.');
    }

    _activePath = resolved;
    return resolved;
  }

  /// Cancels recording without saving. Safe to call even if not recording.
  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // best-effort
    }
    _activePath = null;
  }

  Future<bool> get isRecording => _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

class AudioServiceException implements Exception {
  final String message;
  const AudioServiceException(this.message);

  @override
  String toString() => message;
}