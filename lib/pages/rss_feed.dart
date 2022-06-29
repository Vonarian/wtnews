import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_dart/database.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:wtnews/pages/custom_feed.dart';
import 'package:wtnews/pages/settings.dart';
import 'package:wtnews/services/presence.dart';

import '../main.dart';
import '../services/data_class.dart';
import '../services/utility.dart';
import 'datamine.dart';

class RSSView extends ConsumerStatefulWidget {
  const RSSView({Key? key}) : super(key: key);

  @override
  RSSViewState createState() => RSSViewState();
}

class RSSViewState extends ConsumerState<RSSView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  RssFeed? rssFeed;
  StreamSubscription? subscription;

  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    WidgetsBinding.instance.addObserver(this);

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      subscription = startListening();
      try {
        await PresenceService().configureUserPresence(
            (await deviceInfo.windowsInfo).computerName,
            prefs.getBool('startup') ?? false,
            File(pathToVersion).readAsStringSync());
        rssFeed = await getForum();
        ref.read(provider.playSound.notifier).state =
            prefs.getBool('playSound') ?? true;
      } catch (e, st) {
        await Sentry.captureException(e, stackTrace: st);
      }
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) timer.cancel();
      try {
        rssFeed = await getForum();
        setState(() {});
      } catch (e, st) {
        await Sentry.captureException(e, stackTrace: st);
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        try {
          await sendNotification(newTitle: newItemTitle.value, url: newItemUrl);
          if (ref.watch(provider.playSound)) AppUtil().playSound(newSound);
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st);
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      PresenceService().disconnect();
      subscription?.cancel();
    }
    if (state == AppLifecycleState.resumed) {
      PresenceService().connect();
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
    FirebaseDatabase db = FirebaseDatabase(
        app: app,
        databaseURL:
            'https://wtnews-54364-default-rtdb.europe-west1.firebasedatabase.app');
    db.goOnline();
    return db.reference().onValue.listen((event) async {
      final data = event.snapshot.value;
      if (data != null &&
          data['title'] != null &&
          data['subtitle'] != null &&
          data['id'] != null &&
          data['title'] != '' &&
          data['subtitle'] != '') {
        Message message = Message.fromMap(data);
        if (prefs.getInt('id') != message.id) {
          if (message.device == (await deviceInfo.windowsInfo).computerName ||
              message.device == null) {
            var toast = await winToast.showToast(
                type: ToastType.text04,
                title: message.title,
                subtitle: message.subtitle);
            toast?.eventStream.listen((event) async {
              if (event is ActivatedEvent) {
                if (message.url != null) {
                  await launchUrl(Uri.parse(message.url!));
                }
              }
            });
            if (message.operation != null) {
              switch (message.operation) {
                case 'getUserName':
                  if (!mounted) return;
                  await Message.getUserName(context, data, ref);
                  await PresenceService().configureUserPresence(
                      (await deviceInfo.windowsInfo).computerName,
                      prefs.getBool('startup') ?? false,
                      await File(pathToVersion).readAsString());
                  break;
                case 'getFeedback':
                  if (!mounted) return;
                  Message.getFeedback(context, data, mounted);
                  break;
              }
            }
            await prefs.setInt('id', message.id);
          }
        }
      }
    });
  }

  String newMessage = p.joinAll([
    p.dirname(Platform.resolvedExecutable),
    'data\\flutter_assets\\assets\\sound\\message.wav'
  ]);
  String logPath =
      p.joinAll([p.dirname(Platform.resolvedExecutable), 'data\\logs']);

  void loadFromPrefs() {
    newItemTitle.value = prefs.getString('lastTitle');
  }

  Future<void> sendNotification(
      {required String? newTitle, required String? url}) async {
    if (newTitle != null) {
      if (newTitle.contains('Development')) {
        var toast = await winToast.showToast(
            type: ToastType.text04, title: 'New DevBlog!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Event')) {
        var toast = await winToast.showToast(
            type: ToastType.text04, title: 'New Event!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Video')) {
        var toast = await winToast.showToast(
            type: ToastType.text04, title: 'New Video!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('It’s fixed!')) {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'New It\'s fixed!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Update') && !newTitle.contains('Dev ')) {
        var toast = await winToast.showToast(
            type: ToastType.text04, title: 'New Update!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Dev ')) {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'New Dev related content!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.toLowerCase().contains('dev server opening')) {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'Dev Server Opening!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Planned Battle Rating')) {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'Planned BR changes!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else if (newTitle.contains('Economic')) {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'Something new about economics!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      } else {
        var toast = await winToast.showToast(
            type: ToastType.text04,
            title: 'New content in the official forums',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          }
        });
      }
    }
  }

  Future<void> saveToPrefs() async {
    await prefs.setString('lastTitle', newItemTitle.value ?? '');
  }

  Future<RssFeed> getForum() async {
    Response response = await dio
        .get('https://forum.warthunder.com/index.php?/discover/693.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    return rssFeed;
  }

  String? newItemUrl;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return NavigationView(
      appBar: NavigationAppBar(
        title: Text(
          'WTNews',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.accentColor.lighter),
        ),
        automaticallyImplyLeading: false,
      ),
      pane: NavigationPane(
        selected: index,
        displayMode: PaneDisplayMode.auto,
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
          ),
          PaneItem(
              icon: const Icon(FluentIcons.settings),
              title: const Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )),
          PaneItem(
              icon: const Icon(FluentIcons.database),
              title: const Text(
                'DataMine',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )),
          PaneItem(
              icon: const Icon(FluentIcons.news),
              title: const Text(
                'Custom Feed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: NavigationBody(
          index: index,
          children: [
            ScaffoldPage(
              padding: EdgeInsets.zero,
              content: rssFeed != null
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      child: ListView.builder(
                          itemCount: rssFeed?.items?.length,
                          itemBuilder: (context, index) {
                            newItemUrl = rssFeed?.items?.first.link;
                            newItemTitle.value = rssFeed?.items?.first.title;
                            RssItem? data = rssFeed?.items?[index];
                            String? description = data?.description;
                            if (data != null) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  HoverButton(
                                    builder: (context, set) => ListTile(
                                      title: Text(
                                        data.title ?? 'No title',
                                        style: TextStyle(
                                            color: theme.accentColor.lightest,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        description
                                                ?.replaceAll('\n', '')
                                                .replaceAll('	', '') ??
                                            '',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        style: const TextStyle(
                                            letterSpacing: 0.52, fontSize: 14),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      isThreeLine: true,
                                    ),
                                    onPressed: () {
                                      if (data.link != null) {
                                        launchUrl(Uri.parse(data.link!));
                                      }
                                    },
                                    focusEnabled: true,
                                    cursor: SystemMouseCursors.click,
                                  ),
                                  const Divider(),
                                ],
                              );
                            } else {
                              return const Center(child: Text('No Data'));
                            }
                          }))
                  : Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: ProgressRing(
                          strokeWidth: 10,
                          activeColor: theme.accentColor,
                        ),
                      ),
                    ),
            ),
            const Settings(),
            const DataMine(),
            const CustomRSSView(),
          ],
        ),
      ),
    );
  }
}
