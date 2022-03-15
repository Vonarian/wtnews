import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/github.dart';
import '../widgets/titlebar.dart';
import 'downloader.dart';
import 'rss_feed.dart';

class Loading extends StatefulWidget {
  const Loading({Key? key}) : super(key: key);

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      await checkGitVersion(await checkVersion());
    });
  }

  Future<String> checkVersion() async {
    final File file = File(
        '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/install/version.txt');
    final String version = await file.readAsString();
    return version;
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
                  'Version: $version. Status: Proceeding to update in 3 seconds!')));

        Future.delayed(const Duration(seconds: 3), () async {
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
    } catch (e, st) {
      log('ERROR: $e', stackTrace: st);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
                'Version: $version ___ Status: Error checking for update!')));
      Future.delayed(const Duration(seconds: 4), () async {
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
              child: Image.asset(
                'assets/bg.png',
                fit: BoxFit.cover,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)),
          const Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            ),
          ),
          const WindowTitleBar(),
        ],
      ),
    );
  }
}
