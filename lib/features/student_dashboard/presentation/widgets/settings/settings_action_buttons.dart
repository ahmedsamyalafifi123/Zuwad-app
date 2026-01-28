import 'package:flutter/material.dart';

class SettingsActionButtons extends StatelessWidget {
  final VoidCallback onAddStudent;
  final VoidCallback onNewExperience;

  const SettingsActionButtons({
    super.key,
    required this.onAddStudent,
    required this.onNewExperience,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'إضافة طالب جديد',
            Icons.person_add_alt_1_rounded,
            onAddStudent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'تجربة مادة جديدة',
            Icons.post_add_rounded,
            onNewExperience,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return SizedBox(
      height: isDesktop ? 60 : 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: isDesktop ? 24 : 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Qatar',
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
