import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wtnews/widgets/gradient_widget.dart';

import '../data/news.dart';
import '../providers.dart';
import '../services/extensions.dart';
import 'item_webview.dart';

class NewsView extends ConsumerStatefulWidget {
  const NewsView({
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState createState() => _NewsViewState();
}

class _NewsViewState extends ConsumerState<NewsView> {
  final _searchHotKey = HotKey(
    KeyCode.keyF,
    scope: HotKeyScope.inapp,
    modifiers: [KeyModifier.control],
  );

  @override
  void initState() {
    super.initState();
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

  final List<News> searchList = [];

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

  void _handleSearch(String v, {required List<News> newsList}) {
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

  Widget searchBox(List<News> newsList) {
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
                onChanged: (v) => _handleSearch(v, newsList: newsList),
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
    final newsList = ref.watch(provider.newsProvider);
    final appPrefs = ref.watch(provider.prefsProvider);
    final theme = FluentTheme.of(context);
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showSearch ? searchBox(newsList) : null,
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
                                    return Acrylic(
                                      child: HoverButton(
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
                                                  leading: const Icon(
                                                      FluentIcons
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
                                      ),
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
}
