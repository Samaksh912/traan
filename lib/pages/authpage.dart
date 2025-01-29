import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:raksha/Home/home.dart';
import 'package:raksha/pages/loginpage.dart';
import 'package:raksha/pages/registerpage.dart';
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator(); // Show loading indicator if still waiting
          }
          if (snapshot.hasData) {
            return HomePage();  // Redirect to HomePage if user is signed in
          } else {
            return RegisterPage();  // Show RegisterPage if user is not signed in
          }
        },
      )

    );
  }
}
