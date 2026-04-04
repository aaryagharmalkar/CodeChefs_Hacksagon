import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _fetchLatestReport();
  }

  Future<void> _fetchLatestReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final response = await http.get(
        Uri.parse('http://192.168.55.176:5000/api/report/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final reports = body['reports'] as List?;
        setState(() {
          // fetchReports returns sorted by createdAt -1, so first is latest
          _report =
              (reports != null && reports.isNotEmpty) ? reports.first as Map<String, dynamic> : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load report (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ── Derived values from report ──────────────────────────────────────────

  int get _mmse => (_report?['mmse'] as num?)?.toInt() ?? 0;

  String get _overallRiskLevel =>
      (_report?['overallRiskLevel'] as String? ?? 'low').toLowerCase();

  double get _overallScore =>
      (_report?['overallScore'] as num?)?.toDouble() ?? 0.0;

  // voice sub-doc (may be null)
  Map<String, dynamic>? get _voice =>
      _report?['voice'] as Map<String, dynamic>?;

  // cookie sub-doc (may be null)
  Map<String, dynamic>? get _cookie =>
      _report?['cookie'] as Map<String, dynamic>?;

  Color get _riskColor {
    switch (_overallRiskLevel) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return const Color(0xFFF5A623);
      default:
        return AppColors.danger;
    }
  }

  String get _riskLabel {
    switch (_overallRiskLevel) {
      case 'low':
        return 'Low Risk';
      case 'medium':
        return 'Medium Risk';
      default:
        return 'High Risk';
    }
  }

  String _mmseInterpretation(int score) {
    if (score >= 24) return 'Normal';
    if (score >= 18) return 'Mild impairment';
    if (score >= 12) return 'Moderate impairment';
    return 'Severe impairment';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assessment Results'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _report == null
                  ? _buildNoReport()
                  : _buildReport(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            NeuraButton(text: 'Retry', onTap: _fetchLatestReport),
          ],
        ),
      ),
    );
  }

  Widget _buildNoReport() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No report found',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete an assessment to see your results here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            NeuraButton(
              text: 'Back to Dashboard',
              onTap: () => context.go('/dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Overall risk banner ──────────────────────────────────────
          _buildOverallBanner(),
          const SizedBox(height: 20),

          // ── MMSE card ────────────────────────────────────────────────
          _buildSectionCard(
            icon: Icons.psychology_rounded,
            title: 'MMSE Score',
            child: _buildMmseContent(),
          ),
          const SizedBox(height: 14),

          // ── Voice card (may be null) ──────────────────────────────────
          if (_voice != null) ...[
            _buildSectionCard(
              icon: Icons.mic_rounded,
              title: 'Voice Analysis',
              child: _buildVoiceContent(),
            ),
            const SizedBox(height: 14),
          ],

          // ── Cookie theft card (may be null) ──────────────────────────
          if (_cookie != null) ...[
            _buildSectionCard(
              icon: Icons.image_search_rounded,
              title: 'Cookie Theft Assessment',
              child: _buildCookieContent(),
            ),
            const SizedBox(height: 14),
          ],

          // ── Disclaimer ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These results are screening tools, not a medical '
                    'diagnosis. Please consult a qualified healthcare '
                    'professional for a full clinical evaluation.',
                    style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Actions ──────────────────────────────────────────────────
          NeuraButton(
            text: 'View All Reports',
            onTap: () => context.go('/reports'),
          ),
          const SizedBox(height: 12),
          NeuraButton(
            text: 'Back to Dashboard',
            onTap: () => context.go('/dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor.withOpacity(0.35), width: 2),
      ),
      child: Column(
        children: [
          Icon(
            _overallRiskLevel == 'low'
                ? Icons.check_circle_rounded
                : _overallRiskLevel == 'medium'
                    ? Icons.warning_amber_rounded
                    : Icons.warning_rounded,
            color: _riskColor,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            _riskLabel,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _riskColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overall neurological risk assessment',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (_voice != null) ...[
            const SizedBox(height: 12),
            Text(
              'Risk score: ${(_overallScore * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: _riskColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMmseContent() {
    final interpretation = _mmseInterpretation(_mmse);
    final ratio = _mmse / 30.0;
    final color = ratio >= 0.8
        ? AppColors.success
        : ratio >= 0.6
            ? const Color(0xFFF5A623)
            : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$_mmse',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              ' / 30',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          interpretation,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceContent() {
    final riskScore = (_voice!['riskScore'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = _voice!['riskLevel'] as String? ?? 'Unknown';
    final ac = (_voice!['ac'] as num?)?.toInt() == 1;
    final nth = (_voice!['nth'] as num?)?.toInt() == 1;
    final htn = (_voice!['htn'] as num?)?.toInt() == 1;

    final color = riskLevel.toLowerCase() == 'low'
        ? AppColors.success
        : riskLevel.toLowerCase() == 'medium'
            ? const Color(0xFFF5A623)
            : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${(riskScore * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                riskLevel,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _infoRow('Age above 60', ac ? 'Yes' : 'No'),
        _infoRow('Neurological history', nth ? 'Yes' : 'No'),
        _infoRow('Hypertension', htn ? 'Yes' : 'No'),
      ],
    );
  }

  Widget _buildCookieContent() {
    final prob =
        (_cookie!['dementiaProbability'] as num?)?.toDouble() ?? 0.0;
    final isHigh = prob >= 0.6;
    final isMod = prob >= 0.3;
    final color = isHigh
        ? AppColors.danger
        : isMod
            ? const Color(0xFFF5A623)
            : AppColors.success;
    final label = isHigh ? 'High Risk' : isMod ? 'Moderate Risk' : 'Low Risk';

    final cogMarkers =
        _cookie!['cognitiveMarkers'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${(prob * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        if (cogMarkers != null) ...[
          const SizedBox(height: 12),
          _infoRow(
            'Lexical diversity',
            (cogMarkers['lexical_diversity'] as num?)
                    ?.toStringAsFixed(3) ??
                '—',
          ),
          _infoRow(
            'Filler rate',
            (cogMarkers['filler_rate'] as num?)?.toStringAsFixed(3) ?? '—',
          ),
          _infoRow(
            'Avg sentence length',
            '${(cogMarkers['avg_sentence_length'] as num?)?.toStringAsFixed(1) ?? '—'} words',
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}