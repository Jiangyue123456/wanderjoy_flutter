import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/dopamine_card.dart';
import 'memory_repository.dart';

const _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  MemoryEntry? _selectedMemory;
  TripType _activeMemoryType = TripType.explore;

  List<UserProfile> _travelCompanions(List<MemoryEntry> memories) {
    final companionNames = memories
        .where((memory) => memory.tripType == TripType.social)
        .expand(
          (memory) => [
            if (memory.buddyName != null) memory.buddyName!,
            ...memory.participantNames.where((name) => name != 'me'),
          ],
        )
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final matched = MockData.users
        .where((user) => companionNames.contains(user.name.toLowerCase()))
        .toList();
    return matched;
  }

  void _showCompanionProfile(UserProfile user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.network(
                      user.avatar,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.travelStyle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        _MiniProfileStat(
                          label: '${user.safetyRating.toStringAsFixed(1)} safety',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(user.bio, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.interests
                    .map((interest) => _MiniProfileStat(label: interest.label))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening message to ${user.name}')),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _routeMemoryTitle(MemoryEntry memory) {
    if (memory.tripType == TripType.social && memory.buddyName != null) {
      return 'Shared route with ${memory.buddyName}';
    }
    return 'Explore route memory';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MemoryEntry>>(
      valueListenable: MemoryRepository.memories,
      builder: (context, memories, _) {
        final visibleMemories = memories
            .where((memory) => memory.tripType == _activeMemoryType)
            .toList();
        final companions = _travelCompanions(memories);
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                140,
              ),
              children: [
                Text(
                  'Your Memories',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Relive your past adventures and connections.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: _MemoryStat(
                        value: '${memories.length}',
                        label: 'Total Trips',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MemoryStat(
                        value:
                            '${memories.where((memory) => memory.tripType == TripType.explore).length}',
                        label: 'Explore Trips',
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _MemoryTypeSwitch(
                  activeType: _activeMemoryType,
                  exploreCount: memories
                      .where((memory) => memory.tripType == TripType.explore)
                      .length,
                  socialCount: memories
                      .where((memory) => memory.tripType == TripType.social)
                      .length,
                  onChanged: (type) => setState(() {
                    _activeMemoryType = type;
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_activeMemoryType == TripType.social) ...[
                  Text(
                    'Travel Companions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (companions.isEmpty)
                    const _EmptyMemoryCard(
                      icon: Icons.people_outline_rounded,
                      title: 'No companions yet',
                      message: 'Social route memories will show people you traveled with.',
                    )
                  else
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: companions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final user = companions[index];
                          return GestureDetector(
                            onTap: () => _showCompanionProfile(user),
                            child: SizedBox(
                              width: 90,
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.network(
                                      user.avatar,
                                      width: 82,
                                      height: 82,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    user.name,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  _activeMemoryType == TripType.explore
                      ? 'Explore Memories'
                      : 'Social Memories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (visibleMemories.isEmpty)
                  _EmptyMemoryCard(
                    icon: _activeMemoryType == TripType.explore
                        ? Icons.explore_outlined
                        : Icons.groups_rounded,
                    title: _activeMemoryType == TripType.explore
                        ? 'No explore memories yet'
                        : 'No social memories yet',
                    message: _activeMemoryType == TripType.explore
                        ? 'Photos saved during solo navigation will appear here.'
                        : 'Photos saved during shared routes will appear here.',
                  )
                else
                  ...visibleMemories.map(
                    (memory) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DopamineCard(
                        padding: EdgeInsets.zero,
                        onTap: () => setState(() => _selectedMemory = memory),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                              child: _MemoryPhoto(
                                path: memory.photo,
                                width: double.infinity,
                                height: 170,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    memory.title,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    memory.tripType == TripType.social &&
                                            memory.buddyName != null
                                        ? 'Social with ${memory.buddyName} - ${memory.location}'
                                        : '${memory.tripType.label} - ${memory.location}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_selectedMemory != null)
              Positioned.fill(
                child: Material(
                  color: Colors.white,
                  child: SafeArea(
                    child: ListView(
                      children: [
                        _selectedMemory!.routeSnapshot == null
                            ? _MemoryPhotoHero(
                                memory: _selectedMemory!,
                                onBack: () =>
                                    setState(() => _selectedMemory = null),
                              )
                            : _MemoryNavigationSnapshotHero(
                                memory: _selectedMemory!,
                                onBack: () =>
                                    setState(() => _selectedMemory = null),
                              ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMemory!.routeSnapshot == null
                                    ? _selectedMemory!.title
                                    : _routeMemoryTitle(_selectedMemory!),
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              if (_selectedMemory!.routeSnapshot == null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _selectedMemory!.tripType ==
                                              TripType.social &&
                                          _selectedMemory!.buddyName != null
                                      ? '${_selectedMemory!.timestamp} - with ${_selectedMemory!.buddyName} - ${_selectedMemory!.location}'
                                      : '${_selectedMemory!.timestamp} - ${_selectedMemory!.location}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F7F7),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Text(
                                    '"${_selectedMemory!.text}"',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.muted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '${_selectedMemory!.routeSnapshot!.stopCount} stops  |  ${_selectedMemory!.routeSnapshot!.durationMinutes} mins',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Places visited',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ..._selectedMemory!.routeSnapshot!.stops
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundColor:
                                                  AppColors.primary,
                                              child: Text(
                                                '${entry.key + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                entry.value.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MemoryTypeSwitch extends StatelessWidget {
  const _MemoryTypeSwitch({
    required this.activeType,
    required this.exploreCount,
    required this.socialCount,
    required this.onChanged,
  });

  final TripType activeType;
  final int exploreCount;
  final int socialCount;
  final ValueChanged<TripType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MemoryTypeButton(
              label: 'Explore',
              count: exploreCount,
              icon: Icons.explore_outlined,
              selected: activeType == TripType.explore,
              onTap: () => onChanged(TripType.explore),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MemoryTypeButton(
              label: 'Social',
              count: socialCount,
              icon: Icons.groups_rounded,
              selected: activeType == TripType.social,
              onTap: () => onChanged(TripType.social),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTypeButton extends StatelessWidget {
  const _MemoryTypeButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$label ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? AppColors.ink : AppColors.muted,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMemoryCard extends StatelessWidget {
  const _EmptyMemoryCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DopamineCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryPhotoHero extends StatelessWidget {
  const _MemoryPhotoHero({
    required this.memory,
    required this.onBack,
  });

  final MemoryEntry memory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _MemoryPhoto(
          path: memory.photo,
          width: double.infinity,
          height: 320,
        ),
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          child: _MemoryBackButton(onPressed: onBack),
        ),
      ],
    );
  }
}

class _MemoryNavigationSnapshotHero extends StatelessWidget {
  const _MemoryNavigationSnapshotHero({
    required this.memory,
    required this.onBack,
  });

  final MemoryEntry memory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final snapshot = memory.routeSnapshot!;
    return SizedBox(
      height: 560,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _showRouteSnapshotDialog(context, snapshot),
              child: _MemoryRouteMap(
                snapshot: snapshot,
                onPhotoTap: (photo) => _showMemoryPhotoDetails(context, photo),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            child: _MemoryBackButton(onPressed: onBack),
          ),
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('LIVE', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMemoryPhotoRail extends StatelessWidget {
  const _RouteMemoryPhotoRail({required this.photos});

  final List<MemoryRoutePhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => _showMemoryPhotoDetails(context, photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _MemoryPhoto(
                path: photo.path,
                width: 72,
                height: 72,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemoryBackButton extends StatelessWidget {
  const _MemoryBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        elevation: 6,
      ),
    );
  }
}

void _showRouteSnapshotDialog(
  BuildContext context,
  MemoryRouteSnapshot snapshot,
) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (context) => SafeArea(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: AspectRatio(
                aspectRatio: 0.72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _MemoryRouteMap(snapshot: snapshot),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMemoryPhotoDialog(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (context) => SafeArea(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Builder(
                builder: (context) {
                  final size = MediaQuery.sizeOf(context);
                  return _MemoryPhoto(
                    path: path,
                    width: size.width,
                    height: size.height,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMemoryPhotoDetails(BuildContext context, MemoryRoutePhoto photo) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showMemoryPhotoDialog(context, photo.path),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _MemoryPhoto(
                  path: photo.path,
                  width: double.infinity,
                  height: 320,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(photo.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '"${photo.text}"',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${photo.timestamp} - ${photo.location}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MiniProfileStat extends StatelessWidget {
  const _MiniProfileStat({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MemoryRouteSnapshotCard extends StatelessWidget {
  const _MemoryRouteSnapshotCard({required this.snapshot});

  final MemoryRouteSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                snapshot.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${snapshot.stopCount} stops | ${snapshot.durationMinutes} mins',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: () => _showRouteSnapshotDialog(context, snapshot),
          child: Hero(
            tag: 'memory-route-${identityHashCode(snapshot)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: _MemoryRouteMap(snapshot: snapshot),
              ),
            ),
          ),
        ),
        if (snapshot.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = snapshot.photos[index];
                return GestureDetector(
                  onTap: () => _showPhotoDialog(context, photo.path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _MemoryPhoto(
                      path: photo.path,
                      width: 74,
                      height: 74,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _showRouteSnapshotDialog(
    BuildContext context,
    MemoryRouteSnapshot snapshot,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) => SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'memory-route-${identityHashCode(snapshot)}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _MemoryRouteMap(snapshot: snapshot),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Builder(
                  builder: (context) {
                    final size = MediaQuery.sizeOf(context);
                    return _MemoryPhoto(
                      path: path,
                      width: size.width,
                      height: size.height,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryRouteMap extends StatelessWidget {
  const _MemoryRouteMap({
    required this.snapshot,
    this.onPhotoTap,
  });

  final MemoryRouteSnapshot snapshot;
  final ValueChanged<MemoryRoutePhoto>? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    if (_googleMapsApiKey.trim().isNotEmpty &&
        (Platform.isAndroid || Platform.isIOS)) {
      return _MemoryGoogleRouteMap(
        snapshot: snapshot,
        onPhotoTap: onPhotoTap,
      );
    }

    return CustomPaint(
      painter: _MemoryRoutePainter(snapshot),
      child: Stack(
        children: [
          for (final entry in snapshot.photos.asMap().entries)
            if (entry.value.lat != null && entry.value.lng != null)
              _PositionedMemoryPhoto(
                snapshot: snapshot,
                photo: entry.value,
                index: entry.key,
                onTap: onPhotoTap == null
                    ? null
                    : () => onPhotoTap!(entry.value),
              ),
        ],
      ),
    );
  }
}

class _MemoryGoogleRouteMap extends StatefulWidget {
  const _MemoryGoogleRouteMap({
    required this.snapshot,
    required this.onPhotoTap,
  });

  final MemoryRouteSnapshot snapshot;
  final ValueChanged<MemoryRoutePhoto>? onPhotoTap;

  @override
  State<_MemoryGoogleRouteMap> createState() => _MemoryGoogleRouteMapState();
}

class _MemoryGoogleRouteMapState extends State<_MemoryGoogleRouteMap> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE7F0EC))
      ..addJavaScriptChannel(
        'WanderJoyMemory',
        onMessageReceived: (message) {
          final text = message.message;
          if (!text.startsWith('photo:')) {
            return;
          }
          final index = int.tryParse(text.substring(6));
          if (index == null ||
              index < 0 ||
              index >= widget.snapshot.photos.length) {
            return;
          }
          widget.onPhotoTap?.call(widget.snapshot.photos[index]);
        },
      )
      ..loadHtmlString(_mapHtml(widget.snapshot));
  }

  @override
  void didUpdateWidget(covariant _MemoryGoogleRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      _controller.loadHtmlString(_mapHtml(widget.snapshot));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      },
    );
  }

  String _mapHtml(MemoryRouteSnapshot snapshot) {
    final points = snapshot.points
        .map((point) => {'lat': point.lat, 'lng': point.lng})
        .toList();
    final stops = snapshot.stops.asMap().entries.map((entry) {
      final stop = entry.value;
      return {
        'index': entry.key + 1,
        'name': stop.name,
        'lat': stop.lat,
        'lng': stop.lng,
      };
    }).toList();
    final photos = snapshot.photos.asMap().entries.map((entry) {
      final photo = entry.value;
      return {
        'index': entry.key,
        'lat': photo.lat,
        'lng': photo.lng,
        'src': _photoSrc(photo.path),
        'title': photo.title,
      };
    }).where((photo) => photo['lat'] != null && photo['lng'] != null).toList();
    final center = points.isNotEmpty
        ? points.first
        : stops.isNotEmpty
            ? {'lat': stops.first['lat'], 'lng': stops.first['lng']}
            : {'lat': 51.5072, 'lng': -0.1276};

    return '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>
      html, body, #map {
        height: 100%;
        width: 100%;
        margin: 0;
        padding: 0;
        overflow: hidden;
        background: #e7f0ec;
        font-family: Arial, sans-serif;
      }
      .stop-label {
        align-items: center;
        background: rgba(255,255,255,.96);
        border: 1px solid #eeeeee;
        border-radius: 16px;
        box-shadow: 0 8px 18px rgba(0,0,0,.18);
        color: #2f2f2f;
        display: flex;
        font-size: 13px;
        font-weight: 800;
        max-width: 210px;
        overflow: hidden;
        padding: 7px 10px;
        white-space: nowrap;
      }
      .stop-label b {
        background: #c73d4a;
        border-radius: 999px;
        color: white;
        display: inline-block;
        flex: 0 0 28px;
        height: 28px;
        line-height: 28px;
        margin-right: 7px;
        min-width: 28px;
        text-align: center;
        width: 28px;
      }
      .stop-label span {
        display: block;
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .photo-pin {
        align-items: center;
        background: #ffffff;
        border: 4px solid #ffffff;
        border-radius: 18px;
        box-shadow: 0 8px 18px rgba(0,0,0,.26);
        cursor: pointer;
        display: flex;
        height: 58px;
        justify-content: center;
        overflow: hidden;
        width: 58px;
      }
      .photo-pin img {
        height: 100%;
        object-fit: cover;
        width: 100%;
      }
      .you-dot {
        background: #1a73e8;
        border: 5px solid white;
        border-radius: 999px;
        box-shadow: 0 6px 14px rgba(0,0,0,.24);
        height: 28px;
        width: 28px;
      }
    </style>
    <script src="https://maps.googleapis.com/maps/api/js?key=$_googleMapsApiKey&callback=initMap" async defer></script>
    <script>
      const center = ${jsonEncode(center)};
      const points = ${jsonEncode(points)};
      const stops = ${jsonEncode(stops)};
      const photos = ${jsonEncode(photos)};

      function initMap() {
        const map = new google.maps.Map(document.getElementById('map'), {
          center,
          zoom: 14,
          disableDefaultUI: true,
          mapTypeControl: false,
          zoomControl: false,
          panControl: false,
          rotateControl: false,
          scaleControl: false,
          fullscreenControl: false,
          streetViewControl: false,
          keyboardShortcuts: false,
          clickableIcons: false,
          gestureHandling: 'greedy'
        });

        const bounds = new google.maps.LatLngBounds();
        points.forEach((point) => bounds.extend(point));
        stops.forEach((stop) => bounds.extend({ lat: stop.lat, lng: stop.lng }));
        photos.forEach((photo) => bounds.extend({ lat: photo.lat, lng: photo.lng }));

        if (points.length > 1) {
          new google.maps.Polyline({
            path: points,
            map,
            clickable: false,
            geodesic: false,
            strokeColor: '#ffffff',
            strokeOpacity: 0.94,
            strokeWeight: 10,
            zIndex: 20
          });
          new google.maps.Polyline({
            path: points,
            map,
            clickable: false,
            geodesic: false,
            strokeColor: '#2563eb',
            strokeOpacity: 0.92,
            strokeWeight: 6,
            zIndex: 21
          });
        }

        if (points.length) {
          createMapLabel(map, points[0], '<div class="you-dot"></div>');
        }
        stops.forEach((stop) => {
          createMapLabel(
            map,
            { lat: stop.lat, lng: stop.lng },
            '<div class="stop-label"><b>' + stop.index + '</b><span>' + escapeHtml(stop.name) + '</span></div>'
          );
        });
        photos.forEach((photo) => {
          createMapLabel(
            map,
            { lat: photo.lat, lng: photo.lng },
            '<div class="photo-pin"><img src="' + photo.src + '" alt=""></div>',
            () => {
              if (window.WanderJoyMemory) {
                window.WanderJoyMemory.postMessage('photo:' + photo.index);
              }
            }
          );
        });

        if (!bounds.isEmpty()) {
          map.fitBounds(bounds, {
            top: 112,
            right: 28,
            bottom: 240,
            left: 28
          });
        }
      }

      function createMapLabel(map, position, html, onClick) {
        class LabelOverlay extends google.maps.OverlayView {
          constructor() {
            super();
            this.position = new google.maps.LatLng(position.lat, position.lng);
            this.div = null;
          }
          onAdd() {
            this.div = document.createElement('div');
            this.div.style.position = 'absolute';
            this.div.style.cursor = onClick ? 'pointer' : 'default';
            this.div.style.transform = 'translate(-50%, -100%)';
            this.div.innerHTML = html;
            if (onClick) {
              this.div.addEventListener('click', onClick);
            }
            this.getPanes().overlayMouseTarget.appendChild(this.div);
          }
          draw() {
            const point = this.getProjection().fromLatLngToDivPixel(this.position);
            if (point && this.div) {
              this.div.style.left = point.x + 'px';
              this.div.style.top = point.y + 'px';
            }
          }
          onRemove() {
            if (this.div) {
              this.div.remove();
              this.div = null;
            }
          }
        }
        new LabelOverlay().setMap(map);
      }

      function escapeHtml(value) {
        return String(value)
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;')
          .replace(/'/g, '&#039;');
      }
    </script>
  </head>
  <body>
    <div id="map"></div>
  </body>
</html>
''';
  }

  String _photoSrc(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return '';
      }
      return 'data:image/jpeg;base64,${base64Encode(file.readAsBytesSync())}';
    } on Object {
      return '';
    }
  }
}

class _PositionedMemoryPhoto extends StatelessWidget {
  const _PositionedMemoryPhoto({
    required this.snapshot,
    required this.photo,
    required this.index,
    this.onTap,
  });

  final MemoryRouteSnapshot snapshot;
  final MemoryRoutePhoto photo;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final point = _project(
          photo.lat!,
          photo.lng!,
          Size(constraints.maxWidth, constraints.maxHeight),
          snapshot,
        );
        const size = 48.0;
        return Positioned(
          left: (point.dx - size / 2).clamp(
            8.0,
            constraints.maxWidth - size - 8,
          ),
          top: (point.dy - size).clamp(54.0, constraints.maxHeight - size - 8),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: _MemoryPhoto(
                  path: photo.path,
                  width: size,
                  height: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MemoryRoutePainter extends CustomPainter {
  const _MemoryRoutePainter(this.snapshot);

  final MemoryRouteSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE7F0EC);
    canvas.drawRect(Offset.zero & size, background);

    final parkPaint = Paint()..color = const Color(0xFFCFE7D8);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.08, size.width * 0.58,
          size.height * 0.54),
      parkPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.48, size.height * 0.30, size.width * 0.55,
          size.height * 0.48),
      parkPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 2;
    for (var x = -size.width; x < size.width * 2; x += 48) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * 0.72, size.height),
        roadPaint,
      );
    }
    for (var y = 24.0; y < size.height; y += 58) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 22), roadPaint);
    }

    final points = _routePoints(size);
    if (points.length >= 2) {
      final shadowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke;
      final routePaint = Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, routePaint);
    }

    if (points.isNotEmpty) {
      canvas.drawCircle(points.first, 9, Paint()..color = Colors.blue);
      canvas.drawCircle(
        points.first,
        14,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    for (var index = 0; index < snapshot.stops.length; index++) {
      final stop = snapshot.stops[index];
      final point = _project(stop.lat, stop.lng, size, snapshot);
      canvas.drawCircle(point, 15, Paint()..color = AppColors.primary);
      canvas.drawCircle(
        point,
        19,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(point.dx - label.width / 2, point.dy - label.height / 2),
      );
    }
  }

  List<Offset> _routePoints(Size size) {
    if (snapshot.points.isEmpty) {
      return const [];
    }
    return snapshot.points
        .map((point) => _project(point.lat, point.lng, size, snapshot))
        .toList();
  }

  @override
  bool shouldRepaint(covariant _MemoryRoutePainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}

Offset _project(
  double lat,
  double lng,
  Size size,
  MemoryRouteSnapshot snapshot,
) {
  final lats = [
    ...snapshot.points.map((point) => point.lat),
    ...snapshot.stops.map((stop) => stop.lat),
    ...snapshot.photos.map((photo) => photo.lat).whereType<double>(),
  ];
  final lngs = [
    ...snapshot.points.map((point) => point.lng),
    ...snapshot.stops.map((stop) => stop.lng),
    ...snapshot.photos.map((photo) => photo.lng).whereType<double>(),
  ];
  if (lats.isEmpty || lngs.isEmpty) {
    return Offset(size.width / 2, size.height / 2);
  }

  final minLat = lats.reduce((a, b) => a < b ? a : b);
  final maxLat = lats.reduce((a, b) => a > b ? a : b);
  final minLng = lngs.reduce((a, b) => a < b ? a : b);
  final maxLng = lngs.reduce((a, b) => a > b ? a : b);
  final latSpan = (maxLat - minLat).abs() < 0.0001 ? 0.01 : maxLat - minLat;
  final lngSpan = (maxLng - minLng).abs() < 0.0001 ? 0.01 : maxLng - minLng;
  final x = ((lng - minLng) / lngSpan).clamp(0.10, 0.90) * size.width;
  final y = (1 - ((lat - minLat) / latSpan).clamp(0.14, 0.86)) * size.height;
  return Offset(x, y);
}

class _MemoryPhoto extends StatelessWidget {
  const _MemoryPhoto({
    required this.path,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
    );
  }
}

class _MemoryStat extends StatelessWidget {
  const _MemoryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
