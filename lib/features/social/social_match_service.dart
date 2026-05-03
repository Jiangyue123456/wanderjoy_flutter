import 'social_match_http_client.dart';

class SocialMatchService {
  const SocialMatchService({
    this.endpoint = const String.fromEnvironment(
      'SOCIAL_MATCH_API_URL',
      defaultValue: 'http://10.0.2.2:8787/api/social-match',
    ),
  });

  final String endpoint;

  Future<SocialMatchResponse> match({
    required String inputAsText,
    required String currentUserId,
    required String city,
    required List<String> interests,
    required String travelIntensity,
  }) async {
    final payload = await postJson(
      Uri.parse(endpoint),
      <String, dynamic>{
        'input_as_text': inputAsText,
        'currentuserid': currentUserId,
        'city': city,
        'interests': interests,
        'travelintensity': travelIntensity,
      },
      const Duration(seconds: 12),
    );

    return SocialMatchResponse.fromJson(payload);
  }
}

class SocialMatchResponse {
  const SocialMatchResponse({
    required this.recommendedUsers,
    required this.messageToUser,
  });

  factory SocialMatchResponse.fromJson(Map<String, dynamic> json) {
    final usersJson = json['recommendedUsers'];
    return SocialMatchResponse(
      recommendedUsers: usersJson is List
          ? usersJson
              .whereType<Map<Object?, Object?>>()
              .map(RecommendedSocialUser.fromJson)
              .toList()
          : const [],
      messageToUser: json['messageToUser']?.toString() ?? '',
    );
  }

  final List<RecommendedSocialUser> recommendedUsers;
  final String messageToUser;
}

class RecommendedSocialUser {
  const RecommendedSocialUser({
    required this.userId,
    required this.displayName,
    required this.sharedInterests,
    required this.travelIntensityCompatibility,
    required this.shortMatchReason,
    required this.distanceKm,
    required this.safetyRating,
    required this.matchScore,
    required this.matchRank,
  });

  factory RecommendedSocialUser.fromJson(Map<Object?, Object?> json) {
    final interestsJson = json['sharedInterests'];
    return RecommendedSocialUser(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Traveler',
      sharedInterests: interestsJson is List
          ? interestsJson.map((item) => item.toString()).toList()
          : const [],
      travelIntensityCompatibility:
          json['travelIntensityCompatibility']?.toString() ?? '',
      shortMatchReason: json['shortMatchReason']?.toString() ?? '',
      distanceKm: _number(json['distanceKm']),
      safetyRating: _number(json['safetyRating']),
      matchScore: _number(json['matchScore']).round(),
      matchRank: _number(json['matchRank']).round(),
    );
  }

  final String userId;
  final String displayName;
  final List<String> sharedInterests;
  final String travelIntensityCompatibility;
  final String shortMatchReason;
  final double distanceKm;
  final double safetyRating;
  final int matchScore;
  final int matchRank;
}

double _number(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
