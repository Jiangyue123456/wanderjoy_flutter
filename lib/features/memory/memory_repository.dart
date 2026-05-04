import 'package:flutter/foundation.dart';

import '../../shared/models/app_models.dart';

class MemoryRepository {
  MemoryRepository._();

  static final ValueNotifier<List<MemoryEntry>> memories =
      ValueNotifier<List<MemoryEntry>>(<MemoryEntry>[]);

  static void add(MemoryEntry memory) {
    memories.value = [memory, ...memories.value];
  }
}
