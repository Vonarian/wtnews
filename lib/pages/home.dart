import 'dart:async';
import 'dart:developer';

import 'package:firebase_dart/database.dart' show Event;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wtnews/data/firebase.dart';
import 'package:wtnews/widgets/news_view.dart';
import 'package:wtnews/widgets/settings.dart';

import '../data/rtdb_model.dart';
import '../main.dart';
import '../providers.dart';

class Home extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const Home(this.prefs, {Key? key}) : super(key: key);

  @override
  HomeState createState() => HomeState();
}

class HomeState extends ConsumerState<Home> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      subscription = startListening();
      try {
        await presenceService.configureUserPresence(
            (await deviceInfo.windowsInfo).computerName,
            ref.read(provider.prefsProvider).runAtStartup,
            appVersion,
            prefs: widget.prefs);
      } catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    });
    final devMessageValue = presenceService.getDevMessage();
    devMessageValue.listen((Event e) async {
      final event = e.snapshot.value as String;
      if (event != widget.prefs.getString('devMessage')) {
        final toast = LocalNotification(title: 'New Message from Vonarian')
          ..show();
        await widget.prefs.setString('devMessage', event);
        toast.onClick = () {
          displayInfoBar(context,
              builder: (context, close) => InfoBar(
                    title: const Text('New Developer Message'),
                    content: Text(event),
                  ),
              duration: const Duration(seconds: 10));
        };
      }
    });
    presenceService.getMessage(uid).listen((event) async {
      final data = event.snapshot.value;
      if (data != null && data != widget.prefs.getString('pm')) {
        LocalNotification(title: 'New private message', body: data).show();
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('New Private Message from Vonarian!'),
            content: Text(data),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.info,
          );
        });
        await widget.prefs.setString('pm', data);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      presenceService.disconnect();
      subscription?.cancel();
    }
    if (state == AppLifecycleState.resumed) {
      presenceService.connect();
      subscription?.resume();
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
  }

  StreamSubscription? startListening() {
    final db = PresenceService.database;
    db.goOnline();
    return db.reference().child('notification').onValue.listen((event) async {
      final data = event.snapshot.value;
      if (data != null &&
          data['title'] != null &&
          data['subtitle'] != null &&
          data['id'] != null &&
          data['title'] != '' &&
          data['subtitle'] != '') {
        Message message = Message.fromMap(data);
        if (widget.prefs.getInt('id') != message.id) {
          if (message.device == (await deviceInfo.windowsInfo).computerName ||
              message.device == null) {
            var toast =
                LocalNotification(title: message.title, body: message.subtitle)
                  ..show();
            toast.onClick = () {
              if (message.url != null) {
                launchUrl(Uri.parse(message.url!));
              }
            };
            await widget.prefs.setInt('id', message.id);
          }
        }
      }
    });
  }

  StreamSubscription? subscription;
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final firebaseValue = ref.watch(provider.versionFBProvider);
    final paneDisplayMode = ref
        .watch(provider.prefsProvider.select((value) => value.paneDisplayMode));
    return Column(
      children: [
        Expanded(
          child: NavigationView(
            pane: NavigationPane(
                selected: index,
                displayMode: paneDisplayMode,
                onChanged: (newIndex) {
                  setState(() {
                    index = newIndex;
                  });
                },
                items: [
                  PaneItem(
                      icon: const Icon(FluentIcons.home),
                      title: const Text(
                        'Home',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      body: const NewsView()),
                ],
                footerItems: [
                  PaneItem(
                    icon: const Icon(FluentIcons.settings),
                    title: const Text(
                      'Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    infoBadge: firebaseValue.when(
                      data: (data) {
                        if (data != null) {
                          return const Tooltip(
                            message: 'New update!',
                            child: InfoBadge(source: Text('!')),
                          );
                        } else {
                          return null;
                        }
                      },
                      loading: () => null,
                      error: (error, st) => null,
                    ),
                    body: Settings(widget.prefs),
                  ),
                ]),
          ),
        ),
      ],
    );
  }
}
