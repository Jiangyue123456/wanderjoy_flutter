import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';

enum SocialStep {
  nearby,
  profile,
  request,
  setup,
  nfc,
  sharedExplore,
  edit,
  sharedTrip,
}

enum RequestStatus { none, sent, accepted, rejected }

class SocialController extends ChangeNotifier {
  SocialController() {
    unawaited(_loadCurrentLocation());
  }

  SocialStep step = SocialStep.nearby;
  UserProfile? selectedUser;
  RequestStatus requestStatus = RequestStatus.none;
  String meetingTime = '14:30';
  final Duration requestWaitDuration = const Duration(seconds: 8);
  final List<String> allMeetingTimeOptions = const [
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
  ];
  final List<String> meetingTimeOptions = const ['14:00', '14:30', '15:30'];
  final List<Poi> sharedPois = [];
  String searchQuery = '';
  bool nfcScanning = false;
  Offset userPosition = const Offset(0.30, 0.30);
  Offset buddyPosition = const Offset(0.35, 0.35);
  double currentLocationLat = 35.681236;
  double currentLocationLng = 139.767125;


  Timer? _sharedTripTimer;
  Timer? _requestTimer;
  Timer? _nfcTimer;
  final Random _random = Random();
  String? _sharedRouteId;

  String get meetingPoint => 'Nearby Cafe Meeting Spot';

  int get selectedUserTimeCount => meetingTimeOptions.length;

  ExploreTripContext get sharedExploreContext {
    final buddy = selectedUser;
    return ExploreTripContext(
      tripType: TripType.social,
      buddyId: buddy?.id,
      buddyName: buddy?.name,
      buddyAvatar: buddy?.avatar,
      buddyBio: buddy?.bio,
      buddyInterests: buddy?.interests ?? const [],
      buddyPreferredIntensity: buddy?.energyLevel,
      sharedRouteId: _sharedRouteId,
    );
  }

  List<UserProfile> get nearbyUsers => _rankLocalMatches(
    currentUserId: MockData.currentUserId,
    city: MockData.currentCity,
    nearbyCities: MockData.nearbyCities,
    interests: MockData.myInterests,
    preferredIntensity: MockData.preferredIntensity,
    bio: MockData.myBio,
  );

  List<Poi> get filteredSearchResults {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }

    return MockData.pois
        .where((poi) => poi.name.toLowerCase().contains(query))
        .where((poi) => !sharedPois.any((item) => item.id == poi.id))
        .toList();
  }

  void openProfile(UserProfile user) {
    selectedUser = user;
    step = SocialStep.profile;
    notifyListeners();
  }

  void goTo(SocialStep nextStep) {
    step = nextStep;
    if (step == SocialStep.sharedTrip) {
      _startSharedTripSimulation();
    } else {
      _sharedTripTimer?.cancel();
    }
    notifyListeners();
  }

  void sendRequest() {
    requestStatus = RequestStatus.sent;
    step = SocialStep.request;
    _requestTimer?.cancel();
    _requestTimer = Timer(requestWaitDuration, () {
      requestStatus = RequestStatus.accepted;
      notifyListeners();
    });
    notifyListeners();
  }

  void acceptRequest() {
    requestStatus = RequestStatus.accepted;
    notifyListeners();
  }

  void rejectRequest() {
    requestStatus = RequestStatus.rejected;
    notifyListeners();
  }

  void setMeetingPoint(String value) {
    notifyListeners();
  }

  void setMeetingTime(String value) {
    meetingTime = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void addPoi(Poi poi) {
    if (sharedPois.any((item) => item.id == poi.id)) {
      return;
    }
    sharedPois.add(poi);
    searchQuery = '';
    notifyListeners();
  }

  void removePoi(String id) {
    sharedPois.removeWhere((poi) => poi.id == id);
    notifyListeners();
  }

  void startNfcScan() {
    nfcScanning = true;
    notifyListeners();
    _nfcTimer?.cancel();
    _nfcTimer = Timer(const Duration(milliseconds: 2500), () {
      nfcScanning = false;
      sharedPois
        ..clear()
        ..addAll(MockData.pois.take(3));
      step = SocialStep.edit;
      notifyListeners();
    });
  }

  void startTripLaunch() {
    nfcScanning = true;
    _nfcTimer?.cancel();
    notifyListeners();
  }

  void openSharedExplore() {
    nfcScanning = false;
    _sharedRouteId ??=
        'shared-${MockData.currentUserId}-${selectedUser?.id ?? 'buddy'}-${DateTime.now().millisecondsSinceEpoch}';
    step = SocialStep.sharedExplore;
    notifyListeners();
  }

  void endSharedTrip() {
    _sharedTripTimer?.cancel();
    _requestTimer?.cancel();
    _nfcTimer?.cancel();
    selectedUser = null;
    requestStatus = RequestStatus.none;
    meetingTime = '14:30';
    sharedPois.clear();
    searchQuery = '';
    nfcScanning = false;
    _sharedRouteId = null;
    userPosition = const Offset(0.30, 0.30);
    buddyPosition = const Offset(0.35, 0.35);
    step = SocialStep.nearby;
    notifyListeners();
  }

  void _startSharedTripSimulation() {
    _sharedTripTimer?.cancel();
    _sharedTripTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      userPosition = Offset(
        _clamp(userPosition.dx + (_random.nextDouble() - 0.4) * 0.05),
        _clamp(userPosition.dy + (_random.nextDouble() - 0.4) * 0.05),
      );
      buddyPosition = Offset(
        _clamp(buddyPosition.dx + (_random.nextDouble() - 0.4) * 0.05),
        _clamp(buddyPosition.dy + (_random.nextDouble() - 0.4) * 0.05),
      );
      notifyListeners();
    });
  }

  double _clamp(double value) => value.clamp(0.1, 0.9);

  String meetingPointMapsUrl() {
    final query = Uri.encodeComponent('cafe near me');
    return 'https://www.google.com/maps/search/?api=1&query=$query&center=$currentLocationLat,$currentLocationLng';
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      currentLocationLat = position.latitude;
      currentLocationLng = position.longitude;
      notifyListeners();
    } catch (_) {
      // Keep the London fallback coordinates if location is unavailable.
    }
  }

  List<UserProfile> _rankLocalMatches({
    required String currentUserId,
    required String city,
    required List<String> nearbyCities,
    required List<PoiCategory> interests,
    required EnergyLevel preferredIntensity,
    required String bio,
  }) {
    final matches = MockData.users
        .where((user) => user.id != currentUserId)
        .toList(growable: false);

    matches.sort((left, right) {
      final rightScore = _localMatchScore(
        right,
        city,
        nearbyCities,
        interests,
        preferredIntensity,
        bio,
      );
      final leftScore = _localMatchScore(
        left,
        city,
        nearbyCities,
        interests,
        preferredIntensity,
        bio,
      );
      final scoreOrder = rightScore.compareTo(leftScore);
      if (scoreOrder != 0) {
        return scoreOrder;
      }

      final safetyOrder = right.safetyRating.compareTo(left.safetyRating);
      if (safetyOrder != 0) {
        return safetyOrder;
      }

      return left.distanceKm.compareTo(right.distanceKm);
    });

    return matches;
  }

  double _localMatchScore(
    UserProfile user,
    String city,
    List<String> nearbyCities,
    List<PoiCategory> interests,
    EnergyLevel preferredIntensity,
    String bio,
  ) {
    final cityScore = user.city == city
        ? 28.0
        : nearbyCities.contains(user.city)
        ? 20.0
        : 4.0;
    final sharedInterestCount = user.interests
        .where((interest) => interests.contains(interest))
        .length;
    final interestScore = sharedInterestCount * 14.0;
    final safetyScore = user.safetyRating * 5.0;
    final intensityScore =
        18.0 - (_intensityDistance(user.energyLevel, preferredIntensity) * 7.0);
    final baseScore = (user.paceMatch ?? 0) * 0.18;
    final bioScore = _bioOverlapScore(user.bio, bio);

    return cityScore + interestScore + safetyScore + intensityScore + baseScore + bioScore;
  }

  int _intensityDistance(EnergyLevel left, EnergyLevel right) {
    return (left.index - right.index).abs();
  }

  double _bioOverlapScore(String candidateBio, String currentBio) {
    final currentWords = _matchWords(currentBio);
    if (currentWords.isEmpty) {
      return 0;
    }
    final candidateWords = _matchWords(candidateBio);
    final overlapCount = candidateWords
        .where((word) => currentWords.contains(word))
        .length;
    return overlapCount.clamp(0, 5).toDouble() * 2.0;
  }

  Set<String> _matchWords(String text) {
    const ignoredWords = {
      'and',
      'are',
      'for',
      'that',
      'the',
      'where',
      'with',
    };

    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 3 && !ignoredWords.contains(word))
        .toSet();
  }

  @override
  void dispose() {
    _sharedTripTimer?.cancel();
    _requestTimer?.cancel();
    _nfcTimer?.cancel();
    super.dispose();
  }
}
