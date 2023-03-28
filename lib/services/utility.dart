import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:system_info2/system_info2.dart';
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

  static Future<void> setEffect(bool disabled) async {
    log('Disabled transparent effects: $disabled');
    if (disabled == true) {
      return;
    }
    if (int.parse(SysInfo.operatingSystemVersion.split('.')[2]) >= 22523) {
      log('Tabbed');
      await Window.setEffect(effect: WindowEffect.tabbed);
    } else if (int.parse(SysInfo.operatingSystemVersion.split('.')[1]) <=
            22523 &&
        int.parse(SysInfo.operatingSystemVersion.split('.')[2]) >= 19042) {
      log('Acrylic');
      await Window.setEffect(effect: WindowEffect.acrylic);
    } else {
      log('Aero');
      await Window.setEffect(
        effect: WindowEffect.aero,
      );
    }
  }
}
