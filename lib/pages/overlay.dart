import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/pages/rss_feed.dart';
import 'package:wtnews/services/utility.dart';

class OverlayMode extends ConsumerStatefulWidget {
  const OverlayMode({Key? key}) : super(key: key);

  @override
  _OverlayModeState createState() => _OverlayModeState();
}

class _OverlayModeState extends ConsumerState<OverlayMode>
    with SingleTickerProviderStateMixin {
  @override
  initState() {
    super.initState();
    startHotkey();
    title.addListener(() async {
      AppUtil().playSound(newSound);
      await Future.delayed(const Duration(milliseconds: 3500));
      rssFeed = null;
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      rssFeed = await getForum();
      if (rssFeed != null && title.value != rssFeed?.items?[0].title) {
        title.value = rssFeed?.items![0].title;
        setState(() {});
      }
    });
  }

  Widget notification(BuildContext context, String value) {
    return SizedBox(
      width: 210,
      height: 75,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          tileColor: Colors.black.withOpacity(0.55),
          title: const Text('New Post!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              )),
          subtitle: Text(value, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }

  Future<void> startHotkey() async {
    await Window.setEffect(
        effect: WindowEffect.transparent, color: Colors.transparent);
    await Process.start(pathAhkExe, [pathAhkScript]);
    await Window.enterFullscreen();
    HotKey hotKey = HotKey(
      KeyCode.keyQ,
      modifiers: [KeyModifier.shift, KeyModifier.control],
      scope: HotKeyScope.system,
    );
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) async {
        Window.exitFullscreen();
        Window.setEffect(
            effect: WindowEffect.aero, color: Colors.black.withOpacity(0.55));
        Process.start('taskkill', ['/im', 'AutoHotkeyU64.exe']);
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const RSSView()));
      },
    );
  }

  Future<RssFeed> getForum() async {
    Dio dio = Dio();
    Response response = await dio
        .get('https://forum.warthunder.com/index.php?/discover/693.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    return rssFeed;
  }

  ValueNotifier<String?> title = ValueNotifier<String?>(null);

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregisterAll();
    title.removeListener(() {});
  }

  RssFeed? rssFeed;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      width: 210,
      height: 75,
      alignment: Alignment.topRight,
      child: rssFeed != null
          ? notification(context, title.value as String)
          : const SizedBox(),
    );
  }
}
