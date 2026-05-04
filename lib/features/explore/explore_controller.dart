import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../memory/memory_repository.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';
import 'explore_agent_service.dart';

enum ExploreStep { home, input, customize, route, trip, summary }

class ExploreController extends ChangeNotifier {
  ExploreController({
    this.exploreAgentService = const ExploreAgentService(),
    this.tripContext = const ExploreTripContext(),
    ExploreStep initialStep = ExploreStep.home,
  }) : step = initialStep {
    chatMessages.add(
      tripContext.isSocial
          ? 'AI: Tell me what you and ${tripContext.buddyName ?? 'your friend'} want to do together.'
          : 'AI: Let\'s talk about where you\'d like to go.',
    );
  }

  final ExploreAgentService exploreAgentService;
  final ExploreTripContext tripContext;

  ExploreStep step;
  RouteMode mode = RouteMode.relaxed;
  EnergyLevel energy = EnergyLevel.low;
  final List<PoiCategory> interests = List<PoiCategory>.from(MockData.myInterests);
  final List<String> profileInterestLabels = MockData.myInterests
      .map((interest) => interest.label)
      .toList();
  final List<Poi> selectedPois = [];
  final List<String> chatMessages = [];
  String searchQuery = '';
  String chatInput = '';
  String timeAvailable = 'Half day';
  String profileName = 'Explorer';
  String profileAvatar = '';
  String profileBio = MockData.myBio;
  String? conversationLanguage;
  bool isListening = false;
  bool isGeneratingPlaces = false;
  bool isSearchingPlaces = false;
  bool isPlanningRoute = false;
  String? exploreError;
  final List<Poi> searchResults = [];
  final Set<String> loadingPlaceDetailIds = {};
  final List<MemoryEntry> routeMemories = [];
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

  Poi? get navigationNextStop {
    if (optimizedPois.isEmpty) {
      return null;
    }
    final originLat = currentLocationLat;
    final originLng = currentLocationLng;
    if (originLat == null || originLng == null) {
      return optimizedPois.first;
    }

    for (final poi in optimizedPois) {
      final distance = _haversineKm(originLat, originLng, poi.lat, poi.lng);
      if (distance > 0.08) {
        return poi;
      }
    }
    return optimizedPois.last;
  }

  NavigationCue get navigationCue {
    final points = routePlan?.polylinePoints ?? const [];
    final originLat = currentLocationLat;
    final originLng = currentLocationLng;
    final fallbackStop = navigationNextStop;
    if (originLat == null || originLng == null) {
      return NavigationCue(
        icon: Icons.navigation_rounded,
        title: 'Follow the route',
        subtitle: fallbackStop?.name ?? 'Continue to the next stop',
      );
    }

    if (points.length < 4) {
      final stop = fallbackStop;
      final distance = stop == null ? null : distanceFromCurrentKm(stop);
      return NavigationCue(
        icon: Icons.arrow_upward_rounded,
        title: 'Head toward ${stop?.name ?? 'the route'}',
        subtitle: distance == null ? 'Follow the blue line' : '${distance.toStringAsFixed(1)} km away',
      );
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final distance = pow(point.lat - originLat, 2) + pow(point.lng - originLng, 2);
      if (distance < nearestDistance) {
        nearestDistance = distance.toDouble();
        nearestIndex = index;
      }
    }

    final nextIndex = min(nearestIndex + 3, points.length - 1);
    final futureIndex = min(nearestIndex + 8, points.length - 1);
    final firstBearing = _bearingDegrees(originLat, originLng, points[nextIndex].lat, points[nextIndex].lng);
    final secondBearing = _bearingDegrees(points[nextIndex].lat, points[nextIndex].lng, points[futureIndex].lat, points[futureIndex].lng);
    final delta = _bearingDelta(firstBearing, secondBearing);
    final stop = navigationNextStop;
    final distance = stop == null ? null : distanceFromCurrentKm(stop);
    final subtitle = stop == null
        ? 'Follow the blue route'
        : '${stop.name}${distance == null ? '' : ' - ${distance.toStringAsFixed(1)} km'}';

    if (delta > 35) {
      return NavigationCue(
        icon: Icons.turn_right_rounded,
        title: 'Turn right soon',
        subtitle: subtitle,
      );
    }
    if (delta < -35) {
      return NavigationCue(
        icon: Icons.turn_left_rounded,
        title: 'Turn left soon',
        subtitle: subtitle,
      );
    }
    return NavigationCue(
      icon: Icons.arrow_upward_rounded,
      title: 'Continue straight',
      subtitle: subtitle,
    );
  }

  double get navigationBearingDegrees {
    final points = routePlan?.polylinePoints ?? const [];
    final originLat = currentLocationLat;
    final originLng = currentLocationLng;
    if (originLat == null || originLng == null || points.length < 2) {
      return 0;
    }
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final distance = pow(point.lat - originLat, 2) + pow(point.lng - originLng, 2);
      if (distance < nearestDistance) {
        nearestDistance = distance.toDouble();
        nearestIndex = index;
      }
    }
    final nextIndex = min(nearestIndex + 4, points.length - 1);
    return _bearingDegrees(originLat, originLng, points[nextIndex].lat, points[nextIndex].lng);
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

  void saveRouteMemory({
    required String photoPath,
    required String note,
  }) {
    final now = DateTime.now();
    final stop = navigationNextStop;
    final locationName = stop?.name ?? currentLocationName;
    final isSocial = tripContext.isSocial;
    final buddyName = tripContext.buddyName;
    final memory = MemoryEntry(
      id: 'memory_${now.millisecondsSinceEpoch}',
      routeId:
          tripContext.sharedRouteId ??
          'route_${routePlan?.orderedPlaceIds.join('_') ?? now.millisecondsSinceEpoch}',
      userId: 'me',
      photo: photoPath,
      text: note.trim().isEmpty
          ? isSocial
                ? 'A shared moment from this WanderJoy route with $buddyName.'
                : 'A moment from this WanderJoy route.'
          : note.trim(),
      location: locationName,
      timestamp: _formatMemoryTimestamp(now),
      tripType: tripContext.tripType,
      title: isSocial && buddyName != null
          ? 'Shared memory with $buddyName at $locationName'
          : 'Explore memory at $locationName',
      lat: currentLocationLat,
      lng: currentLocationLng,
      participantIds: [
        'me',
        if (tripContext.buddyId != null) tripContext.buddyId!,
      ],
      participantNames: [
        profileName,
        if (buddyName != null) buddyName,
      ],
      buddyName: buddyName,
      buddyAvatar: tripContext.buddyAvatar,
      sharedRouteId: tripContext.sharedRouteId,
      routeSnapshot: _buildMemoryRouteSnapshot(
        photoPath: photoPath,
        note: note,
      ),
    );
    routeMemories.insert(0, memory);
    MemoryRepository.add(memory);
    notifyListeners();
  }

  MemoryRouteSnapshot _buildMemoryRouteSnapshot({
    required String photoPath,
    required String note,
  }) {
    final routePoints = routePlan?.polylinePoints
            .map((point) => MemoryRoutePoint(lat: point.lat, lng: point.lng))
            .toList() ??
        const <MemoryRoutePoint>[];
    final fallbackPoints = [
      if (navigationOriginLat != null && navigationOriginLng != null)
        MemoryRoutePoint(lat: navigationOriginLat!, lng: navigationOriginLng!),
      ...optimizedPois.map((poi) => MemoryRoutePoint(lat: poi.lat, lng: poi.lng)),
    ];
    final photos = [
      ...routeMemories.map(
        (memory) => MemoryRoutePhoto(
          path: memory.photo,
          text: memory.text,
          title: memory.title,
          timestamp: memory.timestamp,
          location: memory.location,
          lat: memory.lat,
          lng: memory.lng,
        ),
      ),
      MemoryRoutePhoto(
        path: photoPath,
        text: note.trim().isEmpty
            ? tripContext.isSocial
                ? 'A shared moment from this WanderJoy route with ${tripContext.buddyName}.'
                : 'A moment from this WanderJoy route.'
            : note.trim(),
        title: tripContext.isSocial && tripContext.buddyName != null
            ? 'Shared memory with ${tripContext.buddyName}'
            : 'Explore memory',
        timestamp: _formatMemoryTimestamp(DateTime.now()),
        location: navigationNextStop?.name ?? currentLocationName,
        lat: currentLocationLat,
        lng: currentLocationLng,
      ),
    ];

    return MemoryRouteSnapshot(
      title: tripContext.isSocial ? 'Shared route map' : 'Route map',
      durationMinutes: estimatedMinutes,
      stopCount: optimizedPois.length,
      points: routePoints.isEmpty ? fallbackPoints : routePoints,
      stops: optimizedPois
          .map(
            (poi) => MemoryRouteStop(
              name: poi.name,
              lat: poi.lat,
              lng: poi.lng,
            ),
          )
          .toList(),
      photos: photos,
    );
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

  void applyProfile(
    Map<String, dynamic>? data, {
    String? fallbackName,
    String? fallbackAvatar,
  }) {
    final nextName = _readString(data, 'displayName', fallback: fallbackName ?? 'Explorer');
    final nextAvatar = _readString(data, 'avatarUrl', fallback: fallbackAvatar ?? '');
    final nextBio = _readString(data, 'bio', fallback: MockData.myBio);
    final nextIntensity = _readString(data, 'preferredIntensity', fallback: 'Relaxed');
    final nextInterestLabels = _readInterestLabels(data?['interests']);
    final nextInterests = _readInterests(nextInterestLabels);
    final signature =
        '$nextName|$nextAvatar|$nextBio|$nextIntensity|${nextInterestLabels.join(',')}';

    if (_profileSignature == signature) {
      return;
    }

    profileName = nextName;
    profileAvatar = nextAvatar;
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
      ..add(
        tripContext.isSocial
            ? 'AI: Tell me what you and ${tripContext.buddyName ?? 'your friend'} want to do together.'
            : 'AI: Let\'s talk about where you\'d like to go.',
      );
    _profileSignature = signature;
    notifyListeners();
  }

  void startVoiceConversation() {
    isListening = true;
    chatMessages.add(
      tripContext.isSocial
          ? 'AI: I am listening. Tell me what both of you want, your shared pace, or anything either of you wants to avoid.'
          : 'AI: I am listening. Tell me your mood, time, or anything you want to avoid today.',
    );
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
      tripContext.isSocial
          ? 'AI: Got it. I will combine both profiles before recommending places.'
          : 'AI: Got it. I will combine that with your saved profile before recommending places.',
    );
    notifyListeners();
  }

  void addChatMessage() {
    final trimmed = chatInput.trim();
    if (trimmed.isEmpty) {
      return;
    }

    chatMessages.add('You: $trimmed');
    conversationLanguage ??= _detectConversationLanguage(trimmed);
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
      tripContext.isSocial
          ? 'AI: Got it. I will combine both profiles with what you just said before recommending places.'
          : 'AI: Got it. I will combine your profile with what you just said before recommending places.',
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
      conversationLanguage ??= _detectConversationLanguage(pendingInput);
      chatInput = '';
    }

    isGeneratingPlaces = true;
    exploreError = null;
    chatMessages.add('AI: I am checking places on Google Maps...');
    notifyListeners();

    try {
      final response = await exploreAgentService.recommend(
        inputAsText: _agentInputText(),
        userId: 'preview_user',
        profileInterests: _agentInterestLabels(),
        preferredIntensity: mode.name,
        profileBio: _agentProfileBio(),
        responseLanguage:
            conversationLanguage ?? _detectConversationLanguage(_latestUserInput()),
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
    if (tripContext.isSocial) {
      return 'We want to explore nearby places that match both of our interests.';
    }
    return 'I want to explore nearby places that match my interests.';
  }

  String _agentInputText() {
    final input = _latestUserInput();
    if (!tripContext.isSocial) {
      return input;
    }
    return [
      input,
      'This is a social trip with ${tripContext.buddyName ?? 'a friend'}. Recommend real places that work for both people.',
    ].join('\n');
  }

  List<String> _agentInterestLabels() {
    if (!tripContext.isSocial) {
      return profileInterestLabels;
    }
    return {
      ...profileInterestLabels,
      ...tripContext.buddyInterests.map((interest) => interest.label),
    }.toList();
  }

  String _agentProfileBio() {
    if (!tripContext.isSocial) {
      return profileBio;
    }
    return [
      'Me: $profileBio',
      if (tripContext.buddyName != null || tripContext.buddyBio != null)
        '${tripContext.buddyName ?? 'Friend'}: ${tripContext.buddyBio ?? ''}',
    ].join('\n');
  }

  String _detectConversationLanguage(String text) {
    final hasCjk = RegExp(r'[\u3400-\u9fff]').hasMatch(text);
    if (hasCjk) {
      return 'Chinese';
    }
    return 'English';
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

  double _radiansToDegrees(double value) => value * 180 / pi;

  double _bearingDegrees(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final lat1 = _degreesToRadians(startLat);
    final lat2 = _degreesToRadians(endLat);
    final dLng = _degreesToRadians(endLng - startLng);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (_radiansToDegrees(atan2(y, x)) + 360) % 360;
  }

  double _bearingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  String _formatMemoryTimestamp(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

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

class NavigationCue {
  const NavigationCue({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
