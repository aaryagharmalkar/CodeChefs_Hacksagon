import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class VoiceAssistantScreen extends StatefulWidget {
	const VoiceAssistantScreen({super.key});

	@override
	State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
	bool listening = false;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Voice Assistant'),
				backgroundColor: AppColors.background,
			),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					children: [
						const SizedBox(height: 30),
						Container(
							height: 140,
							width: 140,
							decoration: BoxDecoration(
								shape: BoxShape.circle,
								color: listening ? AppColors.primary : Colors.white,
							),
							child: Icon(
								listening ? Icons.graphic_eq : Icons.mic_none,
								size: 56,
								color: listening ? Colors.white : AppColors.primary,
							),
						),
						const SizedBox(height: 20),
						Text(
							listening ? 'Listening...' : 'Tap to start listening',
							style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
						),
						const Spacer(),
						NeuraButton(
							text: listening ? 'Stop Listening' : 'Start Listening',
							onTap: () => setState(() => listening = !listening),
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
