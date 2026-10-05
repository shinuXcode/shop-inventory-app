import 'package:flutter/material.dart';

class SBillLogo extends StatelessWidget {
  const SBillLogo({super.key, this.size = 40, this.showName = false});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SBillLogoPainter(
          light: Theme.of(context).colorScheme.primary,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );

    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(
          'SBILL',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
        ),
      ],
    );
  }
}

class _SBillLogoPainter extends CustomPainter {
  const _SBillLogoPainter({required this.light, required this.dark});

  final Color light;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(32 * scale, 32 * scale, 960 * scale, 960 * scale),
      Radius.circular(220 * scale),
    );
    final gradient = LinearGradient(
      colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rrect.outerRect));

    final path = Path()
      ..moveTo(710 * scale, 285 * scale)
      ..cubicTo(640 * scale, 212 * scale, 526 * scale, 180 * scale, 407 * scale, 207 * scale)
      ..cubicTo(286 * scale, 234 * scale, 213 * scale, 303 * scale, 213 * scale, 395 * scale)
      ..cubicTo(213 * scale, 501 * scale, 287 * scale, 546 * scale, 418 * scale, 582 * scale)
      ..cubicTo(552 * scale, 618 * scale, 617 * scale, 642 * scale, 617 * scale, 703 * scale)
      ..cubicTo(617 * scale, 763 * scale, 556 * scale, 804 * scale, 463 * scale, 804 * scale)
      ..cubicTo(380 * scale, 804 * scale, 313 * scale, 775 * scale, 256 * scale, 686 * scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 86 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (!dark) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 * scale, 30 * scale, 964 * scale, 964 * scale),
          Radius.circular(224 * scale),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..color = light.withValues(alpha: .10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SBillLogoPainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}
