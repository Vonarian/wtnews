import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/services/presence.dart';

class Feedback extends ConsumerStatefulWidget {
  final bool onlyUserName;
  final String text;
  const Feedback({Key? key, required this.onlyUserName, required this.text})
      : super(key: key);

  @override
  _FeedbackState createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<Feedback> {
  static Route<String> dialogBuilderUserName(BuildContext context) {
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
                decoration: const InputDecoration(
                    hintText: 'Enter your forum username'),
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

  static Route<String> dialogBuilderFeedback(BuildContext context) {
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

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Text(
        widget.text,
        style: const TextStyle(fontSize: 40, color: Colors.red),
      ),
      onTap: () async {
        if ((ref.watch(userNameProvider) == null ||
                ref.watch(userNameProvider) == '') ||
            widget.onlyUserName) {
          ref.read(userNameProvider.notifier).state =
              (await Navigator.of(context)
                  .push(dialogBuilderUserName(context)))!;
          Sentry.configureScope(
            (scope) => scope.user = SentryUser(
                username: ref.watch(userNameProvider),
                ipAddress: scope.user?.ipAddress),
          );

          await prefs.setString('userName', ref.watch(userNameProvider) ?? '');
          await PresenceService().configureUserPresence(
              (await deviceInfo.windowsInfo).computerName,
              prefs.getBool('startup') ?? false,
              File(pathToVersion).readAsStringSync());
          if (!widget.onlyUserName) {
            SentryId sentryId = await Sentry.captureMessage(
                (await Navigator.of(context)
                    .push(dialogBuilderFeedback(context)))!);
            final feedback = SentryUserFeedback(
              eventId: sentryId,
              name: ref.watch(userNameProvider),
            );
            await Sentry.captureUserFeedback(feedback);
            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                  const SnackBar(content: Text('Feedback sent, thanks!')));
          }
        } else {
          if (!widget.onlyUserName) {
            SentryId sentryId = await Sentry.captureMessage(
                (await Navigator.of(context)
                    .push(dialogBuilderFeedback(context)))!);
            final feedback = SentryUserFeedback(
              eventId: sentryId,
              name: ref.watch(userNameProvider),
            );

            await Sentry.captureUserFeedback(feedback);
            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                  const SnackBar(content: Text('Feedback sent, thanks!')));
          }
        }
      },
    );
  }
}
