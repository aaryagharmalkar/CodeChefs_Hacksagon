import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../services/audio_summariser_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg       = AppColors.background;
  static const surface   = AppColors.card;
  static const card      = AppColors.card;
  static const border    = AppColors.border;
  static const teal      = AppColors.primary;
  static const tealDim   = AppColors.primarySoft;
  static const red       = AppColors.danger;
  static const redDim    = Color(0xFFFFF1F1);
  static const textPri   = AppColors.textPrimary;
  static const textSec   = AppColors.textSecondary;
  static const textMut   = AppColors.textMuted;
  static const success   = AppColors.success;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Processing Stage Enum
// ─────────────────────────────────────────────────────────────────────────────

enum ProcessingStage { idle, uploading, processing, polling, done, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Main Page
// ─────────────────────────────────────────────────────────────────────────────

class MedicalSummariserPage extends StatefulWidget {
  const MedicalSummariserPage({super.key});

  @override
  State<MedicalSummariserPage> createState() => _MedicalSummariserPageState();
}

class _MedicalSummariserPageState extends State<MedicalSummariserPage>
    with TickerProviderStateMixin {

  // Tabs
  int _tabIndex = 0;

  // Recording
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  late AnimationController _pulseCtrl;

  // Timer
  late AnimationController _timerCtrl;

  // Processing
  ProcessingStage _stage = ProcessingStage.idle;
  double _progress = 0;
  int _retryAttempt = 0;
  final int _maxRetries = 20;
  String? _errorMessage;

  // Result
  String? _summary;
  Map<String, dynamic>? _summaryJson;
  String? _audioName;

  // File info
  String? _selectedFileName;
  double? _selectedFileSizeMB;

  @override
  void initState() {
    super.initState();
    _log('initState()');
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _timerCtrl = AnimationController(vsync: this);

    // Timer tick every second while recording
    _startRecordingTimer();
  }

  void _startRecordingTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_isRecording) {
        setState(() => _recordingSeconds++);
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _log('dispose()');
    _pulseCtrl.dispose();
    _timerCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Recording
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _log('startRecording() requested');
    final hasPermission = await _recorder.hasPermission();
    _log('startRecording() permission=$hasPermission');
    if (!hasPermission) {
      _showSnack('Microphone permission denied', isError: true);
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _log('startRecording() outputPath=$filePath');

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _summary = null;
      _summaryJson = null;
      _errorMessage = null;
    });

    _log('startRecording() started');

    _startRecordingTimer();
  }

  Future<void> _stopRecording() async {
    _log('stopRecording() requested');
    final filePath = await _recorder.stop();
    _log('stopRecording() filePath=$filePath');
    setState(() => _isRecording = false);

    if (filePath == null) {
      _showSnack('Recording failed', isError: true);
      return;
    }

    final file = File(filePath);
    final sizeMB = file.lengthSync() / (1024 * 1024);

    setState(() {
      _selectedFileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _selectedFileSizeMB = sizeMB;
    });

    _log('stopRecording() saved file=${file.path} sizeMB=${sizeMB.toStringAsFixed(2)}');

    await _processAudio(file);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  File Pick
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    _log('pickAndUpload() requested');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    _log('pickAndUpload() resultCount=${result?.files.length ?? 0}');

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    final sizeMB = file.lengthSync() / (1024 * 1024);
    _log('pickAndUpload() path=${picked.path} sizeMB=${sizeMB.toStringAsFixed(2)}');

    if (sizeMB > 50) {
      _showSnack('File too large (max 50 MB)', isError: true);
      return;
    }

    setState(() {
      _selectedFileName = picked.name;
      _selectedFileSizeMB = sizeMB;
      _summary = null;
      _summaryJson = null;
      _errorMessage = null;
    });

    await _processAudio(file);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Process Audio
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _processAudio(File file) async {
    _log('processAudio() file=${file.path} sizeBytes=${file.lengthSync()}');
    setState(() {
      _stage = ProcessingStage.uploading;
      _progress = 0.0;
      _errorMessage = null;
      _retryAttempt = 0;
    });

    try {
      // 1. Upload
      final uploadResp = await AudioSummariserService.uploadAudio(file);
      _log('processAudio() uploadResp=$uploadResp');
      final audioName = uploadResp['audio_name'] as String?;
      final fallbackName = uploadResp['audioName'] as String?;
      final selectedAudioName = audioName ?? fallbackName;

      if (selectedAudioName == null) {
        throw Exception('Upload response missing audio_name/audioName');
      }

      _audioName = selectedAudioName;
      _log('processAudio() audioName=$_audioName');

      setState(() {
        _stage = ProcessingStage.processing;
        _progress = 0.3;
      });

      await Future.delayed(const Duration(seconds: 3));

      // 2. Poll for summary
      setState(() => _stage = ProcessingStage.polling);

      final summary = await AudioSummariserService.fetchSummary(
        selectedAudioName,
        maxRetries: _maxRetries,
        onProgress: (attempt, max) {
          if (!mounted) return;
          setState(() {
            _retryAttempt = attempt;
            _progress = 0.3 + ((attempt / max) * 0.65).clamp(0, 0.65);
          });
          _log('processAudio() polling attempt=$attempt/$max progress=${_progress.toStringAsFixed(2)}');
        },
      );

      _log('processAudio() summaryLength=${summary.length}');

      setState(() {
        _summary = summary;
        _summaryJson = _parseSummaryJson(summary);
        _stage = ProcessingStage.done;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _stage = ProcessingStage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _progress = 0;
      });

      _log('processAudio() failed error=$_errorMessage');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Download PDF
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    _log('downloadPdf() requested audioName=$_audioName');
    if (_audioName == null) return;

    try {
      _showSnack('Downloading PDF…');
      final bytes = await AudioSummariserService.downloadPdf(_audioName!);
      _log('downloadPdf() bytes=${bytes.length}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_audioName.pdf');
      await file.writeAsBytes(bytes);
      _log('downloadPdf() writtenFile=${file.path}');

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Medical Summary Report',
      );
    } catch (e) {
      _showSnack('PDF download failed: $e', isError: true);
    }
  }

  Future<void> _viewPdf() async {
    _log('viewPdf() requested audioName=$_audioName');
    if (_summary == null) return;

    final bytes = await _buildPdfBytes();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Summary PDF Preview'),
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.textPrimary,
          ),
          body: PdfPreview(
            build: (format) async => bytes,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: 'medical_summary.pdf',
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Reset
  // ─────────────────────────────────────────────────────────────────────────

  void _reset() {
    _log('reset()');
    setState(() {
      _stage = ProcessingStage.idle;
      _summary = null;
      _summaryJson = null;
      _audioName = null;
      _progress = 0;
      _errorMessage = null;
      _selectedFileName = null;
      _selectedFileSizeMB = null;
      _retryAttempt = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    _log('snack(isError=$isError): $msg');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _C.textPri)),
      backgroundColor: isError ? _C.redDim : _C.tealDim,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _stageLabel() {
    switch (_stage) {
      case ProcessingStage.uploading: return 'Uploading audio…';
      case ProcessingStage.processing: return 'Processing audio…';
      case ProcessingStage.polling:
        return 'Generating summary… ($_retryAttempt/$_maxRetries)';
      default: return 'Working…';
    }
  }

  bool get _isProcessing =>
      _stage == ProcessingStage.uploading ||
      _stage == ProcessingStage.processing ||
      _stage == ProcessingStage.polling;

  void _log(String message) {
    debugPrint('[MedicalSummariserPage] $message');
  }

  Map<String, dynamic>? _parseSummaryJson(String summary) {
    final candidates = <String>[
      summary.trim(),
      _stripCodeFences(summary.trim()),
      _extractJsonObject(summary.trim()) ?? '',
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is String) {
          final nested = decoded.trim();
          if (nested.isNotEmpty && nested != candidate) {
            final nestedDecoded = jsonDecode(nested);
            if (nestedDecoded is Map<String, dynamic>) {
              return nestedDecoded;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    _log('parseSummaryJson() could not decode summary payload');
    return null;
  }

  String _stripCodeFences(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('```')) return trimmed;

    final lines = trimmed.split('\n');
    if (lines.length >= 3 && lines.first.startsWith('```') && lines.last.startsWith('```')) {
      return lines.sublist(1, lines.length - 1).join('\n').trim();
    }
    return trimmed.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '').replaceAll(RegExp(r'\s*```$', caseSensitive: false), '').trim();
  }

  String? _extractJsonObject(String input) {
    final start = input.indexOf('{');
    final end = input.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return input.substring(start, end + 1).trim();
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return const [];
  }

  Future<Uint8List> _buildPdfBytes() async {
    final document = pw.Document();
    final summary = _summaryJson ?? <String, dynamic>{'doctor_summary': _summary ?? ''};
    final riskLevel = summary['risk_level']?.toString() ?? 'Summary';

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: pdf.PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Medical Summary Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: pdf.PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generated locally from the summariser output',
                  style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.white),
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: pdf.PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(
                    riskLevel,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: pdf.PdfColors.blueGrey900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _pdfSection('Summary', summary['doctor_summary']?.toString() ?? _summary ?? 'No summary available.'),
          pw.SizedBox(height: 12),
          _pdfSection('Symptoms', _asStringList(summary['symptoms']).join(', ')),
          pw.SizedBox(height: 12),
          _pdfSection('Patient History', _asStringList(summary['patient_history']).join(', ')),
          pw.SizedBox(height: 12),
          _pdfSection('Risk Factors', _asStringList(summary['risk_factors']).join(', ')),
          pw.SizedBox(height: 12),
          _pdfSection('Prescription', _asStringList(summary['prescription']).join(', ')),
          pw.SizedBox(height: 12),
          _pdfSection('Advice', _asStringList(summary['advice']).join(', ')),
          pw.SizedBox(height: 12),
          _pdfSection('Recommended Action', summary['recommended_action']?.toString() ?? 'N/A'),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfSection(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: pdf.PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: pdf.PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value.isEmpty ? 'N/A' : value,
            style: const pw.TextStyle(fontSize: 11, color: pdf.PdfColors.blueGrey700),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _tabIndex == 0 ? _buildAudioTab() : _buildReportTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medical Summariser',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'AI-powered analysis via Hydralite',
                style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          _tabItem(0, Icons.mic_rounded, 'Doctor Audio'),
          _tabItem(1, Icons.description_rounded, 'Medical Report'),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: AppColors.primary.withOpacity(0.25))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? AppColors.primary : _C.textSec),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primary : _C.textSec,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AUDIO TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAudioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),

          if (_stage == ProcessingStage.idle ||
              _stage == ProcessingStage.error) ...[
            _buildRecordUploadCard(),
            if (_stage == ProcessingStage.error) ...[
              const SizedBox(height: 12),
              _buildErrorCard(),
            ],
          ],

          if (_isProcessing) ...[
            _buildProcessingCard(),
          ],

          if (_stage == ProcessingStage.done && _summary != null) ...[
            _buildSummaryCard(),
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How it works',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _infoBullet('Record', 'Capture audio directly from microphone'),
                _infoBullet('Upload', 'Choose existing audio file (MP3/WAV/M4A)'),
                _infoBullet('Process', 'Hydralite transcribes & summarizes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBullet(String bold, String rest) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          children: [
            TextSpan(
                text: '$bold  ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: rest),
          ],
        ),
      ),
    );
  }

  // ── Record/Upload Card ────────────────────────────────────────────────────

  Widget _buildRecordUploadCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Record button
          if (!_isRecording) ...[
            _buildRecordButton(),
            const SizedBox(height: 24),
            _buildDivider(),
            const SizedBox(height: 24),
            _buildUploadZone(),
          ] else ...[
            _buildActiveRecordingUI(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _startRecording,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [AppColors.primarySoft, Colors.white],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.18), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Start Recording',
              style: TextStyle(
                color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Tap to capture microphone audio',
              style: TextStyle(color: _C.textSec, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingUI() {
    return Column(
      children: [
        // Pulsing recording indicator
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (ctx, _) {
            final scale = 1.0 + _pulseCtrl.value * 0.12;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.danger.withOpacity(0.55 + _pulseCtrl.value * 0.35),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.danger.withOpacity(0.12 + _pulseCtrl.value * 0.18),
                        blurRadius: 25,
                        spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.radio_button_on_rounded,
                    color: AppColors.danger, size: 36),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          _formatTime(_recordingSeconds),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w200,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        const Text('Recording in progress…',
          style: TextStyle(color: AppColors.danger, fontSize: 13)),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: _C.redDim,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.danger.withOpacity(0.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_rounded, color: AppColors.danger, size: 18),
                SizedBox(width: 8),
                Text('Stop Recording',
                    style: TextStyle(
                        color: _C.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _C.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: TextStyle(color: _C.textMut, fontSize: 12)),
        ),
        Expanded(child: Divider(color: _C.border, thickness: 1)),
      ],
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 32),
            const SizedBox(height: 10),
            const Text('Upload audio file',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('MP3, WAV, M4A, WebM or OGG (max 50 MB)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Processing Card ───────────────────────────────────────────────────────

  Widget _buildProcessingCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated spinner
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: _stage == ProcessingStage.uploading ? null : _progress,
              strokeWidth: 3,
              backgroundColor: AppColors.backgroundAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _stageLabel(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _stage == ProcessingStage.uploading ? null : _progress,
              backgroundColor: AppColors.backgroundAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stage == ProcessingStage.uploading
                ? 'Uploading...'
                : '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (_retryAttempt > 0 && _stage != ProcessingStage.uploading) ...[
            const SizedBox(height: 10),
            Text(
              'This may take up to 90 seconds for long recordings',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── Error Card ────────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 17),
              SizedBox(width: 8),
              Text('Processing Error',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An unknown error occurred.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withOpacity(0.18)),
              ),
              child: const Text('Try Again',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final payload = _summaryJson ?? <String, dynamic>{'doctor_summary': _summary ?? ''};
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 20,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Doctor Conversation Summary',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: AppColors.border, thickness: 1,
              indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              children: [
                _buildHeroSummaryBox(),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Symptoms',
                  icon: Icons.monitor_heart_outlined,
                  accent: AppColors.primary,
                  child: _buildChipWrap(_asStringList(payload['symptoms'])),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Patient History',
                  icon: Icons.history_edu_outlined,
                  accent: AppColors.secondary,
                  child: _buildChipWrap(_asStringList(payload['patient_history'])),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Risk Factors',
                  icon: Icons.warning_amber_rounded,
                  accent: AppColors.warning,
                  child: _buildChipWrap(_asStringList(payload['risk_factors'])),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Prescription',
                  icon: Icons.medication_outlined,
                        accent: AppColors.accent,
                  child: _buildChipWrap(_asStringList(payload['prescription'])),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Advice',
                  icon: Icons.tips_and_updates_outlined,
                  accent: AppColors.success,
                  child: _buildChipWrap(_asStringList(payload['advice'])),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(
                  title: 'Recommended Action',
                  icon: Icons.check_circle_outline_rounded,
                  accent: AppColors.primary,
                  child: Text(
                    payload['recommended_action']?.toString().trim().isNotEmpty == true
                        ? payload['recommended_action'].toString()
                        : 'No action provided.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackSummaryBox() {
    final fallback = _summary ?? 'No summary available.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary received',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fallback,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryBox() {
    final summaryText = _summaryJson?['doctor_summary']?.toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySoft, Colors.white],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.summarize_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Summary',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (summaryText == null || summaryText.isEmpty) ? 'No summary text provided.' : summaryText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildChipWrap(List<String> items) {
    if (items.isEmpty) {
      return const Text(
        'No data provided.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.6,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionBtn(
          icon: Icons.visibility_rounded,
          label: 'View PDF',
          onTap: _viewPdf,
          primary: false,
        ),
        _actionBtn(
          icon: Icons.download_rounded,
          label: 'Download PDF',
          onTap: _downloadPdf,
          primary: true,
        ),
        _actionBtn(
          icon: Icons.refresh_rounded,
          label: 'New Analysis',
          onTap: _reset,
          primary: false,
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return SizedBox(
      width: 110,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: primary ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: primary ? AppColors.primary.withOpacity(0.18) : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary ? Colors.white : AppColors.textSecondary, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: primary ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  REPORT TAB  (placeholder — same upload pattern)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.description_rounded,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Upload Medical Report',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Upload a PDF or image of your medical report to get an AI-powered summary',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                );
                if (result != null) {
                  _showSnack('Report upload coming soon!');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Select PDF or Image',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('PDF, JPG, or PNG supported',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
