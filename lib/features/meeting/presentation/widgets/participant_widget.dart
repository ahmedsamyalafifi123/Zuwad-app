import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/theme/app_theme.dart';

class ParticipantWidget extends StatefulWidget {
  final Participant participant;
  final bool isLocal;
  final String? celebrationVariant;

  const ParticipantWidget({
    super.key,
    required this.participant,
    required this.isLocal,
    this.celebrationVariant,
  });

  @override
  State<ParticipantWidget> createState() => _ParticipantWidgetState();
}

class _ParticipantWidgetState extends State<ParticipantWidget>
    with SingleTickerProviderStateMixin {
  VideoTrack? _videoTrack;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isScreenSharing = false;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;

  @override
  void initState() {
    super.initState();
    _setupParticipant();
    widget.participant.addListener(_onParticipantChanged);

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _celebrationAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(ParticipantWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrationVariant != oldWidget.celebrationVariant &&
        widget.celebrationVariant != null) {
      _celebrationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    _celebrationController.dispose();
    super.dispose();
  }

  void _setupParticipant() {
    // Get video track - prioritize screen share over camera
    final screenSharePublication = widget.participant.videoTrackPublications
        .where((pub) => pub.source.toString().toLowerCase().contains('screen'))
        .firstOrNull;

    final cameraPublication = widget.participant.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera)
        .firstOrNull;

    // Use screen share if available, otherwise use camera
    final videoPublication = screenSharePublication ?? cameraPublication;

    if (videoPublication?.track != null) {
      _videoTrack = videoPublication!.track as VideoTrack;
      _isScreenSharing = screenSharePublication != null;
      if (kDebugMode) {
        print(
            'Video track found for ${widget.participant.identity}: source=${videoPublication.source}, isScreenShare=$_isScreenSharing');
      }
    } else {
      _isScreenSharing = false;
      if (kDebugMode) {
        print('No video track found for ${widget.participant.identity}');
        print(
            'Available video publications: ${widget.participant.videoTrackPublications.length}');
        for (final pub in widget.participant.videoTrackPublications) {
          print(
              '  Video track: source=${pub.source}, subscribed=${pub.subscribed}, muted=${pub.muted}');
        }
      }
    }

    // Get audio track
    final audioPublication = widget.participant.audioTrackPublications
        .where((pub) => pub.source == TrackSource.microphone)
        .firstOrNull;

    if (kDebugMode) {
      if (audioPublication?.track != null) {
        print(
            'Audio track found for ${widget.participant.identity}: subscribed=${audioPublication!.subscribed}, muted=${audioPublication.muted}');
      } else {
        print('No audio track found for ${widget.participant.identity}');
        print(
            'Available audio publications: ${widget.participant.audioTrackPublications.length}');
      }
    }

    // Check audio/video status
    _updateMediaStatus();
  }

  void _onParticipantChanged() {
    if (mounted) {
      setState(() {
        _setupParticipant();
      });
    }
  }

  void _updateMediaStatus() {
    // Check for screen share first, then camera
    final screenSharePublication = widget.participant.videoTrackPublications
        .where((pub) => pub.source.toString().toLowerCase().contains('screen'))
        .firstOrNull;

    final cameraPublication = widget.participant.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera)
        .firstOrNull;

    final videoPublication = screenSharePublication ?? cameraPublication;
    _isScreenSharing = screenSharePublication != null;

    final audioPublication = widget.participant.audioTrackPublications
        .where((pub) => pub.source == TrackSource.microphone)
        .firstOrNull;

    _isVideoEnabled = videoPublication?.subscribed == true &&
        videoPublication?.muted == false;

    _isAudioEnabled = audioPublication?.subscribed == true &&
        audioPublication?.muted == false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLocal ? AppTheme.secondaryColor : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Video or avatar
            _buildVideoOrAvatar(),

            // Audio track (invisible but necessary for playback)
            _buildAudioTrack(),

            // Participant info overlay
            _buildParticipantInfo(),

            // Media status indicators
            _buildMediaStatusIndicators(),

            // Celebration Overlay
            if (widget.celebrationVariant != null) _buildCelebrationOverlay(),
          ],
        ),
      ),
    );
  }

  // Revised _buildCelebrationOverlay using Alignment for proper relative positioning within the Container
  Widget _buildCelebrationOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      return AnimatedBuilder(
        animation: _celebrationAnimation,
        builder: (context, child) {
          if (_celebrationController.status == AnimationStatus.dismissed)
            return const SizedBox.shrink();

          String emoji;
          bool isRising;

          switch (widget.celebrationVariant) {
            case 'hearts':
              emoji = '❤️';
              isRising = true;
              break;
            case 'claps':
              emoji = '👏';
              isRising = true;
              break;
            case 'thumbs':
              emoji = '👍';
              isRising = true;
              break;
            case 'confetti':
              emoji = '🎉';
              isRising = false;
              break;
            default:
              emoji = '❤️';
              isRising = true;
          }

          return Stack(
            children: List.generate(8, (index) {
              // Generate pseudo-random positions based on index
              final double seed = index * 13.0; // deterministic random-ish
              final double xPos = (seed % 100) / 100.0; // 0.0 to 1.0

              final double stagger = (index % 4) * 0.1;
              double progress =
                  (_celebrationAnimation.value * 1.5 - stagger).clamp(0.0, 1.0);

              if (progress <= 0 || progress >= 1)
                return const SizedBox.shrink();

              final double yPos = isRising
                  ? 1.0 - progress // Bottom to Top
                  : progress; // Top to Bottom

              // Add some sine wave horizontal movement
              final double xOffset =
                  math.sin(progress * math.pi * 2 + seed) * 0.1;

              return Align(
                alignment: Alignment(
                    (xPos - 0.5) * 2 + xOffset, // Map 0..1 to -1..1
                    (yPos - 0.5) * 2 // Map 0..1 to -1..1
                    ),
                child: Opacity(
                  opacity: 1.0 - progress,
                  child: Transform.scale(
                    scale: 0.5 + (progress * 0.5), // Grow slightly
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: constraints.maxWidth * 0.2, // Responsive size
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      );
    });
  }

  Widget _buildVideoOrAvatar() {
    if (_videoTrack != null && _isVideoEnabled) {
      return SizedBox.expand(
        child: VideoTrackRenderer(
          _videoTrack!,
          fit: _isScreenSharing ? VideoViewFit.contain : VideoViewFit.cover,
        ),
      );
    } else {
      // Show avatar when video is disabled
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[800],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                _getInitials(widget.participant.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.participant.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAudioTrack() {
    // In LiveKit Flutter, audio tracks are automatically played when subscribed
    return const SizedBox.shrink();
  }

  Widget _buildParticipantInfo() {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xB3000000), // 0.7 opacity black
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isLocal) ...[
              const Icon(
                Icons.person,
                color: AppTheme.secondaryColor,
                size: 16,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                widget.isLocal
                    ? 'أنت (${widget.participant.name})'
                    : widget.participant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaStatusIndicators() {
    return Positioned(
      top: 8,
      right: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Screen sharing indicator (if active)
          if (_isScreenSharing) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xCCFF9800), // 0.8 opacity orange
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.screen_share,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 6),
          ],
          // Microphone status
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isAudioEnabled
                  ? const Color(0xCC4CAF50) // 0.8 opacity green
                  : const Color(0xCCF44336), // 0.8 opacity red
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isAudioEnabled ? Icons.mic : Icons.mic_off,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          // Camera/Video status
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isVideoEnabled
                  ? const Color(0xCC4CAF50) // 0.8 opacity green
                  : const Color(0xCCF44336), // 0.8 opacity red
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isScreenSharing
                  ? Icons.screen_share
                  : (_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'م';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1))
          .toUpperCase();
    }
  }
}
