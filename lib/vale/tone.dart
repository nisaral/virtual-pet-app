import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum ValeSound { tap, good, low, rite }

class ValeTone {
  ValeTone._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(ValeSound sound) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(_wav(sound), mimeType: 'audio/wav'));
    } catch (_) {}
  }

  static Uint8List _wav(ValeSound sound) {
    final notes = switch (sound) {
      ValeSound.tap => [(660.0, 70)],
      ValeSound.good => [(523.0, 90), (659.0, 90), (784.0, 140)],
      ValeSound.low => [(392.0, 90), (330.0, 150)],
      ValeSound.rite => [(523.0, 100), (659.0, 100), (784.0, 100), (1046.0, 220)],
    };
    const rate = 22050;
    final samples = <int>[];
    for (final note in notes) {
      final count = rate * note.$2 ~/ 1000;
      for (var i = 0; i < count; i++) {
        final env = _envelope(i, count);
        final wave = math.sin(2 * math.pi * note.$1 * i / rate);
        samples.add((wave * env * 0.22 * 32767).round().clamp(-32767, 32767));
      }
      for (var i = 0; i < rate ~/ 80; i++) {
        samples.add(0);
      }
    }
    final dataLength = samples.length * 2;
    final header = ByteData(44);
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataLength, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6d);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, rate, Endian.little);
    header.setUint32(28, rate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataLength, Endian.little);
    final bytes = BytesBuilder();
    bytes.add(header.buffer.asUint8List());
    final pcm = ByteData(dataLength);
    for (var i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(pcm.buffer.asUint8List());
    return bytes.toBytes();
  }

  static double _envelope(int index, int count) {
    final attack = (index / (count * 0.08)).clamp(0.0, 1.0);
    final release = ((count - index) / (count * 0.28)).clamp(0.0, 1.0);
    return attack * release;
  }
}
