// lib/features/voice_check/processing_view.dart
//
// Shown immediately after stopRecording() fires (navigateToProcessing = true).
// Listens on the shared VoiceCheckViewModel via Consumer and auto-navigates
// to /results once navigateToResults becomes true.

import '../../../core/constants/colors.dart';
import './voice_check_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class ProcessingView extends StatefulWidget {
  const ProcessingView({super.key});

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _checkNavigate(VoiceCheckViewModel vm) {
    if (vm.shouldNavigateToResults) {
      vm.resetNavigationFlags();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/assessment/voice/results');
      });
    }

    if (vm.errorMessage != null && !vm.isUploading) {
      vm.resetNavigationFlags();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Go back to voice-check so user can retry
        context.go('/assessment/voice-analysis');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<VoiceCheckViewModel>(
          builder: (_, vm, __) {
            _checkNavigate(vm);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Pulse icon ──────────────────────────────────────────
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withOpacity(0.12),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 56,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    'Analysing your voice…',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Our AI model is processing your recording.\nThis may take up to 30 seconds.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // ── Progress bar ────────────────────────────────────────
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Processing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            vm.progressLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: vm.processProgress.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Please keep the app open',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}