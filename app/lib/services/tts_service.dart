import 'package:flutter_tts/flutter_tts.dart';

/// Pronunciation with the device's text-to-speech engine (en-US).
class TtsService {
  TtsService._();
  static final _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> speak(String text) async {
    if (!_ready) {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    }
    await _tts.stop();
    await _tts.speak(text);
  }
}
