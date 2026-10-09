import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart'; // REQUIRED: Add geolocator to pubspec.yaml
import 'dart:math' as math;
import 'route_service.dart';
import 'safety_scorer.dart';
import 'safe_planner.dart';
import 'package:url_launcher/url_launcher.dart';

// Safest/Moderate may take up to this many times the fastest route's time.
const double _maxDetour = 3.0;

const String _kGoogleKey = String.fromEnvironment('GMAPS_KEY',
    defaultValue: '');

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

  // Data-quality helpers
  final Map<String, String> _stateOfDistrict = {};
  int _skippedNoLocation = 0;

  // --- Route planner state ---
  bool _routeMode = true; // directions-first screen
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  LatLng? _from;
  LatLng? _to;
  int _activeField = 0; // 0 = From, 1 = To
  List<SafetyZone> _suggestions = [];
  RouteMode _selectedMode = RouteMode.safest;
  List<RouteOption> _routes = [];
  Map<RouteMode, RouteOption> _picked = {};
  bool _routeLoading = false;
  SafetyScorer? _scorer;
  List<ZoneRisk> _zoneRisks = [];
  SafeRouter? _safeRouter; // built on first use
  final RouteService _routeService = RouteService(_kGoogleKey);

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyData() async {
    try {
      final rawData =
          await rootBundle.loadString('assets/final_safety_scores.csv');

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
          var row =
              const CsvToListConverter(shouldParseNumbers: false).convert(line);
          if (row.isNotEmpty) csvData.add(row[0]);
        }
      }

      if (csvData.isEmpty || csvData.length <= 1) {
        setState(() => _isLoading = false);
        return;
      }

      // Some CSV rows (2014/2015) have a blank State/UT. Learn each district's
      // state from rows that do have one, so those rows can be repaired.
      _stateOfDistrict.clear();
      for (int i = 1; i < csvData.length; i++) {
        final r = csvData[i];
        if (r.length < 13) continue;
        final s = _normalizeName(r[0]);
        if (s.isNotEmpty && s != '0' && s != 'NAN') {
          _stateOfDistrict.putIfAbsent(_normalizeName(r[1]), () => s);
        }
      }
      _skippedNoLocation = 0;

      Map<String, List<dynamic>> latestDistrictData = {};

      for (int i = 1; i < csvData.length; i++) {
        var row = csvData[i];
        if (row.length < 13) continue;

        String state = _stateFor(row);
        String district = _normalizeName(row[1]);

        if (district.contains('TOTAL') || district == 'ZZ') continue;
        if (district.isEmpty || district == 'NAN')
          continue; // blank rows would match every name

        int year = int.tryParse(row[2].toString().split('.')[0]) ?? 0;
        String key = "${state}_$district";

        if (!latestDistrictData.containsKey(key) ||
            year >
                (int.tryParse(
                        latestDistrictData[key]![2].toString().split('.')[0]) ??
                    0)) {
          latestDistrictData[key] = row;
        }
      }

      List<SafetyZone> zones = [];
      latestDistrictData.forEach((key, row) {
        String state = _stateFor(row);
        String district = _normalizeName(row[1]);

        if (district.contains('RLY') || district.contains('RAILWAY')) return;

        final LatLng? center = _getBestCoordinates(state, district);
        if (center == null) {
          // No trustworthy position (e.g. blank state in the CSV): do not draw
          // it or route through it.
          _skippedNoLocation++;
          return;
        }

        String safetyCategory = row[12].toString().trim();
        if (safetyCategory.isNotEmpty) {
          safetyCategory = safetyCategory[0].toUpperCase() +
              safetyCategory.substring(1).toLowerCase();
        }

        zones.add(SafetyZone(
          name: district,
          state: row[0].toString().trim().isEmpty ? state : row[0].toString(),
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
        _zoneRisks = _buildZoneRisks(zones);
        _scorer = SafetyScorer(_zoneRisks);
        print('Zones skipped (no usable location): $_skippedNoLocation');
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
    return input
        .toString()
        .toUpperCase()
        .trim()
        .replaceAll(' UT', '')
        .replaceAll(' (UT)', '')
        .replaceAll('&', 'AND');
  }

  String _stateFor(List<dynamic> row) {
    final s = _normalizeName(row[0]);
    if (s.isNotEmpty && s != '0' && s != 'NAN') return s;
    return _stateOfDistrict[_normalizeName(row[1])] ?? '';
  }

  // Newer / alternate spellings -> the name used in GeoData.districtCoordinates
  static const Map<String, String> _districtAliases = {
    'BENGALURU CITY': 'BANGALORE URBAN',
    'BENGALURU URBAN': 'BANGALORE URBAN',
    'BANGALORE CITY': 'BANGALORE URBAN',
    'BANGALORE COMMR.': 'BANGALORE URBAN',
    'BENGALURU RURAL': 'BANGALORE RURAL',
    'MYSURU': 'MYSORE',
    'MYSORE CITY': 'MYSORE',
    'HYDERABAD': 'HYDERABAD CITY',
    'CYBERABAD': 'RANGA REDDY',
    'COCHIN': 'KOCHI',
    'COCHIN CITY': 'KOCHI',
    'KOCHI CITY': 'KOCHI',
    'KOLKATA CITY': 'KOLKATA',
    'HOWRAH CITY': 'HOWRAH',
  };

  // Returns null when we have no trustworthy position for the district.
  LatLng? _getBestCoordinates(String state, String district) {
    final alias = _districtAliases[district];
    if (alias != null && GeoData.districtCoordinates.containsKey(alias)) {
      return GeoData.districtCoordinates[alias]!;
    }
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
      return LatLng(
          stateCenter.latitude + latOffset, stateCenter.longitude + lngOffset);
    }
    return null;
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
            content: Text(
                'You are near ${nearestZone.name} (${(minDistance / 1000).toStringAsFixed(1)} km away)'),
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

  // --- ROUTE PLANNER ---

  // Risk per zone = percentile rank of total crimes (0 = fewest, 1 = most).
  // "hot" matches the Moderate/Unsafe colours you see on the map.
  List<ZoneRisk> _buildZoneRisks(List<SafetyZone> zones) {
    final sorted = zones.map((z) => z.totalCrimes).toList()..sort();
    double percentile(double v) {
      if (sorted.length < 2) return 0.0;
      int lo = 0, hi = sorted.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (sorted[mid] < v) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo / (sorted.length - 1);
    }

    return zones
        .map((z) => ZoneRisk(
              z.center.latitude,
              z.center.longitude,
              percentile(z.totalCrimes),
              hot: z.safetyCategory == 'Moderate' ||
                  z.safetyCategory == 'Unsafe',
              level: z.safetyCategory == 'Unsafe'
                  ? 2
                  : (z.safetyCategory == 'Moderate' ? 1 : 0),
            ))
        .toList();
  }

  SafetyZone? _nearestZone(LatLng p) {
    SafetyZone? best;
    double bestDist = double.infinity;
    const Distance calc = Distance();
    for (final z in _allZones) {
      final d = calc.as(LengthUnit.Meter, p, z.center);
      if (d < bestDist) {
        bestDist = d;
        best = z;
      }
    }
    return best;
  }

  void _clearRoutes() {
    _routes = [];
    _picked = {};
  }

  void _openRouteMode() {
    _resetView(); // show all zones again
    setState(() {
      _routeMode = true;
      _activeField = 0;
    });
  }

  void _closeRouteMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _from = null;
      _to = null;
      _fromCtrl.clear();
      _toCtrl.clear();
      _suggestions = [];
      _clearRoutes();
    });
  }

  void _setPoint(bool isFrom, LatLng p, String label) {
    setState(() {
      if (isFrom) {
        _from = p;
        _fromCtrl.text = label;
        _activeField = 1;
      } else {
        _to = p;
        _toCtrl.text = label;
      }
      _suggestions = [];
      _clearRoutes();
    });
  }

  // Map tap while planning: first tap = From, second = To, then it replaces
  // whichever field was last selected.
  void _handleRouteTap(LatLng p) {
    final near = _nearestZone(p);
    final label = near == null
        ? 'Dropped pin'
        : 'Dropped pin near ${_titleCase(near.name)}';
    final bool isFrom = _from == null || (_to != null && _activeField == 0);
    _setPoint(isFrom, p, label);
  }

  // Typing only shows suggestions from zones on the map. The point is not set
  // until the user picks one.
  void _onRouteFieldChanged(int field, String text) {
    final q = text.trim().toUpperCase();
    setState(() {
      _activeField = field;
      if (field == 0) {
        _from = null;
      } else {
        _to = null;
      }
      _clearRoutes();
      if (q.length < 2) {
        _suggestions = [];
      } else {
        final matches = _allZones.where((z) => z.name.contains(q)).toList();
        matches.sort((a, b) {
          final sa = a.name.startsWith(q) ? 0 : 1;
          final sb = b.name.startsWith(q) ? 0 : 1;
          return sa != sb ? sa - sb : a.name.compareTo(b.name);
        });
        _suggestions = matches.take(6).toList();
      }
    });
  }

  void _selectSuggestion(SafetyZone z) {
    _setPoint(_activeField == 0, z.center, _placeLabel(z));
    FocusScope.of(context).unfocus();
    _mapController.move(z.center, 7.0);
  }

  void _swapPoints() {
    setState(() {
      final tp = _from;
      _from = _to;
      _to = tp;
      final tt = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = tt;
      _clearRoutes();
    });
  }

  Future<void> _findRoutes() async {
    final from = _from, to = _to, scorer = _scorer;
    if (from == null || to == null || scorer == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _routeLoading = true);
    try {
      _safeRouter ??= SafeRouter(
        scorer: scorer,
        planner: SafeCorridorPlanner(_zoneRisks),
        service: _routeService,
      );
      final routes = await _safeRouter!.candidates(from, to);
      if (routes.isEmpty) throw 'No route found between these points.';
      final picked = scorer.pick(routes, maxDetour: _maxDetour);
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _picked = picked;
      });
      _fitRoute();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not get route: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  void _selectMode(RouteMode m) {
    setState(() => _selectedMode = m);
    _fitRoute();
  }

  void _fitRoute() {
    final r = _picked[_selectedMode];
    if (r == null || r.points.isEmpty) return;
    // Leave room for the top panel and the floating summary card, but never
    // more than the screen can spare.
    final h = MediaQuery.of(context).size.height;
    _mapController.fitBounds(
      LatLngBounds.fromPoints(r.points),
      options: FitBoundsOptions(
        padding: EdgeInsets.fromLTRB(
            40, math.min(170.0, h * 0.2), 40, math.min(300.0, h * 0.4)),
      ),
    );
  }

  // One navigation colour for the selected route (risk colours are separate).
  Color _modeColor(RouteMode m) => Colors.blue.shade800;

  String _modeLabel(RouteMode m) {
    switch (m) {
      case RouteMode.safest:
        return 'Safest';
      case RouteMode.moderate:
        return 'Balanced';
      case RouteMode.fastest:
        return 'Fastest';
    }
  }

  String _fmtDuration(double seconds) {
    final mins = (seconds / 60).round();
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  String _titleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _placeLabel(SafetyZone z) => z.state.trim().isEmpty
      ? _titleCase(z.name)
      : '${_titleCase(z.name)}, ${_titleCase(z.state)}';

  Widget _pinDot(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
    );
  }

  Future<void> _useMyLocationAsFrom() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are disabled.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied.';
      }
      final pos = await Geolocator.getCurrentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      _setPoint(true, p, 'My location');
      _mapController.move(p, 8.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  String _fmtKm(double meters) {
    final km = meters / 1000;
    if (km < 100) return km.toStringAsFixed(1);
    return km
        .round()
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  Widget _routeField(TextEditingController c, String hint, int field) {
    return TextField(
      controller: c,
      onTap: () => setState(() => _activeField = field),
      onChanged: (v) => _onRouteFieldChanged(field, v),
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        prefixIcon: field == 0
            ? Icon(Icons.radio_button_checked,
                size: 18, color: Colors.blue.shade800)
            : Icon(Icons.location_on, size: 20, color: Colors.red.shade700),
        prefixIconConstraints: BoxConstraints(minWidth: 30),
        suffixIcon: field == 0
            ? IconButton(
                tooltip: 'Use current location',
                icon: Icon(Icons.my_location,
                    size: 20, color: Colors.blue.shade800),
                onPressed: _useMyLocationAsFrom,
              )
            : null,
      ),
    );
  }

  Widget _legendDot(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        SizedBox(width: 4),
        Text(t, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Widget _hintStrip() {
    final missing = _from == null || _to == null;
    return Row(
      children: [
        Expanded(
          child: Text(
            missing ? 'Search or tap the map' : 'Zone risk',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
          ),
        ),
        _legendDot(Colors.green, 'Low'),
        SizedBox(width: 10),
        _legendDot(Colors.orange, 'Moderate'),
        SizedBox(width: 10),
        _legendDot(Colors.red, 'High'),
      ],
    );
  }

  Widget _buildRouteTopPanel(double topPadding) {
    return Positioned(
      top: topPadding + 8,
      left: 10,
      right: 10,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Material(
                elevation: 3,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, 4, 2, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _routeField(_fromCtrl, 'Starting point', 0),
                                Divider(height: 1),
                                _routeField(_toCtrl, 'Where are you going?', 1),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Swap',
                                icon: Icon(Icons.swap_vert, size: 22),
                                onPressed: _swapPoints,
                              ),
                              if (_from != null || _to != null)
                                IconButton(
                                  tooltip: 'Clear',
                                  icon: Icon(Icons.close, size: 20),
                                  onPressed: _closeRouteMode,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _hintStrip(),
                    ),
                  ],
                ),
              ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Material(
                    elevation: 4,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: _suggestions
                          .map((z) => ListTile(
                                dense: true,
                                leading: Icon(Icons.place_outlined,
                                    size: 20, color: Colors.grey[700]),
                                title: Text(_titleCase(z.name)),
                                subtitle: z.state.trim().isEmpty
                                    ? null
                                    : Text(_titleCase(z.state)),
                                onTap: () => _selectSuggestion(z),
                              ))
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- risk wording: always colour + text, never colour alone ----
  String _riskWord(double safety) {
    if (safety >= 75) return 'Low risk';
    if (safety >= 50) return 'Moderate risk';
    return 'High risk';
  }

  Color _riskColor(double safety) {
    if (safety >= 75) return Colors.green.shade700;
    if (safety >= 50) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  String _routeHint(RouteMode m) {
    switch (m) {
      case RouteMode.safest:
        return 'Lowest-risk route available';
      case RouteMode.moderate:
        return 'Balance of safety and travel time';
      case RouteMode.fastest:
        return 'Shortest travel time';
    }
  }

  Widget _routeRow(RouteMode m) {
    final r = _picked[m];
    final selected = _selectedMode == m;
    final riskColor = r == null ? Colors.grey : _riskColor(r.safety);
    return InkWell(
      onTap: () => _selectMode(m),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.blue.shade700 : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_modeLabel(m),
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(
                    r == null
                        ? _routeHint(m)
                        : '${_fmtDuration(r.durationSeconds)} · ${_fmtKm(r.distanceMeters)} km',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            if (r != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${r.safety.round()}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: riskColor)),
                      Text('/100',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                  Text(_riskWord(r.safety),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: riskColor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, Color color, String text) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[900])),
          ),
        ],
      ),
    );
  }

  String _areas(int n) => n == 1 ? 'area' : 'areas';

  // Only facts that come from the route's own data.
  List<Widget> _detailLines(RouteOption sel) {
    final fast = _picked[RouteMode.fastest];
    final nonFast = fast != null && !identical(sel, fast);
    final lines = <Widget>[];
    if (nonFast) {
      final f = fast!;
      final avoided = f.highRiskAreas - sel.highRiskAreas;
      final extra = sel.durationSeconds - f.durationSeconds;
      if (avoided > 0) {
        lines.add(_detailLine(Icons.check_circle, Colors.green.shade700,
            'Avoids $avoided high-risk ${_areas(avoided)}'));
      } else if (sel.safety > f.safety + 1) {
        lines.add(_detailLine(Icons.check_circle, Colors.green.shade700,
            'More of the route in lower-risk zones'));
      }
      lines.add(_detailLine(
          Icons.schedule,
          Colors.grey.shade700,
          extra > 60
              ? '+${_fmtDuration(extra)} compared with the fastest route'
              : 'About the same travel time as the fastest route'));
    } else if (_selectedMode != RouteMode.fastest) {
      lines.add(_detailLine(Icons.info_outline, Colors.grey.shade700,
          'No lower-risk route found for this trip'));
    } else {
      lines.add(_detailLine(
          Icons.schedule, Colors.grey.shade700, 'Shortest travel time'));
    }
    if (sel.highRiskAreas > 0) {
      lines.add(_detailLine(Icons.warning_amber_rounded, Colors.red.shade700,
          'Passes through ${sel.highRiskAreas} high-risk ${_areas(sel.highRiskAreas)}'));
    } else {
      lines.add(_detailLine(Icons.check_circle_outline, Colors.green.shade700,
          'No high-risk areas on this route'));
    }
    return lines;
  }

  bool _hasSaferReasons(RouteOption sel) {
    final fast = _picked[RouteMode.fastest];
    if (fast == null || identical(sel, fast)) return false;
    return fast.highRiskAreas > sel.highRiskAreas ||
        sel.lowShare - fast.lowShare >= 0.02 ||
        fast.risk - sel.risk >= 0.01;
  }

  void _showWhySheet() {
    final sel = _picked[_selectedMode];
    if (sel == null) return;
    final fast = _picked[RouteMode.fastest];
    final nonFast = fast != null && !identical(sel, fast);
    final reasons = <String>[];
    if (nonFast) {
      final f = fast!;
      final avoided = f.highRiskAreas - sel.highRiskAreas;
      if (avoided > 0) {
        reasons.add(
            'Avoids $avoided high-risk ${_areas(avoided)}. The fastest route passes through ${f.highRiskAreas}, this one passes through ${sel.highRiskAreas}.');
      }
      if (sel.lowShare - f.lowShare >= 0.02) {
        reasons.add(
            'More of the route is in lower-risk zones: ${(sel.lowShare * 100).round()}% compared with ${(f.lowShare * 100).round()}% on the fastest route.');
      }
      if (f.risk - sel.risk >= 0.01) {
        reasons.add(
            'Lower reported crime levels along the way than on the fastest route.');
      }
    }
    final title = reasons.isNotEmpty
        ? 'Why is this route safer?'
        : 'How the safety score works';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              for (final t in reasons)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle,
                            size: 16, color: Colors.green.shade700),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(t, style: TextStyle(fontSize: 13.5))),
                    ],
                  ),
                ),
              if (reasons.isNotEmpty) SizedBox(height: 4),
              Text('How the score works',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                'Each stretch of the route is rated by the zone it passes through: low risk counts fully, moderate risk counts half and high risk counts zero. The score is the average, out of 100.',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
              SizedBox(height: 10),
              Text(
                'This is a risk estimate based on reported district-level crime data (crimes against women). It is not a guarantee of personal safety.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hands the chosen route to Google Maps (same start, end and via points).
  Future<void> _startNavigation() async {
    final sel = _picked[_selectedMode];
    final from = _from, to = _to;
    if (sel == null || from == null || to == null) return;
    var via = sel.via;
    if (via.length > 8) {
      final step = via.length / 8;
      via = [for (var i = 0; i < 8; i++) via[(i * step).floor()]];
    }
    String ll(LatLng p) =>
        '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${ll(from)}&destination=${ll(to)}&travelmode=driving'
        '${via.isEmpty ? '' : '&waypoints=${via.map(ll).join('%7C')}'}';
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Widget _buildRouteBottomPanel(double bottomPadding) {
    final sel = _picked[_selectedMode];
    final hasRoutes = _picked.isNotEmpty;
    final canGo = _from != null && _to != null && !_routeLoading;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Material(
            elevation: 10,
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 10 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final m in RouteMode.values)
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: _routeRow(m),
                    ),
                  if (sel != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _detailLines(sel),
                      ),
                    ),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: hasRoutes
                          ? _startNavigation
                          : (canGo ? _findRoutes : null),
                      icon: Icon(hasRoutes ? Icons.navigation : Icons.route,
                          size: 20),
                      label: Text(
                        _routeLoading
                            ? 'Finding routes...'
                            : (hasRoutes ? 'Start Navigation' : 'Get routes'),
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (sel != null)
                    InkWell(
                      onTap: _showWhySheet,
                      child: Padding(
                        padding: EdgeInsets.only(top: 10, bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _hasSaferReasons(sel)
                                  ? 'Why is this route safer?'
                                  : 'How is the safety score calculated?',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18, color: Colors.blue.shade800),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
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
                      Text(zone.name,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(zone.state,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(zone.safetyCategory.toUpperCase()),
                  backgroundColor: zone.baseColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: zone.borderColor, fontWeight: FontWeight.bold),
                )
              ],
            ),
            Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBox("Safety Score",
                    "${zone.safetyScore.toStringAsFixed(1)}/100"),
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
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'safe':
        return Icons.shield_outlined;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'unsafe':
        return Icons.dangerous_outlined;
      default:
        return Icons.help_outline;
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
                      if (_routeMode) {
                        _handleRouteTap(point);
                        return;
                      }

                      for (var zone in _visibleZones) {
                        final double dist = math.sqrt(math.pow(
                                point.latitude - zone.center.latitude, 2) +
                            math.pow(
                                point.longitude - zone.center.longitude, 2));
                        if (dist < 0.3) {
                          _isolateZone(zone);
                          break;
                        }
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.raksha',
                    ),
                    PolygonLayer(
                      polygons: _visibleZones.map((zone) {
                        final double opacity =
                            _isFocusedMode ? 0.85 : 0.45; // transparency
                        return Polygon(
                          points: zone.boundary,
                          color: zone.baseColor.withOpacity(opacity),
                          borderColor: zone.borderColor,
                          borderStrokeWidth: _isFocusedMode ? 3.0 : 1.5,
                          isFilled: true,
                        );
                      }).toList(),
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final r in _picked.values.toSet())
                          if (!identical(r, _picked[_selectedMode]))
                            Polyline(
                              points: r.points,
                              strokeWidth: 5,
                              color: Colors.grey.shade600.withOpacity(0.75),
                            ),
                        if (_picked[_selectedMode] != null) ...[
                          Polyline(
                            points: _picked[_selectedMode]!.points,
                            strokeWidth: 9,
                            color: Colors.blue.shade900,
                          ),
                          Polyline(
                            points: _picked[_selectedMode]!.points,
                            strokeWidth: 5.5,
                            color: Colors.blue.shade500,
                          ),
                        ],
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_from != null)
                          Marker(
                            point: _from!,
                            width: 22,
                            height: 22,
                            builder: (_) => _pinDot(Colors.blue.shade800),
                          ),
                        if (_to != null)
                          Marker(
                            point: _to!,
                            width: 40,
                            height: 40,
                            builder: (_) => Transform.translate(
                              offset: Offset(0, -17),
                              child: Icon(Icons.location_on,
                                  size: 40, color: Colors.red.shade700),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ROUTE PLANNER TOP PANEL (replaces the search bar in route mode)
                if (_routeMode) _buildRouteTopPanel(padding.top),

                // TOP BAR
                if (!_routeMode)
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
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search district...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.grey),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon:
                                          Icon(Icons.close, color: Colors.grey),
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
                // ROUTE PLANNER BOTTOM PANEL
                if (_routeMode) _buildRouteBottomPanel(padding.bottom),

                if (!_isFocusedMode && !_routeMode)
                  Positioned(
                    bottom: padding.bottom + 100, // Above the legend
                    right: 16,
                    child: FloatingActionButton(
                      onPressed:
                          _isLocating ? null : _handleFindNearestDistrict,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      child: _isLocating
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.my_location),
                    ),
                  ),

                // BOTTOM BAR (Legend & Stats)
                if (!_isFocusedMode && !_routeMode)
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
                            boxShadow: [
                              BoxShadow(blurRadius: 8, color: Colors.black12)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Safety Levels',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: Colors.grey[700])),
                              SizedBox(height: 6),
                              _legendItem(Colors.green, 'Safe'),
                              _legendItem(Colors.orange, 'Moderate'),
                              _legendItem(Colors.red, 'Unsafe'),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade800,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  blurRadius: 8,
                                  color: Colors.blue.withOpacity(0.3))
                            ],
                          ),
                          child: Text(
                            '${_visibleZones.length} Zones',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // BACK TO MAP Button
                if (_isFocusedMode && !_routeMode)
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
        child: Text(label,
            style: TextStyle(
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
