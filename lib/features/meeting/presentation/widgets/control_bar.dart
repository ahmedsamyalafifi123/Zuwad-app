import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ControlBar extends StatelessWidget {
  final bool isCameraEnabled;
  final bool isMicrophoneEnabled;
  final bool isWhiteboardVisible;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onSwitchCamera;
  final VoidCallback onLeaveMeeting;

  const ControlBar({
    super.key,
    required this.isCameraEnabled,
    required this.isMicrophoneEnabled,
    required this.isWhiteboardVisible,
    required this.onToggleCamera,
    required this.onToggleMicrophone,
    required this.onSwitchCamera,
    required this.onLeaveMeeting,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildLandscapeBar(context);
    } else {
      return _buildPortraitBar(context);
    }
  }

  Widget _buildLandscapeBar(BuildContext context) {
    return Center(
      heightFactor: 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xB3000000), // 0.7 opacity black
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
              isEnabled: isCameraEnabled,
              onPressed: onToggleCamera,
              tooltip: isCameraEnabled ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
              backgroundColor: isCameraEnabled ? Colors.green : null,
              size: 44, // Smaller size for landscape
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              isEnabled: isMicrophoneEnabled,
              onPressed: onToggleMicrophone,
              tooltip: isMicrophoneEnabled ? 'كتم الصوت' : 'إلغاء كتم الصوت',
              backgroundColor: isMicrophoneEnabled ? Colors.green : null,
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              icon: Icons.call_end,
              isEnabled: true,
              onPressed: () => _showLeaveConfirmation(context), // Pass context
              tooltip: 'مغادرة الدرس',
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              size: 44,
              iconSize: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: isWhiteboardVisible
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xCC000000), // 0.8 opacity black
                  Color(0xE6000000), // 0.9 opacity black
                ],
              ),
        color: isWhiteboardVisible ? Colors.black.withOpacity(0.2) : null,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
              isEnabled: isCameraEnabled,
              onPressed: onToggleCamera,
              tooltip: isCameraEnabled ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
              backgroundColor: isCameraEnabled ? Colors.green : null,
            ),
            _buildControlButton(
              icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              isEnabled: isMicrophoneEnabled,
              onPressed: onToggleMicrophone,
              tooltip: isMicrophoneEnabled ? 'كتم الصوت' : 'إلغاء كتم الصوت',
              backgroundColor: isMicrophoneEnabled ? Colors.green : null,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              isEnabled: true,
              onPressed: () => _showLeaveConfirmation(context), // Pass context
              tooltip: 'مغادرة الدرس',
              backgroundColor: Colors.red,
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onPressed,
    required String tooltip,
    Color? backgroundColor,
    Color? iconColor,
    double size = 56, // Default size for portrait
    double iconSize = 28,
  }) {
    final bgColor = backgroundColor ??
        (isEnabled ? AppTheme.primaryColor : Colors.grey[600]!);
    final iColor = iconColor ?? Colors.white;

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x4D000000), // 0.3 opacity black
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: bgColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'مغادرة الدرس',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من أنك تريد مغادرة الدرس؟',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  onLeaveMeeting(); // Leave meeting
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'مغادرة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
