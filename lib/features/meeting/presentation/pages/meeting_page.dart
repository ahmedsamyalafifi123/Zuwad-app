import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/livekit_service.dart';
import '../widgets/participant_widget.dart';
import '../widgets/control_bar.dart';

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
  late final LiveKitService _liveKitService;
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isCameraEnabled = true;
  bool _isMicrophoneEnabled = true;
  String? _errorMessage;

  List<Participant> _participants = [];
  Participant? _localParticipant;
  Participant? _screenShareParticipant;

  @override
  void initState() {
    print('MeetingPage: initState started');
    super.initState();
    print('MeetingPage: Creating LiveKitService');
    _liveKitService = LiveKitService();
    print('MeetingPage: LiveKitService created');
    print('MeetingPage: Requesting permissions');
    _requestPermissions();
    print('MeetingPage: initState completed');
  }

  @override
  void dispose() {
    _liveKitService.disconnect();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    print('MeetingPage: _requestPermissions started');
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ];

    print('MeetingPage: Requesting permissions');
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    print('MeetingPage: Permissions statuses: $statuses');

    bool essentialGranted = statuses[Permission.camera]!.isGranted && statuses[Permission.microphone]!.isGranted;

    if (essentialGranted) {
      print('MeetingPage: Essential permissions granted');
      await _connectToRoom();
      print('MeetingPage: _connectToRoom completed');
    } else {
      print('MeetingPage: Essential permissions not granted');
      setState(() {
        _isConnecting = false;
        _errorMessage = 'يجب منح الصلاحيات للكاميرا والميكروفون للانضمام للدرس';
      });
    }
  }

  Future<void> _connectToRoom() async {
    print('MeetingPage: _connectToRoom started');
    try {
      print('MeetingPage: Calling LiveKitService.connectToRoom');
      final success = await _liveKitService.connectToRoom(
        roomName: widget.roomName,
        participantName: widget.participantName,
        participantId: widget.participantId,
      );
      print('MeetingPage: connectToRoom succeeded: $success');

      if (success && _liveKitService.room != null) {
        print('MeetingPage: Success and room not null, setup listeners');
        _setupRoomListeners();
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
        print('MeetingPage: State set to connected');
      } else {
        print('MeetingPage: Connection not successful');
        setState(() {
          _isConnecting = false;
          _errorMessage = 'فشل في الاتصال بالدرس. يرجى المحاولة مرة أخرى.';
        });
      }
    } catch (e) {
      print('MeetingPage: connectToRoom failed: $e');
      setState(() {
        _isConnecting = false;
        _errorMessage = 'حدث خطأ أثناء الاتصال: ${e.toString()}';
      });
    }
    print('MeetingPage: _connectToRoom ended');
  }

  void _setupRoomListeners() {
    final room = _liveKitService.room!;

    room.addListener(_onRoomUpdate);

    // Set initial participants
    _localParticipant = room.localParticipant;
    _participants = room.remoteParticipants.values.toList();
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
        _participants = room.remoteParticipants.values.toList();
        _screenShareParticipant = _findScreenShareParticipant();

        // Debug: Log participant and track information
        print('Room update: ${_participants.length} remote participants');
        for (final participant in _participants) {
          print(
              'Participant ${participant.identity}: ${participant.audioTrackPublications.length} audio tracks, ${participant.videoTrackPublications.length} video tracks');
          for (final pub in participant.audioTrackPublications) {
            print(
                '  Audio track: subscribed=${pub.subscribed}, muted=${pub.muted}, source=${pub.source}');
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

    for (final participant in allParticipants) {
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

  Future<void> _switchCamera() async {
    await _liveKitService.switchCamera();
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
                      'متصل (${_participants.length + 1})',
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
            onSwitchCamera: _switchCamera,
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
}
