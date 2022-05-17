import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wtnews/main.dart';
import 'package:wtnews/services/presence.dart';

import '../providers.dart';
import '../services/data_class.dart';

class Feedback extends ConsumerStatefulWidget {
  final bool onlyUserName;
  final String text;
  const Feedback({Key? key, required this.onlyUserName, required this.text})
      : super(key: key);

  @override
  _FeedbackState createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<Feedback> {
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
