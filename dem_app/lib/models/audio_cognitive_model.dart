class AudioCognitiveResponse {
  final String transcript;
  final double dementiaProbability;
  final AudioMetrics audioMetrics;
  final CognitiveMarkers cognitiveMarkers;
  final bool isHealthySpeech;

  AudioCognitiveResponse({
    required this.transcript,
    required this.dementiaProbability,
    required this.audioMetrics,
    required this.cognitiveMarkers,
    required this.isHealthySpeech,
  });

  factory AudioCognitiveResponse.fromJson(Map<String, dynamic> json) {
    return AudioCognitiveResponse(
      transcript: json['transcript'] ?? '',
      dementiaProbability: (json['dementia_probability'] ?? 0.0).toDouble(),
      audioMetrics: AudioMetrics.fromJson(json['audio_metrics'] ?? {}),
      cognitiveMarkers: CognitiveMarkers.fromJson(json['cognitive_markers'] ?? {}),
      isHealthySpeech: json['is_healthy_speech'] ?? false,
    );
  }
}

class AudioMetrics {
  final double avgPauseDurationSeconds;
  final int pauseCount;

  AudioMetrics({
    required this.avgPauseDurationSeconds,
    required this.pauseCount,
  });

  factory AudioMetrics.fromJson(Map<String, dynamic> json) {
    return AudioMetrics(
      avgPauseDurationSeconds: (json['avg_pause_duration_seconds'] ?? 0.0).toDouble(),
      pauseCount: json['pause_count'] ?? 0,
    );
  }
}

class CognitiveMarkers {
  final double fillerRate;
  final double lexicalDiversity;
  final double avgSentenceLength;
  final double hesitationRatio;
  final double longPauseRate;

  CognitiveMarkers({
    required this.fillerRate,
    required this.lexicalDiversity,
    required this.avgSentenceLength,
    required this.hesitationRatio,
    required this.longPauseRate,
  });

  factory CognitiveMarkers.fromJson(Map<String, dynamic> json) {
    return CognitiveMarkers(
      fillerRate: (json['filler_rate'] ?? 0.0).toDouble(),
      lexicalDiversity: (json['lexical_diversity'] ?? 0.0).toDouble(),
      avgSentenceLength: (json['avg_sentence_length'] ?? 0.0).toDouble(),
      hesitationRatio: (json['hesitation_ratio'] ?? 0.0).toDouble(),
      longPauseRate: (json['long_pause_rate'] ?? 0.0).toDouble(),
    );
  }

  /// Flag concerning markers
  List<String> getFlaggedMarkers() {
    final flags = <String>[];
    if (fillerRate > 0.05) flags.add("🔴 High filler rate (${(fillerRate * 100).toStringAsFixed(1)}%)");
    if (lexicalDiversity < 0.3) flags.add("🔴 Low lexical diversity (${(lexicalDiversity * 100).toStringAsFixed(1)}%)");
    if (avgSentenceLength < 5) flags.add("🔴 Very short sentences (${avgSentenceLength.toStringAsFixed(1)} words)");
    if (hesitationRatio > 0.08) flags.add("🔴 High hesitation (${(hesitationRatio * 100).toStringAsFixed(1)}%)");
    if (longPauseRate > 0.02) flags.add("🔴 Frequent long pauses (${(longPauseRate * 100).toStringAsFixed(1)}%)");
    return flags;
  }
}
