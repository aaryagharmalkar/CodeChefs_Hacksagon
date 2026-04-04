import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

const String kBaseUrl = 'https://hydralite-backend.onrender.com';

class AudioSummariserService {
  // ─── Upload Audio ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadAudio(File file) async {
    final uri = Uri.parse('$kBaseUrl/upload-audio');
    final request = http.MultipartRequest('POST', uri);

    final ext = path.extension(file.path).toLowerCase().replaceAll('.', '');
    final mediaType = _mimeForExt(ext);

    _log('▶ uploadAudio()');
    _log('  file=${file.path} size=${file.lengthSync()} bytes ext=$ext mime=$mediaType');
    _log('  requestUri=$uri');

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mediaType),
    ));

    final streamed = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        _log('  uploadTimeout=90s');
        throw TimeoutException(
          'Upload timed out after 90 seconds. The backend may be cold-starting or the network may be slow.',
        );
      },
    );
    final body = await streamed.stream.bytesToString();

    _log('  responseStatus=${streamed.statusCode}');
    _log('  responseBody=$body');

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected upload response format: $body');
    }

    _log('  uploadDecoded=$decoded');
    return decoded;
  }

  // ─── Get Status ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStatus({String? audioName}) async {
    final uri = Uri.parse('$kBaseUrl/status${audioName == null ? '' : '?audio_name=$audioName'}');
    _log('▶ getStatus()');
    _log('  requestUri=$uri');

    final resp = await http.get(uri);

    _log('  responseStatus=${resp.statusCode}');
    _log('  responseBody=${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('Status check failed (${resp.statusCode}): ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected status response format: ${resp.body}');
    }
    return decoded;
  }

  // ─── Fetch Summary with Polling ────────────────────────────────────────────
  static Future<String> fetchSummary(
    String audioName, {
    int maxRetries = 20,
    Duration initialDelay = const Duration(seconds: 3),
    void Function(int attempt, int max)? onProgress,
  }) async {
    _log('▶ fetchSummary(audioName=$audioName, maxRetries=$maxRetries)');
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      onProgress?.call(attempt, maxRetries);

      try {
        final uri = Uri.parse('$kBaseUrl/summary/$audioName');
        _log('  attempt=$attempt requestUri=$uri');
        final resp = await http.get(uri);
        _log('  attempt=$attempt responseStatus=${resp.statusCode}');
        _log('  attempt=$attempt responseBody=${resp.body}');

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          // Accept string or object with 'summary' key
          if (data is String) {
            _log('  attempt=$attempt parsedSummary=string');
            return data;
          }
          if (data is Map && data['summary'] != null) {
            _log('  attempt=$attempt parsedSummary=summary-field');
            return data['summary'].toString();
          }
          if (data is Map && data['text'] != null) {
            _log('  attempt=$attempt parsedSummary=text-field');
            return data['text'].toString();
          }
          _log('  attempt=$attempt parsedSummary=json');
          return jsonEncode(data);
        }

        // 202 = still processing
        if (resp.statusCode == 202 || resp.statusCode == 404) {
          _log('  attempt=$attempt summary not ready yet (${resp.statusCode})');
          // Not ready yet, continue polling
        } else {
          throw Exception('Summary request failed (${resp.statusCode}): ${resp.body}');
        }
      } catch (e) {
        _log('  attempt=$attempt error=$e');
        if (attempt == maxRetries) rethrow;
      }

      // Exponential backoff capped at 8 s
      final wait = Duration(
        milliseconds: (initialDelay.inMilliseconds * (1 + attempt * 0.3)).clamp(
          initialDelay.inMilliseconds.toDouble(),
          8000,
        ).toInt(),
      );
      await Future.delayed(wait);
    }

    throw Exception('Audio not ready after $maxRetries attempts.');
  }

  // ─── Download PDF ──────────────────────────────────────────────────────────
  static Future<List<int>> downloadPdf(String audioName) async {
    final uri = Uri.parse('$kBaseUrl/download-pdf/$audioName');
    _log('▶ downloadPdf(audioName=$audioName)');
    _log('  requestUri=$uri');
    final resp = await http.get(uri);

    _log('  responseStatus=${resp.statusCode}');
    _log('  responseBodyLength=${resp.bodyBytes.length}');

    if (resp.statusCode != 200) {
      throw Exception('PDF download failed (${resp.statusCode})');
    }
    return resp.bodyBytes;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static String _mimeForExt(String ext) {
    const map = {
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'webm': 'audio/webm',
      'ogg': 'audio/ogg',
      'aac': 'audio/aac',
    };
    return map[ext] ?? 'audio/mpeg';
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AudioSummariserService] $message');
    }
  }
}
