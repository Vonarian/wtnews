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
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wtnews/widgets/gradient_widget.dart';

import '../main.dart';
import '../providers.dart';
import '../services/data/news.dart';
import '../services/extensions.dart';
import '../services/utility.dart';
import 'item_webview.dart';

class NewsView extends ConsumerStatefulWidget {
  const NewsView({
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState createState() => _NewsViewState();
}

class _NewsViewState extends ConsumerState<NewsView>
    with AutomaticKeepAliveClientMixin {
  late final FlutterTts tts;
  final List<WebSocketChannel> channels = [];

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

  void loadFromPrefs() {
    newItemTitle.value = prefs.getString('lastTitle');
  }

  Future<void> sendNotification(
      {required String? newTitle, required String? url}) async {
    if (newTitle != null) {
      final toast = LocalNotification(
          title: 'New item in WarThunder news', body: newTitle)
        ..show();
      toast.onClick = () async {
        if (url != null) {
          launchUrlString(url);
        }
      };
    }
  }

  final _searchHotKey = HotKey(
    KeyCode.keyF,
    scope: HotKeyScope.inapp,
    modifiers: [KeyModifier.control],
  );

  @override
  void initState() {
    super.initState();
    avoidEmptyNews();
    loadFromPrefs();
    registerHotkeys([_searchHotKey]);
    boxFocus.onKeyEvent = (node, kE) {
      if (kE.logicalKey == LogicalKeyboardKey.enter) {
        node.unfocus();
        return KeyEventResult.handled;
      }
      if (kE.logicalKey == LogicalKeyboardKey.escape) {
        showSearch = false;
        searchList.clear();
        setState(() {});
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    final appPrefs = ref.read(provider.prefsProvider);
    AppUtil.setupTTS().then((value) => tts = value);
    channels.addAll(getAllChannels());
    if (channels.isNotEmpty) {
      Future.delayed(Duration.zero, () async {
        final newsChannel = channels.first;
        newsChannel.ready.then((_) {
          newsChannel.stream.listen((event) {
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
          });
        });
        final changelogChannel = channels.last;
        changelogChannel.ready.then((_) {
          changelogChannel.stream.listen((event) {
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
          });
        });
      });
    }
    Future.delayed(const Duration(seconds: 10), () {
      newItemTitle.addListener(() async {
        saveToPrefs();
        try {
          if (!appPrefs.focusedMode) {
            await sendNotification(
                newTitle: newItemTitle.value, url: newItem.link);
            if (appPrefs.playSound) {
              await compute(AppUtil.playSound, newSound);
            }
            if (appPrefs.readNewTitle) {
              await tts.speak(newItemTitle.value ?? '');
            }
            if (appPrefs.readNewCaption) {
              await tts.speak(newsList.first.description);
            }
          } else {
            if (newItem.dev) {
              await sendNotification(
                  newTitle: newItemTitle.value, url: newItem.link);
              if (appPrefs.playSound) {
                await compute(AppUtil.playSound, newSound);
              }
              if (appPrefs.readNewTitle) {
                await tts.speak(newItemTitle.value ?? '');
              }
              if (appPrefs.readNewCaption) {
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

  Future<void> registerHotkeys(List<HotKey> hotkeys) async {
    await hotKeyManager.unregisterAll();
    for (final hotKey in hotkeys) {
      if (hotKey.keyCode == KeyCode.keyF) {
        await hotKeyManager.register(hotKey, keyDownHandler: (_) {
          if (!showSearch) {
            showSearch = true;
            boxFocus.requestFocus();
          } else {
            showSearch = false;
            boxFocus.unfocus();
          }
          setState(() {});
        });
      } else {
        await hotKeyManager.register(hotKey);
      }
    }
  }

  @override
  void dispose() {
    for (var ch in channels) {
      ch.sink.close();
    }
    boxFocus.dispose();
    super.dispose();
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

  List<WebSocketChannel> getAllChannels() {
    final newsChannel = News.connectNews();
    final changelogChannel = News.connectChangelog();
    return [newsChannel, changelogChannel];
  }

  Future<void> saveToPrefs() async {
    await prefs.setString('lastTitle', newItemTitle.value ?? '');
  }

  final List<News> newsList = [];
  final List<News> searchList = [];
  late News newItem;
  ValueNotifier<String?> newItemTitle = ValueNotifier(null);

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

  void _handleSearch(String v) {
    searchList.clear();
    bool hasMatch = false;
    for (final item in newsList) {
      if (item.title.toLowerCase().contains(v.toLowerCase())) {
        hasMatch = true;
        setState(() {
          searchList.add(item);
        });
      }
    }
    if (!hasMatch) {
      searchList.clear();
    }
  }

  final List<Tab> tabs = [];
  int tabIndex = 0;
  final boxFocus = FocusNode();
  bool showSearch = false;

  Widget searchBox() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Text('Search: '),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: 32,
              width: 400,
              child: TextBox(
                focusNode: boxFocus,
                onChanged: _handleSearch,
                onSubmitted: (_) {
                  showSearch = false;
                  setState(() {});
                },
                prefix: IconButton(
                    icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: searchList.isNotEmpty
                            ? const Icon(FluentIcons.search)
                            : const Icon(FluentIcons.cancel)),
                    onPressed: () {
                      showSearch = false;
                      setState(() {});
                    }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appPrefs = ref.watch(provider.prefsProvider);
    final theme = FluentTheme.of(context);
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showSearch ? searchBox() : null,
        ),
        Expanded(
          child: TabView(
              addIconData:
                  !showSearch ? FluentIcons.search : FluentIcons.cancel,
              onNewPressed: () {
                if (showSearch) {
                  boxFocus.unfocus();
                } else {
                  boxFocus.requestFocus();
                }
                showSearch = !showSearch;
                boxFocus.requestFocus();
                setState(() {});
              },
              shortcutsEnabled: true,
              onChanged: (index) => setState(() => tabIndex = index),
              closeButtonVisibility: CloseButtonVisibilityMode.onHover,
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
                  icon: const Icon(FluentIcons.news),
                  text: const Text('News'),
                  body: ScaffoldPage(
                    padding: EdgeInsets.zero,
                    content: newsList.isNotEmpty && searchList.isEmpty
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 700),
                            child:
                                LayoutBuilder(builder: (context, constraints) {
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
                                        color: set.isHovering
                                            ? Colors.grey[200]
                                            : null,
                                        child: ContextMenuArea(
                                          verticalPadding: 0,
                                          builder: (context) {
                                            return <Widget>[
                                              ListTile(
                                                leading: const Icon(FluentIcons
                                                    .open_in_new_tab),
                                                title: const Text(
                                                    'Open in new tab'),
                                                onPressed: () {
                                                  final tab = generateTab(item);
                                                  tabs.add(tab);
                                                  tabIndex = tabs.length;
                                                  setState(() {});
                                                  Navigator.of(context).pop();
                                                },
                                                tileColor:
                                                    ButtonState.resolveWith<
                                                        Color>((states) {
                                                  late final Color color;
                                                  if (states.isHovering) {
                                                    color = theme.accentColor
                                                        .withOpacity(0.31);
                                                  } else {
                                                    color = theme
                                                        .scaffoldBackgroundColor;
                                                  }
                                                  return color;
                                                }),
                                              ),
                                              ListTile(
                                                leading: const Icon(FluentIcons
                                                    .open_in_new_window),
                                                title: const Text(
                                                    'Launch in browser'),
                                                onPressed: () {
                                                  launchUrlString(item.link);
                                                  Navigator.of(context).pop();
                                                },
                                                tileColor:
                                                    ButtonState.resolveWith<
                                                        Color>((states) {
                                                  late final Color color;
                                                  if (states.isHovering) {
                                                    color = theme.accentColor
                                                        .withOpacity(0.31);
                                                  } else {
                                                    color = theme
                                                        .scaffoldBackgroundColor;
                                                  }
                                                  return color;
                                                }),
                                              ),
                                              ListTile(
                                                leading: const Icon(FluentIcons
                                                    .clipboard_list_add),
                                                title: const Text('Copy Link'),
                                                onPressed: () async {
                                                  await Clipboard.setData(
                                                      ClipboardData(
                                                          text: item.link));
                                                  if (!mounted) {
                                                    return;
                                                  }
                                                  Navigator.of(context).pop();
                                                },
                                                tileColor:
                                                    ButtonState.resolveWith<
                                                        Color>((states) {
                                                  late final Color color;
                                                  if (states.isHovering) {
                                                    color = theme.accentColor
                                                        .withOpacity(0.31);
                                                  } else {
                                                    color = theme
                                                        .scaffoldBackgroundColor;
                                                  }
                                                  return color;
                                                }),
                                              ),
                                            ];
                                          },
                                          child: GradientView(_buildCard(item),
                                              item: item),
                                        ),
                                      ),
                                      onPressed: () {
                                        if (appPrefs.openInsideApp) {
                                          final tab = generateTab(item);
                                          tabs.add(tab);
                                          tabIndex = tabs.length;
                                          setState(() {});
                                        } else {
                                          launchUrlString(item.link);
                                        }
                                      },
                                      cursor: SystemMouseCursors.click,
                                    );
                                  });
                            }))
                        : searchList.isNotEmpty //DRY!
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 700),
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
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
                                      itemCount: searchList.length,
                                      itemBuilder: (context, index) {
                                        final item = searchList[index];
                                        return HoverButton(
                                          builder: (context, set) => Container(
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
                                                          generateTab(item);
                                                      tabs.add(tab);
                                                      tabIndex = tabs.length;
                                                      setState(() {});
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    tileColor:
                                                        ButtonState.resolveWith<
                                                            Color>((states) {
                                                      late final Color color;
                                                      if (states.isHovering) {
                                                        color = theme
                                                            .accentColor
                                                            .withOpacity(0.31);
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
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    tileColor:
                                                        ButtonState.resolveWith<
                                                            Color>((states) {
                                                      late final Color color;
                                                      if (states.isHovering) {
                                                        color = theme
                                                            .accentColor
                                                            .withOpacity(0.31);
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
                                                    title:
                                                        const Text('Copy Link'),
                                                    onPressed: () async {
                                                      await Clipboard.setData(
                                                          ClipboardData(
                                                              text: item.link));
                                                      if (!mounted) {
                                                        return;
                                                      }
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    tileColor:
                                                        ButtonState.resolveWith<
                                                            Color>((states) {
                                                      late final Color color;
                                                      if (states.isHovering) {
                                                        color = theme
                                                            .accentColor
                                                            .withOpacity(0.31);
                                                      } else {
                                                        color = theme
                                                            .scaffoldBackgroundColor;
                                                      }
                                                      return color;
                                                    }),
                                                  ),
                                                ];
                                              },
                                              child: GradientView(
                                                  _buildCard(item),
                                                  item: item),
                                            ),
                                          ),
                                          onPressed: () {
                                            if (appPrefs.openInsideApp) {
                                              final tab = generateTab(item);
                                              tabs.add(tab);
                                              tabIndex = tabs.length;
                                              setState(() {});
                                            } else {
                                              launchUrlString(item.link);
                                            }
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
                  closeIcon: null,
                  onClosed: null,
                ),
                ...tabs
              ]),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
