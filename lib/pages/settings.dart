import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/pages/custom_feed.dart';
import 'package:wtnews/services/presence.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../providers.dart';
import '../services/data_class.dart';
import '../widgets/settings_list_custom.dart';
import 'overlay.dart';

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
      ref.read(startupEnabled.notifier).state =
          prefs.getBool('startup') ?? false;
      if (ref.read(startupEnabled.notifier).state) {
        await Process.run(pathToUpdateShortcut, []);
      }

      ref.read(playSound.notifier).state = prefs.getBool('playSound') ?? false;
      ref.read(additionalNotif.notifier).state =
          prefs.getBool('additionalNotif') ?? false;
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
                      Navigator.of(context).pop(url);
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

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Widget settings(BuildContext context) {
    return CustomizedSettingsList(
        platform: DevicePlatform.web,
        brightness: Brightness.dark,
        darkTheme: const SettingsThemeData(
          settingsListBackground: Colors.transparent,
          settingsSectionBackground: Colors.transparent,
        ),
        sections: [
          SettingsSection(
            title: const Text('Main'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: ref.watch(startupEnabled),
                onToggle: (value) {
                  if (value) {
                    Process.run(pathToUpdateShortcut, []);
                  } else {
                    Process.run(pathToRemoveShortcut, []);
                    ref.read(minimizeOnStart.notifier).state = false;
                    prefs.setBool('minimize', false);
                  }
                  ref.read(startupEnabled.notifier).state = value;
                  prefs.setBool('startup', value);
                },
                title: const Text('Run at Startup'),
                leading: const Icon(Icons.launch),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(minimizeOnStart),
                onToggle: (value) {
                  ref.read(minimizeOnStart.notifier).state = value;
                  prefs.setBool('minimize', value);
                },
                title: const Text('Minimize on Startup'),
                leading: const Icon(Icons.settings),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(playSound),
                onToggle: (value) {
                  ref.read(playSound.notifier).state = value;
                  prefs.setBool('playSound', value);
                },
                title: const Text('Play Sound'),
                leading: Icon(ref.watch(playSound)
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_rounded),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Additional'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: ref.watch(checkDataMine),
                onToggle: (value) async {
                  prefs.setBool('checkDataMine', value);
                  ref.read(checkDataMine.notifier).state = value;
                },
                title: const Text('DataMine Notifier'),
                leading: Image.asset(
                  'assets/gszabi.jpg',
                  width: 30,
                  height: 30,
                ),
              ),
              SettingsTile.switchTile(
                initialValue: ref.watch(additionalNotif),
                onToggle: (value) {
                  ref.read(additionalNotif.notifier).state = value;
                  prefs.setBool('additionalNotif', value);
                },
                title: const Text('Tray and Greeting Notifications'),
                leading: const Icon(Icons.notifications_active),
              ),
              SettingsTile(
                title: const Text('Set Custom Feed Url'),
                leading: const Icon(Icons.rss_feed),
                onPressed: (ctx) async {
                  ref.read(customFeed.notifier).state =
                      (await Navigator.of(context).push(dialogBuilderUrl(
                          context, ref.watch(customFeed) ?? '')));
                  await prefs.setString(
                      'customFeed', ref.watch(customFeed) ?? '');
                },
              ),
              SettingsTile.navigation(
                title: const Text('Switch to Custom Feed'),
                leading: const Icon(Icons.rss_feed),
                onPressed: (ctx) async {
                  if (ref.read(customFeed.notifier).state != null &&
                      ref.read(customFeed.notifier).state!.isNotEmpty) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const CustomRSSView()));
                  } else {
                    await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                              title: const Text('Error'),
                              content: const Text(
                                  'Please set custom feed url first :)'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.of(context).pop(),
                                )
                              ],
                            ));
                  }
                },
              ),
              SettingsTile.navigation(
                title: const Text('Switch to Overlay Mode'),
                leading: const Icon(Icons.desktop_windows),
                onPressed: (ctx) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const OverlayMode()));
                },
              ),
            ],
          ),
          SettingsSection(title: const Text('Misc'), tiles: [
            SettingsTile(
              title: const Text('Set Username'),
              leading: const Icon(Icons.account_circle),
              onPressed: (ctx) async {
                ref.read(userNameProvider.notifier).state =
                    (await Navigator.of(context)
                        .push(dialogBuilderUserName(context)))!;
                Sentry.configureScope(
                  (scope) => scope.user = SentryUser(
                      username: ref.watch(userNameProvider),
                      ipAddress: scope.user?.ipAddress),
                );

                await prefs.setString(
                    'userName', ref.watch(userNameProvider) ?? '');
                await PresenceService().configureUserPresence(
                    (await deviceInfo.windowsInfo).computerName,
                    prefs.getBool('startup') ?? false,
                    File(pathToVersion).readAsStringSync());
              },
            ),
            SettingsTile(
              title: const Text('Send Feedback to Vonarian'),
              leading: const Icon(Icons.favorite),
              onPressed: (ctx) async {
                if (ref.watch(userNameProvider) != null ||
                    ref.watch(userNameProvider)!.isNotEmpty) {
                  SentryId sentryId = await Sentry.captureMessage(
                      (await Navigator.of(context)
                          .push(dialogBuilderFeedback(context))));
                  final feedback = SentryUserFeedback(
                    eventId: sentryId,
                    name: ref.watch(userNameProvider),
                  );

                  await Sentry.captureUserFeedback(feedback);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                    ..removeCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                        content: Text('Feedback sent, thanks!')));
                } else {
                  await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: const Text('Error'),
                            content: const Text('Please set username first :)'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('OK'),
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            ],
                          ));
                }
              },
            ),
          ]),
        ]);
  }

  String pathToAddShortcut =
      '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/addShortcut.bat';
  String pathToRemoveShortcut =
      '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/removeShortcut.bat';
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            backgroundColor: Colors.transparent,
            body: settings(context),
          ),
          const WindowTitleBar(isCustom: true),
        ],
      ),
    );
  }
}
