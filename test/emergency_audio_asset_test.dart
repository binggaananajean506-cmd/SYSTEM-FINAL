import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emergency Flutter and Android audio assets are real MP3 files', () {
    final flutterAsset = File('assets/audio/esugid_emergency_alert.mp3');
    final androidAsset = File(
      'android/app/src/main/res/raw/esugid_emergency_alert.mp3',
    );

    expect(flutterAsset.existsSync(), isTrue);
    expect(androidAsset.existsSync(), isTrue);
    expect(flutterAsset.lengthSync(), greaterThan(1000));
    expect(androidAsset.readAsBytesSync(), flutterAsset.readAsBytesSync());

    final header = flutterAsset.readAsBytesSync().take(3).toList();
    final isId3 = header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33;
    final isMpegFrame = header[0] == 0xFF && (header[1] & 0xE0) == 0xE0;
    expect(isId3 || isMpegFrame, isTrue);
  });
}
