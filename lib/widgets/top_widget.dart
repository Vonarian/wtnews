import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' hide MenuItem;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart';
import '../services/utility.dart';

class App extends ConsumerStatefulWidget {
  final bool startup;

  const App({super.key, required this.child, required this.startup});

  final Widget child;

  @override
  AppState createState() => AppState();
}

class AppState extends ConsumerState<App> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
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
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (ref.watch(provider.checkDataMine)) {
        rssFeed = await getDataMine()
            .timeout(const Duration(seconds: 25))
            .whenComplete(() async {
          if (rssFeed != null && rssFeed?.items != null) {
            RssItem item = rssFeed!.items!.first;
            if (item.description != null) {
              String itemDescription = item.description!;
              bool? isDataMine = (itemDescription.contains('Raw changes:') &&
                      itemDescription.contains('→') &&
                      itemDescription.contains('Current dev version')) ||
                  itemDescription.contains('	');
              if (isDataMine) {
                if (lastPubDate.value != item.pubDate.toString()) {
                  newItemUrl = item.link;
                  lastPubDate.value = item.pubDate.toString();
                }
              }
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    lastPubDate.removeListener(() {});
    super.dispose();
  }

  Future<void> notify(String pubDate, String url) async {
    if (prefs.getString('previous') != null) {
      if (prefs.getString('previous') != pubDate) {
        String? previous = prefs.getString('previous');
        if (kDebugMode) {
          print('isNew');
          print(previous);
          print(pubDate);
        }

        AppUtil.playSound(newSound);
        final toast = await winToast.showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'Click to launch in browser',
        );
        toast?.eventStream.listen((event) {
          if (event is ActivatedEvent) {
            launchUrl(Uri.parse(url));
          }
        });
      }
    } else {
      if (kDebugMode) {
        print('Null');
      }
      AppUtil.playSound(newSound);
      final toast = await winToast.showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'New Data Mine from gszabi');
      toast?.eventStream.listen((event) {
        if (event is ActivatedEvent) {
          launchUrl(Uri.parse(url));
        }
      });
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
    if (prefs.getBool('additionalNotif') != null &&
        prefs.getBool('additionalNotif')!) {
      winToast.showToast(
          type: ToastType.text04,
          title: 'WTNews is minimized to tray',
          subtitle: 'Check tray to open app again');
    }
  }

  @override
  void onWindowFocus() {
    setState(() {
      focused = true;
    });
  }
}
