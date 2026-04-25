import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundFeedbackService {
  static final AudioPlayer _player = AudioPlayer();

  Future<void> playSuccessSound() async {
    final audioData = await rootBundle.load('lib/assets/sounds/ss.mp3');
    final bytes = audioData.buffer.asUint8List();

    await _player.stop();
    await _player.play(BytesSource(bytes), volume: 1.0);
  }

  Future<void> playErrorSound() async {
    final audioData = await rootBundle.load('lib/assets/sounds/as.mp3');
    final bytes = audioData.buffer.asUint8List();

    await _player.stop();
    await _player.play(BytesSource(bytes), volume: 1.0);
  }
}
