import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:wtnews/services/utility.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../main.dart';

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
      rssFeed = await getForum();
      SharedPreferences prefs = await SharedPreferences.getInstance();
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
        await sendNotification(newTitle: newItemTitle.value);
        if (ref.watch(playSound)) {
          soundPlayer(newSound);
        }
      });
    });
  }

  String newSound = p.joinAll([
    p.dirname(Platform.resolvedExecutable),
    'data\\flutter_assets\\assets\\sound\\new.wav'
  ]);
  String logPath =
      p.joinAll([p.dirname(Platform.resolvedExecutable), 'data\\logs']);
  Future<void> loadFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    newItemTitle.value = prefs.getString('lastTitle');
  }

  Future<void> sendNotification({required String? newTitle}) async {
    if (newTitle != null) {
      if (newTitle.contains('Development')) {
        LocalNotification notification =
            LocalNotification(title: 'New DevBlog!!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Event')) {
        LocalNotification notification =
            LocalNotification(title: 'New Event!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Video')) {
        LocalNotification notification =
            LocalNotification(title: 'New Video!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('It’s fixed!')) {
        LocalNotification notification =
            LocalNotification(title: 'New It\'s Fixed!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Update') && !newTitle.contains('Dev ')) {
        LocalNotification notification =
            LocalNotification(title: 'New Update!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Dev ')) {
        LocalNotification notification =
            LocalNotification(title: 'New Dev-related news!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.toLowerCase().contains('dev server opening')) {
        LocalNotification notification =
            LocalNotification(title: 'Dev Server Opening!!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Planned Battle Rating')) {
        LocalNotification notification = LocalNotification(
            title: 'Planned Battle Rating changes!', body: newTitle);
        await localNotifier.notify(notification);
      } else if (newTitle.contains('Economic')) {
        LocalNotification notification = LocalNotification(
            title: 'There seems to be some economic stuff!', body: newTitle);
        await localNotifier.notify(notification);
      } else {
        LocalNotification notification = LocalNotification(
            title: 'New content in official forums', body: newTitle);
        await localNotifier.notify(notification);
      }
    }
  }

  Future<void> saveToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
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
          const WindowTitleBar()
        ],
      ),
    );
  }
}
