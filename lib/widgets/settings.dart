import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/utility.dart';
import 'package:wtnews/von_assistant/von_assistant.dart';
import 'package:wtnews/widgets/card_highlight.dart';
import 'package:wtnews/widgets/loading_widget.dart';

import '../pages/downloader.dart';
import '../services/extensions.dart';

class Settings extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const Settings(this.prefs, {Key? key}) : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends ConsumerState<Settings> {
  Widget updateWidget(String version, {required FluentThemeData theme}) {
    return CardHighlight(
      leading: const Icon(FluentIcons.update_restore),
      title: Text(
        'New Update!',
        style: theme.typography.bodyStrong
            ?.copyWith(color: theme.accentColor.lightest),
      ),
      description: Text('$version is available to download'),
      trailing: Button(
          style: ButtonStyle(
              backgroundColor:
                  ButtonState.resolveWith((_) => theme.accentColor.lighter)),
          onPressed: () {
            Navigator.of(context)
                .pushReplacement(FluentPageRoute(builder: (context) {
              return const Downloader();
            }));
          },
          child: const Text('Update')),
    );
  }

  final scrollController = ScrollController(keepScrollOffset: true);

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final firebaseValue = ref.watch(provider.versionFBProvider);
    final prefs = ref.watch(provider.prefsProvider);
    final prefsNotifier = ref.read(provider.prefsProvider.notifier);
    return ScaffoldPage(
      header: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Text(
          'Settings',
          style: theme.typography.title,
        ),
      ),
      content: SingleChildScrollView(
        controller: scrollController,
        child: Card(
            backgroundColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                firebaseValue.when(
                    data: (data) => data != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                'Updates',
                                style: theme.typography.bodyStrong,
                              ),
                              const Gap(6.0),
                              updateWidget(data, theme: theme),
                            ],
                          )
                        : const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    loading: () => const SizedBox()),
                Text(
                  'Startup',
                  style: theme.typography.bodyStrong,
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.system,
                    size: 20,
                  ),
                  title: Text(
                    'Run at startup',
                    style: theme.typography.body,
                  ),
                  description: Text(
                    'This option allows running WTNews on system startup',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.runAtStartup,
                      leadingContent: true,
                      onChanged: (v) async {
                        prefsNotifier.update(runAtStartup: v);
                        final von = await showLoading<VonAssistant>(
                            context: context,
                            future: VonAssistant.initialize(appDocPath),
                            message: 'Getting Startup Service Ready!');
                        von.setStartup(v);
                      },
                      content: Text(prefs.runAtStartup ? 'On' : 'Off')),
                ),
                Text(
                  'Interface',
                  style: theme.typography.bodyStrong,
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.secondary_nav,
                    size: 24,
                  ),
                  title: Text(
                    'Navigation position',
                    style: theme.typography.body,
                  ),
                  description: Text(
                    'Set a navigation position from the list, Auto is suggested.',
                    style: theme.typography.caption,
                  ),
                  trailing: SizedBox(
                    width: 121,
                    child: ComboBox<PaneDisplayMode>(
                        items: PaneDisplayMode.values
                            .map((e) => ComboBoxItem(
                                value: e,
                                child: Text(
                                    '${e.name[0].toUpperCase()}${e.name.substring(1)}')))
                            .toList(),
                        onChanged: (v) =>
                            prefsNotifier.update(paneDisplayMode: v),
                        value: prefs.paneDisplayMode),
                  ),
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.screen,
                    size: 20,
                  ),
                  title: Text('Disable transparent-background effects',
                      style: theme.typography.body),
                  description: Text(
                    'This will disable any background transparent effect (Acrylic/Tabbed/Aero)',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.disableBackgroundTransparency,
                      onChanged: (v) {
                        prefsNotifier.update(disableBackgroundTransparency: v);
                        AppUtil.setEffect(v);
                      },
                      leadingContent: true,
                      content: Text(
                          prefs.disableBackgroundTransparency ? 'On' : 'Off')),
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.tab_center,
                    size: 20,
                  ),
                  title: Text('Open news items in a new tab',
                      style: theme.typography.body),
                  description: Text(
                    'Opens news items in a new tab inside the app (Requires Windows 10 1809+ & WebView2 Runtime)',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.openInsideApp,
                      onChanged: (v) => prefsNotifier.update(openInsideApp: v),
                      leadingContent: true,
                      content: Text(prefs.openInsideApp ? 'On' : 'Off')),
                ),
                Text(
                  'Notifications & Sound',
                  style: theme.typography.bodyStrong,
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.volume2,
                    size: 20,
                  ),
                  title: Text('Play Sound', style: theme.typography.body),
                  description: Text(
                    'Play a sound when new item arrives',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.playSound,
                      onChanged: (v) => prefsNotifier.update(playSound: v),
                      leadingContent: true,
                      content: Text(prefs.playSound ? 'On' : 'Off')),
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.focus_view,
                    size: 20,
                  ),
                  title: Text('Focused Mode', style: theme.typography.body),
                  description: Text(
                    'Only notify of Devblogs.',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.focusedMode,
                      onChanged: (v) => prefsNotifier.update(focusedMode: v),
                      leadingContent: true,
                      content: Text(prefs.focusedMode ? 'On' : 'Off')),
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.speech,
                    size: 20,
                  ),
                  title: Text('Read new Item\'s title aloud',
                      style: theme.typography.body),
                  description: Text(
                    'Reads title of the newly arrived item aloud. Uses Windows Text-to-Speech feature',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.readNewTitle,
                      onChanged: (v) => prefsNotifier.update(readNewTitle: v),
                      leadingContent: true,
                      content: Text(prefs.readNewTitle ? 'On' : 'Off')),
                ),
                CardHighlight(
                  leading: const Icon(
                    FluentIcons.speech,
                    size: 20,
                  ),
                  title: Text('Read new Item\'s caption aloud',
                      style: theme.typography.body),
                  description: Text(
                    'Reads caption of the newly arrived item aloud. Uses Windows Text-to-Speech feature',
                    style: theme.typography.caption,
                  ),
                  trailing: ToggleSwitch(
                      checked: prefs.readNewCaption,
                      onChanged: (v) => prefsNotifier.update(readNewCaption: v),
                      leadingContent: true,
                      content: Text(prefs.readNewCaption ? 'On' : 'Off')),
                ),
                Text(
                  'About',
                  style: theme.typography.bodyStrong,
                ),
                Card(
                  borderRadius: const BorderRadius.all(Radius.circular(4.0)),
                  padding: const EdgeInsets.only(bottom: 5, top: 5),
                  margin: const EdgeInsets.only(right: 30),
                  child: Expander(
                      animationDuration: const Duration(milliseconds: 150),
                      onStateChanged: (state) async {
                        if (state) {
                          await Future.delayed(
                              const Duration(milliseconds: 151));
                          scrollController.animateTo(
                              scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn);
                        }
                      },
                      leading: Image.asset(
                        'assets/app_icon.ico',
                        height: 25,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      headerBackgroundColor:
                          ButtonState.resolveWith((_) => Colors.transparent),
                      contentBackgroundColor: Colors.transparent,
                      header: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WTNews', style: theme.typography.body),
                          Text('2023 Vonarian 😎',
                              style: theme.typography.caption),
                        ],
                      ),
                      trailing: Text(appVersion),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'WTNews is an open-source program voluntarily developed by Vonarian.\nFeel free to contact me via the following methods:'),
                          const Gap(5),
                          Tooltip(
                            message:
                                'Open https://github.com/Vonarian in browser',
                            child: ListTile(
                              leading: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  FluentIcons.open_source,
                                  size: 20,
                                ),
                              ),
                              title: const Text('Github'),
                              subtitle: Text(
                                'Issues, feedback and feature requests can be discussed here.',
                                style: theme.typography.caption,
                              ),
                              onPressed: () {
                                launchUrlString('https://github.com/Vonarian');
                              },
                            ),
                          ),
                          Tooltip(
                            message:
                                'Open https://forum.warthunder.com/index.php?/profile/718501-vonarianthegreat in browser',
                            child: ListTile(
                              leading: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  FluentIcons.game,
                                  size: 20,
                                ),
                              ),
                              title: const Text('WT Forums'),
                              subtitle: Text(
                                'Contact me in the forums.',
                                style: theme.typography.caption,
                              ),
                              onPressed: () {
                                launchUrlString(
                                    'https://forum.warthunder.com/index.php?/profile/718501-vonarianthegreat');
                              },
                            ),
                          ),
                          Tooltip(
                            message:
                                'Open https://discord.gg/8HfGR3mubx in browser',
                            child: ListTile(
                              leading: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  FluentIcons.chat,
                                  size: 20,
                                ),
                              ),
                              title: const Text('Discord Server'),
                              subtitle: Text(
                                'AKA Vonarian\'s Chilling Zone! 🙂 You can share feedback and discuss stuff easier here.',
                                style: theme.typography.caption,
                              ),
                              onPressed: () {
                                launchUrlString(
                                    'https://discord.gg/8HfGR3mubx');
                              },
                            ),
                          ),
                        ].withDividerBetween(context),
                      )),
                ),
              ].withSpaceBetween(6.0),
            )),
      ),
    );
  }
}
