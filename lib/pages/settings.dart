import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:wtnews/main.dart';
import 'package:wtnews/pages/custom_feed.dart';
import 'package:wtnews/widgets/feedback.dart' as fb;
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
      ref.read(isStartupEnabled.notifier).state =
          prefs.getBool('startup') ?? false;
      if (ref.read(isStartupEnabled.notifier).state) {
        await Process.run(pathToUpdateShortcut, []);
      }
      ref.read(playSound.notifier).state = prefs.getBool('playSound') ?? false;
      ref.read(customFeed.notifier).state = prefs.getString('customFeed');
    });
  }

  static Route<String> dialogBuilderUrl(BuildContext context, String url) {
    TextEditingController userInputOverG = TextEditingController(text: url);
    return DialogRoute(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: TextField(
                onChanged: (value) {},
                controller: userInputOverG,
                decoration: const InputDecoration(
                    hintText:
                        'https://forum.warthunder.com/index.php?/discover/*NUMBER HERE*.xml/'),
              ),
              title: const Text('Set custom url for feed'),
              actions: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content:
                                Text('Custom set: ${userInputOverG.text}. ')));
                      Navigator.of(context).pop(userInputOverG.text);
                    },
                    child: const Text('Notify'))
              ],
            ));
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
                        ref.read(minimizeOnStart.notifier).state =
                            !ref.read(minimizeOnStart.notifier).state;
                        await prefs.setBool(
                            'minimize', ref.watch(minimizeOnStart));
                      },
                      icon: const Icon(
                        Icons.settings,
                        size: 40,
                      ),
                      label: Text(
                        'Minimize on startup: ${ref.watch(minimizeOnStart) ? 'On' : 'Off'}',
                        style: const TextStyle(fontSize: 40),
                      )),
                  TextButton.icon(
                      onPressed: () async {
                        ref.read(playSound.notifier).state =
                            !ref.read(playSound.notifier).state;
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
                  TextButton.icon(
                      onPressed: () async {
                        ref.read(customFeed.notifier).state =
                            (await Navigator.of(context).push(dialogBuilderUrl(
                                context, ref.watch(customFeed) ?? '')))!;
                        await prefs.setString(
                            'customFeed', ref.watch(customFeed) ?? '');
                      },
                      icon: const Icon(
                        Icons.save,
                        size: 40,
                      ),
                      label: const Text(
                        'Set custom feed url',
                        style: TextStyle(
                            fontSize: 40, color: Colors.deepPurpleAccent),
                      )),
                  TextButton.icon(
                      onPressed: () async {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const CustomRSSView()));
                      },
                      icon: const Icon(
                        Icons.save,
                        size: 40,
                      ),
                      label: const Text(
                        'Switch to custom feed screen',
                        style: TextStyle(
                            fontSize: 40, color: Colors.deepPurpleAccent),
                      )),
                  const fb.Feedback(text: 'Set Username', onlyUserName: true),
                  const fb.Feedback(
                      text: 'Send Feedback ❤', onlyUserName: false),
                ],
              ),
            ),
          ),
          const WindowTitleBar(isCustom: true),
        ],
      ),
    );
  }
}
