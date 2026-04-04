import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class VoiceAnalysisScreen extends StatelessWidget {
	const VoiceAnalysisScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Voice Analysis'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Read this sentence aloud:',
							style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 8),
						const Text(
							'"Today I feel calm, focused, and ready for my health check."',
						),
						const SizedBox(height: 24),
						Container(
							height: 140,
							width: double.infinity,
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
							),
							alignment: Alignment.center,
							child: const Icon(Icons.mic, size: 48, color: AppColors.primary),
						),
						const Spacer(),
						NeuraButton(
							text: 'Continue',
							onTap: () => context.go('/assessment/cookie-theft'),
						),
					],
				),
			),
		);
	}
}
