import 'package:flutter/material.dart';

class CalendarGridPainter extends CustomPainter {
  CalendarGridPainter({
    required this.cellCount,
    required this.cellHeight,
    required this.columnCount,
    required this.color,
  });

  final int cellCount;

  final double cellHeight;

  final int columnCount;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var row = 0; row <= cellCount; row++) {
      final y = row == cellCount ? size.height : row * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    if (columnCount > 0) {
      final columnWidth = size.width / columnCount;
      for (var column = 0; column <= columnCount; column++) {
        final x = column == columnCount ? size.width : column * columnWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CalendarGridPainter oldDelegate) {
    return oldDelegate.cellCount != cellCount ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.columnCount != columnCount ||
        oldDelegate.color != color;
  }
}
