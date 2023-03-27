import 'package:fluent_ui/fluent_ui.dart';

class WidgetWithTip extends StatelessWidget {
  final Widget widget;
  final Tooltip tooltip;

  const WidgetWithTip({Key? key, required this.widget, required this.tooltip})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        widget,
        tooltip,
      ],
    );
  }
}
