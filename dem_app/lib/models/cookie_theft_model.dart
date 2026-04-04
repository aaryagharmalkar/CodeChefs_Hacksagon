class CookieTheftScore {
  final String rawText;
  final int nTokens;
  final int nSentences;
  final double meanSentenceLength;
  final ContentUnits contentUnits;
  final MentalState mentalState;
  final FluencyFillers fluencyFillers;
  final double lexicalDiversity;
  final PronounCohesion pronounCohesion;
  final Map<String, int> repetitions;
  final RiskAssessment? riskAssessment;
  final DateTime timestamp;

  CookieTheftScore({
    required this.rawText,
    required this.nTokens,
    required this.nSentences,
    required this.meanSentenceLength,
    required this.contentUnits,
    required this.mentalState,
    required this.fluencyFillers,
    required this.lexicalDiversity,
    required this.pronounCohesion,
    required this.repetitions,
    this.riskAssessment,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from JSON response
  factory CookieTheftScore.fromJson(Map<String, dynamic> json) {
    return CookieTheftScore(
      rawText: json['raw_text'] ?? '',
      nTokens: json['n_tokens'] ?? 0,
      nSentences: json['n_sentences'] ?? 0,
      meanSentenceLength:
          (json['mean_sentence_length_tokens'] ?? 0).toDouble(),
      contentUnits: ContentUnits.fromJson(json['content_units'] ?? {}),
      mentalState: MentalState.fromJson(json['mental_state'] ?? {}),
      fluencyFillers: FluencyFillers.fromJson(json['fluency_fillers'] ?? {}),
      lexicalDiversity: (json['lexical_diversity'] ?? 0).toDouble(),
      pronounCohesion: PronounCohesion.fromJson(json['pronoun_cohesion'] ?? {}),
      repetitions: Map<String, int>.from(json['repetitions'] ?? {}),
      riskAssessment: json['risk_assessment'] != null
          ? RiskAssessment.fromJson(json['risk_assessment'])
          : null,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'raw_text': rawText,
      'n_tokens': nTokens,
      'n_sentences': nSentences,
      'mean_sentence_length_tokens': meanSentenceLength,
      'content_units': contentUnits.toJson(),
      'mental_state': mentalState.toJson(),
      'fluency_fillers': fluencyFillers.toJson(),
      'lexical_diversity': lexicalDiversity,
      'pronoun_cohesion': pronounCohesion.toJson(),
      'repetitions': repetitions,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get overall cognitive performance score (0-100)
  int getOverallScore() {
    // Weighted scoring based on key metrics
    double score = 0;

    // Content units: 40% weight
    double cuRatio = contentUnits.presentProportion;
    score += cuRatio * 40;

    // Lexical diversity: 30% weight
    // Normalize TTR to 0-1 scale (typical range is 0.3-0.8)
    double normalizedLex = (lexicalDiversity - 0.3) / 0.5;
    normalizedLex = normalizedLex.clamp(0, 1);
    score += normalizedLex * 30;

    // Pronoun cohesion: 20% weight
    score += pronounCohesion.cohesionRatio * 20;

    // Mental state mentions: 10% weight (lower is not necessarily better)
    double mentalScore =
        (mentalState.totalMentalTerms > 0 ? 1 : 0) * 10;
    score += mentalScore;

    return score.toInt();
  }
}

class ContentUnits {
  final int expectedTotal;
  final int presentCount;
  final double presentProportion;
  final List<String> matchedItems;
  final Map<String, int> counts;

  ContentUnits({
    required this.expectedTotal,
    required this.presentCount,
    required this.presentProportion,
    required this.matchedItems,
    required this.counts,
  });

  factory ContentUnits.fromJson(Map<String, dynamic> json) {
    return ContentUnits(
      expectedTotal: json['expected_total'] ?? 0,
      presentCount: json['present_count'] ?? 0,
      presentProportion: (json['present_proportion'] ?? 0).toDouble(),
      matchedItems: List<String>.from(json['matched_items'] ?? []),
      counts: Map<String, int>.from(json['counts'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expected_total': expectedTotal,
      'present_count': presentCount,
      'present_proportion': presentProportion,
      'matched_items': matchedItems,
      'counts': counts,
    };
  }
}

class MentalState {
  final Map<String, int> countsByTerm;
  final int totalMentalTerms;

  MentalState({
    required this.countsByTerm,
    required this.totalMentalTerms,
  });

  factory MentalState.fromJson(Map<String, dynamic> json) {
    return MentalState(
      countsByTerm: Map<String, int>.from(json['counts_by_term'] ?? {}),
      totalMentalTerms: json['total_mental_terms'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'counts_by_term': countsByTerm,
      'total_mental_terms': totalMentalTerms,
    };
  }
}

class FluencyFillers {
  final Map<String, int> countsByFiller;
  final int totalFillers;

  FluencyFillers({
    required this.countsByFiller,
    required this.totalFillers,
  });

  factory FluencyFillers.fromJson(Map<String, dynamic> json) {
    return FluencyFillers(
      countsByFiller: Map<String, int>.from(json['counts_by_filler'] ?? {}),
      totalFillers: json['total_fillers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'counts_by_filler': countsByFiller,
      'total_fillers': totalFillers,
    };
  }
}

class PronounCohesion {
  final int pronounCount;
  final int pronounsWithPriorAntecedent;
  final double cohesionRatio;
  final Map<String, int> breakdown;

  PronounCohesion({
    required this.pronounCount,
    required this.pronounsWithPriorAntecedent,
    required this.cohesionRatio,
    required this.breakdown,
  });

  factory PronounCohesion.fromJson(Map<String, dynamic> json) {
    return PronounCohesion(
      pronounCount: json['pronoun_count'] ?? 0,
      pronounsWithPriorAntecedent: json['pronouns_with_prior_antecedent'] ?? 0,
      cohesionRatio: (json['cohesion_ratio'] ?? 0).toDouble(),
      breakdown: Map<String, int>.from(json['breakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pronoun_count': pronounCount,
      'pronouns_with_prior_antecedent': pronounsWithPriorAntecedent,
      'cohesion_ratio': cohesionRatio,
      'breakdown': breakdown,
    };
  }
}

class RiskAssessment {
  final String riskLabel;
  final double riskScore;
  final List<String> reasons;
  final Map<String, dynamic> metrics;

  RiskAssessment({
    required this.riskLabel,
    required this.riskScore,
    required this.reasons,
    required this.metrics,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      riskLabel: json['risk_label'] ?? 'Unknown',
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      reasons: List<String>.from(json['reasons'] ?? []),
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'risk_label': riskLabel,
      'risk_score': riskScore,
      'reasons': reasons,
      'metrics': metrics,
    };
  }

  /// Get color based on risk level
  String getRiskColorHex() {
    if (riskScore >= 0.6) {
      return '#FF4444'; // Red
    } else if (riskScore >= 0.3) {
      return '#FFA500'; // Orange
    } else {
      return '#44DD44'; // Green
    }
  }
}

