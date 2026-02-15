import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/theme/app_theme.dart';

class ParticipantWidget extends StatefulWidget {
  final Participant participant;
  final bool isLocal;
  final bool forceAvatar;

  const ParticipantWidget({
    super.key,
    required this.participant,
    required this.isLocal,
    this.forceAvatar = false,
  });

  @override
  State<ParticipantWidget> createState() => _ParticipantWidgetState();
}

class _ParticipantWidgetState extends State<ParticipantWidget> {
  VideoTrack? _videoTrack;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isScreenSharing = false;

  @override
  void initState() {
    super.initState();
    _setupParticipant();
    widget.participant.addListener(_onParticipantChanged);
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLocal ? AppTheme.secondaryColor : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmall = constraints.maxWidth < 150;
          return Stack(
            children: [
              // Video or avatar
              _buildVideoOrAvatar(),

              // Audio track (invisible but necessary for playback)
              _buildAudioTrack(),

              // Participant info overlay
              _buildParticipantInfo(isSmall),

              // Media status indicators
              _buildMediaStatusIndicators(isSmall),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoOrAvatar() {
    if (_videoTrack != null && _isVideoEnabled && !widget.forceAvatar) {
      return SizedBox.expand(
        child: VideoTrackRenderer(
          _videoTrack!,
          fit: _isScreenSharing ? VideoViewFit.contain : VideoViewFit.cover,
        ),
      );
    } else {
      // Show avatar when video is disabled
      return LayoutBuilder(
        builder: (context, constraints) {
          final double size =
              math.min(constraints.maxWidth, constraints.maxHeight);
          final double avatarRadius = (size * 0.3).clamp(15.0, 40.0);
          final double fontSize = (size * 0.15).clamp(10.0, 24.0);
          final double nameFontSize = (size * 0.12).clamp(8.0, 16.0);
          final double spacing = (size * 0.08).clamp(4.0, 12.0);

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[800],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    _getInitials(widget.participant.name),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    widget.participant.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildAudioTrack() {
    // In LiveKit Flutter, audio tracks are automatically played when subscribed
    return const SizedBox.shrink();
  }

  Widget _buildParticipantInfo(bool isSmall) {
    return Positioned(
      bottom: isSmall ? 4 : 8,
      left: isSmall ? 4 : 8,
      right: isSmall ? 4 : 8,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 12,
          vertical: isSmall ? 3 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xB3000000), // 0.7 opacity black
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isLocal) ...[
              Icon(
                Icons.person,
                color: AppTheme.secondaryColor,
                size: isSmall ? 12 : 16,
              ),
              SizedBox(width: isSmall ? 2 : 4),
            ],
            Expanded(
              child: Text(
                widget.isLocal
                    ? (isSmall ? 'أنت' : 'أنت (${widget.participant.name})')
                    : widget.participant.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 10 : 12,
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

  Widget _buildMediaStatusIndicators(bool isSmall) {
    final double iconSize = isSmall ? 12 : 16;
    final double padding = isSmall ? 4 : 6;
    final double spacing = isSmall ? 4 : 6;

    return Positioned(
      top: isSmall ? 4 : 8,
      right: isSmall ? 4 : 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Screen sharing indicator (if active)
          if (_isScreenSharing) ...[
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: const Color(0xCCFF9800), // 0.8 opacity orange
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.screen_share,
                color: Colors.white,
                size: iconSize,
              ),
            ),
            SizedBox(width: spacing),
          ],
          // Microphone status
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: _isAudioEnabled
                  ? const Color(0xCC4CAF50) // 0.8 opacity green
                  : const Color(0xCCF44336), // 0.8 opacity red
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isAudioEnabled ? Icons.mic : Icons.mic_off,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          SizedBox(width: spacing),
          // Camera/Video status
          Container(
            padding: EdgeInsets.all(padding),
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
              size: iconSize,
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
