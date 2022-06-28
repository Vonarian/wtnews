import 'dart:developer';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
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
  static Future<void> logAndSaveToText(String filePath, String e,
      String stackTrace, String location) async {
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

  ///Plays a wav file with given [path].
  void playSound(String path) {
    final fileBool = File(path).existsSync();

    if (!fileBool) {
      if (kDebugMode) {
        print('WAV file missing.');
      }
    } else {
      final soundFile = TEXT(path);
      final result = PlaySound(soundFile, NULL, SND_FILENAME | SND_SYNC);

      if (result != TRUE) {
        if (kDebugMode) {
          print('Sound playback failed.');
        }
      }
      free(soundFile);
    }
  }
}
