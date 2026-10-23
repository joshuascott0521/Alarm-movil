import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Dibuja el pin de la parada (círculo de color con un bus) como imagen
/// para usarlo como marcador de Google Maps.
Future<BitmapDescriptor> stopMarkerIcon(Color color, double pixelRatio) async {
  const width = 48.0, height = 58.0, center = Offset(width / 2, 20);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  canvas.drawRect(
    Rect.fromLTWH(width / 2 - 1.5, 36, 3, height - 36),
    Paint()..color = color,
  );
  canvas.drawCircle(
    center.translate(0, 1.5),
    20,
    Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawCircle(center, 20, Paint()..color = Colors.white);
  canvas.drawCircle(center, 17, Paint()..color = color);

  const icon = Icons.directions_bus;
  final glyph = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 22,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
  )..layout();
  glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));

  final image = await recorder.endRecording().toImage(
        (width * pixelRatio).round(),
        (height * pixelRatio).round(),
      );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    png!.buffer.asUint8List(),
    width: width,
    height: height,
  );
}
