import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:wtnews/widgets/titlebar.dart';

import '../main.dart';
import '../services/utility.dart';

class CustomRSSView extends ConsumerStatefulWidget {
  const CustomRSSView({Key? key}) : super(key: key);

  @override
  CustomRSSViewState createState() => CustomRSSViewState();
}

class CustomRSSViewState extends ConsumerState<CustomRSSView> {
  RssFeed? rssFeed;

  @override
  void initState() {
    super.initState();
    loadFromPrefs();

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      rssFeed = await getForum(ref.watch(provider.customFeed) ?? '');
      ref.read(provider.playSound.notifier).state =
          prefs.getBool('playSound') ?? true;
      setState(() {});
    });
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) timer.cancel();
      rssFeed = await getForum(ref.read(provider.customFeed) ?? '');
      setState(() {});
    });

    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        await sendNotification(newTitle: newItemTitle.value, url: newItemUrl);
        if (ref.read(provider.playSound)) {
          AppUtil().playSound(newSound);
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
    newItemTitle.value = prefs.getString('lastTitleCustom');
  }

  Future<void> sendNotification(
      {required String? newTitle, required String url}) async {
    if (newTitle != null) {
      var toast = await WinToast.instance().showToast(
          type: ToastType.text04,
          title: 'New content in the feed',
          subtitle: newTitle);
      toast?.eventStream.listen((event) async {
        if (event is ActivatedEvent) {
          await launchUrl(Uri.parse(url));
        }
      });
    }
  }

  Future<void> saveToPrefs() async {
    await prefs.setString('lastTitleCustom', newItemTitle.value ?? '');
  }

  Future<RssFeed> getForum(String url) async {
    try {
      Dio dio = Dio();
      Response response = await dio.get(url);
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
    return Material(
      child: Stack(children: [
        Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          backgroundColor: Colors.transparent,
          body: rssFeed != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                  child: ListView.builder(
                      itemCount: rssFeed?.items?.length,
                      itemBuilder: (context, index) {
                        newItemTitle.value = rssFeed?.items?.first.title;
                        newItemUrl = rssFeed?.items?.first.link ?? '';
                        RssItem? data = rssFeed?.items?[index];
                        String? description = data?.description;
                        if (data != null) {
                          Color color = Colors.red;
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
                              await launchUrl(Uri.parse(
                                  data.link ?? 'https://Forum.Warthunder.com'));
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
        ),
        const WindowTitleBar(
          isCustom: true,
        )
      ]),
    );
  }
}
