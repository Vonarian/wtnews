import 'package:fluent_ui/fluent_ui.dart' show Brightness, Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyProvider {
  final StateProvider<bool> startupEnabled = StateProvider((ref) => false);
  final StateProvider<bool> playSound = StateProvider((ref) => true);
  final StateProvider<bool> minimizeOnStart = StateProvider((ref) => false);
  final StateProvider<bool> checkDataMine = StateProvider((ref) => false);
  final StateProvider<bool> additionalNotif = StateProvider((ref) => false);
  final StateProvider<String?> customFeed = StateProvider((ref) => null);
  final versionProvider = StateProvider<String?>((ref) => null);
  late final StateProvider<String?> userNameProvider;
  final systemColorProvider = StateProvider<Color>((ref) => Colors.red);
  final systemThemeProvider =
      StateProvider<Brightness>((ref) => Brightness.dark);
}
