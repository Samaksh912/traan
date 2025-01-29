import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:raksha/pages/raksha.dart';

import '../Home/home.dart';
import '../pages/loginorreg.dart';

class AuthService{
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  void debugprint(String message){
    assert((){
      print(message);
      return true;
    }());
  }
  signinwithgoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? guser = await _googleSignIn.signIn();

      // Check if user is already signed in
      if (guser == null) {
        print("Google Sign-In was cancelled by the user.");
        return null; // User cancelled the login process
      }

      final GoogleSignInAuthentication gauth = await guser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gauth.accessToken,
        idToken: gauth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Explicitly navigate to HomePage after successful sign-in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Raksha()),
      );
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }


  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Disconnect the GoogleSignIn instance
      await _googleSignIn.disconnect();

      // Sign out from Google
      await _googleSignIn.signOut();

      debugPrint("User signed out successfully.");
    } catch (e) {
      debugPrint("Error during sign out: $e");
    }
  }

}



