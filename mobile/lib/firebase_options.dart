// TODO: Replace this stub with real Firebase configuration values.
// Run `flutterfire configure` (from the FlutterFire CLI) to generate this file
// automatically, or fill in the values manually from your Firebase project
// settings (Project settings → Your apps → SDK setup and configuration).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Fill in real values from Firebase console.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'TODO',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'TODO',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'TODO',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    databaseURL: 'TODO',
  );
}
