import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raksha/pages/authpage.dart';
import 'package:raksha/pages/loginpage.dart';
import 'package:raksha/pages/raksha.dart';
import 'package:raksha/utils/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFEFF2F9),
      statusBarIconBrightness: Brightness.dark));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      home: AuthPage(), // Set Raksha() as the home widget
      theme: ThemeData(
        scaffoldBackgroundColor: Color(ColorsValue().primary),
        appBarTheme: const AppBarTheme(
          color: Color.fromARGB(238, 234, 59, 59),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.black.withOpacity(0),
        ),
      ),
    );

  }
}
