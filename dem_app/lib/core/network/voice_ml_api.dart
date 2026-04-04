// lib/core/network/voice_ml_api.dart
//
// Production-ready ML upload service.
// Switch _baseUrl back to the Render URL before releasing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class VoiceMlApi {
  // ── Endpoints ─────────────────────────────────────────────────────────────
  // Toggle between local dev and production:
  static const String _mlBaseUrl =
      'https://neurovoice-level1-ml.onrender.com'; // production ML
  // static const String _mlBaseUrl = 'http://192.168.29.16:10000'; // local dev

  static const String _predictEndpoint = '/predict';

  // Generous timeout to survive Render cold-starts (~30 s).
  static const Duration _mlTimeout = Duration(seconds: 90);

  // ── ML prediction ─────────────────────────────────────────────────────────

  /// Uploads [wavPath] + clinical fields, returns the parsed JSON body.
  ///
  /// Throws a plain [Exception] with a user-friendly message on any failure.
  static Future<Map<String, dynamic>> uploadWav({
    required String wavPath,
    required int ac,
    required int nth,
    required int htn,
  }) async {
    final uri = Uri.parse('$_mlBaseUrl$_predictEndpoint');

    debugPrint('➡️  ML request → $uri');
    debugPrint('🎧  Audio path  : $wavPath');
    debugPrint('🧾  Clinical    : ac=$ac  nth=$nth  htn=$htn');

    final request = http.MultipartRequest('POST', uri);

    // Audio file
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        wavPath,
        contentType: MediaType('audio', 'wav'),
      ),
    );

    // Clinical fields (all sent as strings per API contract)
    request.fields['ac'] = ac.toString();
    request.fields['nth'] = nth.toString();
    request.fields['htn'] = htn.toString();

    try {
      final streamed = await request.send().timeout(
        _mlTimeout,
        onTimeout: () => throw TimeoutException(
          'ML server did not respond within ${_mlTimeout.inSeconds} s. '
          'It may be starting up — please wait 30 seconds and try again.',
        ),
      );

      debugPrint('⬅️  HTTP status : ${streamed.statusCode}');

      final response = await http.Response.fromStream(streamed);
      debugPrint('📦  Body        : ${response.body}');

      if (response.statusCode != 200) {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        } catch (_) {}
        final msg = decoded?['message'] as String? ??
            decoded?['error'] as String? ??
            'Server error (HTTP ${response.statusCode})';
        throw Exception(msg);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response format from ML server.');
      }
      if (!decoded.containsKey('risk_score')) {
        throw Exception('Response missing required field: risk_score');
      }

      debugPrint('✅  ML result   : $decoded');
      return decoded;
    } on TimeoutException catch (e) {
      debugPrint('❌  Timeout: $e');
      throw Exception(
          e.message ?? 'Request timed out. Please try again in 30 s.');
    } on SocketException {
      debugPrint('❌  SocketException – no internet');
      throw Exception('No internet connection. Please check your network.');
    } on FormatException catch (e) {
      debugPrint('❌  JSON parse error: $e');
      throw Exception('Could not read server response. Please try again.');
    } on Exception {
      rethrow; // already user-friendly
    } catch (e) {
      debugPrint('❌  Unexpected: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }
}