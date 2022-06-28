import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' hide MenuItem;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart';

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
        ref.read(provider.minimizeOnStart.notifier).state =
            prefs.getBool('minimize') ?? false;
        if (ref.watch(provider.minimizeOnStart)) {
          await windowManager.minimize();
          await windowManager.hide();
        }
      }
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
    super.dispose();
  }

  bool focused = true;

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
      WinToast.instance().showToast(
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
