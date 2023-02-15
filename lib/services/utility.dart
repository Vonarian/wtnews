import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

class AppUtil {
  ///Will create the folder if missing and return its path.
  static Future<String> createFolderInAppDocDir(String path) async {
    //Get this App Document Directory

    //App Document Directory + folder name
    final Directory appDocDirFolder = Directory(path);

    try {
      if (await appDocDirFolder.exists()) {
        //if folder already exists return path
        return appDocDirFolder.path;
      } else {
        //if folder not exists create folder and then return its path
        final Directory finalDir =
            await appDocDirFolder.create(recursive: true);
        return finalDir.path;
      }
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }

  ///Will save error and stack trace to a text file with given [e], [stackTrace] and [location].
  static Future<void> logAndSaveToText(
      String filePath, String e, String stackTrace, String location) async {
    await createFolderInAppDocDir(p.dirname(filePath));
    final File file = File(filePath);
    if (await file.exists()) {
      if (await file.length() / 1000000 >= 10) {
        await file.delete();
      }
      String previousString = await file.readAsString();
      String logString = '$previousString'
          '\n Location:$location'
          '\n Error: $e'
          '\n StackTrace: $stackTrace';
      await file.writeAsString(logString);
    } else {
      String logString = 'Location:$location'
          '\n Error: $e'
          '\n StackTrace: $stackTrace';
      await file.writeAsString(logString);
    }
  }

  static String packAndAccessLog(String path) {
    var encoder = ZipFileEncoder();
    encoder.zipDirectory(Directory(path), filename: 'log.zip');
    return '$path\\log.zip';
  }

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
}
