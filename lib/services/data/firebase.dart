import 'dart:async';
import 'dart:io';

import 'package:firebase_dart/database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import 'firebase_data.dart';

class PresenceService {
  FirebaseDatabase database =
      FirebaseDatabase(app: app, databaseURL: dataBaseUrl);
  StreamSubscription? subscription;
  DatabaseReference? con;

  Future<void> configureUserPresence(String uid, bool startup, String version,
      {required SharedPreferences prefs}) async {
    final uidRef = database.reference().child('presence').child(uid);
    final myConnectionsRef = uidRef.child('connected');
    final lastOnlineRef = uidRef.child('lastOnline');
    final userNameRef = uidRef.child('username');
    final startupRef = uidRef.child('startup');
    final versionRef = uidRef.child('version');
    await database.goOnline();
    String? userName = prefs.getString('userName');
    if (userName != '' && userName != null) {
      userNameRef.set(userName);
    }
    startupRef.set(startup);
    versionRef.set(version);
    subscription = database
        .reference()
        .child('.info/connected')
        .onValue
        .listen((event) async {
      if (event.snapshot.value) {
        con = myConnectionsRef;
        con?.onDisconnect().set(false);
        con?.set(true);
        DateFormat f = DateFormat('E, d MMM yyyy HH:mm:ss');
        final String locale = Platform.localeName;
        final String date = '${f.format(DateTime.now())} ($locale)';
        lastOnlineRef.onDisconnect().set(date);
      }
    });
  }

  Stream<Event> getVersion() {
    final versionRef = database.reference().child('version');
    final sub = versionRef.onValue;
    return sub;
  }

  Stream<Event> getDevMessage() {
    final versionRef = database.reference().child('message');
    final sub = versionRef.onValue;
    return sub;
  }

  void connect() {
    database.goOnline();
  }

  void disconnect({bool signOut = false}) {
    if (signOut && subscription != null) {
      subscription?.cancel();
    }
    database.goOffline();
  }

  Stream<Event> getPremium(String uid) {
    final uidRef = database.reference().child('presence').child(uid);
    final premiumRef = uidRef.child('premium');
    final sub = premiumRef.onValue;
    return sub.asBroadcastStream();
  }

  Stream<Event> getMessage(String uid) {
    final uidRef = database.reference().child('presence').child(uid);
    final premiumRef = uidRef.child('message');
    final sub = premiumRef.onValue;
    return sub.asBroadcastStream();
  }
}

final PresenceService presenceService = PresenceService();