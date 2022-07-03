import 'dart:convert';
import 'dart:io';

import 'package:blinking_text/blinking_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:settings_ui/settings_ui.dart';
import 'package:wtnews/main.dart';

import '../services/data_class.dart';
import 'downloader.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends ConsumerState<Settings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(provider.startupEnabled.notifier).state =
          prefs.getBool('startup') ?? false;
      ref.read(provider.minimizeOnStart.notifier).state =
          prefs.getBool('minimize') ?? false;

      ref.read(provider.playSound.notifier).state =
          prefs.getBool('playSound') ?? false;
      ref.read(provider.additionalNotif.notifier).state =
          prefs.getBool('additionalNotif') ?? false;
      ref.read(provider.customFeed.notifier).state =
          prefs.getString('customFeed');
      ref.read(provider.checkDataMine.notifier).state =
          prefs.getBool('checkDataMine') ?? false;
    });
  }

  Widget settings(BuildContext context) {
    final theme = FluentTheme.of(context);
    final firebaseVersion = ref.watch(provider.versionFBProvider);
    return SettingsList(
        platform: DevicePlatform.web,
        brightness: theme.brightness,
        darkTheme: SettingsThemeData(
            settingsListBackground: Colors.transparent,
            settingsSectionBackground: Colors.transparent,
            tileHighlightColor: theme.accentColor.resolve(context)),
        lightTheme: SettingsThemeData(
            settingsListBackground: Colors.transparent,
            settingsSectionBackground: Colors.transparent,
            tileHighlightColor: theme.accentColor.resolve(context)),
        sections: [
          SettingsSection(
            title: const Text('Main'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.startupEnabled),
                onToggle: (value) async {
                  if (value) {
                    final process = await Process.start(pathToEcho, []);
                    String output = '';
                    await for (final line
                        in process.stdout.transform(utf8.decoder)) {
                      output += line.replaceAll('\n', '').trim();
                    }
                    final file = File(pathToShortcut);
                    final directory = Directory(
                        '${output.replaceAll('"', '')}\\WTNewsShortcut.bat');
                    await file.copy(directory.path);
                  } else {
                    Process.run(pathToRemoveShortcut, []);
                    ref.read(provider.minimizeOnStart.notifier).state = false;
                    prefs.setBool('minimize', false);
                  }
                  ref.read(provider.startupEnabled.notifier).state = value;
                  prefs.setBool('startup', value);
                },
                title: const Text('Run at Startup'),
                leading: Icon(FluentIcons.app_icon_default,
                    color: theme.accentColor),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.minimizeOnStart),
                onToggle: (value) async {
                  ref.read(provider.minimizeOnStart.notifier).state = value;
                  await prefs.setBool('minimize', value);
                },
                title: const Text('Minimize on Startup'),
                leading: Icon(FluentIcons.settings, color: theme.accentColor),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.playSound),
                onToggle: (value) {
                  ref.read(provider.playSound.notifier).state = value;
                  prefs.setBool('playSound', value);
                },
                title: const Text('Play Sound'),
                leading: Icon(
                    ref.watch(provider.playSound)
                        ? FluentIcons.volume3
                        : FluentIcons.volume_disabled,
                    color: theme.accentColor),
              ),
              firebaseVersion.when(data: (data) {
                int fbVersion = int.parse(data.replaceAll('.', ''));
                int currentVersion = int.parse(
                    File(pathToVersion).readAsStringSync().replaceAll('.', ''));
                final bool updateAvailable = fbVersion > currentVersion;
                if (updateAvailable) {
                  return SettingsTile(
                    description: Text('v$data available'),
                    title: BlinkText(
                      'Download & Install Update',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                    leading: Icon(FluentIcons.update_restore,
                        color: theme.accentColor),
                    onPressed: (ctx) {
                      Navigator.pushReplacement(
                          context,
                          FluentPageRoute(
                              builder: (context) => const Downloader()));
                    },
                  );
                } else {
                  return SettingsTile(
                    description: const Text('There is no update available'),
                    title: const Text(
                      'Download & Install Update',
                      style: TextStyle(decoration: TextDecoration.lineThrough),
                    ),
                    leading: Icon(FluentIcons.update_restore,
                        color: theme.accentColor),
                    onPressed: (ctx) {
                      showDialog(
                          context: ctx,
                          builder: (ctx) => ContentDialog(
                                title: const Text('Update'),
                                content: const Text(
                                    'There is no update available at this time.'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('OK'),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ));
                    },
                  );
                }
              }, error: (e, st) {
                return SettingsTile(
                  description: const Text('Error fetching version'),
                  title: const Text(
                    'Download & Install Update',
                    style: TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  leading: Icon(FluentIcons.update_restore,
                      color: theme.accentColor),
                  onPressed: (ctx) {
                    showDialog(
                        context: ctx,
                        builder: (ctx) => ContentDialog(
                              title: const Text('Update'),
                              content: const Text(
                                  'Error fetching version. Please try again later.'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ));
                  },
                );
              }, loading: () {
                return SettingsTile(
                  description: const Text('Fetching version...'),
                  title: const Text(
                    'Download & Install Update',
                    style: TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  leading: Icon(FluentIcons.update_restore,
                      color: theme.accentColor),
                  onPressed: (ctx) {
                    showDialog(
                        context: ctx,
                        builder: (ctx) => ContentDialog(
                              title: const Text('Update'),
                              content: const Text('Fetching version...'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ));
                  },
                );
              }),
            ],
          ),
          SettingsSection(
            title: const Text('Additional'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.checkDataMine),
                onToggle: (value) async {
                  prefs.setBool('checkDataMine', value);
                  ref.read(provider.checkDataMine.notifier).state = value;
                },
                title: const Text('DataMine Notifier'),
                leading: Image.asset(
                  'assets/gszabi.jpg',
                  width: 30,
                  height: 30,
                ),
                trailing: Icon(FluentIcons.info, color: theme.accentColor),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.additionalNotif),
                onToggle: (value) {
                  ref.read(provider.additionalNotif.notifier).state = value;
                  prefs.setBool('additionalNotif', value);
                },
                title: const Text('Tray and Greeting Notifications'),
              ),
            ],
          ),
          SettingsSection(title: const Text('Misc'), tiles: [
            SettingsTile(
              description: const Text('Used to contact the client'),
              title: const Text('Set Username'),
              leading: Icon(FluentIcons.account_management,
                  color: theme.accentColor),
              onPressed: (ctx) async {
                Message.getUserName(context, null, ref);
              },
            ),
          ]),
        ]);
  }

  String pathToRemoveShortcut =
      '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/removeShortcut.bat';

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Flex(
        direction: Axis.vertical,
        children: [
          Text(
            'Current Version: ${File(pathToVersion).readAsStringSync()}',
            style: TextStyle(
              fontSize: 19,
              color: Colors.red,
            ),
          ),
          ref.watch(provider.versionProvider) != null &&
                  int.parse(ref
                          .watch(provider.versionProvider)!
                          .replaceAll('.', '')) >
                      int.parse(File(pathToVersion)
                          .readAsStringSync()
                          .replaceAll('.', ''))
              ? BlinkText(
                  'Latest version: ${ref.watch(provider.versionProvider)}',
                  style: TextStyle(
                    fontSize: 19,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  duration: const Duration(seconds: 2),
                )
              : const SizedBox(),
          Expanded(child: settings(context)),
        ],
      ),
    );
  }
}
