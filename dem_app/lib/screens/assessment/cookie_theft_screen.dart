import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class CookieTheftScreen extends StatelessWidget {
	const CookieTheftScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Cookie Theft Test'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Describe everything happening in this scene.',
							style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 12),
						Container(
							height: 200,
							width: double.infinity,
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
							),
							alignment: Alignment.center,
							child: const Text('Scene Placeholder'),
						),
						const Spacer(),
						NeuraButton(
							text: 'Continue',
							onTap: () => context.go('/assessment/tug-test'),
						),
					],
				),
			),
		);
	}
}
