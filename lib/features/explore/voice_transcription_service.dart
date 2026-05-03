import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart';

const _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
const _transcriptionModel = String.fromEnvironment(
  'OPENAI_TRANSCRIBE_MODEL',
  defaultValue: 'gpt-4o-mini-transcribe',
);

class VoiceTranscriptionService {
  const VoiceTranscriptionService({
    this.endpoint = 'https://api.openai.com/v1/audio/transcriptions',
  });

  final String endpoint;

  bool get isConfigured => _openAiApiKey.trim().isNotEmpty;

  Future<String> transcribe(File audioFile) async {
    if (!isConfigured) {
      throw const VoiceTranscriptionException(
        'Missing OPENAI_API_KEY. Run Flutter with --dart-define=OPENAI_API_KEY=...',
      );
    }

    if (!await audioFile.exists()) {
      throw const VoiceTranscriptionException('Audio file was not created.');
    }

    final request = MultipartRequest('POST', Uri.parse(endpoint))
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $_openAiApiKey'
      ..fields['model'] = _transcriptionModel
      ..fields['response_format'] = 'json'
      ..files.add(
        await MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'wanderjoy_voice.m4a',
          contentType: MediaType('audio', 'mp4'),
        ),
      );

    final response = await request.send().timeout(const Duration(seconds: 45));
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VoiceTranscriptionException(
        'Transcription failed ${response.statusCode}: $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const VoiceTranscriptionException(
        'Transcription response was not a JSON object.',
      );
    }

    final text = decoded['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const VoiceTranscriptionException(
        'I could not hear any words in that recording.',
      );
    }

    return text;
  }
}

class VoiceTranscriptionException implements Exception {
  const VoiceTranscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
