import 'dart:async';

import 'package:firebase_dart/database.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import 'firebase_data.dart';

class PresenceService {
  FirebaseDatabase database =
      FirebaseDatabase(app: app, databaseURL: dataBaseUrl);
  StreamSubscription? subscription;
  DatabaseReference? con;
  Future<void> configureUserPresence(
      String uid, bool startup, String version) async {
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
        String date = "${f.format(DateTime.now().toUtc())} GMT";
        lastOnlineRef.onDisconnect().set(date);
      }
    });
  }

  Future<String?> getVersion() async {
    final versionRef = database.reference().child('version');
    String? version = (await versionRef.once()).value;
    return version;
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
