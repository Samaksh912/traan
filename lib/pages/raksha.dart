import 'package:boxicons/boxicons.dart';
import 'package:flutter/material.dart';
import 'package:raksha/Home/home.dart';
import 'package:raksha/pages/MapPage.dart' as map;
import 'package:raksha/pages/audiopage.dart';
import 'package:raksha/tools/tools.dart';
import 'package:raksha/utils/colors.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../Map/map.dart';


class Raksha extends StatefulWidget {
  @override
  State<Raksha> createState() => _RakshaState();
}

class _RakshaState extends State<Raksha> {
  List<Widget> pages = [
    const HomePage(),
     const MapPage(),
    const AudioGuidePage(),
    const ToolsPage(),

  ];

  int _currentIndex = 0; // Using int instead of var for consistency

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: pages[_currentIndex], // Switch pages based on currentIndex
        bottomNavigationBar: CurvedNavigationBar(
          color: Colors.black87,
          index: _currentIndex, // Correct property to set the selected index
          backgroundColor: Color(ColorsValue().primary),
          height: 60, // Add height if necessary
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

          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
