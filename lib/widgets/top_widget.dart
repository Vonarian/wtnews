import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../providers.dart';

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
      ref.read(provider.prefsProvider.notifier).load();
      if (widget.startup &&
          ref.read(provider.prefsProvider).minimizeAtStartup) {
        await _trayInit();
      }
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

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  bool focused = true;

  @override
  Widget build(BuildContext context) {
    final sysColor = ref.watch(provider.systemColorProvider);
    final bgColor = Colors.black.withOpacity(0.45);
    return FluentApp(
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
    focused = false;
    _trayInit();
  }

  @override
  void onWindowFocus() {
    focused = true;
  }
}
