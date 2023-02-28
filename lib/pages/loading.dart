import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data/github.dart';
import 'downloader.dart';
import 'home.dart';

class Loading extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const Loading(this.prefs, {Key? key}) : super(key: key);

  @override
  LoadingState createState() => LoadingState();
}

class LoadingState extends ConsumerState<Loading> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkGitVersion(await checkVersion());
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
      GHData data = await GHData.getData();
      if (int.parse(data.tagName.replaceAll('.', '')) >
          int.parse(version.replaceAll('.', ''))) {
        if (!mounted) return;
        showSnackbar(
            context,
            Snackbar(
              content: Text(
                  'Version: $version. Status: Proceeding to update in 4 seconds!'),
              action: Button(
                  child: const Text('Cancel update'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (c, a1, a2) => Home(widget.prefs),
                        transitionsBuilder: (c, anim, a2, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 1000),
                      ),
                    );
                  }),
              extended: true,
            ));

        Future.delayed(const Duration(seconds: 4), () async {
          Navigator.of(context)
              .pushReplacement(FluentPageRoute(builder: (context) {
            return const Downloader();
          }));
        });
      } else {
        if (!mounted) return;

        showSnackbar(
          context,
          Snackbar(
            content: Text('Version: $version ___ Status: Up-to-date!'),
            extended: true,
          ),
        );
        Future.delayed(const Duration(microseconds: 500), () async {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => Home(widget.prefs),
              transitionsBuilder: (c, anim, a2, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 1000),
            ),
          );
        });
      }
    } catch (e, st) {
      showSnackbar(
          context,
          Snackbar(
            content: Text(
                'Version: $version ___ Status: Error checking for update!'),
            extended: true,
          ));
      await Sentry.captureException(e, stackTrace: st);
      Future.delayed(const Duration(seconds: 2), () async {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => Home(widget.prefs),
            transitionsBuilder: (c, anim, a2, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: ProgressRing(
              strokeWidth: 10,
              activeColor: FluentTheme.of(context).accentColor,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'Checking for updates...',
          ),
        ],
      )),
    );
  }
}
