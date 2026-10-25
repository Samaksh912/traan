import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'route_service.dart';
import 'safety_scorer.dart';

double _km2d(double lat1, double lng1, double lat2, double lng2) {
  final x = (lng2 - lng1) * cos((lat1 + lat2) * pi / 360) * 111.0;
  final y = (lat2 - lat1) * 111.0;
  return x * x + y * y;
}

double _km(LatLng p, LatLng q) =>
    sqrt(_km2d(p.latitude, p.longitude, q.latitude, q.longitude));

class _Edge {
  final int to;
  final double km;
  const _Edge(this.to, this.km);
}

/// Safety-weighted shortest path over a graph of your zones.
/// cost of a hop = km * (1 + lambda * danger), danger = risk^2.
/// lambda = 0 -> plain shortest path; bigger lambda -> avoids risky zones harder.
class SafeCorridorPlanner {
  final List<ZoneRisk> zones;
  final int neighbours;
  final int sectors;
  final double maxEdgeKm;
  late final List<List<_Edge>> _adj;
  late final List<double> _danger;

  SafeCorridorPlanner(this.zones,
      {this.neighbours = 6, this.sectors = 8, this.maxEdgeKm = 900}) {
    final n = zones.length;
    _danger = zones.map((z) => z.risk * z.risk).toList();
    final adj = List.generate(n, (_) => <_Edge>[]);
    final have = <int>{};

    void link(int i, int j, double km) {
      if (have.add(i * n + j)) adj[i].add(_Edge(j, km));
      if (have.add(j * n + i)) adj[j].add(_Edge(i, km));
    }

    for (var i = 0; i < n; i++) {
      // 1) nearest zone in each compass sector (keeps the graph connected even
      //    when zones sit in far-apart clusters), 2) a few nearest overall.
      final sectorD = List<double>.filled(sectors, double.infinity);
      final sectorJ = List<int>.filled(sectors, -1);
      final nearD = <double>[];
      final nearJ = <int>[];
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final dx = (zones[j].lng - zones[i].lng) *
            cos((zones[i].lat + zones[j].lat) * pi / 360) *
            111.0;
        final dy = (zones[j].lat - zones[i].lat) * 111.0;
        final d2 = dx * dx + dy * dy;

        final sec =
            (((atan2(dy, dx) + pi) / (2 * pi)) * sectors).floor() % sectors;
        if (d2 < sectorD[sec]) {
          sectorD[sec] = d2;
          sectorJ[sec] = j;
        }

        if (nearD.length == neighbours && d2 >= nearD.last) continue;
        var pos = nearD.length;
        while (pos > 0 && nearD[pos - 1] > d2) {
          pos--;
        }
        nearD.insert(pos, d2);
        nearJ.insert(pos, j);
        if (nearD.length > neighbours) {
          nearD.removeLast();
          nearJ.removeLast();
        }
      }
      for (var s = 0; s < sectors; s++) {
        if (sectorJ[s] >= 0 && sqrt(sectorD[s]) <= maxEdgeKm) {
          link(i, sectorJ[s], sqrt(sectorD[s]));
        }
      }
      for (var t = 0; t < nearJ.length; t++) {
        final km = sqrt(nearD[t]);
        if (km <= maxEdgeKm) link(i, nearJ[t], km);
      }
    }
    _adj = adj;
  }

  List<int> _nearest(LatLng p, int m) {
    final d = zones
        .map((z) => _km2d(p.latitude, p.longitude, z.lat, z.lng))
        .toList();
    final idx = List<int>.generate(zones.length, (i) => i);
    idx.sort((x, y) => d[x].compareTo(d[y]));
    return idx.take(m).toList();
  }

  /// Waypoints (thinned) along the best safety-weighted path from a to b.
  /// Empty list = no useful steering (or no path in the graph).
  List<LatLng> corridor(LatLng a, LatLng b, double lambda,
      {double minSpacingKm = 50, int maxWaypoints = 20}) {
    final n = zones.length;
    if (n == 0) return [];

    final startKm = <int, double>{
      for (final i in _nearest(a, 6))
        i: sqrt(_km2d(a.latitude, a.longitude, zones[i].lat, zones[i].lng))
    };
    final endKm = <int, double>{
      for (final i in _nearest(b, 6))
        i: sqrt(_km2d(b.latitude, b.longitude, zones[i].lat, zones[i].lng))
    };

    // Dijkstra. Node n is the target (b). prev == -1 means "from start (a)".
    final dist = List<double>.filled(n + 1, double.infinity);
    final prev = List<int>.filled(n + 1, -1);
    final done = List<bool>.filled(n + 1, false);
    startKm.forEach((i, km) => dist[i] = km * (1 + lambda * _danger[i]));

    while (true) {
      int u = -1;
      double best = double.infinity;
      for (var i = 0; i <= n; i++) {
        if (!done[i] && dist[i] < best) {
          best = dist[i];
          u = i;
        }
      }
      if (u == -1 || u == n) break;
      done[u] = true;
      for (final e in _adj[u]) {
        final c = e.km * (1 + lambda * 0.5 * (_danger[u] + _danger[e.to]));
        if (dist[u] + c < dist[e.to]) {
          dist[e.to] = dist[u] + c;
          prev[e.to] = u;
        }
      }
      final ek = endKm[u];
      if (ek != null) {
        final c = ek * (1 + lambda * _danger[u]);
        if (dist[u] + c < dist[n]) {
          dist[n] = dist[u] + c;
          prev[n] = u;
        }
      }
    }
    if (dist[n].isInfinite) return [];

    final path = <int>[];
    var cur = prev[n];
    while (cur != -1) {
      path.add(cur);
      cur = prev[cur];
    }
    final pts = path.reversed
        .map((i) => LatLng(zones[i].lat, zones[i].lng))
        .toList();

    // Thin out: keep waypoints far enough apart (and under the API limit).
    double totalKm = 0;
    var last = a;
    for (final p in pts) {
      totalKm += _km(last, p);
      last = p;
    }
    totalKm += _km(last, b);
    final spacing = max(minSpacingKm, totalKm / maxWaypoints);

    final out = <LatLng>[];
    last = a;
    for (final p in pts) {
      if (_km(last, p) >= spacing && _km(p, b) >= spacing / 2) {
        out.add(p);
        last = p;
      }
    }
    return out;
  }
}

/// Builds candidate routes: Google's own alternatives plus routes steered
/// through safer district corridors, all scored on the real road polyline.
class SafeRouter {
  final SafetyScorer scorer;
  final SafeCorridorPlanner planner;
  final RouteService service;
  final List<double> lambdas;

  SafeRouter({
    required this.scorer,
    required this.planner,
    required this.service,
    this.lambdas = const [4, 12, 40],
  });

  String _sig(List<LatLng> w) => w
      .map((p) =>
          '${p.latitude.toStringAsFixed(2)},${p.longitude.toStringAsFixed(2)}')
      .join('|');

  /// Short human-readable summary of the last search (shown in the panel).
  String lastReport = '';

  /// Where Google placed the start / end when they were given as place names
  /// (null when plain coordinates were used).
  LatLng? resolvedFrom;
  LatLng? resolvedTo;

  Future<List<RouteOption>> candidates(LatLng from, LatLng to,
      {String? fromAddress, String? toAddress}) async {
    resolvedFrom = null;
    resolvedTo = null;
    final all = <RouteOption>[
      ...await service.fetchRoutes(from, to,
          fromAddress: fromAddress, toAddress: toAddress)
    ];
    if (all.isEmpty) return all;
    // From here on, use where Google actually put the places.
    resolvedFrom = service.resolvedFrom;
    resolvedTo = service.resolvedTo;
    final start = resolvedFrom ?? from;
    final end = resolvedTo ?? to;
    final report = <String>['${all.length} direct'];

    // Skip steered plans that are identical to the plain shortest corridor.
    final seen = <String>{_sig(planner.corridor(start, end, 0))};
    for (final l in lambdas) {
      final wps = planner.corridor(start, end, l);
      if (wps.isEmpty) {
        report.add('safety $l: no waypoints');
        continue;
      }
      if (!seen.add(_sig(wps))) {
        report.add('safety $l: same corridor');
        continue;
      }
      try {
        final r = await service.fetchVia(start, end, wps);
        if (r != null) {
          r.via = wps;
          all.add(r);
          report.add('safety $l: ok (${wps.length} waypoints)');
        } else {
          report.add('safety $l: no route');
        }
      } catch (e) {
        report.add('safety $l: failed');
        print('Steered route (safety $l) failed: $e');
      }
    }
    scorer.score(all);
    final stats = all
        .map((r) =>
            '${(r.durationSeconds / 3600).toStringAsFixed(1)}h/safety ${r.safety.round()}')
        .join(', ');
    report.add('routes (time/safety): $stats');
    lastReport = report.join(' | ');
    print('Plan: $lastReport');
    return all;
  }
}