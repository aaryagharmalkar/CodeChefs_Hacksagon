// lib/features/voice_check/voice_check_viewmodel.dart
//
// Production ViewModel. Matches your existing provider + Consumer pattern.
// Integrates AudioRecorderService, VoiceMlApi, and all state your UI needs.

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/network/voice_ml_api.dart';
import '../../../core/utils/audio_helper.dart';
import '../../../core/utils/app_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

abstract class TestTypes {
  static const String voice = 'voice';
  static const String face = 'face';
  static const String tremors = 'tremors';
}

// ─────────────────────────────────────────────────────────────────────────────
// ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class VoiceCheckViewModel extends ChangeNotifier {
  // ── Services ───────────────────────────────────────────────────────────────
  final AudioRecorderService _audioService = AudioRecorderService();

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _recordingTimer;
  Timer? _progressTimer;

  // ── Recording state ────────────────────────────────────────────────────────
  bool _isRecording = false;
  int remainingSeconds = 12;
  String? recordedFilePath;

  // ── Upload / analysis state ────────────────────────────────────────────────
  bool isUploading = false;
  double processProgress = 0.0;
  double? confidence;     // normalised 0.0–1.0
  String? riskLevel;      // "Low" | "Medium" | "High"
  String? errorMessage;

  // ── Navigation flags ───────────────────────────────────────────────────────
  bool _navigateToProcessing = false;
  bool _navigateToResults = false;

  // ── Clinical inputs ────────────────────────────────────────────────────────
  int? ac;
  int? nth;
  int? htn;
  int updrs = 0; // binary toggle from ClinicalInputSheet

  // ── Lifecycle guard ────────────────────────────────────────────────────────
  bool _disposed = false;

  static const String _userId = 'demo-user';

  // ─── Getters ───────────────────────────────────────────────────────────────

  bool get isRecording => _isRecording;
  bool get shouldNavigateToProcessing => _navigateToProcessing;
  bool get shouldNavigateToResults => _navigateToResults;

  /// Countdown formatted as "00:12"
  String get formattedTime =>
      '00:${remainingSeconds.toString().padLeft(2, '0')}';

  /// Progress 0.0–1.0 as percentage string for ProcessingView if needed
  String get progressLabel =>
      '${(processProgress * 100).toStringAsFixed(0)}%';

  // ─── Navigation ────────────────────────────────────────────────────────────

  void resetNavigationFlags() {
    _navigateToProcessing = false;
    _navigateToResults = false;
    // Do NOT notify here – called from within build callback (_checkAndNavigate)
    // to avoid setState-during-build errors.
  }

  // ─── Clinical inputs ───────────────────────────────────────────────────────

  void setClinicalInputs({
    required int ac,
    required int nth,
    required int htn,
    int updrs = 0,
  }) {
    this.ac = ac;
    this.nth = nth;
    this.htn = htn;
    this.updrs = updrs;
    debugPrint('🧾 Clinical inputs set → ac=$ac nth=$nth htn=$htn updrs=$updrs');
  }

  // ─── Recording ─────────────────────────────────────────────────────────────

  Future<void> startRecording() async {
    if (_isRecording || _disposed) return;

    if (ac == null || nth == null || htn == null) {
      errorMessage = 'Clinical information missing. Please complete the form.';
      _safeNotify();
      return;
    }

    // Request microphone permission
    final permStatus = await _audioService.requestPermission();
    if (permStatus == MicPermissionStatus.permanentlyDenied) {
      errorMessage =
          'Microphone access is permanently denied. '
          'Please enable it in your device Settings.';
      _safeNotify();
      return;
    }
    if (permStatus == MicPermissionStatus.denied) {
      errorMessage = 'Microphone permission is required for voice analysis.';
      _safeNotify();
      return;
    }

    remainingSeconds = 12;
    errorMessage = null;
    _safeNotify();

    try {
      recordedFilePath = await _audioService.startRecording();
    } on AudioServiceException catch (e) {
      errorMessage = e.message;
      _safeNotify();
      return;
    }

    _isRecording = true;
    _safeNotify();

    // Auto-stop countdown
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_disposed) { t.cancel(); return; }
      if (remainingSeconds <= 0) {
        t.cancel();
        await stopRecording();
      } else {
        remainingSeconds--;
        _safeNotify();
      }
    });
  }

  Future<void> stopRecording() async {
    if (!_isRecording || _disposed) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      recordedFilePath = await _audioService.stopRecording();
    } on AudioServiceException catch (e) {
      errorMessage = e.message;
      _isRecording = false;
      _safeNotify();
      return;
    }

    _isRecording = false;

    if (_disposed || recordedFilePath == null) return;

    _navigateToProcessing = true;
    _safeNotify();

    // Fire upload without awaiting — navigation happens immediately
    unawaited(_uploadAndAnalyze());
  }

  // ─── Upload & analysis ─────────────────────────────────────────────────────

  Future<void> _uploadAndAnalyze() async {
    if (_disposed) return;

    isUploading = true;
    processProgress = 0.1;
    _safeNotify();

    // Fake progress ticker so the processing screen feels alive
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!isUploading || _disposed) { t.cancel(); return; }
      if (processProgress < 0.88) {
        processProgress += 0.025;
        _safeNotify();
      }
    });

    try {
      final result = await VoiceMlApi.uploadWav(
        wavPath: recordedFilePath!,
        ac: ac!,
        nth: nth!,
        htn: htn!,
        updrs: updrs,
      );

      debugPrint('🧠 ML result: $result');

      // Normalise risk_score to 0–1
      final rawScore = (result['risk_score'] as num).toDouble();
      confidence = rawScore > 1.0 ? rawScore / 100.0 : rawScore;
      riskLevel = result['risk_level'] as String? ??
          _levelFromScore(confidence!);

      _progressTimer?.cancel();
      isUploading = false;
      processProgress = 1.0;
      _navigateToResults = true;
      _safeNotify();

      AppSession().scores['voice'] = {
        'riskScore': confidence!,
        'riskLevel': riskLevel!,
        'ac': ac,
        'nth': nth,
        'htn': htn,
        'updrs': updrs,
      };
    } catch (e) {
      _progressTimer?.cancel();
      debugPrint('❌ Voice analysis failed: $e');

      isUploading = false;
      processProgress = 0.0;

      final msg = e.toString();
      if (msg.contains('timeout') || msg.contains('Timeout')) {
        errorMessage =
            'Server is starting up. Please wait 30 seconds and try again.';
      } else if (msg.contains('connection') ||
          msg.contains('network') ||
          msg.contains('internet') ||
          msg.contains('Connection')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else {
        errorMessage = 'Unable to analyse voice. Please try again.';
      }

      _safeNotify();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _levelFromScore(double score) {
    if (score < 0.33) return 'Low';
    if (score < 0.66) return 'Medium';
    return 'High';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ─── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _recordingTimer?.cancel();
    _progressTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}