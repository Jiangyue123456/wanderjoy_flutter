enum PoiCategory { nature, culture, food, arts, other }

enum EnergyLevel { low, medium, high }

enum RouteMode { relaxed, medium, active }

enum TripType { explore, social }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.interests,
    required this.energyLevel,
    required this.travelStyle,
    required this.bio,
    required this.distanceKm,
    required this.safetyRating,
    this.paceMatch,
  });

  final String id;
  final String name;
  final String avatar;
  final int age;
  final List<PoiCategory> interests;
  final EnergyLevel energyLevel;
  final String travelStyle;
  final String bio;
  final double distanceKm;
  final double safetyRating;
  final int? paceMatch;
}

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.reason,
    required this.lat,
    required this.lng,
    required this.emoji,
    required this.hours,
    this.googlePlaceId = '',
    this.mapsUri = '',
    this.placeType = '',
    this.matchScore = 0,
    this.googleRating,
    this.userRatingsTotal,
    this.isOpenNow,
    this.openingHours = const [],
    this.photoUrls = const [],
    this.googleReviewSummaries = const [],
  });

  final String id;
  final String name;
  final PoiCategory category;
  final String description;
  final double rating;
  final String reason;
  final double lat;
  final double lng;
  final String emoji;
  final String hours;
  final String googlePlaceId;
  final String mapsUri;
  final String placeType;
  final double matchScore;
  final double? googleRating;
  final int? userRatingsTotal;
  final bool? isOpenNow;
  final List<String> openingHours;
  final List<String> photoUrls;
  final List<String> googleReviewSummaries;

  Poi copyWith({
    String? id,
    String? name,
    PoiCategory? category,
    String? description,
    double? rating,
    String? reason,
    double? lat,
    double? lng,
    String? emoji,
    String? hours,
    String? googlePlaceId,
    String? mapsUri,
    String? placeType,
    double? matchScore,
    double? googleRating,
    int? userRatingsTotal,
    bool? isOpenNow,
    List<String>? openingHours,
    List<String>? photoUrls,
    List<String>? googleReviewSummaries,
  }) {
    return Poi(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reason: reason ?? this.reason,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      emoji: emoji ?? this.emoji,
      hours: hours ?? this.hours,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      mapsUri: mapsUri ?? this.mapsUri,
      placeType: placeType ?? this.placeType,
      matchScore: matchScore ?? this.matchScore,
      googleRating: googleRating ?? this.googleRating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      openingHours: openingHours ?? this.openingHours,
      photoUrls: photoUrls ?? this.photoUrls,
      googleReviewSummaries:
          googleReviewSummaries ?? this.googleReviewSummaries,
    );
  }
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.routeId,
    required this.userId,
    required this.photo,
    required this.text,
    required this.location,
    required this.timestamp,
    required this.tripType,
    required this.title,
  });

  final String id;
  final String routeId;
  final String userId;
  final String photo;
  final String text;
  final String location;
  final String timestamp;
  final TripType tripType;
  final String title;
}

extension PoiCategoryX on PoiCategory {
  String get label => switch (this) {
    PoiCategory.nature => 'Nature',
    PoiCategory.culture => 'Culture',
    PoiCategory.food => 'Food',
    PoiCategory.arts => 'Arts',
    PoiCategory.other => 'Other',
  };
}

extension EnergyLevelX on EnergyLevel {
  String get label => switch (this) {
    EnergyLevel.low => 'Relaxed',
    EnergyLevel.medium => 'Medium',
    EnergyLevel.high => 'Active',
  };
}

extension RouteModeX on RouteMode {
  String get label => switch (this) {
    RouteMode.relaxed => 'Relaxed',
    RouteMode.medium => 'Medium',
    RouteMode.active => 'Active',
  };
}

extension TripTypeX on TripType {
  String get label => switch (this) {
    TripType.explore => 'Explore',
    TripType.social => 'Social',
  };
}
