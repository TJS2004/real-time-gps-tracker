import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart'; // Adjust path
import 'screens/login_screen.dart';  // Adjust path
import 'screens/map_screen.dart';    // Adjust path

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase core
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      // Start the app with the Splash Screen
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),

        // Login Screen Route
        '/login': (context) => const LoginPage(),

        // Map Screen Route (Requires argument)
        '/map': (context) {
          // Get the UID passed from the SplashScreen
          final uid = ModalRoute.of(context)!.settings.arguments as String?;

          // Fallback check: If the user ID is somehow missing, redirect to login
          if (uid == null) {
            // Optional: You could redirect back to login here for safety
            return const LoginPage();
          }

          // Pass the required userId to the MapScreen
          return MapScreen(userId: uid);
        },

        // '/register': (context) => const RegisterPage(), // Optional: Add if needed
      },
    );
  }
}