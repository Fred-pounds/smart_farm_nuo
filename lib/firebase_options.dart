// ─────────────────────────────────────────────────────────────────────────────
// GENERATED FILE — replace all placeholder values with your own Firebase
// project credentials. See FIREBASE_SETUP.md for step-by-step instructions.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android ────────────────────────────────────────────────────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDG767h17kUW2aFW3Nk4Wf9oh6C2tZZ-HI',
    appId: '1:150213806225:android:08692ba652b663b27b1730',
    messagingSenderId: '150213806225',
    projectId: 'smart-farm-602a3',
    databaseURL: 'https://smart-farm-602a3-default-rtdb.firebaseio.com',
    storageBucket: 'smart-farm-602a3.firebasestorage.app',
  );

  // Find these in your google-services.json file

  // ── iOS ────────────────────────────────────────────────────────────────────

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD64bkDVRldNEQ5tQecgahqIXGUi68KdrI',
    appId: '1:150213806225:ios:c9cc1e5d1a0bc09e7b1730',
    messagingSenderId: '150213806225',
    projectId: 'smart-farm-602a3',
    databaseURL: 'https://smart-farm-602a3-default-rtdb.firebaseio.com',
    storageBucket: 'smart-farm-602a3.firebasestorage.app',
    iosBundleId: 'com.smartfarm.smartFarm',
  );

  // Find these in your GoogleService-Info.plist file

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCCQMwCaCnigZAEiOzlu8HJp8cgsDmxrsY',
    appId: '1:150213806225:web:0fd8980fe3cb366f7b1730',
    messagingSenderId: '150213806225',
    projectId: 'smart-farm-602a3',
    authDomain: 'smart-farm-602a3.firebaseapp.com',
    databaseURL: 'https://smart-farm-602a3-default-rtdb.firebaseio.com',
    storageBucket: 'smart-farm-602a3.firebasestorage.app',
    measurementId: 'G-FFQPJP10CE',
  );

  // ── Web (optional) ─────────────────────────────────────────────────────────
}
