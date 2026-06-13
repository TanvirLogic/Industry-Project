import 'package:flutter/material.dart';

class DashedBorder extends ShapeBorder {
  final Color color;
  final double width;
  final double radius;

  const DashedBorder({
    required this.color,
    this.width = 1.5,
    this.radius = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  ShapeBorder scale(double t) => DashedBorder(color: color, width: width * t, radius: radius * t);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final metric = path.computeMetrics().first;

    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
      final segment = metric.extractPath(distance, end);
      canvas.drawPath(segment, paint);
      distance += dashWidth + dashSpace;
    }
  }
}
