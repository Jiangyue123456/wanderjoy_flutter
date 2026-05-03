import 'dart:convert';
import 'dart:io';

import '../../shared/models/app_models.dart';

const _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
const _openAiModel = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-5.2',
);

class ExploreAgentService {
  const ExploreAgentService({
    this.endpoint = 'https://api.openai.com/v1/responses',
    this.mcpServerUrl = 'https://wanderjoyflutter.fly.dev/mcp',
  });

  final String endpoint;
  final String mcpServerUrl;

  bool get isConfigured => _openAiApiKey.trim().isNotEmpty;

  Future<ExploreAgentResponse> recommend({
    required String inputAsText,
    required String userId,
    required List<String> profileInterests,
    required String preferredIntensity,
    required String profileBio,
    double? currentLocationLat,
    double? currentLocationLng,
    String? currentLocationName,
  }) async {
    if (!isConfigured) {
      throw const ExploreAgentException(
        'Missing OPENAI_API_KEY. Run Flutter with --dart-define=OPENAI_API_KEY=...',
      );
    }

    final payload = <String, dynamic>{
      'model': _openAiModel,
      'input': [
        {
          'role': 'developer',
          'content': _exploreAgentPrompt,
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'input_as_text': inputAsText,
            'userid': userId,
            'profileinterests': profileInterests.join(', '),
            'preferredintensity': preferredIntensity,
            'profileBio': profileBio,
            'currentlocationlat': currentLocationLat,
            'currentlocationlng': currentLocationLng,
            'currentlocationname': currentLocationName,
          }),
        },
      ],
      'tools': [
        {
          'type': 'mcp',
          'server_label': 'google_maps',
          'server_description': 'Google Maps tools for real places and activities.',
          'server_url': mcpServerUrl,
          'require_approval': 'never',
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'explore_agent_output',
          'strict': true,
          'schema': _exploreAgentOutputSchema,
        },
      },
    };

    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_openAiApiKey');
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(const Duration(seconds: 45));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExploreAgentException(
          'OpenAI returned ${response.statusCode}: $responseBody',
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const ExploreAgentException('OpenAI response was not a JSON object.');
      }

      final outputText = _extractOutputText(decoded);
      final outputJson = jsonDecode(outputText);
      if (outputJson is! Map<String, dynamic>) {
        throw const ExploreAgentException('Explore Agent output was not a JSON object.');
      }

      return ExploreAgentResponse.fromJson(outputJson);
    } on ExploreAgentException {
      rethrow;
    } on Object catch (error) {
      throw ExploreAgentException('Explore Agent request failed: $error');
    } finally {
      client.close();
    }
  }

  String _extractOutputText(Map<String, dynamic> response) {
    final direct = response['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final output = response['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is! Map) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final part in content) {
          if (part is Map && part['type'] == 'output_text') {
            buffer.write(part['text'] ?? '');
          }
        }
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    throw const ExploreAgentException('Could not find output_text in OpenAI response.');
  }
}

class ExploreAgentResponse {
  const ExploreAgentResponse({
    required this.recommendedPlaces,
    required this.needsMoreInfo,
    required this.followUpQuestion,
    required this.needsConfirmation,
  });

  factory ExploreAgentResponse.fromJson(Map<String, dynamic> json) {
    final placesJson = json['recommendedPlaces'];
    return ExploreAgentResponse(
      recommendedPlaces: placesJson is List
          ? placesJson
              .whereType<Map<Object?, Object?>>()
              .map(RecommendedPlace.fromJson)
              .toList()
          : const [],
      needsMoreInfo: json['needsMoreInfo'] == true,
      followUpQuestion: json['followUpQuestion']?.toString() ?? '',
      needsConfirmation: json['needsConfirmation'] == true,
    );
  }

  final List<RecommendedPlace> recommendedPlaces;
  final bool needsMoreInfo;
  final String followUpQuestion;
  final bool needsConfirmation;
}

class RecommendedPlace {
  const RecommendedPlace({
    required this.placeName,
    required this.placeType,
    required this.googlePlaceId,
    required this.source,
    required this.mapsUri,
    required this.activitySuggestion,
    required this.latitude,
    required this.longitude,
    required this.shortReason,
    required this.suitabilityForIntensity,
    required this.matchScore,
  });

  factory RecommendedPlace.fromJson(Map<Object?, Object?> json) {
    return RecommendedPlace(
      placeName: json['placeName']?.toString() ?? '',
      placeType: json['placeType']?.toString() ?? '',
      googlePlaceId: json['googlePlaceId']?.toString() ?? '',
      source: json['source']?.toString() ?? 'google_maps',
      mapsUri: json['mapsUri']?.toString() ?? '',
      activitySuggestion: json['activitySuggestion']?.toString() ?? '',
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      shortReason: json['shortReason']?.toString() ?? '',
      suitabilityForIntensity: json['suitabilityForIntensity']?.toString() ?? '',
      matchScore: _number(json['matchScore']),
    );
  }

  final String placeName;
  final String placeType;
  final String googlePlaceId;
  final String source;
  final String mapsUri;
  final String activitySuggestion;
  final double latitude;
  final double longitude;
  final String shortReason;
  final String suitabilityForIntensity;
  final double matchScore;

  Poi toPoi() {
    return Poi(
      id: googlePlaceId.isEmpty ? placeName : googlePlaceId,
      name: placeName,
      category: _categoryFromPlaceType(placeType),
      description: activitySuggestion,
      rating: (matchScore * 5).clamp(0.0, 5.0),
      reason: shortReason,
      lat: latitude,
      lng: longitude,
      emoji: _emojiForPlaceType(placeType),
      hours: 'Google Maps result',
      googlePlaceId: googlePlaceId,
      mapsUri: mapsUri,
      placeType: placeType,
      matchScore: matchScore,
    );
  }
}

class ExploreAgentException implements Exception {
  const ExploreAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}

double _number(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

PoiCategory _categoryFromPlaceType(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('art') ||
      normalized.contains('gallery') ||
      normalized.contains('museum') ||
      normalized.contains('dance') ||
      normalized.contains('theatre') ||
      normalized.contains('theater')) {
    return PoiCategory.arts;
  }
  if (normalized.contains('park') || normalized.contains('garden')) {
    return PoiCategory.nature;
  }
  if (normalized.contains('food') ||
      normalized.contains('restaurant') ||
      normalized.contains('cafe') ||
      normalized.contains('bar')) {
    return PoiCategory.food;
  }
  if (normalized.contains('culture') || normalized.contains('historic')) {
    return PoiCategory.culture;
  }
  return PoiCategory.other;
}

String _emojiForPlaceType(String value) {
  final category = _categoryFromPlaceType(value);
  return switch (category) {
    PoiCategory.nature => 'N',
    PoiCategory.culture => 'C',
    PoiCategory.food => 'F',
    PoiCategory.arts => 'A',
    PoiCategory.other => 'O',
  };
}

const _exploreAgentPrompt = '''
You are WanderJoy's Explore Agent.

Your role is to recommend real nearby places and activities based on the user's natural-language preferences.

You must use the google_maps MCP tools to find real places before recommending any place.
Do not recommend, name, rank, or describe a real-world place unless it was returned by google_maps.
Do not invent real-time ratings, live distance, coordinates, opening hours, phone numbers, or reviews unless they are returned by google_maps.

The user message is provided inside a JSON object as input_as_text. Other fields are app state.

Required information:
- exploration location, either explicit in the user's message or provided by location state variables
- interests or an inferred exploration preference
- travelIntensity, either explicit, provided by preferredintensity, or clearly inferred from wording

Location rules:
- Location can be a city, area, landmark, address, postcode, or place mentioned in input_as_text, such as "London", "伦敦", "Tokyo Station", "near Shibuya", "E20 1LZ", or "上海静安寺".
- If input_as_text contains a location, use that as the exploration location and do not ask for coordinates.
- If both textual location and coordinates are available, prefer the textual location when the user clearly names it.
- If the user says "nearby" after mentioning a city, area, landmark, or address, interpret nearby as near that mentioned location.
- If only currentlocationlat and currentlocationlng are provided, use them for nearby search.
- Ask for location only if no textual location, no currentlocationname, and no usable coordinates are available.

Preference priority rules:
- Explicit user interests always have highest priority.
- The user's latest input_as_text has priority over saved profile fields when they conflict.
- Saved profile interests, bio, and preferredintensity are helpful background context, not hard constraints.
- If the user mentions "art", "艺术", "gallery", "museum", "exhibition", "dance", "舞蹈", "performance", "演出", "展览", "画廊", "美术馆", or similar words, the search must focus on those related places and activities.
- Do not replace explicit interests with generic categories like parks, cafes, bars, or attractions unless the user also asked for them.
- Cafes, parks, bars, and general attractions may only be included if they are clearly related to the explicit interest.

Do not require the user to use exact words like relaxed, medium, or active.
Infer travelIntensity only when the user's wording clearly implies energy level.
- relaxed: tired, exhausted, sleepy, long studying, low energy, want to chill, chill out, casual walk, quiet, slow, nearby, easy, not too much walking, "好累", "累", "随便转转", "放松", "轻松", "不想太累", "休息一下"
- medium: normal energy, balanced plan, some walking, explore a bit, "普通", "适中", "都可以", "逛逛"
- active: energetic, want adventure, lots of walking, packed day, hiking, sports, "很有精力", "想多玩点", "暴走", "挑战"

If travelIntensity is not provided by profile and cannot be clearly inferred, ask one short follow-up question instead of recommending places.
Do not default to relaxed just because the user says "nearby".

Search query rules:
- Build the google_maps query from the user's explicit location and explicit interests.
- The query must include explicit interest words when they exist.
- For art-related requests, use queries like "art galleries near [location]", "museums near [location]", "exhibitions near [location]", "creative spaces near [location]".
- For dance-related requests, use queries like "dance events near [location]", "dance studios near [location]", "performance venues near [location]", "dance classes near [location]".

Tool use requirements:
- Use google_maps to search for places matching the user's location and inferred interests.
- Prefer maps_search_places for text-based searches.
- Prefer maps_search_nearby when coordinates are available and the user asks for nearby places.
- Use maps_place_details when more detail is needed about a candidate place.
- If google_maps returns no suitable results, ask the user to adjust the area or preference.
- If google_maps is unavailable or fails, do not invent places.

Recommend 3 to 5 suitable places.

For each recommended place, include:
- placeName
- placeType
- googlePlaceId
- source: "google_maps"
- mapsUri, or an empty string if not returned by google_maps
- activitySuggestion
- latitude
- longitude
- shortReason
- suitabilityForIntensity
- matchScore from 0 to 1

If required information is missing:
- recommendedPlaces must be []
- needsMoreInfo must be true
- followUpQuestion must contain one short question
- needsConfirmation must be false

If recommendations are ready:
- recommendedPlaces must contain 3 to 5 places
- needsMoreInfo must be false
- followUpQuestion must be ""
- needsConfirmation must be true

Respond in the same language as the user's input.
Return only JSON matching the schema.
''';

const _exploreAgentOutputSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'recommendedPlaces': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'placeName': {'type': 'string'},
          'placeType': {'type': 'string'},
          'googlePlaceId': {'type': 'string'},
          'source': {
            'type': 'string',
            'enum': ['google_maps'],
          },
          'mapsUri': {'type': 'string'},
          'activitySuggestion': {'type': 'string'},
          'latitude': {'type': 'number'},
          'longitude': {'type': 'number'},
          'shortReason': {'type': 'string'},
          'suitabilityForIntensity': {
            'type': 'string',
            'enum': ['relaxed', 'medium', 'active'],
          },
          'matchScore': {
            'type': 'number',
            'minimum': 0,
            'maximum': 1,
          },
        },
        'required': [
          'placeName',
          'placeType',
          'googlePlaceId',
          'source',
          'mapsUri',
          'activitySuggestion',
          'latitude',
          'longitude',
          'shortReason',
          'suitabilityForIntensity',
          'matchScore',
        ],
      },
    },
    'needsMoreInfo': {'type': 'boolean'},
    'followUpQuestion': {'type': 'string'},
    'needsConfirmation': {'type': 'boolean'},
  },
  'required': [
    'recommendedPlaces',
    'needsMoreInfo',
    'followUpQuestion',
    'needsConfirmation',
  ],
};
