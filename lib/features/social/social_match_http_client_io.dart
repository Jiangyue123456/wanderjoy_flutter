import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> postJson(
  Uri uri,
  Map<String, dynamic> body,
  Duration timeout,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Social match backend returned ${response.statusCode}: $responseBody',
        uri: uri,
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Social match response must be a JSON object.');
    }

    return decoded;
  } finally {
    client.close();
  }
}
