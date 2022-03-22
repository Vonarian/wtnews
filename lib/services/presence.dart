import 'dart:async';

import 'package:firebase_dart/database.dart';

import '../main.dart';

class PresenceService {
  FirebaseDatabase database = FirebaseDatabase(
      app: app,
      databaseURL:
          'https://wtnews-54364-default-rtdb.europe-west1.firebasedatabase.app');
  StreamSubscription? subscription;
  DatabaseReference? con;
  Future<void> configureUserPresence(
      String uid, bool startup, String version) async {
    final myConnectionsRef =
        database.reference().child('presence').child(uid).child('connected');
    final lastOnlineRef =
        database.reference().child('presence').child(uid).child('lastOnline');
    final userNameRef =
        database.reference().child('presence').child(uid).child('username');
    final startupRef =
        database.reference().child('presence').child(uid).child('startup');
    final versionRef =
        database.reference().child('presence').child(uid).child('version');
    await database.goOnline();
    if (prefs.getString('userName') != '' &&
        prefs.getString('userName') != null) {
      userNameRef.set(prefs.getString('userName'));
    }
    startupRef.set(startup);
    versionRef.set(version);
    database
        .reference()
        .child('presence')
        .child(uid)
        .onValue
        .listen((event) {});
    subscription = database
        .reference()
        .child('.info/connected')
        .onValue
        .listen((event) async {
      if (event.snapshot.value) {
        con = myConnectionsRef;
        con?.onDisconnect().set(false);
        con?.set(true);

        lastOnlineRef.onDisconnect().set(DateTime.now().toUtc().toString());
      }
    });
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
}
