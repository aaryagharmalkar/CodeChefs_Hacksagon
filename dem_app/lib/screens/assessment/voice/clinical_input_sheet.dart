// lib/features/voice_check/clinical_input_sheet.dart
//
// Modal bottom sheet that collects clinical parameters before recording.
// Matches your existing return contract: {'ac', 'nth', 'htn', 'updrs'}
// All four values are int (0 or 1 for toggles; 0–199 range for UPDRS).

import '../../../core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClinicalInputSheet extends StatefulWidget {
  const ClinicalInputSheet({super.key});

  @override
  State<ClinicalInputSheet> createState() => _ClinicalInputSheetState();
}

class _ClinicalInputSheetState extends State<ClinicalInputSheet> {
  // ── Toggle state ───────────────────────────────────────────────────────────
  bool _ageAbove60 = false;
  bool _neuroHistory = false;
  bool _hypertension = false;

  // ── UPDRS text field ───────────────────────────────────────────────────────
  final TextEditingController _updrsController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _updrsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final updrsValue = double.tryParse(_updrsController.text.trim()) ?? 0.0;

    Navigator.pop(context, {
      'ac': _ageAbove60 ? 1 : 0,
      'nth': _neuroHistory ? 1 : 0,
      'htn': _hypertension ? 1 : 0,
      'updrs': updrsValue,
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle bar ──────────────────────────────────────────────
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

              // ── Header ──────────────────────────────────────────────────
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

              // ── Toggle: Age above 60 ─────────────────────────────────
              _ToggleTile(
                icon: Icons.cake_outlined,
                label: 'Age above 60',
                subtitle: 'Are you 60 years old or older?',
                value: _ageAbove60,
                onChanged: (v) => setState(() => _ageAbove60 = v),
              ),

              // ── Toggle: Neurological history ─────────────────────────
              _ToggleTile(
                icon: Icons.psychology_outlined,
                label: 'Neurological history',
                subtitle: 'Any prior neurological tests or diagnoses?',
                value: _neuroHistory,
                onChanged: (v) => setState(() => _neuroHistory = v),
              ),

              // ── Toggle: Hypertension ─────────────────────────────────
              _ToggleTile(
                icon: Icons.favorite_border_rounded,
                label: 'High blood pressure',
                subtitle: 'Do you have hypertension (HTN)?',
                value: _hypertension,
                onChanged: (v) => setState(() => _hypertension = v),
              ),

              const SizedBox(height: 20),

              // ── UPDRS numeric field ───────────────────────────────────
              const _FieldLabel(
                icon: Icons.bar_chart_rounded,
                label: 'UPDRS Score',
                subtitle: "Unified Parkinson's Disease Rating Scale (0–199)",
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updrsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,3}\.?\d{0,2}'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g. 12.5  (enter 0 if unknown)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 1.6,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.6),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your UPDRS score (enter 0 if unknown)';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 0 || n > 199) return 'UPDRS must be between 0 and 199';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────────────────────
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _FieldLabel({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}