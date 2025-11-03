import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    // Wait 3 seconds to show the splash screen
    Timer(const Duration(seconds: 3), () {
      // Check if a user is currently logged in
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is logged in, navigate to the Map Screen (home screen)
        // We use pushReplacementNamed here
        Navigator.pushReplacementNamed(context, '/map', arguments: user.uid);
      } else {
        // User is not logged in, navigate to the Login Screen
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo (optional)
            Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 100,
            ),
            SizedBox(height: 20),
            Text(
              "Welcome to Family Safety Tracker",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}