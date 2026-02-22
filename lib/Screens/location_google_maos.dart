import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
/// LocationVendorsMapScreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';


class LocationVendorsMapScreen extends StatefulWidget {
  const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
  final bool showFirstTooltipOnLoad;

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _gm;

  LatLng? _myLatLng;
  Offset? _myScreenPx;
  late final Future<void> _locationFuture;

  // ✅ vendor markers (API) - unchanged
  final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
  final Set<Marker> _vendorMarkers = {};
  BitmapDescriptor? _vendorMarkerIcon;

  // ✅ Google Places markers (RED)
  final Set<Marker> _nearbyTyreShopMarkers = {};
  bool _nearbyTyreShopLoaded = false;
  bool _nearbyTyreShopLoading = false;

  // 🔑 Put your Places API key here (must have Places API enabled + billing)
  static const String _googlePlacesApiKey = 'AIzaSyBFIEDQXjgT6djAIrXB466aR1oG5EmXojQ';

  // ✅ max coverage radius
  static const int _radiusMeters = 20000; // 20km

  // ✅ keywords used
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

  MarkerId? _selected;
  Offset? _selectedScreenPx;

  static const double _tooltipCardW = 292.0;
  static const double _tooltipCardH = 235.0;
  static const double _tooltipGap = 14.0;
  static const double _markerLiftPx = 62.0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const double _meMarkerSize = 34;
  static const double _meLiftPx = 12;

  static const double _bottomOverlayHeight = 195 + 17 + 18;

  Timer? _camTick;

  static const _mapStyleJson = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9f2ff"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();

    // ✅ fade in/out ONLY (unchanged)
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    // ✅ get location BEFORE map builds
    _locationFuture = _fetchCurrentLocationOnce();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _camTick?.cancel();
    super.dispose();
  }

  // ✅ convert screen pixels -> logical pixels (fix right-side drift)
  Offset _toLogicalOffset(ScreenCoordinate sc) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Offset(sc.x / dpr, sc.y / dpr);
  }

  Future<void> _fetchCurrentLocationOnce() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('❌ Location service disabled');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied');
        return;
      }

      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      // ✅ LOCK it once
      _myLatLng = LatLng(p.latitude, p.longitude);
      debugPrint('✅ CURRENT LOCATION: ${p.latitude}, ${p.longitude}');
      if (mounted) setState(() {});

      // ✅ Ensure your custom API marker icon
      await _ensureVendorMarkerIcon();

      // ✅ API call using CURRENT LOCATION (no hardcode)
      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(
              latitude: p.latitude,
              longitude: p.longitude,
            ),
          );

      // ✅ Load nearby tyre/tire shops as RED markers (places)
      await _loadGooglePlacesMarkers(force: true);
    } catch (e) {
      debugPrint('❌ _fetchCurrentLocationOnce error: $e');
    }
  }

  Future<void> _ensureVendorMarkerIcon() async {
    if (_vendorMarkerIcon != null) return;
    _vendorMarkerIcon = await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
  }

  // ✅ Google Places loader with MAX coverage
  Future<void> _loadGooglePlacesMarkers({bool force = false}) async {
    if (_myLatLng == null) return;
    if (_nearbyTyreShopLoading) return;

    // allow retry if empty
    if (!force && _nearbyTyreShopLoaded && _nearbyTyreShopMarkers.isNotEmpty) return;

    if (_googlePlacesApiKey.trim().isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      debugPrint('❌ Google Places key not set. Red markers will not load.');
      return;
    }

    _nearbyTyreShopLoading = true;

    try {
      final lat = _myLatLng!.latitude;
      final lng = _myLatLng!.longitude;

      debugPrint('🔎 PLACES KEYWORDS = $_placesKeywords');
      debugPrint('📍 PLACES SEARCH @ $lat,$lng radius=$_radiusMeters');

      final dedup = <String, Marker>{};

      // 1) RankByDistance keyword searches (works well in many areas)
      for (final k in _placesKeywords) {
        final mk = await _placesNearbyRankByDistance(lat: lat, lng: lng, keyword: k);
        for (final m in mk) {
          dedup[m.markerId.value] = m;
        }
      }

      // 2) NearbySearch radius keyword searches
      for (final k in _placesKeywords) {
        final mk = await _placesNearbySearchAllPages(
          lat: lat,
          lng: lng,
          radius: _radiusMeters,
          keyword: k,
          type: null,
        );
        for (final m in mk) {
          dedup[m.markerId.value] = m;
        }
      }

      // 3) BIG fallback: NearbySearch type=car_repair (no keyword)
      // This ensures you SEE Google markers even if local shops don't include "tyre/tire" in the name.
      if (dedup.isEmpty) {
        debugPrint('⚠️ tyre keywords produced 0. Trying fallback: type=car_repair (NO keyword)');
        final mk = await _placesNearbySearchAllPages(
          lat: lat,
          lng: lng,
          radius: _radiusMeters,
          keyword: null,
          type: 'car_repair',
        );
        for (final m in mk) {
          dedup[m.markerId.value] = m;
        }
      }

      // 4) TextSearch fallback (location+radius)
      if (dedup.length < 5) {
        final textQueries = <String>[
          'tyre shop',
          'tire shop',
          'tyre repair',
          'tire repair',
          'puncture repair',
        ];
        for (final q in textQueries) {
          final mk = await _placesTextSearchAllPages(lat: lat, lng: lng, radius: _radiusMeters, query: q);
          for (final m in mk) {
            dedup[m.markerId.value] = m;
          }
        }
      }

      final all = dedup.values.toList();
      final tyreOnly = _filterTyreLikeNames(all);

      // If tyreOnly becomes 0 but all has markers, we keep "all"
      // so you STILL see Google markers (proves Places is working).
      final finalMarkers = tyreOnly.isNotEmpty ? tyreOnly : all;

      debugPrint('✅ GOOGLE markers all=${all.length} tyreOnly=${tyreOnly.length} FINAL=${finalMarkers.length}');

      if (!mounted) return;
      setState(() {
        _nearbyTyreShopMarkers
          ..clear()
          ..addAll(finalMarkers);
        _nearbyTyreShopLoaded = true;
      });

      // If still 0, allow future retry (e.g., permissions/key/billing fixed later)
      if (finalMarkers.isEmpty) _nearbyTyreShopLoaded = false;
    } catch (e) {
      debugPrint('❌ Places loading failed: $e');
      _nearbyTyreShopLoaded = false;
    } finally {
      _nearbyTyreShopLoading = false;
    }
  }

  List<Marker> _filterTyreLikeNames(List<Marker> markers) {
    bool ok(String? t) {
      final s = (t ?? '').toLowerCase();
      return s.contains('tyre') ||
          s.contains('tire') ||
          s.contains('puncture') ||
          s.contains('wheel') ||
          s.contains('alignment') ||
          s.contains('balancing');
    }

    return markers.where((m) => ok(m.infoWindow.title)).toList();
  }

  // ✅ Nearby search RankByDistance (no radius)
  Future<List<Marker>> _placesNearbyRankByDistance({
    required double lat,
    required double lng,
    required String keyword,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'key': _googlePlacesApiKey,
      'location': '$lat,$lng',
      'rankby': 'distance',
      'keyword': keyword,
    });

    final res = await http.get(uri);
    final body = res.body;

    debugPrint('🌐 RankByDistance("$keyword") HTTP ${res.statusCode}');
    if (res.statusCode != 200) {
      debugPrint('❌ RankByDistance("$keyword") non-200 body=${_short(body)}');
      return [];
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final err = (json['error_message'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

    debugPrint('✅ RankByDistance("$keyword") status=$status err=${err.isEmpty ? "-" : err} results=${results.length}');
    _logSampleResults('RankByDistance("$keyword")', results);

    if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];

    return _markersFromPlacesResults(results);
  }

  // ✅ NearbySearch (multi page)
  Future<List<Marker>> _placesNearbySearchAllPages({
    required double lat,
    required double lng,
    required int radius,
    String? keyword,
    String? type,
  }) async {
    final out = <Marker>[];
    String? pageToken;
    int safety = 0;

    while (safety < 3) {
      safety++;

      final params = <String, String>{
        'key': _googlePlacesApiKey,
        'location': '$lat,$lng',
        'radius': '$radius',
        if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (pageToken != null) 'pagetoken': pageToken!,
      };

      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);
      final res = await http.get(uri);
      final body = res.body;

      debugPrint('🌐 NearbySearch("${keyword ?? "NO_KEYWORD"}" type=${type ?? "-"}) HTTP ${res.statusCode}');
      if (res.statusCode != 200) {
        debugPrint('❌ NearbySearch non-200 body=${_short(body)}');
        break;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      final err = (json['error_message'] ?? '').toString();
      final results = (json['results'] as List?) ?? const [];

      debugPrint('✅ NearbySearch("${keyword ?? "NO_KEYWORD"}") status=$status err=${err.isEmpty ? "-" : err} results=${results.length}');
      _logSampleResults('NearbySearch("${keyword ?? "NO_KEYWORD"}")', results);

      if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') break;

      if (status == 'INVALID_REQUEST' && pageToken != null) {
        await Future.delayed(const Duration(milliseconds: 1800));
        continue;
      }

      if (status != 'OK' && status != 'ZERO_RESULTS') break;

      out.addAll(_markersFromPlacesResults(results));

      pageToken = (json['next_page_token'] as String?)?.trim();
      if (pageToken == null || pageToken.isEmpty) break;

      await Future.delayed(const Duration(milliseconds: 1800));
    }

    return out;
  }

  // ✅ TextSearch (multi page)
  Future<List<Marker>> _placesTextSearchAllPages({
    required double lat,
    required double lng,
    required int radius,
    required String query,
  }) async {
    final out = <Marker>[];
    String? pageToken;
    int safety = 0;

    while (safety < 3) {
      safety++;

      final params = <String, String>{
        'key': _googlePlacesApiKey,
        'query': query,
        'location': '$lat,$lng',
        'radius': '$radius',
        if (pageToken != null) 'pagetoken': pageToken!,
      };

      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', params);
      final res = await http.get(uri);
      final body = res.body;

      debugPrint('🌐 TextSearch("$query") HTTP ${res.statusCode}');
      if (res.statusCode != 200) {
        debugPrint('❌ TextSearch non-200 body=${_short(body)}');
        break;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      final err = (json['error_message'] ?? '').toString();
      final results = (json['results'] as List?) ?? const [];

      debugPrint('✅ TextSearch("$query") status=$status err=${err.isEmpty ? "-" : err} results=${results.length}');
      _logSampleResults('TextSearch("$query")', results);

      if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') break;

      if (status == 'INVALID_REQUEST' && pageToken != null) {
        await Future.delayed(const Duration(milliseconds: 1800));
        continue;
      }

      if (status != 'OK' && status != 'ZERO_RESULTS') break;

      out.addAll(_markersFromPlacesResults(results));

      pageToken = (json['next_page_token'] as String?)?.trim();
      if (pageToken == null || pageToken.isEmpty) break;

      await Future.delayed(const Duration(milliseconds: 1800));
    }

    return out;
  }

  void _logSampleResults(String tag, List results) {
    if (results.isEmpty) return;
    final take = results.take(5).toList();
    for (final r in take) {
      final m = (r as Map).cast<String, dynamic>();
      final name = (m['name'] ?? '').toString();
      final pid = (m['place_id'] ?? '').toString();
      final loc = ((m['geometry'] as Map?)?['location'] as Map?) ?? const {};
      final plat = (loc['lat'] as num?)?.toDouble();
      final plng = (loc['lng'] as num?)?.toDouble();
      debugPrint('📌 $tag sample => $name | $pid | $plat,$plng');
    }
  }

  String _short(String s) => s.substring(0, s.length > 220 ? 220 : s.length);

  // ✅ build markers from Places results (red markers)
  List<Marker> _markersFromPlacesResults(List results) {
    final out = <Marker>[];

    for (final r in results) {
      final m = (r as Map).cast<String, dynamic>();

      final placeId = (m['place_id'] ?? '').toString();
      final name = (m['name'] ?? 'Tyre shop').toString();

      final loc = ((m['geometry'] as Map?)?['location'] as Map?) ?? const {};
      final plat = (loc['lat'] as num?)?.toDouble();
      final plng = (loc['lng'] as num?)?.toDouble();

      if (placeId.isEmpty || plat == null || plng == null) continue;

      final id = MarkerId('g_$placeId');

      out.add(
        Marker(
          markerId: id,
          position: LatLng(plat, plng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(.5, .5),
          infoWindow: InfoWindow(title: name),
          onTap: _hidePopup, // do not touch vendor tooltip logic
          zIndex: 2.0, // ensure visible
        ),
      );
    }

    return out;
  }

  // ✅ keeps "You're here" overlay pinned while panning
  void _onCameraMoveThrottled(CameraPosition _) {
    if (_camTick?.isActive == true) return;
    _camTick = Timer(const Duration(milliseconds: 35), () async {
      await _updateMyAnchor();
      await _updateAnchor();
    });
  }

  Future<void> _updateMyAnchor() async {
    if (_gm == null || _myLatLng == null) return;
    final sc = await _gm!.getScreenCoordinate(_myLatLng!);
    if (!mounted) return;
    setState(() => _myScreenPx = _toLogicalOffset(sc));
  }

  void _buildMarkersFromApi(List<ShopVendorModel> shops) {
    _vendorByMarker.clear();
    _vendorMarkers.clear();

    for (final s in shops) {
      if (s.latitude == 0 || s.longitude == 0) continue;
      if (s.latitude.abs() > 90 || s.longitude.abs() > 180) continue;

      final id = MarkerId(s.id.isNotEmpty ? s.id : '${s.shopName}_${s.latitude}_${s.longitude}');
      _vendorByMarker[id] = s;

      _vendorMarkers.add(
        Marker(
          markerId: id,
          position: LatLng(s.latitude, s.longitude),
          icon: _vendorMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(.5, .5),
          onTap: () async {
            setState(() {
              _selected = id;
              _selectedScreenPx = null;
            });
            await _updateAnchor();
            await _ensureTooltipShowsAbove();
          },
          zIndex: 3.0, // keep your custom markers on top
        ),
      );
    }

    if (_selected != null && !_vendorByMarker.containsKey(_selected)) {
      _selected = null;
      _selectedScreenPx = null;
    }

    setState(() {});
  }

  Future<void> _updateAnchor() async {
    if (_gm == null || _selected == null) return;
    final selectedMarker = _vendorMarkers.where((m) => m.markerId == _selected).toList();
    if (selectedMarker.isEmpty) return;

    final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
    if (!mounted) return;
    setState(() => _selectedScreenPx = _toLogicalOffset(sc));
  }

  Future<void> _ensureTooltipShowsAbove() async {
    if (_gm == null || _selected == null) return;

    final selectedMarker = _vendorMarkers.where((m) => m.markerId == _selected).toList();
    if (selectedMarker.isEmpty) return;

    final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
    final rawAnchor = _toLogicalOffset(sc);
    final adjustedAnchor = Offset(rawAnchor.dx, rawAnchor.dy - _markerLiftPx);

    final desiredTop = adjustedAnchor.dy - _tooltipCardH - _tooltipGap;
    const minTop = 12.0;

    if (desiredTop < minTop) {
      final need = (minTop - desiredTop);
      await _gm!.animateCamera(CameraUpdate.scrollBy(0, need));
    } else {
      final targetY = (MediaQuery.of(context).size.height * 0.55);
      final dy = rawAnchor.dy - targetY;
      if (dy > 0) await _gm!.animateCamera(CameraUpdate.scrollBy(0, dy));
    }

    await _updateAnchor();
  }

  void _hidePopup() {
    if (_selected != null || _selectedScreenPx != null) {
      setState(() {
        _selected = null;
        _selectedScreenPx = null;
      });
    }
  }

  void _ensureMarkersBuiltIfNeeded(List<ShopVendorModel> shops) {
    if (shops.isEmpty) return;
    if (_vendorMarkers.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureVendorMarkerIcon();
      if (!mounted) return;
      _buildMarkersFromApi(shops);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        top: true,
        bottom: false,
        child: FutureBuilder<void>(
          future: _locationFuture,
          builder: (context, snap) {
            if (_myLatLng == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return BlocConsumer<AuthBloc, AuthState>(
              listenWhen: (p, c) => p.shopsStatus != c.shopsStatus || p.shops.length != c.shops.length,
              listener: (context, state) async {
                if (state.shopsStatus == ShopsStatus.success) {
                  await _ensureVendorMarkerIcon();
                  _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
                  await _updateMyAnchor();
                  await _updateAnchor();
                }
              },
              builder: (context, state) {
                final loading = state.shopsStatus == ShopsStatus.loading;

                if (state.shopsStatus == ShopsStatus.success) {
                  _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
                }

                // ✅ union markers (API markers + Google red markers)
                final allMarkers = <Marker>{
                  ..._vendorMarkers,
                  ..._nearbyTyreShopMarkers,
                };

                debugPrint(
                  '🧩 markers: API=${_vendorMarkers.length} GOOGLE_RED=${_nearbyTyreShopMarkers.length} total=${allMarkers.length}',
                );

                return Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final mapW = c.maxWidth;
                          final mapH = c.maxHeight;

                          return Stack(
                            children: [
                              GoogleMap(
                                padding: EdgeInsets.only(bottom: _bottomOverlayHeight + pad.bottom),
                                initialCameraPosition: CameraPosition(target: _myLatLng!, zoom: 15),
                                onMapCreated: (ctrl) async {
                                  _gm = ctrl;
                                  await _gm?.setMapStyle(_mapStyleJson);

                                  await Future.delayed(const Duration(milliseconds: 10));
                                  await _gm?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(target: _myLatLng!, zoom: 15),
                                    ),
                                  );

                                  await _updateMyAnchor();
                                  await _updateAnchor();

                                  // ✅ ensure we attempt loading red markers here too
                                  await _loadGooglePlacesMarkers(force: false);
                                },
                                onCameraMove: _onCameraMoveThrottled,
                                onCameraIdle: () async {
                                  await _updateMyAnchor();
                                  await _updateAnchor();
                                },
                                onTap: (_) => _hidePopup(),
                                markers: allMarkers,
                                zoomControlsEnabled: false,
                                compassEnabled: false,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                mapToolbarEnabled: false,
                                buildingsEnabled: false,
                                trafficEnabled: false,
                              ),

                              // ✅ CURRENT LOCATION MARKER (unchanged)
                              if (_myScreenPx != null)
                                _FadingYouAreHereMarker(
                                  mapSize: Size(mapW, mapH),
                                  anchor: _myScreenPx!,
                                  liftPx: _meLiftPx,
                                  size: _meMarkerSize,
                                  fade: _fadeAnim,
                                ),

                              // ✅ vendor tooltip (unchanged)
                              if (_selected != null &&
                                  _selectedScreenPx != null &&
                                  _vendorByMarker[_selected] != null)
                                _TooltipPositioner(
                                  mapSize: Size(mapW, mapH),
                                  anchor: _selectedScreenPx!,
                                  child: _VendorPopupCard(vendor: _vendorByMarker[_selected]!),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ✅ bottom overlay cards (unchanged)
                    Positioned(
                      left: 4,
                      right: 0,
                      bottom: 18 + pad.bottom,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 17),
                          SizedBox(
                            height: 195,
                            child: _BottomCards(
                              loading: loading,
                              error: state.shopsStatus == ShopsStatus.failure ? state.shopsError : null,
                              shops: state.shops.cast<ShopVendorModel>(),
                              onTapShop: (shop) async {
                                final markerId = MarkerId(
                                  shop.id.isNotEmpty
                                      ? shop.id
                                      : '${shop.shopName}_${shop.latitude}_${shop.longitude}',
                                );
                                final pos = LatLng(shop.latitude, shop.longitude);

                                await _gm?.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(target: pos, zoom: 12.0),
                                  ),
                                );

                                setState(() {
                                  _selected = markerId;
                                  _selectedScreenPx = null;
                                });
                                await _updateAnchor();
                                await _ensureTooltipShowsAbove();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ loading pill (unchanged)
                    if (loading)
                      Positioned(
                        top: 14 + pad.top,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'ClashGrotesk',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =======================
// Everything below is your UI/widgets/helpers (UNCHANGED)
// =======================

class _VendorPopupCard extends StatelessWidget {
  const _VendorPopupCard({required this.vendor});
  final ShopVendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 118,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(5),
                      ),
                      child: Image.network(
                        'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(left: 10, top: 10, child: _ratingPillSmall(vendor.rating)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    vendor.shopName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _circleBlueIcon(Icons.call_rounded),
                const SizedBox(width: 10),
                _circleBlueIcon(Icons.navigation_rounded),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (vendor.services?.trim().isNotEmpty == true)
                  ? vendor.services!.trim()
                  : 'Vehicle inspection service',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13.5,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text(
                  'Closed',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ' - Opens 08:00',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const Image(
                    image: NetworkImage('https://i.pravatar.cc/100?img=11'),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"Fast car inspection service\nand excellent customer service."',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 12.5,
                      color: const Color(0xFF9CA3AF).withOpacity(.95),
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _circleBlueIcon(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

Widget _ratingPillSmall(double rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
            color: Color(0xFF111827),
          ),
        ),
      ],
    ),
  );
}

class _FadingYouAreHereMarker extends StatelessWidget {
  const _FadingYouAreHereMarker({
    required this.mapSize,
    required this.anchor,
    required this.liftPx,
    required this.size,
    required this.fade,
  });

  final Size mapSize;
  final Offset anchor;
  final double liftPx;
  final double size;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    final left = (anchor.dx - size / 2).clamp(6.0, mapSize.width - size - 6.0);
    final top = (anchor.dy - size / 2 - liftPx).clamp(6.0, mapSize.height - size - 6.0);

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: fade,
          builder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 0.25 + (fade.value * 0.75),
                  child: _MeDot(size: size),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    "You're here",
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: Color(0xFF111827),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3B82F6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Center(
        child: Container(
          width: size * 0.25,
          height: size * 0.25,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

class _TooltipPositioner extends StatelessWidget {
  const _TooltipPositioner({
    required this.mapSize,
    required this.anchor,
    required this.child,
  });

  final Size mapSize;
  final Offset anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const cardW = _LocationVendorsMapScreenState._tooltipCardW;
    const cardH = _LocationVendorsMapScreenState._tooltipCardH;
    const gap = _LocationVendorsMapScreenState._tooltipGap;
    const markerLiftPx = _LocationVendorsMapScreenState._markerLiftPx;

    final adjustedAnchor = Offset(anchor.dx, anchor.dy - markerLiftPx);

    final left = (adjustedAnchor.dx - cardW * .55).clamp(12.0, mapSize.width - cardW - 12.0);
    final desiredTop = adjustedAnchor.dy - cardH - gap;
    final top = desiredTop < 12.0 ? 12.0 : desiredTop;

    return Positioned(left: left, top: top, child: child);
  }
}

class _BottomCards extends StatelessWidget {
  const _BottomCards({
    required this.loading,
    required this.error,
    required this.shops,
    required this.onTapShop,
  });

  final bool loading;
  final String? error;
  final List<ShopVendorModel> shops;
  final void Function(ShopVendorModel shop) onTapShop;

  bool _isSponsoredOne(ShopVendorModel v) {
    // supports both bool and int backend mappings
    final dynamic raw = (v as dynamic).isSponsored;
    if (raw is bool) return raw == true;
    if (raw is int) return raw == 1;
    if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 14, right: 14),
        child: Container(
          height: 216,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
              fontFamily: 'ClashGrotesk',
            ),
          ),
        ),
      );
    }

    // ✅ FILTER: only sponsored where "isSponsored": 1
    final sponsoredShops = shops.where(_isSponsoredOne).toList();

    if (sponsoredShops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 14, right: 14),
        child: Container(
          height: 216,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: Text(
            loading ? 'Loading vendors...' : 'No sponsored vendors found',
            style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'ClashGrotesk'),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 14),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (_, i) {
        final v = sponsoredShops[i];
        return GestureDetector(
          onTap: () => onTapShop(v),
          child: _VendorCard(v: v),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemCount: sponsoredShops.length,
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.v});
  final ShopVendorModel v;

  bool get _isSponsoredOne {
    final dynamic raw = (v as dynamic).isSponsored;
    if (raw is bool) return raw == true;
    if (raw is int) return raw == 1;
    if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 122,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                  child: Image.network(
                    'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(left: 10, top: 10, child: _ratingPill(v.rating)),
                if (_isSponsoredOne)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _jsonSponsoredPill(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v.displayAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6C7A91),
                            fontFamily: 'ClashGrotesk',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _jsonSponsoredPill() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: const Text(
      'Sponsored',
      style: TextStyle(
        fontFamily: 'ClashGrotesk',
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: Colors.white,
        letterSpacing: .2,
      ),
    ),
  );
}

Widget _ratingPill(double rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
    child: Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
            fontFamily: 'ClashGrotesk',
          ),
        ),
      ],
    ),
  );
}

Future<BitmapDescriptor> markerFromAssetAtDp(
  BuildContext context,
  String assetPath,
  double logicalDp,
) async {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final targetWidthPx = (logicalDp * dpr).round();

  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: targetWidthPx,
  );
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}



