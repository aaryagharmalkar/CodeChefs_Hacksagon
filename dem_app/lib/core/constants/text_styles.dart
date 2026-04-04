import 'package:flutter/material.dart';

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E),
  );
  static const TextStyle stepText = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3A86FF),
    letterSpacing: 0.5,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14, color: Color(0xFF9CA3AF), height: 1.5,
  );
  static const TextStyle timer = TextStyle(
    fontSize: 52, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E),
    fontFeatures: [FontFeature.tabularFigures()],
  );
}