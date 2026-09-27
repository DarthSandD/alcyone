// Generates the Alcyone launcher icon PNG into assets/icon/.
// Run with: flutter test test/make_icon_test.dart
//
// This lives in a test file on purpose: it needs the Flutter-bundled Dart and
// the flutter/painting libraries, which a bare `dart run` cannot resolve.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate Alcyone launcher icon', () async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size, size);

    // Background: diagonal indigo -> violet gradient.
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5865F2), Color(0xFF8B5CF6)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Soft radial highlight for depth.
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size * 0.3, size * 0.26),
        size * 0.62,
        [Colors.white.withValues(alpha: 0.22), Colors.transparent],
      );
    canvas.drawRect(rect, glow);

    // Hub glyph: a central node plus three satellites - the "agents on a
    // board" idea, drawn from scratch (no Multica artwork is reproduced).
    final center = Offset(size / 2, size / 2);
    final orbit = size * 0.27;
    final hubR = size * 0.115;
    final nodeR = size * 0.072;

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = size * 0.028
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sat = <Offset>[];
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 2 + (i * 2 * math.pi / 3);
      sat.add(
        Offset(center.dx + orbit * math.cos(a), center.dy + orbit * math.sin(a)),
      );
    }

    for (final p in sat) {
      canvas.drawLine(center, p, line);
    }
    for (final p in sat) {
      canvas.drawCircle(p, nodeR, Paint()..color = Colors.white);
    }
    canvas.drawCircle(center, hubR, Paint()..color = const Color(0xFF5865F2));
    canvas.drawCircle(
      center,
      hubR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.022,
    );

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('assets/icon/alcyone_icon.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('ICON WRITTEN: ${out.path} (${out.lengthSync()} bytes)');
  });
}
