import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/livekit_service.dart';
import '../widgets/participant_widget.dart';
import '../widgets/control_bar.dart';
import 'package:audioplayers/audioplayers.dart';

class MeetingPage extends StatefulWidget {
  final String roomName;
  final String participantName;
  final String participantId;
  final String lessonName;
  final String teacherName;

  const MeetingPage({
    super.key,
    required this.roomName,
    required this.participantName,
    required this.participantId,
    required this.lessonName,
    required this.teacherName,
  });

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  static const MethodChannel _pipChannel = MethodChannel('com.zuwad/pip');

  late final LiveKitService _liveKitService;
  late final EventsListener<RoomEvent> _roomListener;
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isCameraEnabled = true;
  bool _isMicrophoneEnabled = true;
  String? _errorMessage;

  List<Participant> _participants = [];
  Participant? _localParticipant;
  Participant? _screenShareParticipant;

  // Celebration state - now triggers via an object to avoid duplicate adds on rebuild
  _ReactionEvent? _reactionEvent;
  // Throttling variables
  DateTime _lastReactionTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAudioTime = DateTime.fromMillisecondsSinceEpoch(0);

  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    if (kDebugMode) {
      print('MeetingPage: initState started');
    }
    super.initState();

    // Enable wake lock to keep screen on during meeting
    _enableWakeLock();

    // Enable PiP mode for this page
    _enablePiP();

    // Initialize AudioPlayer
    _audioPlayer = AudioPlayer();
    _initAudio();

    if (kDebugMode) {
      print('MeetingPage: Creating LiveKitService');
    }
    _liveKitService = LiveKitService();
    if (kDebugMode) {
      print('MeetingPage: LiveKitService created');
      print('MeetingPage: Requesting permissions');
    }
    _requestPermissions();
    if (kDebugMode) {
      print('MeetingPage: initState completed');
    }
  }

  @override
  void dispose() {
    // Disable wake lock when leaving meeting page
    _disableWakeLock();
    // Disable PiP mode when leaving meeting page
    _disablePiP();
    // Dispose event listener
    _roomListener.dispose();
    // _celebrationTimer removed in optimization
    _audioPlayer.dispose();
    _liveKitService.disconnect();
    super.dispose();
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      if (kDebugMode) {
        print('MeetingPage: Wake lock enabled - screen will stay on');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeetingPage: Failed to enable wake lock: $e');
      }
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      if (kDebugMode) {
        print('MeetingPage: Wake lock disabled - screen timeout restored');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeetingPage: Failed to disable wake lock: $e');
      }
    }
  }

  Future<void> _initAudio() async {
    // Configure audio context to mix with other sources (LiveKit)
    // This is crucial to prevent the meeting audio from being interrupted
    await _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus
            .none, // Do not request focus to avoid ducking LiveKit
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory
            .playback, // Changed to playback to allow mixWithOthers
        options: const {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    ));
  }

  Future<void> _enablePiP() async {
    if (kIsWeb) return;
    try {
      await _pipChannel.invokeMethod('enablePip');
      if (kDebugMode) {
        print('MeetingPage: PiP enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeetingPage: Failed to enable PiP: $e');
      }
    }
  }

  Future<void> _disablePiP() async {
    if (kIsWeb) return;
    try {
      await _pipChannel.invokeMethod('disablePip');
      if (kDebugMode) {
        print('MeetingPage: PiP disabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeetingPage: Failed to disable PiP: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (kDebugMode) {
      print('MeetingPage: _requestPermissions started');
    }
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      if (!kIsWeb) ...[
        Permission.bluetooth,
        Permission.bluetoothConnect,
      ],
    ];

    if (kDebugMode) {
      print('MeetingPage: Requesting permissions');
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    if (kDebugMode) {
      print('MeetingPage: Permissions statuses: $statuses');
    }

    bool essentialGranted = statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;

    if (essentialGranted) {
      if (kDebugMode) {
        print('MeetingPage: Essential permissions granted');
      }
      await _connectToRoom();
      if (kDebugMode) {
        print('MeetingPage: _connectToRoom completed');
      }
    } else {
      if (kDebugMode) {
        print('MeetingPage: Essential permissions not granted');
      }
      setState(() {
        _isConnecting = false;
        _errorMessage = 'يجب منح الصلاحيات للكاميرا والميكروفون للانضمام للدرس';
      });
    }
  }

  Future<void> _connectToRoom() async {
    if (kDebugMode) {
      print('MeetingPage: _connectToRoom started');
    }
    try {
      if (kDebugMode) {
        print('MeetingPage: Calling LiveKitService.connectToRoom');
      }
      final success = await _liveKitService.connectToRoom(
        roomName: widget.roomName,
        participantName: widget.participantName,
        participantId: widget.participantId,
      );
      if (kDebugMode) {
        print('MeetingPage: connectToRoom succeeded: $success');
      }

      if (success && _liveKitService.room != null) {
        if (kDebugMode) {
          print('MeetingPage: Success and room not null, setup listeners');
        }
        _setupRoomListeners();
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
        if (kDebugMode) {
          print('MeetingPage: State set to connected');
        }
      } else {
        if (kDebugMode) {
          print('MeetingPage: Connection not successful');
        }
        setState(() {
          _isConnecting = false;
          _errorMessage = 'فشل في الاتصال بالدرس. يرجى المحاولة مرة أخرى.';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeetingPage: connectToRoom failed: $e');
      }
      setState(() {
        _isConnecting = false;
        _errorMessage = 'حدث خطأ أثناء الاتصال: ${e.toString()}';
      });
    }
    if (kDebugMode) {
      print('MeetingPage: _connectToRoom ended');
    }
  }

  void _setupRoomListeners() {
    final room = _liveKitService.room!;

    // General room state listener
    room.addListener(_onRoomUpdate);

    // Create events listener for track subscription events (critical for audio playback)
    _roomListener = room.createListener();

    // Listen for track subscription events
    _roomListener
      ..on<TrackSubscribedEvent>((event) {
        if (kDebugMode) {
          print(
              'MeetingPage: Track subscribed - ${event.track.kind} from ${event.participant.identity}');
        }
        if (mounted) {
          setState(() {
            _onRoomUpdate();
          });
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (kDebugMode) {
          print(
              'MeetingPage: Track unsubscribed - ${event.track.kind} from ${event.participant.identity}');
        }
        if (mounted) {
          setState(() {
            _onRoomUpdate();
          });
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        if (kDebugMode) {
          print(
              'MeetingPage: Participant connected - ${event.participant.identity}');
        }
        if (mounted) {
          setState(() {
            _onRoomUpdate();
          });
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (kDebugMode) {
          print(
              'MeetingPage: Participant disconnected - ${event.participant.identity}');
        }
        if (mounted) {
          setState(() {
            _onRoomUpdate();
          });
        }
      })
      ..on<DataReceivedEvent>((event) {
        if (kDebugMode) {
          print('MeetingPage: Data received');
        }
        _handleDataReceived(event);
      });

    // Set initial participants (filter out hidden KPI observers)
    _localParticipant = room.localParticipant;

    // Filter out hidden KPI observers using the helper method
    final allRemoteParticipants = room.remoteParticipants.values.toList();
    _participants = LiveKitService.filterHiddenObservers(allRemoteParticipants);

    if (kDebugMode) {
      if (allRemoteParticipants.length != _participants.length) {
        final hiddenCount = allRemoteParticipants.length - _participants.length;
        print(
            'MeetingPage: Initial setup - filtered out $hiddenCount hidden KPI observer(s)');
      }
      print(
          'MeetingPage: Initial setup - ${_participants.length} visible participants (filtered from ${allRemoteParticipants.length} total)');
    }

    _screenShareParticipant = _findScreenShareParticipant();

    // Enable camera and microphone by default
    _liveKitService.enableCamera();
    _liveKitService.enableMicrophone();
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {
        final room = _liveKitService.room!;
        _localParticipant = room.localParticipant;

        // Filter out hidden KPI observers using the helper method
        final allRemoteParticipants = room.remoteParticipants.values.toList();
        _participants =
            LiveKitService.filterHiddenObservers(allRemoteParticipants);

        if (kDebugMode &&
            allRemoteParticipants.length != _participants.length) {
          final hiddenCount =
              allRemoteParticipants.length - _participants.length;
          print(
              'MeetingPage: Filtered out $hiddenCount hidden KPI observer(s)');
        }

        _screenShareParticipant = _findScreenShareParticipant();

        // Debug: Log participant and track information
        if (kDebugMode) {
          print(
              'Room update: ${_participants.length} visible remote participants (filtered from ${allRemoteParticipants.length} total)');
          for (final participant in _participants) {
            print(
                'Participant ${participant.identity}: ${participant.audioTrackPublications.length} audio tracks, ${participant.videoTrackPublications.length} video tracks');
            for (final pub in participant.audioTrackPublications) {
              print(
                  '  Audio track: subscribed=${pub.subscribed}, muted=${pub.muted}, source=${pub.source}');
            }
          }
        }
      });
    }
  }

  Participant? _findScreenShareParticipant() {
    final allParticipants = <Participant>[
      if (_localParticipant != null) _localParticipant!,
      ..._participants,
    ];

    // Find first participant with screen share (excluding hidden KPI observers)
    for (final participant in allParticipants) {
      // Skip hidden KPI observers
      if (LiveKitService.isHiddenKPIObserver(participant)) {
        continue;
      }

      final hasScreen = participant.videoTrackPublications.any((pub) {
        final sourceName = pub.source.toString().toLowerCase();
        return sourceName.contains('screen') &&
            pub.track != null &&
            pub.muted == false;
      });
      if (hasScreen) return participant;
    }
    return null;
  }

  void _handleDataReceived(DataReceivedEvent event) {
    try {
      // Decode data (UTF-8)
      final String decoded = utf8.decode(event.data);
      final Map<String, dynamic> payload = jsonDecode(decoded);

      if (payload['type'] == 'celebration') {
        final String variant = payload['variant'] ?? 'hearts';
        final now = DateTime.now();

        // Throttle visuals - max 1 every 300ms
        if (now.difference(_lastReactionTime).inMilliseconds > 300) {
          _triggerFullPageCelebration(variant);
          _lastReactionTime = now;
        }

        // Throttle audio - max 1 every 500ms
        if (now.difference(_lastAudioTime).inMilliseconds > 500) {
          _playCelebrationSound(variant);
          _lastAudioTime = now;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing data received: $e');
      }
    }
  }

  void _triggerFullPageCelebration(String variant) {
    if (kDebugMode) {
      print('Triggering full-page celebration ($variant)');
    }

    if (mounted) {
      // Update state with unique timestamp to force didUpdateWidget detection
      setState(() {
        _reactionEvent = _ReactionEvent(variant, DateTime.now());
      });

      // We don't clear it, so the overlay stays mounted (preserving existing particles)
    }
  }

  Future<void> _playCelebrationSound(String variant) async {
    try {
      String soundPath;
      switch (variant) {
        case 'hearts':
          soundPath = 'audio/hearts.mp3';
          break;
        case 'confetti':
          soundPath = 'audio/Confetti.mp3';
          break;
        case 'claps':
          soundPath = 'audio/claps.mp3';
          break;
        case 'thumbs':
          soundPath = 'audio/Thumbs.mp3';
          break;
        default:
          return;
      }

      if (kDebugMode) {
        print('Playing celebration sound: $soundPath');
      }

      // Stop any currently playing sound to avoid overlap
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(soundPath),
          mode: PlayerMode.lowLatency);
    } catch (e) {
      if (kDebugMode) {
        print('Error playing celebration sound: $e');
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_isCameraEnabled) {
      await _liveKitService.disableCamera();
    } else {
      await _liveKitService.enableCamera();
    }
    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
    });
  }

  Future<void> _toggleMicrophone() async {
    if (_isMicrophoneEnabled) {
      await _liveKitService.disableMicrophone();
    } else {
      await _liveKitService.enableMicrophone();
    }
    setState(() {
      _isMicrophoneEnabled = !_isMicrophoneEnabled;
    });
  }

  void _leaveMeeting() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lessonName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'مع ${widget.teacherName}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _leaveMeeting,
          ),
          actions: [
            if (_isConnected)
              Container(
                margin: const EdgeInsets.only(left: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8),
                    const SizedBox(width: 4),
                    Text(
                      'متصل (${_participants.length + 1})', // +1 for local participant
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isConnecting) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (!_isConnected) {
      return _buildErrorScreen();
    }

    return _buildMeetingScreen();
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: AppTheme.primaryColor,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFf6c302),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'جاري الاتصال بالدرس...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يرجى الانتظار',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: AppTheme.primaryColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'حدث خطأ غير متوقع',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isConnecting = true;
                    _errorMessage = null;
                  });
                  _requestPermissions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf6c302),
                  foregroundColor: AppTheme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingScreen() {
    final allParticipants = <Participant>[
      if (_localParticipant != null) _localParticipant!,
      ..._participants,
    ];

    return Stack(
      children: [
        // Main area: either screen share or grid
        Positioned.fill(
          child: _screenShareParticipant != null
              ? ParticipantWidget(
                  participant: _screenShareParticipant!,
                  isLocal: _screenShareParticipant == _localParticipant,
                )
              : _buildSquareGrid(allParticipants),
        ),

        // Thumbnails strip when screen sharing
        if (_screenShareParticipant != null)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allParticipants.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final p = allParticipants[index];
                  return AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ParticipantWidget(
                        participant: p,
                        isLocal: p == _localParticipant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Full-page celebration overlay
        if (_reactionEvent != null) _buildFullPageCelebration(),

        // Control bar at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ControlBar(
            isCameraEnabled: _isCameraEnabled,
            isMicrophoneEnabled: _isMicrophoneEnabled,
            onToggleCamera: _toggleCamera,
            onToggleMicrophone: _toggleMicrophone,
            onSwitchCamera: () {}, // Removed functionality
            onLeaveMeeting: _leaveMeeting,
          ),
        ),
      ],
    );
  }

  // Removed old _buildVideoArea in favor of unified grid/screen-share layout

  Widget _buildSquareGrid(List<Participant> participants) {
    // Limit participants to avoid performance issues
    const maxDisplayedParticipants = 16;
    final displayList = participants.take(maxDisplayedParticipants).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = displayList.length;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        // Use a square grid: columns = ceil(sqrt(n))
        final columns = math.max(1, math.min(4, math.sqrt(count).ceil()));

        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0, // perfect squares
            ),
            itemBuilder: (context, index) {
              final p = displayList[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ParticipantWidget(
                  participant: p,
                  isLocal: p == _localParticipant,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Removed unused "more participants" indicator for the new grid layout

  Widget _buildFullPageCelebration() {
    return Positioned.fill(
      child: _CelebrationOverlay(
        event: _reactionEvent!,
      ),
    );
  }
}

class _ReactionEvent {
  final String variant;
  final DateTime timestamp;
  _ReactionEvent(this.variant, this.timestamp);
}

class _CelebrationOverlay extends StatefulWidget {
  final _ReactionEvent event;

  const _CelebrationOverlay({required this.event});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 1000));
    _controller.addListener(() {
      if (_particles.isNotEmpty) {
        setState(() {
          _updateParticles();
        });
      } else if (_controller.isAnimating) {
        _controller.stop();
      }
    });
    // Trigger first batch
    _addParticles(widget.event.variant);
    _controller.repeat();
  }

  @override
  void didUpdateWidget(_CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only add if it's a NEW event (timestamp check causes equality failure for new instances)
    if (widget.event != oldWidget.event) {
      _addParticles(widget.event.variant);
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  void _addParticles(String variant) {
    final bool isConfetti = variant == 'confetti';
    // Increased particle count as requested (was 20/5)
    final int count = isConfetti ? 50 : 20;

    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(), // 0.0 to 1.0
        y: 1.1, // Start slightly below screen
        speed: 0.005 + _random.nextDouble() * 0.01,
        angle: 0, // No rotation
        spinSpeed: 0, // No spin
        color: isConfetti ? _getRandomColor() : null,
        emoji: isConfetti ? null : _getEmoji(variant),
        size: isConfetti
            ? (5 + _random.nextDouble() * 10)
            : (30 + _random.nextDouble() * 20), // Slightly larger emojis
        wobbleOffset: _random.nextDouble() * 2 * math.pi,
      ));
    }
  }

  Color _getRandomColor() {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan
    ];
    return colors[_random.nextInt(colors.length)];
  }

  String _getEmoji(String variant) {
    switch (variant) {
      case 'hearts':
        return '❤️';
      case 'claps':
        return '👏';
      case 'thumbs':
        return '👍';
      default:
        return '❤️';
    }
  }

  void _updateParticles() {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.y -= p.speed;
      p.angle += p.spinSpeed;
      p.wobble += 0.05;

      // Remove if off screen
      if (p.y < -0.1) {
        _particles.removeAt(i);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: ParticlePainter(_particles),
        size: Size.infinite,
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double speed;
  double angle; // for rotation
  double spinSpeed;
  Color? color;
  String? emoji;
  double size;
  double wobbleOffset;
  double wobble = 0;

  Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.spinSpeed,
    this.color,
    this.emoji,
    required this.size,
    required this.wobbleOffset,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final TextPainter _textPainter =
      TextPainter(textDirection: TextDirection.ltr);

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var p in particles) {
      final x = (p.x * size.width) + (math.sin(p.wobble + p.wobbleOffset) * 10);
      final y = p.y * size.height;

      // Calculate opacity based on Y position (fade out at top)
      // 1.0 at y=0.5 -> 0.0 at y=0.0
      double opacity = 1.0;
      if (p.y < 0.3) {
        opacity = (p.y / 0.3).clamp(0.0, 1.0);
      }

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle); // Angle is now always 0 (no rotation)

      if (p.emoji != null) {
        // Apply opacity to text
        _textPainter.text = TextSpan(
          text: p.emoji,
          style: TextStyle(
            fontSize: p.size,
            color: Colors.white.withOpacity(opacity), // Fading opacity
          ),
        );
        _textPainter.layout();
        _textPainter.paint(
            canvas, Offset(-_textPainter.width / 2, -_textPainter.height / 2));
      } else if (p.color != null) {
        paint.color = p.color!.withOpacity(opacity); // Fading opacity
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
