import 'dart:convert';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../main.dart';
// Currently private
import 'vps_data.dart' as vps;

class News extends Equatable {
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

  factory News.fromJson(Map<String, dynamic> json, {required bool workers}) =>
      News(
        title: json['title'],
        description: json['description'],
        imageUrl: json['imageUrl'],
        date: DateFormat('d-LLLL-y')
            .parseLoose(json[workers ? 'date' : 'dateString']),
        link: json['link'],
        isNews: json['isNews'],
        dev: json['dev'],
        dateString: json[workers ? 'date' : 'dateString'],
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'date': date.toString(),
        'link': link,
        'isNews': isNews,
        'dev': dev,
        'dateString': dateString,
      };

  static WebSocketChannel connectNews() {
    //Get from news section
    final channel = WebSocketChannel.connect(Uri.parse('ws://${vps.address}'));
    return channel;
  }

  static WebSocketChannel connectChangelog() {
    //Get from changelog section
    final channel = WebSocketChannel.connect(Uri.parse('ws://${vps.address}'));
    return channel;
  }

  static Future<List<News>> getAllNews() async {
    List<News> news = [];
    try {
      final response = await dio
          .get('http://${vps.address}')
          .timeout(const Duration(seconds: 7));
      final jsonList = jsonDecode(response.data) as List;
      news = (jsonList.map((e) => News.fromJson(e, workers: false))).toList();
    } catch (e, st) {
      log(e.toString(), stackTrace: st);
      news = await getAllNewsFallback();
    }
    return news;
  }

  static Future<List<News>> getAllNewsFallback() async {
    List<News> list = [];
    try {
      final news = await getNews();
      final changelog = await getChangelog();
      final finalList = [...news, ...changelog]
        ..sort((a, b) => a.date.compareTo(b.date));
      list.addAll(finalList);
    } catch (e) {
      //
    }
    return list;
  }

  static Future<List<News>> getNews() async {
    final responseNews =
        await dio.get('https://wtnews-server.vonarian.workers.dev/');
    final list = jsonDecode(responseNews.data) as List;
    final newsList = list.map((e) => News.fromJson(e, workers: true)).toList();
    return newsList;
  }

  static Future<List<News>> getChangelog() async {
    final responseNews =
        await dio.get('https://wtnews-server-changelog.vonarian.workers.dev/');
    final list = jsonDecode(responseNews.data) as List;
    final newsList = list.map((e) => News.fromJson(e, workers: true)).toList();
    return newsList;
  }

  @override
  List<Object?> get props => [title];
}

class NewsNotifier extends StateNotifier<List<News>> {
  NewsNotifier() : super([]);

  void add(News item) => state = [item, ...state];

  void addAll(List<News> items) => state = [...items, ...state];

  void sortByTime() => state = state..sort((a, b) => b.date.compareTo(a.date));

  void deduplicate() => state = state.toSet().toList();

  @override
  set state(List<News> value) {
    super.state = value;
    prefs.setString('lastItem', newestItem.title);
  }

  News get newestItem => state.first;
}
