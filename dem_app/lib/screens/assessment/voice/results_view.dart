// lib/features/voice_check/results_view.dart
//
// Reads confidence + riskLevel from AppSession (written by VoiceCheckViewModel
// immediately after the ML response). Displays a color-coded result card and
// submits the full AppSession scores to the backend on Continue.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/app_session.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    // Scores were written to AppSession by VoiceCheckViewModel._uploadAndAnalyze()
    // immediately after the ML response. We only read here — never write.
    final voiceScores =
        AppSession().scores['voice'] as Map<String, dynamic>? ?? {};

    final double riskScore =
        (voiceScores['riskScore'] as num?)?.toDouble() ?? 0.0;
    final String level =
        voiceScores['riskLevel'] as String? ?? 'Unknown';
    final double pct = riskScore * 100;

    Future<void> _submitResults(BuildContext context) async {
      try {
        final storage = const FlutterSecureStorage();
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
      // riskScore < 0.20 means the recording quality was too low — retry.
      if (riskScore < 0.20) {
        context.go('/assessment/voice-analysis');
      } else {
        await _submitResults(context);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text('Your Result', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Risk card ──────────────────────────────────────────────
              _RiskCard(level: level, riskScore: riskScore, percentage: pct),

              const SizedBox(height: 20),

              // ── Score bar ──────────────────────────────────────────────
              _ScoreBar(riskScore: riskScore, percentage: pct, level: level),

              const SizedBox(height: 20),

              // ── Info card ──────────────────────────────────────────────
              _InfoCard(level: level),

              const Spacer(),

              // ── Continue ───────────────────────────────────────────────
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => handleSaveAndContinue(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue to Cognitive Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: risk colour
// ─────────────────────────────────────────────────────────────────────────────

Color _riskColor(String level) {
  switch (level.toLowerCase()) {
    case 'low':
      return const Color(0xFF2E7D32);
    case 'medium':
      return const Color(0xFFE65100);
    default:
      return const Color(0xFFC62828);
  }
}

Color _riskBg(String level) {
  switch (level.toLowerCase()) {
    case 'low':
      return const Color(0xFFE8F5E9);
    case 'medium':
      return const Color(0xFFFFF3E0);
    default:
      return const Color(0xFFFFEBEE);
  }
}

IconData _riskIcon(String level) {
  switch (level.toLowerCase()) {
    case 'low':
      return Icons.check_circle_rounded;
    case 'medium':
      return Icons.warning_amber_rounded;
    default:
      return Icons.error_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RiskCard extends StatelessWidget {
  final String level;
  final double riskScore;
  final double percentage;

  const _RiskCard({
    required this.level,
    required this.riskScore,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: _riskBg(level),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor(level).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(_riskIcon(level), size: 60, color: _riskColor(level)),
          const SizedBox(height: 14),
          Text(
            level,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: _riskColor(level),
            ),
          ),
          Text(
            'Risk Level',
            style: TextStyle(
              fontSize: 14,
              color: _riskColor(level).withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double riskScore;
  final double percentage;
  final String level;

  const _ScoreBar({
    required this.riskScore,
    required this.percentage,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightBlack,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Risk Score',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _riskColor(level),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: riskScore.clamp(0.0, 1.0),
              minHeight: 13,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_riskColor(level)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text('High',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String level;
  const _InfoCard({required this.level});

  String get _bodyText {
    switch (level.toLowerCase()) {
      case 'low':
        return 'Your voice patterns show no significant neurological indicators at this time. Continue with the remaining assessments to complete your full evaluation.';
      case 'medium':
        return 'Some mild voice irregularities were detected. This does not constitute a diagnosis. Please complete the remaining assessments and consult a clinician if concerned.';
      default:
        return 'Notable voice pattern variations were detected. This is not a medical diagnosis. We strongly recommend completing all assessments and discussing results with a healthcare professional.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _bodyText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}