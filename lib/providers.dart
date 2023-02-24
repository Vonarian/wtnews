import 'package:firebase_dart/firebase_dart.dart';
import 'package:fluent_ui/fluent_ui.dart' show Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wtnews/services/data/firebase.dart';
import 'package:wtnews/services/preferences.dart';

class MyProvider {
  final systemColorProvider = StateProvider<Color>((_) => Colors.red);
  final versionFBProvider = StreamProvider<String>(
    (_) async* {
      await for (Event e in presenceService.getVersion()) {
        yield e.snapshot.value.toString();
      }
    },
  );
  final devMessageProvider = StreamProvider<String?>(
    (_) async* {
      await for (Event e in presenceService.getDevMessage()) {
        yield e.snapshot.value as String?;
      }
    },
  );

  final prefsProvider = StateNotifierProvider<PreferencesNotifier, Preferences>(
      (ref) => PreferencesNotifier(const Preferences()));
}

final provider = MyProvider();
