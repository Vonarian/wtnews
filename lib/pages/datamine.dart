import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';

import '../main.dart';
import '../services/utility.dart';

class DataMine extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const DataMine(this.prefs, {Key? key}) : super(key: key);

  @override
  DataMineState createState() => DataMineState();
}

class DataMineState extends ConsumerState<DataMine> {
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(provider.checkDataMine.notifier).state =
          widget.prefs.getBool('checkDataMine') ?? false;
    });
    lastPubDate.addListener(() async {
      await notify(lastPubDate.value!, newItemUrl!);
      await widget.prefs.setString('previous', lastPubDate.value!);
    });
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) timer.cancel();
      if (ref.watch(provider.checkDataMine)) {
        ref.refresh(provider.dataMineFutureProvider);
      }
    });
  }

  Future<void> notify(String pubDate, String url) async {
    if (widget.prefs.getString('previous') != null) {
      if (widget.prefs.getString('previous') != pubDate) {
        String? previous = widget.prefs.getString('previous');
        if (kDebugMode) {
          print('isNew');
          print(previous);
          print(pubDate);
        }

        AppUtil.playSound(newSound);
        final toast = await winToast.showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'Click to launch in browser',
        );
        toast?.eventStream.listen((event) {
          if (event is ActivatedEvent) {
            launchUrl(Uri.parse(url));
          }
        });
      }
    } else {
      if (kDebugMode) {
        print('Null');
      }
      AppUtil.playSound(newSound);
      final toast = await winToast.showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'New Data Mine from gszabi');
      toast?.eventStream.listen((event) {
        if (event is ActivatedEvent) {
          launchUrl(Uri.parse(url));
        }
      });
    }
  }

  String? newItemUrl;
  ValueNotifier<String?> lastPubDate = ValueNotifier(null);
  RssFeed? rssFeed;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    final rssValue = ref.watch(provider.dataMineFutureProvider);
    return ScaffoldPage(
        padding: EdgeInsets.zero,
        content: rssValue.when(
          data: (value) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: ListView.builder(
                  itemCount: value.items?.length,
                  itemBuilder: (context, index) {
                    newItemUrl = value.items?.first.link;
                    lastPubDate.value = value.items?.first.pubDate.toString();
                    RssItem? data = value.items?[index];
                    String? description = data?.description;
                    rssFeed = value;
                    if (data != null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          HoverButton(
                            builder: (context, set) => ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    data.title ?? '',
                                    style: TextStyle(
                                        color: theme.accentColor.light,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    ' 📰By gszabi99_HUN📰',
                                    style: TextStyle(
                                        color: theme.accentColor.lightest,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
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
                  })),
          loading: () {
            if (rssFeed == null) {
              return Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: ProgressRing(
                    strokeWidth: 10,
                    activeColor: theme.accentColor,
                  ),
                ),
              );
            } else {
              return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: ListView.builder(
                      itemCount: rssFeed!.items?.length,
                      itemBuilder: (context, index) {
                        RssItem? data = rssFeed!.items?[index];
                        String? description = data?.description;
                        if (data != null) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              HoverButton(
                                builder: (context, set) => ListTile(
                                  title: Row(
                                    children: [
                                      Text(
                                        data.title ?? '',
                                        style: TextStyle(
                                            color: theme.accentColor.light,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        ' 📰By gszabi99_HUN📰',
                                        style: TextStyle(
                                            color: theme.accentColor.lightest,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
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
                      }));
            }
          },
          error: (e, st) {
            return const Center(
              child: Text('Error'),
            );
          },
        ));
  }
}
