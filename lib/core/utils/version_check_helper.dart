import 'package:flutter/material.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class VersionCheckHelper {
  static Future<void> checkVersion(BuildContext context) async {
    try {
      final newVersion = NewVersionPlus();

      final status = await newVersion.getVersionStatus();
      if (status != null && status.canUpdate) {
        if (context.mounted) {
          _showUpdateModal(context, status);
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  static void _showUpdateModal(BuildContext context, dynamic status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Prevent physical back button
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تحديث جديد متاح',
                    style: TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'يتوفر إصدار جديد من التطبيق (${status.storeVersion}). يرجى التحديث للحصول على أفضل تجربة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Qatar',
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final Uri url = Uri.parse(status.appStoreLink);
                        try {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Could not launch store link: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'تحديث الان',
                        style: TextStyle(
                          fontFamily: 'Qatar',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'تحديث لاحقاً',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
