import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/common/neura_button.dart';

class ProfileScreen extends StatelessWidget {
	const ProfileScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(title: const Text('My Profile')),
			bottomNavigationBar: const NeuraBottomNavBar(currentIndex: 4),
			body: SafeArea(
				child: ListView(
					padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
					children: [
						Container(
							padding: const EdgeInsets.all(18),
							decoration: BoxDecoration(
								gradient: const LinearGradient(
									begin: Alignment.topLeft,
									end: Alignment.bottomRight,
									colors: [AppColors.primary, AppColors.primaryLight],
								),
								borderRadius: BorderRadius.circular(22),
							),
							child: Row(
								children: [
									const CircleAvatar(
										radius: 33,
										backgroundColor: Colors.white24,
										child: Text(
											'R',
											style: TextStyle(
												fontSize: 28,
												fontWeight: FontWeight.w700,
												color: Colors.white,
											),
										),
									),
									const SizedBox(width: 14),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													'Ramesh Kumar',
													style: theme.textTheme.titleLarge?.copyWith(
														color: Colors.white,
														fontWeight: FontWeight.w700,
													),
												),
												const SizedBox(height: 4),
												Text(
													'Patient ID: NC-2048',
													style: theme.textTheme.bodySmall?.copyWith(
														color: Colors.white.withValues(alpha: 0.85),
													),
												),
											],
										),
									),
								],
							),
						),
						const SizedBox(height: 20),
						_profileTile(
							icon: Icons.phone_rounded,
							label: 'Phone',
							value: '+91 98765 43210',
						),
						_profileTile(
							icon: Icons.family_restroom_rounded,
							label: 'Emergency Contact',
							value: 'Sita Kumar',
						),
						_profileTile(
							icon: Icons.person_outline_rounded,
							label: 'Gender',
							value: 'Male',
						),
						const SizedBox(height: 18),
						NeuraButton(
							text: 'Edit Profile',
							icon: Icons.edit_rounded,
							onTap: () => context.go('/profile-setup'),
						),
					],
				),
			),
		);
	}

	Widget _profileTile({
		required IconData icon,
		required String label,
		required String value,
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
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(
							color: AppColors.primarySoft,
							borderRadius: BorderRadius.circular(10),
						),
						child: Icon(icon, color: AppColors.primary, size: 18),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									label,
									style: const TextStyle(
										color: AppColors.textSecondary,
										fontSize: 12,
									),
								),
								const SizedBox(height: 2),
								Text(
									value,
									style: const TextStyle(
										fontWeight: FontWeight.w700,
										color: AppColors.textPrimary,
									),
								),
							],
						),
					),
				],
			),
		);
	}
}
