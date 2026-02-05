import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raksha/pages/raksha.dart';
import 'package:raksha/utils/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );

  // Request location permission on app start
  await _requestLocationPermission();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFEFF2F9),
      statusBarIconBrightness: Brightness.dark));

  runApp(const MyApp());
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    await Geolocator.requestPermission();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raksha',
      debugShowCheckedModeBanner: false,
      home: Raksha(),
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