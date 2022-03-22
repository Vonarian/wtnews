import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_dart/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:wtnews/services/presence.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../main.dart';
import '../services/data_class.dart';
import '../services/utility.dart';

class RSSView extends ConsumerStatefulWidget {
  const RSSView({Key? key}) : super(key: key);

  @override
  _RSSViewState createState() => _RSSViewState();
}

class _RSSViewState extends ConsumerState<RSSView> with WidgetsBindingObserver {
  RssFeed? rssFeed;
  StreamSubscription? subscription;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    WidgetsBinding.instance?.addObserver(this);
    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      subscription = startListening();
      try {
        await PresenceService().configureUserPresence(
            (await deviceInfo.windowsInfo).computerName,
            prefs.getBool('startup') ?? false,
            File(pathToVersion).readAsStringSync());
        rssFeed = await getForum();
        ref.read(playSound.notifier).state = prefs.getBool('playSound') ?? true;
      } catch (e, st) {
        await Sentry.captureException(e, stackTrace: st);
      }
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;
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
          if (ref.watch(playSound)) AppUtil().soundPlayer(newSound);
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
    WidgetsBinding.instance?.removeObserver(this);
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
            var toast = await WinToast.instance().showToast(
                type: ToastType.text04,
                title: message.title,
                subtitle: message.subtitle);
            toast?.eventStream.listen((event) async {
              if (event is ActivatedEvent) {
                if (message.url != null) {
                  await launch(message.url!);
                }
              }
            });
            if (message.operation != null) {
              switch (message.operation) {
                case 'restart':
                  await Future.delayed(const Duration(seconds: 50));
                  Message.restart(context);
                  break;
                case 'getUserName':
                  await Message.getUserName(context);
                  await PresenceService().configureUserPresence(
                      (await deviceInfo.windowsInfo).computerName,
                      prefs.getBool('startup') ?? false,
                      await File(pathToVersion).readAsString());
                  break;
                case 'getFeedback':
                  Message.getFeedback(context);
                  break;
              }
            }
            await prefs.setInt('id', message.id);
          }
        }
      }
    });
  }

  String newSound = p.joinAll([
    p.dirname(Platform.resolvedExecutable),
    'data\\flutter_assets\\assets\\sound\\new.wav'
  ]);
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
      {required String? newTitle, required String url}) async {
    if (newTitle != null) {
      if (newTitle.contains('Development')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New DevBlog!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Event')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Event!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Video')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Video!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('It’s fixed!')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New It\'s fixed!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Update') && !newTitle.contains('Dev ')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Update!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Dev ')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New Dev related content!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.toLowerCase().contains('dev server opening')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Dev Server Opening!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Planned Battle Rating')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Planned BR changes!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else if (newTitle.contains('Economic')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Something new about economics!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
            }
          }
        });
      } else {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New content in the official forums',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            if (url != '') {
              await launch(url);
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
    try {
      Dio dio = Dio();
      Response response = await dio
          .get('https://forum.warthunder.com/index.php?/discover/693.xml');
      RssFeed rssFeed = RssFeed.parse(response.data);
      return rssFeed;
    } catch (e, st) {
      log('ERROR: $e', stackTrace: st);
      rethrow;
    }
  }

  String newItemUrl = '';
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ImageFiltered(
              child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.black,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black87,
                    Colors.black,
                    Colors.black,
                    Colors.black,
                  ],
                )),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0)),
          rssFeed != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 45, 0, 0),
                  child: ListView.builder(
                      itemCount: rssFeed?.items?.length,
                      itemBuilder: (context, index) {
                        newItemTitle.value = rssFeed?.items?.first.title;
                        newItemUrl = rssFeed?.items?.first.link ?? '';
                        RssItem? data = rssFeed?.items![index];
                        String? description = data?.description;
                        if (data != null) {
                          Color color = data.title!.contains('Development')
                              ? Colors.red
                              : data.title!.contains('Event')
                                  ? Colors.blue
                                  : data.title!.contains('Video')
                                      ? Colors.amber
                                      : data.title!.contains('It’s fixed!')
                                          ? Colors.deepPurpleAccent
                                          : data.title!.contains('Update') &&
                                                  !data.title!.contains('Dev ')
                                              ? Colors.cyanAccent
                                              : data.title!
                                                      .contains('Dev Server')
                                                  ? Colors.redAccent
                                                  : Colors.teal;
                          return ListTile(
                            title: Text(
                              data.title ?? 'No title',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              description
                                      ?.replaceAll('\n', '')
                                      .replaceAll('	', '') ??
                                  '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            onTap: () async {
                              await launch(
                                  data.link ?? 'https://Forum.Warthunder.com');
                            },
                          );
                        } else {
                          return const Center(child: Text('No Data'));
                        }
                      }),
                )
              : const Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                    ),
                  ),
                ),
          const WindowTitleBar(
            isCustom: false,
          )
        ],
      ),
    );
  }
}
