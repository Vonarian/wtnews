import 'package:firebase_dart/firebase_dart.dart';
import 'package:fluent_ui/fluent_ui.dart' show Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wtnews/data/firebase.dart';
import 'package:wtnews/data/news.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/services/preferences.dart';

import 'data/update_mode.dart';

class MyProvider {
  final systemColorProvider = StateProvider<Color>((_) => Colors.red);
  final versionFBProvider = StreamProvider<String?>(
    (_) async* {
      await for (Event e in presenceService.getVersion()) {
        final data = e.snapshot.value.toString();
        final version = int.parse(data.replaceAll('.', ''));
        final currentVersion = int.parse(appVersion.replaceAll('.', ''));
        if (version > currentVersion) {
          yield data;
        } else {
          yield null;
        }
      }
    },
  );

  final prefsProvider = StateNotifierProvider<PreferencesNotifier, Preferences>(
      (ref) => PreferencesNotifier(const Preferences(), ref: ref));
  final newsProvider =
      StateNotifierProvider<NewsNotifier, List<News>>((_) => NewsNotifier());
  final updateModeProvider =
      StateNotifierProvider<UpdateModeNotifier, UpdateMode>(
          (ref) => UpdateModeNotifier(
                const UpdateMode(
                    autoLegacy: false,
                    manualLegacy: false,
                    webSocketConnected: false),
              ));
}

final provider = MyProvider();
