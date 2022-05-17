import 'package:flutter_riverpod/flutter_riverpod.dart';

final StateProvider<bool> isStartupEnabled = StateProvider((ref) => false);
final StateProvider<bool> playSound = StateProvider((ref) => true);
final StateProvider<bool> minimizeOnStart = StateProvider((ref) => false);
final StateProvider<bool> checkDataMine = StateProvider((ref) => false);
final StateProvider<String?> customFeed = StateProvider((ref) => null);
late final StateProvider<String?> userNameProvider;
