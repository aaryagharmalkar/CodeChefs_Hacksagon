import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class TugTestScreen extends StatelessWidget {
	const TugTestScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('TUG Mobility Test'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Timed Up and Go (TUG)',
							style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 10),
						const Text(
							'Stand, walk 3 meters, return, and sit. Press finish when done.',
							style: TextStyle(color: AppColors.textSecondary),
						),
						const Spacer(),
						NeuraButton(
							text: 'Finish Assessment',
							onTap: () => context.go('/assessment/results'),
						),
					],
				),
			),
		);
	}
}
