class Message {
  final String title;
  final String subtitle;
  final int id;
  final String? url;
  @override
  String toString() {
    return 'Message{title: $title, subtitle: $subtitle, id: $id, url: $url}';
  }

  const Message(
      {required this.title,
      required this.subtitle,
      required this.id,
      this.url});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'id': id,
      'url': url,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      id: map['id'] as int,
      url: map['url'] ?? '',
    );
  }
}
