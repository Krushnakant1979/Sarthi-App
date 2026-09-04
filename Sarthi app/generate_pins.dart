import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Generate pins', (WidgetTester tester) async {
    // Generate Pickup Pin (Blue Dot)
    final pickupImage = await _drawPickupPin();
    final pickupData = await pickupImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File(
      'android/app/src/main/res/drawable/ic_pickup_pin.png',
    ).writeAsBytesSync(pickupData!.buffer.asUint8List());

    // Generate Dest Pin (Red Flag)
    final destImage = await _drawDestPin();
    final destData = await destImage.toByteData(format: ui.ImageByteFormat.png);
    File(
      'android/app/src/main/res/drawable/ic_dest_pin.png',
    ).writeAsBytesSync(destData!.buffer.asUint8List());

    // print('Pins generated successfully!');
  });
}

Future<ui.Image> _drawPickupPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final width = 60.0;
  final height = 60.0;

  final whitePaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  final bluePaint = ui.Paint()..color = const ui.Color(0xFF2563EB);

  canvas.drawCircle(ui.Offset(width / 2, height / 2), 26, whitePaint);
  canvas.drawCircle(ui.Offset(width / 2, height / 2), 20, bluePaint);
  canvas.drawCircle(ui.Offset(width / 2, height / 2), 8, whitePaint);

  final picture = recorder.endRecording();
  return await picture.toImage(width.toInt(), height.toInt());
}

Future<ui.Image> _drawDestPin() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final width = 72.0;
  final height = 90.0;

  final polePaint = ui.Paint()..color = const ui.Color(0xFF374151);
  final redPaint = ui.Paint()..color = const ui.Color(0xFFEA4335);

  canvas.drawRect(
    ui.Rect.fromLTRB(width / 2 - 3, 10, width / 2 + 3, height - 5),
    polePaint,
  );

  final path = ui.Path();
  path.moveTo(width / 2 + 3, 10);
  path.lineTo(width - 5, 28);
  path.lineTo(width / 2 + 3, 46);
  path.close();
  canvas.drawPath(path, redPaint);

  final picture = recorder.endRecording();
  return await picture.toImage(width.toInt(), height.toInt());
}
