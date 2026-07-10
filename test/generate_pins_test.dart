import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate custom map pins', () async {
    // Ensure icons directory exists
    final dir = Directory('assets/icons');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Generate Pickup Pin
    final pickupBytes = await generatePickupPin();
    await File('assets/icons/pickup_pin.png').writeAsBytes(pickupBytes);
    print('✅ Generated pickup_pin.png');

    // Generate Destination Pin
    final destBytes = await generateDestinationPin();
    await File('assets/icons/destination_pin.png').writeAsBytes(destBytes);
    print('✅ Generated destination_pin.png');

    // Generate Car Pin
    final carBytes = await generateCarPin();
    await File('assets/icons/car_pin.png').writeAsBytes(carBytes);
    print('✅ Generated car_pin.png');
  });
}

Future<List<int>> generatePickupPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 128, 128));
  
  // Paint shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  
  final pinPath = Path();
  pinPath.moveTo(64, 115);
  pinPath.cubicTo(24, 75, 20, 60, 20, 48);
  pinPath.arcToPoint(const Offset(108, 48), radius: const Radius.circular(44));
  pinPath.cubicTo(108, 60, 104, 75, 64, 115);
  pinPath.close();
  
  // Draw shadow
  canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);
  
  // Fill gradient (Purple brand colors)
  final fillPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(20, 20),
      const Offset(108, 108),
      [const Color(0xFF9B95FF), const Color(0xFF6C63FF)],
    );
  canvas.drawPath(pinPath, fillPaint);
  
  // Stroke border (White)
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.5
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(pinPath, borderPaint);
  
  // Inner white circle
  final innerCirclePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(64, 48), 12, innerCirclePaint);
  
  final picture = recorder.endRecording();
  final img = await picture.toImage(128, 128);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}

Future<List<int>> generateDestinationPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 128, 128));
  
  // Paint shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  
  final pinPath = Path();
  pinPath.moveTo(64, 115);
  pinPath.cubicTo(24, 75, 20, 60, 20, 48);
  pinPath.arcToPoint(const Offset(108, 48), radius: const Radius.circular(44));
  pinPath.cubicTo(108, 60, 104, 75, 64, 115);
  pinPath.close();
  
  // Draw shadow
  canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);
  
  // Fill gradient (Red / Accent error colors)
  final fillPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(20, 20),
      const Offset(108, 108),
      [const Color(0xFFFF8A8A), const Color(0xFFFF5252)],
    );
  canvas.drawPath(pinPath, fillPaint);
  
  // Stroke border (White)
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.5
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(pinPath, borderPaint);
  
  // Inner white rounded square
  final innerSquarePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(64, 48), width: 22, height: 22),
      const Radius.circular(4),
    ),
    innerSquarePaint,
  );
  
  final picture = recorder.endRecording();
  final img = await picture.toImage(128, 128);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}

Future<List<int>> generateCarPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 128, 128));
  
  // Paint shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  canvas.drawCircle(const Offset(64, 64 + 4), 46, shadowPaint);
  
  // Fill background circle (dark indigo surface)
  final bgPaint = Paint()
    ..color = const Color(0xFF13131F)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(64, 64), 46, bgPaint);
  
  // Stroke border
  final borderPaint = Paint()
    ..color = const Color(0xFF6C63FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.5;
  canvas.drawCircle(const Offset(64, 64), 46, borderPaint);
  
  // Draw car
  // Car body (rounded rect)
  final carBodyPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(64, 64), width: 28, height: 50),
      const Radius.circular(8),
    ),
    carBodyPaint,
  );
  
  // Car windshield (glass / dark)
  final glassPaint = Paint()
    ..color = const Color(0xFF1A1A2E)
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(64, 52), width: 22, height: 10),
      const Radius.circular(2),
    ),
    glassPaint,
  );
  
  // Car rear window
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(64, 78), width: 22, height: 7),
      const Radius.circular(2),
    ),
    glassPaint,
  );
  
  // Headlights (yellow)
  final lightPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(54, 42), 3, lightPaint);
  canvas.drawCircle(const Offset(74, 42), 3, lightPaint);
  
  // Taillights (red)
  final tailLightPaint = Paint()
    ..color = const Color(0xFFFF5252)
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(51, 85, 4, 2),
      const Radius.circular(1),
    ),
    tailLightPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(73, 85, 4, 2),
      const Radius.circular(1),
    ),
    tailLightPaint,
  );
  
  final picture = recorder.endRecording();
  final img = await picture.toImage(128, 128);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}
