// File generated manually as a scaffold.
// Replace values by running from `mobile/`:
//   flutterfire configure
// Or paste values from Firebase Console → Project settings.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured {
    final options = currentPlatform;
    return options.apiKey != 'YOUR_API_KEY' &&
        options.projectId != 'YOUR_PROJECT_ID' &&
        options.appId != 'YOUR_APP_ID';
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxNWwy1prByBH0UmoNEAhaQrbvNPgVTmE',
    appId: '1:1088818781536:web:9f8b3766ecb68125881205',
    messagingSenderId: '1088818781536',
    projectId: 'mimio-f4bb7',
    authDomain: 'mimio-f4bb7.firebaseapp.com',
    storageBucket: 'mimio-f4bb7.firebasestorage.app',
    measurementId: 'G-RC0LDCCBDS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCj11FqUfYkYTyd6YGP6_tARsFAZGHapdo',
    appId: '1:1088818781536:android:63c8fe0d88bbd4c4881205',
    messagingSenderId: '1088818781536',
    projectId: 'mimio-f4bb7',
    storageBucket: 'mimio-f4bb7.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBgemxkFi8AIV1iE66rNQbGygJtrsB8-Q',
    appId: '1:1088818781536:ios:7b12914714200fde881205',
    messagingSenderId: '1088818781536',
    projectId: 'mimio-f4bb7',
    storageBucket: 'mimio-f4bb7.firebasestorage.app',
    iosClientId: '1088818781536-6epk3ova7ji3shma956ds91iq81rcqsd.apps.googleusercontent.com',
    iosBundleId: 'com.mimio.mimio',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCBgemxkFi8AIV1iE66rNQbGygJtrsB8-Q',
    appId: '1:1088818781536:ios:7b12914714200fde881205',
    messagingSenderId: '1088818781536',
    projectId: 'mimio-f4bb7',
    storageBucket: 'mimio-f4bb7.firebasestorage.app',
    iosClientId: '1088818781536-6epk3ova7ji3shma956ds91iq81rcqsd.apps.googleusercontent.com',
    iosBundleId: 'com.mimio.mimio',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDxNWwy1prByBH0UmoNEAhaQrbvNPgVTmE',
    appId: '1:1088818781536:web:3377a23237fc7b04881205',
    messagingSenderId: '1088818781536',
    projectId: 'mimio-f4bb7',
    authDomain: 'mimio-f4bb7.firebaseapp.com',
    storageBucket: 'mimio-f4bb7.firebasestorage.app',
    measurementId: 'G-WVP5BKGBRJ',
  );
}
