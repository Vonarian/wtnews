import 'dart:ui';

import 'package:dart_rss/dart_rss.dart';
import 'package:flutter/material.dart';
import 'package:wtnews/widgets/titlebar.dart';

class Home extends StatefulWidget {
  final RssFeed rssFeed;
  const Home({Key? key, required this.rssFeed}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late RssFeed rssFeed;

  @override
  void initState() {
    super.initState();
    rssFeed = widget.rssFeed;
  }

  @override
  Widget build(BuildContext context) {
    print(rssFeed.items.first.description!.replaceAll('\n', ''));

    return Scaffold(
      body: Stack(
        children: [
          ImageFiltered(
              child: Image.asset(
                'assets/bg.png',
                fit: BoxFit.cover,
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              imageFilter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: ListView.builder(
                itemCount: rssFeed.items.length,
                itemBuilder: (context, index) {
                  RssItem data = rssFeed.items[index];

                  return ListTile(
                    title: Text(
                      data.title ?? 'No title',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      data.description?.replaceAll('\n', '') ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }),
          ),
          const WindowTitleBar()
        ],
      ),
    );
  }
}
