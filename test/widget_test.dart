import 'package:flutter_test/flutter_test.dart';
import 'package:wanderjoy_flutter/shared/data/mock_data.dart';
import 'package:wanderjoy_flutter/shared/models/app_models.dart';

void main() {
  test('mock data matches converted app structure', () {
    expect(MockData.pois, isNotEmpty);
    expect(MockData.users.length, 3);
    expect(MockData.memories.length, 2);
    expect(MockData.pois.first.category, PoiCategory.nature);
    expect(MockData.memories.first.tripType, TripType.explore);
  });
}
