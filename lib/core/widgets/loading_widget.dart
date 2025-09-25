import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoadingWidget extends StatelessWidget {
  final double size;
  final Color? color;
  final String? message;

  const LoadingWidget({
    super.key,
    this.size = 50.0,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitDoubleBounce(
            color: color ?? const Color(0xFFf6c302),
            size: size,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message ?? 'جاري التحميل...',
              style: TextStyle(
                color: color ?? const Color(0xFFf6c302),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ],
      ),
    );
  }
}
