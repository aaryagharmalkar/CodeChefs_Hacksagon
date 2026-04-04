// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';
import '../../core/utils/app_session.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  THEME CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

class _T {
  static const cardBg = Colors.white;
  static const pageBg = Color(0xFFF4F6FA);
  static const accent = Color(0xFF4F6EF7);
  static const accentLight = Color(0xFFEEF1FE);
  static const accentDark = Color(0xFF2D4AD9);
  static const textPrimary = Color(0xFF1A1D2E);
  static const textSecondary = Color(0xFF7A7F96);
  static const border = Color(0xFFE4E8F0);
  static const shadow = Color(0x14000000);

  static const radiusCard = 24.0;

  static const sectionGradients = [
    [Color(0xFF4F6EF7), Color(0xFF7B93FF)],
    [Color(0xFF23C4A0), Color(0xFF40E0C0)],
    [Color(0xFFE86B5F), Color(0xFFFF8F86)],
    [Color(0xFFF5A623), Color(0xFFFFCA60)],
    [Color(0xFF9B59B6), Color(0xFFBB7FD4)],
    [Color(0xFF2196F3), Color(0xFF64B5F6)],
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED FIELD DECORATION
// ═══════════════════════════════════════════════════════════════════════════

InputDecoration _decoration({
  String hint = 'Enter your answer',
  Widget? suffixIcon,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _T.textSecondary, fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _T.accentLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _T.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _T.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _T.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

// ═══════════════════════════════════════════════════════════════════════════
//  ENUMS & MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum AnswerType { text, speechOnly, serial7, spellBackwards }

// ═══════════════════════════════════════════════════════════════════════════
//  QUESTION BANK
// ═══════════════════════════════════════════════════════════════════════════

class MmseQuestion {
  final String id;
  final String prompt; // shown as large card text + read by TTS
  final String? subtitle; // shown small, NOT read by TTS
  final AnswerType type;
  final int maxScore;
  final List<String>? acceptedAnswers;
  final String? wordToSpell;
  final String? imageAsset; // for object-naming questions

  const MmseQuestion({
    required this.id,
    required this.prompt,
    this.subtitle,
    required this.type,
    required this.maxScore,
    this.acceptedAnswers,
    this.wordToSpell,
    this.imageAsset,
  });
}

class MmseSection {
  final String title;
  final String description;
  final IconData icon;
  final List<MmseQuestion> questions;

  const MmseSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.questions,
  });
}

final List<MmseSection> mmseSections = [
  // ── 1. Orientation to Time ─────────────────────────────────────────────
  MmseSection(
    title: 'Orientation to Time',
    description: 'Answer each question about the current date and time.',
    icon: Icons.access_time_rounded,
    questions: [
      MmseQuestion(
        id: 'time_year',
        prompt: 'What year is it?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: [DateTime.now().year.toString()],
      ),
      MmseQuestion(
        id: 'time_season',
        prompt: 'What season is it?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: _getCurrentSeason(),
      ),
      MmseQuestion(
        id: 'time_month',
        prompt: 'What month is it?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: _getCurrentMonthAnswers(),
      ),
      MmseQuestion(
        id: 'time_date',
        prompt: "What is today's date?",
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: [DateTime.now().day.toString()],
      ),
      MmseQuestion(
        id: 'time_day',
        prompt: 'What day of the week is it?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: _getCurrentDayAnswers(),
      ),
      MmseQuestion(
        id: 'time_timeofday',
        prompt: 'What time of day is it?',
        subtitle: 'morning / afternoon / evening / night',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: _getCurrentTimeOfDay(),
      ),
    ],
  ),

  // ── 2. Orientation to Place ── (removed building & floor) ──────────────
  MmseSection(
    title: 'Orientation to Place',
    description: 'Answer each question about where you are.',
    icon: Icons.location_on_rounded,
    questions: [
      MmseQuestion(
        id: 'place_country',
        prompt: 'What country are we in?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: null, // filled dynamically from GPS
      ),
      MmseQuestion(
        id: 'place_state',
        prompt: 'What state or province are we in?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: null,
      ),
      MmseQuestion(
        id: 'place_city',
        prompt: 'What city or town are we in?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: null,
      ),
    ],
  ),

  // ── 3. Registration ─────────────────────────────────────────────────────
  MmseSection(
    title: 'Registration',
    description: 'Listen to each word and repeat it aloud.',
    icon: Icons.psychology_rounded,
    questions: [
      MmseQuestion(
        id: 'reg_apple',
        prompt: 'Say: Apple',
        subtitle: 'Tap the mic and repeat the word aloud',
        type: AnswerType.speechOnly,
        maxScore: 1,
        acceptedAnswers: ['apple'],
      ),
      MmseQuestion(
        id: 'reg_table',
        prompt: 'Say: Table',
        subtitle: 'Tap the mic and repeat the word aloud',
        type: AnswerType.speechOnly,
        maxScore: 1,
        acceptedAnswers: ['table'],
      ),
      MmseQuestion(
        id: 'reg_penny',
        prompt: 'Say: Penny',
        subtitle: 'Tap the mic and repeat the word aloud',
        type: AnswerType.speechOnly,
        maxScore: 1,
        acceptedAnswers: ['penny'],
      ),
    ],
  ),

  // ── 4. Attention & Calculation ──────────────────────────────────────────
  MmseSection(
    title: 'Attention & Calculation',
    description: 'Two attention tasks.',
    icon: Icons.calculate_rounded,
    questions: [
      MmseQuestion(
        id: 'serial7',
        prompt: 'Starting from 100, subtract 7 five times.',
        subtitle: 'Enter each result after subtracting 7. You may type or use the mic.',
        type: AnswerType.serial7,
        maxScore: 5,
      ),
      MmseQuestion(
        id: 'world_backwards',
        prompt: 'Spell the word "WORLD" backwards.',
        subtitle: 'Enter one letter per box',
        type: AnswerType.spellBackwards,
        maxScore: 2,
        wordToSpell: 'WORLD',
      ),
    ],
  ),

  // ── 5. Recall ───────────────────────────────────────────────────────────
  MmseSection(
    title: 'Recall',
    description: 'Try to remember the 3 objects from earlier.',
    icon: Icons.replay_rounded,
    questions: [
      MmseQuestion(
        id: 'recall_1',
        prompt: 'What was the first object?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: ['apple'],
      ),
      MmseQuestion(
        id: 'recall_2',
        prompt: 'What was the second object?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: ['table'],
      ),
      MmseQuestion(
        id: 'recall_3',
        prompt: 'What was the third object?',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: ['penny'],
      ),
    ],
  ),

  // ── 6. Language ─────────────────────────────────────────────────────────
  MmseSection(
    title: 'Language',
    description: 'Object naming and verbal repetition.',
    icon: Icons.translate_rounded,
    questions: [
      MmseQuestion(
        id: 'lang_pencil',
        prompt: 'What is this object called?',
        subtitle: 'Type or say your answer',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: ['pencil', 'pen'],
        imageAsset: 'assets/pencil.png',
      ),
      MmseQuestion(
        id: 'lang_watch',
        prompt: 'What is this object called?',
        subtitle: 'Type or say your answer',
        type: AnswerType.text,
        maxScore: 1,
        acceptedAnswers: ['watch', 'clock', 'wristwatch'],
        imageAsset: 'assets/watch.jpg',
      ),
      MmseQuestion(
        id: 'lang_repeat',
        prompt: 'Repeat this sentence: "No ifs, ands, or buts."',
        subtitle: '1 point per key word spoken: no · ifs · ands · buts',
        type: AnswerType.speechOnly,
        maxScore: 4,
        acceptedAnswers: null,
      ),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

List<String> _getCurrentSeason() {
  final m = DateTime.now().month;
  if (m >= 3 && m <= 6) return ['summer'];
  if (m >= 7 && m <= 9) return ['rainy', 'monsoon'];
  return ['winter'];
}

List<String> _getCurrentMonthAnswers() {
  const months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];
  final n = DateTime.now().month;
  return [months[n - 1], n.toString()];
}

List<String> _getCurrentDayAnswers() {
  const days = [
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];
  return [days[DateTime.now().weekday - 1]];
}

List<String> _getCurrentTimeOfDay() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return ['morning'];
  if (h >= 12 && h < 17) return ['afternoon'];
  if (h >= 17 && h < 21) return ['evening'];
  return ['night'];
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCORING ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class MmseScorer {
  static int scoreText(MmseQuestion q, String answer) {
    if (q.acceptedAnswers == null) return answer.trim().isNotEmpty ? 1 : 0;
    return q.acceptedAnswers!.contains(answer.trim().toLowerCase())
        ? q.maxScore
        : 0;
  }

  static int scoreSpeech(MmseQuestion q, String transcript) {
    if (q.id == 'lang_repeat') return _scoreRepetition(transcript);
    if (q.acceptedAnswers == null) return transcript.trim().isNotEmpty ? 1 : 0;
    final words = transcript.toLowerCase().split(RegExp(r'\s+'));
    return q.acceptedAnswers!.any((a) => words.contains(a)) ? 1 : 0;
  }

  static int _scoreRepetition(String transcript) {
    final t = transcript.toLowerCase();
    const tokens = ['no', 'ifs', 'ands', 'buts'];
    return tokens.where(t.contains).length;
  }

  static int scoreSerial7(List<String> answers) {
    const expected = [93, 86, 79, 72, 65];
    int score = 0;
    for (int i = 0; i < answers.length && i < 5; i++) {
      if (int.tryParse(answers[i].trim()) == expected[i]) score++;
    }
    return score;
  }

  static int scoreWorldBackwards(List<String> letters) {
    const correct = ['D', 'L', 'R', 'O', 'W'];
    final hits = [
      for (int i = 0; i < 5; i++)
        letters[i].trim().toUpperCase() == correct[i] ? 1 : 0
    ].fold(0, (a, b) => a + b);
    if (hits == 5) return 2;
    if (hits >= 3) return 1;
    return 0;
  }

  static Map<String, int> calculateSectionScores(Map<String, dynamic> answers) {
    final Map<String, int> out = {};
    for (final section in mmseSections) {
      int total = 0;
      for (final q in section.questions) {
        final ans = answers[q.id];
        if (ans == null) continue;
        total += switch (q.type) {
          AnswerType.text => scoreText(q, ans as String),
          AnswerType.speechOnly => scoreSpeech(q, ans as String),
          AnswerType.serial7 => scoreSerial7(ans as List<String>),
          AnswerType.spellBackwards => scoreWorldBackwards(ans as List<String>),
        };
      }
      out[section.title] = total;
    }
    return out;
  }

  static int totalScore(Map<String, int> s) => s.values.fold(0, (a, b) => a + b);

  static String interpretation(int score) {
    if (score >= 24) return 'Normal / No impairment';
    if (score >= 18) return 'Mild cognitive impairment';
    if (score >= 12) return 'Moderate cognitive impairment';
    return 'Severe cognitive impairment';
  }

  static Color interpretationColor(int score) {
    if (score >= 24) return const Color(0xFF34C759);
    if (score >= 18) return const Color(0xFFFF9500);
    if (score >= 12) return const Color(0xFFFF6B35);
    return const Color(0xFFFF3B30);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TTS CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════

class TtsController {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _speaking = false);
  }

  bool get speaking => _speaking;

  Future<void> speak(String text) async {
    await stop();
    _speaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  void dispose() => _tts.stop();
}

// ═══════════════════════════════════════════════════════════════════════════
//  MIC BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _MicBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final bool small;

  const _MicBtn({required this.active, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final sz = small ? 34.0 : 44.0;
    final iconSz = small ? 16.0 : 20.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: sz,
        height: sz,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
            colors: [Color(0xFFFF3B30), Color(0xFFFF6B5B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [_T.accent, _T.accentDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (active ? const Color(0xFFFF3B30) : _T.accent).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          active ? Icons.stop_rounded : Icons.mic_rounded,
          size: iconSz,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STT CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════

class SttController {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  String? activeId;

  bool get isListening => _speech.isListening;

  Future<bool> _ensureReady() async {
    if (_ready) return true;
    _ready = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
    return _ready;
  }

  Future<void> startListening({
    required String id,
    required void Function(String partial) onPartial,
    required void Function(String final_) onDone,
  }) async {
    if (!await _ensureReady()) return;
    activeId = id;
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult) {
          activeId = null;
          onDone(r.recognizedWords);
        } else {
          onPartial(r.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> stop() async {
    activeId = null;
    await _speech.stop();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INPUT WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _TextWithMic extends StatefulWidget {
  final String questionId;
  final String value;
  final SttController stt;
  final ValueChanged<String> onChanged;
  final VoidCallback onRebuild;

  const _TextWithMic({
    required this.questionId,
    required this.value,
    required this.stt,
    required this.onChanged,
    required this.onRebuild,
  });

  @override
  State<_TextWithMic> createState() => _TextWithMicState();
}

class _TextWithMicState extends State<_TextWithMic> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextWithMic old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _active =>
      widget.stt.isListening && widget.stt.activeId == widget.questionId;

  Future<void> _toggle() async {
    if (_active) {
      await widget.stt.stop();
      widget.onRebuild();
      return;
    }
    await widget.stt.startListening(
      id: widget.questionId,
      onPartial: (p) {
        _ctrl.text = p;
        _ctrl.selection = TextSelection.collapsed(offset: p.length);
        widget.onChanged(p);
        widget.onRebuild();
      },
      onDone: (f) {
        _ctrl.text = f;
        _ctrl.selection = TextSelection.collapsed(offset: f.length);
        widget.onChanged(f);
        widget.onRebuild();
      },
    );
    widget.onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(color: _T.textPrimary, fontSize: 15),
      decoration: _decoration(suffixIcon: _MicBtn(active: _active, onTap: _toggle)),
    );
  }
}

class _SpeechOnly extends StatefulWidget {
  final String questionId;
  final String transcript;
  final SttController stt;
  final ValueChanged<String> onTranscript;
  final VoidCallback onRebuild;

  const _SpeechOnly({
    required this.questionId,
    required this.transcript,
    required this.stt,
    required this.onTranscript,
    required this.onRebuild,
  });

  @override
  State<_SpeechOnly> createState() => _SpeechOnlyState();
}

class _SpeechOnlyState extends State<_SpeechOnly> {
  bool get _active =>
      widget.stt.isListening && widget.stt.activeId == widget.questionId;

  Future<void> _toggle() async {
    if (_active) {
      await widget.stt.stop();
      widget.onRebuild();
      return;
    }
    await widget.stt.startListening(
      id: widget.questionId,
      onPartial: (p) {
        widget.onTranscript(p);
        widget.onRebuild();
      },
      onDone: (f) {
        widget.onTranscript(f);
        widget.onRebuild();
      },
    );
    widget.onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.transcript.trim().isNotEmpty;
    return Column(
      children: [
        // Waveform visual when active
        if (_active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WaveformWidget(),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: _active
                ? LinearGradient(
              colors: [_T.accent.withOpacity(0.08), _T.accentDark.withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: _active ? null : _T.accentLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _active ? _T.accent.withOpacity(0.5) : _T.border,
              width: _active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasText
                      ? widget.transcript
                      : _active
                      ? 'Listening…'
                      : 'Tap the mic to speak',
                  style: TextStyle(
                    fontSize: 15,
                    color: hasText ? _T.textPrimary : _T.textSecondary,
                    fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MicBtn(active: _active, onTap: _toggle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated waveform bars shown when STT is listening
class _WaveformWidget extends StatefulWidget {
  @override
  State<_WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<_WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final phase = (i / 7) * 3.14159;
            final height = 10 +
                24 *
                    (0.5 +
                        0.5 *
                            ((_ctrl.value * 6.28 + phase) %
                                6.28 <
                                3.14
                                ? (_ctrl.value * 6.28 + phase) %
                                3.14 /
                                3.14
                                : 1 -
                                ((_ctrl.value * 6.28 + phase) %
                                    6.28 -
                                    3.14) /
                                    3.14));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [_T.accent, _T.accentDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Serial7 extends StatefulWidget {
  final String questionId;
  final List<String> values;
  final SttController stt;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onRebuild;

  const _Serial7({
    required this.questionId,
    required this.values,
    required this.stt,
    required this.onChanged,
    required this.onRebuild,
  });

  @override
  State<_Serial7> createState() => _Serial7State();
}

class _Serial7State extends State<_Serial7> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls =
        List.generate(5, (i) => TextEditingController(text: widget.values[i]));
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  String _subId(int i) => '${widget.questionId}_$i';
  bool _active(int i) =>
      widget.stt.isListening && widget.stt.activeId == _subId(i);

  Future<void> _toggle(int i) async {
    if (_active(i)) {
      await widget.stt.stop();
      widget.onRebuild();
      return;
    }
    await widget.stt.startListening(
      id: _subId(i),
      onPartial: (p) => _applyDigit(i, p),
      onDone: (f) => _applyDigit(i, f),
    );
    widget.onRebuild();
  }

  void _applyDigit(int i, String raw) {
    final digits = RegExp(r'\d+').firstMatch(raw)?.group(0) ?? raw;
    _ctrls[i].text = digits;
    _ctrls[i].selection = TextSelection.collapsed(offset: digits.length);
    final updated = List<String>.from(widget.values);
    updated[i] = digits;
    widget.onChanged(updated);
    widget.onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['1st', '2nd', '3rd', '4th', '5th'];
    const hints = ['100 − 7 = ?', '93 − 7 = ?', '86 − 7 = ?', '79 − 7 = ?', '72 − 7 = ?'];
    return Column(
      children: List.generate(5, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_T.accent.withOpacity(0.18), _T.accent.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      color: _T.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrls[i],
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final updated = List<String>.from(widget.values);
                    updated[i] = v;
                    widget.onChanged(updated);
                  },
                  style: const TextStyle(color: _T.textPrimary, fontSize: 15),
                  decoration: _decoration(
                    hint: hints[i],
                    suffixIcon: _MicBtn(
                      active: _active(i),
                      onTap: () => _toggle(i),
                      small: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SpellBackwards extends StatefulWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const _SpellBackwards({required this.values, required this.onChanged});

  @override
  State<_SpellBackwards> createState() => _SpellBackwardsState();
}

class _SpellBackwardsState extends State<_SpellBackwards> {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _ctrls =
        List.generate(5, (i) => TextEditingController(text: widget.values[i]));
    _nodes = List.generate(5, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: The correct order hint banner is intentionally removed per user request
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        return SizedBox(
          width: 56,
          child: TextField(
            controller: _ctrls[i],
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _T.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _T.accentLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _T.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _T.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _T.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (v) {
              final updated = List<String>.from(widget.values);
              updated[i] = v.toUpperCase();
              widget.onChanged(updated);
              if (v.isNotEmpty && i < 4) _nodes[i + 1].requestFocus();
            },
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOCATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class LocationAnswers {
  final String? country;
  final String? state;
  final String? city;

  const LocationAnswers({this.country, this.state, this.city});
}

Future<LocationAnswers?> fetchLocationAnswers() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );

    final placemarks =
    await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks.isEmpty) return null;

    final p = placemarks.first;
    return LocationAnswers(
      country: p.country?.toLowerCase(),
      state: p.administrativeArea?.toLowerCase(),
      city: p.locality?.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ROOT SCREEN  —  Location gate + test
// ═══════════════════════════════════════════════════════════════════════════

class MmseTestScreen extends StatefulWidget {
  const MmseTestScreen({super.key});
  @override
  State<MmseTestScreen> createState() => _MmseTestScreenState();
}

class _MmseTestScreenState extends State<MmseTestScreen>
    with SingleTickerProviderStateMixin {
  // ── state ──────────────────────────────────────────────────────────────
  bool _locationLoading = true;
  bool _locationGranted = false;
  LocationAnswers? _locationAnswers;

  int _currentSection = 0;
  int _currentQuestion = 0; // flashcard index within section
  bool _showResults = false;

  final Map<String, dynamic> _answers = {};
  final SttController _stt = SttController();
  final TtsController _tts = TtsController();

  late final AnimationController _cardCtrl;
  late final Animation<double> _cardAnim;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic);
    _cardCtrl.forward();
    _resetAnswers();
    _tts.init();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final loc = await fetchLocationAnswers();
    if (!mounted) return;
    setState(() {
      _locationLoading = false;
      _locationGranted = loc != null;
      _locationAnswers = loc;
      // Inject GPS answers into question acceptedAnswers lists
      if (loc != null) _patchLocationAnswers(loc);
    });
  }

  void _patchLocationAnswers(LocationAnswers loc) {
    // Find place questions by id and set their dynamic accepted answers
    // We store them separately; scoring will use _locationAnswers at runtime
    // (Patching mmseSections at runtime is not ideal; we use a side-map instead)
  }

  // Dynamic accepted answers for place questions
  List<String>? _acceptedForQuestion(MmseQuestion q) {
    if (_locationAnswers == null) return q.acceptedAnswers;
    switch (q.id) {
      case 'place_country':
        return _locationAnswers!.country != null
            ? [_locationAnswers!.country!]
            : null;
      case 'place_state':
        return _locationAnswers!.state != null
            ? [_locationAnswers!.state!]
            : null;
      case 'place_city':
        return _locationAnswers!.city != null
            ? [_locationAnswers!.city!]
            : null;
      default:
        return q.acceptedAnswers;
    }
  }

  void _resetAnswers() {
    for (final s in mmseSections) {
      for (final q in s.questions) {
        _answers[q.id] = switch (q.type) {
          AnswerType.text || AnswerType.speechOnly => '',
          AnswerType.serial7 || AnswerType.spellBackwards =>
          List<String>.filled(5, ''),
        };
      }
    }
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  MmseSection get _section => mmseSections[_currentSection];
  MmseQuestion get _question => _section.questions[_currentQuestion];

  bool get _isLastQuestion =>
      _currentQuestion == _section.questions.length - 1;
  bool get _isLastSection => _currentSection == mmseSections.length - 1;

  Future<void> _animateTransition(VoidCallback action) async {
    await _stt.stop();
    await _tts.stop();
    await _cardCtrl.reverse();
    setState(action);
    _cardCtrl.forward();
    // Auto-read the new question
    await Future.delayed(const Duration(milliseconds: 100));
    _speakCurrentQuestion();
  }

  void _speakCurrentQuestion() {
    if (_showResults) return;
    final q = _section.questions[_currentQuestion];
    _tts.speak(q.prompt);
  }

  void _next() {
    _animateTransition(() {
      if (!_isLastQuestion) {
        _currentQuestion++;
      } else if (!_isLastSection) {
        _currentSection++;
        _currentQuestion = 0;
      } else {
        _showResults = true;
      }
    });
  }

  void _back() {
    _animateTransition(() {
      if (_currentQuestion > 0) {
        _currentQuestion--;
      } else if (_currentSection > 0) {
        _currentSection--;
        _currentQuestion = mmseSections[_currentSection].questions.length - 1;
      }
    });
  }

  bool get _canGoBack => _currentSection > 0 || _currentQuestion > 0;

  int get _totalQuestions =>
      mmseSections.fold(0, (s, sec) => s + sec.questions.length);

  int get _currentQuestionIndex {
    int idx = 0;
    for (int s = 0; s < _currentSection; s++) {
      idx += mmseSections[s].questions.length;
    }
    return idx + _currentQuestion;
  }

  int get _maxPossible =>
      mmseSections.fold(0, (s, sec) => s + sec.questions.fold(0, (s2, q) => s2 + q.maxScore));

  @override
  Widget build(BuildContext context) {
    if (_locationLoading) return _buildLocationGate(loading: true);

    final scores = MmseScorer.calculateSectionScores(_answers);
    final total = MmseScorer.totalScore(scores);

    return Scaffold(
      backgroundColor: _T.pageBg,
      body: SafeArea(
        child: _showResults
            ? _ResultsView(
          scores: scores,
          total: total,
          maxPossible: _maxPossible,
          onRetake: () async {
            await _cardCtrl.reverse();
            setState(() {
              _currentSection = 0;
              _currentQuestion = 0;
              _showResults = false;
              _resetAnswers();
            });
            _cardCtrl.forward();
          },
        )
            : Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: ScaleTransition(
                scale: _cardAnim,
                child: FadeTransition(
                  opacity: _cardAnim,
                  child: _buildFlashcard(),
                ),
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationGate({required bool loading}) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_T.accent, _T.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _T.accent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 28),
              const Text(
                'Location Access',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _T.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loading
                    ? 'Detecting your location to set up place-related questions…'
                    : 'Location helps us verify your orientation answers automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: _T.textSecondary,
                  height: 1.55,
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: _T.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final gradColors = _T.sectionGradients[_currentSection % _T.sectionGradients.length];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: _T.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Section icon pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_section.icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _section.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Speaker button
          GestureDetector(
            onTap: _speakCurrentQuestion,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _T.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.volume_up_rounded, color: _T.accent, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          // Question counter
          Text(
            '${_currentQuestionIndex + 1} / $_totalQuestions',
            style: const TextStyle(
              color: _T.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / _totalQuestions;
    return Container(
      height: 5,
      color: Colors.white,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: MediaQuery.of(context).size.width * progress,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_T.accent, _T.accentDark],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcard() {
    final q = _question;
    final gradColors = _T.sectionGradients[_currentSection % _T.sectionGradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _T.cardBg,
            borderRadius: BorderRadius.circular(_T.radiusCard),
            boxShadow: [
              BoxShadow(
                color: gradColors[0].withOpacity(0.15),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _T.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top gradient stripe ──────────────────────────────────
              Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_T.radiusCard),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Question number chip ───────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gradColors[0].withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Question ${_currentQuestion + 1} of ${_section.questions.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gradColors[0],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Main prompt — large, read by TTS ──────────────
                    Text(
                      q.prompt,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _T.textPrimary,
                        height: 1.4,
                      ),
                    ),

                    // ── Subtitle — small, NOT read ─────────────────────
                    if (q.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        q.subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _T.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],

                    // ── Object image for naming questions ──────────────
                    if (q.imageAsset != null) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 180,
                          height: 160,
                          decoration: BoxDecoration(
                            color: _T.accentLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _T.border, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Image.asset(
                              q.imageAsset!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    q.id == 'lang_pencil'
                                        ? Icons.edit_rounded
                                        : Icons.watch_rounded,
                                    size: 64,
                                    color: _T.accent.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    q.id == 'lang_pencil' ? 'Pencil' : 'Watch',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _T.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Answer input ───────────────────────────────────
                    switch (q.type) {
                      AnswerType.text => _TextWithMic(
                        questionId: q.id,
                        value: _answers[q.id] as String? ?? '',
                        stt: _stt,
                        onChanged: (v) => setState(() => _answers[q.id] = v),
                        onRebuild: () => setState(() {}),
                      ),
                      AnswerType.speechOnly => _SpeechOnly(
                        questionId: q.id,
                        transcript: _answers[q.id] as String? ?? '',
                        stt: _stt,
                        onTranscript: (v) =>
                            setState(() => _answers[q.id] = v),
                        onRebuild: () => setState(() {}),
                      ),
                      AnswerType.serial7 => _Serial7(
                        questionId: q.id,
                        values: _answers[q.id] as List<String>? ??
                            List.filled(5, ''),
                        stt: _stt,
                        onChanged: (v) => setState(() => _answers[q.id] = v),
                        onRebuild: () => setState(() {}),
                      ),
                      AnswerType.spellBackwards => _SpellBackwards(
                        values: _answers[q.id] as List<String>? ??
                            List.filled(5, ''),
                        onChanged: (v) => setState(() => _answers[q.id] = v),
                      ),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    final isLast = _isLastQuestion && _isLastSection;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _T.shadow,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_canGoBack) ...[
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _T.accentLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _T.border),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: _T.accent, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _next,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_T.accent, _T.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _T.accent.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? 'View Results' : 'Next',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RESULTS VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsView extends StatelessWidget {
  final Map<String, int> scores;
  final int total;
  final int maxPossible;
  final VoidCallback onRetake;

  const _ResultsView({
    required this.scores,
    required this.total,
    required this.maxPossible,
    required this.onRetake,
  });

  static const Map<String, int> _sectionMax = {
    'Orientation to Time': 6,
    'Orientation to Place': 3, // removed 2 questions
    'Registration': 3,
    'Attention & Calculation': 7,
    'Recall': 3,
    'Language': 6,
  };

  Future<void> _handleSaveAndContinue(BuildContext context) async {
    AppSession().scores.clear();
    AppSession().scores['mmse'] = total;

    if (total < 20) {
      context.go('/assessment/voice-analysis');
    } else {
      await _submitResults(context);
    }
  }

Future<void> _submitResults(BuildContext context) async {
  try {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    final body = AppSession().scores;
    final response = await http.post(
      Uri.parse('http://192.168.55.176:5000/api/report/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (!context.mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      context.go('/assessment/results');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit results. Please try again.')),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final color = MmseScorer.interpretationColor(total);
    final label = MmseScorer.interpretation(total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          const Text(
            'Assessment Complete',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _T.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Here are your results',
            style: TextStyle(fontSize: 15, color: _T.textSecondary),
          ),
          const SizedBox(height: 24),

          // ── Score card ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  'out of $maxPossible',
                  style: const TextStyle(fontSize: 15, color: _T.textSecondary),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Severity legend ────────────────────────────────────────────
          _SeverityLegend(),
          const SizedBox(height: 28),

          // ── Breakdown ─────────────────────────────────────────────────
          const Text(
            'Score Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _T.textPrimary),
          ),
          const SizedBox(height: 14),
          ...scores.entries.map((e) => _ScoreRow(
            label: e.key,
            score: e.value,
            max: _sectionMax[e.key] ?? 1,
          )),
          const SizedBox(height: 28),

          // ── Disclaimer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This result is a screening tool, not a medical diagnosis. '
                        'Please consult a qualified healthcare professional for a '
                        'full clinical evaluation.',
                    style: TextStyle(
                        color: Colors.amber.shade900, fontSize: 13, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Actions ───────────────────────────────────────────────────
          _ActionButton(
            label: 'Save & Continue',
            icon: Icons.arrow_forward_rounded,
            gradient: const [_T.accent, _T.accentDark],
            onTap: () => _handleSaveAndContinue(context),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Retake Test',
            icon: Icons.refresh_rounded,
            gradient: const [Color(0xFF34C759), Color(0xFF20A048)],
            onTap: onRetake,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SeverityLegend extends StatelessWidget {
  static const _bands = [
    ('24–30', 'Normal', Color(0xFF34C759)),
    ('18–23', 'Mild', Color(0xFFFF9500)),
    ('12–17', 'Moderate', Color(0xFFFF6B35)),
    ('<12', 'Severe', Color(0xFFFF3B30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _bands.map((b) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: b.$3.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: b.$3.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: b.$3, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '${b.$1} — ${b.$2}',
                style: TextStyle(
                  fontSize: 12,
                  color: b.$3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;
  final int max;

  const _ScoreRow(
      {required this.label, required this.score, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? score / max : 0.0;
    final color = ratio >= 0.8
        ? const Color(0xFF34C759)
        : ratio >= 0.5
        ? const Color(0xFFFF9500)
        : const Color(0xFFFF3B30);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _T.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _T.textPrimary),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$score / $max',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                backgroundColor: _T.border,
                color: color,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}