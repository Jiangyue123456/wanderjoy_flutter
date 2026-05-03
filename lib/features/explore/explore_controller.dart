import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  String? exploreError;
  Poi? activePoi;
  Offset userPosition = const Offset(0.40, 0.40);
  double? currentLocationLat = 51.544;
  double? currentLocationLng = -0.009;
  String currentLocationName = 'Stratford E20 1LZ London';

  Timer? _tripTimer;
  final Random _random = Random();
  String? _profileSignature;

  List<Poi> get optimizedPois {
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

  int get estimatedMinutes {
    final base = switch (energy) {
      EnergyLevel.low => 24,
      EnergyLevel.medium => 18,
      EnergyLevel.high => 14,
    };
    return (optimizedPois.length * base + totalDistanceKm * 12).round();
  }

  List<Poi> get filteredSearchResults {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }

    return MockData.pois
        .where((poi) => poi.name.toLowerCase().contains(query))
        .where((poi) => !selectedPois.any((item) => item.id == poi.id))
        .toList();
  }

  void goTo(ExploreStep nextStep) {
    step = nextStep;
    if (step == ExploreStep.trip) {
      _startTripSimulation();
    } else {
      _tripTimer?.cancel();
    }
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
    searchQuery = '';
    notifyListeners();
  }

  void removePoi(String id) {
    selectedPois.removeWhere((poi) => poi.id == id);
    notifyListeners();
  }

  void setActivePoi(Poi? poi) {
    activePoi = poi;
    notifyListeners();
  }

  void finishAndReset() {
    _tripTimer?.cancel();
    step = ExploreStep.home;
    searchQuery = '';
    activePoi = null;
    userPosition = const Offset(0.40, 0.40);
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
    super.dispose();
  }
}
