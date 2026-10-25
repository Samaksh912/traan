import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'safety_scorer.dart';

/// Fetches driving routes from Google's Routes API only.
class RouteService {
  final String apiKey;
  String lastSource = 'Google Routes API';

  /// Where Google placed the start / end when they were sent as place names
  /// (null when plain coordinates were used).
  LatLng? resolvedFrom;
  LatLng? resolvedTo;

  RouteService(this.apiKey);

  /// Google's own alternatives for A to B. When a place is only known by name
  /// (its stored coordinates are a placeholder), pass its address and Google
  /// finds the real spot.
  Future<List<RouteOption>> fetchRoutes(LatLng from, LatLng to,
      {String? fromAddress, String? toAddress}) async {
    resolvedFrom = null;
    resolvedTo = null;
    if (fromAddress != null || toAddress != null) {
      try {
        return await _fetchGoogle(from, to,
            fromAddress: fromAddress, toAddress: toAddress);
      } catch (e) {
        print('Address lookup failed, using stored coordinates: $e');
        resolvedFrom = null;
        resolvedTo = null;
      }
    }
    return _fetchGoogle(from, to);
  }

  /// One route that passes through [via] waypoints (used for safer corridors).
  Future<RouteOption?> fetchVia(
      LatLng from, LatLng to, List<LatLng> via) async {
    final r = await _fetchGoogle(from, to, via: via);
    return r.isEmpty ? null : r.first;
  }

  Map<String, dynamic> _wp(LatLng p) => {
        'location': {
          'latLng': {'latitude': p.latitude, 'longitude': p.longitude}
        }
      };

  LatLng? _latLng(dynamic loc) {
    try {
      final m = loc['latLng'];
      return LatLng((m['latitude'] as num).toDouble(),
          (m['longitude'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<List<RouteOption>> _fetchGoogle(LatLng from, LatLng to,
      {List<LatLng> via = const [],
      String? fromAddress,
      String? toAddress}) async {
    if (apiKey.isEmpty) {
      throw Exception(
          'Google API key missing. Paste it as defaultValue near the top of the map file.');
    }
    final res = await http
        .post(
          Uri.parse(
              'https://routes.googleapis.com/directions/v2:computeRoutes'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.startLocation,routes.legs.endLocation',
          },
          body: jsonEncode({
            'origin':
                fromAddress != null ? {'address': fromAddress} : _wp(from),
            'destination': toAddress != null ? {'address': toAddress} : _wp(to),
            'travelMode': 'DRIVE',
            // Google does not allow alternatives together with intermediates.
            'computeAlternativeRoutes': via.isEmpty,
            if (via.isNotEmpty)
              'intermediates':
                  via.map((p) => {'via': true, ..._wp(p)}).toList(),
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) {
      var detail = '';
      try {
        detail = jsonDecode(res.body)['error']['message'].toString();
      } catch (_) {}
      throw Exception('Google Routes API ${res.statusCode} $detail');
    }

    final routes = (jsonDecode(res.body)['routes'] as List?) ?? [];
    if (routes.isNotEmpty && (fromAddress != null || toAddress != null)) {
      final legs = (routes.first['legs'] as List?) ?? [];
      if (legs.isNotEmpty) {
        if (fromAddress != null)
          resolvedFrom = _latLng(legs.first['startLocation']);
        if (toAddress != null) resolvedTo = _latLng(legs.last['endLocation']);
      }
    }
    return routes.map<RouteOption>((r) {
      final secs = double.parse((r['duration'] as String).replaceAll('s', ''));
      final dist = (r['distanceMeters'] as num?)?.toDouble() ?? 0;
      final pts = decodePolyline(r['polyline']['encodedPolyline'] as String);
      return RouteOption(pts, dist, secs);
    }).toList();
  }
}

List<LatLng> decodePolyline(String encoded) {
  final pts = <LatLng>[];
  int index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
    pts.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return pts;
}
