import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' show Window, WindowEffect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/link.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/utility.dart';
import 'package:wtnews/von_assistant/von_assistant.dart';
import 'package:wtnews/widgets/loading_widget.dart';
import 'package:wtnews/widgets/widget_with_tip.dart';

class Settings extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const Settings(this.prefs, {Key? key}) : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends ConsumerState<Settings> {
  @override
  void initState() {
    super.initState();
  }

  final controller = ScrollController(keepScrollOffset: true);

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final prefs = ref.watch(provider.prefsProvider);
    final prefsNotifier = ref.read(provider.prefsProvider.notifier);
    return ScaffoldPage.scrollable(
      scrollController: controller,
      header: Row(
        children: [
          const SizedBox(
            width: 30,
          ),
          Text(
            'Settings',
            style: theme.typography.titleLarge,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 24, left: 30),
      children: [
        Card(
            borderColor: prefs.disableBackgroundTransparency
                ? theme.accentColor.darker
                : Colors.transparent,
            backgroundColor: prefs.disableBackgroundTransparency
                ? Colors.grey.withAlpha(150)
                : Colors.transparent,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10.0,
              direction: Axis.vertical,
              children: [
                Text(
                  'Startup',
                  style: theme.typography.subtitle,
                ),
                WidgetWithTip(
                  widget: Text(
                    'Run WTNews on startup',
                    style: theme.typography.body,
                  ),
                  tooltip: const Tooltip(
                    message: 'Starts WTNews on system startup',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.runAtStartup,
                    onChanged: (v) async {
                      prefsNotifier.update(runAtStartup: v);
                      final von = await showLoading<VonAssistant>(
                          context: context,
                          future: VonAssistant.initialize(appDocPath),
                          message: 'Getting Startup Service Ready!');
                      von.setStartup(v);
                    },
                    content: Text(prefs.runAtStartup ? 'On' : 'Off')),
                WidgetWithTip(
                  widget: Text('Minimize WTNews on startup',
                      style: theme.typography.body),
                  tooltip: const Tooltip(
                    message:
                        'Hides WTNews on system startup (Currently malfunctioning :/)',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.minimizeAtStartup,
                    onChanged: (v) {
                      prefsNotifier.update(minimizeAtStartup: v);
                    },
                    content: Text(prefs.minimizeAtStartup ? 'On' : 'Off')),
                Text(
                  'Interface',
                  style: theme.typography.subtitle,
                ),
                WidgetWithTip(
                  widget: Text(
                    'Navigation position',
                    style: theme.typography.body,
                  ),
                  tooltip: const Tooltip(
                    message:
                        'Set a navigation position from the list, Auto is suggested.',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                SizedBox(
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
                WidgetWithTip(
                  widget: Text('Turn off transparent-background effect',
                      style: theme.typography.body),
                  tooltip: const Tooltip(
                    message:
                        'This will disable any background transparent effect/style',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.disableBackgroundTransparency,
                    onChanged: (v) {
                      prefsNotifier.update(disableBackgroundTransparency: v);
                      if (v) {
                        Window.setEffect(effect: WindowEffect.disabled);
                      } else {
                        AppUtil.setEffect(v);
                      }
                    },
                    content: Text(
                        prefs.disableBackgroundTransparency ? 'On' : 'Off')),
                WidgetWithTip(
                  widget: Text('Open news items in a new tab',
                      style: theme.typography.body),
                  tooltip: Tooltip(
                    message:
                        'Opens news inside the app (Requires Windows 10 1809+ & WebView2 Runtime)',
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        color: Colors.red,
                        size: 12,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.openInsideApp,
                    onChanged: (v) => prefsNotifier.update(openInsideApp: v),
                    content: Text(prefs.openInsideApp ? 'On' : 'Off')),
                Text(
                  'Notifications & Sound',
                  style: theme.typography.subtitle,
                ),
                WidgetWithTip(
                  widget: Text('Play Sound', style: theme.typography.body),
                  tooltip: const Tooltip(
                    message: 'Plays a sound to notify about new item',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.playSound,
                    onChanged: (v) => prefsNotifier.update(playSound: v),
                    content: Text(prefs.playSound ? 'On' : 'Off')),
                WidgetWithTip(
                  widget: Text('Focused Mode', style: theme.typography.body),
                  tooltip: const Tooltip(
                    message:
                        'Only notify of Devblogs. In another word, notifications will be sent for devblogs only',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.focusedMode,
                    onChanged: (v) => prefsNotifier.update(focusedMode: v),
                    content: Text(prefs.focusedMode ? 'On' : 'Off')),
                WidgetWithTip(
                  widget: Text('Read new Item\'s title aloud',
                      style: theme.typography.body),
                  tooltip: const Tooltip(
                    message:
                        'Reads title of the newly arrived item aloud. Uses Windows Text-to-Speech feature',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.readNewTitle,
                    onChanged: (v) => prefsNotifier.update(readNewTitle: v),
                    content: Text(prefs.readNewTitle ? 'On' : 'Off')),
                WidgetWithTip(
                  widget: Text('Read new Item\'s caption aloud',
                      style: theme.typography.body),
                  tooltip: const Tooltip(
                    message:
                        'Reads description of the newly arrived item aloud. Uses Windows Text-to-Speech feature',
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        FluentIcons.info,
                        size: 10,
                      ),
                    ),
                  ),
                ),
                ToggleSwitch(
                    checked: prefs.readNewCaption,
                    onChanged: (v) => prefsNotifier.update(readNewCaption: v),
                    content: Text(prefs.readNewCaption ? 'On' : 'Off')),
                Text(
                  'More Info',
                  style: theme.typography.subtitle,
                ),
                const Text(
                    'This application is voluntarily developed and maintained by Vonarian for War Thunder\'s community.\nFeel free to leave feedback in Discord, through GitHub, or Forums.'),
                const Text('Contact Methods:'),
                Row(
                  children: [
                    Link(
                      uri: Uri.parse('https://github.com/Vonarian'),
                      builder: (context, open) => Tooltip(
                        message: 'GitHub',
                        child: IconButton(
                          icon: const Icon(FluentIcons.open_source, size: 24.0),
                          onPressed: open,
                        ),
                      ),
                    ),
                    Link(
                      uri: Uri.parse(
                          'https://forum.warthunder.com/index.php?/profile/718501-vonarianthegreat/'),
                      builder: (context, open) => Tooltip(
                        message: 'War Thunder Forums',
                        child: IconButton(
                          icon: const Icon(FluentIcons.game, size: 24.0),
                          onPressed: open,
                        ),
                      ),
                    ),
                    Link(
                      uri: Uri.parse('https://discord.gg/8HfGR3mubx'),
                      builder: (context, open) => Tooltip(
                        message: 'Discord Server',
                        child: IconButton(
                          icon: const Icon(FluentIcons.chat, size: 24.0),
                          onPressed: open,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )),
      ],
    );
  }
}
