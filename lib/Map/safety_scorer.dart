import 'dart:math';
import 'package:latlong2/latlong.dart';

/// One safety zone. level: 0 = Safe, 1 = Moderate, 2 = Unsafe (map colours).
/// risk: 0..1 crime percentile (used only to break ties).
class ZoneRisk {
  final double lat, lng, risk;
  final bool hot;
  final int level;
  const ZoneRisk(this.lat, this.lng, this.risk,
      {this.hot = false, this.level = 0});
}

enum RouteMode { safest, moderate, fastest }

class RouteOption {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// 0..100 shown to the user. 100 = the whole route is inside Safe (green)
  /// zones, Moderate (orange) counts half, Unsafe (red) counts zero.
  double safety = 100;

  /// 0..1 mean crime percentile along the route (tie-break only).
  double risk = 0;

  /// 0..1 share of the route inside Moderate/Unsafe zones.
  double hotShare = 0;

  /// Safety (0..1) of consecutive slices of the route, start to end.
  /// Drawn as the coloured "journey" bar.
  List<double> strip = [];

  /// Number of distinct High-risk (red) / Moderate (orange) zones the route
  /// passes through.
  int highRiskAreas = 0;
  int moderateAreas = 0;

  /// 0..1 share of the route inside Low-risk (green) zones.
  double lowShare = 0;

  /// Waypoints this route was steered through (empty for Google's own routes).
  List<LatLng> via = [];

  RouteOption(this.points, this.distanceMeters, this.durationSeconds);
}

class SafetyScorer {
  final List<ZoneRisk> zones;
  final double maxZoneKm; // zones are district centroids, so be generous
  final double unknownRisk; // percentile used when no zone is near
  final double unknownWeight; // safety weight used when no zone is near

  static const List<double> _levelWeight = [1.0, 0.5, 0.0];
  static const int stripBins = 40;

  SafetyScorer(this.zones,
      {this.maxZoneKm = 40, this.unknownRisk = 0.3, this.unknownWeight = 0.7});

  // Fast flat-earth squared distance in km^2 (fine at district scale).
  double _km2(double lat1, double lng1, double lat2, double lng2) {
    final x = (lng2 - lng1) * cos((lat1 + lat2) * pi / 360) * 111.0;
    final y = (lat2 - lat1) * 111.0;
    return x * x + y * y;
  }

  List<LatLng> _sample(List<LatLng> pts, double stepKm) {
    if (pts.length < 2) return pts;
    final out = <LatLng>[pts.first];
    double acc = 0;
    for (var i = 1; i < pts.length; i++) {
      acc += sqrt(_km2(pts[i - 1].latitude, pts[i - 1].longitude,
          pts[i].latitude, pts[i].longitude));
      if (acc >= stepKm) {
        out.add(pts[i]);
        acc = 0;
      }
    }
    out.add(pts.last);
    return out;
  }

  /// Index of the nearest zone within range, or -1.
  int _zoneIndexAt(LatLng p) {
    double best = double.infinity;
    int found = -1;
    for (var i = 0; i < zones.length; i++) {
      final z = zones[i];
      final d = _km2(p.latitude, p.longitude, z.lat, z.lng);
      if (d < best) {
        best = d;
        found = i;
      }
    }
    if (found < 0 || sqrt(best) > maxZoneKm) return -1;
    return found;
  }

  List<double> _bins(List<double> ws) {
    final out = <double>[];
    for (var b = 0; b < stripBins; b++) {
      final lo = (b * ws.length / stripBins).floor();
      var hi = ((b + 1) * ws.length / stripBins).floor();
      if (hi <= lo) hi = lo + 1;
      double sum = 0;
      int c = 0;
      for (var k = lo; k < hi && k < ws.length; k++) {
        sum += ws[k];
        c++;
      }
      out.add(c == 0 ? ws.last : sum / c);
    }
    return out;
  }

  /// Fills safety, risk, hotShare, strip and the area counts for every route.
  void score(List<RouteOption> routes) {
    for (final r in routes) {
      // ~1 km steps for short routes, capped at ~300 samples for long ones.
      final stepKm = max(1.0, r.distanceMeters / 1000 / 300);
      final samples = _sample(r.points, stepKm);
      final ws = <double>[];
      final highSet = <int>{};
      final modSet = <int>{};
      double riskSum = 0;
      double wSum = 0;
      int hot = 0;
      int low = 0;
      for (final p in samples) {
        final idx = _zoneIndexAt(p);
        final z = idx < 0 ? null : zones[idx];
        final w =
            z == null ? unknownWeight : _levelWeight[min(2, max(0, z.level))];
        ws.add(w);
        wSum += w;
        riskSum += z?.risk ?? unknownRisk;
        if (z != null) {
          if (z.hot) hot++;
          if (z.level == 2) {
            highSet.add(idx);
          } else if (z.level == 1) {
            modSet.add(idx);
          } else {
            low++;
          }
        }
      }
      r.safety = 100 * wSum / ws.length;
      r.risk = riskSum / ws.length;
      r.hotShare = hot / ws.length;
      r.lowShare = low / ws.length;
      r.highRiskAreas = highSet.length;
      r.moderateAreas = modSet.length;
      r.strip = _bins(ws);
    }
  }

  /// Picks which route to show for each mode.
  /// Safest/Moderate only consider routes up to [maxDetour] x the fastest
  /// time, so "safest" can be much longer but not absurdly so.
  Map<RouteMode, RouteOption> pick(List<RouteOption> routes,
      {double maxDetour = 3.0}) {
    if (routes.isEmpty) return {};
    double norm(double v, double lo, double hi) =>
        hi == lo ? 0.0 : (v - lo) / (hi - lo);

    final fastest = ([...routes]
          ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds)))
        .first;
    final eligible = routes
        .where((r) => r.durationSeconds <= fastest.durationSeconds * maxDetour)
        .toList();

    final minS = eligible.map((r) => r.safety).reduce(min);
    final maxS = eligible.map((r) => r.safety).reduce(max);
    final minD = eligible.map((r) => r.durationSeconds).reduce(min);
    final maxD = eligible.map((r) => r.durationSeconds).reduce(max);

    // Highest safety score wins (half-point buckets), then lower crime
    // percentile, then faster.
    final safest = ([...eligible]..sort((a, b) {
            final c = (b.safety * 2).round().compareTo((a.safety * 2).round());
            if (c != 0) return c;
            final c2 = a.risk.compareTo(b.risk);
            return c2 != 0
                ? c2
                : a.durationSeconds.compareTo(b.durationSeconds);
          }))
        .first;

    double balance(RouteOption r) =>
        0.5 * norm(maxS - r.safety, 0, maxS - minS) +
        0.5 * norm(r.durationSeconds, minD, maxD);
    final moderate =
        ([...eligible]..sort((a, b) => balance(a).compareTo(balance(b)))).first;

    return {
      RouteMode.fastest: fastest,
      RouteMode.safest: safest,
      RouteMode.moderate: moderate,
    };
  }
}
