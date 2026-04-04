import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// lib/features/voice_check/voice_check_view.dart
//
// Production VoiceCheckView.
// Matches your AppColors, AppTextStyles, WillPopScope, Consumer<VoiceCheckViewModel>,
// and Navigator.pushReplacementNamed routing contract exactly.

import 'dart:math' as math;

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import 'voice_check_viewmodel.dart';
import 'package:provider/provider.dart';

import './clinical_input_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry widget (keeps StatelessWidget outer shell you already have)
// ─────────────────────────────────────────────────────────────────────────────

class VoiceCheckView extends StatelessWidget {
  const VoiceCheckView({super.key});
  

  @override
  Widget build(BuildContext context) {
    return const _VoiceCheckBody();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body – StatefulWidget for sheet + navigation side-effects
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceCheckBody extends StatefulWidget {
  const _VoiceCheckBody();

  @override
  State<_VoiceCheckBody> createState() => _VoiceCheckBodyState();
}

class _VoiceCheckBodyState extends State<_VoiceCheckBody>
    with SingleTickerProviderStateMixin {
  bool _formShown = false;

  // Wave animation controller
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_formShown) {
      _formShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const ClinicalInputSheet(),
        );

        if (!mounted || result == null) return;

        final vm = context.read<VoiceCheckViewModel>();

        vm.setClinicalInputs(
          ac: (result['ac'] as num).toInt(),
          nth: (result['nth'] as num).toInt(),
          htn: (result['htn'] as num).toInt(),
        );

        await vm.startRecording();
      });
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  // Navigation check — called from Consumer builder
  void _checkAndNavigate(VoiceCheckViewModel vm) {
    if (vm.shouldNavigateToProcessing) {
      vm.resetNavigationFlags();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/assessment/voice-processing');
      });
    }

    if (vm.shouldNavigateToResults) {
      vm.resetNavigationFlags();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/assessment/voice/results');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent the system back gesture while recording is active.
      // When not recording, allow pop but redirect to /assessment via onPopInvoked.
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return; // already handled (shouldn't happen with canPop:false)
        final vm = context.read<VoiceCheckViewModel>();
        if (vm.isRecording) {
          await vm.stopRecording();
        }
        if (!mounted) return;
        context.go('/assessment');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.black),
            onPressed: () async {
              final vm = context.read<VoiceCheckViewModel>();
              if (vm.isRecording) {
                await vm.stopRecording();
              }
              if (!mounted) return;
              context.go('/assessment');
            },
          ),
          title: const Text('Voice Check', style: AppTextStyles.title),
        ),
        body: SafeArea(
          child: Consumer<VoiceCheckViewModel>(
            builder: (_, vm, __) {
              _checkAndNavigate(vm);

              // Error overlay
              if (vm.errorMessage != null && !vm.isRecording) {
                return _ErrorBody(
                  message: vm.errorMessage!,
                  onRetry: () async {
                    // Reset error then attempt again
                    vm.resetNavigationFlags();
                    await vm.startRecording();
                  },
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // ── Instruction card ────────────────────────────────────
                    _InstructionCard(isRecording: vm.isRecording),

                    const SizedBox(height: 36),

                    // ── Wave bars ───────────────────────────────────────────
                    _WaveBars(
                      animation: _waveCtrl,
                      active: vm.isRecording,
                    ),

                    const SizedBox(height: 24),

                    // ── Status chip ─────────────────────────────────────────
                    _StatusChip(isRecording: vm.isRecording),

                    const SizedBox(height: 28),

                    // ── Timer ───────────────────────────────────────────────
                    Text(vm.formattedTime, style: AppTextStyles.timer),
                    const SizedBox(height: 6),
                    const Text(
                      'RECORDING TIME',
                      style: TextStyle(
                        letterSpacing: 2.0,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const Spacer(),

                    // ── Stop button ─────────────────────────────────────────
                    _StopButton(vm: vm),

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instruction card
// ─────────────────────────────────────────────────────────────────────────────

class _InstructionCard extends StatelessWidget {
  final bool isRecording;
  const _InstructionCard({required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRecording
              ? AppColors.dangerRed.withOpacity(0.25)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: AppColors.lightBlack,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('Level 1', style: AppTextStyles.stepText),
          const SizedBox(height: 10),
          const Text('Say "aaaa"', style: AppTextStyles.title),
          const SizedBox(height: 8),
          const Text(
            'Keep your voice steady for 10–15 seconds.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          if (isRecording) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.dangerRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'RECORDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated wave bars
// ─────────────────────────────────────────────────────────────────────────────

class _WaveBars extends StatelessWidget {
  final Animation<double> animation;
  final bool active;

  const _WaveBars({required this.animation, required this.active});

  static const List<double> _baseHeights = [
    44, 68, 88, 100, 88, 68, 44, 56, 80, 60, 40, 72, 92
  ];
  static const List<double> _phases = [
    0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 0.2, 0.35, 0.5, 0.65, 0.8, 0.1
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_baseHeights.length, (i) {
              final double wave = active
                  ? math.sin(
                          (animation.value + _phases[i]) * 2 * math.pi) *
                      0.5 +
                      0.5
                  : 0.3; // inactive – short flat bars
              final double h = active
                  ? 20 + (_baseHeights[i] - 20) * wave
                  : _baseHeights[i] * 0.3;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: h,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryBlue
                          .withOpacity(0.5 + wave * 0.5)
                      : AppColors.primaryBlue.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isRecording;
  const _StatusChip({required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: isRecording
          ? _chip(
              key: const ValueKey('active'),
              color: AppColors.successGreen,
              icon: Icons.check_circle,
              label: 'Nice and steady!',
            )
          : _chip(
              key: const ValueKey('waiting'),
              color: Colors.grey.shade400,
              icon: Icons.mic_none_rounded,
              label: 'Waiting to start…',
            ),
    );
  }

  Widget _chip({
    required Key key,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stop button
// ─────────────────────────────────────────────────────────────────────────────

class _StopButton extends StatelessWidget {
  final VoiceCheckViewModel vm;
  const _StopButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: vm.isRecording ? vm.stopRecording : null,
        icon: const Icon(Icons.stop_circle_outlined, size: 22),
        label: const Text(
          'Stop Recording',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dangerRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error body
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.dangerRed,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Try Again',
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
    );
  }
}