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
  final TextEditingController _chatTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ExploreController();
  }

  @override
  void dispose() {
    _chatTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendChat() {
    _controller.addChatMessage();
    _chatTextController.clear();
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
          ExploreStep.customize => _preview(context),
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
        Text('Explore Mode', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'AI recommends places, you confirm the stops, then WanderJoy builds a route.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Image.network(
                'https://picsum.photos/seed/wander-route/900/520',
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
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERSONAL EXPLORATION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'AI places -> route -> start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
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
          label: 'Chat With AI',
          icon: Icons.auto_awesome_rounded,
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
          title: 'AI Chat Input',
          onBack: () => _controller.goTo(ExploreStep.home),
        ),
        const SizedBox(height: AppSpacing.lg),
        DopamineCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final message in _controller.chatMessages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.startsWith('AI:')
                          ? AppColors.ink
                          : AppColors.primary,
                    ),
                  ),
                ),
              TextField(
                controller: _chatTextController,
                onChanged: _controller.setChatInput,
                onSubmitted: (_) => _sendChat(),
                decoration: InputDecoration(
                  hintText: 'Interests, mood, time, special preferences...',
                  suffixIcon: IconButton(
                    onPressed: _sendChat,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ],
          ),
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
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Travel Intensity'),
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
                  icon: Icons.directions_walk_rounded,
                  onTap: () => _controller.setMode(mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _ContextChip(
                icon: Icons.psychology_alt_outlined,
                label: _controller.moodNote,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContextChip(
                icon: Icons.schedule_rounded,
                label: _controller.timeAvailable,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Recommend Places',
          icon: Icons.travel_explore_rounded,
          onPressed: _controller.generateInitialRoute,
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final results = _controller.filteredSearchResults;
    return ListView(
      key: const ValueKey('explore-preview'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Preview Places',
          onBack: () => _controller.goTo(ExploreStep.input),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          onChanged: _controller.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search and manually add a place...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
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
        Row(
          children: [
            const Expanded(child: _MiniLabel('Recommended POIs')),
            TextButton.icon(
              onPressed: _controller.generateInitialRoute,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Adjust'),
            ),
          ],
        ),
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
          label: 'Confirm Places',
          onPressed: _controller.selectedPois.isEmpty
              ? null
              : () => _controller.goTo(ExploreStep.route),
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
                    top: 80 + (entry.key % 3) * 94,
                    left: 30 + (entry.key % 4) * 78,
                    child: _MapBadge(label: entry.value.emoji, index: entry.key + 1),
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
                        'Generated Route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _SmallBadge('Shortest Path'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${pois.length} stops - ${_controller.totalDistanceKm.toStringAsFixed(1)} km - ${_controller.estimatedMinutes} mins',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pois.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => Container(
                      width: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${index + 1}. ${pois[index].name}'),
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
                        label: 'Start Navigation',
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
                          currentPoi?.name ?? 'Exploration route',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_controller.totalDistanceKm.toStringAsFixed(1)} km',
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
          child: DopamineCard(
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
                        Icons.my_location_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Real-time tracking is active. During-trip memory prompts can be added later.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _controller.finishAndReset,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Trip'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    return const SizedBox.shrink(key: ValueKey('explore-summary'));
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border),
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

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DopamineCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
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
            leading ??
                CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Text(poi.emoji),
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          poi.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                      Text(
                        poi.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poi.reason,
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
  const _MapBadge({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
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

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
