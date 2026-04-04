import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/app_session.dart';

import '../../core/theme/app_colors.dart';
import '../../services/assessment_service.dart';
import '../../widgets/common/neura_button.dart';

class CookieTheftScreen extends StatefulWidget {
	const CookieTheftScreen({super.key});

	@override
	State<CookieTheftScreen> createState() => _CookieTheftScreenState();
}

class _CookieTheftScreenState extends State<CookieTheftScreen> {
	late FlutterSoundRecorder _audioRecorder;
	bool _isRecording = false;
	bool _isLoading = false;
	String? _error;
	String? _audioFilePath;

	// Results from pipeline
	String? _transcript;
	Map<String, dynamic>? _audioMetrics;
	double? _dementiaProbability;
	Map<String, dynamic>? _cognitiveMarkers;

	@override
	void initState() {
		super.initState();
		_audioRecorder = FlutterSoundRecorder();
		_initializeAudioRecorder();
	}

	Future<void> _initializeAudioRecorder() async {
		try {
			final status = await Permission.microphone.request();
			if (!status.isGranted) {
				_showError('Microphone permission is required');
				return;
			}
			await _audioRecorder.closeRecorder();
			await _audioRecorder.openRecorder();
		} catch (e) {
			print('Audio recorder initialization warning: $e');
		}
	}

	@override
	void dispose() {
		_audioRecorder.closeRecorder();
		super.dispose();
	}

	Future<String> _getAudioFilePath() async {
		final dir = await getApplicationDocumentsDirectory();
		final timestamp = DateTime.now().millisecondsSinceEpoch;
		return '${dir.path}/cookie_theft_$timestamp.wav';
	}

	Future<void> _startRecording() async {
		final status = await Permission.microphone.request();

		if (!status.isGranted) {
			_showError('Microphone permission is required');
			return;
		}

		if (!_isRecording) {
			try {
				_audioFilePath = await _getAudioFilePath();
				await _audioRecorder.startRecorder(
					toFile: _audioFilePath!,
					codec: Codec.pcm16WAV,
					sampleRate: 16000,
				);

				setState(() {
					_isRecording = true;
					_error = null;
				});
			} catch (e) {
				_showError('Failed to start recording: $e');
			}
		}
	}

	Future<void> _stopRecording() async {
		if (_isRecording) {
			try {
				final recordedFile = await _audioRecorder.stopRecorder();
				if (recordedFile != null) {
					_audioFilePath = recordedFile;
				}

				setState(() {
					_isRecording = false;
				});
			} catch (e) {
				_showError('Error stopping recording: $e');
			}
		}
	}

	Future<void> _submitAssessment() async {
		if (_audioFilePath == null) {
			_showError('Please record audio first');
			return;
		}

		setState(() {
			_isLoading = true;
			_error = null;
		});

		try {
			const patientId = "69d0cd4a8c9a30bd8cb24fdd"; // TODO: Replace with actual patient ID

			final result = await AssessmentService.processAudioAssessment(
				audioFilePath: _audioFilePath!,
				patientId: patientId,
			);

			final transcript = result['data']['transcript'] as String?;
			final audioMetrics = result['data']['audio_metrics'] as Map<String, dynamic>?;
			final dementiaProbability = (result['data']['dementia_probability'] as num?)?.toDouble();
			final cognitiveMarkers = result['data']['cognitive_markers'] as Map<String, dynamic>?;

			// Store to AppSession only after we have actual results
			AppSession().scores['cookie'] = {
				'dementiaProbability': dementiaProbability,
				'audioMetrics': audioMetrics,
				'cognitiveMarkers': cognitiveMarkers,
				'transcript': transcript,
			};

			setState(() {
				_transcript = transcript;
				_audioMetrics = audioMetrics;
				_dementiaProbability = dementiaProbability;
				_cognitiveMarkers = cognitiveMarkers;
				_isLoading = false;
			});
		} catch (e) {
			setState(() {
				_error = e.toString();
				_isLoading = false;
			});
		}
	}

	void _reset() {
		setState(() {
			_audioFilePath = null;
			_transcript = null;
			_audioMetrics = null;
			_dementiaProbability = null;
			_cognitiveMarkers = null;
			_error = null;
		});
	}

  Future<void> _uploadToBackend() async {
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

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        context.go('/assessment/results');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit results. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _handleContinue() async {
    final prob = _dementiaProbability ?? 0.0;
    if (prob >= 0.6) {
      context.go('/assessment/tug-test');
    } else {
      await _uploadToBackend();
    }
  }

	void _showError(String message) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(message),
				backgroundColor: Colors.red.shade600,
				duration: const Duration(seconds: 3),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Cookie Theft Assessment'),
				backgroundColor: AppColors.background,
				elevation: 0,
			),
			body: _transcript != null
				? _buildResultsView()
				: _buildRecordingView(),
		);
	}

	Widget _buildRecordingView() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(20),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Cookie Theft Test',
						style: TextStyle(
							fontSize: 24,
							fontWeight: FontWeight.bold,
						),
					),
					const SizedBox(height: 16),
					Container(
						padding: const EdgeInsets.all(12),
						decoration: BoxDecoration(
							color: Colors.blue.shade50,
							borderRadius: BorderRadius.circular(8),
						),
						child: const Text(
							'Look at the image and describe everything you see. Tell what is happening, who is in the picture, and what the people are doing.',
							style: TextStyle(fontSize: 14),
						),
					),
					const SizedBox(height: 24),

					Container(
						height: 200,
						width: double.infinity,
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(12),
							border: Border.all(
								color: Colors.grey.shade300,
								width: 1,
							),
						),
						alignment: Alignment.center,
						child: Image.asset(
							'assets/cookie_theft.jpg',
							fit: BoxFit.cover,
							errorBuilder: (context, error, stackTrace) {
								return Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Icon(Icons.image_not_supported,
											size: 48, color: Colors.red.shade400),
										const SizedBox(height: 12),
										Text('Failed to load image',
											style:
												TextStyle(color: Colors.red.shade600)),
									],
								);
							},
						),
					),
					const SizedBox(height: 24),

					Container(
						padding: const EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: _isRecording ? Colors.red.shade50 : Colors.blue.shade50,
							borderRadius: BorderRadius.circular(12),
							border: Border.all(
								color: _isRecording ? Colors.red.shade300 : Colors.blue.shade300,
								width: 2,
							),
						),
						child: Row(
							children: [
								Icon(
									_isRecording ? Icons.mic : Icons.mic_none,
									size: 28,
									color: _isRecording ? Colors.red : AppColors.primary,
								),
								const SizedBox(width: 12),
								Expanded(
									child: Text(
										_isRecording
											? '🔴 Recording... Speak now!'
											: '🎤 Ready to record',
										style: TextStyle(
											fontSize: 14,
											fontWeight: FontWeight.w600,
											color: _isRecording ? Colors.red : AppColors.primary,
										),
									),
								),
							],
						),
					),
					const SizedBox(height: 24),

					if (!_isRecording)
						NeuraButton(
							text: '🎤 Start Recording',
							onTap: _startRecording,
						)
					else
						NeuraButton(
							text: '⏹ Stop Recording',
							onTap: _stopRecording,
						),
					const SizedBox(height: 12),

					if (!_isRecording && _audioFilePath != null)
						_isLoading
							? SizedBox(
								height: 48,
								child: ElevatedButton(
									onPressed: null,
									style: ElevatedButton.styleFrom(
										backgroundColor: AppColors.primary,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
									child: const SizedBox(
										width: 24,
										height: 24,
										child: CircularProgressIndicator(
											strokeWidth: 2,
											valueColor:
												AlwaysStoppedAnimation(Colors.white),
										),
									),
								),
							)
							: Column(
								children: [
									NeuraButton(
										text: 'Analyze Recording',
										onTap: _submitAssessment,
									),
									const SizedBox(height: 12),
									NeuraButton(
										text: 'Clear & Re-record',
										onTap: _reset,
									),
								],
							),

					if (_error != null) ...[
						const SizedBox(height: 24),
						Container(
							padding: const EdgeInsets.all(12),
							decoration: BoxDecoration(
								color: Colors.red.shade50,
								borderRadius: BorderRadius.circular(8),
								border: Border.all(color: Colors.red.shade300),
							),
							child: Row(
								children: [
									Icon(
										Icons.error_outline,
										color: Colors.red.shade600,
									),
									const SizedBox(width: 8),
									Expanded(
										child: Text(
											_error!,
											style: TextStyle(
												color: Colors.red.shade700,
												fontSize: 12,
											),
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

	Widget _buildResultsView() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(20),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					_buildRiskCard(),
					const SizedBox(height: 24),

					if (_audioMetrics != null)
						_buildMetricsSection(
							'Audio Analysis',
							[
								'Pause duration: ${_audioMetrics!['avg_pause_duration_seconds']}s',
								'Pause count: ${_audioMetrics!['pause_count']}',
							],
						),
					const SizedBox(height: 16),

					if (_cognitiveMarkers != null)
						_buildMetricsSection(
							'Cognitive Markers',
							[
								'Filler rate: ${(_cognitiveMarkers!['filler_rate'] as num).toStringAsFixed(3)}',
								'Lexical diversity: ${(_cognitiveMarkers!['lexical_diversity'] as num).toStringAsFixed(3)}',
								'Avg sentence length: ${(_cognitiveMarkers!['avg_sentence_length'] as num).toStringAsFixed(2)} words',
								'Hesitation ratio: ${(_cognitiveMarkers!['hesitation_ratio'] as num).toStringAsFixed(3)}',
								'Long pause rate: ${(_cognitiveMarkers!['long_pause_rate'] as num).toStringAsFixed(3)}',
							],
						),
					const SizedBox(height: 16),

					const Text(
						'Transcript',
						style: TextStyle(
							fontSize: 16,
							fontWeight: FontWeight.bold,
						),
					),
					const SizedBox(height: 12),
					Container(
						padding: const EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: Colors.grey.shade50,
							borderRadius: BorderRadius.circular(8),
							border: Border.all(color: Colors.grey.shade200),
						),
						child: SelectableText(
							_transcript ?? 'No transcript',
							style: const TextStyle(
								fontSize: 14,
								height: 1.5,
							),
						),
					),
					const SizedBox(height: 32),

					SizedBox(
						width: double.infinity,
						child: NeuraButton(
              text: _dementiaProbability != null && _dementiaProbability! >= 0.6
                  ? 'Next Assessment'
                  : 'Save & Continue',
              onTap: _handleContinue,
            ),
					),
					const SizedBox(height: 12),
					SizedBox(
						width: double.infinity,
						child: ElevatedButton(
							onPressed: _reset,
							style: ElevatedButton.styleFrom(
								backgroundColor: Colors.grey.shade200,
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(8),
								),
							),
							child: Text(
								'Retake Assessment',
								style: TextStyle(
									color: Colors.grey.shade800,
									fontWeight: FontWeight.w600,
								),
							),
						),
					),
				],
			),
		);
	}

	Widget _buildRiskCard() {
		if (_dementiaProbability == null) {
			return const SizedBox.shrink();
		}

		final prob = _dementiaProbability!;
		final isHighRisk = prob >= 0.6;
		final isModerateRisk = prob >= 0.3;

		final bgColor = isHighRisk
			? Colors.red.shade50
			: isModerateRisk
				? Colors.orange.shade50
				: Colors.green.shade50;
		final borderColor = isHighRisk
			? Colors.red.shade300
			: isModerateRisk
				? Colors.orange.shade300
				: Colors.green.shade300;
		final titleColor = isHighRisk
			? Colors.red.shade700
			: isModerateRisk
				? Colors.orange.shade700
				: Colors.green.shade700;
		final label = isHighRisk
			? 'High Risk'
			: isModerateRisk
				? 'Moderate Risk'
				: 'Low Risk';

		return Container(
			padding: const EdgeInsets.all(20),
			decoration: BoxDecoration(
				color: bgColor,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: borderColor, width: 3),
				boxShadow: [
					BoxShadow(
						color: titleColor.withOpacity(0.15),
						blurRadius: 12,
						offset: const Offset(0, 4),
					),
				],
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Icon(
								isHighRisk
									? Icons.warning_rounded
									: isModerateRisk
										? Icons.info_rounded
										: Icons.check_circle_rounded,
								color: titleColor,
								size: 32,
							),
							const SizedBox(width: 16),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											'Dementia Risk Assessment',
											style: TextStyle(
												fontSize: 14,
												fontWeight: FontWeight.w600,
											),
										),
										const SizedBox(height: 8),
										Text(
											label,
											style: TextStyle(
												fontSize: 22,
												fontWeight: FontWeight.bold,
												color: titleColor,
											),
										),
									],
								),
							),
							Container(
								padding: const EdgeInsets.symmetric(
									horizontal: 16,
									vertical: 12,
								),
								decoration: BoxDecoration(
									color: titleColor.withOpacity(0.15),
									borderRadius: BorderRadius.circular(12),
									border: Border.all(color: titleColor, width: 2),
								),
								child: Column(
									children: [
										Text(
											'Probability',
											style: TextStyle(
												fontSize: 10,
												fontWeight: FontWeight.w600,
												color: titleColor,
												letterSpacing: 0.5,
											),
										),
										const SizedBox(height: 4),
										Text(
											'${(prob * 100).toStringAsFixed(1)}%',
											style: TextStyle(
												fontSize: 20,
												fontWeight: FontWeight.bold,
												color: titleColor,
											),
										),
									],
								),
							),
						],
					),
					const SizedBox(height: 16),
					ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: LinearProgressIndicator(
							value: prob,
							minHeight: 12,
							backgroundColor: Colors.grey.shade300,
							valueColor: AlwaysStoppedAnimation<Color>(titleColor),
						),
					),
					const SizedBox(height: 16),
					Container(
						padding: const EdgeInsets.all(12),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(8),
						),
						child: const Text(
							'⚕️ Note: This is a screening tool, not a clinical diagnosis. Results should be reviewed with a healthcare professional.',
							style: TextStyle(
								fontSize: 11,
								fontStyle: FontStyle.italic,
							),
						),
					),
				],
			),
		);
	}

	Widget _buildMetricsSection(String title, List<String> metrics) {
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: Colors.blue.shade50,
				borderRadius: BorderRadius.circular(8),
				border: Border.all(color: Colors.blue.shade200),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						title,
						style: const TextStyle(
							fontSize: 14,
							fontWeight: FontWeight.bold,
							color: AppColors.primary,
						),
					),
					const SizedBox(height: 12),
					...metrics.map(
						(metric) => Padding(
							padding: const EdgeInsets.only(bottom: 8),
							child: Row(
								children: [
									Icon(
										Icons.check_circle,
										size: 18,
										color: AppColors.primary,
									),
									const SizedBox(width: 8),
									Expanded(
										child: Text(
											metric,
											style: const TextStyle(
												fontSize: 13,
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