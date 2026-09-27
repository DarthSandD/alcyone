// Generates the Alcyone launcher icon.
//
// BRAND DNA: the icon reworks Darren's existing "Omni Eyes View" mark (an eye
// wrapped around a globe, cyan #00F6FF on blue) into an agent-orchestration
// mark: a six-blade aperture that reads simultaneously as an eye, a camera
// shutter, and a fan-out of agents around a central orchestrator.
//
// LEGIBILITY RULES (an app icon is judged at 48px on a home screen):
//   - Bold silhouette only. No hairlines - anything under ~10px dies at 48px.
//   - High-contrast dark base so the mark pops on any wallpaper.
//   - The pupil and the three agent nodes are solid filled circles; they are
//     the only elements that must survive at the smallest size.
//
// Run with: flutter test test/make_icon_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color kCyan = Color(0xFF00F6FF);
const Color kViolet = Color(0xFF7C3AED);
const Color kBase0 = Color(0xFF05070D);
const Color kBase1 = Color(0xFF0E1428);

void main() {
  test('generate Alcyone launcher icon', () async {
    const size = 1024.0;
    const c = Offset(size / 2, size / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size, size);

    // ---------- base: deep diagonal gradient ----------
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBase1, kBase0],
        ).createShader(rect),
    );

    // radial bloom behind the mark for depth
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          size * 0.60,
          [
            kViolet.withValues(alpha: 0.34),
            kCyan.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          [0.0, 0.45, 1.0],
        ),
    );

    // A Paint's shader is single-use in a recorded canvas, so every draw that
    // needs the mark gradient gets its own Paint.
    Paint markPaint() => Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kCyan, kViolet],
      ).createShader(rect);

    // ---------- aperture ring (bold stroke) ----------
    const ringR = size * 0.255;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.046
        ..shader = markPaint().shader,
    );

    // ---------- six iris blades ----------
    // Thick chords across the ring, rotated in 60deg steps. This is what makes
    // the mark read as an eye AND a camera aperture at the same time.
    final blade = Path();
    const bladeR = size * 0.163;
    const inset = size * 0.017;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i * math.pi / 3);
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
        ..strokeWidth = size * 0.040
        ..strokeCap = StrokeCap.round
        ..shader = markPaint().shader,
    );

    // ---------- central pupil (the orchestrator) ----------
    canvas.drawCircle(c, size * 0.072, Paint()..color = kCyan);
    canvas.drawCircle(
      c,
      size * 0.115,
      Paint()..color = kCyan.withValues(alpha: 0.22),
    );

    // ---------- three orbiting agent nodes ----------
    // Solid filled circles on an implied orbit: they carry the "agents on a
    // board" idea and stay legible at 48px. No connecting ring is drawn - at
    // icon size it would collapse into a sub-pixel smudge.
    const orbitR = size * 0.375;
    const nodeR = size * 0.052;
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 3 + (i * 2 * math.pi / 3);
      final p = Offset(
        c.dx + orbitR * math.cos(a),
        c.dy + orbitR * math.sin(a),
      );
      canvas.drawCircle(
        p,
        nodeR * 1.55,
        Paint()..color = kViolet.withValues(alpha: 0.28),
      );
      canvas.drawCircle(p, nodeR, Paint()..shader = markPaint().shader);
    }

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('assets/icon/alcyone_icon.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'ICON WRITTEN: ${out.path} (${out.lengthSync()} bytes, '
      '${size.toInt()}x${size.toInt()})',
    );
  });
}
