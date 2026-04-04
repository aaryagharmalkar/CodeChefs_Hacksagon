import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------
class ViewMedicationService {
  static const String _base = 'http://192.168.55.176:5000';

  /// Returns medicines active on [date], with intakeTimes already resolved
  /// to human-readable labels by the backend.
  static Future<List<Map<String, dynamic>>> fetchByDate(
      DateTime date) async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final formatted =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$_base/api/medicine/fetch')
        .replace(queryParameters: {'date': formatted});

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List medicines = body['medicines'] ?? [];
      return medicines.cast<Map<String, dynamic>>();
    }
    throw Exception(
        'Failed to load medications (${response.statusCode})');
  }

  /// Returns every medicine for the patient, regardless of date.
  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final response = await http.get(
      Uri.parse('$_base/api/medicine/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception(
        'Failed to load medications (${response.statusCode})');
  }

  static Future<void> deleteMedication(String id) async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final response = await http.delete(
      Uri.parse('$_base/api/medicine/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw Exception('Failed to delete medication');
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ViewMedicationsScreen extends StatefulWidget {
  const ViewMedicationsScreen({super.key});

  @override
  State<ViewMedicationsScreen> createState() =>
      _ViewMedicationsScreenState();
}

class _ViewMedicationsScreenState
    extends State<ViewMedicationsScreen> {
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _loadForDay(_selectedDay);
  }

  void _loadForDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _future = ViewMedicationService.fetchByDate(day);
    });
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Remove "$name" from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ViewMedicationService.deleteMedication(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication removed')),
        );
        _loadForDay(_selectedDay);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-medication');
          _loadForDay(_selectedDay);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Calendar ──────────────────────────────────────────────
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _selectedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, _) =>
                _loadForDay(selectedDay),
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
            ),
          ),

          const Divider(height: 1),

          // ── Medicine list for selected day ─────────────────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () =>
                              _loadForDay(_selectedDay),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final meds = snapshot.data ?? [];

                if (meds.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medication_outlined,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No medications scheduled',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text('for this day',
                            style: TextStyle(
                                color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      16, 16, 16, 96),
                  itemCount: meds.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final med = meds[index];
                    return _MedicationCard(
                      medication: med,
                      onDelete: () => _confirmDelete(
                        med['_id']?.toString() ??
                            med['id']?.toString() ??
                            '',
                        med['name']?.toString() ??
                            'this medication',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------
class _MedicationCard extends StatelessWidget {
  final Map<String, dynamic> medication;
  final VoidCallback onDelete;

  const _MedicationCard(
      {required this.medication, required this.onDelete});

  String _formatType(String? type) {
    if (type == null || type.isEmpty) return 'Tablet';
    return type[0].toUpperCase() + type.substring(1);
  }

  String _formatDose(Map<String, dynamic> med) {
    final type = med['type']?.toString() ?? 'tablet';
    final count = med['doseCount'] ?? 1;
    if (type == 'syrup') return '$count ml';
    if (type == 'tablet') return '$count tablet(s)';
    return '$count';
  }

  /// intakeTimes: resolved labels sent by backend.
  /// customTimes: free-form strings stored on the document.
  String _formatTimes(Map<String, dynamic> med) {
    final List intakeTimes =
        (med['intakeTimes'] as List?)?.cast<String>() ?? [];
    final List customTimes =
        (med['customTimes'] as List?)?.cast<String>() ?? [];
    final all = [...intakeTimes, ...customTimes];
    if (all.isEmpty) return 'No times set';
    return all.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final name = medication['name']?.toString() ?? 'Unknown';
    final frequency =
        medication['frequency']?.toString() ?? 'Daily';
    final duration =
        medication['durationDays']?.toString() ?? '?';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(Icons.category_outlined, 'Type',
                _formatType(medication['type']?.toString())),
            _InfoRow(Icons.medical_services_outlined, 'Dose',
                _formatDose(medication)),
            _InfoRow(Icons.access_time_outlined, 'Times',
                _formatTimes(medication)),
            _InfoRow(
                Icons.repeat_outlined, 'Frequency', frequency),
            _InfoRow(Icons.calendar_today_outlined, 'Duration',
                '$duration days'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared row widget
// ---------------------------------------------------------------------------
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}