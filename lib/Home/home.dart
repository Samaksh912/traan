import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:raksha/models/sos.dart';
import 'package:raksha/pages/profile.dart';
import 'package:raksha/utils/colors.dart';
import 'package:raksha/widgets/cards.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String name = "Loading...";
  String emergencyContact2 = "";

  @override
  void initState() {
    super.initState();
    _getUserName();
  }

  // Function to fetch the user's name from Firestore
  Future<void> _getUserName() async {
    User? user = FirebaseAuth.instance.currentUser; // Get the current logged-in user

    if (user != null) {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          name = userDoc['name'];
          emergencyContact2 = userDoc['emergencyContact2'];// Assuming 'name' is a field in the Firestore document
        });
      } else {
        setState(() {
          name = "User not found";
          emergencyContact2 = ""; // Handle the case where the document does not exist
        });
      }
    } else {
      setState(() {
        name = "User not logged in";
        emergencyContact2 = ""; // Handle the case where the user is not logged in
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.person, color: Color(ColorsValue().h5)),
                            onPressed: () {
                              // Directly navigate to ProfilePage without popping.
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProfilePage()),
                              );
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Column(
                            children: [
                              Text("Hello, $name",
                                  style: TextStyle(
                                    color: Color(ColorsValue().h5),
                                    fontSize: 20,
                                  )),
                              const SizedBox(
                                height: 5,
                              ),

                            ],
                          )
                        ],
                      ),
                      Row(
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),

                         ] ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 64,
                  ),
                  Text(
                    "Emergency!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 30,
                        color: Colors.black,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding: const EdgeInsets.all(0), // No padding
                    child: ClipOval(
                      child: InkWell(
                        splashColor: Colors.black54, // Add a splash effect if needed
                        onTap: () async {
                          SOS().sendSOSMessage("7058384971"); // Call the function to send an SOS SMS
                        },
                        child: Ink.image(
                          image: const AssetImage('assets/images/sos.png'),
                          height: 205,
                          width: 205,
                          fit: BoxFit.cover, // Ensures the image covers the entire circular area
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),



                  Text(
                    "Press the button to send SOS",
                    style: TextStyle(
                      color: Color(ColorsValue().h5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                          onTap: () {
                            _callNumber("123456789");
                          },
                          child: HelpLineCards(
                            title: "Police 100",
                            assetImg: "assets/images/pol.png",
                            number: "100",
                          )),
                      InkWell(
                          onTap: () {
                            _callNumber(emergencyContact2);
                          },
                          child: HelpLineCards(
                            title: "emergency contact",
                            assetImg: "assets/images/contact.png",
                            number:  emergencyContact2.isEmpty ? "Loading..." : emergencyContact2, // Display number if available,
                          ))
                    ],
                  )
                ],
              ),
            ),
          ),
        ));
  }

  _callNumber(String number) async {
//set the number here
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);
  }
}
