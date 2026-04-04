import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int index = 0;

  final pages = [
    {
      "title": "Catch It Before It Grows",
      "desc":
          "NeuraCare uses voice, movement, and memory tests to detect early signs of dementia, Parkinson's and more.",
      "icon": Icons.psychology,
    },
    {
      "title": "Just Speak. We Listen.",
      "desc":
          "Our app is fully voice-guided. No typing needed. Perfect for all ages.",
      "icon": Icons.graphic_eq,
    },
    {
      "title": "From Screening to Recovery",
      "desc":
          "Book doctors, track medications, and get consultation summaries.",
      "icon": Icons.sync_alt,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => index = i),
        itemCount: pages.length,
        itemBuilder: (_, i) {
          final page = pages[i];

          return Column(
            children: [
              const SizedBox(height: 80),
              Icon(page["icon"] as IconData,
                  size: 80, color: AppColors.primary),

              const Spacer(),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Text(
                      page["title"] as String,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(page["desc"] as String,
                        textAlign: TextAlign.center),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (dot) => Container(
                          margin: const EdgeInsets.all(4),
                          width: index == dot ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == dot
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    NeuraButton(
                      text: i == 2 ? "Get Started" : "Next →",
                      onTap: () {
                        if (i == 2) {
                          context.go('/auth');
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        }
                      },
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}