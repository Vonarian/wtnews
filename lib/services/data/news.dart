import 'dart:convert';

import 'package:intl/intl.dart';

import '../../main.dart';

class News {
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final String dateString;
  final String link;
  final bool isNews;
  final bool dev;

  const News(
      {required this.title,
      required this.description,
      required this.imageUrl,
      required this.date,
      required this.link,
      required this.dateString,
      required this.isNews,
      required this.dev});

  @override
  String toString() {
    return 'News{title: $title, description: $description, imageUrl: $imageUrl, date: $date, dateString: $dateString, link: $link, isNews: $isNews, dev: $dev}';
  }

  factory News.fromJson(Map<String, dynamic> json) => News(
        title: json['title'],
        description: json['description'],
        imageUrl: json['imageUrl'],
        date: DateFormat('d-LLLL-y').parseLoose(json['date']),
        link: json['link'],
        isNews: json['isNews'],
        dev: json['dev'],
        dateString: json['date'],
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'date': date.toString(),
        'link': link,
        'isNews': isNews,
        'dev': dev,
      };

  static Future<List<News>> getNews() async {
    //Get from news section
    final responseNews =
        await dio.get('https://wtnews-server.vonarian.workers.dev/');
    final list = jsonDecode(responseNews.data) as List;
    final newsList = list.map((e) => News.fromJson(e)).toList();
    return newsList;
  }

  static Future<List<News>> getChangelog() async {
    //Get from changelog section
    final responseNews =
        await dio.get('https://wtnews-server-changelog.vonarian.workers.dev/');
    final list = jsonDecode(responseNews.data) as List;
    final newsList = list.map((e) => News.fromJson(e)).toList();
    return newsList;
  }
}
