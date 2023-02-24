import 'dart:convert';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:win32/win32.dart';

class AppUtil {
  static Future<String> runPowerShellScript(
      String scriptPath, List<String> argumentsToScript) async {
    var process = await Process.start(
        'Powershell.exe', [...argumentsToScript, '-File', scriptPath]);
    String finalString = '';

    await for (var line in process.stdout.transform(utf8.decoder)) {
      finalString += line;
    }
    return finalString;
  }

  ///Plays a wav file with given [path].
  static void playSound(String path) {
    final fileBool = File(path).existsSync();

    if (!fileBool) {
    } else {
      final soundFile = TEXT(path);
      PlaySound(soundFile, NULL, SND_FILENAME | SND_SYNC);
      free(soundFile);
    }
  }

  static Future<FlutterTts> setupTTS() async {
    final flutterTts = FlutterTts();
    await flutterTts.awaitSpeakCompletion(true);

    await flutterTts.setSpeechRate(0.55);
    await flutterTts.setVolume(0.5);
    await flutterTts.setPitch(0.9);

    return flutterTts;
  }
}
