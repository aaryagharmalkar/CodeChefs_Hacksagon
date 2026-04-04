import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/common/neura_button.dart';

class MedicationsScreen extends StatelessWidget {
	const MedicationsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(title: const Text('Medication Plan')),
			bottomNavigationBar: const NeuraBottomNavBar(currentIndex: 2),
			body: SafeArea(
				child: ListView(
					padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
					children: [
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: AppColors.card,
								borderRadius: BorderRadius.circular(18),
								border: Border.all(color: AppColors.border),
							),
							child: const Row(
								children: [
									Icon(Icons.schedule_rounded, color: AppColors.primary),
									SizedBox(width: 10),
									Expanded(
										child: Text(
											'2 medications due today. Tap an item to view reminders.',
											style: TextStyle(color: AppColors.textSecondary),
										),
									),
								],
							),
						),
						const SizedBox(height: 20),
						Text('Today', style: theme.textTheme.titleLarge),
						const SizedBox(height: 12),
						_medTile(
							icon: Icons.wb_sunny_outlined,
							name: 'Levodopa',
							time: '8:00 AM',
							dosage: '1 tablet after breakfast',
						),
						_medTile(
							icon: Icons.nights_stay_outlined,
							name: 'Donepezil',
							time: '8:00 PM',
							dosage: '1 tablet after dinner',
						),
						const SizedBox(height: 18),
						NeuraButton(
							text: 'Schedule Consultation',
							icon: Icons.calendar_month_rounded,
							onTap: () => context.go('/consultation'),
						),
					],
				),
			),
		);
	}

	Widget _medTile({
		required IconData icon,
		required String name,
		required String time,
		required String dosage,
	}) {
		return Container(
			margin: const EdgeInsets.only(bottom: 12),
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: AppColors.border),
			),
			child: Row(
				children: [
					Container(
						padding: const EdgeInsets.all(9),
						decoration: BoxDecoration(
							color: AppColors.primarySoft,
							borderRadius: BorderRadius.circular(12),
						),
						child: Icon(icon, color: AppColors.primary, size: 20),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									name,
									style: const TextStyle(
										fontWeight: FontWeight.w700,
										color: AppColors.textPrimary,
									),
								),
								const SizedBox(height: 2),
								Text(
									dosage,
									style: const TextStyle(
										color: AppColors.textSecondary,
										fontSize: 13,
									),
								),
							],
						),
					),
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
						decoration: BoxDecoration(
							color: AppColors.backgroundAlt,
							borderRadius: BorderRadius.circular(10),
						),
						child: Text(
							time,
							style: const TextStyle(
								fontWeight: FontWeight.w700,
								color: AppColors.textPrimary,
							),
						),
					),
				],
			),
		);
	}
}
