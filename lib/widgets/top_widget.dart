import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart';
import '../providers.dart';
import '../services/data/news.dart';
import '../services/utility.dart';

class App extends ConsumerStatefulWidget {
  final bool startup;

  const App({super.key, required this.child, required this.startup});

  final Widget child;

  @override
  AppState createState() => AppState();
}

class AppState extends ConsumerState<App> with TrayListener, WindowListener {
  final List<WebSocketChannel> channels = [];
  late final FlutterTts tts;

  List<WebSocketChannel> getAllChannels() {
    final newsChannel = News.connectNews();
    final changelogChannel = News.connectChangelog();
    return [newsChannel, changelogChannel];
  }

  void loadFromPrefs() {
    newItemTitle.value = prefs.getString('lastTitle');
  }

  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    AppUtil.setupTTS().then((value) => tts = value);
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(provider.prefsProvider.notifier).load();
      if (widget.startup &&
          ref.read(provider.prefsProvider).minimizeAtStartup) {
        await _trayInit();
      }
    });
    channels.addAll(getAllChannels());
    if (channels.isNotEmpty) {
      Future.delayed(Duration.zero, () async {
        final newsNotifier = ref.read(provider.newsProvider.notifier);
        final newsChannel = channels.first;
        newsChannel.ready.then((_) {
          newsChannel.stream.listen((event) {
            final json = jsonDecode(event);
            if (json['error'] != null) return;
            if (json is! List) {
              final news = News.fromJson(json);
              newsNotifier.add(news);
              newsNotifier.deduplicate();
              newsNotifier.sortByTime();
              return;
            }
            final listNews = json.map((e) => News.fromJson(e)).toList();
            newsNotifier.addAll(listNews);
            newsNotifier.deduplicate();
            newsNotifier.sortByTime();
          });
        });
        final changelogChannel = channels.last;
        changelogChannel.ready.then((_) {
          changelogChannel.stream.listen((event) {
            final json = jsonDecode(event);
            if (json['error'] != null) return;
            if (json is! List) {
              final news = News.fromJson(json);
              newsNotifier.add(news);
              newsNotifier.deduplicate();
              newsNotifier.sortByTime();
              return;
            }
            final listNews = json.map((e) => News.fromJson(e)).toList();
            newsNotifier.addAll(listNews);
            newsNotifier.deduplicate();
            newsNotifier.sortByTime();
          });
        });
      });
    }
    final appPrefs = ref.read(provider.prefsProvider);
    Future.delayed(const Duration(seconds: 10), () {
      final newsList = ref.read(provider.newsProvider);
      final newItem = newsList.first;
      newItemTitle.addListener(() async {
        try {
          if (!appPrefs.focusedMode) {
            await AppUtil.sendNotification(
                newTitle: newItemTitle.value, url: newItem.link);
            if (appPrefs.playSound) {
              await compute(AppUtil.playSound, newSound);
            }
            if (appPrefs.readNewTitle) {
              await tts.speak(newItemTitle.value ?? '');
            }
            if (appPrefs.readNewCaption) {
              await tts.speak(newsList.first.description);
            }
          } else {
            if (newItem.dev) {
              await AppUtil.sendNotification(
                  newTitle: newItemTitle.value, url: newItem.link);
              if (appPrefs.playSound) {
                await compute(AppUtil.playSound, newSound);
              }
              if (appPrefs.readNewTitle) {
                await tts.speak(newItemTitle.value ?? '');
              }
              if (appPrefs.readNewCaption) {
                await tts.speak(newsList.first.description);
              }
            }
          }
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st);
        }
      });
    });
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!focused) return;
      Color? systemColor = await DynamicColorPlugin.getAccentColor();
      if (ref.read(provider.systemColorProvider.notifier).state !=
              systemColor &&
          systemColor != null) {
        ref.read(provider.systemColorProvider.notifier).state = systemColor;
      }
    });
  }

  Future<List<News>> getAllNews() async {
    try {
      final result = await Future.wait([News.getNews(), News.getChangelog()]);
      final List<News> finalList = [...result.first, ...result.last];
      finalList.sort((a, b) => b.date.compareTo(a.date));
      return finalList;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> avoidEmptyNews() async {
    final newsList = ref.read(provider.newsProvider);
    final newsNotifier = ref.read(provider.newsProvider.notifier);
    while (newsList.isEmpty) {
      try {
        final value = await getAllNews()
            .timeout(const Duration(seconds: 7), onTimeout: () => []);
        if (value.isNotEmpty) {
          setState(() {
            newsNotifier.addAll(value);
            newsNotifier.deduplicate();
          });
        }
      } on DioError catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    for (var ch in channels) {
      ch.sink.close();
    }
    super.dispose();
  }

  bool focused = true;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final sysColor = ref.watch(provider.systemColorProvider);
    final bgColor = Colors.black.withOpacity(0.50);
    return FluentApp(
        builder: (context, child) {
          return Column(
            children: [
              SizedBox(
                height: kWindowCaptionHeight,
                child: WindowCaption(
                  title: Text(
                    'WTNews v$appVersion',
                    textAlign: TextAlign.left,
                  ),
                  brightness: Brightness.dark,
                  backgroundColor: bgColor,
                ),
              ),
              Expanded(child: child ?? const SizedBox()),
            ],
          );
        },
        theme: FluentThemeData(
            brightness: Brightness.dark,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: bgColor,
            accentColor: sysColor.toAccentColor(),
            navigationPaneTheme: NavigationPaneThemeData(
              animationDuration: const Duration(milliseconds: 600),
              animationCurve: Curves.easeInOut,
              highlightColor: sysColor,
              backgroundColor: bgColor,
            )),
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
    focused = true;
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
    focused = false;
    _trayInit();
  }

  @override
  void onWindowFocus() {
    focused = true;
  }
}
