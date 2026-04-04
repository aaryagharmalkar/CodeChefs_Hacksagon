// lib/features/voice_check/results_view.dart
//
// Shows the captured voice assessment fields directly in the UI and lets the
// user export a local PDF report generated on-device.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/app_session.dart';

class ResultsView extends StatefulWidget {
  const ResultsView({super.key});

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  bool _isExporting = false;

  // Read voice scores from AppSession
  Map<String, dynamic> get _voiceScores =>
      (AppSession().scores['voice'] as Map<String, dynamic>?) ?? {};

  double get _riskScore {
    return (_voiceScores['riskScore'] as num?)?.toDouble() ?? 0.0;
  }

  String get _riskLevel {
    return _voiceScores['riskLevel'] as String? ?? 'Unknown';
  }

  bool get _ageAbove60 => (_voiceScores['ac'] as num?)?.toInt() == 1;
  bool get _neuroHistory => (_voiceScores['nth'] as num?)?.toInt() == 1;
  bool get _hypertension => (_voiceScores['htn'] as num?)?.toInt() == 1;

  String get _timestampLabel {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  Color get _riskColor {
    switch (_riskLevel.toLowerCase()) {
      case 'low':
        return const Color(0xFF1F8A70);
      case 'medium':
        return const Color(0xFFE08D14);
      default:
        return const Color(0xFFE15241);
    }
  }

  Color get _riskTint {
    switch (_riskLevel.toLowerCase()) {
      case 'low':
        return const Color(0xFFE8F7F1);
      case 'medium':
        return const Color(0xFFFFF2D8);
      default:
        return const Color(0xFFFFE8E5);
    }
  }

  Future<void> submitResults(BuildContext context) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final body = AppSession().scores;
      final response = await http.post(
        Uri.parse('http://192.168.55.176:5000/api/report/upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (!context.mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        context.go('/assessment/results');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to submit results. Please try again.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> handleSaveAndContinue(BuildContext context) async {
    if (_riskLevel.toLowerCase() == 'high') {
      context.go('/assessment/cookie-theft');
    } else {
      await submitResults(context);
    }
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final bytes = await _buildPdfBytes();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'voice_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Voice Assessment Report',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final document = pw.Document();
    final riskPct = (_riskScore * 100).clamp(0, 100);
    final buttonLabel = _riskLevel.toLowerCase() == 'high'
        ? 'Continue to Cognitive Assessment'
        : 'Save & Continue';

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
                  'Voice Assessment Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: pdf.PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  buttonLabel,
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: pdf.PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generated locally from the captured clinical fields',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: pdf.PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: pdf.PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(
                    'Risk Level: $_riskLevel',
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
          pw.Row(
            children: [
              _pdfMetricCard('Risk Score', '${riskPct.toStringAsFixed(1)}%'),
              pw.SizedBox(width: 12),
              _pdfMetricCard('Age > 60', _ageAbove60 ? 'Yes' : 'No'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _pdfMetricCard('Neuro History', _neuroHistory ? 'Yes' : 'No'),
              pw.SizedBox(width: 12),
              _pdfMetricCard('Hypertension', _hypertension ? 'Yes' : 'No'),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: pdf.PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: pdf.PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Captured Fields',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: pdf.PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 12),
                _pdfFieldRow('Risk Level', _riskLevel),
                _pdfFieldRow('Risk Score', '${riskPct.toStringAsFixed(1)}%'),
                _pdfFieldRow('Age above 60', _ageAbove60 ? 'Yes' : 'No'),
                _pdfFieldRow(
                    'Neurological history', _neuroHistory ? 'Yes' : 'No'),
                _pdfFieldRow(
                    'High blood pressure', _hypertension ? 'Yes' : 'No'),
                _pdfFieldRow('Captured at', _timestampLabel),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'This report contains the raw screening fields only. It is not a medical diagnosis and should be reviewed with a clinician if needed.',
            style: pw.TextStyle(
              fontSize: 11,
              color: pdf.PdfColors.grey700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfMetricCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: pdf.PdfColors.white,
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: pdf.PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: pdf.PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
                color: pdf.PdfColors.blueGrey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfFieldRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                color: pdf.PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pdf.PdfColors.blueGrey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continue() {
    context.go('/assessment/cookie-theft');
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      _FieldChip(
        label: 'Risk Level',
        value: _riskLevel,
        accent: _riskColor,
        icon: Icons.bolt_rounded,
      ),
      _FieldChip(
        label: 'Risk Score',
        value: '${(_riskScore * 100).toStringAsFixed(1)}%',
        accent: _riskColor,
        icon: Icons.show_chart_rounded,
      ),
      _FieldChip(
        label: 'Age > 60',
        value: _ageAbove60 ? 'Yes' : 'No',
        accent:
            _ageAbove60 ? const Color(0xFF1F8A70) : const Color(0xFFE15241),
        icon: Icons.cake_outlined,
      ),
      _FieldChip(
        label: 'Neurological history',
        value: _neuroHistory ? 'Yes' : 'No',
        accent:
            _neuroHistory ? const Color(0xFF1F8A70) : const Color(0xFFE15241),
        icon: Icons.psychology_outlined,
      ),
      _FieldChip(
        label: 'Hypertension',
        value: _hypertension ? 'Yes' : 'No',
        accent:
            _hypertension ? const Color(0xFF1F8A70) : const Color(0xFFE15241),
        icon: Icons.favorite_border_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Report',
                              style: AppTextStyles.title.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Captured fields only, with local PDF export',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.hearing_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Screening complete',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _riskLevel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(_riskScore * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'risk score',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.88),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _riskScore.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.16),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_riskColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Local report generated from the fields captured during your voice check.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.90),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          label: 'Age above 60',
                          value: _ageAbove60 ? 'Yes' : 'No',
                          icon: Icons.cake_outlined,
                          accent: _ageAbove60
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          label: 'Neurological history',
                          value: _neuroHistory ? 'Yes' : 'No',
                          icon: Icons.psychology_outlined,
                          accent: _neuroHistory
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MiniStatCard(
                    label: 'High blood pressure',
                    value: _hypertension ? 'Yes' : 'No',
                    icon: Icons.favorite_border_rounded,
                    accent:
                        _hypertension ? AppColors.success : AppColors.danger,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.border.withOpacity(0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _riskTint,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.view_list_rounded,
                                color: _riskColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Captured Fields',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...fields,
                        const SizedBox(height: 2),
                        Text(
                          'This report is intentionally limited to the raw fields collected during the voice check.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                          _isExporting ? 'Preparing PDF...' : 'Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => handleSaveAndContinue(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _riskLevel.toLowerCase() == 'high'
                            ? 'Continue to Cognitive Assessment'
                            : 'Save & Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _FieldChip({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool fullWidth;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(color: AppColors.background),
            ),
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft,
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: -50,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}