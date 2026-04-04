import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Shared accent colour — swap out for AppColors if you wire that up later
// ---------------------------------------------------------------------------
const Color _kAccent = Color(0xFFB39DDB);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------
class MedicationService {
  static const String _mainBackend = 'http://192.168.55.176:5000';
  static const String _voiceServer = 'http://192.168.55.176:5001';
  static const String _prescriptionServer = 'http://192.168.55.176:5002';

  static Future<void> addMedication(Map<String, dynamic> data) async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final response = await http.post(
      Uri.parse('$_mainBackend/api/medicine/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add medication');
    }
  }

  static Future<Map<String, dynamic>> processVoiceInput(
      String audioPath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_voiceServer/api/medicine/process-voice'),
    );
    request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      return jsonDecode(body);
    }
    throw Exception('Failed to process voice input');
  }

  static Future<List<Map<String, dynamic>>> extractFromFile(
      String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_prescriptionServer/api/medicine/extract-file'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      if (json['success'] == true) {
        return (json['medicines'] as List).cast<Map<String, dynamic>>();
      }
      throw Exception(json['message'] ?? 'No medicines detected');
    }
    throw Exception('Failed to process file');
  }
}

// ===========================================================================
// ADD MEDICATION SCREEN  (single medication)
// ===========================================================================
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();

  String _medicineType = 'tablet';
  final Map<String, bool> _intakeMap = {
    'Before Breakfast': false,
    'After Breakfast': false,
    'Before Lunch': false,
    'After Lunch': false,
    'Before Dinner': false,
    'After Dinner': false,
  };
  List<TimeOfDay> _customTimes = [];
  String _frequency = 'Daily';
  int _doseCount = 1;

  // Voice
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // ── Voice ────────────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) await _processRecording(path);
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showError('Microphone permission required');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/med_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
      setState(() => _isRecording = true);
    }
  }

  Future<void> _processRecording(String audioPath) async {
    setState(() => _isProcessing = true);
    try {
      final result = await MedicationService.processVoiceInput(audioPath);
      setState(() {
        _nameController.text = result['name'] ?? '';
        _medicineType = result['type'] ?? 'tablet';
        _doseCount =
            result['doseCount'] ?? (_medicineType == 'syrup' ? 5 : 1);
        _frequency = result['frequency'] ?? 'Daily';
        _durationController.text = (result['durationDays'] ?? 7).toString();

        _intakeMap.forEach((k, _) => _intakeMap[k] = false);
        for (final t in (result['intakeTimes'] as List? ?? [])) {
          if (_intakeMap.containsKey(t)) _intakeMap[t] = true;
        }

        _customTimes.clear();
        for (final ts in (result['customTimes'] as List? ?? [])) {
          final parts = ts.toString().split(':');
          if (parts.length == 2) {
            _customTimes.add(TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            ));
          }
        }
      });
      _showSuccess('Voice input processed! Review and edit if needed.');
    } catch (e) {
      _showError('Error processing voice: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ── Custom time ───────────────────────────────────────────────────────────
  Future<void> _pickCustomTime({int? editIndex}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          editIndex != null ? _customTimes[editIndex] : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (editIndex != null) {
          _customTimes[editIndex] = picked;
        } else {
          _customTimes.add(picked);
        }
      });
    }
  }

  // ── Validation & save ─────────────────────────────────────────────────────
  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter medicine name');
      return false;
    }
    final intakeSelected = _intakeMap.values.any((v) => v);
    if (!intakeSelected && _customTimes.isEmpty) {
      _showError('Please select at least one intake time or add a custom time');
      return false;
    }
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      _showError('Duration must be greater than 0 days');
      return false;
    }
    if (_medicineType == 'tablet' && _doseCount < 1) {
      _showError('Tablet count must be at least 1');
      return false;
    }
    if (_medicineType == 'syrup' && _doseCount < 5) {
      _showError('Syrup quantity must be at least 5 ml');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    final intakeTimes =
        _intakeMap.entries.where((e) => e.value).map((e) => e.key).toList();

    final data = {
      'name': _nameController.text.trim(),
      'type': _medicineType,
      'intakeTimes': intakeTimes,
      'customTimes': _customTimes.map((t) => t.format(context)).toList(),
      'frequency': _frequency,
      'doseCount': _doseCount,
      'durationDays': int.parse(_durationController.text),
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await MedicationService.addMedication(data);
      _showSuccess('Medication saved!');
      if (mounted) context.pop();
    } catch (e) {
      _showError('Failed to save medication: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg), backgroundColor: const Color(0xFF4CAF50)),
      );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const _PrescriptionSheet(),
              );
            },
            child: const Text('From Prescription'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Voice input banner ──────────────────────────────────────
            _VoiceBanner(
              isRecording: _isRecording,
              isProcessing: _isProcessing,
              onTap: _isProcessing ? null : _toggleRecording,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── Medicine name ───────────────────────────────────────────
            const _SectionLabel('Medicine Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter medicine name',
                prefixIcon: Icon(Icons.medication, color: _kAccent),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Type ────────────────────────────────────────────────────
            const _SectionLabel('Medicine Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _medicineType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category, color: _kAccent),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                DropdownMenuItem(value: 'syrup', child: Text('Syrup')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() {
                _medicineType = v!;
                _doseCount = v == 'syrup' ? 5 : 1;
              }),
            ),
            const SizedBox(height: 20),

            // ── Intake times ────────────────────────────────────────────
            const _SectionLabel('Time of Intake'),
            const SizedBox(height: 12),
            _buildMealSection('Breakfast'),
            _buildMealSection('Lunch'),
            _buildMealSection('Dinner'),
            const SizedBox(height: 12),

            // Custom times
            OutlinedButton.icon(
              onPressed: () => _pickCustomTime(),
              icon: const Icon(Icons.add_circle_outline, color: _kAccent),
              label: const Text('Add Custom Time',
                  style: TextStyle(color: _kAccent)),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _customTimes.length; i++)
              ListTile(
                leading:
                    const Icon(Icons.access_time, color: _kAccent),
                title: Text(_customTimes[i].format(context)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: _kAccent),
                      onPressed: () => _pickCustomTime(editIndex: i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () =>
                          setState(() => _customTimes.removeAt(i)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ── Frequency ───────────────────────────────────────────────
            const _SectionLabel('Frequency'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.repeat, color: _kAccent),
                border: OutlineInputBorder(),
              ),
              items: ['Daily', 'Alternate Days']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 20),

            // ── Duration ────────────────────────────────────────────────
            const _SectionLabel('Duration (days)'),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 7',
                prefixIcon: Icon(Icons.calendar_today, color: _kAccent),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Dosage ──────────────────────────────────────────────────
            if (_medicineType != 'other') ...[
              _SectionLabel(
                  _medicineType == 'tablet' ? 'Dosage' : 'Quantity'),
              const SizedBox(height: 8),
              _DoseStepper(
                medicineType: _medicineType,
                doseCount: _doseCount,
                onChanged: (v) => setState(() => _doseCount = v),
              ),
              const SizedBox(height: 20),
            ],

            // ── Save ────────────────────────────────────────────────────
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Medication',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(String meal) {
    final beforeKey = 'Before $meal';
    final afterKey = 'After $meal';
    final beforeSelected = _intakeMap[beforeKey] == true;
    final afterSelected = _intakeMap[afterKey] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(meal,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: _TogglePill(
              label: 'Before',
              selected: beforeSelected,
              onTap: () =>
                  setState(() => _intakeMap[beforeKey] = !beforeSelected),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TogglePill(
              label: 'After',
              selected: afterSelected,
              onTap: () =>
                  setState(() => _intakeMap[afterKey] = !afterSelected),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// PRESCRIPTION BOTTOM SHEET  (camera / gallery / PDF → extract → save all)
// ===========================================================================
class _PrescriptionSheet extends StatefulWidget {
  const _PrescriptionSheet();

  @override
  State<_PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _PrescriptionSheetState extends State<_PrescriptionSheet> {
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _extractedMedicines = [];

  // ── File picking ──────────────────────────────────────────────────────────
  Future<void> _pickCamera() async {
    final img = await _imagePicker.pickImage(
        source: ImageSource.camera, imageQuality: 85);
    if (img != null) {
      setState(() {
        _selectedFilePath = img.path;
        _selectedFileName = img.name;
        _extractedMedicines = [];
      });
    }
  }

  Future<void> _pickGallery() async {
    final img = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img != null) {
      setState(() {
        _selectedFilePath = img.path;
        _selectedFileName = img.name;
        _extractedMedicines = [];
      });
    }
  }

  Future<void> _pickPDF() async {
    final pdfType = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final file = await openFile(acceptedTypeGroups: [pdfType]);
    if (file != null) {
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = file.name;
        _extractedMedicines = [];
      });
    }
  }

  // ── Extract ───────────────────────────────────────────────────────────────
  Future<void> _processFile() async {
    if (_selectedFilePath == null) return;
    setState(() {
      _isProcessing = true;
      _extractedMedicines = [];
    });
    try {
      final meds =
          await MedicationService.extractFromFile(_selectedFilePath!);
      if (meds.isEmpty) {
        _showSnack('No medications found in the prescription',
            Colors.orange);
      } else {
        setState(() => _extractedMedicines = meds);
        _showSnack(
            'Found ${meds.length} medication(s)! Review and save.',
            const Color(0xFF4CAF50));
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ── Validate & save all ───────────────────────────────────────────────────
  bool _validateMed(Map<String, dynamic> med) {
    if (med['name'] == null ||
        med['name'].toString().trim().isEmpty) return false;
    final intakeTimes = med['intakeTimes'] as List? ?? [];
    final customTimes = med['customTimes'] as List? ?? [];
    if (intakeTimes.isEmpty && customTimes.isEmpty) return false;
    final duration = med['durationDays'] as int?;
    if (duration == null || duration <= 0) return false;
    final dose = med['doseCount'] as int? ?? 0;
    if (med['type'] == 'tablet' && dose < 1) return false;
    if (med['type'] == 'syrup' && dose < 5) return false;
    return true;
  }

  Future<void> _saveAll() async {
    final invalid = <String>[];
    for (int i = 0; i < _extractedMedicines.length; i++) {
      if (!_validateMed(_extractedMedicines[i])) {
        invalid.add(
            _extractedMedicines[i]['name']?.toString() ??
                'Medicine ${i + 1}');
      }
    }
    if (invalid.isNotEmpty) {
      _showSnack(
          'Invalid data in: ${invalid.join(', ')}. Please edit first.',
          Colors.red);
      return;
    }

    int success = 0, fail = 0;
    for (final med in _extractedMedicines) {
      try {
        med['createdAt'] = DateTime.now().toIso8601String();
        await MedicationService.addMedication(med);
        success++;
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      if (fail == 0) {
        _showSnack('Saved all $success medication(s)!',
            const Color(0xFF4CAF50));
        Navigator.pop(context); // close sheet
      } else {
        _showSnack('Saved $success, Failed $fail medication(s)',
            Colors.orange);
      }
    }
  }

  void _editMedicine(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditMedicineSheet(
        medicine: _extractedMedicines[index],
        onSave: (updated) =>
            setState(() => _extractedMedicines[index] = updated),
      ),
    );
  }

  void _deleteMedicine(int index) {
    setState(() => _extractedMedicines.removeAt(index));
    _showSnack('Medication removed', Colors.orange);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('From Prescription',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Upload card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: _kAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFilePath != null
                              ? Icons.check_circle_outline
                              : Icons.upload_file,
                          size: 42,
                          color: _kAccent,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedFilePath != null
                              ? 'Selected: $_selectedFileName'
                              : 'Upload prescription image or PDF',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isProcessing ? null : _pickCamera,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isProcessing ? null : _pickGallery,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _pickPDF,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Choose PDF'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Extract button
                  if (_selectedFilePath != null && !_isProcessing) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _processFile,
                        child: const Text('Extract Medications'),
                      ),
                    ),
                  ],

                  // Loading
                  if (_isProcessing) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    const Center(
                        child: Text('Processing prescription...')),
                  ],

                  // Extracted list
                  if (_extractedMedicines.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Extracted Medications',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('${_extractedMedicines.length} found',
                            style: TextStyle(color: _kAccent)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0;
                        i < _extractedMedicines.length;
                        i++)
                      _ExtractedMedCard(
                        medicine: _extractedMedicines[i],
                        onEdit: () => _editMedicine(i),
                        onDelete: () => _deleteMedicine(i),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveAll,
                        child: Text(
                            'Save All ${_extractedMedicines.length} Medications'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// EDIT MEDICINE SHEET  (bottom sheet opened from prescription sheet)
// ===========================================================================
class _EditMedicineSheet extends StatefulWidget {
  final Map<String, dynamic> medicine;
  final Function(Map<String, dynamic>) onSave;

  const _EditMedicineSheet(
      {required this.medicine, required this.onSave});

  @override
  State<_EditMedicineSheet> createState() => _EditMedicineSheetState();
}

class _EditMedicineSheetState extends State<_EditMedicineSheet> {
  late TextEditingController _nameController;
  late TextEditingController _durationController;
  late String _medicineType;
  late Map<String, bool> _intakeMap;
  late List<TimeOfDay> _customTimes;
  late String _frequency;
  late int _doseCount;

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController =
        TextEditingController(text: med['name']?.toString() ?? '');
    _durationController = TextEditingController(
        text: (med['durationDays'] ?? 7).toString());
    _medicineType = med['type']?.toString() ?? 'tablet';
    _intakeMap = {
      'Before Breakfast': false,
      'After Breakfast': false,
      'Before Lunch': false,
      'After Lunch': false,
      'Before Dinner': false,
      'After Dinner': false,
    };
    for (final t in (med['intakeTimes'] as List? ?? [])) {
      if (_intakeMap.containsKey(t)) _intakeMap[t] = true;
    }
    _customTimes = [];
    for (final ts in (med['customTimes'] as List? ?? [])) {
      final parts = ts.toString().split(':');
      if (parts.length >= 2) {
        _customTimes.add(TimeOfDay(
          hour: int.parse(parts[0].trim()),
          minute: int.parse(parts[1].trim().split(' ')[0]),
        ));
      }
    }
    _frequency = med['frequency']?.toString() ?? 'Daily';
    _doseCount = med['doseCount'] as int? ??
        (_medicineType == 'syrup' ? 5 : 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomTime({int? editIndex}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: editIndex != null
          ? _customTimes[editIndex]
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (editIndex != null) {
          _customTimes[editIndex] = picked;
        } else {
          _customTimes.add(picked);
        }
      });
    }
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter medicine name');
      return;
    }
    final intakeSelected = _intakeMap.values.any((v) => v);
    if (!intakeSelected && _customTimes.isEmpty) {
      _showError('Please select at least one intake time');
      return;
    }
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      _showError('Duration must be greater than 0 days');
      return;
    }

    final intakeTimes =
        _intakeMap.entries.where((e) => e.value).map((e) => e.key).toList();

    widget.onSave({
      'name': _nameController.text.trim(),
      'type': _medicineType,
      'intakeTimes': intakeTimes,
      'customTimes': _customTimes.map((t) => t.format(context)).toList(),
      'frequency': _frequency,
      'doseCount': _doseCount,
      'durationDays': duration,
    });
    Navigator.pop(context);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Edit Medication',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Name
                  const _SectionLabel('Medicine Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.medication, color: _kAccent),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Type
                  const _SectionLabel('Medicine Type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _medicineType,
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.category, color: _kAccent),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'tablet', child: Text('Tablet')),
                      DropdownMenuItem(
                          value: 'syrup', child: Text('Syrup')),
                      DropdownMenuItem(
                          value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() {
                      _medicineType = v!;
                      _doseCount = v == 'syrup' ? 5 : 1;
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Intake times
                  const _SectionLabel('Time of Intake'),
                  const SizedBox(height: 12),
                  for (final meal in ['Breakfast', 'Lunch', 'Dinner'])
                    _buildMealRow(meal),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickCustomTime(),
                    icon: const Icon(Icons.add_circle_outline,
                        color: _kAccent),
                    label: const Text('Add Custom Time',
                        style: TextStyle(color: _kAccent)),
                  ),
                  for (int i = 0; i < _customTimes.length; i++)
                    ListTile(
                      leading: const Icon(Icons.access_time,
                          color: _kAccent),
                      title: Text(_customTimes[i].format(context)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: _kAccent),
                            onPressed: () =>
                                _pickCustomTime(editIndex: i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => setState(
                                () => _customTimes.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Frequency
                  const _SectionLabel('Frequency'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.repeat, color: _kAccent),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Daily', 'Alternate Days']
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _frequency = v!),
                  ),
                  const SizedBox(height: 16),

                  // Duration
                  const _SectionLabel('Duration (days)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 7',
                      prefixIcon: Icon(Icons.calendar_today,
                          color: _kAccent),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dosage
                  if (_medicineType != 'other') ...[
                    _SectionLabel(_medicineType == 'tablet'
                        ? 'Dosage'
                        : 'Quantity'),
                    const SizedBox(height: 8),
                    _DoseStepper(
                      medicineType: _medicineType,
                      doseCount: _doseCount,
                      onChanged: (v) => setState(() => _doseCount = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMealRow(String meal) {
    final beforeKey = 'Before $meal';
    final afterKey = 'After $meal';
    final beforeSelected = _intakeMap[beforeKey] == true;
    final afterSelected = _intakeMap[afterKey] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(meal,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: _TogglePill(
              label: 'Before',
              selected: beforeSelected,
              onTap: () =>
                  setState(() => _intakeMap[beforeKey] = !beforeSelected),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TogglePill(
              label: 'After',
              selected: afterSelected,
              onTap: () =>
                  setState(() => _intakeMap[afterKey] = !afterSelected),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SMALL SHARED WIDGETS
// ===========================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600));
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TogglePill(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _kAccent : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoseStepper extends StatelessWidget {
  final String medicineType;
  final int doseCount;
  final ValueChanged<int> onChanged;

  const _DoseStepper(
      {required this.medicineType,
      required this.doseCount,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isSyrup = medicineType == 'syrup';
    final step = isSyrup ? 5 : 1;
    final min = isSyrup ? 5 : 1;
    final label = isSyrup ? '$doseCount ml' : '$doseCount';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: _kAccent),
          onPressed: doseCount > min
              ? () => onChanged(doseCount - step)
              : null,
        ),
        const SizedBox(width: 16),
        Text(label,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: _kAccent),
          onPressed: () => onChanged(doseCount + step),
        ),
      ],
    );
  }
}

class _ExtractedMedCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExtractedMedCard(
      {required this.medicine,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name =
        medicine['name']?.toString() ?? 'Unknown Medicine';
    final type = medicine['type']?.toString() ?? 'tablet';
    final typeLabel = type[0].toUpperCase() + type.substring(1);
    final intakeTimes =
        (medicine['intakeTimes'] as List? ?? []).join(', ');
    final customTimes =
        (medicine['customTimes'] as List? ?? []).join(', ');
    final freq =
        medicine['frequency']?.toString() ?? 'Daily';
    final duration = medicine['durationDays']?.toString() ?? '?';
    final dose = medicine['doseCount'] ?? 1;
    final doseLabel =
        type == 'syrup' ? '$dose ml' : '$dose tablet(s)';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication,
                    color: _kAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: _kAccent),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
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
            _Row(Icons.category_outlined, 'Type', typeLabel),
            if (intakeTimes.isNotEmpty)
              _Row(Icons.restaurant, 'Meal Times', intakeTimes),
            if (customTimes.isNotEmpty)
              _Row(Icons.access_time, 'Custom Times', customTimes),
            _Row(Icons.repeat, 'Frequency', freq),
            _Row(Icons.timelapse, 'Duration', '$duration days'),
            _Row(Icons.medical_services_outlined, 'Dose', doseLabel),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(this.icon, this.label, this.value);

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
                    fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
class _VoiceBanner extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback? onTap;

  const _VoiceBanner({
    required this.isRecording,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String text = "Tap to record voice input";

    if (isRecording) text = "Recording... Tap to stop";
    if (isProcessing) text = "Processing voice...";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple),
        ),
        child: Row(
          children: [
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              color: Colors.purple,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}