import 'package:flutter/material.dart';

class FluencyIndicator extends StatelessWidget {
  final int fillerCount;
  final int wordCount;
  final bool isRecording;

  const FluencyIndicator({
    super.key,
    required this.fillerCount,
    required this.wordCount,
    required this.isRecording,
  });

  /// Calculate fillers per 100 tokens
  double get fillersPerHundred {
    if (wordCount == 0) return 0;
    return (fillerCount * 100.0) / wordCount;
  }

  /// Get fluency status (0-1)
  double get fluencyScore {
    // Lower is better; threshold is 5.0 per 100 tokens
    const threshold = 5.0;
    if (fillersPerHundred <= threshold) return 0.0;
    return (fillersPerHundred - threshold) / (threshold * 3);
  }

  Color get fluencyColor {
    if (fillersPerHundred <= 5.0) return Colors.green;
    if (fillersPerHundred <= 10.0) return Colors.orange;
    return Colors.red;
  }

  String get fluencyLabel {
    if (fillersPerHundred <= 5.0) return 'Good Fluency';
    if (fillersPerHundred <= 10.0) return 'Moderate Hesitation';
    return 'High Hesitation';
  }

  @override
  Widget build(BuildContext context) {
    if (!isRecording) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fluencyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fluencyColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fillersPerHundred > 10
                    ? Icons.pause_rounded
                    : fillersPerHundred > 5
                        ? Icons.pending_rounded
                        : Icons.check_circle_rounded,
                color: fluencyColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                fluencyLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fluencyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filled Pauses: $fillerCount',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Rate: ${fillersPerHundred.toStringAsFixed(1)}/100 words',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fluencyScore.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(fluencyColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
