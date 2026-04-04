import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedFilter = "All";

  final List<Map<String, dynamic>> reports = [
    {
      "date": "Mar 31, 2026",
      "risk": "MEDIUM",
      "scores": [0.5, 0.6, 0.5, 0.7]
    },
    {
      "date": "Mar 15, 2026",
      "risk": "LOW",
      "scores": [0.9, 0.8, 0.85, 0.9]
    },
    {
      "date": "Feb 28, 2026",
      "risk": "LOW",
      "scores": [0.85, 0.8, 0.75, 0.9]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const NeuraBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Reports',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Track risk trends and assessment history',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ["All", "This Month", "Last 3 Months"]
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter),
                        selected: selectedFilter == filter,
                        onSelected: (_) => setState(() => selectedFilter = filter),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selectedFilter == filter
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        backgroundColor: Colors.white,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Column(
                children: reports.map((report) => _reportCard(context, report)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, Map<String, dynamic> report) {
    final theme = Theme.of(context);
    Color riskColor = report["risk"] == "LOW"
        ? AppColors.success
        : report["risk"] == "MEDIUM"
            ? AppColors.warning
            : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insert_chart_outlined_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    report["date"],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${report["risk"]} RISK",
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Assessment category scores',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: (report["scores"] as List)
                .cast<double>()
                .map((score) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.backgroundAlt,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: score,
                          child: Container(
                            decoration: BoxDecoration(
                              color: riskColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/assessment/results'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View Full Report'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
        ],
      ),
    );
  }
}