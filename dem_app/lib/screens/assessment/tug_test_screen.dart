import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class TugTestScreen extends StatefulWidget {
	const TugTestScreen({super.key});

	@override
	State<TugTestScreen> createState() => _TugTestScreenState();
}

class _TugTestScreenState extends State<TugTestScreen> {
	Timer? _ticker;
	final Stopwatch _stopwatch = Stopwatch();

	int _countdown = 3;
	bool _isStarted = false;
	bool _isCompleted = false;
	int _phaseIndex = 0;

	static const List<String> _phases = [
		'Sit to Stand',
		'Walk Forward (3m)',
		'Turn Around',
		'Walk Back',
		'Stand to Sit',
	];

	static const List<String> _phaseCues = [
		'Stand up safely from the chair.',
		'Walk forward steadily to the marker.',
		'Turn carefully and maintain balance.',
		'Walk back toward the chair.',
		'Sit down in a controlled manner.',
	];

	@override
	void dispose() {
		_ticker?.cancel();
		_stopwatch.stop();
		super.dispose();
	}

	void _startCountdown() {
		if (_isStarted || _isCompleted) return;

		setState(() {
			_countdown = 3;
		});

		_ticker?.cancel();
		_ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
			if (_countdown > 1) {
				setState(() => _countdown--);
				return;
			}

			timer.cancel();
			setState(() {
				_isStarted = true;
				_countdown = 0;
				_phaseIndex = 0;
			});
			_stopwatch
				..reset()
				..start();

			_ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
				if (mounted) setState(() {});
			});
		});
	}

	void _nextPhase() {
		if (!_isStarted || _isCompleted) return;

		if (_phaseIndex < _phases.length - 1) {
			setState(() => _phaseIndex++);
			return;
		}

		_completeTest();
	}

	void _completeTest() {
		if (!_isStarted || _isCompleted) return;

		_stopwatch.stop();
		_ticker?.cancel();

		setState(() {
			_isCompleted = true;
			_isStarted = false;
		});
	}

	String _formatElapsed() {
		final elapsed = _stopwatch.elapsed;
		final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
		final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
		final millis = (elapsed.inMilliseconds.remainder(1000) ~/ 10)
				.toString()
				.padLeft(2, '0');
		return '$minutes:$seconds.$millis';
	}

	Widget _buildStepStatus() {
		return Column(
			children: List.generate(_phases.length, (index) {
				final isDone = index < _phaseIndex || (_isCompleted && index == _phaseIndex);
				final isCurrent = index == _phaseIndex && _isStarted && !_isCompleted;

				return Container(
					margin: const EdgeInsets.only(bottom: 10),
					padding: const EdgeInsets.all(12),
					decoration: BoxDecoration(
						color: isCurrent ? AppColors.primarySoft : Colors.white,
						borderRadius: BorderRadius.circular(12),
						border: Border.all(
							color: isDone || isCurrent ? AppColors.primary : AppColors.border,
						),
					),
					child: Row(
						children: [
							Icon(
								isDone ? Icons.check_circle : Icons.radio_button_unchecked,
								color: isDone ? AppColors.success : AppColors.textMuted,
							),
							const SizedBox(width: 10),
							Expanded(
								child: Text(
									_phases[index],
									style: TextStyle(
										fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
										color: AppColors.textPrimary,
									),
								),
							),
						],
					),
				);
			}),
		);
	}

	@override
	Widget build(BuildContext context) {
		final showCountdown = !_isStarted && !_isCompleted && _countdown > 0;
		final currentCue = _isCompleted ? 'Test completed successfully.' : _phaseCues[_phaseIndex];

		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('TUG Mobility Test'),
				backgroundColor: AppColors.background,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Timed Up and Go (TUG)',
							style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 8),
						const Text(
							'Complete all mobility phases continuously. Use Next Phase after each step.',
							style: TextStyle(color: AppColors.textSecondary),
						),
						const SizedBox(height: 16),
						Container(
							width: double.infinity,
							padding: const EdgeInsets.all(18),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
								border: Border.all(color: AppColors.border),
							),
							child: Column(
								children: [
									Text(
										showCountdown ? 'Starting in $_countdown' : (_isCompleted ? 'Completed' : 'In Progress'),
										style: TextStyle(
											fontSize: 18,
											fontWeight: FontWeight.w700,
											color: _isCompleted ? AppColors.success : AppColors.primary,
										),
									),
									const SizedBox(height: 8),
									Text(
										_formatElapsed(),
										style: const TextStyle(
											fontSize: 34,
											fontWeight: FontWeight.bold,
											letterSpacing: 1,
										),
									),
								],
							),
						),
						const SizedBox(height: 16),
						Container(
							width: double.infinity,
							padding: const EdgeInsets.all(14),
							decoration: BoxDecoration(
								color: AppColors.primarySoft,
								borderRadius: BorderRadius.circular(12),
							),
							child: Text(
								currentCue,
								style: const TextStyle(
									color: AppColors.textPrimary,
									fontWeight: FontWeight.w600,
								),
							),
						),
						const SizedBox(height: 16),
						_buildStepStatus(),
						const SizedBox(height: 8),
						if (!_isStarted && !_isCompleted)
							NeuraButton(
								text: 'Start TUG Test',
								onTap: _startCountdown,
							),
						if (_isStarted && !_isCompleted) ...[
							NeuraButton(
								text: _phaseIndex == _phases.length - 1 ? 'Complete Test' : 'Next Phase',
								onTap: _nextPhase,
							),
							const SizedBox(height: 10),
							NeuraButton(
								text: 'Stop Test',
								onTap: _completeTest,
							),
						],
						if (_isCompleted) ...[
							NeuraButton(
								text: 'View Results',
								onTap: () => context.go('/assessment/results'),
							),
						],
					],
				),
			),
		);
	}
}