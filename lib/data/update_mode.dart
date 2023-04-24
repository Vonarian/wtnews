import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateMode {
  final bool autoLegacy;
  final bool manualLegacy;
  final bool webSocketConnected;

  const UpdateMode({
    required this.autoLegacy,
    required this.manualLegacy,
    required this.webSocketConnected,
  });

  UpdateMode copyWith({
    bool? autoLegacy,
    bool? manualLegacy,
    bool? webSocketConnected,
  }) {
    return UpdateMode(
      autoLegacy: autoLegacy ?? this.autoLegacy,
      manualLegacy: manualLegacy ?? this.manualLegacy,
      webSocketConnected: webSocketConnected ?? this.webSocketConnected,
    );
  }

  String get modeText {
    String text = '';
    if (autoLegacy && manualLegacy) {
      text = 'Auto/Manual Legacy Mode';
    } else if (autoLegacy && !manualLegacy) {
      text = 'Auto Legacy Mode';
    } else if (!autoLegacy && manualLegacy) {
      text = 'Manual Legacy Mode';
    }
    return text;
  }

  Color? get iconColor {
    Color? color;
    if (autoLegacy && manualLegacy) {
      color = Colors.orange;
    } else if (autoLegacy && !manualLegacy) {
      color = Colors.orange;
    } else if (!autoLegacy && manualLegacy && webSocketConnected) {
      color = Colors.orange;
    } else if (!autoLegacy && !manualLegacy && webSocketConnected) {
      color = Colors.green;
    } else if (!webSocketConnected && !autoLegacy && !manualLegacy) {
      color = Colors.red;
    }
    return color;
  }

  String get wsText {
    late final String text;
    if (webSocketConnected) {
      text = 'WebSocket Connected';
    } else {
      text = 'WebSocket Disconnected';
    }
    return text;
  }
}

class UpdateModeNotifier extends StateNotifier<UpdateMode> {
  UpdateModeNotifier(super.state);

  void update({
    bool? autoLegacy,
    bool? manualLegacy,
    bool? webSocketConnected,
  }) {
    state = state.copyWith(
        autoLegacy: autoLegacy,
        manualLegacy: manualLegacy,
        webSocketConnected: webSocketConnected);
  }
}
