import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:boxicons/boxicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:raksha/models/sos.dart';
import 'package:raksha/pages/profile.dart';
import 'package:raksha/utils/colors.dart';
import 'package:raksha/widgets/cards.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                              Text("Home",
                                  style: TextStyle(
                                    color: Color(ColorsValue().h5),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  )),
                              const SizedBox(
                                height: 5,
                              ),

                            ],
                          )
                        ],
                      ),
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
                          try {
                            // Check if location services are enabled
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              print("Location services are disabled");
                              return;
                            }

                            // Request location permission
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) {
                                print("Location permissions denied");
                                return;
                              }
                            }

                            if (permission == LocationPermission.deniedForever) {
                              print("Location permissions permanently denied");
                              return;
                            }

                            // Get current location
                            Position position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );

                            // Create Google Maps link
                            String locationUrl = "https://maps.google.com/?q=${position.latitude},${position.longitude}";

                            // Create message
                            String message = "Emergency! My current location: $locationUrl";

                            // Share to WhatsApp using wa.me link
                            String phoneNumber = "919627320508"; // Add country code (91 for India)
                            String whatsappUrl = "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}";

                            final Uri uri = Uri.parse(whatsappUrl);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);

                          } catch (e) {
                            print("Error sharing location: $e");
                          }
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
                    height: 30,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                          onTap: () {
                            _callNumber("7058384971");
                          },
                          child: HelpLineCards(
                            title: "Police 100",
                            assetImg: "assets/images/pol.png",
                            number: "100",
                          )),
                      InkWell(
                          onTap: () {
                            _callNumber("9307227317");
                          },
                          child: HelpLineCards(
                            title: "Women Helpline",
                            assetImg: "assets/images/contact.png",
                            number: "100",
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
