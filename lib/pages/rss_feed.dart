import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:firebase_dart/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:wtnews/services/utility.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../main.dart';
import '../services/data_class.dart';

class RSSView extends ConsumerStatefulWidget {
  const RSSView({Key? key}) : super(key: key);

  @override
  _RSSViewState createState() => _RSSViewState();
}

class _RSSViewState extends ConsumerState<RSSView> {
  RssFeed? rssFeed;

  @override
  void initState() {
    super.initState();
    loadFromPrefs();

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      startListening();
      rssFeed = await getForum();
      ref.read(playSound.notifier).state = prefs.getBool('playSound') ?? true;
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;

      try {
        rssFeed = await getForum();
        setState(() {});
      } catch (e, st) {
        await AppUtil.logAndSaveToText('$logPath\\rss_feed.txt', e.toString(),
            st.toString(), 'RSS_Feed Timer');
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        await sendNotification(newTitle: newItemTitle.value, url: newItemUrl);
        if (ref.watch(playSound)) {
          soundPlayer(newSound);
        }
      });
    });
  }

  void startListening() {
    DatabaseReference ref = FirebaseDatabase(
            app: app,
            databaseURL:
                'https://wtnews-54364-default-rtdb.europe-west1.firebasedatabase.app')
        .reference();
    ref.onValue.listen((event) async {
      final data = event.snapshot.value;
      if (data != null &&
          data['title'] != null &&
          data['subtitle'] != null &&
          data['id'] != null &&
          data['title'] != '' &&
          data['subtitle'] != '') {
        Message message = Message.fromMap(data);
        if (prefs.getInt('id') != message.id) {
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
          await prefs.setInt('id', message.id);
        }
      }
    });
  }

  String newSound = p.joinAll([
    p.dirname(Platform.resolvedExecutable),
    'data\\flutter_assets\\assets\\sound\\new.wav'
  ]);
  String logPath =
      p.joinAll([p.dirname(Platform.resolvedExecutable), 'data\\logs']);
  Future<void> loadFromPrefs() async {
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
            await launch(url);
          }
        });
      } else if (newTitle.contains('Event')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Event!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('Video')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Video!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('It’s fixed!')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New It\'s fixed!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('Update') && !newTitle.contains('Dev ')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04, title: 'New Update!!', subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('Dev ')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New Dev related content!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.toLowerCase().contains('dev server opening')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Dev Server Opening!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('Planned Battle Rating')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Planned BR changes!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else if (newTitle.contains('Economic')) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Something new about economics!!',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
          }
        });
      } else {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'New content in the official forums',
            subtitle: newTitle);
        toast?.eventStream.listen((event) async {
          if (event is ActivatedEvent) {
            await launch(url);
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
                    Colors.black,
                    Colors.black,
                    Colors.black,
                  ],
                )),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0)),
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
