enum PoiCategory { nature, culture, food, arts }

enum EnergyLevel { low, medium, high }

enum RouteMode { relaxed, custom, hard }

enum TripType { explore, social }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.interests,
    required this.energyLevel,
    required this.travelStyle,
    required this.safetyRating,
    this.paceMatch,
  });

  final String id;
  final String name;
  final String avatar;
  final List<PoiCategory> interests;
  final EnergyLevel energyLevel;
  final String travelStyle;
  final double safetyRating;
  final int? paceMatch;
}

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    required this.emoji,
    required this.hours,
  });

  final String id;
  final String name;
  final PoiCategory category;
  final String description;
  final double lat;
  final double lng;
  final String emoji;
  final String hours;
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
  };
}

extension EnergyLevelX on EnergyLevel {
  String get label => switch (this) {
    EnergyLevel.low => 'Low',
    EnergyLevel.medium => 'Medium',
    EnergyLevel.high => 'High',
  };
}

extension RouteModeX on RouteMode {
  String get label => switch (this) {
    RouteMode.relaxed => 'Relaxed',
    RouteMode.custom => 'Custom',
    RouteMode.hard => 'Hard',
  };
}

extension TripTypeX on TripType {
  String get label => switch (this) {
    TripType.explore => 'Explore',
    TripType.social => 'Social',
  };
}
