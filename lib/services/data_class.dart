import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../main.dart';

class Message {
  final String title;
  final String subtitle;
  final int id;
  final String? url;
  final String? operation;
  final String? device;
  @override
  const Message(
      {required this.title,
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

  static void restart(BuildContext context) {
    Phoenix.rebirth(context);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Application will be restarted in 50 seconds'),
      ));
  }

  static Future<void> getUserName(BuildContext context) async {
    if (prefs.getString('userName') == null ||
        prefs.getString('userName') == '') {
      try {
        String userName =
            (await Navigator.of(context).push(dialogBuilderUserName(context)))!;
        await prefs.setString('userName', userName);
      } catch (e, st) {
        await Sentry.captureException('Operation canceled.\n$e',
            stackTrace: st);
      }
    }
  }

  static Future<void> getFeedback(BuildContext context) async {
    try {
      if (prefs.getString('userName') != null &&
          prefs.getString('userName') != '') {
        SentryId sentryId = await Sentry.captureMessage(
            await Navigator.of(context).push(dialogBuilderFeedback(context)));
        final feedback = SentryUserFeedback(
            name: prefs.getString('userName'), eventId: sentryId);
        await Sentry.captureUserFeedback(feedback);
      }
    } catch (e, st) {
      await Sentry.captureException('Operation canceled.\n$e', stackTrace: st);
    }
  }
}

Route<String> dialogBuilderUserName(BuildContext context) {
  TextEditingController userNameController = TextEditingController();
  return DialogRoute(
      context: context,
      builder: (BuildContext context) => AlertDialog(
            content: TextFormField(
              onChanged: (value) {},
              validator: (value) {
                if (value != null) {
                  if (value.isEmpty) {
                    return 'Username can\'t be empty';
                  } else {
                    return null;
                  }
                }
                return null;
              },
              controller: userNameController,
              decoration:
                  const InputDecoration(hintText: 'Enter your forum username'),
            ),
            title: const Text('Set a username (Forum username)'),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(userNameController.text);
                  },
                  child: const Text('Save'))
            ],
          ));
}

Route<String> dialogBuilderFeedback(BuildContext context) {
  TextEditingController feedBackController = TextEditingController();
  return DialogRoute(
      context: context,
      builder: (BuildContext context) => AlertDialog(
            content: TextFormField(
              onChanged: (value) {},
              validator: (value) {
                if (value != null) {
                  if (value.isEmpty) {
                    return 'Feedback can\'t be empty';
                  } else {
                    return null;
                  }
                }
                return null;
              },
              controller: feedBackController,
              decoration: const InputDecoration(
                  hintText:
                      'I like this part, I don\'t like that part, that part has issues'),
            ),
            title: const Text('Send feedback'),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(feedBackController.text);
                  },
                  child: const Text('Send'))
            ],
          ));
}
