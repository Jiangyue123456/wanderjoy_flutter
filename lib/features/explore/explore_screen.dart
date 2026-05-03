import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/dopamine_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'explore_controller.dart';
import 'voice_transcription_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreController _controller;
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceTranscriptionService _voiceTranscriptionService =
      const VoiceTranscriptionService();
  final TextEditingController _chatTextController = TextEditingController();
  bool _isTranscribingVoice = false;

  @override
  void initState() {
    super.initState();
    _controller = ExploreController();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _chatTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_controller.isListening) {
      await _stopVoiceInput();
      return;
    }

    _controller.setExploreError(null);

    if (!await _recorder.hasPermission()) {
      _controller.setExploreError(
        'Microphone permission is needed for voice input. You can still type your request.',
      );
      return;
    }

    _chatTextController.clear();
    _controller.setChatInput('');
    final tempDir = await getTemporaryDirectory();
    final audioPath =
        '${tempDir.path}/wanderjoy_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: audioPath,
    );
    _controller.setListeningState(true);
  }

  Future<void> _stopVoiceInput() async {
    final audioPath = await _recorder.stop();
    _controller.setListeningState(false);
    if (audioPath == null || audioPath.trim().isEmpty) {
      _controller.setExploreError('Voice recording did not save. Please try again.');
      return;
    }

    setState(() {
      _isTranscribingVoice = true;
    });

    try {
      final transcript = await _voiceTranscriptionService.transcribe(
        File(audioPath),
      );
      _chatTextController.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(offset: transcript.length),
      );
      _controller.setChatInput(transcript);
    } on Object catch (error) {
      _controller.setExploreError('Voice transcription failed: $error');
    } finally {
      setState(() {
        _isTranscribingVoice = false;
      });

      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void _sendTypedMessage() {
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
    if (AuthService.instance.isPreviewMode) {
      _applyProfileAfterBuild(null, fallbackName: 'Preview Explorer');
      return _inputContent(context, isProfileLoading: false);
    }

    final User? user = AuthService.instance.currentUser;
    if (user == null) {
      _applyProfileAfterBuild(null);
      return _inputContent(context, isProfileLoading: false);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _applyProfileAfterBuild(
            snapshot.data?.data(),
            fallbackName: user.displayName,
          );
        }

        return _inputContent(
          context,
          isProfileLoading: snapshot.connectionState == ConnectionState.waiting,
        );
      },
    );
  }

  void _applyProfileAfterBuild(
    Map<String, dynamic>? data, {
    String? fallbackName,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.applyProfile(data, fallbackName: fallbackName);
    });
  }

  Widget _inputContent(BuildContext context, {required bool isProfileLoading}) {
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
          title: 'Talk with AI',
          onBack: () => _controller.goTo(ExploreStep.home),
        ),
        const SizedBox(height: AppSpacing.lg),
        DopamineCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _controller.isListening
                            ? AppColors.primary
                            : AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        color: _controller.isListening
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isTranscribingVoice
                                ? 'Turning voice into text'
                                : _controller.isListening
                                ? 'Recording now'
                                : 'Tap the mic to talk',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isProfileLoading
                                ? 'Loading your saved profile...'
                                : 'Using profile interests, bio, and pace.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    for (final message in _controller.chatMessages)
                      _VoiceMessageBubble(message: message),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _chatTextController,
                      minLines: 1,
                      maxLines: 3,
                      onChanged: _controller.setChatInput,
                      onSubmitted: (_) => _sendTypedMessage(),
                      decoration: InputDecoration(
                        hintText: 'Tell WanderJoy what you want to explore...',
                        prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: _sendTypedMessage,
                          icon: const Icon(Icons.send_rounded),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: _isTranscribingVoice ? null : _toggleVoiceInput,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          color: _controller.isListening
                              ? AppColors.primary
                              : AppColors.secondarySoft,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_controller.isListening
                                      ? AppColors.primary
                                      : AppColors.secondary)
                                  .withValues(alpha: 0.24),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          _controller.isListening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 42,
                          color: _controller.isListening
                              ? Colors.white
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isTranscribingVoice
                          ? 'Transcribing...'
                          : _controller.isListening
                          ? 'Tap again to stop'
                          : 'Start voice input',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _ContextChip(
                icon: Icons.favorite_rounded,
                label: _controller.profileInterestLabels.join(', '),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContextChip(
                icon: Icons.directions_walk_rounded,
                label: _controller.energy.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ContextChip(
          icon: Icons.notes_rounded,
          label: _controller.profileBio,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_controller.exploreError != null) ...[
          DopamineCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _controller.exploreError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PrimaryButton(
          label: _controller.isGeneratingPlaces
              ? 'Finding places...'
              : 'Recommend places',
          icon: Icons.travel_explore_rounded,
          onPressed: _controller.isGeneratingPlaces
              ? null
              : _controller.generateInitialRoute,
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
            (poi) => _PoiRow(
              poi: poi,
              onTap: () => _showPoiDetails(context, poi),
              onAdd: () => _controller.addPoi(poi),
            ),
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
            distanceKm: _controller.distanceFromCurrentKm(entry.value),
            onTap: () => _showPoiDetails(context, entry.value),
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

  void _showPoiDetails(BuildContext context, Poi poi) {
    final distanceKm = _controller.distanceFromCurrentKm(poi);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PoiDetailsSheet(
        poi: poi,
        distanceKm: distanceKm,
        onOpenMaps: () => _openPoiInMaps(poi),
      ),
    );
  }

  Future<void> _openPoiInMaps(Poi poi) async {
    final uri = Uri.parse(_googleMapsUrlFor(poi));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _googleMapsUrlFor(Poi poi) {
    if (poi.mapsUri.trim().startsWith('http')) {
      return poi.mapsUri.trim();
    }

    final query = Uri.encodeComponent(poi.name);
    final placeId = Uri.encodeComponent(poi.googlePlaceId);
    if (poi.googlePlaceId.trim().isNotEmpty) {
      return 'https://www.google.com/maps/search/?api=1&query=$query&query_place_id=$placeId';
    }

    return 'https://www.google.com/maps/search/?api=1&query=$query&center=${poi.lat},${poi.lng}';
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

class _VoiceMessageBubble extends StatelessWidget {
  const _VoiceMessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isAi = message.startsWith('AI:');
    final text = message.replaceFirst(isAi ? 'AI: ' : 'You: ', '');

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isAi ? AppColors.backgroundSoft : AppColors.primarySoft,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isAi ? 4 : 18),
            bottomRight: Radius.circular(isAi ? 18 : 4),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isAi ? AppColors.ink : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
  const _PoiRow({
    required this.poi,
    this.leading,
    this.distanceKm,
    this.onTap,
    this.onAdd,
    this.onDelete,
  });

  final Poi poi;
  final Widget? leading;
  final double? distanceKm;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
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
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        Text(
                          'Match ${(poi.matchScore * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      poi.reason,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (distanceKm != null)
                          _InlineInfo(
                            icon: Icons.near_me_outlined,
                            label: '${distanceKm!.toStringAsFixed(1)} km',
                          ),
                        if (poi.googlePlaceId.isNotEmpty)
                          const _InlineInfo(
                            icon: Icons.map_outlined,
                            label: 'Google Maps',
                          ),
                        if (poi.placeType.isNotEmpty)
                          _InlineInfo(
                            icon: Icons.category_outlined,
                            label: poi.placeType,
                          ),
                      ],
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
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _PoiDetailsSheet extends StatelessWidget {
  const _PoiDetailsSheet({
    required this.poi,
    required this.distanceKm,
    required this.onOpenMaps,
  });

  final Poi poi;
  final double? distanceKm;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final matchPercent = poi.matchScore > 0
        ? '${(poi.matchScore * 100).round()}%'
        : '${(poi.rating / 5 * 100).round()}%';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(poi.emoji),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        poi.placeType.isEmpty ? poi.category.label : poi.placeType,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InlineInfo(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Match $matchPercent',
                ),
                if (distanceKm != null)
                  _InlineInfo(
                    icon: Icons.near_me_outlined,
                    label: '${distanceKm!.toStringAsFixed(1)} km away',
                  ),
                _InlineInfo(
                  icon: Icons.location_on_outlined,
                  label:
                      '${poi.lat.toStringAsFixed(4)}, ${poi.lng.toStringAsFixed(4)}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailBlock(title: 'Why this fits', body: poi.reason),
            const SizedBox(height: AppSpacing.md),
            _DetailBlock(title: 'Suggested activity', body: poi.description),
            const SizedBox(height: AppSpacing.md),
            const _DetailBlock(
              title: 'Live details',
              body:
                  'Open Google Maps for current hours, ratings, reviews, photos, and directions.',
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Open in Google Maps',
              icon: Icons.map_rounded,
              onPressed: onOpenMaps,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
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
