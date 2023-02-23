import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:dio/dio.dart';
import 'package:firebase_dart/database.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/custom_feed.dart';
import 'package:wtnews/pages/settings.dart';
import 'package:wtnews/services/data/firebase.dart';
import 'package:wtnews/services/data/news.dart';
import 'package:wtnews/services/extensions.dart';

import '../main.dart';
import '../services/data/rtdb_model.dart';
import '../services/utility.dart';
import 'downloader.dart';

class RSSView extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const RSSView(this.prefs, {Key? key}) : super(key: key);

  @override
  RSSViewState createState() => RSSViewState();
}

class RSSViewState extends ConsumerState<RSSView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final List<StreamSubscription> subscriptions = [];

  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    getAllNews().then((value) {
      setState(() {
        newsList.addAll(value);
        newsList.toSet().toList();
      });
    });
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
        final listNews =
            (jsonDecode(event) as List).map((e) => News.fromJson(e)).toList();
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
        final listNews =
            (jsonDecode(event) as List).map((e) => News.fromJson(e)).toList();
        newsList.addAll(listNews);
        newsList.toSet().toList();
        newsList.sort(
          (a, b) => b.date.compareTo(a.date),
        );
        setState(() {});
      }));
    }
    Future.delayed(Duration.zero, () async {
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
            windowManager.show();
          };
        }
      });
      try {
        await presenceService.configureUserPresence(
            (await deviceInfo.windowsInfo).computerName,
            widget.prefs.getBool('startup') ?? false,
            appVersion,
            prefs: widget.prefs);
        setState(() {});
      } catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) timer.cancel();
      rssFeed = await getForum();
      final item = rssFeed?.items?.firstWhere((element) =>
          element.title!.toLowerCase().contains('technical') ||
          element.title!.toLowerCase().contains('opening') ||
          element.title!.toLowerCase().contains('planned'));
      newRssUrl = item?.link;
      if (item?.title != null &&
          item?.title != newRssTitle.value &&
          newRssTitle.value !=
              ref.read(provider.prefsProvider).getString('rssTitle')) {
        newRssTitle.value = item?.title;
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        try {
          if (!ref.read(provider.focusedProvider)) {
            await sendNotification(
                newTitle: newItemTitle.value, url: newItem.link);
            if (ref.read(provider.playSound)) AppUtil.playSound(newSound);
          } else {
            if (newItem.isNews && newItem.dev) {
              await sendNotification(
                  newTitle: newItemTitle.value, url: newItem.link);
              if (ref.read(provider.playSound)) AppUtil.playSound(newSound);
            }
          }
        } catch (e, st) {
          await Sentry.captureException(e, stackTrace: st);
        }
      });
      newRssTitle.addListener(() async {
        try {
          await ref
              .read(provider.prefsProvider)
              .setString('rssTitle', newRssTitle.value!);
          await sendNotification(newTitle: newRssTitle.value, url: newRssUrl);
          if (ref.read(provider.playSound)) AppUtil.playSound(newSound);
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
            if (message.operation != null) {
              switch (message.operation) {
                case 'getUserName':
                  if (!mounted) return;
                  await Message.getUserName(context, data, ref);
                  break;
                case 'getFeedback':
                  if (!mounted) return;
                  Message.getFeedback(context, data, mounted,
                      prefs: widget.prefs);
                  break;
              }
            }
            await widget.prefs.setInt('id', message.id);
          }
        }
      }
    });
  }

  void loadFromPrefs() {
    newItemTitle.value = widget.prefs.getString('lastTitle');
    newRssTitle.value = widget.prefs.getString('rssTitle');
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

  List<WebSocketChannel> getAllChannels() {
    final newsChannel = News.connectNews();
    final changelogChannel = News.connectChangelog();
    return [newsChannel, changelogChannel];
  }

  final List<WebSocketChannel> channels = [];

  Future<void> saveToPrefs() async {
    await widget.prefs.setString('lastTitle', newItemTitle.value ?? '');
  }

  Future<RssFeed> getForum() async {
    Response response = await dio
        .get('https://forum.warthunder.com/index.php?/discover/693.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    return rssFeed;
  }

  RssFeed? rssFeed;
  final List<News> newsList = [];
  StreamSubscription? subscription;
  late News newItem;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);
  String? newRssUrl;
  ValueNotifier<String?> newRssTitle = ValueNotifier(null);
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final devMessageValue = ref.watch(provider.devMessageProvider);
    final firebaseValue = ref.watch(provider.versionFBProvider);
    return NavigationView(
      appBar: NavigationAppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 7.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WTNews v$appVersion ${ref.watch(provider.premiumProvider) ? '(Premium!)' : ''}',
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor.lighter),
              ),
              devMessageValue.when(
                data: (data) => Text(
                  data != null ? 'Vonarian\'s Message: $data' : '',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                loading: () => const SizedBox(),
                error: (error, st) => const SizedBox(),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
        actions: firebaseValue.when(
          data: (data) {
            final version = int.parse(data.replaceAll('.', ''));
            final currentVersion = int.parse(appVersion.replaceAll('.', ''));
            if (version > currentVersion) {
              return IconButton(
                icon: const Icon(FluentIcons.download),
                onPressed: () async {
                  Navigator.of(context)
                      .pushReplacement(FluentPageRoute(builder: (context) {
                    return const Downloader();
                  }));
                },
              );
            } else {
              return const SizedBox();
            }
          },
          loading: () => const SizedBox(),
          error: (error, st) => const SizedBox(),
        ),
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
            body: ScaffoldPage(
              padding: EdgeInsets.zero,
              content: newsList.isNotEmpty
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        int crossAxisCount = 2;
                        if (width / height >= 1.5 && width >= 600) {
                          crossAxisCount = 3;
                        }
                        if ((width / height >= 2 || width >= 1300) &&
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
                              newItemTitle.value = newsList.first.title;
                              return HoverButton(
                                builder: (context, set) => Container(
                                  color:
                                      set.isHovering ? Colors.grey[200] : null,
                                  child: ContextMenuArea(
                                    verticalPadding: 0,
                                    builder: (context) {
                                      return <Widget>[
                                        ListTile(
                                          title: const Text('Copy Link'),
                                          onPressed: () async {
                                            await Clipboard.setData(
                                                ClipboardData(text: item.link));
                                            if (!mounted) return;
                                            Navigator.of(context).pop();
                                          },
                                          tileColor:
                                              ButtonState.resolveWith<Color>(
                                                  (states) {
                                            late final Color color;
                                            if (states.isHovering) {
                                              color = theme.accentColor
                                                  .withOpacity(0.31);
                                            } else {
                                              color =
                                                  theme.scaffoldBackgroundColor;
                                            }
                                            return color;
                                          }),
                                        ),
                                      ];
                                    },
                                    child: _buildGradient(_buildCard(item),
                                        item: item),
                                  ),
                                ),
                                onPressed: () {
                                  launchUrl(Uri.parse(item.link));
                                },
                                cursor: SystemMouseCursors.click,
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
          ),
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
          PaneItem(
              icon: const Icon(FluentIcons.news),
              title: const Text(
                'Custom Feed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              body: CustomRSSView(widget.prefs)),
        ],
      ),
    );
  }
}
