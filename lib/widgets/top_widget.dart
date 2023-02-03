import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' hide MenuItem;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:system_theme/system_theme.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/services/data/firebase.dart';

import '../main.dart';
import '../services/utility.dart';

class App extends ConsumerStatefulWidget {
  final bool startup;

  const App({super.key, required this.child, required this.startup});

  final Widget child;

  @override
  AppState createState() => AppState();
}

class AppState extends ConsumerState<App>
    with TrayListener, WindowListener, LocalNotificationListener {
  @override
  void initState() {
    final prefs = ref.read(provider.prefsProvider);
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    localNotifier.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.startup) {
        ref.read(provider.checkDataMine.notifier).state =
            prefs.getBool('checkDataMine') ?? false;
        ref.read(provider.minimizeOnStart.notifier).state =
            prefs.getBool('minimize') ?? false;
        await Future.delayed(const Duration(milliseconds: 20));
        if (ref.watch(provider.minimizeOnStart)) {
          await windowManager.minimize();
          await windowManager.hide();
        }
      }
      ref.read(provider.focusedProvider.notifier).state =
          prefs.getBool('focused') ?? false;
      presenceService.getPremium(uid).listen((event) {
        if (event.snapshot.value is bool) {
          ref.read(provider.premiumProvider.notifier).state =
              event.snapshot.value;
        }
      });
      presenceService.getMessage(uid).listen((event) async {
        final data = event.snapshot.value;
        if (data != null && data != prefs.getString('pm')) {
          final notif =
              LocalNotification(title: 'New private message', body: data)
                ..show();
          notif.onClick = () {};
          await prefs.setString('pm', data);
        }
      });
    });
    lastPubDate.addListener(() async {
      await notify(lastPubDate.value!, newItemUrl!);
      await prefs.setString('previous', lastPubDate.value!);
    });
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!focused) return;
      Color? systemColor = await DynamicColorPlugin.getAccentColor();
      Brightness brightness =
          SystemTheme.isDarkMode ? Brightness.dark : Brightness.light;
      if (ref.read(provider.systemColorProvider.notifier).state !=
              systemColor &&
          systemColor != null) {
        ref.read(provider.systemColorProvider.notifier).state = systemColor;
      }
      if (brightness != ref.read(provider.systemThemeProvider.notifier).state) {
        ref.read(provider.systemThemeProvider.notifier).state = brightness;
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    localNotifier.removeListener(this);
    lastPubDate.removeListener(() {});
    super.dispose();
  }

  Future<void> notify(String pubDate, String url) async {
    final prefs = ref.read(provider.prefsProvider);
    if (prefs.getString('previous') != null) {
      if (prefs.getString('previous') != pubDate) {
        String? previous = prefs.getString('previous');
        if (kDebugMode) {
          print('isNew');
          print(previous);
          print(pubDate);
        }

        AppUtil.playSound(newSound);
        final toast = LocalNotification(
          title: 'New Data Mine',
          body: 'Click to launch in browser',
        )..show();
        toast.onClick = () {
          launchUrl(Uri.parse(url));
        };
      }
    } else {
      if (kDebugMode) {
        print('Null');
      }
      AppUtil.playSound(newSound);
      final toast = LocalNotification(
          title: 'New Data Mine', body: 'Click to launch in browser')
        ..show();
      toast.onClick = () {
        launchUrl(Uri.parse(url));
      };
    }
  }

  Future<RssFeed> getDataMine() async {
    Response response = await dio
        .get('https://forum.warthunder.com/index.php?/discover/704.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    return rssFeed;
  }

  bool focused = true;
  String? newItemUrl;
  ValueNotifier<String?> lastPubDate = ValueNotifier(null);
  RssFeed? rssFeed;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
        theme: ThemeData(
            brightness: ref.watch(provider.systemThemeProvider),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            cardColor: Colors.transparent,
            accentColor:
                ref.watch(provider.systemColorProvider).toAccentColor(),
            navigationPaneTheme: NavigationPaneThemeData(
                animationDuration: const Duration(milliseconds: 600),
                animationCurve: Curves.easeInOut,
                highlightColor: ref.watch(provider.systemColorProvider),
                iconPadding: const EdgeInsets.only(left: 6),
                labelPadding: const EdgeInsets.only(left: 4),
                backgroundColor: Colors.transparent)),
        debugShowCheckedModeBanner: false,
        title: 'WTNews',
        home: widget.child);
  }

  Future<void> _handleClickRestore() async {
    await windowManager.setIcon('assets/app_icon.ico');
    windowManager.restore();
    windowManager.show();
  }

  Future<void> _trayInit() async {
    await trayManager.setIcon(
      'assets/app_icon.ico',
    );
    Menu menu = Menu(items: [
      MenuItem(key: 'show-app', label: 'Show'),
      MenuItem.separator(),
      MenuItem(key: 'close-app', label: 'Exit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  void _trayUnInit() async {
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() async {
    _handleClickRestore();
    _trayUnInit();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onWindowRestore() {
    setState(() {});
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show-app':
        windowManager.show();
        break;
      case 'close-app':
        windowManager.close();
        break;
    }
  }

  @override
  void onWindowMinimize() {
    windowManager.hide();
    setState(() {
      focused = false;
    });
    _trayInit();
  }

  @override
  void onWindowFocus() {
    setState(() {
      focused = true;
    });
  }

  @override
  void onLocalNotificationClick(LocalNotification notification) {
    return;
  }
}
