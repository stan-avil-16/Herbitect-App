import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
//import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: "AIzaSyDBYAKhZVRFRb5n6oV3hqrL5Tnc0RLtmeU",
      authDomain: "herbal-i-106f8.firebaseapp.com",
      projectId: "herbal-i-106f8",
      storageBucket: "herbal-i-106f8.appspot.com",
      messagingSenderId: "90357859309",
      appId: "1:90357859309:web:f19cc874b2f008ff91dde4",
      measurementId: "G-Z1V16BKD4V",
      databaseURL: "https://herbal-i-106f8-default-rtdb.firebaseio.com",
    );
  }
}
