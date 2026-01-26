import 'package:boxicons/boxicons.dart';
import 'package:flutter/material.dart';
import 'package:raksha/Home/home.dart';
import 'package:raksha/tools/tools.dart';
import 'package:raksha/utils/colors.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../Map/map.dart';
import '../community/community.dart';

class Raksha extends StatefulWidget {
  @override
  State<Raksha> createState() => _RakshaState();
}

class _RakshaState extends State<Raksha> {
  List pages = [
    const HomePage(),
    const MapPage(),
    const Text("Bot"),
    const ToolsPage(),
    const CommunityPage(),
  ];

  var _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBody: true,
        body: pages[_currentIndex],
        bottomNavigationBar: CurvedNavigationBar(
          color: Colors.black87,
          index: _currentIndex,
          backgroundColor: Color(ColorsValue().primary),
          height: 60,
          items: [
            Icon(
              Boxicons.bx_home,
              color: _currentIndex == 0 ? Color(ColorsValue().secondary) : Colors.grey,
            ),
            Icon(
              Boxicons.bx_map,
              color: _currentIndex == 1 ? Color(ColorsValue().secondary) : Colors.grey,
            ),
            Icon(
              Boxicons.bx_bot,
              color: _currentIndex == 2 ? Color(ColorsValue().secondary) : Colors.grey,
            ),
            Icon(
              Boxicons.bx_shield,
              color: _currentIndex == 3 ? Color(ColorsValue().secondary) : Colors.grey,
            ),
            Icon(
              Boxicons.bx_group,
              color: _currentIndex == 4 ? Color(ColorsValue().secondary) : Colors.grey,
            ),
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        // Add floating button only on Map page
        floatingActionButton: _currentIndex == 1
            ? FloatingActionButton(
          onPressed: () {
            // Center map to India
          },
          child: Icon(Icons.my_location),
          backgroundColor: Colors.blue,
        )
            : null,

    );
  }
}