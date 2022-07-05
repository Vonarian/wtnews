import 'dart:developer';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wtnews/services/firebase.dart';

import '../main.dart';

class Message {
  final String title;
  final String subtitle;
  final int id;
  final String? url;
  final String? operation;
  final String? device;

  @override
  const Message({required this.title,
    required this.subtitle,
    required this.id,
    this.url,
    this.operation,
    this.device});

  @override
  String toString() {
    return 'Message{title: $title, subtitle: $subtitle, id: $id, url: $url, operation: $operation, device: $device}';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'id': id,
      'url': url,
      'operation': operation,
      'device': device,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      id: map['id'] as int,
      url: map['url'] as String?,
      operation: map['operation'] as String?,
      device: map['device'] as String?,
    );
  }

  static Future<void> getUserName(BuildContext context, data,
      WidgetRef ref) async {
    if (prefs.getString('userName') == null ||
        prefs.getString('userName') == '') {
      try {
        showDialog(
            context: context,
            builder: (context) => dialogBuilderUserName(context, data, ref));
      } catch (e, st) {
        log(e.toString(), stackTrace: st);
      }
    }
  }

  static Future<void> getFeedback(BuildContext context, data,
      bool mounted) async {
    try {
      if (prefs.getString('userName') != null &&
          prefs.getString('userName') != '') {
        dialogBuilderFeedback(context, data, mounted);
      }
    } catch (e, st) {
      await Sentry.captureException('Operation canceled.\n$e', stackTrace: st);
    }
  }
}

ContentDialog dialogBuilderUserName(BuildContext context, data, WidgetRef ref) {
  TextEditingController userNameController = TextEditingController();
  return ContentDialog(
    content: TextFormBox(
      onChanged: (value) {},
      validator: (value) {
        if (value != null) {
          return 'Username can\'t be empty';
        }
        if (value!.isEmpty) {
          return 'Username can\'t be empty';
        }
        return null;
      },
      controller: userNameController,
    ),
    title: const Text('Set a username (Forum username)'),
    actions: [
      Button(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel')),
      Button(
          onPressed: () async {
            Navigator.of(context).pop();
            Sentry.configureScope(
                  (scope) async =>
              await scope.setUser(SentryUser(
                  username: ref.watch(provider.userNameProvider),
                  ipAddress: scope.user?.ipAddress)),
            );

            await prefs.setString(
                'userName', ref.watch(provider.userNameProvider) ?? '');
            await presenceService.configureUserPresence(
                (await deviceInfo.windowsInfo).computerName,
                prefs.getBool('startup') ?? false,
                appVersion);
          },
          child: const Text('Save'))
    ],
  );
}

ContentDialog dialogBuilderFeedback(BuildContext context, data, bool mounted) {
  TextEditingController controller = TextEditingController();
  return ContentDialog(
    content: TextFormBox(
      onChanged: (value) {},
      validator: (value) {
        if (value != null) {
          return 'Feedback can\'t be empty';
        }
        if (value!.isEmpty) {
          return 'Feedback can\'t be empty';
        }
        return null;
      },
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),
    title: const Text('Set a username (Forum username)'),
    actions: [
      Button(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel')),
      Button(
          onPressed: () async {
            Navigator.of(context).pop();
            String message = controller.text;
            if (message.isNotEmpty) {
              SentryId sentryId = await Sentry.captureMessage(message);
              final feedback = SentryUserFeedback(
                eventId: sentryId,
                name: prefs.getString('username') ?? '',
              );

              await Sentry.captureUserFeedback(feedback);
              if (!mounted) return;
              showSnackbar(
                  context,
                  const Snackbar(
                    content: Text('Feedback sent, thanks!'),
                    extended: true,
                  ));
            }
          },
          child: const Text('Save'))
    ],
  );
}
