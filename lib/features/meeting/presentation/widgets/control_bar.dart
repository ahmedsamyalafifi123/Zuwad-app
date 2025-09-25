import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ControlBar extends StatelessWidget {
  final bool isCameraEnabled;
  final bool isMicrophoneEnabled;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onSwitchCamera;
  final VoidCallback onLeaveMeeting;

  const ControlBar({
    super.key,
    required this.isCameraEnabled,
    required this.isMicrophoneEnabled,
    required this.onToggleCamera,
    required this.onToggleMicrophone,
    required this.onSwitchCamera,
    required this.onLeaveMeeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Camera toggle
            _buildControlButton(
              icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
              isEnabled: isCameraEnabled,
              onPressed: onToggleCamera,
              tooltip: isCameraEnabled ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
            ),
            
            // Microphone toggle
            _buildControlButton(
              icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              isEnabled: isMicrophoneEnabled,
              onPressed: onToggleMicrophone,
              tooltip: isMicrophoneEnabled ? 'كتم الصوت' : 'إلغاء كتم الصوت',
            ),
            
            // Switch camera
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              isEnabled: true,
              onPressed: onSwitchCamera,
              tooltip: 'تبديل الكاميرا',
              backgroundColor: Colors.grey[700],
            ),
            
            // Leave meeting
            _buildControlButton(
              icon: Icons.call_end,
              isEnabled: true,
              onPressed: () => _showLeaveConfirmation(context),
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
  }) {
    final bgColor = backgroundColor ?? 
        (isEnabled ? AppTheme.primaryColor : Colors.grey[600]!);
    final iColor = iconColor ?? Colors.white;

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iColor,
                size: 28,
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
