import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/settings.dart';
import 'package:wtnews/services/data/firebase.dart';
import 'package:wtnews/services/data/news.dart';
import 'package:wtnews/services/extensions.dart';
import 'package:wtnews/widgets/LinkPane.dart';
import 'package:wtnews/widgets/item_webview.dart';

import '../main.dart';
import '../providers.dart';
import '../services/data/rtdb_model.dart';
import '../services/utility.dart';

class HomeFeed extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const HomeFeed(this.prefs, {Key? key}) : super(key: key);

  @override
  HomeFeedState createState() => HomeFeedState();
}

class HomeFeedState extends ConsumerState<HomeFeed>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final List<StreamSubscription> subscriptions = [];
  late final FlutterTts tts;

  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    avoidEmptyNews();
    AppUtil.setupTTS().then((value) => tts = value);
    final prefs = ref.read(provider.prefsProvider);
    WidgetsBinding.instance.addObserver(this);
    channels.addAll(getAllChannels());
    if (channels.isNotEmpty) {
      final newsChannel = channels.first;
      subscriptions.add(newsChannel.stream.listen((event) {
        final json = jsonDecode(event);
        if (json['error'] != null) return;
        if (json is! List) {
          final news = News.fromJson(json);
          newsList.add(news);
          newsList.toSet().toList();
          newsList.sort(
            (a, b) => b.date.compareTo(a.date),
          );
          setState(() {});
          return;
        }
        final listNews = (json).map((e) => News.fromJson(e)).toList();
        newsList.addAll(listNews);
        newsList.toSet().toList();
        newsList.sort(
          (a, b) => b.date.compareTo(a.date),
        );
        setState(() {});
      }));
      final changelogChannel = channels.last;
      subscriptions.add(changelogChannel.stream.listen((event) {
        final json = jsonDecode(event);
        if (json['error'] != null) return;
        if (json is! List) {
          final news = News.fromJson(json);
          newsList.add(news);
          newsList.toSet().toList();
          newsList.sort(
            (a, b) => b.date.compareTo(a.date),
          );
          setState(() {});
          return;
        }
        final listNews = (json).map((e) => News.fromJson(e)).toList();
        newsList.addAll(listNews);
        newsList.toSet().toList();
        newsList.sort(
          (a, b) => b.date.compareTo(a.date),
        );
        setState(() {});
      }));
    }
    Future.delayed(Duration.zero, () async {
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

      if (!mounted) return;
      subscription = startListening();
      setState(() {});
      final devMessageValue = ref.watch(provider.devMessageProvider.stream);
      devMessageValue.listen((String? event) async {
        if (event != widget.prefs.getString('devMessage')) {
          final toast = LocalNotification(title: 'New Message from Vonarian')
            ..show();
          await widget.prefs.setString('devMessage', event ?? '');
          toast.onClick = () async {
            displayInfoBar(context,
                builder: (context, close) => InfoBar(
                      title: const Text('New Developer Message'),
                      content: Text(event ?? ''),
                    ),
                duration: const Duration(seconds: 10));
          };
        }
      });
      try {
        await presenceService.configureUserPresence(
            (await deviceInfo.windowsInfo).computerName,
            ref.read(provider.prefsProvider).runAtStartup,
            appVersion,
            prefs: widget.prefs);
        setState(() {});
      } catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        try {
          if (!prefs.focusedMode) {
            await sendNotification(
                newTitle: newItemTitle.value, url: newItem.link);
            if (prefs.playSound) {
              await compute(AppUtil.playSound, newSound);
            }
            if (prefs.readNewTitle) {
              await tts.speak(newItemTitle.value ?? '');
            }
            if (prefs.readNewCaption) {
              await tts.speak(newsList.first.description);
            }
          } else {
            if (newItem.dev) {
              await sendNotification(
                  newTitle: newItemTitle.value, url: newItem.link);
              if (prefs.playSound) {
                await compute(AppUtil.playSound, newSound);
              }
              if (prefs.readNewTitle) {
                await tts.speak(newItemTitle.value ?? '');
              }
              if (prefs.readNewCaption) {
                await tts.speak(newsList.first.description);
              }
            }
          }
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st);
        }
      });
    });
  }

  Future<void> avoidEmptyNews() async {
    while (newsList.isEmpty) {
      try {
        final value = await getAllNews()
            .timeout(const Duration(seconds: 5), onTimeout: () => []);
        if (value.isNotEmpty) {
          setState(() {
            newsList.addAll(value);
            newsList.toSet().toList();
          });
        }
      } on DioError catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    }
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
    for (var sub in subscriptions) {
      sub.cancel();
    }
  }

  StreamSubscription? startListening() {
    final db = PresenceService.database;
    db.goOnline();
    return db
        .reference()
        .child('notification')
        .onChildChanged
        .listen((event) async {
      log(event.snapshot.value);
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

  void loadFromPrefs() {
    newItemTitle.value = widget.prefs.getString('lastTitle');
  }

  Future<void> sendNotification(
      {required String? newTitle, required String? url}) async {
    if (newTitle != null) {
      final toast = LocalNotification(
          title: 'New item in WarThunder news', body: newTitle)
        ..show();
      toast.onClick = () async {
        if (url != null) {
          launchUrl(Uri.parse(url));
        }
      };
    }
  }

  Widget _buildCard(News item) {
    return Card(
        child: Column(
      children: [
        CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.cover,
          width: 378,
          height: 213,
        ),
        Flexible(
          child: Text(
            item.title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: item.dev ? Colors.teal : null),
            textAlign: TextAlign.left,
          ),
        ),
        Flexible(
          fit: FlexFit.tight,
          child: Text(
            item.description,
            overflow: TextOverflow.fade,
            style: TextStyle(
              letterSpacing: 0.50,
              fontSize: 14,
              color: HexColor.fromHex('#8da0aa'),
            ),
            maxLines: 3,
            textAlign: TextAlign.left,
          ),
        ),
      ],
    ));
  }

  Widget _buildGradient(Widget widget, {required News item}) {
    return Stack(children: [
      Positioned.fill(child: widget),
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            colors: [
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.4],
            begin: Alignment.bottomCenter,
            end: Alignment.center,
          )),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  item.dateString,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: HexColor.fromHex('#8da0aa'),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
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

  Tab generateTab(News item) {
    late Tab tab;
    tab = Tab(
      text: Text(item.title),
      icon: const Icon(FluentIcons.site_scan),
      body: ItemWebView(url: item.link),
      onClosed: () {
        setState(() {
          tabs.remove(tab);
          if (tabIndex > 0) tabIndex--;
        });
      },
    );
    return tab;
  }

  List<WebSocketChannel> getAllChannels() {
    final newsChannel = News.connectNews();
    final changelogChannel = News.connectChangelog();
    return [newsChannel, changelogChannel];
  }

  final List<WebSocketChannel> channels = [];

  Future<void> saveToPrefs() async {
    await widget.prefs.setString('lastTitle', newItemTitle.value ?? '');
  }

  final List<News> newsList = [];
  StreamSubscription? subscription;
  late News newItem;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);
  int index = 0;
  int tabIndex = 0;

  final List<Tab> tabs = [];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final firebaseValue = ref.watch(provider.versionFBProvider);
    final preferences = ref.watch(provider.prefsProvider);
    return Column(
      children: [
        SizedBox(
          height: kWindowCaptionHeight,
          child: WindowCaption(
            title: Text(
              'WTNews v$appVersion',
              textAlign: TextAlign.left,
            ),
            brightness: theme.brightness,
            backgroundColor: theme.scaffoldBackgroundColor,
          ),
        ),
        Expanded(
          child: NavigationView(
            pane: NavigationPane(
                selected: index,
                displayMode: preferences.paneDisplayMode,
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
                    body: TabView(
                        shortcutsEnabled: true,
                        onChanged: (index) => setState(() => tabIndex = index),
                        closeButtonVisibility:
                            CloseButtonVisibilityMode.onHover,
                        currentIndex: tabIndex,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final item = tabs.removeAt(oldIndex);
                          tabs.insert(newIndex, item);
                          if (tabIndex == newIndex) {
                            tabIndex = oldIndex;
                          } else if (tabIndex == oldIndex) {
                            tabIndex = newIndex;
                          }
                          setState(() {});
                        },
                        tabs: [
                          Tab(
                              text: const Text('News'),
                              closeIcon: null,
                              body: ScaffoldPage(
                                padding: EdgeInsets.zero,
                                content: newsList.isNotEmpty
                                    ? AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 700),
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          final width = constraints.maxWidth;
                                          final height = constraints.maxHeight;
                                          int crossAxisCount = 2;
                                          if (width / height >= 1.5 &&
                                              width >= 600) {
                                            crossAxisCount = 3;
                                          }
                                          if ((width / height >= 2 ||
                                                  width >= 1300) &&
                                              width >= 1200) {
                                            crossAxisCount = 4;
                                          }
                                          return GridView.builder(
                                              padding: EdgeInsets.zero,
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                              ),
                                              itemCount: newsList.length,
                                              itemBuilder: (context, index) {
                                                final item = newsList[index];
                                                newItem = newsList.first;
                                                newItemTitle.value =
                                                    newsList.first.title;
                                                return HoverButton(
                                                  builder: (context, set) =>
                                                      Container(
                                                    color: set.isHovering
                                                        ? Colors.grey[200]
                                                        : null,
                                                    child: ContextMenuArea(
                                                      verticalPadding: 0,
                                                      builder: (context) {
                                                        return <Widget>[
                                                          ListTile(
                                                            leading: const Icon(
                                                                FluentIcons
                                                                    .open_in_new_tab),
                                                            title: const Text(
                                                                'Open in new tab'),
                                                            onPressed: () {
                                                              final tab =
                                                                  generateTab(
                                                                      item);
                                                              tabs.add(tab);
                                                              tabIndex =
                                                                  tabs.length;
                                                              setState(() {});
                                                            },
                                                            tileColor: ButtonState
                                                                .resolveWith<
                                                                        Color>(
                                                                    (states) {
                                                              late final Color
                                                                  color;
                                                              if (states
                                                                  .isHovering) {
                                                                color = theme
                                                                    .accentColor
                                                                    .withOpacity(
                                                                        0.31);
                                                              } else {
                                                                color = theme
                                                                    .scaffoldBackgroundColor;
                                                              }
                                                              return color;
                                                            }),
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                                FluentIcons
                                                                    .open_in_new_window),
                                                            title: const Text(
                                                                'Launch in browser'),
                                                            onPressed: () {
                                                              launchUrlString(
                                                                  item.link);
                                                            },
                                                            tileColor: ButtonState
                                                                .resolveWith<
                                                                        Color>(
                                                                    (states) {
                                                              late final Color
                                                                  color;
                                                              if (states
                                                                  .isHovering) {
                                                                color = theme
                                                                    .accentColor
                                                                    .withOpacity(
                                                                        0.31);
                                                              } else {
                                                                color = theme
                                                                    .scaffoldBackgroundColor;
                                                              }
                                                              return color;
                                                            }),
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                                FluentIcons
                                                                    .clipboard_list_add),
                                                            title: const Text(
                                                                'Copy Link'),
                                                            onPressed:
                                                                () async {
                                                              await Clipboard.setData(
                                                                  ClipboardData(
                                                                      text: item
                                                                          .link));
                                                              if (!mounted) {
                                                                return;
                                                              }
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                            },
                                                            tileColor: ButtonState
                                                                .resolveWith<
                                                                        Color>(
                                                                    (states) {
                                                              late final Color
                                                                  color;
                                                              if (states
                                                                  .isHovering) {
                                                                color = theme
                                                                    .accentColor
                                                                    .withOpacity(
                                                                        0.31);
                                                              } else {
                                                                color = theme
                                                                    .scaffoldBackgroundColor;
                                                              }
                                                              return color;
                                                            }),
                                                          ),
                                                        ];
                                                      },
                                                      child: _buildGradient(
                                                          _buildCard(item),
                                                          item: item),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    if (preferences
                                                        .openInsideApp) {
                                                      final tab =
                                                          generateTab(item);
                                                      tabs.add(tab);
                                                      tabIndex = tabs.length;
                                                      setState(() {});
                                                    } else {
                                                      launchUrlString(
                                                          item.link);
                                                    }
                                                  },
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                );
                                              });
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
                              icon: const Icon(FluentIcons.news)),
                          ...tabs
                        ]),
                  ),
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
                        final version = int.parse(data.replaceAll('.', ''));
                        final currentVersion =
                            int.parse(appVersion.replaceAll('.', ''));
                        if (version > currentVersion) {
                          return const InfoBadge(source: Text('!'));
                        } else {
                          return null;
                        }
                      },
                      loading: () => null,
                      error: (error, st) => null,
                    ),
                    body: Settings(widget.prefs),
                  ),
                  LinkPaneItemAction(
                    icon: const Icon(FluentIcons.info),
                    link: 'https://github.com/Vonarian/wtnews/',
                    body: const Placeholder(),
                    title: const Text('About'),
                  ),
                ]),
          ),
        ),
      ],
    );
  }
}
