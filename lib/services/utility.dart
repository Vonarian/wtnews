import 'dart:developer';
import 'dart:io';

class AppUtil {
  static Future<String> createFolderInAppDocDir(String path) async {
    //Get this App Document Directory

    //App Document Directory + folder name
    final Directory _appDocDirFolder = Directory(path);

    try {
      if (await _appDocDirFolder.exists()) {
        //if folder already exists return path
        return _appDocDirFolder.path;
      } else {
        //if folder not exists create folder and then return its path
        final Directory _appDocDirNewFolder =
            await _appDocDirFolder.create(recursive: true);
        return _appDocDirNewFolder.path;
      }
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }
}
