import 'package:flutter/material.dart';

class IslamicBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int chatUnreadCount; // Total unread chat messages
  final Map<int, GlobalKey>? itemKeys;

  const IslamicBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.chatUnreadCount = 0,
    this.itemKeys,
  });

  static const List<Map<String, dynamic>> navItems = [
    {'icon': Icons.home_rounded, 'label': 'الرئيسة'},
    {'icon': Icons.calendar_month_rounded, 'label': 'الجدول'},
    {'icon': Icons.chat_bubble_rounded, 'label': 'المراسلة'},
    {'icon': Icons.settings_rounded, 'label': 'الاعدادات'},
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Main nav bar container with Islamic modern design
              Container(
                margin: const EdgeInsets.only(top: 25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 255, 255), // Warm cream white
                      Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      // Subtle Islamic geometric pattern overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: IslamicPatternPainter(),
                        ),
                      ),
                      // Navigation items
                      Row(
                        children: [
                          // Left side: 2 nav items
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNavItem(0),
                                _buildNavItem(1),
                              ],
                            ),
                          ),
                          // Center spacer for logo
                          const SizedBox(width: 70),
                          // Right side: 2 nav items
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNavItem(2),
                                _buildNavItem(3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Decorative centered logo (non-clickable)
              Positioned(
                top: -15,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/zuwad.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = currentIndex == index;
    final item = navItems[index];
    final bool showBadge = index == 2 && chatUnreadCount > 0; // Messages tab

    return GestureDetector(
      key: itemKeys?[index],
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    item['icon'] as IconData,
                    size: isSelected ? 22 : 20,
                    color: isSelected
                        ? const Color.fromARGB(
                            255, 224, 173, 5) // Gold/Yellow when selected
                        : const Color(0xFF8B0628), // Burgundy when not selected
                  ),
                ),
                // Unread badge for Messages tab
                if (showBadge)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 12, 207, 35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        chatUnreadCount > 99
                            ? '99+'
                            : chatUnreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Qatar',
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color.fromARGB(255, 0, 0, 0) // Black when selected
                    : const Color(0xFF8B0628), // Burgundy when not selected
              ),
              child: Text(item['label'] as String),
            ),
          ],
        ),
      ),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AD4AF37) // 4% opacity
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final path = Path()
          ..moveTo(x, y - 5)
          ..lineTo(x + 5, y)
          ..lineTo(x, y + 5)
          ..lineTo(x - 5, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
