import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../main.dart';

class RSSView extends StatefulWidget {
  final RssFeed? rssFeed;
  const RSSView({Key? key, this.rssFeed}) : super(key: key);

  @override
  State<RSSView> createState() => _RSSViewState();
}

class _RSSViewState extends State<RSSView> {
  RssFeed? rssFeed;

  @override
  void initState() {
    super.initState();
    loadFromPrefs();
    if (widget.rssFeed != null) {
      rssFeed = widget.rssFeed!;
    }
    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      rssFeed = await getForum();
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;

      rssFeed = await getForum();
      setState(() {});
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        await sendNotification(newTitle: newItemTitle.value);
      });
    });
  }

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
      }
      if (newTitle.contains('Event')) {
        LocalNotification notification =
            LocalNotification(title: 'New Event!', body: newTitle);
        await localNotifier.notify(notification);
      }
      if (newTitle.contains('Video')) {
        LocalNotification notification =
            LocalNotification(title: 'New Video!', body: newTitle);
        await localNotifier.notify(notification);
      }
      if (newTitle.contains('It’s fixed!')) {
        LocalNotification notification =
            LocalNotification(title: 'New It\'s Fixed!', body: newTitle);
        await localNotifier.notify(notification);
      }
      if (newTitle.contains('Update') && !newTitle.contains('Dev ')) {
        LocalNotification notification =
            LocalNotification(title: 'New Update!', body: newTitle);
        await localNotifier.notify(notification);
      }
      if (newTitle.contains('Dev ')) {
        LocalNotification notification =
            LocalNotification(title: 'New Dev-related news!', body: newTitle);
        await localNotifier.notify(notification);
      }
      if (newTitle.toLowerCase().contains('dev server opening')) {
        LocalNotification notification =
            LocalNotification(title: 'Dev Server Opening!!', body: newTitle);
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
              child: Image.asset(
                'assets/bg.png',
                fit: BoxFit.cover,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0)),
          rssFeed != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
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
                              style: const TextStyle(color: Colors.white),
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
                    width: 150,
                    height: 150,
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
