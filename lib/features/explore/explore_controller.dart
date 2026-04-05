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
  String searchQuery = '';
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
    notifyListeners();
  }

  void setEnergy(EnergyLevel value) {
    energy = value;
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
      EnergyLevel.medium => 4,
      EnergyLevel.high => 6,
    };
    selectedPois
      ..clear()
      ..addAll(filtered.take(count));
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
