import 'package:fluent_ui/fluent_ui.dart';
import 'package:gap/gap.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `false`).
  String toHex({bool leadingHashSign = false}) =>
      '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

extension EnhancedWidgetList on List<Widget> {
  List<Widget> withSpaceBetween(double space) => [
        if (isNotEmpty) this[0],
        for (int i = 1; i < length; i++) ...[
          Gap(space),
          this[i],
        ],
      ];

  List<Widget> withDividerBetween(BuildContext context) => [
        if (isNotEmpty) this[0],
        for (int i = 1; i < length; i++) ...[
          this[i],
          Divider(
              style: DividerThemeData(
            decoration: BoxDecoration(
                color: FluentTheme.of(context).scaffoldBackgroundColor),
          )),
        ],
      ];
}
