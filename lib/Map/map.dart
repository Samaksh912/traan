import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
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

  Color get fillColor {
    String category = safetyCategory.toLowerCase();
    if (category == 'safe') return Colors.green.withOpacity(0.5);
    if (category == 'moderate') return Colors.orange.withOpacity(0.5);
    if (category == 'unsafe') return Colors.red.withOpacity(0.5);
    return Colors.grey.withOpacity(0.4);
  }

  Color get borderColor {
    String category = safetyCategory.toLowerCase();
    if (category == 'safe') return Colors.green.shade800;
    if (category == 'moderate') return Colors.orange.shade900;
    if (category == 'unsafe') return Colors.red.shade900;
    return Colors.grey.shade800;
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  List<SafetyZone> _allZones = [];
  List<SafetyZone> _visibleZones = [];
  bool _isLoading = true;
  Set<String> _selectedCategories = {'Safe', 'Moderate', 'Unsafe'};

  // Cache for State Centers to avoid re-parsing constantly
  final Map<String, LatLng> _stateCenters = GeoData.stateCoordinates;

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  Future<void> _loadSafetyData() async {
    try {
      print('Starting to load CSV data...');
      final rawData = await rootBundle.loadString('assets/final_safety_scores.csv');
      print('CSV file loaded, size: ${rawData.length} characters');

      // Parse CSV with explicit settings to handle different line endings
      List<List<dynamic>> csvData = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(rawData);

      print('CSV parsed, total rows: ${csvData.length}');

      // If still only 1 row, try splitting manually by newlines
      if (csvData.length == 1) {
        print('Only 1 row detected, trying manual line splitting...');

        // Try different line ending patterns
        List<String> lines = rawData.split('\n');
        if (lines.length <= 1) {
          lines = rawData.split('\r\n');
        }
        if (lines.length <= 1) {
          lines = rawData.split('\r');
        }

        print('Found ${lines.length} lines after manual split');

        // Re-parse each line
        csvData = [];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          var row = const CsvToListConverter(shouldParseNumbers: false).convert(line);
          if (row.isNotEmpty) {
            csvData.add(row[0]);
          }
        }

        print('After re-parsing: ${csvData.length} rows');
      }

      if (csvData.isEmpty || csvData.length <= 1) {
        print('ERROR: CSV data is empty or has only headers!');
        setState(() => _isLoading = false);
        return;
      }

      // Print first row (headers)
      print('CSV Headers (first 5): ${csvData[0].take(5).toList()}');

      // Print a sample data row
      if (csvData.length > 1) {
        print('Sample row (first 5 cols): ${csvData[1].take(5).toList()}');
        print('Row length: ${csvData[1].length}');
      }

      // Map to store only the LATEST year data for each district (Key: "STATE_DISTRICT")
      Map<String, List<dynamic>> latestDistrictData = {};

      // 1. Filter for latest year
      for (int i = 1; i < csvData.length; i++) {
        var row = csvData[i];

        // Check minimum required columns
        if (row.length < 13) {
          print('Skipping row $i: insufficient columns (${row.length})');
          continue;
        }

        String state = _normalizeName(row[0]);
        String district = _normalizeName(row[1]);

        // Skip aggregates
        if (district.contains('TOTAL') || district == 'ZZ') {
          print('Skipping aggregate: $district');
          continue;
        }

        // Normalize Year
        int year = int.tryParse(row[2].toString().split('.')[0]) ?? 0;

        String key = "${state}_$district";

        if (!latestDistrictData.containsKey(key) ||
            year > (int.tryParse(latestDistrictData[key]![2].toString().split('.')[0]) ?? 0)) {
          latestDistrictData[key] = row;
        }
      }

      print('Filtered to ${latestDistrictData.length} unique districts');

      // 2. Create SafetyZone objects
      List<SafetyZone> zones = [];
      int processedCount = 0;
      int skippedCount = 0;

      latestDistrictData.forEach((key, row) {
        String state = _normalizeName(row[0]);
        String district = _normalizeName(row[1]);

        // Skip railway and special administrative units
        if (district.contains('RLY') || district.contains('RAILWAY')) {
          skippedCount++;
          return;
        }

        // Logic: Try exact match -> Try fuzzy match -> Fallback to State Center + Offset
        LatLng center = _getBestCoordinates(state, district);

        // Normalize safety category
        String safetyCategory = row[12].toString().trim();
        // Capitalize first letter only
        if (safetyCategory.isNotEmpty) {
          safetyCategory = safetyCategory[0].toUpperCase() +
              safetyCategory.substring(1).toLowerCase();
        }

        print('Processing: $district, $state -> Category: $safetyCategory, Center: ${center.latitude}, ${center.longitude}');

        zones.add(SafetyZone(
          name: district,
          state: row[0].toString(),
          year: int.tryParse(row[2].toString().split('.')[0]) ?? 0,
          totalCrimes: double.tryParse(row[10].toString()) ?? 0,
          safetyScore: double.tryParse(row[11].toString()) ?? 0,
          safetyCategory: safetyCategory,
          center: center,
          // INCREASED RADIUS: 0.3 degrees (~33km) instead of 0.11
          boundary: _generateCircularBoundary(center, 0.3),
        ));

        processedCount++;

        // Only print first 5 to avoid spam
        if (processedCount <= 5) {
          print('Added zone: $district ($safetyCategory)');
        }
      });

      print('Processed: $processedCount zones, Skipped: $skippedCount');
      print('Total zones created: ${zones.length}');

      setState(() {
        _allZones = zones;
        _updateVisibleZones();
        _isLoading = false;
      });

      print('Loaded ${zones.length} safety zones');
      print('Safe: ${zones.where((z) => z.safetyCategory.toLowerCase() == 'safe').length}');
      print('Moderate: ${zones.where((z) => z.safetyCategory.toLowerCase() == 'moderate').length}');
      print('Unsafe: ${zones.where((z) => z.safetyCategory.toLowerCase() == 'unsafe').length}');

    } catch (e, stackTrace) {
      print('ERROR loading data: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);

      // Show error dialog to user
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error Loading Data'),
            content: Text('Failed to load safety data: $e\n\nPlease check that final_safety_scores.csv is in the assets folder and pubspec.yaml is configured correctly.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Helper to standardise names for lookup
  String _normalizeName(dynamic input) {
    if (input == null) return "";
    return input.toString().toUpperCase().trim()
        .replaceAll(' UT', '')
        .replaceAll(' (UT)', '')
        .replaceAll('&', 'AND');
  }

  LatLng _getBestCoordinates(String state, String district) {
    // 1. Check Exact District Match
    if (GeoData.districtCoordinates.containsKey(district)) {
      return GeoData.districtCoordinates[district]!;
    }

    // 2. Check Partial District Match (e.g. "HYDERABAD CITY" -> "HYDERABAD")
    for (var key in GeoData.districtCoordinates.keys) {
      if (district.contains(key) || key.contains(district)) {
        return GeoData.districtCoordinates[key]!;
      }
    }

    // 3. Fallback: Use State Center + Deterministic Random Offset
    // This ensures all districts in a state appear clustered but not overlapping
    if (_stateCenters.containsKey(state)) {
      LatLng stateCenter = _stateCenters[state]!;

      // Use hashcode to generate a consistent "random" offset for this district
      int hash = district.hashCode;
      double latOffset = ((hash % 100) - 50) / 100.0; // +/- 0.5 degrees (INCREASED)
      double lngOffset = (((hash >> 4) % 100) - 50) / 100.0;

      return LatLng(stateCenter.latitude + latOffset, stateCenter.longitude + lngOffset);
    }

    // 4. Absolute Fallback (Center of India)
    return LatLng(20.5937, 78.9629);
  }

  List<LatLng> _generateCircularBoundary(LatLng center, double radiusDegrees) {
    List<LatLng> points = [];
    // Increased to 24 points for smoother circles
    const int numberOfPoints = 24;
    for (int i = 0; i < numberOfPoints; i++) {
      double angle = (i * 360 / numberOfPoints) * math.pi / 180;
      double lat = center.latitude + radiusDegrees * math.cos(angle);
      double lng = center.longitude + radiusDegrees * math.sin(angle);
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  void _updateVisibleZones() {
    setState(() {
      _visibleZones = _allZones
          .where((zone) => _selectedCategories.contains(zone.safetyCategory))
          .toList();
    });
    print('Visible zones: ${_visibleZones.length}');
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _updateVisibleZones();
    });
  }

  void _showZoneDetails(SafetyZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIconForCategory(zone.safetyCategory),
                    color: zone.borderColor, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('${zone.state} • Year ${zone.year}', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 30),
            _buildDetailRow("Safety Status", zone.safetyCategory.toUpperCase(), zone.borderColor),
            _buildDetailRow("Safety Score", "${zone.safetyScore.toStringAsFixed(2)} / 100", Colors.blue.shade700),
            _buildDetailRow("Crimes Reported", "${zone.totalCrimes.toInt()}", Colors.red.shade700),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mapController.move(zone.center, 10);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: zone.borderColor,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Focus Map Here", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'safe': return Icons.check_circle_outline;
      case 'moderate': return Icons.warning_amber_rounded;
      case 'unsafe': return Icons.dangerous_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('India Safety Zones Map'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
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
                // Simple hit test with UPDATED radius
                for (var zone in _visibleZones) {
                  final double dist = math.sqrt(
                      math.pow(point.latitude - zone.center.latitude, 2) +
                          math.pow(point.longitude - zone.center.longitude, 2)
                  );
                  if (dist < 0.3) { // Updated to match new radius
                    _showZoneDetails(zone);
                    break;
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolygonLayer(
                polygons: _visibleZones.map((zone) => Polygon(
                  points: zone.boundary,
                  color: zone.fillColor,
                  borderColor: zone.borderColor,
                  borderStrokeWidth: 2.0, // Increased border width
                  isFilled: true,
                )).toList(),
              ),
            ],
          ),

          // Filters
          Positioned(
            top: 10,
            left: 10, right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _filterChip('Safe', Colors.green),
                    _filterChip('Moderate', Colors.orange),
                    _filterChip('Unsafe', Colors.red),
                  ],
                ),
              ),
            ),
          ),

          // Count Indicator
          Positioned(
            bottom: 20, left: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
              ),
              child: Text('${_visibleZones.length} Districts Visible',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

          // Legend
          Positioned(
            bottom: 60, left: 20,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(height: 6),
                  _legendItem(Colors.green, 'Safe'),
                  _legendItem(Colors.orange, 'Moderate'),
                  _legendItem(Colors.red, 'Unsafe'),
                ],
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
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5),
              border: Border.all(width: 1.5),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color) {
    bool isSelected = _selectedCategories.contains(label);
    return GestureDetector(
      onTap: () => _toggleCategory(label),
      child: Chip(
        label: Text(label, style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        )),
        backgroundColor: isSelected ? color : Colors.grey[200],
      ),
    );
  }
}

// ==========================================
// STATIC GEOGRAPHICAL DATA (For Lookup)
// ==========================================
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
    // Andhra Pradesh
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

    // Major Metros & Cities (Mapping key districts)
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