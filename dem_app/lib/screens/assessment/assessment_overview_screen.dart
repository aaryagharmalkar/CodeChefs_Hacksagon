import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class AssessmentOverviewScreen extends StatelessWidget {
	const AssessmentOverviewScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				backgroundColor: AppColors.background,
				title: const Text('Assessment Overview'),
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Today\'s Assessment Plan',
							style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 12),
						const Text(
							'Complete these tests in sequence to generate your report.',
							style: TextStyle(color: AppColors.textSecondary),
						),
						const SizedBox(height: 24),
						const _StepTile(title: '1. MMSE Memory Test'),
						const _StepTile(title: '2. Voice Analysis'),
						const _StepTile(title: '3. Cookie Theft Description'),
						const _StepTile(title: '4. TUG Mobility Test'),
						const Spacer(),
						NeuraButton(
							text: 'Start MMSE Test',
							onTap: () => context.go('/assessment/mmse'),
						),
					],
				),
			),
		);
	}
}

class _StepTile extends StatelessWidget {
	final String title;

	const _StepTile({required this.title});

	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.only(bottom: 12),
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(14),
			),
			child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
		);
	}
}
