// lib/features/voice_check/clinical_input_sheet.dart
//
// Modal bottom sheet that collects clinical parameters before recording.
// Matches your existing return contract: {'ac', 'nth', 'htn'}
// All values are int toggles (0 or 1).

import '../../../core/constants/colors.dart';
import 'package:flutter/material.dart';

class ClinicalInputSheet extends StatefulWidget {
  const ClinicalInputSheet({super.key});

  @override
  State<ClinicalInputSheet> createState() => _ClinicalInputSheetState();
}

class _ClinicalInputSheetState extends State<ClinicalInputSheet> {
  bool _ageAbove60 = false;
  bool _neuroHistory = false;
  bool _hypertension = false;

  void _submit() {
    Navigator.pop(context, {
      'ac': _ageAbove60 ? 1 : 0,
      'nth': _neuroHistory ? 1 : 0,
      'htn': _hypertension ? 1 : 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.lightBlack,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Before we begin',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Answer a few quick questions so the analysis is accurate.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            _ToggleTile(
              icon: Icons.cake_outlined,
              label: 'Age above 60',
              subtitle: 'Are you 60 years old or older?',
              value: _ageAbove60,
              onChanged: (v) => setState(() => _ageAbove60 = v),
            ),
            _ToggleTile(
              icon: Icons.psychology_outlined,
              label: 'Neurological history',
              subtitle: 'Any prior neurological tests or diagnoses?',
              value: _neuroHistory,
              onChanged: (v) => setState(() => _neuroHistory = v),
            ),
            _ToggleTile(
              icon: Icons.favorite_border_rounded,
              label: 'High blood pressure',
              subtitle: 'Do you have hypertension (HTN)?',
              value: _hypertension,
              onChanged: (v) => setState(() => _hypertension = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue to Recording',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primaryBlue.withOpacity(0.06)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppColors.primaryBlue.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: value
                ? AppColors.primaryBlue.withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value ? AppColors.primaryBlue : Colors.grey.shade500,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: value ? AppColors.primaryBlue : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
