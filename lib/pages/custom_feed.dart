import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';

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

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      await loadFromPrefs();

      if (ref.read(provider.customFeed) == null) {
        await dialog();
      }
      ref
          .read(provider.playSound.notifier)
          .state = prefs.getBool('playSound') ?? true;
      rssFeed = await getForum(ref.watch(provider.customFeed) ?? '');


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
          AppUtil.playSound(newSound);
        }
      });
    });
  }

  String newSound = p.joinAll([
    p.dirname(Platform.resolvedExecutable),
    'data\\flutter_assets\\assets\\sound\\new.wav'
  ]);

  Future<void> loadFromPrefs() async {
    ref
        .read(provider.customFeed.notifier)
        .state =
        prefs.getString('customFeed');
    newItemTitle.value = prefs.getString('lastTitleCustom');
  }

  Future<void> sendNotification(
      {required String? newTitle, required String url}) async {
    if (newTitle != null) {
      var toast = await winToast.showToast(
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

  Future<void> dialog() async {
    TextEditingController controller = TextEditingController();
    await showDialog(
        context: context,
        builder: (context) {
          return ContentDialog(
            title: const Text('Enter RSS Feed URL'),
            content: TextFormBox(
              validator: (value) {
                if (value != null) {
                  return 'Username can\'t be empty';
                }
                if (value!.isEmpty) {
                  return 'Username can\'t be empty';
                }
                return null;
              },
              controller: controller,
              onFieldSubmitted: (value) async {
                ref
                    .read(provider.customFeed.notifier)
                    .state = value;
                await prefs.setString('customFeed', value);
                if (!mounted) return;
                Navigator.of(context).pop();
                rssFeed = await getForum(value);
              },
            ),
            actions: [
              Button(
                child: const Text('Save'),
                onPressed: () async {
                  ref
                      .read(provider.customFeed.notifier)
                      .state =
                      controller.text;
                  await prefs.setString('customFeed', controller.text);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
              ),
              Button(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<void> saveToPrefs() async {
    await prefs.setString('lastTitleCustom', newItemTitle.value ?? '');
  }

  Future<RssFeed> getForum(String url) async {
    try {
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
    var theme = FluentTheme.of(context);
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      header: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          HoverButton(
            builder: (context, set) =>
                Text('Change feed URL',
                    style: TextStyle(fontSize: 18, color: Colors.red)),
            onPressed: () async {
              await dialog();
              setState(() {});
            },
          ),
        ],
      ),
      content: rssFeed != null
          ? ListView.builder(
          itemCount: rssFeed?.items?.length,
          itemBuilder: (context, index) {
            newItemTitle.value = rssFeed?.items?.first.title;
            newItemUrl = rssFeed?.items?.first.link ?? '';
            RssItem? data = rssFeed?.items?[index];
            String? description = data?.description;
            if (data != null) {
              return HoverButton(
                builder: (context, set) =>
                    ListTile(
                      title: Text(
                        data.title ?? 'No title',
                        style: TextStyle(
                            color: theme.accentColor.lightest,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        description?.replaceAll('\n', '').replaceAll(
                            '	', '') ??
                            '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style:
                        const TextStyle(letterSpacing: 0.52, fontSize: 14),
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
              );
            } else {
              return const Center(child: Text('No Data'));
            }
          })
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
    );
  }
}
