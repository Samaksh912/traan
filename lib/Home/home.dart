import 'package:path_provider/path_provider.dart';
import 'package:boxicons/boxicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:raksha/models/sos.dart';
import 'package:raksha/pages/profile.dart';
import 'package:raksha/utils/colors.dart';
import 'package:raksha/widgets/cards.dart';

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
                              Text("Hello, Madhura",
                                  style: TextStyle(
                                    color: Color(ColorsValue().h5),
                                    fontSize: 14,
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
                              Column(
                                children: [
                                  Text("Alan zone...",
                                      style: TextStyle(
                                        color: Color(ColorsValue().h5),
                                        fontSize: 14,
                                      )),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text("Safe Location",
                                      style: TextStyle(
                                        color: Color(ColorsValue().secondary),
                                        fontSize: 14,
                                      )),
                                ],
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Icon(
                                Boxicons.bxs_map,
                                color: Color(ColorsValue().secondary),
                              )
                            ],
                          ),
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
                          var externalStorageDirectories = await getExternalStorageDirectories();

                          if (externalStorageDirectories != null && externalStorageDirectories.isNotEmpty) {
                            String filePath = externalStorageDirectories[0].path + "/digambar.jpeg";
                            print(filePath);

                            SOS().sharePhotoToWhatsApp("7058384971", "http://file://$filePath");
                            print("file://$filePath");
                          } else {
                            print("External storage directory not found.");
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
