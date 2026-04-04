import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';

// Configure with your backend laptop's IP address
const String apiBaseUrl = "http://192.168.55.176:5000/api";

class AssessmentService {
  /// Process cookie theft assessment with audio file
  /// Takes audio file path and patientId
  /// Returns cognitive assessment results
  static Future<Map<String, dynamic>> processAudioAssessment({
    required String audioFilePath,
    required String patientId,
  }) async {
    try {
      // Verify audio file exists
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        throw AssessmentException(
          message: 'Audio file not found: $audioFilePath',
        );
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$apiBaseUrl/assessment/cookie-theft"),
      );

      // Add fields
      request.fields['patientId'] = patientId;

      // Add audio file with explicit MIME type
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      // Send request
      final response = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw AssessmentException(
          message: 'Request timeout: Audio processing took too long',
        ),
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data;
      } else {
        try {
          final error = jsonDecode(responseBody);
          throw AssessmentException(
            message: error['error'] ?? 'Unknown error',
            statusCode: response.statusCode,
          );
        } catch (_) {
          throw AssessmentException(
            message: 'Server error (${response.statusCode})',
            statusCode: response.statusCode,
          );
        }
      }
    } on http.ClientException catch (e) {
      throw AssessmentException(
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      if (e is AssessmentException) rethrow;
      throw AssessmentException(
        message: 'Failed to process audio: $e',
      );
    }
  }

  /// Get assessment history for a patient
  static Future<Map<String, dynamic>> getAssessmentHistory({
    required String patientId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse("$apiBaseUrl/assessment/cookie-theft/$patientId"),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw AssessmentException(
          message: 'Failed to fetch history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is AssessmentException) rethrow;
      throw AssessmentException(
        message: 'Error fetching history: $e',
      );
    }
  }
}

class AssessmentException implements Exception {
  final String message;
  final int? statusCode;

  AssessmentException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
