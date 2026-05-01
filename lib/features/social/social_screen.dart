import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/dopamine_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'social_controller.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  late final SocialController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SocialController();
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
          SocialStep.nearby => _nearby(context),
          SocialStep.profile => _profile(context),
          SocialStep.request => _request(context),
          SocialStep.setup => _setup(context),
          SocialStep.nfc => _nfc(context),
          SocialStep.edit => _edit(context),
          SocialStep.sharedTrip => _sharedTrip(context),
        },
      ),
    );
  }

  Widget _nearby(BuildContext context) {
    return ListView(
      key: const ValueKey('social-nearby'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        Text(
          'AI Match Nearby Explorers',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Recommended from bio, interests, travel intensity, and safety signals.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        ...MockData.users.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DopamineCard(
              onTap: () => _controller.openProfile(user),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      user.avatar,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
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
                                user.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${user.distanceKm.toStringAsFixed(1)} km',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${user.travelStyle} - ${user.paceMatch}% match',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: user.interests.take(2).map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                interest.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC7C7C7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profile(BuildContext context) {
    final user = _controller.selectedUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      key: const ValueKey('social-profile'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Explorer Profile',
          onBack: () => _controller.goTo(SocialStep.nearby),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.network(
              user.avatar,
              width: 132,
              height: 132,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            user.name,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${user.age} - ${user.travelStyle}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _ProfileCard(
                label: 'Energy',
                value: user.energyLevel.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileCard(
                label: 'Match Score',
                value: '${user.paceMatch}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        DopamineCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bio', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(user.bio, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Safety rating ${user.safetyRating.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Interests'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: user.interests
              .map(
                (interest) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    interest.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Send Join Request',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _controller.sendRequest,
        ),
      ],
    );
  }

  Widget _request(BuildContext context) {
    final accepted = _controller.requestStatus == RequestStatus.accepted;
    final rejected = _controller.requestStatus == RequestStatus.rejected;
    return Center(
      key: const ValueKey('social-request'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          140,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 66,
              backgroundColor: accepted
                  ? AppColors.secondarySoft
                  : AppColors.primarySoft,
              child: Icon(
                rejected
                    ? Icons.close_rounded
                    : accepted
                    ? Icons.check_rounded
                    : Icons.groups_rounded,
                size: 60,
                color: accepted ? AppColors.secondary : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              rejected
                  ? 'Request Rejected'
                  : accepted
                  ? 'Request Accepted!'
                  : 'Sending Request...',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              accepted
                  ? '${_controller.selectedUser?.name} is excited to explore with you.'
                  : rejected
                  ? 'No worries. You can return to nearby matches.'
                  : 'Waiting for ${_controller.selectedUser?.name} to accept your invitation.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            rejected
                ? PrimaryButton(
                    label: 'Back to Matches',
                    onPressed: _controller.endSharedTrip,
                  )
                : accepted
                ? PrimaryButton(
                    label: 'Setup Meeting',
                    onPressed: () => _controller.goTo(SocialStep.setup),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _controller.endSharedTrip,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Simulate Accept',
                          backgroundColor: AppColors.secondary,
                          onPressed: _controller.acceptRequest,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _controller.rejectRequest,
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    return ListView(
      key: const ValueKey('social-setup'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Meeting Details',
          onBack: () => _controller.goTo(SocialStep.request),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _MiniLabel('Meeting Point'),
        const SizedBox(height: AppSpacing.sm),
        DopamineCard(
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _controller.meetingPoint,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Shared Available Times'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _controller.meetingTimeOptions
              .map(
                (time) => ChoiceChip(
                  label: Text(time),
                  selected: _controller.meetingTime == time,
                  onSelected: (_) => _controller.setMeetingTime(time),
                  selectedColor: AppColors.secondarySoft,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        DopamineCard(
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Matched time: ${_controller.meetingTime}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            '"${_controller.selectedUser?.name}: That works for me! Let\'s meet at ${_controller.meetingPoint} at ${_controller.meetingTime}."',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Confirm & Meet!',
          onPressed: () => _controller.goTo(SocialStep.nfc),
        ),
      ],
    );
  }

  Widget _nfc(BuildContext context) {
    return Center(
      key: const ValueKey('social-nfc'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          140,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filled(
                onPressed: () => _controller.goTo(SocialStep.setup),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Meet Offline',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap phones together to confirm you\'ve met and start the group trip.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AnimatedScale(
              scale: _controller.nfcScanning ? 1.05 : 1,
              duration: const Duration(milliseconds: 250),
              child: Container(
                width: 180,
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(42),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: Colors.white24,
                  size: 72,
                ),
              ),
            ),
            const Spacer(),
            _controller.nfcScanning
                ? Text(
                    'Scanning...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.secondary,
                    ),
                  )
                : PrimaryButton(
                    label: 'Scan NFC to Start',
                    icon: Icons.smartphone_rounded,
                    onPressed: _controller.startNfcScan,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _edit(BuildContext context) {
    return ListView(
      key: const ValueKey('social-edit'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        140,
      ),
      children: [
        _FlowHeader(
          title: 'Plan Shared Route',
          onBack: () => _controller.goTo(SocialStep.nfc),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          onChanged: _controller.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Add more places together...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_controller.filteredSearchResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _MiniLabel('Search Results'),
          const SizedBox(height: AppSpacing.sm),
          ..._controller.filteredSearchResults.map(
            (poi) =>
                _SocialPoiRow(poi: poi, onAdd: () => _controller.addPoi(poi)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _MiniLabel('Collaborative Plan'),
        const SizedBox(height: AppSpacing.sm),
        ..._controller.sharedPois.asMap().entries.map(
          (entry) => _SocialPoiRow(
            poi: entry.value,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.secondary,
              child: Text(
                '${entry.key + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            subtitle:
                'Added by ${entry.key.isEven ? 'You' : _controller.selectedUser?.name}',
            onDelete: () => _controller.removePoi(entry.value.id),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Start Shared Trip!',
          onPressed: () => _controller.goTo(SocialStep.sharedTrip),
        ),
      ],
    );
  }

  Widget _sharedTrip(BuildContext context) {
    return Stack(
      key: const ValueKey('social-shared-trip'),
      children: [
        Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Wandering with ${_controller.selectedUser?.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF6E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      _controller.buddyPosition.dx * 2 - 1,
                      _controller.buddyPosition.dy * 2 - 1,
                    ),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.secondary,
                      child: Icon(Icons.person, color: Colors.white),
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
          bottom: 44,
          child: DopamineCard(
            child: Column(
              children: [
                Text(
                  _controller.sharedPois.isEmpty
                      ? 'Shared Route'
                      : _controller.sharedPois.first.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '0.8 km together',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _controller.endSharedTrip,
                  child: const Text('End Shared Trip'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DopamineCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
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

class _SocialPoiRow extends StatelessWidget {
  const _SocialPoiRow({
    required this.poi,
    this.leading,
    this.subtitle,
    this.onAdd,
    this.onDelete,
  });

  final Poi poi;
  final Widget? leading;
  final String? subtitle;
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
                    subtitle ?? poi.category.label,
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
