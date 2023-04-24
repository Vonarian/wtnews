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
import 'package:window_manager/window_manager.dart';

import '../data/news.dart';
import '../main.dart';
import '../providers.dart';
import '../services/utility.dart';

class App extends ConsumerStatefulWidget {
  final bool startup;

  const App({super.key, required this.child, required this.startup});

  final Widget child;

  @override
  AppState createState() => AppState();
}

class AppState extends ConsumerState<App> with TrayListener, WindowListener {
  late final FlutterTts tts;
  late final newsChannel = News.connectAllNews();

  void loadFromPrefs() {
    newItemTitle.value = prefs.getString('lastTitle');
  }

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    loadFromPrefs();
    avoidEmptyNews();
    legacyChecker();
    AppUtil.setupTTS().then((value) => tts = value);
    final modeNotifier = ref.read(provider.updateModeProvider.notifier);
    autoLegacy.addListener(() {
      modeNotifier.update(autoLegacy: autoLegacy.value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(provider.prefsProvider.notifier).load();
      if (widget.startup &&
          ref.read(provider.prefsProvider).minimizeAtStartup) {
        await _trayInit();
      }
    });
    webSocketConnect();
    final appPrefs = ref.read(provider.prefsProvider);
    Future.delayed(const Duration(seconds: 20), () {
      newItemTitle.addListener(() async {
        final newsList = ref.read(provider.newsProvider);
        final newItem = newsList.first;
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
        prefs.setString('lastTitle', newItemTitle.value!);
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

  Future<void> webSocketReconnect(Duration delay) async {
    reconnecting = true;
    log('Trying to reconnect in ${delay.inSeconds} Seconds');
    await Future.delayed(delay);
    await webSocketConnect();
    reconnecting = false;
  }

  Future<void> _onError(e, {required String channelName}) async {
    log('$channelName Error: ${e.toString()}');
    autoLegacy.value = true;
    if (reconnecting) return;
    await webSocketReconnect(const Duration(seconds: 10));
  }

  Future<void> _onDone({required String channelName}) async {
    log('$channelName Done');
    autoLegacy.value = true;
    if (reconnecting) return;
    await webSocketReconnect(const Duration(seconds: 10));
  }

  Future<void> webSocketConnect() async {
    final newsNotifier = ref.read(provider.newsProvider.notifier);
    Future.delayed(Duration.zero, () async {
      newsChannel.ready.then((_) {
        autoLegacy.value = false;
        ref
            .read(provider.updateModeProvider.notifier)
            .update(webSocketConnected: true);
      }).timeout(const Duration(seconds: 2));
      newsChannel.stream.listen((event) {
        autoLegacy.value = false;
        final json = jsonDecode(event);
        if (json['error'] != null) return;
        if (json is! List) {
          final news = News.fromJson(json, workers: false);
          newsNotifier.add(news);
          newsNotifier.deduplicate();
          newsNotifier.sortByTime();
        } else {
          final listNews =
              json.map((e) => News.fromJson(e, workers: false)).toList();

          newsNotifier.addAll(listNews);
          newsNotifier.deduplicate();
          newsNotifier.sortByTime();
        }
        newItemTitle.value = ref.read(provider.newsProvider).first.title;
      },
          cancelOnError: false,
          onError: (e) => _onError(e, channelName: 'NewsChannel'),
          onDone: () => _onDone(channelName: 'NewsChannel'));
    });
  }

  Future<void> avoidEmptyNews() async {
    final newsNotifier = ref.read(provider.newsProvider.notifier);
    while (ref.read(provider.newsProvider).isEmpty) {
      try {
        final value = await News.getAllNews()
            .timeout(const Duration(seconds: 10), onTimeout: () => []);
        if (value.isNotEmpty) {
          newsNotifier.addAll(value);
          newsNotifier.deduplicate();
          newsNotifier.sortByTime();
        }
      } on DioError catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    }
  }

  Future<void> legacyChecker() async {
    final newsNotifier = ref.read(provider.newsProvider.notifier);

    Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (ref.read(
              provider.prefsProvider.select((value) => value.legacyUpdate)) ||
          autoLegacy.value) {
        final value = await News.getAllNews()
            .timeout(const Duration(seconds: 10), onTimeout: () => []);
        if (value.isNotEmpty) {
          newsNotifier.addAll(value);
          newsNotifier.deduplicate();
          newsNotifier.sortByTime();
        }
      }
    });
  }

  final autoLegacy = ValueNotifier(false);
  bool reconnecting = false;

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    newsChannel.sink.close();
    autoLegacy.dispose();
    super.dispose();
  }

  bool focused = true;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final sysColor = ref.watch(provider.systemColorProvider);
    final disableBackgroundTransparency = ref.watch(provider.prefsProvider
        .select((value) => value.disableBackgroundTransparency));
    late Color bgColor;
    if (!disableBackgroundTransparency) {
      bgColor = Colors.black.withOpacity(0.50).withAlpha(70);
    } else {
      bgColor = Colors.grey.withAlpha(50);
    }
    return FluentApp(
        builder: (context, child) {
          return Column(
            children: [
              SizedBox(
                height: kWindowCaptionHeight,
                child: WindowCaption(
                  title: const Text(
                    'WTNews',
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
        themeMode: ThemeMode.dark,
        theme: FluentThemeData(
          brightness: Brightness.dark,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: bgColor,
          accentColor: sysColor.toAccentColor(),
          navigationPaneTheme: NavigationPaneThemeData(
            animationDuration: const Duration(milliseconds: 600),
            animationCurve: Curves.easeInOut,
            highlightColor: sysColor.toAccentColor().lighter,
            backgroundColor: bgColor,
          ),
        ),
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
