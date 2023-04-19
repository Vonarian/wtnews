import 'package:fluent_ui/fluent_ui.dart';

class CardHighlight extends StatefulWidget {
  const CardHighlight({
    Key? key,
    this.backgroundColor,
    required this.title,
    required this.description,
    this.leading,
    this.trailing,
  }) : super(key: key);

  final Widget title;
  final Widget description;
  final Widget? leading;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  State<CardHighlight> createState() => _CardHighlightState();
}

class _CardHighlightState extends State<CardHighlight> {
  @override
  Widget build(BuildContext context) {
    return Card(
      backgroundColor: widget.backgroundColor,
      borderRadius: const BorderRadius.all(Radius.circular(4.0)),
      padding: const EdgeInsets.only(bottom: 5, top: 5),
      margin: const EdgeInsets.only(right: 30),
      child: SizedBox(
        width: double.infinity,
        child: ListTile(
          leading: Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: widget.leading,
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: widget.trailing,
          ),
          title: widget.title,
          subtitle: widget.description,
        ),
      ),
    );
  }
}
