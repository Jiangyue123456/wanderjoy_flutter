import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';

enum SocialStep { nearby, profile, request, setup, nfc, edit, sharedTrip }

enum RequestStatus { none, sent, accepted, rejected }

class SocialController extends ChangeNotifier {
  SocialStep step = SocialStep.nearby;
  UserProfile? selectedUser;
  RequestStatus requestStatus = RequestStatus.none;
  String meetingPoint = 'Art Alley Entrance';
  String meetingTime = '14:30';
  final List<Poi> sharedPois = [];
  String searchQuery = '';
  bool nfcScanning = false;
  Offset userPosition = const Offset(0.30, 0.30);
  Offset buddyPosition = const Offset(0.35, 0.35);

  Timer? _sharedTripTimer;
  Timer? _requestTimer;
  Timer? _nfcTimer;
  final Random _random = Random();

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
    _requestTimer = Timer(const Duration(seconds: 2), () {
      requestStatus = RequestStatus.accepted;
      notifyListeners();
    });
    notifyListeners();
  }

  void acceptRequest() {
    requestStatus = RequestStatus.accepted;
    notifyListeners();
  }

  void setMeetingPoint(String value) {
    meetingPoint = value;
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

  void endSharedTrip() {
    _sharedTripTimer?.cancel();
    _requestTimer?.cancel();
    _nfcTimer?.cancel();
    selectedUser = null;
    requestStatus = RequestStatus.none;
    meetingPoint = 'Art Alley Entrance';
    meetingTime = '14:30';
    sharedPois.clear();
    searchQuery = '';
    nfcScanning = false;
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

  @override
  void dispose() {
    _sharedTripTimer?.cancel();
    _requestTimer?.cancel();
    _nfcTimer?.cancel();
    super.dispose();
  }
}
