import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/widgets/titlebar.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          ImageFiltered(
              child: Image.asset(
                'assets/bg.png',
                fit: BoxFit.cover,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                      onPressed: () async {
                        ref.read(isStartupEnabled.notifier).state =
                            await launchAtStartup.isEnabled();
                        PackageInfo packageInfo =
                            await PackageInfo.fromPlatform();
                        launchAtStartup.setup(
                          appName: packageInfo.appName,
                          appPath: Platform.resolvedExecutable,
                        );

                        if (!ref.watch(isStartupEnabled)) {
                          await launchAtStartup.enable();
                        } else {
                          await launchAtStartup.disable();
                        }
                        ref.read(isStartupEnabled.notifier).state =
                            await launchAtStartup.isEnabled();
                      },
                      icon: const Icon(
                        Icons.settings,
                        size: 40,
                      ),
                      label: Text(
                        'Start at startup: ${ref.watch(isStartupEnabled) ? 'On' : 'Off'}',
                        style: const TextStyle(fontSize: 40),
                      ))
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
