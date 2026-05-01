import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';

enum ExploreStep { home, input, customize, route, trip, summary }

class ExploreController extends ChangeNotifier {
  ExploreStep step = ExploreStep.home;
  RouteMode mode = RouteMode.relaxed;
  EnergyLevel energy = EnergyLevel.medium;
  final List<PoiCategory> interests = [PoiCategory.nature];
  final List<Poi> selectedPois = [];
  final List<String> chatMessages = [
    'AI: What kind of place sounds good today: nature, culture, food, arts, or something else?',
  ];
  String searchQuery = '';
  String chatInput = '';
  String moodNote = 'Quiet places preferred';
  String timeAvailable = 'Half day';
  Poi? activePoi;
  Offset userPosition = const Offset(0.40, 0.40);

  Timer? _tripTimer;
  final Random _random = Random();

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
      moodNote = 'Relaxed and quiet';
      setEnergy(EnergyLevel.low);
    } else if (lower.contains('active') ||
        lower.contains('walk') ||
        lower.contains('energetic')) {
      moodNote = 'Ready to walk more';
      setEnergy(EnergyLevel.high);
    }
    if (lower.contains('hour')) {
      timeAvailable = 'About 1 hour';
    } else if (lower.contains('half')) {
      timeAvailable = 'Half day';
    }
    chatMessages.add(
      'AI: Got it. I will use your interests, ${energy.label.toLowerCase()} intensity, and "$moodNote" to recommend places.',
    );
    chatInput = '';
    notifyListeners();
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

  void generateInitialRoute() {
    final filtered = MockData.pois
        .where((poi) => interests.contains(poi.category))
        .toList();
    final count = switch (energy) {
      EnergyLevel.low => 2,
      EnergyLevel.medium => 3,
      EnergyLevel.high => 5,
    };
    selectedPois
      ..clear()
      ..addAll((filtered.isEmpty ? MockData.pois : filtered).take(count));
    step = ExploreStep.customize;
    notifyListeners();
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

  @override
  void dispose() {
    _tripTimer?.cancel();
    super.dispose();
  }
}
