import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class ConsultationScreen extends StatelessWidget {
	const ConsultationScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Consultation'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							'Consultation Summary',
							style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 12),
						const Text(
							'Doctor has reviewed your latest assessment and medication adherence.',
							style: TextStyle(color: AppColors.textSecondary),
						),
						const Spacer(),
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
