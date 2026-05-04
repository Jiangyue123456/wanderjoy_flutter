import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/dopamine_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'explore_agent_service.dart';
import 'explore_controller.dart';
import 'voice_transcription_service.dart';

const _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.tripContext = const ExploreTripContext(),
    this.initialStep = ExploreStep.home,
  });

  final ExploreTripContext tripContext;
  final ExploreStep initialStep;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreController _controller;
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceTranscriptionService _voiceTranscriptionService =
      const VoiceTranscriptionService();
  final TextEditingController _chatTextController = TextEditingController();
  bool _isTranscribingVoice = false;

  @override
  void initState() {
    super.initState();
    _controller = ExploreController(
      tripContext: widget.tripContext,
      initialStep: widget.initialStep,
    );
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
            fallbackAvatar: user.photoURL,
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
    String? fallbackAvatar,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.applyProfile(
        data,
        fallbackName: fallbackName,
        fallbackAvatar: fallbackAvatar,
      );
    });
  }

  Widget _inputContent(BuildContext context, {required bool isProfileLoading}) {
    final visibleError = _visibleExploreError();
    final isSocial = _controller.tripContext.isSocial;
    final buddyName = _controller.tripContext.buddyName ?? 'your friend';
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
          title: isSocial ? 'Plan Together' : 'Talk with AI',
          onBack: () => _controller.goTo(ExploreStep.home),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isSocial) ...[
          DopamineCard(
            child: Row(
              children: [
                _ExploreBuddyAvatars(
                  meAvatar: _controller.profileAvatar,
                  buddyAvatar: _controller.tripContext.buddyAvatar,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'I will recommend places and plan a route based on your and $buddyName\'s preferences.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
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
                                : isSocial
                                ? 'Using both profiles, shared interests, and pace.'
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
                        hintText: isSocial
                            ? 'Tell WanderJoy what both of you want to explore...'
                            : 'Tell WanderJoy what you want to explore...',
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
        const SizedBox(height: AppSpacing.xl),
        if (visibleError != null) ...[
          DopamineCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    visibleError,
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

  String? _visibleExploreError() {
    final error = _controller.exploreError;
    if (error == null || error.trim().isEmpty) {
      return null;
    }

    final lower = error.toLowerCase();
    final isTechnicalBackendError =
        lower.contains('timeout') ||
        lower.contains('future not completed') ||
        lower.contains('explore agent request failed') ||
        lower.contains('openai returned') ||
        lower.contains('route planning failed') ||
        lower.contains('missing openai_api_key');
    if (isTechnicalBackendError) {
      return null;
    }

    return error;
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
          onSubmitted: (_) => _controller.searchGooglePlaces(),
          decoration: InputDecoration(
            hintText: 'Search and manually add a place...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.isSearchingPlaces
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: _controller.searchGooglePlaces,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_controller.isSearchingPlaces || results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _MiniLabel('Google Maps Search Results'),
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
          label: _controller.isPlanningRoute
              ? 'Planning fastest route...'
              : 'Confirm Places',
          onPressed: _controller.selectedPois.isEmpty || _controller.isPlanningRoute
              ? null
              : () {
                  _controller.confirmPlacesAndPlanRoute();
                },
        ),
      ],
    );
  }

  Widget _route(BuildContext context) {
    final pois = _controller.optimizedPois;
    final routePlan = _controller.routePlan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.startLocationUpdates();
      }
    });
    return Stack(
      key: const ValueKey('explore-route'),
      children: [
        Positioned.fill(
          child: _RouteMapBackground(
            pois: pois,
            routePlan: routePlan,
            navigationActive: _controller.isNavigationActive,
            tripContext: _controller.tripContext,
            routeOriginLat:
                _controller.navigationOriginLat ?? _controller.currentLocationLat,
            routeOriginLng:
                _controller.navigationOriginLng ?? _controller.currentLocationLng,
            currentLat: _controller.currentLocationLat,
            currentLng: _controller.currentLocationLng,
            navigationBearing: _controller.navigationBearingDegrees,
            routeMemories: _controller.routeMemories,
            profileAvatar: _controller.profileAvatar,
            onPoiTap: (poi) => _showPoiDetails(context, poi),
            onMemoryTap: (memory) => _showRouteMemoryDetails(context, memory),
          ),
        ),
        Positioned(
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SmallBadge(
                    routePlan == null
                        ? (_controller.tripContext.isSocial
                              ? 'Shared Route Preview'
                              : 'Route Preview')
                        : 'Google Maps',
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _openRouteInMaps,
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Open Maps'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white.withValues(alpha: 0.94),
                      foregroundColor: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (_controller.locationStatus != null) ...[
                const SizedBox(height: 8),
                _MapHint(message: _controller.locationStatus!),
              ],
            ],
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 24,
          child: DopamineCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _controller.tripContext.isSocial
                            ? 'Fastest Shared Route'
                            : 'Fastest Route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${pois.length} stops  |  ${_controller.estimatedMinutes} mins',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (routePlan != null && routePlan.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    routePlan.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_controller.isNavigationActive)
                  _RouteMemoryCaptureCard(
                    memoryCount: _controller.routeMemories.length,
                    onCapture: _captureRouteMemory,
                  )
                else
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pois.length,
                      separatorBuilder: (_, _) => const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                      itemBuilder: (context, index) => _RouteStopChip(
                        index: index + 1,
                        name: pois[index].name,
                        onTap: () => _showPoiDetails(context, pois[index]),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (!_controller.isNavigationActive) ...[
                      IconButton.outlined(
                        onPressed: () => _controller.goTo(ExploreStep.customize),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit places',
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _controller.isNavigationActive
                          ? OutlinedButton.icon(
                              onPressed: _controller.endNavigation,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('End Navigation'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                            )
                          : PrimaryButton(
                              label: 'Start Navigation',
                              icon: Icons.navigation_rounded,
                              onPressed: _controller.startNavigation,
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

  Future<void> _captureRouteMemory() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 86,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) {
      return;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final fileName =
        'wanderjoy_memory_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPhoto = await File(photo.path).copy('${documentsDir.path}/$fileName');
    if (!mounted) {
      return;
    }

    final note = await _showMemoryNoteSheet(savedPhoto);
    if (note == null || !mounted) {
      return;
    }

    _controller.saveRouteMemory(photoPath: savedPhoto.path, note: note);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to Memory')),
    );
  }

  Future<String?> _showMemoryNoteSheet(File photoFile) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _MemoryNoteSheet(photoFile: photoFile),
    );
  }

  void _showPoiDetails(BuildContext context, Poi poi) {
    _controller.loadGooglePlaceDetails(poi);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final livePoi = _controller.latestPoi(poi);
          return _PoiDetailsSheet(
            poi: livePoi,
            distanceKm: _controller.distanceFromCurrentKm(livePoi),
            travelMinutes: _controller.travelMinutesFromCurrent(livePoi),
            isLoadingLiveDetails: _controller.isLoadingPlaceDetails(livePoi),
            onOpenMaps: () => _openPoiInMaps(livePoi),
          );
        },
      ),
    );
  }

  void _showRouteMemoryDetails(BuildContext context, MemoryEntry memory) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: memory.photo.startsWith('http')
                          ? Image.network(
                              memory.photo,
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(memory.photo),
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      memory.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${memory.timestamp} - ${memory.location}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        memory.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _openPoiInMaps(Poi poi) async {
    final uri = Uri.parse(_googleMapsUrlFor(poi));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openRouteInMaps() async {
    final uri = Uri.parse(_controller.routeMapsUrl());
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
          color: isAi ? AppColors.backgroundSoft : AppColors.secondarySoft,
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
            color: isAi ? AppColors.ink : const Color(0xFF19756E),
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

class _MemoryNoteSheet extends StatefulWidget {
  const _MemoryNoteSheet({required this.photoFile});

  final File photoFile;

  @override
  State<_MemoryNoteSheet> createState() => _MemoryNoteSheetState();
}

class _MemoryNoteSheetState extends State<_MemoryNoteSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.58,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  widget.photoFile,
                  width: double.infinity,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add a memory note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'What happened here?',
                  filled: true,
                  fillColor: Color(0xFFF7F7F7),
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: 'Save Memory',
                icon: Icons.bookmark_add_rounded,
                onPressed: () {
                  Navigator.of(context).pop(_noteController.text);
                },
              ),
            ],
          ),
        ),
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
    required this.travelMinutes,
    required this.isLoadingLiveDetails,
    required this.onOpenMaps,
  });

  final Poi poi;
  final double? distanceKm;
  final int? travelMinutes;
  final bool isLoadingLiveDetails;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final rating = poi.googleRating ?? poi.rating;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poi.photoUrls.isNotEmpty) ...[
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: poi.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      poi.photoUrls[index],
                      width: 188,
                      height: 128,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 188,
                        height: 128,
                        color: AppColors.mapGrid,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
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
                  icon: Icons.star_rounded,
                  label: poi.userRatingsTotal == null
                      ? rating.toStringAsFixed(1)
                      : '${rating.toStringAsFixed(1)} (${poi.userRatingsTotal})',
                ),
                if (distanceKm != null)
                  _InlineInfo(
                    icon: Icons.near_me_outlined,
                    label: '${distanceKm!.toStringAsFixed(1)} km away',
                  ),
                if (travelMinutes != null)
                  _InlineInfo(
                    icon: Icons.directions_walk_rounded,
                    label: '$travelMinutes min',
                  ),
                if (poi.googlePlaceId.isNotEmpty)
                  const _InlineInfo(
                    icon: Icons.location_on_outlined,
                    label: 'Verified place',
                  ),
                if (poi.isOpenNow != null)
                  _InlineInfo(
                    icon: Icons.schedule_rounded,
                    label: poi.isOpenNow! ? 'Open now' : 'Closed now',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailBlock(title: 'Why this fits', body: poi.reason),
            const SizedBox(height: AppSpacing.md),
            _DetailBlock(title: 'Suggested activity', body: poi.description),
            const SizedBox(height: AppSpacing.md),
            _GoogleLiveDetails(
              poi: poi,
              isLoading: isLoadingLiveDetails,
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
      ),
    );
  }
}

class _GoogleLiveDetails extends StatelessWidget {
  const _GoogleLiveDetails({
    required this.poi,
    required this.isLoading,
  });

  final Poi poi;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasGoogleData =
        poi.openingHours.isNotEmpty ||
        poi.googleReviewSummaries.isNotEmpty ||
        poi.photoUrls.isNotEmpty ||
        poi.googleRating != null ||
        poi.isOpenNow != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIVE DETAILS', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        if (isLoading)
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading Google Maps details...'),
            ],
          )
        else if (!hasGoogleData)
          Text(
            'Google live details were not returned for this place. Open Google Maps for the full listing.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...[
          if (poi.openingHours.isNotEmpty) ...[
            ...poi.openingHours.take(7).map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (poi.googleReviewSummaries.isNotEmpty) ...[
            Text(
              'Reviews',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            ...poi.googleReviewSummaries.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  review,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ],
      ],
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

class _ExploreBuddyAvatars extends StatelessWidget {
  const _ExploreBuddyAvatars({
    required this.meAvatar,
    required this.buddyAvatar,
  });

  final String meAvatar;
  final String? buddyAvatar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 54,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 3,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: _SmallRouteAvatar(
                  path: meAvatar,
                  fallbackColor: AppColors.primary,
                  fallbackText: 'Y',
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 3,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: _SmallRouteAvatar(
                  path: buddyAvatar ?? '',
                  fallbackColor: AppColors.secondary,
                  fallbackText: 'F',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallRouteAvatar extends StatelessWidget {
  const _SmallRouteAvatar({
    required this.path,
    required this.fallbackColor,
    required this.fallbackText,
  });

  final String path;
  final Color fallbackColor;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http')) {
      return Image.network(
        trimmed,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (trimmed.isNotEmpty && File(trimmed).existsSync()) {
      return Image.file(
        File(trimmed),
        width: 46,
        height: 46,
        fit: BoxFit.cover,
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 46,
      height: 46,
      color: fallbackColor,
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouteMapBackground extends StatelessWidget {
  const _RouteMapBackground({
    required this.pois,
    required this.routePlan,
    required this.navigationActive,
    required this.tripContext,
    required this.routeOriginLat,
    required this.routeOriginLng,
    required this.currentLat,
    required this.currentLng,
    required this.navigationBearing,
    required this.routeMemories,
    required this.profileAvatar,
    required this.onPoiTap,
    required this.onMemoryTap,
  });

  final List<Poi> pois;
  final ExploreRoutePlan? routePlan;
  final bool navigationActive;
  final ExploreTripContext tripContext;
  final double? routeOriginLat;
  final double? routeOriginLng;
  final double? currentLat;
  final double? currentLng;
  final double navigationBearing;
  final List<MemoryEntry> routeMemories;
  final String profileAvatar;
  final ValueChanged<Poi> onPoiTap;
  final ValueChanged<MemoryEntry> onMemoryTap;

  @override
  Widget build(BuildContext context) {
    final html = _mapHtml();
    if (html != null && (Platform.isAndroid || Platform.isIOS)) {
      return _EmbeddedRouteMap(
        html: html,
        onMarkerTap: (message) {
          if (message.startsWith('memory:')) {
            final id = message.substring(7);
            final matches = routeMemories.where((memory) => memory.id == id);
            if (matches.isNotEmpty) {
              onMemoryTap(matches.first);
            }
            return;
          }
          final matches = pois.where((poi) => poi.id == message);
          if (matches.isNotEmpty) {
            onPoiTap(matches.first);
          }
        },
      );
    }

    return _EstimatedRouteMap(
      pois: pois,
      routePlan: routePlan,
      navigationActive: navigationActive,
      tripContext: tripContext,
      currentLat: currentLat,
      currentLng: currentLng,
    );
  }

  String? _mapHtml() {
    final routePois = pois.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    if (routePois.isEmpty || _googleMapsApiKey.trim().isEmpty) {
      return null;
    }

    final origin = routeOriginLat != null && routeOriginLng != null
        ? {'lat': routeOriginLat, 'lng': routeOriginLng, 'label': 'Start'}
        : {
            'lat': routePois.first.lat,
            'lng': routePois.first.lng,
            'label': routePois.first.name,
          };
    final liveLocation = currentLat != null && currentLng != null
        ? {'lat': currentLat, 'lng': currentLng}
        : null;
    final socialStart = tripContext.isSocial
        ? {
            'meAvatar': _imageSrc(profileAvatar),
            'buddyName': tripContext.buddyName ?? 'Friend',
            'buddyAvatar': tripContext.buddyAvatar ?? '',
          }
        : null;
    final destination = {
      'lat': routePois.last.lat,
      'lng': routePois.last.lng,
      'label': routePois.last.name,
    };
    final waypointPois = currentLat != null && currentLng != null
        ? routePois.sublist(0, routePois.length - 1)
        : routePois.length > 2
        ? routePois.sublist(1, routePois.length - 1)
        : <Poi>[];
    final stops = routePois.asMap().entries.map((entry) {
      final poi = entry.value;
      return {
        'id': poi.id,
        'index': entry.key + 1,
        'name': poi.name,
        'lat': poi.lat,
        'lng': poi.lng,
      };
    }).toList();
    final waypoints = waypointPois
        .map((poi) => {'lat': poi.lat, 'lng': poi.lng})
        .toList();
    final memoryPins = routeMemories
        .where((memory) => memory.lat != null && memory.lng != null)
        .map(
          (memory) => {
            'id': memory.id,
            'lat': memory.lat,
            'lng': memory.lng,
            'title': memory.title,
            'text': memory.text,
            'photoSrc': _memoryPhotoSrc(memory),
          },
        )
        .toList();

    final html = '''
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
        background: #eaf1ee;
        font-family: Arial, sans-serif;
      }
      .poi-label {
        background: white;
        border: 1px solid #eeeeee;
        border-radius: 16px;
        box-shadow: 0 8px 18px rgba(0,0,0,.18);
        color: #2f2f2f;
        font-size: 13px;
        font-weight: 800;
        max-width: 150px;
        overflow: hidden;
        padding: 7px 10px;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      .poi-label b {
        background: #ff6b6b;
        border-radius: 999px;
        color: white;
        display: inline-block;
        height: 24px;
        line-height: 24px;
        margin-right: 6px;
        text-align: center;
        width: 24px;
      }
      .you-label {
        background: #1a73e8;
        border: 3px solid white;
        border-radius: 999px;
        box-shadow: 0 6px 14px rgba(0,0,0,.20);
        color: white;
        font-size: 12px;
        font-weight: 900;
        height: 34px;
        line-height: 34px;
        min-width: 48px;
        padding: 0 9px 0 28px;
        position: relative;
      }
      .you-arrow {
        display: none;
      }
      .you-heading {
        align-items: center;
        background: #1a73e8;
        border: 4px solid white;
        border-radius: 999px;
        box-shadow: 0 6px 16px rgba(0,0,0,.28);
        display: flex;
        height: 38px;
        justify-content: center;
        width: 38px;
      }
      .you-heading-arrow {
        border-left: 8px solid transparent;
        border-right: 8px solid transparent;
        border-bottom: 19px solid white;
        height: 0;
        transform-origin: 50% 62%;
        width: 0;
      }
      .social-start-label {
        align-items: center;
        background: #ffffff;
        border-radius: 999px;
        box-shadow: 0 8px 18px rgba(0,0,0,.20);
        display: flex;
        gap: 4px;
        padding: 7px 12px 7px 8px;
      }
      .social-start-label b {
        color: #2f2f2f;
        font-size: 12px;
        font-weight: 900;
        margin-left: 4px;
        white-space: nowrap;
      }
      .social-avatar {
        align-items: center;
        border: 3px solid #ffffff;
        border-radius: 999px;
        color: #ffffff;
        display: flex;
        font-size: 12px;
        font-weight: 900;
        height: 32px;
        justify-content: center;
        overflow: hidden;
        width: 32px;
      }
      .social-avatar.me {
        background: #ff6b6b;
      }
      .social-avatar.buddy {
        background: #4ecdc4;
        margin-left: -12px;
      }
      .social-avatar img {
        height: 100%;
        object-fit: cover;
        width: 100%;
      }
      .memory-pin {
        align-items: center;
        background: #ffffff;
        border: 3px solid #ffffff;
        border-radius: 999px 999px 999px 4px;
        box-shadow: 0 8px 18px rgba(0,0,0,.25);
        cursor: pointer;
        display: flex;
        height: 46px;
        justify-content: center;
        overflow: hidden;
        position: relative;
        transform: rotate(-45deg);
        width: 46px;
      }
      .memory-pin img {
        height: 62px;
        object-fit: cover;
        transform: rotate(45deg) scale(1.08);
        width: 62px;
      }
      .memory-pin-fallback {
        align-items: center;
        background: #ff6b6b;
        color: white;
        display: flex;
        font-size: 20px;
        height: 100%;
        justify-content: center;
        transform: rotate(45deg);
        width: 100%;
      }
    </style>
    <script src="https://maps.googleapis.com/maps/api/js?key=$_googleMapsApiKey&callback=initMap" async defer></script>
    <script>
      const origin = ${jsonEncode(origin)};
      const destination = ${jsonEncode(destination)};
      const waypoints = ${jsonEncode(waypoints)};
      const stops = ${jsonEncode(stops)};
      const memoryPins = ${jsonEncode(memoryPins)};
      const liveLocation = ${jsonEncode(liveLocation)};
      const socialStart = ${jsonEncode(socialStart)};
      const navigationActive = $navigationActive;
      const navigationBearing = $navigationBearing;

      function initMap() {
        const map = new google.maps.Map(document.getElementById('map'), {
          center: { lat: origin.lat, lng: origin.lng },
          zoom: 14,
          mapTypeControl: false,
          fullscreenControl: false,
          streetViewControl: false,
          clickableIcons: false
        });

        const directionsService = new google.maps.DirectionsService();
        directionsService.route({
          origin: { lat: origin.lat, lng: origin.lng },
          destination: { lat: destination.lat, lng: destination.lng },
          waypoints: waypoints.map((point) => ({
            location: { lat: point.lat, lng: point.lng },
            stopover: true
          })),
          travelMode: google.maps.TravelMode.WALKING
        }, (result, status) => {
          if (status === 'OK') {
            drawRoutePreview(map, result.routes[0]);
            fitRoute(map, result.routes[0]);
          }
        });

        if (navigationActive && liveLocation) {
          createMapLabel(
            map,
            liveLocation,
            '<div class="you-heading"><span class="you-heading-arrow" style="transform: rotate(' + navigationBearing + 'deg);"></span></div>'
          );
        } else {
          createMapLabel(
            map,
            { lat: origin.lat, lng: origin.lng },
            socialStart ? socialStartHtml(socialStart) : '<div class="you-label">You</div>'
          );
        }

        stops.forEach((stop) => {
          createMapLabel(
            map,
            { lat: stop.lat, lng: stop.lng },
            '<div class="poi-label"><b>' + stop.index + '</b>' + escapeHtml(stop.name) + '</div>',
            () => {
            if (window.WanderJoy) {
              window.WanderJoy.postMessage(stop.id);
            }
            }
          );
        });
        memoryPins.forEach((memory) => {
          createMapLabel(
            map,
            { lat: memory.lat, lng: memory.lng },
            memory.photoSrc
              ? '<div class="memory-pin"><img src="' + memory.photoSrc + '" alt=""></div>'
              : '<div class="memory-pin"><span class="memory-pin-fallback">+</span></div>',
            () => {
              if (window.WanderJoy) {
                window.WanderJoy.postMessage('memory:' + memory.id);
              }
            }
          );
        });
      }

      function drawRoutePreview(map, route) {
        const path = route.overview_path || [];
        if (!path.length) {
          return;
        }

        const splitIndex = navigationActive && liveLocation
          ? nearestPathIndex(path, liveLocation)
          : 0;
        const liveLatLng = liveLocation
          ? new google.maps.LatLng(liveLocation.lat, liveLocation.lng)
          : null;
        const completedPath = navigationActive && liveLatLng && splitIndex > 0
          ? path.slice(0, splitIndex + 1).concat([liveLatLng])
          : [];
        const remainingPath = navigationActive && liveLatLng
          ? [liveLatLng].concat(path.slice(Math.max(1, splitIndex)))
          : path;

        if (completedPath.length > 1) {
          new google.maps.Polyline({
            path: completedPath,
            map,
            clickable: false,
            geodesic: false,
            strokeColor: '#9ca3af',
            strokeOpacity: 0.86,
            strokeWeight: 6,
            zIndex: 18
          });
        }

        new google.maps.Polyline({
          path: remainingPath,
          map,
          clickable: false,
          geodesic: false,
          strokeColor: '#ffffff',
          strokeOpacity: 0.94,
          strokeWeight: 9,
          zIndex: 20
        });

        new google.maps.Polyline({
          path: remainingPath,
          map,
          clickable: false,
          geodesic: false,
          strokeColor: '#2563eb',
          strokeOpacity: 0.92,
          strokeWeight: 5,
          zIndex: 21
        });
      }

      function nearestPathIndex(path, point) {
        let bestIndex = 0;
        let bestDistance = Number.POSITIVE_INFINITY;
        path.forEach((latLng, index) => {
          const dLat = latLng.lat() - point.lat;
          const dLng = latLng.lng() - point.lng;
          const distance = dLat * dLat + dLng * dLng;
          if (distance < bestDistance) {
            bestDistance = distance;
            bestIndex = index;
          }
        });
        return bestIndex;
      }

      function fitRoute(map, route) {
        const bounds = route.bounds || new google.maps.LatLngBounds();
        stops.forEach((stop) => bounds.extend({ lat: stop.lat, lng: stop.lng }));
        bounds.extend({ lat: origin.lat, lng: origin.lng });
        map.fitBounds(bounds, {
          top: 92,
          right: 28,
          bottom: 260,
          left: 28
        });
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
            this.div.innerHTML = html;
            if (this.div.firstElementChild && this.div.firstElementChild.classList.contains('you-heading')) {
              this.div.style.transform = 'translate(-50%, -50%)';
            } else {
              this.div.style.transform = 'translate(-50%, -100%)';
            }
            if (onClick) {
              this.div.addEventListener('click', onClick);
            }
            this.getPanes().overlayMouseTarget.appendChild(this.div);
          }

          draw() {
            const projection = this.getProjection();
            const point = projection.fromLatLngToDivPixel(this.position);
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

      function socialStartHtml(value) {
        const meAvatar = value.meAvatar
          ? '<img src="' + escapeHtml(value.meAvatar) + '" alt="">'
          : '<span>Y</span>';
        const avatar = value.buddyAvatar
          ? '<img src="' + escapeHtml(value.buddyAvatar) + '" alt="">'
          : '<span>F</span>';
        return '<div class="social-start-label"><div class="social-avatar me">' + meAvatar + '</div><div class="social-avatar buddy">' + avatar + '</div><b>Start together</b></div>';
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
    return html;
  }

  String _memoryPhotoSrc(MemoryEntry memory) {
    return _imageSrc(memory.photo);
  }

  String _imageSrc(String path) {
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

class _EmbeddedRouteMap extends StatefulWidget {
  const _EmbeddedRouteMap({
    required this.html,
    required this.onMarkerTap,
  });

  final String html;
  final ValueChanged<String> onMarkerTap;

  @override
  State<_EmbeddedRouteMap> createState() => _EmbeddedRouteMapState();
}

class _EmbeddedRouteMapState extends State<_EmbeddedRouteMap> {
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAF1EE))
      ..addJavaScriptChannel(
        'WanderJoy',
        onMessageReceived: (message) => widget.onMarkerTap(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(widget.html, baseUrl: 'https://www.google.com');
  }

  @override
  void didUpdateWidget(covariant _EmbeddedRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _webViewController.loadHtmlString(
        widget.html,
        baseUrl: 'https://www.google.com',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}

class _EstimatedRouteMap extends StatelessWidget {
  const _EstimatedRouteMap({
    required this.pois,
    required this.routePlan,
    required this.navigationActive,
    required this.tripContext,
    required this.currentLat,
    required this.currentLng,
  });

  final List<Poi> pois;
  final ExploreRoutePlan? routePlan;
  final bool navigationActive;
  final ExploreTripContext tripContext;
  final double? currentLat;
  final double? currentLng;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFEAF1EE)),
      child: CustomPaint(
        painter: _RouteMapPainter(
          pois: pois,
          routePlan: routePlan,
          navigationActive: navigationActive,
          tripContext: tripContext,
          currentLat: currentLat,
          currentLng: currentLng,
        ),
      ),
    );
  }
}

class _RouteStopChip extends StatelessWidget {
  const _RouteStopChip({
    required this.index,
    required this.name,
    this.onTap,
  });

  final int index;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 138,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMemoryCaptureCard extends StatelessWidget {
  const _RouteMemoryCaptureCard({
    required this.memoryCount,
    required this.onCapture,
  });

  final int memoryCount;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Take Photo'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              memoryCount == 0
                  ? 'Capture a moment on this route.'
                  : '$memoryCount route memories saved',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationCueCard extends StatelessWidget {
  const _NavigationCueCard({required this.cue});

  final NavigationCue cue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(cue.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cue.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cue.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopOverlay extends StatelessWidget {
  const _RouteStopOverlay({
    required this.pois,
    required this.controller,
    required this.onTap,
  });

  final List<Poi> pois;
  final ExploreController controller;
  final ValueChanged<Poi> onTap;

  @override
  Widget build(BuildContext context) {
    if (pois.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pois.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final poi = pois[index];
          final distance = controller.distanceFromCurrentKm(poi);
          final minutes = controller.travelMinutesFromCurrent(poi);
          return GestureDetector(
            onTap: () => onTap(poi),
            child: Container(
              width: 154,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          poi.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          distance == null
                              ? 'Tap for details'
                              : '${distance.toStringAsFixed(1)} km'
                                  '${minutes == null ? '' : ' | $minutes min'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RouteMapMarkersOverlay extends StatelessWidget {
  const _RouteMapMarkersOverlay({
    required this.pois,
    required this.currentLat,
    required this.currentLng,
    required this.controller,
    required this.onPoiTap,
  });

  final List<Poi> pois;
  final double? currentLat;
  final double? currentLng;
  final ExploreController controller;
  final ValueChanged<Poi> onPoiTap;

  @override
  Widget build(BuildContext context) {
    final validPois = pois.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    if (validPois.isEmpty && (currentLat == null || currentLng == null)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (currentLat != null && currentLng != null)
              _positionedMarker(
                size: size,
                lat: currentLat!,
                lng: currentLng!,
                width: 76,
                height: 44,
                child: const _CurrentLocationMarker(),
              ),
            for (final entry in pois.asMap().entries)
              if (entry.value.lat != 0 || entry.value.lng != 0)
                _positionedMarker(
                  size: size,
                  lat: entry.value.lat,
                  lng: entry.value.lng,
                  width: 164,
                  height: 64,
                  child: _PoiMapMarker(
                    index: entry.key + 1,
                    poi: entry.value,
                    distanceKm: controller.distanceFromCurrentKm(entry.value),
                    minutes: controller.travelMinutesFromCurrent(entry.value),
                    onTap: () => onPoiTap(entry.value),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _positionedMarker({
    required Size size,
    required double lat,
    required double lng,
    required double width,
    required double height,
    required Widget child,
  }) {
    final point = _project(lat, lng, size);
    return Positioned(
      left: (point.dx - width / 2).clamp(8.0, size.width - width - 8),
      top: (point.dy - height).clamp(96.0, size.height - 330),
      width: width,
      height: height,
      child: child,
    );
  }

  Offset _project(double lat, double lng, Size size) {
    final validPois = pois.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    final lats = [
      if (currentLat != null) currentLat!,
      ...validPois.map((poi) => poi.lat),
    ];
    final lngs = [
      if (currentLng != null) currentLng!,
      ...validPois.map((poi) => poi.lng),
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
    final x = ((lng - minLng) / lngSpan).clamp(0.16, 0.84) * size.width;
    final y = (1 - ((lat - minLat) / latSpan).clamp(0.18, 0.70)) * size.height;
    return Offset(x, y);
  }
}

class _PoiMapMarker extends StatelessWidget {
  const _PoiMapMarker({
    required this.index,
    required this.poi,
    required this.distanceKm,
    required this.minutes,
    required this.onTap,
  });

  final int index;
  final Poi poi;
  final double? distanceKm;
  final int? minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (distanceKm != null)
                        Text(
                          '${distanceKm!.toStringAsFixed(1)} km'
                          '${minutes == null ? '' : ' | $minutes min'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(18, 10),
            painter: _MarkerPointerPainter(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            'You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(16, 9),
          painter: _MarkerPointerPainter(color: Colors.blue),
        ),
      ],
    );
  }
}

class _MarkerPointerPainter extends CustomPainter {
  const _MarkerPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerPointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({
    required this.pois,
    required this.routePlan,
    required this.navigationActive,
    required this.tripContext,
    required this.currentLat,
    required this.currentLng,
  });

  final List<Poi> pois;
  final ExploreRoutePlan? routePlan;
  final bool navigationActive;
  final ExploreTripContext tripContext;
  final double? currentLat;
  final double? currentLng;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _routePoints(size);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      return;
    }

    final routePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.72)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, routePaint);

    final originPaint = Paint()..color = Colors.blue;
    if (tripContext.isSocial) {
      canvas.drawCircle(
        points.first.translate(-8, 0),
        9,
        Paint()..color = AppColors.primary,
      );
      canvas.drawCircle(
        points.first.translate(8, 0),
        9,
        Paint()..color = AppColors.secondary,
      );
    } else {
      canvas.drawCircle(points.first, 8, originPaint);
    }
    canvas.drawCircle(
      points.first,
      tripContext.isSocial ? 18 : 13,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final stopPaint = Paint()..color = AppColors.primary;
    for (final point in points.skip(1)) {
      canvas.drawCircle(point, 7, stopPaint);
      canvas.drawCircle(
        point,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  Offset _project(double lat, double lng, Size size) {
    final validPois = pois.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    final lats = [
      if (currentLat != null) currentLat!,
      ...validPois.map((poi) => poi.lat),
    ];
    final lngs = [
      if (currentLng != null) currentLng!,
      ...validPois.map((poi) => poi.lng),
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
    final x = ((lng - minLng) / lngSpan).clamp(0.08, 0.92) * size.width;
    final y = (1 - ((lat - minLat) / latSpan).clamp(0.08, 0.92)) * size.height;
    return Offset(x, y);
  }

  List<Offset> _routePoints(Size size) {
    final polyline = routePlan?.polylinePoints ?? const [];
    if (polyline.isNotEmpty) {
      return polyline.map((point) => _project(point.lat, point.lng, size)).toList();
    }

    return [
      if (currentLat != null && currentLng != null)
        _project(currentLat!, currentLng!, size),
      ...pois.map((poi) => _project(poi.lat, poi.lng, size)),
    ];
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return oldDelegate.pois != pois ||
        oldDelegate.routePlan != routePlan ||
        oldDelegate.tripContext != tripContext ||
        oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLng != currentLng;
  }
}

class _RouteOverlayPainter extends CustomPainter {
  const _RouteOverlayPainter({
    required this.pois,
    required this.routePlan,
    required this.currentLat,
    required this.currentLng,
  });

  final List<Poi> pois;
  final ExploreRoutePlan? routePlan;
  final double? currentLat;
  final double? currentLng;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _routePoints(size);

    if (points.length >= 2) {
      final routePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.82)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, routePaint);
    }

    if (points.isNotEmpty) {
      canvas.drawCircle(
        points.first,
        9,
        Paint()..color = Colors.blue,
      );
      canvas.drawCircle(
        points.first,
        14,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    for (var index = 0; index < pois.length; index++) {
      final poi = pois[index];
      if (poi.lat == 0 && poi.lng == 0) {
        continue;
      }
      final point = _project(poi.lat, poi.lng, size);
      canvas.drawCircle(point, 16, Paint()..color = AppColors.primary);
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

  Offset _project(double lat, double lng, Size size) {
    final validPois = pois.where((poi) => poi.lat != 0 || poi.lng != 0).toList();
    final lats = [
      if (currentLat != null) currentLat!,
      ...validPois.map((poi) => poi.lat),
    ];
    final lngs = [
      if (currentLng != null) currentLng!,
      ...validPois.map((poi) => poi.lng),
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
    final x = ((lng - minLng) / lngSpan).clamp(0.08, 0.92) * size.width;
    final y = (1 - ((lat - minLat) / latSpan).clamp(0.12, 0.78)) * size.height;
    return Offset(x, y);
  }

  List<Offset> _routePoints(Size size) {
    final polyline = routePlan?.polylinePoints ?? const [];
    if (polyline.isNotEmpty) {
      return polyline.map((point) => _project(point.lat, point.lng, size)).toList();
    }

    return [
      if (currentLat != null && currentLng != null)
        _project(currentLat!, currentLng!, size),
      ...pois
          .where((poi) => poi.lat != 0 || poi.lng != 0)
          .map((poi) => _project(poi.lat, poi.lng, size)),
    ];
  }

  @override
  bool shouldRepaint(covariant _RouteOverlayPainter oldDelegate) {
    return oldDelegate.pois != pois ||
        oldDelegate.routePlan != routePlan ||
        oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLng != currentLng;
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
