// Generates the Android ADAPTIVE ICON foreground for Alcyone.
//
// Adaptive icons are cropped to a circle/squircle mask and the outer ~18% of
// each edge can be cut, so the mark must sit inside a centred safe zone with
// generous padding. The foreground layer is transparent: the background colour
// comes from `adaptive_icon_background` in pubspec.yaml.
//
// Run with: flutter test test/make_icon_foreground_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color kCyan = Color(0xFF00F6FF);
const Color kViolet = Color(0xFF7C3AED);

void main() {
  test('generate Alcyone adaptive-icon foreground', () async {
    const size = 1024.0;
    const c = Offset(size / 2, size / 2);
    // Android's guaranteed-visible safe zone is a centred 66% circle.
    const safe = size * 0.30;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size, size);

    // Transparent base - the system supplies the background colour.
    canvas.drawRect(rect, Paint()..color = const Color(0x00000000));

    Paint markPaint() => Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kCyan, kViolet],
      ).createShader(rect);

    // Everything below is scaled to the safe zone relative to the 1024 master.
    const s = safe / (size * 0.46); // master draw extent was 0.46 * size

    double r(double v) => v * size * s;

    // aperture ring
    canvas.drawCircle(
      c,
      r(0.255),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r(0.046)
        ..shader = markPaint().shader,
    );

    // six iris blades
    final blade = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i * math.pi / 3);
      final bladeR = r(0.163);
      final inset = r(0.017);
      final p1 = Offset(
        c.dx + (bladeR + inset) * math.cos(a - 0.62),
        c.dy + (bladeR + inset) * math.sin(a - 0.62),
      );
      final p2 = Offset(
        c.dx + (bladeR + inset) * math.cos(a + 0.62),
        c.dy + (bladeR + inset) * math.sin(a + 0.62),
      );
      blade
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(
          c.dx + bladeR * 0.30 * math.cos(a),
          c.dy + bladeR * 0.30 * math.sin(a),
          p2.dx,
          p2.dy,
        );
    }
    canvas.drawPath(
      blade,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r(0.040)
        ..strokeCap = StrokeCap.round
        ..shader = markPaint().shader,
    );

    // pupil + halo
    canvas.drawCircle(c, r(0.115), Paint()..color = kCyan.withValues(alpha: 0.22));
    canvas.drawCircle(c, r(0.072), Paint()..color = kCyan);

    // three orbiting agent nodes
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 3 + (i * 2 * math.pi / 3);
      final p = Offset(
        c.dx + r(0.375) * math.cos(a),
        c.dy + r(0.375) * math.sin(a),
      );
      canvas.drawCircle(
        p,
        r(0.052) * 1.55,
        Paint()..color = kViolet.withValues(alpha: 0.28),
      );
      canvas.drawCircle(p, r(0.052), Paint()..shader = markPaint().shader);
    }

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('assets/icon/alcyone_icon_foreground.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('ADAPTIVE FOREGROUND WRITTEN: ${out.path} (${out.lengthSync()} bytes)');
  });
}
