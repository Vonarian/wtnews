import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/main.dart';

import '../providers.dart';
import '../services/github.dart';
import '../widgets/titlebar.dart';
import 'downloader.dart';
import 'rss_feed.dart';

class Loading extends ConsumerStatefulWidget {
  const Loading({Key? key}) : super(key: key);

  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends ConsumerState<Loading> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      await checkGitVersion(await checkVersion());
      ref.read(minimizeOnStart.notifier).state =
          prefs.getBool('minimize') ?? false;
      if (ref.watch(minimizeOnStart)) {
        await windowManager.minimize();
        await windowManager.hide();
      }
    });
  }

  Future<String> checkVersion() async {
    try {
      final File file = File(
          '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/install/version.txt');
      final String version = await file.readAsString();
      return version;
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> checkGitVersion(String version) async {
    try {
      Data data = await Data.getData();
      if (int.parse(data.tagName.replaceAll('.', '')) >
          int.parse(version.replaceAll('.', ''))) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
                'Version: $version. Status: Proceeding to update in 4 seconds!'),
            action: SnackBarAction(
                label: 'Cancel update',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (c, a1, a2) => const RSSView(),
                      transitionsBuilder: (c, anim, a2, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 1000),
                    ),
                  );
                }),
          ));

        Future.delayed(const Duration(seconds: 5), () async {
          Navigator.of(context)
              .pushReplacement(MaterialPageRoute(builder: (context) {
            return const Downloader();
          }));
        });
      } else {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 10),
              content: Text('Version: $version ___ Status: Up-to-date!')));
        Future.delayed(const Duration(microseconds: 500), () async {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => const RSSView(),
              transitionsBuilder: (c, anim, a2, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 1000),
            ),
          );
        });
      }
    } catch (e, st) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
                'Version: $version ___ Status: Error checking for update!')));
      await Sentry.captureException(e, stackTrace: st);
      Future.delayed(const Duration(seconds: 2), () async {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => const RSSView(),
            transitionsBuilder: (c, anim, a2, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 2000),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
                    Colors.black,
                    Colors.black,
                    Colors.black,
                  ],
                )),
              ),
              imageFilter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0)),
          const Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            ),
          ),
          const WindowTitleBar(isCustom: false),
        ],
      ),
    );
  }
}
