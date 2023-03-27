import 'package:fluent_ui/fluent_ui.dart';

import '../services/data/news.dart';
import '../services/extensions.dart';

class GradientView extends StatelessWidget {
  final Widget widget;
  final News item;

  const GradientView(this.widget, {Key? key, required this.item})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: widget),
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            colors: [
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.4],
            begin: Alignment.bottomCenter,
            end: Alignment.center,
          )),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  item.dateString,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: HexColor.fromHex('#8da0aa'),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}
