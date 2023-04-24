import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/github.dart';
import '../main.dart' as m;
import 'data.dart' as d;

class VonAssistant {
  static final Dio _dio = Dio()
    ..options.headers['Authorization'] = 'Token ${d.token}'
    ..options.headers['User-Agent'] = 'VonAssistant';

  static String path = '${m.appDocPath}\\VonAssistant\\vonassistant.exe';
  final String filePath;
  final bool installed;

  const VonAssistant(this.installed, this.filePath);

  static Future<VonAssistant> initialize(String? docPath) async {
    final filePath = '$docPath\\VonAssistant\\vonassistant.exe';
    if (!await File(path).exists()) {
      await download();
      return VonAssistant(await File(path).exists(), filePath);
    } else {
      if (await needUpdate()) {
        await Process.run('taskkill', ['/F', '/IM', 'vonassistant.exe']);
        await download();
      }
      return VonAssistant(await File(path).exists(), filePath);
    }
  }

  static Future<void> download() async {
    try {
      GHData data = await getData();
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      Directory tempWTNewsPath =
          await Directory('$tempPath\\WTNews').create(recursive: true);
      final deleteFolder = Directory(p.joinAll([tempWTNewsPath.path, 'out']));
      if (await deleteFolder.exists()) {
        await deleteFolder.delete(recursive: true);
      }
      final String downloadPath =
          'https://api.github.com/repos/Vonarian/vonassistant/releases/assets/${data.assets.last.id}';
      _dio.options.headers['Accept'] = 'application/octet-stream';
      await _dio
          .download(downloadPath, '${tempWTNewsPath.path}\\vonassistant.zip')
          .timeout(const Duration(minutes: 4));

      final File filePath = File('${tempWTNewsPath.path}\\vonassistant.zip');
      final Uint8List bytes = await filePath.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${p.dirname(filePath.path)}\\out\\$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('${p.dirname(filePath.path)}\\out\\$filename')
              .create(recursive: true);
        }
      }
      final exeFile =
          File('${p.dirname(filePath.path)}\\out\\vonassistant.exe');
      if (!await Directory(p.dirname(path)).exists()) {
        await Directory(p.dirname(path)).create(recursive: true);
      }
      await exeFile.copy(path);
    } catch (e, st) {
      log(e.toString(), stackTrace: st);
    }
  }

  static Future<GHData> getData() async {
    _dio.options.headers['Accept'] = 'application/json';
    Response response = await _dio.get(
      'https://api.github.com/repos/Vonarian/vonassistant/releases/latest',
    );
    GHData data = GHData.fromJson(response.data);
    return data;
  }

  Future<void> installAppUpdate(String msixDir) async {
    await Process.run(filePath, ['-u', '-p', msixDir, '-n', 'wtnews'],
        runInShell: true, workingDirectory: msixDir);
  }

  ///Returns true if the GH version is newer than the current version.
  static Future<bool> needUpdate() async {
    final ghVersion = int.parse((await getData()).tagName.replaceAll('.', ''));
    final process = await Process.start(path, ['--version']);
    String versionStr = '';
    await for (final event in process.stdout.transform(utf8.decoder)) {
      if (event.contains('.')) versionStr = event;
    }
    final version = int.parse(versionStr.replaceAll('.', ''));
    if (ghVersion > version) return true;
    return false;
  }

  Future<void> setStartup(bool value) async {
    if (!installed) {
      log('VonAssistant is not installed at $filePath!, cancelling operation!');
      return;
    }
    await Process.run(filePath, ['-s', '$value', '-n', 'wtnews']);
  }

  ///WARNING: THIS DOES NOT CHECK IF VONASSISTANT IS INSTALLED OR NOT.
  static Future<bool> checkStartup() async {
    final process = await Process.start(path, ['-e', '-n', 'wtnews']);
    String result = '';
    await for (var res in process.stdout.transform(utf8.decoder)) {
      result += res;
    }
    if (result.contains('true')) return true;
    return false;
  }
}
