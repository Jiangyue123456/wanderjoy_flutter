import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';
import 'explore_agent_service.dart';

enum ExploreStep { home, input, customize, route, trip, summary }

class ExploreController extends ChangeNotifier {
  ExploreController({this.exploreAgentService = const ExploreAgentService()});

  final ExploreAgentService exploreAgentService;

  ExploreStep step = ExploreStep.home;
  RouteMode mode = RouteMode.relaxed;
  EnergyLevel energy = EnergyLevel.low;
  final List<PoiCategory> interests = List<PoiCategory>.from(MockData.myInterests);
  final List<String> profileInterestLabels = MockData.myInterests
      .map((interest) => interest.label)
      .toList();
  final List<Poi> selectedPois = [];
  final List<String> chatMessages = [
    'AI: Let\'s talk about where you\'d like to go.',
  ];
  String searchQuery = '';
  String chatInput = '';
  String timeAvailable = 'Half day';
  String profileName = 'Explorer';
  String profileBio = MockData.myBio;
  bool isListening = false;
  bool isGeneratingPlaces = false;
  bool isSearchingPlaces = false;
  bool isPlanningRoute = false;
  String? exploreError;
  final List<Poi> searchResults = [];
  final Set<String> loadingPlaceDetailIds = {};
  Poi? activePoi;
  ExploreRoutePlan? routePlan;
  String? routePlanningNotice;
  String? locationStatus;
  bool isNavigationActive = false;
  Offset userPosition = const Offset(0.40, 0.40);
  double? currentLocationLat = 51.544;
  double? currentLocationLng = -0.009;
  String currentLocationName = 'Stratford E20 1LZ London';
  double? navigationOriginLat;
  double? navigationOriginLng;

  Timer? _tripTimer;
  StreamSubscription<Position>? _positionSubscription;
  final Random _random = Random();
  String? _profileSignature;

  List<Poi> get optimizedPois {
    final orderedIds = routePlan?.orderedPlaceIds ?? const [];
    if (orderedIds.isNotEmpty) {
      final ordered = <Poi>[];
      final usedIds = <String>{};
      for (final id in orderedIds) {
        final match = selectedPois.where((poi) => _matchesPoiId(poi, id));
        if (match.isEmpty) {
          continue;
        }
        final poi = match.first;
        if (usedIds.add(poi.id)) {
          ordered.add(poi);
        }
      }
      ordered.addAll(selectedPois.where((poi) => !usedIds.contains(poi.id)));
      return ordered;
    }

    if (selectedPois.length <= 1) {
      return List<Poi>.from(selectedPois);
    }

    final result = <Poi>[];
    final remaining = List<Poi>.from(selectedPois);
    var current = remaining.removeAt(0);
    result.add(current);

    while (remaining.isNotEmpty) {
      var nearestIndex = 0;
      var minDistance = double.infinity;

      for (var index = 0; index < remaining.length; index++) {
        final candidate = remaining[index];
        final distance = sqrt(
          pow(current.lat - candidate.lat, 2) +
              pow(current.lng - candidate.lng, 2),
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = index;
        }
      }

      current = remaining.removeAt(nearestIndex);
      result.add(current);
    }

    return result;
  }

  double get totalDistanceKm {
    final plannedDistance = routePlan?.totalDistanceKm ?? 0;
    if (plannedDistance > 0) {
      return plannedDistance;
    }

    if (optimizedPois.length < 2) {
      return optimizedPois.length * 0.7;
    }

    var total = 0.0;
    for (var index = 0; index < optimizedPois.length - 1; index++) {
      final current = optimizedPois[index];
      final next = optimizedPois[index + 1];
      total += sqrt(
            pow(current.lat - next.lat, 2) + pow(current.lng - next.lng, 2),
          ) *
          92;
    }
    return total.clamp(0.8, 9.9);
  }

  double? distanceFromCurrentKm(Poi poi) {
    final originLat = currentLocationLat;
    final originLng = currentLocationLng;
    if (originLat == null || originLng == null) {
      return null;
    }
    return _haversineKm(originLat, originLng, poi.lat, poi.lng);
  }

  int? travelMinutesFromCurrent(Poi poi) {
    final distance = distanceFromCurrentKm(poi);
    if (distance == null) {
      return null;
    }

    final kmPerHour = switch (energy) {
      EnergyLevel.low => 4.2,
      EnergyLevel.medium => 4.8,
      EnergyLevel.high => 5.4,
    };
    return max(1, (distance / kmPerHour * 60).round());
  }

  int get estimatedMinutes {
    final plannedMinutes = routePlan?.totalDurationMinutes ?? 0;
    if (plannedMinutes > 0) {
      return plannedMinutes;
    }

    final base = switch (energy) {
      EnergyLevel.low => 24,
      EnergyLevel.medium => 18,
      EnergyLevel.high => 14,
    };
    return (optimizedPois.length * base + totalDistanceKm * 12).round();
  }

  List<Poi> get filteredSearchResults {
    return searchResults
        .where((poi) => !selectedPois.any((item) => item.id == poi.id))
        .toList();
  }

  bool isLoadingPlaceDetails(Poi poi) {
    return loadingPlaceDetailIds.contains(_poiDetailKey(poi));
  }

  Poi latestPoi(Poi poi) {
    final selectedMatch = selectedPois.where((item) => _matchesPoiId(item, poi.id));
    if (selectedMatch.isNotEmpty) {
      return selectedMatch.first;
    }
    final searchMatch = searchResults.where((item) => _matchesPoiId(item, poi.id));
    if (searchMatch.isNotEmpty) {
      return searchMatch.first;
    }
    return poi;
  }

  Future<void> loadGooglePlaceDetails(Poi poi) async {
    final key = _poiDetailKey(poi);
    final current = latestPoi(poi);
    if (key.isEmpty ||
        current.openingHours.isNotEmpty ||
        current.photoUrls.isNotEmpty ||
        current.googleReviewSummaries.isNotEmpty ||
        loadingPlaceDetailIds.contains(key)) {
      return;
    }

    loadingPlaceDetailIds.add(key);
    notifyListeners();
    final detailed = await exploreAgentService.fetchGooglePlaceDetails(current);
    _replacePoi(detailed);
    loadingPlaceDetailIds.remove(key);
    notifyListeners();
  }

  void goTo(ExploreStep nextStep) {
    step = nextStep;
    if (step == ExploreStep.route || step == ExploreStep.trip) {
      startLocationUpdates();
    }
    if (step == ExploreStep.trip) {
      _startTripSimulation();
    } else {
      _tripTimer?.cancel();
    }
    notifyListeners();
  }

  void startNavigation() {
    isNavigationActive = true;
    navigationOriginLat = currentLocationLat;
    navigationOriginLng = currentLocationLng;
    step = ExploreStep.route;
    startLocationUpdates();
    notifyListeners();
  }

  void endNavigation() {
    isNavigationActive = false;
    navigationOriginLat = null;
    navigationOriginLng = null;
    notifyListeners();
  }

  void setMode(RouteMode value) {
    mode = value;
    energy = switch (value) {
      RouteMode.relaxed => EnergyLevel.low,
      RouteMode.medium => EnergyLevel.medium,
      RouteMode.active => EnergyLevel.high,
    };
    notifyListeners();
  }

  void setEnergy(EnergyLevel value) {
    energy = value;
    mode = switch (value) {
      EnergyLevel.low => RouteMode.relaxed,
      EnergyLevel.medium => RouteMode.medium,
      EnergyLevel.high => RouteMode.active,
    };
    notifyListeners();
  }

  void setChatInput(String value) {
    chatInput = value;
  }

  void setListeningState(bool value) {
    if (isListening == value) {
      return;
    }
    isListening = value;
    notifyListeners();
  }

  void setExploreError(String? value) {
    exploreError = value;
    notifyListeners();
  }

  void applyProfile(Map<String, dynamic>? data, {String? fallbackName}) {
    final nextName = _readString(data, 'displayName', fallback: fallbackName ?? 'Explorer');
    final nextBio = _readString(data, 'bio', fallback: MockData.myBio);
    final nextIntensity = _readString(data, 'preferredIntensity', fallback: 'Relaxed');
    final nextInterestLabels = _readInterestLabels(data?['interests']);
    final nextInterests = _readInterests(nextInterestLabels);
    final signature = '$nextName|$nextBio|$nextIntensity|${nextInterestLabels.join(',')}';

    if (_profileSignature == signature) {
      return;
    }

    profileName = nextName;
    profileBio = nextBio;
    profileInterestLabels
      ..clear()
      ..addAll(
        nextInterestLabels.isEmpty
            ? MockData.myInterests.map((interest) => interest.label)
            : nextInterestLabels,
      );
    interests
      ..clear()
      ..addAll(nextInterests.isEmpty ? MockData.myInterests : nextInterests);
    energy = _energyFromLabel(nextIntensity);
    mode = switch (energy) {
      EnergyLevel.low => RouteMode.relaxed,
      EnergyLevel.medium => RouteMode.medium,
      EnergyLevel.high => RouteMode.active,
    };
    chatMessages
      ..clear()
      ..add('AI: Let\'s talk about where you\'d like to go.');
    _profileSignature = signature;
    notifyListeners();
  }

  void startVoiceConversation() {
    isListening = true;
    chatMessages.add('AI: I am listening. Tell me your mood, time, or anything you want to avoid today.');
    notifyListeners();
  }

  void finishVoiceConversation() {
    if (!isListening) {
      return;
    }

    isListening = false;
    chatMessages.add(
      'You: I would like the route to match how I feel right now.',
    );
    chatMessages.add(
      'AI: Got it. I will combine that with your saved profile before recommending places.',
    );
    notifyListeners();
  }

  void addChatMessage() {
    final trimmed = chatInput.trim();
    if (trimmed.isEmpty) {
      return;
    }

    chatMessages.add('You: $trimmed');
    final lower = trimmed.toLowerCase();
    for (final category in PoiCategory.values) {
      if (lower.contains(category.label.toLowerCase()) &&
          !interests.contains(category)) {
        interests.add(category);
      }
    }
    if (lower.contains('tired') ||
        lower.contains('quiet') ||
        lower.contains('relaxed') ||
        lower.contains('slow')) {
      setEnergy(EnergyLevel.low);
    } else if (lower.contains('active') ||
        lower.contains('walk') ||
        lower.contains('energetic')) {
      setEnergy(EnergyLevel.high);
    }
    if (lower.contains('hour')) {
      timeAvailable = 'About 1 hour';
    } else if (lower.contains('half')) {
      timeAvailable = 'Half day';
    }
    chatMessages.add(
      'AI: Got it. I will combine your profile with what you just said before recommending places.',
    );
    chatInput = '';
    notifyListeners();
  }

  void toggleListening() {
    if (isListening) {
      finishVoiceConversation();
    } else {
      startVoiceConversation();
    }
  }

  void toggleInterest(PoiCategory category) {
    if (interests.contains(category)) {
      if (interests.length == 1) {
        return;
      }
      interests.remove(category);
    } else {
      interests.add(category);
    }
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void _replacePoi(Poi poi) {
    for (var index = 0; index < selectedPois.length; index++) {
      if (_matchesPoiId(selectedPois[index], poi.id)) {
        selectedPois[index] = poi;
      }
    }
    for (var index = 0; index < searchResults.length; index++) {
      if (_matchesPoiId(searchResults[index], poi.id)) {
        searchResults[index] = poi;
      }
    }
  }

  String _poiDetailKey(Poi poi) {
    if (poi.googlePlaceId.trim().isNotEmpty) {
      return poi.googlePlaceId.trim();
    }
    return poi.id.trim();
  }

  Future<void> searchGooglePlaces() async {
    final query = searchQuery.trim();
    if (query.isEmpty || isSearchingPlaces) {
      return;
    }

    isSearchingPlaces = true;
    exploreError = null;
    searchResults.clear();
    notifyListeners();

    try {
      final results = await exploreAgentService.searchPlaces(
        query: query,
        currentLocationLat: currentLocationLat,
        currentLocationLng: currentLocationLng,
        currentLocationName: currentLocationName,
      );
      searchResults
        ..clear()
        ..addAll(results);
      if (searchResults.isEmpty) {
        exploreError = 'No matching Google Maps places found.';
      }
    } on Object catch (error) {
      exploreError = error.toString();
    } finally {
      isSearchingPlaces = false;
      notifyListeners();
    }
  }

  Future<void> generateInitialRoute() async {
    if (isGeneratingPlaces) {
      return;
    }

    final pendingInput = chatInput.trim();
    if (pendingInput.isNotEmpty) {
      chatMessages.add('You: $pendingInput');
      chatInput = '';
    }

    isGeneratingPlaces = true;
    exploreError = null;
    chatMessages.add('AI: I am checking places on Google Maps...');
    notifyListeners();

    try {
      final response = await exploreAgentService.recommend(
        inputAsText: _latestUserInput(),
        userId: 'preview_user',
        profileInterests: profileInterestLabels,
        preferredIntensity: mode.name,
        profileBio: profileBio,
        currentLocationLat: currentLocationLat,
        currentLocationLng: currentLocationLng,
        currentLocationName: currentLocationName,
      );

      if (response.needsMoreInfo) {
        chatMessages.add('AI: ${response.followUpQuestion}');
        isGeneratingPlaces = false;
        notifyListeners();
        return;
      }

      final realPois = response.recommendedPlaces
          .map((place) => place.toPoi())
          .where((poi) => poi.name.trim().isNotEmpty)
          .toList();

      if (realPois.isEmpty) {
        throw const ExploreAgentException(
          'The agent did not return usable places.',
        );
      }

      selectedPois
        ..clear()
        ..addAll(realPois);
      routePlan = null;
      chatMessages.add(
        'AI: I found ${realPois.length} places. Preview them before building your route.',
      );
      step = ExploreStep.customize;
    } on Object catch (error) {
      exploreError = error.toString();
      chatMessages.add(
        'AI: I could not get places from Google Maps. Please try again.',
      );
    } finally {
      isGeneratingPlaces = false;
      notifyListeners();
    }
  }

  String _latestUserInput() {
    for (final message in chatMessages.reversed) {
      if (message.startsWith('You: ')) {
        return message.substring(5).trim();
      }
    }
    return 'I want to explore nearby places that match my interests.';
  }

  void addPoi(Poi poi) {
    if (selectedPois.any((item) => item.id == poi.id)) {
      return;
    }
    selectedPois.add(poi);
    routePlan = null;
    routePlanningNotice = null;
    searchQuery = '';
    searchResults.clear();
    notifyListeners();
  }

  void removePoi(String id) {
    selectedPois.removeWhere((poi) => poi.id == id);
    routePlan = null;
    routePlanningNotice = null;
    notifyListeners();
  }

  void setActivePoi(Poi? poi) {
    activePoi = poi;
    notifyListeners();
  }

  Future<void> startLocationUpdates() async {
    if (_positionSubscription != null) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationStatus = 'Location services are off.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationStatus = 'Location permission is needed for live distance.';
        notifyListeners();
        return;
      }

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _applyPosition(currentPosition);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_applyPosition);
    } on Object {
      locationStatus = 'Live location is temporarily unavailable.';
      notifyListeners();
    }
  }

  Future<void> confirmPlacesAndPlanRoute() async {
    if (selectedPois.isEmpty || isPlanningRoute) {
      return;
    }

    isPlanningRoute = true;
    exploreError = null;
    routePlanningNotice = null;
    notifyListeners();

    try {
      final directionsRoute = await exploreAgentService.planRouteWithDirectionsApi(
        places: selectedPois,
        travelMode: _travelModeForEnergy(),
        currentLocationLat: currentLocationLat,
        currentLocationLng: currentLocationLng,
        currentLocationName: currentLocationName,
      );
      if (directionsRoute != null && _isUsableRoutePlan(directionsRoute)) {
        routePlan = directionsRoute;
        return;
      }

      final plannedRoute = await exploreAgentService.planRoute(
        places: selectedPois,
        travelMode: _travelModeForEnergy(),
        currentLocationLat: currentLocationLat,
        currentLocationLng: currentLocationLng,
        currentLocationName: currentLocationName,
      );
      if (_isUsableRoutePlan(plannedRoute)) {
        routePlan = plannedRoute;
      } else {
        routePlan = null;
        routePlanningNotice =
            'Google Maps route optimization is unavailable, so this is an estimated order. Tap the map button for live directions.';
      }
    } on Object catch (error) {
      routePlanningNotice =
          'Google Maps route optimization is unavailable, so this is an estimated order. Tap the map button for live directions.';
      routePlan = null;
    } finally {
      isPlanningRoute = false;
      step = ExploreStep.route;
      notifyListeners();
    }
  }

  String routeMapsUrl() {
    final plannedUrl = routePlan?.mapsUrl.trim() ?? '';
    if (plannedUrl.startsWith('http')) {
      return plannedUrl;
    }

    final ordered = optimizedPois;
    final origin = currentLocationName.trim().isNotEmpty
        ? currentLocationName
        : currentLocationLat != null && currentLocationLng != null
        ? '$currentLocationLat,$currentLocationLng'
        : '';
    final destination = ordered.isEmpty ? origin : _poiMapsQuery(ordered.last);
    final waypoints = ordered.length > 1
        ? ordered.sublist(0, ordered.length - 1).map(_poiMapsQuery).join('|')
        : '';

    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1');
    if (origin.isNotEmpty) {
      buffer.write('&origin=${Uri.encodeComponent(origin)}');
    }
    if (destination.isNotEmpty) {
      buffer.write('&destination=${Uri.encodeComponent(destination)}');
    }
    if (waypoints.isNotEmpty) {
      buffer.write('&waypoints=${Uri.encodeComponent(waypoints)}');
    }
    buffer.write('&travelmode=${_travelModeForEnergy()}');
    return buffer.toString();
  }

  void finishAndReset() {
    _tripTimer?.cancel();
    step = ExploreStep.home;
    searchQuery = '';
    activePoi = null;
    routePlan = null;
    routePlanningNotice = null;
    isNavigationActive = false;
    navigationOriginLat = null;
    navigationOriginLng = null;
    userPosition = const Offset(0.40, 0.40);
    notifyListeners();
  }

  void _applyPosition(Position position) {
    currentLocationLat = position.latitude;
    currentLocationLng = position.longitude;
    currentLocationName = 'Current location';
    locationStatus = null;
    notifyListeners();
  }

  void _startTripSimulation() {
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      userPosition = Offset(
        _clamp(userPosition.dx + (_random.nextDouble() - 0.4) * 0.06),
        _clamp(userPosition.dy + (_random.nextDouble() - 0.4) * 0.06),
      );
      notifyListeners();
    });
  }

  double _clamp(double value) => value.clamp(0.1, 0.9);

  double _haversineKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);
    final lat1 = _degreesToRadians(startLat);
    final lat2 = _degreesToRadians(endLat);
    final a =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degreesToRadians(double value) => value * pi / 180;

  bool _matchesPoiId(Poi poi, String id) {
    return poi.id == id ||
        poi.googlePlaceId == id ||
        poi.name.toLowerCase() == id.toLowerCase();
  }

  bool _isUsableRoutePlan(ExploreRoutePlan plan) {
    final summary = plan.summary.toLowerCase();
    final looksLikeFailure = summary.contains('unable') ||
        summary.contains('not available') ||
        summary.contains('invalid') ||
        summary.contains('not enabled') ||
        summary.contains('failed');
    return !looksLikeFailure &&
        plan.orderedPlaceIds.isNotEmpty &&
        plan.totalDistanceKm > 0 &&
        plan.totalDurationMinutes > 0;
  }

  String _travelModeForEnergy() {
    return switch (energy) {
      EnergyLevel.high => 'walking',
      EnergyLevel.medium => 'walking',
      EnergyLevel.low => 'transit',
    };
  }

  String _poiMapsQuery(Poi poi) {
    return '${poi.lat},${poi.lng}';
  }

  String _readString(
    Map<String, dynamic>? data,
    String key, {
    required String fallback,
  }) {
    final value = data?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  List<String> _readInterestLabels(Object? value) {
    if (value is String) {
      return _splitInterestText(value);
    }
    if (value is! Iterable) {
      return const [];
    }

    return value
        .expand((item) => _splitInterestText(item.toString()))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _splitInterestText(String value) {
    return value
        .split(RegExp(r'[,，/、;；|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<PoiCategory> _readInterests(List<String> labels) {
    return labels
        .map((item) => item.trim().toLowerCase())
        .map(_categoryFromLabel)
        .whereType<PoiCategory>()
        .toSet()
        .toList();
  }

  PoiCategory? _categoryFromLabel(String value) {
    for (final category in PoiCategory.values) {
      final label = category.label.toLowerCase();
      if (label == value || category.name == value || value.contains(label)) {
        return category;
      }
    }
    return null;
  }

  EnergyLevel _energyFromLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('active') || normalized.contains('high')) {
      return EnergyLevel.high;
    }
    if (normalized.contains('medium')) {
      return EnergyLevel.medium;
    }
    return EnergyLevel.low;
  }

  @override
  void dispose() {
    _tripTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
