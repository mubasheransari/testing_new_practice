import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ios_tiretest_ai/models/place_marker_data.dart';
import '../Bloc/auth_state.dart';

class PlacesService {
  PlacesService({
    required this.apiKey,
    this.radiusMeters = 20000,
  });

  final String apiKey;
  final int radiusMeters;

  static const List<String> _placesKeywords = [
    'tyre',
    'tire',
    'tyre shop',
    'tire shop',
    'tyre repair',
    'tire repair',
    'puncture repair',
    'wheel alignment',
    'wheel balancing',
  ];

  Future<List<PlaceMarkerData>> fetchAll({
    required double lat,
    required double lng,
  }) async {
    if (apiKey.trim().isEmpty || apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      return [];
    }

    final dedup = <String, PlaceMarkerData>{};

    // 1) rankby=distance keyword searches
    for (final k in _placesKeywords) {
      final list = await _nearbyRankByDistance(lat: lat, lng: lng, keyword: k);
      for (final p in list) {
        dedup[p.id] = p;
      }
    }

    // 2) radius keyword searches (multi page)
    for (final k in _placesKeywords) {
      final list = await _nearbySearchAllPages(
        lat: lat,
        lng: lng,
        radius: radiusMeters,
        keyword: k,
        type: null,
      );
      for (final p in list) {
        dedup[p.id] = p;
      }
    }

    // 3) fallback type=car_repair
    if (dedup.isEmpty) {
      final list = await _nearbySearchAllPages(
        lat: lat,
        lng: lng,
        radius: radiusMeters,
        keyword: null,
        type: 'car_repair',
      );
      for (final p in list) {
        dedup[p.id] = p;
      }
    }

    // 4) text search if too few
    if (dedup.length < 5) {
      final textQueries = <String>[
        'tyre shop',
        'tire shop',
        'tyre repair',
        'tire repair',
        'puncture repair',
      ];
      for (final q in textQueries) {
        final list = await _textSearchAllPages(
          lat: lat,
          lng: lng,
          radius: radiusMeters,
          query: q,
        );
        for (final p in list) {
          dedup[p.id] = p;
        }
      }
    }

    final all = dedup.values.toList();
    final tyreOnly = _filterTyreLikeNames(all);
    return tyreOnly.isNotEmpty ? tyreOnly : all;
  }

  List<PlaceMarkerData> _filterTyreLikeNames(List<PlaceMarkerData> list) {
    bool ok(String? t) {
      final s = (t ?? '').toLowerCase();
      return s.contains('tyre') ||
          s.contains('tire') ||
          s.contains('puncture') ||
          s.contains('wheel') ||
          s.contains('alignment') ||
          s.contains('balancing');
    }

    return list.where((p) => ok(p.name)).toList();
  }

  Future<List<PlaceMarkerData>> _nearbyRankByDistance({
    required double lat,
    required double lng,
    required String keyword,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'key': apiKey,
      'location': '$lat,$lng',
      'rankby': 'distance',
      'keyword': keyword,
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

    if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    return _placesFromResults(results);
  }

  Future<List<PlaceMarkerData>> _nearbySearchAllPages({
    required double lat,
    required double lng,
    required int radius,
    String? keyword,
    String? type,
  }) async {
    final out = <PlaceMarkerData>[];
    String? pageToken;
    int safety = 0;

    while (safety < 3) {
      safety++;

      final params = <String, String>{
        'key': apiKey,
        'location': '$lat,$lng',
        'radius': '$radius',
        if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (pageToken != null) 'pagetoken': pageToken,
      };

      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);
      final res = await http.get(uri);
      if (res.statusCode != 200) break;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      final results = (json['results'] as List?) ?? const [];

      if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') break;

      if (status == 'INVALID_REQUEST' && pageToken != null) {
        await Future.delayed(const Duration(milliseconds: 1800));
        continue;
      }

      if (status != 'OK' && status != 'ZERO_RESULTS') break;

      out.addAll(_placesFromResults(results));

      pageToken = (json['next_page_token'] as String?)?.trim();
      if (pageToken == null || pageToken.isEmpty) break;

      await Future.delayed(const Duration(milliseconds: 1800));
    }

    return out;
  }

  Future<List<PlaceMarkerData>> _textSearchAllPages({
    required double lat,
    required double lng,
    required int radius,
    required String query,
  }) async {
    final out = <PlaceMarkerData>[];
    String? pageToken;
    int safety = 0;

    while (safety < 3) {
      safety++;

      final params = <String, String>{
        'key': apiKey,
        'query': query,
        'location': '$lat,$lng',
        'radius': '$radius',
        if (pageToken != null) 'pagetoken': pageToken,
      };

      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', params);
      final res = await http.get(uri);
      if (res.statusCode != 200) break;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      final results = (json['results'] as List?) ?? const [];

      if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') break;

      if (status == 'INVALID_REQUEST' && pageToken != null) {
        await Future.delayed(const Duration(milliseconds: 1800));
        continue;
      }

      if (status != 'OK' && status != 'ZERO_RESULTS') break;

      out.addAll(_placesFromResults(results));

      pageToken = (json['next_page_token'] as String?)?.trim();
      if (pageToken == null || pageToken.isEmpty) break;

      await Future.delayed(const Duration(milliseconds: 1800));
    }

    return out;
  }

  List<PlaceMarkerData> _placesFromResults(List results) {
    final out = <PlaceMarkerData>[];

    for (final r in results) {
      final m = (r as Map).cast<String, dynamic>();

      final placeId = (m['place_id'] ?? '').toString();
      final name = (m['name'] ?? 'Tyre shop').toString();

      final loc = ((m['geometry'] as Map?)?['location'] as Map?) ?? const {};
      final plat = (loc['lat'] as num?)?.toDouble();
      final plng = (loc['lng'] as num?)?.toDouble();

      if (placeId.isEmpty || plat == null || plng == null) continue;

      out.add(PlaceMarkerData(id: placeId, name: name, lat: plat, lng: plng));
    }

    return out;
  }
}