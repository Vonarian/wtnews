import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:intl/intl.dart';

import '../../main.dart';

class News {
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final String dateString;
  final String link;

  const News(
      {required this.title,
      required this.description,
      required this.imageUrl,
      required this.date,
      required this.link,
      required this.dateString});

  @override
  String toString() {
    return 'News ==> title: $title, description: $description, imageUrl: $imageUrl, date: $date, link: $link';
  }

  static Future<List<News>?> getNews() async {
    //Get from news section
    final responseNews = await dio.get('https://warthunder.com/en/news');
    const rootUrl = 'https://warthunder.com';
    final document = parse(responseNews.data);
    final List<dom.Element> elements =
        document.getElementsByClassName('showcase__content-wrapper');
    List<News> list = [];
    if (elements.isNotEmpty) {
      final items =
          elements[0].getElementsByClassName('showcase__item widget  ');
      if (items.isNotEmpty) {
        for (var item in items) {
          final url = rootUrl +
              (item.getElementsByClassName('widget__link')[0].attributes['href']
                      as String)
                  .replaceAll('//', '');
          final imageUrl = item
              .getElementsByClassName('widget__poster-media')[0]
              .attributes['data-src']
              .toString()
              .replaceAll('//', '');
          final content = item.getElementsByClassName('widget__content').first;
          final title = content.getElementsByClassName('widget__title').first;
          final description =
              content.getElementsByClassName('widget__comment').first;
          final date = content.getElementsByTagName('.widget-meta').first.text;
          final news = News(
              title: title.text.trim(),
              description: description.text.trim(),
              imageUrl: 'https://${imageUrl.trim()}',
              date: DateFormat('d-LLLL-y').parseLoose(date.trim()),
              dateString: date.trim(),
              link: url);
          list.add(news);
        }
        return list;
      }
    }
    return null;
  }

  static Future<List<News>?> getChangelog() async {
    //Get from changelog section
    final responseNews =
        await dio.get('https://warthunder.com/en/game/changelog/');
    const rootUrl = 'https://warthunder.com';
    final document = parse(responseNews.data);
    final List<dom.Element> elements =
        document.getElementsByClassName('showcase__content-wrapper');
    List<News> list = [];
    if (elements.isNotEmpty) {
      final items =
          elements[0].getElementsByClassName('showcase__item widget  ');
      if (items.isNotEmpty) {
        for (var item in items) {
          final url = rootUrl +
              (item.getElementsByClassName('widget__link')[0].attributes['href']
                      as String)
                  .replaceAll('//', '');
          final imageUrl = item
              .getElementsByClassName('widget__poster-media')[0]
              .attributes['data-src']
              .toString()
              .replaceAll('//', '');
          final content = item.getElementsByClassName('widget__content').first;
          final title = content.getElementsByClassName('widget__title').first;
          final description =
              content.getElementsByClassName('widget__comment').first;
          final date = content.getElementsByTagName('.widget-meta').first.text;
          final news = News(
              title: title.text.trim(),
              description: description.text.trim(),
              imageUrl: 'https://${imageUrl.trim()}',
              date: DateFormat('d-LLLL-y').parseLoose(date.trim()),
              dateString: date.trim(),
              link: url);
          list.add(news);
        }
        return list;
      }
    }
    return null;
  }
}
