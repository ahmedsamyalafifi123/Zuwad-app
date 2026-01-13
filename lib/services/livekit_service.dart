import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../core/config/livekit_config.dart';

class LiveKitService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  LiveKitService._internal();

  Room? _room;
  bool _isConnected = false;

  Room? get room => _room;
  bool get isConnected => _isConnected;

  /// Generate JWT token for LiveKit authentication
  String generateToken({
    required String roomName,
    required String participantName,
    required String participantId,
  }) {
    final now = DateTime.now();
    final exp = now.add(LiveKitConfig.tokenExpiration);

    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'iss': LiveKitConfig.apiKey,
      'sub': participantId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': true,
        'canSubscribe': true,
      },
      'name': participantName,
    };

    final headerEncoded =
        base64Url.encode(utf8.encode(json.encode(header))).replaceAll('=', '');
    final payloadEncoded =
        base64Url.encode(utf8.encode(json.encode(payload))).replaceAll('=', '');
    final message = '$headerEncoded.$payloadEncoded';

    final key = utf8.encode(LiveKitConfig.apiSecret);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(message));
    final signature = base64Url.encode(digest.bytes).replaceAll('=', '');

    return '$message.$signature';
  }

  /// Connect to LiveKit room
  Future<bool> connectToRoom({
    required String roomName,
    required String participantName,
    required String participantId,
  }) async {
    if (kDebugMode) {
      print('LiveKitService: connectToRoom started');
    }
    try {
      if (kDebugMode) {
        print('LiveKitService: Generating token');
      }
      // Generate token
      final token = generateToken(
        roomName: roomName,
        participantName: participantName,
        participantId: participantId,
      );
      if (kDebugMode) {
        print('LiveKitService: Token generated');
        print('LiveKitService: Creating Room');
      }

      // Create room instance with audio-specific configurations
      _room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: CameraCaptureOptions(
            maxFrameRate: LiveKitConfig.defaultVideoFrameRate.toDouble(),
          ),
          defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
            maxFrameRate: 15.0,
          ),
          defaultAudioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );
      if (kDebugMode) {
        print('LiveKitService: Room created');
      }

      try {
        if (kDebugMode) {
          print('LiveKitService: Connecting to room');
        }
        // Connect to room with audio-focused options
        await _room!.connect(
          LiveKitConfig.livekitUrl,
          token,
          connectOptions: const ConnectOptions(
            autoSubscribe: true,
          ),
        );
        if (kDebugMode) {
          print('LiveKitService: Connected successfully');
        }

        _isConnected = true;
      } catch (connectError) {
        if (kDebugMode) {
          print('LiveKit connection error: $connectError');
          print('LiveKitService: Attempting fallback connection');
        }
        // Try with simpler options if the first attempt fails
        try {
          await _room!.connect(
            LiveKitConfig.livekitUrl,
            token,
            connectOptions: const ConnectOptions(
              autoSubscribe: true,
              protocolVersion: ProtocolVersion.v8,
            ),
          );
          if (kDebugMode) {
            print('LiveKitService: Fallback connection successful');
          }
          _isConnected = true;
        } catch (fallbackError) {
          if (kDebugMode) {
            print('LiveKit fallback connection error: $fallbackError');
          }
          rethrow;
        }
      }
      if (kDebugMode) {
        print('LiveKitService: connectToRoom completed successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to LiveKit room: $e');
      }
      _isConnected = false;
      return false;
    }
  }

  /// Enable camera
  Future<bool> enableCamera() async {
    try {
      if (_room == null) return false;
      await _room!.localParticipant?.setCameraEnabled(true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling camera: $e');
      }
      return false;
    }
  }

  /// Disable camera
  Future<bool> disableCamera() async {
    try {
      if (_room == null) return false;
      await _room!.localParticipant?.setCameraEnabled(false);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling camera: $e');
      }
      return false;
    }
  }

  /// Enable microphone
  Future<bool> enableMicrophone() async {
    try {
      if (_room == null) return false;
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling microphone: $e');
      }
      return false;
    }
  }

  /// Disable microphone
  Future<bool> disableMicrophone() async {
    try {
      if (_room == null) return false;
      await _room!.localParticipant?.setMicrophoneEnabled(false);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling microphone: $e');
      }
      return false;
    }
  }

  /// Switch camera (front/back)
  Future<bool> switchCamera() async {
    try {
      if (_room == null) return false;

      // For now, disable and re-enable camera to switch
      await disableCamera();
      await Future.delayed(const Duration(milliseconds: 100));
      await enableCamera();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error switching camera: $e');
      }
      return false;
    }
  }

  /// Disconnect from room
  Future<void> disconnect() async {
    try {
      await _room?.disconnect();
      _room = null;
      _isConnected = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting from room: $e');
      }
    }
  }

  /// Generate room name based on student and teacher IDs
  /// Uses fixed room format to match WordPress backend
  String generateRoomName({
    required String studentId,
    required String teacherId,
  }) {
    return 'room_student_${studentId}_teacher_$teacherId';
  }

  /// Dispose resources
  void dispose() {
    disconnect();
  }
}
