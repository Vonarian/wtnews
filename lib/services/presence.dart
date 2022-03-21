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
  Future<void> configureUserPresence(String uid) async {
    final myConnectionsRef =
        database.reference().child('presence').child(uid).child('connections');
    final lastOnlineRef =
        database.reference().child('presence').child(uid).child('lastOnline');
    await database.goOnline();

    database
        .reference()
        .child('presence')
        .child(uid)
        .onValue
        .listen((event) {});
    subscription =
        database.reference().child('.info/connected').onValue.listen((event) {
      if (event.snapshot.value) {
        con = myConnectionsRef.push();
        con?.onDisconnect().remove();
        con?.set(true);

        lastOnlineRef.onDisconnect().set(DateTime.now().toString());
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
