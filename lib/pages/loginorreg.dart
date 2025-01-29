import 'package:flutter/material.dart';
import 'package:raksha/pages/loginpage.dart';
import 'package:raksha/pages/registerpage.dart';

import '../services/authservice.dart';

class LoginorRegPage extends StatefulWidget {
  const LoginorRegPage({super.key});

  @override
  State<LoginorRegPage> createState() => _LoginorRegPageState();
}

class _LoginorRegPageState extends State<LoginorRegPage> {
  bool showLoginPage = true;

  // Toggle between Login and Register Page
  void togglePage() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: showLoginPage
            ? LoginPage(onTap: togglePage) // Pass togglePage to LoginPage
            : RegisterPage(), // Show RegisterPage when toggled
      ),
    );
  }
}
