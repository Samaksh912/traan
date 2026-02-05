import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart'; // REQUIRED: Add geolocator to pubspec.yaml
import 'dart:math' as math;

// Data Model
class SafetyZone {
  final String name;
  final String state;
  final int year;
  final String safetyCategory;
  final double totalCrimes;
  final double safetyScore;
  final LatLng center;
  final List<LatLng> boundary;

  SafetyZone({
    required this.name,
    required this.state,
    required this.year,
    required this.safetyCategory,
    required this.totalCrimes,
    required this.safetyScore,
    required this.center,
    required this.boundary,
  });

  Color get baseColor {
    String category = safetyCategory.toLowerCase();
    if (category == 'safe') return Colors.green;
    if (category == 'moderate') return Colors.orange;
    if (category == 'unsafe') return Colors.red;
    return Colors.grey;
  }

  Color get borderColor {
    String category = safetyCategory.toLowerCase();
    if (category == 'safe') return Colors.green.shade900;
    if (category == 'moderate') return Colors.deepOrange.shade900;
    if (category == 'unsafe') return Colors.red.shade900;
    return Colors.grey.shade900;
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<SafetyZone> _allZones = [];
  List<SafetyZone> _visibleZones = [];
  bool _isLoading = true;
  bool _isLocating = false; // Loading state for GPS
  Set<String> _selectedCategories = {'Safe', 'Moderate', 'Unsafe'};

  // Track if we are in "Focused" mode
  bool get _isFocusedMode => _visibleZones.length == 1;

  final Map<String, LatLng> _stateCenters = GeoData.stateCoordinates;

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyData() async {
    try {
      final rawData = await rootBundle.loadString('assets/final_safety_scores.csv');

      List<List<dynamic>> csvData = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(rawData);

      // Handle generic newline issues
      if (csvData.length == 1) {
        List<String> lines = rawData.split('\n');
        if (lines.length <= 1) lines = rawData.split('\r\n');
        if (lines.length <= 1) lines = rawData.split('\r');

        csvData = [];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          var row = const CsvToListConverter(shouldParseNumbers: false).convert(line);
          if (row.isNotEmpty) csvData.add(row[0]);
        }
      }

      if (csvData.isEmpty || csvData.length <= 1) {
        setState(() => _isLoading = false);
        return;
      }

      Map<String, List<dynamic>> latestDistrictData = {};

      for (int i = 1; i < csvData.length; i++) {
        var row = csvData[i];
        if (row.length < 13) continue;

        String state = _normalizeName(row[0]);
        String district = _normalizeName(row[1]);

        if (district.contains('TOTAL') || district == 'ZZ') continue;

        int year = int.tryParse(row[2].toString().split('.')[0]) ?? 0;
        String key = "${state}_$district";

        if (!latestDistrictData.containsKey(key) ||
            year > (int.tryParse(latestDistrictData[key]![2].toString().split('.')[0]) ?? 0)) {
          latestDistrictData[key] = row;
        }
      }

      List<SafetyZone> zones = [];
      latestDistrictData.forEach((key, row) {
        String state = _normalizeName(row[0]);
        String district = _normalizeName(row[1]);

        if (district.contains('RLY') || district.contains('RAILWAY')) return;

        LatLng center = _getBestCoordinates(state, district);

        String safetyCategory = row[12].toString().trim();
        if (safetyCategory.isNotEmpty) {
          safetyCategory = safetyCategory[0].toUpperCase() +
              safetyCategory.substring(1).toLowerCase();
        }

        zones.add(SafetyZone(
          name: district,
          state: row[0].toString(),
          year: int.tryParse(row[2].toString().split('.')[0]) ?? 0,
          totalCrimes: double.tryParse(row[10].toString()) ?? 0,
          safetyScore: double.tryParse(row[11].toString()) ?? 0,
          safetyCategory: safetyCategory,
          center: center,
          boundary: _generateCircularBoundary(center, 0.3),
        ));
      });

      setState(() {
        _allZones = zones;
        _resetView();
        _isLoading = false;
      });

    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _normalizeName(dynamic input) {
    if (input == null) return "";
    return input.toString().toUpperCase().trim()
        .replaceAll(' UT', '')
        .replaceAll(' (UT)', '')
        .replaceAll('&', 'AND');
  }

  LatLng _getBestCoordinates(String state, String district) {
    if (GeoData.districtCoordinates.containsKey(district)) {
      return GeoData.districtCoordinates[district]!;
    }
    for (var key in GeoData.districtCoordinates.keys) {
      if (district.contains(key) || key.contains(district)) {
        return GeoData.districtCoordinates[key]!;
      }
    }
    if (_stateCenters.containsKey(state)) {
      LatLng stateCenter = _stateCenters[state]!;
      int hash = district.hashCode;
      double latOffset = ((hash % 100) - 50) / 100.0;
      double lngOffset = (((hash >> 4) % 100) - 50) / 100.0;
      return LatLng(stateCenter.latitude + latOffset, stateCenter.longitude + lngOffset);
    }
    return LatLng(20.5937, 78.9629);
  }

  List<LatLng> _generateCircularBoundary(LatLng center, double radiusDegrees) {
    List<LatLng> points = [];
    const int numberOfPoints = 24;
    for (int i = 0; i < numberOfPoints; i++) {
      double angle = (i * 360 / numberOfPoints) * math.pi / 180;
      double lat = center.latitude + radiusDegrees * math.cos(angle);
      double lng = center.longitude + radiusDegrees * math.sin(angle);
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  // --- LOCATION SERVICES ---

  Future<void> _handleFindNearestDistrict() async {
    setState(() => _isLocating = true);

    try {
      // 1. Check Service Status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      // 3. Get Position
      Position position = await Geolocator.getCurrentPosition();
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      // 4. Find Nearest Zone
      SafetyZone? nearestZone;
      double minDistance = double.infinity;
      const Distance distanceCalculator = Distance();

      for (var zone in _allZones) {
        double dist = distanceCalculator.as(
          LengthUnit.Meter,
          userLocation,
          zone.center,
        );

        if (dist < minDistance) {
          minDistance = dist;
          nearestZone = zone;
        }
      }

      // 5. Highlight Nearest
      if (nearestZone != null) {
        // Isolate logic
        _isolateZone(nearestZone);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are near ${nearestZone.name} (${(minDistance/1000).toStringAsFixed(1)} km away)'),
            backgroundColor: Colors.blue.shade900,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }


  // --- FOCUS & SEARCH LOGIC ---

  void _resetView() {
    setState(() {
      _searchController.clear();
      _visibleZones = _allZones
          .where((zone) => _selectedCategories.contains(zone.safetyCategory))
          .toList();
    });
  }

  void _performSearch() {
    String query = _searchController.text.trim().toUpperCase();
    FocusScope.of(context).unfocus();

    if (query.isEmpty) {
      _resetView();
      return;
    }

    List<SafetyZone> results = _allZones.where((zone) {
      return zone.name.contains(query);
    }).toList();

    setState(() {
      _visibleZones = results;
    });

    if (results.isNotEmpty) {
      _mapController.move(results.first.center, 11.0);
      if (results.length == 1) {
        _showZoneDetails(results.first);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No district found matching "$query"')),
      );
    }
  }

  void _isolateZone(SafetyZone zone) {
    setState(() {
      _searchController.text = zone.name;
      _visibleZones = [zone]; // Isolate strictly
      _mapController.move(zone.center, 11.0);
    });
    // Optional delay to let map move before showing sheet
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) _showZoneDetails(zone);
    });
  }

  void _toggleCategory(String category) {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _visibleZones = _allZones
          .where((zone) => _selectedCategories.contains(zone.safetyCategory))
          .toList();
    });
  }

  // --- UI BUILDERS ---

  void _showZoneDetails(SafetyZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                Icon(_getIconForCategory(zone.safetyCategory),
                    color: zone.borderColor, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(zone.state, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(zone.safetyCategory.toUpperCase()),
                  backgroundColor: zone.baseColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: zone.borderColor, fontWeight: FontWeight.bold),
                )
              ],
            ),
            Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBox("Safety Score", "${zone.safetyScore.toStringAsFixed(1)}/100"),
                _buildStatBox("Total Crimes", "${zone.totalCrimes.toInt()}"),
                _buildStatBox("Year", "${zone.year}"),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.check),
              label: Text("Done"),
              style: ElevatedButton.styleFrom(
                backgroundColor: zone.borderColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'safe': return Icons.shield_outlined;
      case 'moderate': return Icons.warning_amber_rounded;
      case 'unsafe': return Icons.dangerous_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(20.5937, 78.9629),
              zoom: 5,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, point) {
                FocusScope.of(context).unfocus();

                for (var zone in _visibleZones) {
                  final double dist = math.sqrt(
                      math.pow(point.latitude - zone.center.latitude, 2) +
                          math.pow(point.longitude - zone.center.longitude, 2)
                  );
                  if (dist < 0.3) {
                    _isolateZone(zone);
                    break;
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolygonLayer(
                polygons: _visibleZones.map((zone) {
                  final double opacity = _isFocusedMode ? 0.85 : 0.45;
                  return Polygon(
                    points: zone.boundary,
                    color: zone.baseColor.withOpacity(opacity),
                    borderColor: zone.borderColor,
                    borderStrokeWidth: _isFocusedMode ? 3.0 : 1.5,
                    isFilled: true,
                  );
                }).toList(),
              ),
            ],
          ),

          // TOP BAR
          Positioned(
            top: padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search district...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close, color: Colors.grey),
                        onPressed: _resetView,
                      )
                          : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (val) {
                      if (val.isEmpty) setState(() {});
                    },
                    textInputAction: TextInputAction.search,
                  ),
                ),

                SizedBox(height: 10),

                if (!_isFocusedMode && _searchController.text.isEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Safe', Colors.green),
                        SizedBox(width: 8),
                        _filterChip('Moderate', Colors.orange),
                        SizedBox(width: 8),
                        _filterChip('Unsafe', Colors.red),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // NEW "MY LOCATION" BUTTON
          // Positioned above the bottom panel
          if (!_isFocusedMode)
            Positioned(
              bottom: padding.bottom + 100, // Above the legend
              right: 16,
              child: FloatingActionButton(
                onPressed: _isLocating ? null : _handleFindNearestDistrict,
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade900,
                child: _isLocating
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location),
              ),
            ),

          // BOTTOM BAR (Legend & Stats)
          if (!_isFocusedMode)
            Positioned(
              bottom: padding.bottom + 20,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Safety Levels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey[700])),
                        SizedBox(height: 6),
                        _legendItem(Colors.green, 'Safe'),
                        _legendItem(Colors.orange, 'Moderate'),
                        _legendItem(Colors.red, 'Unsafe'),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(blurRadius: 8, color: Colors.blue.withOpacity(0.3))],
                    ),
                    child: Text(
                      '${_visibleZones.length} Zones',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // BACK TO MAP Button
          if (_isFocusedMode)
            Positioned(
              bottom: padding.bottom + 20,
              right: 16,
              left: 16,
              child: ElevatedButton.icon(
                onPressed: _resetView,
                icon: Icon(Icons.map),
                label: Text("Show All Districts"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color) {
    bool isSelected = _selectedCategories.contains(label);
    return GestureDetector(
      onTap: () => _toggleCategory(label),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        )),
      ),
    );
  }
}

class GeoData {
  static final Map<String, LatLng> stateCoordinates = {
    "ANDHRA PRADESH": LatLng(15.9129, 79.7400),
    "ARUNACHAL PRADESH": LatLng(28.2180, 94.7278),
    "ASSAM": LatLng(26.2006, 92.9376),
    "BIHAR": LatLng(25.0961, 85.3131),
    "CHHATTISGARH": LatLng(21.2787, 81.8661),
    "GOA": LatLng(15.2993, 74.1240),
    "GUJARAT": LatLng(22.2587, 71.1924),
    "HARYANA": LatLng(29.0588, 76.0856),
    "HIMACHAL PRADESH": LatLng(31.1048, 77.1734),
    "JAMMU AND KASHMIR": LatLng(33.7782, 76.5762),
    "JHARKHAND": LatLng(23.6102, 85.2799),
    "KARNATAKA": LatLng(15.3173, 75.7139),
    "KERALA": LatLng(10.8505, 76.2711),
    "MADHYA PRADESH": LatLng(22.9734, 78.6569),
    "MAHARASHTRA": LatLng(19.7515, 75.7139),
    "MANIPUR": LatLng(24.6637, 93.9063),
    "MEGHALAYA": LatLng(25.4670, 91.3662),
    "MIZORAM": LatLng(23.1645, 92.9376),
    "NAGALAND": LatLng(26.1584, 94.5624),
    "ODISHA": LatLng(20.9517, 85.0985),
    "PUNJAB": LatLng(31.1471, 75.3412),
    "RAJASTHAN": LatLng(27.0238, 74.2179),
    "SIKKIM": LatLng(27.5330, 88.5122),
    "TAMIL NADU": LatLng(11.1271, 78.6569),
    "TRIPURA": LatLng(23.9408, 91.9882),
    "UTTAR PRADESH": LatLng(26.8467, 80.9462),
    "UTTARAKHAND": LatLng(30.0668, 79.0193),
    "WEST BENGAL": LatLng(22.9868, 87.8550),
    "A AND N ISLANDS": LatLng(11.7401, 92.6586),
    "CHANDIGARH": LatLng(30.7333, 76.7794),
    "D AND N HAVELI": LatLng(20.1809, 73.0169),
    "DAMAN AND DIU": LatLng(20.4283, 72.8397),
    "DELHI": LatLng(28.7041, 77.1025),
    "LAKSHADWEEP": LatLng(10.5667, 72.6417),
    "PUDUCHERRY": LatLng(11.9416, 79.8083)
  };

  static final Map<String, LatLng> districtCoordinates = {
    "ADILABAD": LatLng(19.6773, 78.5320),
    "ANANTAPUR": LatLng(14.6819, 77.6006),
    "CHITTOOR": LatLng(13.2172, 79.1003),
    "CUDDAPAH": LatLng(14.4673, 78.8242),
    "EAST GODAVARI": LatLng(16.9891, 82.2475),
    "GUNTUR": LatLng(16.3067, 80.4365),
    "HYDERABAD CITY": LatLng(17.3850, 78.4867),
    "KARIMNAGAR": LatLng(18.4386, 79.1288),
    "KHAMMAM": LatLng(17.2473, 80.1514),
    "KRISHNA": LatLng(16.1808, 81.1303),
    "KURNOOL": LatLng(15.8281, 78.0373),
    "MAHABOOBNAGAR": LatLng(16.7488, 78.0035),
    "MEDAK": LatLng(18.0485, 78.2656),
    "NALGONDA": LatLng(17.0500, 79.2667),
    "NELLORE": LatLng(14.4426, 79.9865),
    "NIZAMABAD": LatLng(18.6725, 78.0941),
    "PRAKASAM": LatLng(15.5057, 80.0499),
    "RANGA REDDY": LatLng(17.3457, 77.9861),
    "SRIKAKULAM": LatLng(18.3064, 83.8923),
    "VISAKHAPATNAM": LatLng(17.6868, 83.2185),
    "VIZIANAGARAM": LatLng(18.1062, 83.4189),
    "WARANGAL": LatLng(17.9689, 79.5941),
    "WEST GODAVARI": LatLng(16.7107, 81.0952),
    "MUMBAI": LatLng(19.0760, 72.8777),
    "MUMBAI SUBURBAN": LatLng(19.1676, 72.8562),
    "THANE": LatLng(19.2183, 72.9781),
    "PUNE": LatLng(18.5204, 73.8567),
    "NAGPUR": LatLng(21.1458, 79.0882),
    "NASHIK": LatLng(19.9975, 73.7898),
    "AURANGABAD": LatLng(19.8762, 75.3433),
    "BANGALORE URBAN": LatLng(12.9716, 77.5946),
    "BANGALORE RURAL": LatLng(13.2384, 77.7077),
    "MYSORE": LatLng(12.2958, 76.6394),
    "CHENNAI": LatLng(13.0827, 80.2707),
    "COIMBATORE": LatLng(11.0168, 76.9558),
    "MADURAI": LatLng(9.9252, 78.1198),
    "KOLKATA": LatLng(22.5726, 88.3639),
    "HOWRAH": LatLng(22.5958, 88.2636),
    "LUCKNOW": LatLng(26.8467, 80.9462),
    "KANPUR": LatLng(26.4499, 80.3319),
    "AGRA": LatLng(27.1767, 78.0081),
    "VARANASI": LatLng(25.3176, 82.9739),
    "GHAZIABAD": LatLng(28.6692, 77.4538),
    "JAIPUR": LatLng(26.9124, 75.7873),
    "JODHPUR": LatLng(26.2389, 73.0243),
    "AHMEDABAD": LatLng(23.0225, 72.5714),
    "SURAT": LatLng(21.1702, 72.8311),
    "VADODARA": LatLng(22.3072, 73.1812),
    "RAJKOT": LatLng(22.3039, 70.8022),
    "BHOPAL": LatLng(23.2599, 77.4126),
    "INDORE": LatLng(22.7196, 75.8577),
    "PATNA": LatLng(25.5941, 85.1376),
    "LUDHIANA": LatLng(30.9010, 75.8573),
    "AMRITSAR": LatLng(31.6340, 74.8723),
    "THIRUVANANTHAPURAM": LatLng(8.5241, 76.9366),
    "KOCHI": LatLng(9.9312, 76.2673),
    "RAIPUR": LatLng(21.2514, 81.6296),
    "RANCHI": LatLng(23.3441, 85.3096),
    "GUWAHATI": LatLng(26.1445, 91.7362),
    "DEHRADUN": LatLng(30.3165, 78.0322),
    "SHIMLA": LatLng(31.1048, 77.1734),
    "SRINAGAR": LatLng(34.0837, 74.7973),
    "JAMMU": LatLng(32.7266, 74.8570),
    "PANAJI": LatLng(15.4909, 73.8278),
  };
}