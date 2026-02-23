
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxep0oDjXlcZpdR76yz_It9YfhO0jvlO8',
    appId: '1:174831976565:web:a6b3d4325e3044e2c6783c',
    messagingSenderId: '174831976565',
    projectId: 'amc303-4f725',
    authDomain: 'amc303-4f725.firebaseapp.com',
    storageBucket: 'amc303-4f725.firebasestorage.app',
    measurementId: 'G-KRVD6RT0MN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBosdqTjsyrTY9vwzgrr8rHuRX9Ud-w6fk',
    appId: '1:174831976565:android:1b586e3a013eb5ccc6783c',
    messagingSenderId: '174831976565',
    projectId: 'amc303-4f725',
    storageBucket: 'amc303-4f725.firebasestorage.app',
  );
}
