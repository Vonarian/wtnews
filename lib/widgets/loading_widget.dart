import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Dialog;

Future<T> showLoading<T>({
  required BuildContext context,
  required Future<T> future,
  String? message,
}) {
  final completer = Completer<T>();

  showDialog(
    context: context,
    builder: (context) => _LoadingDialog(
      future: future,
      completer: completer,
      message: message,
    ),
  ).then((value) {
    if (!completer.isCompleted) {
      // Dialog popped by something else
      if (value is T) {
        completer.complete(value);
      } else {
        completer.completeError(
          Exception(
            'Loading Dialog popped with incompatible value',
          ),
        );
      }
    }
  });

  return completer.future;
}

class _LoadingDialog<T> extends StatefulWidget {
  const _LoadingDialog({
    super.key,
    required this.future,
    required this.completer,
    this.message,
  });

  final Future<T> future;
  final Completer<T> completer;
  final String? message;

  @override
  __LoadingDialogState createState() => __LoadingDialogState();
}

class __LoadingDialogState extends State<_LoadingDialog> {
  @override
  void initState() {
    super.initState();
    widget.future.then((value) {
      if (!mounted) return;
      widget.completer.complete(value);
      Navigator.of(context).pop();
    }).onError<Object>((error, stackTrace) {
      if (!mounted) return;
      widget.completer.completeError(error, stackTrace);
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: WillPopScope(
        onWillPop: () async => false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ProgressRing(),
            if (widget.message != null) ...[
              const SizedBox(height: 8.0),
              Text(
                widget.message!,
                style: FluentTheme.of(context).typography.title,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
