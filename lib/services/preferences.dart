import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class PreferencesNotifier extends StateNotifier<Preferences> {
  PreferencesNotifier(super.state);

  void load() {
    final json = prefs.getString('preferences');
    if (json != null) {
      state = Preferences.fromMap(jsonDecode(json));
    }
  }

  Future<void> save() async {
    await prefs.setString('preferences', jsonEncode(state.toMap()));
  }

  void update(
      {bool? runAtStartup,
      bool? minimizeAtStartup,
      bool? playSound,
      bool? focusedMode,
      bool? readNewTitle,
      bool? readNewCaption,
      PaneDisplayMode? paneDisplayMode,
      bool? openInsideApp,
      String? username}) {
    state = state.copyWith(
      runAtStartup: runAtStartup ?? state.runAtStartup,
      focusedMode: focusedMode ?? state.focusedMode,
      minimizeAtStartup: minimizeAtStartup ?? state.minimizeAtStartup,
      paneDisplayMode: paneDisplayMode ?? state.paneDisplayMode,
      playSound: playSound ?? state.playSound,
      readNewCaption: readNewCaption ?? state.readNewCaption,
      readNewTitle: readNewTitle ?? state.readNewTitle,
      openInsideApp: openInsideApp ?? state.openInsideApp,
      username: username ?? state.username,
    );
    save();
  }
}

@immutable
class Preferences {
  final bool runAtStartup;
  final bool minimizeAtStartup;
  final bool playSound;
  final bool focusedMode;
  final bool readNewTitle;
  final bool readNewCaption;
  final PaneDisplayMode paneDisplayMode;
  final String? username;
  final bool openInsideApp;

  const Preferences(
      {this.runAtStartup = false,
      this.minimizeAtStartup = true,
      this.playSound = true,
      this.focusedMode = false,
      this.readNewTitle = false,
      this.readNewCaption = false,
      this.paneDisplayMode = PaneDisplayMode.auto,
      this.openInsideApp = false,
      this.username});

  Map<String, dynamic> toMap() {
    return {
      'runAtStartup': runAtStartup,
      'minimizeAtStartup': minimizeAtStartup,
      'playSound': playSound,
      'focusedMode': focusedMode,
      'readNewTitle': readNewTitle,
      'readNewCaption': readNewCaption,
      'paneDisplayMode': paneDisplayMode.name,
      'username': username,
      'openInsideApp': openInsideApp,
    };
  }

  static PaneDisplayMode getPane(String mapValue) {
    final paneMode = PaneDisplayMode.values.byName(mapValue);
    return paneMode;
  }

  factory Preferences.fromMap(Map<String, dynamic> map) {
    return Preferences(
      runAtStartup: map['runAtStartup'] ?? false,
      minimizeAtStartup: map['minimizeAtStartup'] ?? true,
      playSound: map['playSound'] ?? true,
      focusedMode: map['focusedMode'] ?? false,
      readNewTitle: map['readNewTitle'] ?? false,
      readNewCaption: map['readNewCaption'] ?? false,
      paneDisplayMode:
          getPane(map['paneDisplayMode'] ?? PaneDisplayMode.auto.name),
      openInsideApp: map['openInsideApp'] ?? false,
      username: map['username'],
    );
  }

  Preferences copyWith({
    bool? runAtStartup,
    bool? minimizeAtStartup,
    bool? playSound,
    bool? focusedMode,
    bool? readNewTitle,
    bool? readNewCaption,
    PaneDisplayMode? paneDisplayMode,
    String? username,
    bool? openInsideApp,
  }) {
    return Preferences(
      runAtStartup: runAtStartup ?? this.runAtStartup,
      minimizeAtStartup: minimizeAtStartup ?? this.minimizeAtStartup,
      playSound: playSound ?? this.playSound,
      focusedMode: focusedMode ?? this.focusedMode,
      readNewTitle: readNewTitle ?? this.readNewTitle,
      readNewCaption: readNewCaption ?? this.readNewCaption,
      paneDisplayMode: paneDisplayMode ?? this.paneDisplayMode,
      openInsideApp: openInsideApp ?? this.openInsideApp,
      username: username ?? this.username,
    );
  }
}
