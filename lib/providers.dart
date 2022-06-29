import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' show Brightness, Color, Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webfeed/domain/rss_feed.dart';

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

  final dataMineFutureProvider = FutureProvider<RssFeed>((ref) async {
    Response response = await Dio()
        .get('https://forum.warthunder.com/index.php?/discover/704.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    if (rssFeed.items != null) {
      rssFeed.items!.removeWhere((item) {
        var itemDescription = item.description;
        bool? isDataMine = (itemDescription!.contains('Raw changes:') &&
                itemDescription.contains('→') &&
                itemDescription.contains('Current dev version')) ||
            itemDescription.contains('	');
        return !isDataMine;
      });
    }
    return rssFeed;
  });
}
