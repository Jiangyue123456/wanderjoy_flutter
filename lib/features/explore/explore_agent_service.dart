import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../shared/models/app_models.dart';

const _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
const _openAiModel = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-5.2',
);
const _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class ExploreAgentService {
  const ExploreAgentService({
    this.endpoint = 'https://api.openai.com/v1/responses',
    this.mcpServerUrl = 'https://wanderjoyflutter.fly.dev/mcp',
  });

  final String endpoint;
  final String mcpServerUrl;

  bool get isConfigured => _openAiApiKey.trim().isNotEmpty;

  Future<Poi> fetchGooglePlaceDetails(Poi poi) async {
    final apiKey = _googleMapsApiKey.trim();
    final placeId = poi.googlePlaceId.trim().isEmpty
        ? poi.id.trim()
        : poi.googlePlaceId.trim();
    if (apiKey.isEmpty || placeId.isEmpty) {
      return poi;
    }

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields':
          'name,rating,user_ratings_total,opening_hours,photos,reviews,url,website,formatted_phone_number',
      'key': apiKey,
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return poi;
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'OK') {
        return poi;
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        return poi;
      }

      final openingHoursJson = result['opening_hours'];
      final weekdayText = openingHoursJson is Map
          ? openingHoursJson['weekday_text']
          : null;
      final openingHours = weekdayText is List
          ? weekdayText.map((item) => item.toString()).toList()
          : const <String>[];
      final isOpenNow = openingHoursJson is Map
          ? openingHoursJson['open_now'] as bool?
          : null;

      final photosJson = result['photos'];
      final photoUrls = photosJson is List
          ? photosJson
              .whereType<Map>()
              .map((photo) => photo['photo_reference']?.toString() ?? '')
              .where((reference) => reference.isNotEmpty)
              .take(4)
              .map(
                (reference) => Uri.https(
                  'maps.googleapis.com',
                  '/maps/api/place/photo',
                  {
                    'maxwidth': '700',
                    'photo_reference': reference,
                    'key': apiKey,
                  },
                ).toString(),
              )
              .toList()
          : const <String>[];

      final reviewsJson = result['reviews'];
      final reviewSummaries = reviewsJson is List
          ? reviewsJson
              .whereType<Map>()
              .take(3)
              .map((review) {
                final author = review['author_name']?.toString() ?? 'Google user';
                final rating = review['rating']?.toString() ?? '';
                final text = review['text']?.toString().trim() ?? '';
                if (text.isEmpty) {
                  return '$author - $rating/5';
                }
                return '$author - $rating/5: $text';
              })
              .toList()
          : const <String>[];

      final googleRating = result['rating'] is num
          ? (result['rating'] as num).toDouble()
          : poi.googleRating;
      final userRatingsTotal = result['user_ratings_total'] is num
          ? (result['user_ratings_total'] as num).toInt()
          : poi.userRatingsTotal;
      final mapsUrl = result['url']?.toString() ?? poi.mapsUri;
      final hoursSummary = isOpenNow == null
          ? poi.hours
          : isOpenNow
              ? 'Open now'
              : 'Closed now';

      return poi.copyWith(
        rating: googleRating ?? poi.rating,
        hours: hoursSummary,
        mapsUri: mapsUrl.isEmpty ? poi.mapsUri : mapsUrl,
        googleRating: googleRating,
        userRatingsTotal: userRatingsTotal,
        isOpenNow: isOpenNow,
        openingHours: openingHours,
        photoUrls: photoUrls,
        googleReviewSummaries: reviewSummaries,
      );
    } catch (_) {
      return poi;
    } finally {
      client.close(force: true);
    }
  }

  Future<ExploreAgentResponse> recommend({
    required String inputAsText,
    required String userId,
    required List<String> profileInterests,
    required String preferredIntensity,
    required String profileBio,
    required String responseLanguage,
    double? currentLocationLat,
    double? currentLocationLng,
    String? currentLocationName,
  }) async {
    final input = {
      'input_as_text': inputAsText,
      'user_id': userId,
      'profile_interests': profileInterests.join(', '),
      'preferred_intensity': preferredIntensity,
      'profile_bio': profileBio,
      'response_language': responseLanguage,
      'current_location_lat': currentLocationLat,
      'current_location_lng': currentLocationLng,
      'current_location_name': currentLocationName,
    };

    return _requestPlacesWithRetry(
      developerPrompt: _exploreAgentPrompt,
      retryPrompt: _fastExploreAgentPrompt,
      input: input,
    );
  }

  Future<List<Poi>> searchPlaces({
    required String query,
    double? currentLocationLat,
    double? currentLocationLng,
    String? currentLocationName,
  }) async {
    final response = await _requestPlaces(
      developerPrompt: _manualPlaceSearchPrompt,
      input: {
        'query': query,
        'currentlocationlat': currentLocationLat,
        'currentlocationlng': currentLocationLng,
        'currentlocationname': currentLocationName,
      },
    );

    return response.recommendedPlaces
        .map((place) => place.toPoi())
        .where((poi) => poi.name.trim().isNotEmpty)
        .toList();
  }

  Future<ExploreRoutePlan> planRoute({
    required List<Poi> places,
    required String travelMode,
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
          'content': _routePlannerPrompt,
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'travelMode': travelMode,
            'currentlocationlat': currentLocationLat,
            'currentlocationlng': currentLocationLng,
            'currentlocationname': currentLocationName,
            'places': places
                .map(
                  (poi) => {
                    'id': poi.id,
                    'name': poi.name,
                    'googlePlaceId': poi.googlePlaceId,
                    'latitude': poi.lat,
                    'longitude': poi.lng,
                    'mapsUri': poi.mapsUri,
                  },
                )
                .toList(),
          }),
        },
      ],
      'tools': [
        {
          'type': 'mcp',
          'server_label': 'google_maps',
          'server_description': 'Google Maps tools for real-time route planning.',
          'server_url': mcpServerUrl,
          'require_approval': 'never',
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'explore_route_plan_output',
          'strict': true,
          'schema': _routePlanOutputSchema,
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
        throw const ExploreAgentException('Route plan output was not a JSON object.');
      }

      return ExploreRoutePlan.fromJson(outputJson);
    } on ExploreAgentException {
      rethrow;
    } on Object catch (error) {
      throw ExploreAgentException('Route planning failed: $error');
    } finally {
      client.close();
    }
  }

  Future<ExploreRoutePlan?> planRouteWithDirectionsApi({
    required List<Poi> places,
    required String travelMode,
    double? currentLocationLat,
    double? currentLocationLng,
    String? currentLocationName,
  }) async {
    final apiKey = _googleMapsApiKey.trim();
    final routePlaces = places.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    if (apiKey.isEmpty || routePlaces.isEmpty) {
      return null;
    }

    final origin = currentLocationLat != null && currentLocationLng != null
        ? '$currentLocationLat,$currentLocationLng'
        : currentLocationName?.trim();
    if (origin == null || origin.isEmpty) {
      return null;
    }

    final destination = routePlaces.last;
    final waypointPlaces = routePlaces.length > 1
        ? routePlaces.sublist(0, routePlaces.length - 1)
        : <Poi>[];
    final mode = travelMode == 'transit' && waypointPlaces.isNotEmpty
        ? 'walking'
        : travelMode;
    final params = <String, String>{
      'origin': origin,
      'destination': '${destination.lat},${destination.lng}',
      'mode': mode,
      'key': apiKey,
    };
    if (waypointPlaces.isNotEmpty) {
      params['waypoints'] =
          'optimize:true|${waypointPlaces.map((poi) => '${poi.lat},${poi.lng}').join('|')}';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'OK') {
        return null;
      }

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        return null;
      }

      final route = routes.first as Map;
      final legs = route['legs'];
      var distanceMeters = 0;
      var durationSeconds = 0;
      if (legs is List) {
        for (final leg in legs.whereType<Map>()) {
          final distance = leg['distance'];
          final duration = leg['duration'];
          if (distance is Map && distance['value'] is num) {
            distanceMeters += (distance['value'] as num).round();
          }
          if (duration is Map && duration['value'] is num) {
            durationSeconds += (duration['value'] as num).round();
          }
        }
      }

      final polyline = route['overview_polyline'];
      final encodedPolyline = polyline is Map ? polyline['points']?.toString() : '';
      final waypointOrderJson = route['waypoint_order'];
      final waypointOrder = waypointOrderJson is List
          ? waypointOrderJson.whereType<num>().map((item) => item.toInt()).toList()
          : const <int>[];
      final orderedWaypoints = waypointOrder.isEmpty
          ? waypointPlaces
          : waypointOrder
              .where((index) => index >= 0 && index < waypointPlaces.length)
              .map((index) => waypointPlaces[index])
              .toList();
      final orderedPlaces = [...orderedWaypoints, destination];

      return ExploreRoutePlan(
        orderedPlaceIds: orderedPlaces.map((poi) => poi.id).toList(),
        totalDistanceKm: distanceMeters / 1000,
        totalDurationMinutes: (durationSeconds / 60).round(),
        mapsUrl: '',
        summary: '',
        steps: const [],
        polylinePoints: _decodePolyline(encodedPolyline ?? ''),
      );
    } on Object {
      return null;
    } finally {
      client.close();
    }
  }

  Future<ExploreAgentResponse> _requestPlaces({
    required String developerPrompt,
    required Map<String, dynamic> input,
    Duration responseTimeout = const Duration(seconds: 45),
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
          'content': developerPrompt,
        },
        {
          'role': 'user',
          'content': jsonEncode(input),
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

      final response = await request.close().timeout(responseTimeout);
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

  Future<ExploreAgentResponse> _requestPlacesWithRetry({
    required String developerPrompt,
    required String retryPrompt,
    required Map<String, dynamic> input,
  }) async {
    try {
      return await _requestPlaces(
        developerPrompt: developerPrompt,
        input: input,
        responseTimeout: const Duration(seconds: 45),
      );
    } on Object catch (error) {
      if (!_isRetryableMapError(error)) {
        rethrow;
      }

      return _requestPlaces(
        developerPrompt: retryPrompt,
        input: input,
        responseTimeout: const Duration(seconds: 70),
      );
    }
  }

  bool _isRetryableMapError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('timeout') ||
        text.contains('future not completed') ||
        text.contains('503') ||
        text.contains('504') ||
        text.contains('temporarily unavailable');
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

class ExploreRoutePlan {
  const ExploreRoutePlan({
    required this.orderedPlaceIds,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.mapsUrl,
    required this.summary,
    required this.steps,
    this.polylinePoints = const [],
  });

  factory ExploreRoutePlan.fromJson(Map<String, dynamic> json) {
    final ids = json['orderedPlaceIds'];
    final stepsJson = json['steps'];
    return ExploreRoutePlan(
      orderedPlaceIds: ids is List
          ? ids.map((item) => item.toString()).where((item) => item.isNotEmpty).toList()
          : const [],
      totalDistanceKm: _number(json['totalDistanceKm']),
      totalDurationMinutes: _number(json['totalDurationMinutes']).round(),
      mapsUrl: json['mapsUrl']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      steps: stepsJson is List
          ? stepsJson
              .whereType<Map<Object?, Object?>>()
              .map(ExploreRouteStep.fromJson)
              .toList()
          : const [],
      polylinePoints: const [],
    );
  }

  final List<String> orderedPlaceIds;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final String mapsUrl;
  final String summary;
  final List<ExploreRouteStep> steps;
  final List<RouteLatLng> polylinePoints;
}

class RouteLatLng {
  const RouteLatLng({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class ExploreRouteStep {
  const ExploreRouteStep({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.durationMinutes,
    required this.instruction,
  });

  factory ExploreRouteStep.fromJson(Map<Object?, Object?> json) {
    return ExploreRouteStep(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      distanceKm: _number(json['distanceKm']),
      durationMinutes: _number(json['durationMinutes']).round(),
      instruction: json['instruction']?.toString() ?? '',
    );
  }

  final String from;
  final String to;
  final double distanceKm;
  final int durationMinutes;
  final String instruction;
}

class ExploreAgentResponse {
  const ExploreAgentResponse({
    required this.recommendedPlaces,
    required this.isDone,
    required this.message,
  });

  factory ExploreAgentResponse.fromJson(Map<String, dynamic> json) {
    final placesJson = json['recommended_places'] ?? json['recommendedPlaces'];
    final isDoneJson = json['is_done'];
    final needsMoreInfoJson = json['needsMoreInfo'];
    return ExploreAgentResponse(
      recommendedPlaces: placesJson is List
          ? placesJson
              .whereType<Map<Object?, Object?>>()
              .map(RecommendedPlace.fromJson)
              .toList()
          : const [],
      isDone: isDoneJson is bool
          ? isDoneJson
          : needsMoreInfoJson is bool
              ? !needsMoreInfoJson
              : false,
      message: json['message']?.toString() ??
          json['followUpQuestion']?.toString() ??
          '',
    );
  }

  final List<RecommendedPlace> recommendedPlaces;
  final bool isDone;
  final String message;

  bool get needsMoreInfo => !isDone;
  String get followUpQuestion => message;
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
      placeName: _readJsonString(json, 'place_name', 'placeName'),
      placeType: _readJsonString(json, 'place_type', 'placeType'),
      googlePlaceId: _readJsonString(json, 'google_place_id', 'googlePlaceId'),
      source: json['source']?.toString() ?? 'google_maps',
      mapsUri: _readJsonString(json, 'maps_uri', 'mapsUri'),
      activitySuggestion: _readJsonString(
        json,
        'activity_suggestion',
        'activitySuggestion',
      ),
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      shortReason: _readJsonString(json, 'short_reason', 'shortReason'),
      suitabilityForIntensity: _readJsonString(
        json,
        'suitability_for_intensity',
        'suitabilityForIntensity',
      ),
      matchScore: _number(json['match_score'] ?? json['matchScore']),
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

String _readJsonString(Map<Object?, Object?> json, String key, String legacyKey) {
  return json[key]?.toString() ?? json[legacyKey]?.toString() ?? '';
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

List<RouteLatLng> _decodePolyline(String encoded) {
  if (encoded.isEmpty) {
    return const [];
  }

  final points = <RouteLatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lat += dLat;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final dLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lng += dLng;

    points.add(RouteLatLng(lat: lat / 1E5, lng: lng / 1E5));
  }

  return points;
}

const _exploreAgentPrompt = '''
You are WanderJoy's Explore Agent.

你作为一个旅游助手，要给用户推荐定制化的旅游目的地。你的任务就是先通过语音输入的文本和以下的基本信息收集用户的基本数据，当你没有得到足够的数据（即 is_done == false），你就继续用 message to user 来获取足够信息。当你觉得收集到足够信息后，再去调用 mcp 获取推荐地点的 POI。在结束的时候（即 is_done == true）用规定的格式返回 POI。

如下是用户的一些基本信息：
经度 {{state.current_location_lng}}
纬度 {{state.current_location_lat}}
用户的兴趣 {{state.profile_interests}}，还有用户预期的旅游强度是 {{state.preferred_intensity}}

The user input is provided as JSON:
- input_as_text: voice input transcribed to text
- profile_interests
- preferred_intensity
- current_location_lat
- current_location_lng
- current_location_name
- profile_bio
- response_language: the language chosen from the user's first conversation message

You must use the google_maps MCP tools to find real places before recommending any place.
Do not recommend, name, rank, or describe a real-world place unless it was returned by google_maps.
Do not invent real-time ratings, live distance, coordinates, opening hours, phone numbers, or reviews unless they are returned by google_maps.

Required information:
- exploration location, either explicit in input_as_text or provided by current_location_lat/current_location_lng/current_location_name
- interests or an inferred exploration preference
- travel intensity, either explicit, provided by preferred_intensity, or clearly inferred from wording

Location rules:
- Location can be a city, area, landmark, address, postcode, or place mentioned in input_as_text.
- If input_as_text contains a location, use that as the exploration location and do not ask for coordinates.
- If both textual location and coordinates are available, prefer the textual location when the user clearly names it.
- If the user says "nearby" after mentioning a city, area, landmark, or address, interpret nearby as near that mentioned location.
- If only current_location_lat and current_location_lng are provided, use them for nearby search.
- Ask for location only if no textual location, no current_location_name, and no usable coordinates are available.

Preference priority rules:
- Explicit user interests always have highest priority.
- The user's latest input_as_text has priority over saved profile fields when they conflict.
- Saved profile interests, bio, and preferred_intensity are helpful background context, not hard constraints.
- If the user mentions art, gallery, museum, exhibition, dance, performance, 艺术, 美术馆, 博物馆, 展览, 舞蹈, 演出, or similar words, the search must focus on those related places and activities.
- Do not replace explicit interests with generic categories like parks, cafes, bars, or attractions unless the user also asked for them.
- Cafes, parks, bars, and general attractions may only be included if they are clearly related to the explicit interest.

Do not require the user to use exact words like relaxed, medium, or active.
Infer travel intensity only when the user's wording clearly implies energy level.
- relaxed: tired, exhausted, sleepy, long studying, low energy, want to chill, casual walk, quiet, slow, nearby, easy, not too much walking, 好累, 累, 随便转转, 放松, 轻松, 不想太累, 休息一下
- medium: normal energy, balanced plan, some walking, explore a bit, 普通, 适中, 都可以, 逛逛
- active: energetic, want adventure, lots of walking, packed day, hiking, sports, 很有精力, 想多玩点, 暴走, 挑战

If travel intensity is not provided by profile and cannot be clearly inferred, ask one short follow-up question instead of recommending places.
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
- Use maps_place_details only when the search result is missing placeId or coordinates.
- If google_maps returns no suitable results, ask the user to adjust the area or preference.
- If google_maps is unavailable or fails, do not invent places.

Recommend exactly 3 suitable places. Keep the tool work small and fast.

For each recommended place, include:
- place_name
- place_type
- google_place_id
- source: "google_maps"
- maps_uri, or an empty string if not returned by google_maps
- activity_suggestion
- latitude
- longitude
- short_reason
- suitability_for_intensity
- match_score from 0 to 1

If required information is missing:
- recommended_places must be []
- is_done must be false
- message must contain one short question

If recommendations are ready:
- recommended_places must contain 3 places
- is_done must be true
- message must be a concise confirmation or summary

Language rules:
- All human-facing text fields must be written in response_language.
- This includes followUpQuestion, activitySuggestion, shortReason, suitabilityForIntensity, and route/recommendation summaries.
- Keep real place names exactly as returned by Google Maps, but translate your explanations.
- Do not switch languages because the app UI, profile text, or prior assistant messages use another language.
Return only JSON matching the schema.
''';

const _fastExploreAgentPrompt = '''
You are WanderJoy's fast Google Maps recommendation helper.

The user input is a JSON object with input_as_text, profile_interests, preferred_intensity, profile_bio, current_location_lat, current_location_lng, current_location_name, and response_language.

You must use google_maps before returning any place. Do not invent places.

Make one focused Google Maps search using the user's clearest location and activity preference. Prefer maps_search_places. If coordinates are available and the user asks for nearby places, maps_search_nearby is also acceptable. Do not use maps_place_details unless the result has no coordinates.

Return exactly 3 real places when possible. Prefer local, smaller, non-chain places when the user asks for local or non-touristy options.

For each place, fill: place_name, place_type, google_place_id, source, maps_uri, activity_suggestion, latitude, longitude, short_reason, suitability_for_intensity, match_score.

If no suitable results are found, return recommended_places: [], is_done: false, message: one short question.
If recommendations are ready, is_done must be true and message must be a concise confirmation or summary.

Language rules:
- All human-facing text fields must be written in response_language.
- This includes followUpQuestion, activitySuggestion, shortReason, and suitabilityForIntensity.
- Keep real place names exactly as returned by Google Maps, but translate your explanations.
- Do not switch languages because the app UI, profile text, or prior assistant messages use another language.
Return only JSON matching the schema.
''';

const _manualPlaceSearchPrompt = '''
You are WanderJoy's Google Maps place search helper.

You must use google_maps MCP tools to search Google Maps before returning any place.
Do not invent places. Only return places from google_maps results.

The user input is a JSON object with:
- query
- currentlocationlat
- currentlocationlng
- currentlocationname

Search rules:
- Search for the exact query the user typed.
- If currentlocationname or coordinates are available, bias the search near that location.
- Prefer maps_search_places for text search.
- Use maps_place_details only if the result is missing placeId or coordinates.
- Return 3 matching places when possible.
- If no results are found, return recommended_places: [], is_done: false, message: "No matching Google Maps places found. Try another search."

For each place, fill:
- place_name
- place_type
- google_place_id
- source: "google_maps"
- maps_uri, or empty string if not returned
- activity_suggestion: a short neutral suggestion for adding this place to the route
- latitude
- longitude
- short_reason: a short reason based on the search result
- suitability_for_intensity: "medium"
- match_score from 0 to 1

If matching places are returned, is_done must be true and message must be "".

Return only JSON matching the schema.
''';

const _routePlannerPrompt = '''
You are WanderJoy's Google Maps route planner.

You must use google_maps MCP tools to plan the route. Prefer maps_plan_route if it is available because it can optimize a multi-stop route in one call. If maps_plan_route is not available, use maps_distance_matrix to compare travel time between stops and maps_directions for the final route.

The user input is JSON with:
- travelMode
- currentlocationlat
- currentlocationlng
- currentlocationname
- places: real Google Maps places already selected by the user

Optimize for the shortest total travel duration, not straight-line distance. Use current location as the route origin when currentlocationlat/currentlocationlng or currentlocationname is available. Do not drop selected places unless Google Maps cannot route to them.

Return only JSON matching the schema:
- orderedPlaceIds: selected place ids in optimized visit order
- totalDistanceKm: Google Maps route distance in kilometers
- totalDurationMinutes: Google Maps route duration in minutes
- mapsUrl: a Google Maps directions URL for the ordered route, or empty string if the tool cannot return/build one
- summary: one concise sentence explaining the route
- steps: segment summaries between the origin/places/stops
''';

const _exploreAgentOutputSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'recommended_places': {
      'type': 'array',
      'default': [],
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'place_name': {
            'type': 'string',
            'default': '',
          },
          'place_type': {
            'type': 'string',
            'default': '',
          },
          'google_place_id': {
            'type': 'string',
            'default': '',
          },
          'source': {
            'type': 'string',
            'enum': ['google_maps'],
            'default': '',
          },
          'maps_uri': {
            'type': 'string',
            'default': '',
          },
          'activity_suggestion': {
            'type': 'string',
            'default': '',
          },
          'latitude': {'type': 'number'},
          'longitude': {'type': 'number'},
          'short_reason': {
            'type': 'string',
            'default': '',
          },
          'suitability_for_intensity': {
            'type': 'string',
            'enum': ['relaxed', 'medium', 'active'],
            'default': '',
          },
          'match_score': {'type': 'number'},
        },
        'required': [
          'place_name',
          'place_type',
          'google_place_id',
          'source',
          'maps_uri',
          'activity_suggestion',
          'latitude',
          'longitude',
          'short_reason',
          'suitability_for_intensity',
          'match_score',
        ],
      },
    },
    'is_done': {
      'type': 'boolean',
      'default': false,
    },
    'message': {
      'type': 'string',
      'default': '',
    },
  },
  'required': [
    'recommended_places',
    'is_done',
    'message',
  ],
};

const _routePlanOutputSchema = <String, dynamic>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'orderedPlaceIds': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'totalDistanceKm': {'type': 'number'},
    'totalDurationMinutes': {'type': 'number'},
    'mapsUrl': {'type': 'string'},
    'summary': {'type': 'string'},
    'steps': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'from': {'type': 'string'},
          'to': {'type': 'string'},
          'distanceKm': {'type': 'number'},
          'durationMinutes': {'type': 'number'},
          'instruction': {'type': 'string'},
        },
        'required': [
          'from',
          'to',
          'distanceKm',
          'durationMinutes',
          'instruction',
        ],
      },
    },
  },
  'required': [
    'orderedPlaceIds',
    'totalDistanceKm',
    'totalDurationMinutes',
    'mapsUrl',
    'summary',
    'steps',
  ],
};
