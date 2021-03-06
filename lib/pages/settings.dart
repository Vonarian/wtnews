import 'dart:convert';
import 'dart:io';

import 'package:blinking_text/blinking_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wtnews/main.dart';

import '../services/data/data_class.dart';
import 'downloader.dart';

class Settings extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const Settings(this.prefs, {Key? key}) : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends ConsumerState<Settings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(provider.startupEnabled.notifier).state =
          widget.prefs.getBool('startup') ?? false;
      ref.read(provider.minimizeOnStart.notifier).state =
          widget.prefs.getBool('minimize') ?? false;

      ref.read(provider.playSound.notifier).state =
          widget.prefs.getBool('playSound') ?? false;
      ref.read(provider.customFeed.notifier).state =
          widget.prefs.getString('customFeed');
      ref.read(provider.checkDataMine.notifier).state =
          widget.prefs.getBool('checkDataMine') ?? false;
    });
  }

  Widget settings(BuildContext context) {
    final theme = FluentTheme.of(context);
    final firebaseVersion = ref.watch(provider.versionFBProvider);
    return SettingsList(
        platform: DevicePlatform.web,
        contentPadding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
        brightness: theme.brightness,
        darkTheme: SettingsThemeData(
          settingsListBackground: Colors.transparent,
          settingsSectionBackground: Colors.transparent,
          tileHighlightColor: theme.accentColor.resolve(context),
        ),
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
                    widget.prefs.setBool('minimize', false);
                  }
                  ref.read(provider.startupEnabled.notifier).state = value;
                  widget.prefs.setBool('startup', value);
                },
                title: const Text('Run at Startup'),
                leading: Icon(FluentIcons.app_icon_default,
                    color: theme.accentColor),
                activeSwitchColor: theme.accentColor.lightest,
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.minimizeOnStart),
                onToggle: (value) async {
                  ref.read(provider.minimizeOnStart.notifier).state = value;
                  await widget.prefs.setBool('minimize', value);
                },
                title: const Text('Minimize on Startup'),
                leading: Icon(FluentIcons.settings, color: theme.accentColor),
                activeSwitchColor: theme.accentColor.lightest,
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(provider.playSound),
                onToggle: (value) {
                  ref.read(provider.playSound.notifier).state = value;
                  widget.prefs.setBool('playSound', value);
                },
                title: const Text('Play Sound'),
                leading: Icon(
                    ref.watch(provider.playSound)
                        ? FluentIcons.volume3
                        : FluentIcons.volume_disabled,
                    color: theme.accentColor),
                activeSwitchColor: theme.accentColor.lightest,
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
                  widget.prefs.setBool('checkDataMine', value);
                  ref.read(provider.checkDataMine.notifier).state = value;
                },
                title: const Text('DataMine Notifier'),
                leading: Image.asset(
                  'assets/gszabi.jpg',
                  width: 30,
                  height: 30,
                ),
                description: const Text(
                    'WTNews Checks for updates of data mines and notifies you when a new one is available.'),
                activeSwitchColor: theme.accentColor.lightest,
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
      padding: EdgeInsets.zero,
      content: settings(context),
    );
  }
}
