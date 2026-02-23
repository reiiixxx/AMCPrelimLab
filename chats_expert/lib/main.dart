import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: ChatApp(),
    ),
  );
}

class ChatApp extends StatelessWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Persona AI Chat',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        cardColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Color(0xFF424242),
          surface: Colors.white,
          background: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}