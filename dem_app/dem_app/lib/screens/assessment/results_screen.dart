import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class ResultsScreen extends StatelessWidget {
	const ResultsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Assessment Results'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					children: [
						Container(
							width: double.infinity,
							padding: const EdgeInsets.all(20),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
							),
							child: const Column(
								children: [
									Text(
										'Low Risk',
										style: TextStyle(
											fontSize: 24,
											fontWeight: FontWeight.bold,
											color: AppColors.success,
										),
									),
									SizedBox(height: 8),
									Text('Your overall neurological score is 82/100.'),
								],
							),
						),
						const Spacer(),
						NeuraButton(
							text: 'View Reports',
							onTap: () => context.go('/reports'),
						),
						const SizedBox(height: 12),
						NeuraButton(
							text: 'Back To Dashboard',
							onTap: () => context.go('/dashboard'),
						),
					],
				),
			),
		);
	}
}
