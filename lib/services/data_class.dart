class Message {
  final String title;
  final String subtitle;

  const Message({
    required this.title,
    required this.subtitle,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
    );
  }

  @override
  String toString() {
    return 'Message{title: $title, subtitle: $subtitle}';
  }
}
