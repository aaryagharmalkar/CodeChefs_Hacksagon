import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

class NeuraBottomNavBar extends StatelessWidget {
	final int currentIndex;

	const NeuraBottomNavBar({
		super.key,
		required this.currentIndex,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: const BoxDecoration(
				color: Colors.white,
				border: Border(top: BorderSide(color: AppColors.border)),
			),
			child: BottomNavigationBar(
				currentIndex: currentIndex,
				selectedItemColor: AppColors.primary,
				unselectedItemColor: AppColors.textMuted,
				selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
				type: BottomNavigationBarType.fixed,
				backgroundColor: Colors.white,
				elevation: 0,
				onTap: (index) {
					const routes = [
						'/dashboard',
						'/reports',
						'/medications',
						'/medical-summariser',
						'/profile',
					];

					if (index != currentIndex) {
						context.go(routes[index]);
					}
				},
				items: const [
					BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
					BottomNavigationBarItem(
						icon: Icon(Icons.summarize_rounded),
						label: 'Reports',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.medication_liquid_rounded),
						label: 'Meds',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.mic_rounded),
						label: 'Summariser',
					),
					BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
				],
			),
		);
	}
}
