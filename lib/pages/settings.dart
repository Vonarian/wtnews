import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/widgets/titlebar.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      ref.read(isStartupEnabled.notifier).state =
          prefs.getBool('startup') ?? false;
      if (ref.read(isStartupEnabled.notifier).state) {
        await Process.run(pathToUpdateShortcut, []);
      }
      ref.read(playSound.notifier).state = prefs.getBool('playSound') ?? false;
    });
  }

  String pathToAddShortcut =
      '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/addShortcut.bat';
  String pathToRemoveShortcut =
      '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/removeShortcut.bat';
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          ImageFiltered(
              child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.black,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black,
                    Colors.black,
                    Colors.black,
                  ],
                )),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0)),
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            backgroundColor: Colors.transparent,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                      onPressed: () async {
                        if (!ref.watch(isStartupEnabled)) {
                          await Process.run(pathToAddShortcut, []);
                        } else {
                          await Process.run(pathToRemoveShortcut, []);
                        }
                        ref.read(isStartupEnabled.notifier).state =
                            !ref.read(isStartupEnabled.notifier).state;
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool(
                            'startup', ref.watch(isStartupEnabled));
                      },
                      icon: const Icon(
                        Icons.settings,
                        size: 40,
                      ),
                      label: Text(
                        'Start at startup: ${ref.watch(isStartupEnabled) ? 'On' : 'Off'}',
                        style: const TextStyle(fontSize: 40),
                      )),
                  TextButton.icon(
                      onPressed: () async {
                        ref.read(playSound.notifier).state =
                            !ref.read(playSound.notifier).state;
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('playSound', ref.watch(playSound));
                      },
                      icon: const Icon(
                        Icons.settings,
                        size: 40,
                      ),
                      label: Text(
                        'Play sound: ${ref.watch(playSound) ? 'On' : 'Off'}',
                        style: const TextStyle(fontSize: 40),
                      )),
                ],
              ),
            ),
          ),
          const WindowTitleBar(),
        ],
      ),
    );
  }
}
