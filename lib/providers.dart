import 'package:dio/dio.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:fluent_ui/fluent_ui.dart' show Brightness, Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:wtnews/services/data/firebase.dart';

class MyProvider {
  final StateProvider<bool> startupEnabled = StateProvider((_) => false);
  final StateProvider<bool> playSound = StateProvider((_) => true);
  final StateProvider<bool> minimizeOnStart = StateProvider((_) => false);
  final StateProvider<bool> checkDataMine = StateProvider((_) => false);
  final StateProvider<bool> premiumProvider = StateProvider((_) => false);
  final StateProvider<bool> focusedProvider = StateProvider((_) => false);
  final prefsProvider =
      Provider<SharedPreferences>((_) => throw UnimplementedError());
  final StateProvider<bool> additionalNotif = StateProvider((_) => false);
  final StateProvider<String?> customFeed = StateProvider((_) => null);
  final versionProvider = StateProvider<String?>((_) => null);
  late final StateProvider<String?> userNameProvider;
  final systemColorProvider = StateProvider<Color>((_) => Colors.red);
  final systemThemeProvider = StateProvider<Brightness>((_) => Brightness.dark);

  final dataMineFutureProvider = FutureProvider<RssFeed>((_) async {
    Response response = await Dio()
        .get('https://forum.warthunder.com/index.php?/discover/704.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    if (rssFeed.items != null) {
      rssFeed.items!.removeWhere((item) {
        var itemDescription = item.description;
        bool isDataMine = itemDescription!.contains('Raw changes:') &&
            itemDescription.contains('→') &&
            itemDescription.contains('Current dev version');
        return !isDataMine;
      });
    }
    return rssFeed;
  });
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
}
