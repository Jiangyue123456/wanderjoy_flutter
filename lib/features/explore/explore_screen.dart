import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/dopamine_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'explore_controller.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExploreController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_controller.step) {
          ExploreStep.home => _home(context),
          ExploreStep.input => _input(context),
          ExploreStep.customize => _customize(context),
          ExploreStep.route => _route(context),
          ExploreStep.trip => _trip(context),
          ExploreStep.summary => _summary(context),
        },
      ),
    );
  }

  Widget _home(BuildContext context) {
    return ListView(
      key: const ValueKey('explore-home'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        Text(
          'Ready for a new little adventure?',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Explore your city at your own pace today.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Image.network(
                'https://picsum.photos/seed/wander/900/500',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 24,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT CITY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'London, UK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Start Exploring',
          icon: Icons.navigation_rounded,
          onPressed: () => _controller.goTo(ExploreStep.input),
        ),
      ],
    );
  }

  Widget _input(BuildContext context) {
    return ListView(
      key: const ValueKey('explore-input'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Customize Your Trip',
          onBack: () => _controller.goTo(ExploreStep.home),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _MiniLabel('Select Mode'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: RouteMode.values
              .map(
                (mode) => _PillChoice(
                  label: mode.label,
                  selected: _controller.mode == mode,
                  color: AppColors.primary,
                  onTap: () => _controller.setMode(mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Energy Level'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: EnergyLevel.values
              .map(
                (energy) => _PillChoice(
                  label: energy.label,
                  selected: _controller.energy == energy,
                  color: AppColors.secondary,
                  icon: Icons.bolt_rounded,
                  onTap: () => _controller.setEnergy(energy),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Interests'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: PoiCategory.values
              .map(
                (category) => _PillChoice(
                  label: category.label,
                  selected: _controller.interests.contains(category),
                  color: AppColors.accent,
                  selectedTextColor: AppColors.ink,
                  icon: Icons.favorite_rounded,
                  onTap: () => _controller.toggleInterest(category),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Generate Route',
          onPressed: _controller.generateInitialRoute,
        ),
      ],
    );
  }

  Widget _customize(BuildContext context) {
    final results = _controller.filteredSearchResults;
    return ListView(
      key: const ValueKey('explore-customize'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Edit Your Route',
          onBack: () => _controller.goTo(ExploreStep.input),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          onChanged: _controller.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search for more places...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _MiniLabel('Search Results'),
          const SizedBox(height: AppSpacing.sm),
          ...results.map(
            (poi) => _PoiRow(poi: poi, onAdd: () => _controller.addPoi(poi)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Current Stops'),
        const SizedBox(height: AppSpacing.sm),
        ..._controller.selectedPois.asMap().entries.map(
          (entry) => _PoiRow(
            poi: entry.value,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            onDelete: () => _controller.removePoi(entry.value.id),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Confirm Route',
          onPressed: () => _controller.goTo(ExploreStep.route),
        ),
      ],
    );
  }

  Widget _route(BuildContext context) {
    final pois = _controller.optimizedPois;
    return Stack(
      key: const ValueKey('explore-route'),
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.mapGrid,
            child: Stack(
              children: [
                for (final entry in pois.asMap().entries)
                  Positioned(
                    top: 90 + (entry.key % 3) * 90,
                    left: 36 + (entry.key % 4) * 76,
                    child: _MapBadge(
                      emoji: entry.value.emoji,
                      index: entry.key + 1,
                    ),
                  ),
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.route_rounded,
                      size: 120,
                      color: Color(0x22FF6B6B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 44,
          child: DopamineCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'The Optimized Wander',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Shortest Path',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${pois.length} stops • ${pois.length * 15} mins total',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 74,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pois.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1}. ${pois[index].emoji} ${pois[index].name}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pois[index].hours,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _controller.goTo(ExploreStep.customize),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Start Trip',
                        onPressed: () => _controller.goTo(ExploreStep.trip),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trip(BuildContext context) {
    final currentPoi = _controller.optimizedPois.isEmpty
        ? null
        : _controller.optimizedPois.first;
    return Stack(
      key: const ValueKey('explore-trip'),
      children: [
        Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT STOP',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPoi?.name ?? 'Adventure',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '0.4 km',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFF7F7F7)),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.route_rounded,
                        size: 120,
                        color: Color(0x18FF6B6B),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      _controller.userPosition.dx * 2 - 1,
                      _controller.userPosition.dy * 2 - 1,
                    ),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 40,
          child: _controller.activePoi == null
              ? DopamineCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.secondarySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Operating Hours',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentPoi?.hours ?? '--',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: currentPoi == null
                            ? null
                            : () => _controller.setActivePoi(currentPoi),
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Simulate Arriving'),
                      ),
                    ],
                  ),
                )
              : DopamineCard(
                  child: Column(
                    children: [
                      Text(
                        _controller.activePoi!.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You\'ve found a lovely spot!',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to ${_controller.activePoi!.name}. Would you like to save this moment?',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _controller.setActivePoi(null),
                              child: const Text('Maybe later'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Record',
                              icon: Icons.camera_alt_outlined,
                              onPressed: () =>
                                  _controller.goTo(ExploreStep.summary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    return ListView(
      key: const ValueKey('explore-summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        140,
      ),
      children: [
        const CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.secondarySoft,
          child: Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Adventure Complete!',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You explored ${(_controller.selectedPois.length * 0.8).toStringAsFixed(1)} km of London today.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${_controller.selectedPois.length}',
                label: 'Places Visited',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _StatCard(
                value: '1',
                label: 'Memories Saved',
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Finish & Save',
          onPressed: _controller.finishAndReset,
        ),
      ],
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class _PillChoice extends StatelessWidget {
  const _PillChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.selectedTextColor = Colors.white,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final Color selectedTextColor;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? color : const Color(0xFFF0F0F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? selectedTextColor : AppColors.muted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedTextColor : AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoiRow extends StatelessWidget {
  const _PoiRow({required this.poi, this.leading, this.onAdd, this.onDelete});

  final Poi poi;
  final Widget? leading;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DopamineCard(
        child: Row(
          children: [
            leading ?? Text(poi.emoji, style: const TextStyle(fontSize: 28)),
            if (leading != null) ...[
              const SizedBox(width: 14),
              Text(poi.emoji, style: const TextStyle(fontSize: 28)),
            ],
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poi.hours,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onAdd != null)
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.emoji, required this.index});

  final String emoji;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        Positioned(
          top: -8,
          right: -6,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary,
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DopamineCard(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
