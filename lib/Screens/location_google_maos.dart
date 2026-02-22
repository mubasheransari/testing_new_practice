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
// LocationVendorsMapScreen.dart
// ✅ SAME UI (all widgets kept as-is)
// ✅ NEW FUNCTIONALITY: prewarm + early marker mapping (no FutureBuilder delay)
// ✅ Sponsored card UI/condition stays same (isSponsored == 1 / true)

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';

import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';
import '../Models/shop_vendor.dart';

class LocationVendorsMapScreen extends StatefulWidget {
  const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
  final bool showFirstTooltipOnLoad;

  /// ✅ Call this in Splash:
  /// WidgetsBinding.instance.addPostFrameCallback((_) {
  ///   LocationVendorsMapScreen.prewarm(context);
  /// });
  ///
  /// What it does:
  /// 1) preload marker icon
  /// 2) if cached lat/lng exists => fire FetchNearbyShopsRequested immediately (markers start early)
  static void prewarm(BuildContext context) {
    try {
      // preload vendor icon early
      // ignore: discarded_futures
      _LocationVendorsMapScreenState._preloadVendorIcon(context);

      // if we have cached last location, trigger shops fetch early
      final box = GetStorage();
      final lat = box.read<double>('last_map_lat');
      final lng = box.read<double>('last_map_lng');
      if (lat != null && lng != null) {
        context.read<AuthBloc>().add(
              FetchNearbyShopsRequested(latitude: lat, longitude: lng),
            );
      }
    } catch (_) {
      // no-op
    }
  }

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _gm;

  LatLng? _myLatLng;
  Offset? _myScreenPx;

  // ✅ vendor markers (API) - unchanged UI
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
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    // ✅ IMPORTANT: no FutureBuilder delay.
    // 1) seed location from cache/lastKnown instantly => map opens fast
    _seedLocationFromCacheOrLastKnown();

    // 2) boot current location + refresh markers in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _bootLocationAndMarkersBackground();
    });
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

  // =========================================================
  // ✅ EARLY MARKER MAPPING STRATEGY
  // - Use cached/lastKnown for instant map + early FetchNearbyShopsRequested
  // - Current location fetched in background and refreshes markers if changed
  // =========================================================

  void _seedLocationFromCacheOrLastKnown() {
    final box = GetStorage();
    final cachedLat = box.read<double>('last_map_lat');
    final cachedLng = box.read<double>('last_map_lng');

    if (cachedLat != null && cachedLng != null) {
      _myLatLng = LatLng(cachedLat, cachedLng);

      // fire shops early
      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(latitude: cachedLat, longitude: cachedLng),
          );

      // also load places in background
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: discarded_futures
        _loadGooglePlacesMarkers(force: false);
      });

      setState(() {});
      return;
    }

    // try lastKnown quickly (non-blocking)
    // ignore: discarded_futures
    Geolocator.getLastKnownPosition().then((p) {
      if (!mounted) return;
      if (p == null) return;
      if (_myLatLng != null) return;

      _myLatLng = LatLng(p.latitude, p.longitude);

      // cache for next time
      box.write('last_map_lat', p.latitude);
      box.write('last_map_lng', p.longitude);

      // fire shops early
      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
          );

      // load places in background
      // ignore: discarded_futures
      _loadGooglePlacesMarkers(force: false);

      setState(() {});
    });
  }

  static Future<void> _preloadVendorIcon(BuildContext context) async {
    try {
      await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
    } catch (_) {}
  }

  Future<void> _ensureVendorMarkerIcon() async {
    if (_vendorMarkerIcon != null) return;
    _vendorMarkerIcon = await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
  }

  Future<void> _bootLocationAndMarkersBackground() async {
    try {
      await _ensureVendorMarkerIcon();

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      final newPos = LatLng(p.latitude, p.longitude);

      final changed = _myLatLng == null ||
          (_myLatLng!.latitude - newPos.latitude).abs() > 0.00001 ||
          (_myLatLng!.longitude - newPos.longitude).abs() > 0.00001;

      if (changed) {
        _myLatLng = newPos;

        // cache latest for splash prewarm
        final box = GetStorage();
        box.write('last_map_lat', p.latitude);
        box.write('last_map_lng', p.longitude);

        if (mounted) setState(() {});

        // smooth camera move if map exists
        // ignore: discarded_futures
        _gm?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: newPos, zoom: 15)),
        );
      }

      // ✅ this is your main condition: always fetch shops using CURRENT location
      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
          );

      // places in background (no UI block)
      // ignore: discarded_futures
      _loadGooglePlacesMarkers(force: false);

      // overlay anchors
      // ignore: discarded_futures
      _updateMyAnchor();
    } catch (e) {
      debugPrint('❌ _bootLocationAndMarkersBackground error: $e');
    }
  }

  // ✅ Google Places loader with MAX coverage (same logic as your code)
  Future<void> _loadGooglePlacesMarkers({bool force = false}) async {
    if (_myLatLng == null) return;
    if (_nearbyTyreShopLoading) return;

    if (!force && _nearbyTyreShopLoaded && _nearbyTyreShopMarkers.isNotEmpty) return;

    if (_googlePlacesApiKey.trim().isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      debugPrint('❌ Google Places key not set. Red markers will not load.');
      return;
    }

    _nearbyTyreShopLoading = true;

    try {
      final lat = _myLatLng!.latitude;
      final lng = _myLatLng!.longitude;

      final dedup = <String, Marker>{};

      // 1) RankByDistance keyword searches
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

      // 3) fallback type=car_repair
      if (dedup.isEmpty) {
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

      // 4) text search fallback if too few
      if (dedup.length < 5) {
        final textQueries = <String>[
          'tyre shop',
          'tire shop',
          'tyre repair',
          'tire repair',
          'puncture repair',
        ];
        for (final q in textQueries) {
          final mk = await _placesTextSearchAllPages(
            lat: lat,
            lng: lng,
            radius: _radiusMeters,
            query: q,
          );
          for (final m in mk) {
            dedup[m.markerId.value] = m;
          }
        }
      }

      final all = dedup.values.toList();
      final tyreOnly = _filterTyreLikeNames(all);
      final finalMarkers = tyreOnly.isNotEmpty ? tyreOnly : all;

      if (!mounted) return;
      setState(() {
        _nearbyTyreShopMarkers
          ..clear()
          ..addAll(finalMarkers);
        _nearbyTyreShopLoaded = true;
      });

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
    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (json['status'] ?? '').toString();
    final results = (json['results'] as List?) ?? const [];

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

      out.addAll(_markersFromPlacesResults(results));

      pageToken = (json['next_page_token'] as String?)?.trim();
      if (pageToken == null || pageToken.isEmpty) break;

      await Future.delayed(const Duration(milliseconds: 1800));
    }

    return out;
  }

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
          zIndex: 2.0,
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
          zIndex: 3.0,
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
        child: BlocConsumer<AuthBloc, AuthState>(
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
            // ✅ show loader ONLY if we truly have no location yet
            if (_myLatLng == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final loading = state.shopsStatus == ShopsStatus.loading;

            if (state.shopsStatus == ShopsStatus.success) {
              _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
            }

            // ✅ union markers (API markers + Google red markers)
            final allMarkers = <Marker>{
              ..._vendorMarkers,
              ..._nearbyTyreShopMarkers,
            };

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

                              // no delay
                              // ignore: discarded_futures
                              _gm?.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(target: _myLatLng!, zoom: 15),
                                ),
                              );

                              await _updateMyAnchor();
                              await _updateAnchor();

                              // ensure we attempt loading red markers here too
                              // ignore: discarded_futures
                              _loadGooglePlacesMarkers(force: false);
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
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

// class LocationVendorsMapScreen extends StatefulWidget {
//   const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
//   final bool showFirstTooltipOnLoad;

//   /// ✅ Call from Splash to preload location + shops + marker asset decode
//   static void prewarm(BuildContext context) {
//     // 1) Pre-cache marker icon (reduces first marker decode delay)
//     precacheImage(const AssetImage('assets/marker_icon.png'), context);

//     // 2) Kick location boot early (cache/last-known/current in your bloc)
//     context.read<AuthBloc>().add(const HomeMapBootRequested(forceRefresh: false));

//     // 3) Kick shops early (ONLY if your bloc needs a separate event)
//     //    Replace with your actual event name, or remove if HomeMapBootRequested
//     //    already triggers shops fetching internally.
//     //
//     // context.read<AuthBloc>().add(const ShopsRequested());
//   }

//   @override
//   State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
// }

// class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
//     with TickerProviderStateMixin {
//   GoogleMapController? _gm;

//   // ✅ we keep local copy for instant UI + anchors
//   LatLng? _myLatLng;
//   Offset? _myScreenPx;

//   final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
//   final Set<Marker> _vendorMarkers = {};
//   BitmapDescriptor? _vendorMarkerIcon;

//   // ✅ Google places red markers (optional)
//   final Set<Marker> _nearbyTyreShopMarkers = {};
//   bool _nearbyTyreShopLoaded = false;
//   bool _nearbyTyreShopLoading = false;

//   // ✅ Your key
//   static const String _googlePlacesApiKey = 'AIzaSyBFIEDQXjgT6djAIrXB466aR1oG5EmXojQ';
//   static const int _radiusMeters = 20000;

//   static const List<String> _placesKeywords = [
//     'tyre',
//     'tire',
//     'tyre shop',
//     'tire shop',
//     'tyre repair',
//     'tire repair',
//     'puncture repair',
//     'wheel alignment',
//     'wheel balancing',
//   ];

//   MarkerId? _selected;
//   Offset? _selectedScreenPx;

//   // Tooltip geometry (KEEP)
//   static const double _tooltipCardW = 292.0;
//   static const double _tooltipCardH = 235.0;
//   static const double _tooltipGap = 14.0;
//   static const double _markerLiftPx = 62.0;

//   late final AnimationController _fadeCtrl;
//   late final Animation<double> _fadeAnim;

//   // You-are-here overlay
//   static const double _meMarkerSize = 34;
//   static const double _meLiftPx = 12;

//   static const double _bottomOverlayHeight = 195 + 17 + 18;
//   Timer? _camTick;

//   // ✅ Default camera if location not ready yet (NO LOADER)
//   static const LatLng _fallback = LatLng(24.8607, 67.0011); // Karachi
//   static const double _fallbackZoom = 13.5;

//   static const _mapStyleJson = '''
//   [
//     {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
//     {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
//     {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
//     {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
//     {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
//     {"featureType":"poi","stylers":[{"visibility":"off"}]},
//     {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
//     {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
//     {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
//     {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
//     {"featureType":"transit","stylers":[{"visibility":"off"}]},
//     {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9f2ff"}]}
//   ]
//   ''';

//   @override
//   void initState() {
//     super.initState();

//     _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
//       ..repeat(reverse: true);
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

//     // ✅ Do NOT block UI. Just ensure boot called (if splash didn't call prewarm)
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<AuthBloc>().add(const HomeMapBootRequested(forceRefresh: false));
//     });
//   }

//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     _camTick?.cancel();
//     super.dispose();
//   }

//   Offset _toLogicalOffset(ScreenCoordinate sc) {
//     final dpr = MediaQuery.of(context).devicePixelRatio;
//     return Offset(sc.x / dpr, sc.y / dpr);
//   }

//   Future<void> _ensureVendorMarkerIcon() async {
//     if (_vendorMarkerIcon != null) return;
//     _vendorMarkerIcon = await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
//   }

//   // ✅ Apply location immediately when state has it
//   Future<void> _applyHomeLocation(double lat, double lng) async {
//     final newPos = LatLng(lat, lng);

//     if (_myLatLng != null) {
//       final d1 = (_myLatLng!.latitude - lat).abs();
//       final d2 = (_myLatLng!.longitude - lng).abs();
//       if (d1 < 0.00001 && d2 < 0.00001) return;
//     }

//     _myLatLng = newPos;
//     if (mounted) setState(() {});

//     // Preload custom icon once (fast)
//     await _ensureVendorMarkerIcon();

//     // Move camera if map exists
//     if (_gm != null) {
//       await _gm!.animateCamera(CameraUpdate.newCameraPosition(
//         CameraPosition(target: _myLatLng!, zoom: 15),
//       ));
//     }

//     // Update overlays
//     await _updateMyAnchor();
//     await _updateAnchor();

//     // Load Places markers (don’t block)
//     unawaited(_loadGooglePlacesMarkers(force: false));
//   }

//   // ✅ Google Places loader (same logic)
//   Future<void> _loadGooglePlacesMarkers({bool force = false}) async {
//     if (_myLatLng == null) return;
//     if (_nearbyTyreShopLoading) return;

//     if (!force && _nearbyTyreShopLoaded && _nearbyTyreShopMarkers.isNotEmpty) return;

//     if (_googlePlacesApiKey.trim().isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
//       debugPrint('❌ Google Places key not set. Red markers will not load.');
//       return;
//     }

//     _nearbyTyreShopLoading = true;

//     try {
//       final lat = _myLatLng!.latitude;
//       final lng = _myLatLng!.longitude;

//       final dedup = <String, Marker>{};

//       for (final k in _placesKeywords) {
//         final mk = await _placesNearbyRankByDistance(lat: lat, lng: lng, keyword: k);
//         for (final m in mk) {
//           dedup[m.markerId.value] = m;
//         }
//       }

//       for (final k in _placesKeywords) {
//         final mk = await _placesNearbySearchAllPages(
//           lat: lat,
//           lng: lng,
//           radius: _radiusMeters,
//           keyword: k,
//           type: null,
//         );
//         for (final m in mk) {
//           dedup[m.markerId.value] = m;
//         }
//       }

//       if (dedup.isEmpty) {
//         final mk = await _placesNearbySearchAllPages(
//           lat: lat,
//           lng: lng,
//           radius: _radiusMeters,
//           keyword: null,
//           type: 'car_repair',
//         );
//         for (final m in mk) {
//           dedup[m.markerId.value] = m;
//         }
//       }

//       final all = dedup.values.toList();
//       final tyreOnly = _filterTyreLikeNames(all);
//       final finalMarkers = tyreOnly.isNotEmpty ? tyreOnly : all;

//       if (!mounted) return;
//       setState(() {
//         _nearbyTyreShopMarkers
//           ..clear()
//           ..addAll(finalMarkers);
//         _nearbyTyreShopLoaded = true;
//       });

//       if (finalMarkers.isEmpty) _nearbyTyreShopLoaded = false;
//     } catch (e) {
//       debugPrint('❌ Places loading failed: $e');
//       _nearbyTyreShopLoaded = false;
//     } finally {
//       _nearbyTyreShopLoading = false;
//     }
//   }

//   List<Marker> _filterTyreLikeNames(List<Marker> markers) {
//     bool ok(String? t) {
//       final s = (t ?? '').toLowerCase();
//       return s.contains('tyre') ||
//           s.contains('tire') ||
//           s.contains('puncture') ||
//           s.contains('wheel') ||
//           s.contains('alignment') ||
//           s.contains('balancing');
//     }

//     return markers.where((m) => ok(m.infoWindow.title)).toList();
//   }

//   Future<List<Marker>> _placesNearbyRankByDistance({
//     required double lat,
//     required double lng,
//     required String keyword,
//   }) async {
//     final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
//       'key': _googlePlacesApiKey,
//       'location': '$lat,$lng',
//       'rankby': 'distance',
//       'keyword': keyword,
//     });

//     final res = await http.get(uri);
//     if (res.statusCode != 200) return [];

//     final json = jsonDecode(res.body) as Map<String, dynamic>;
//     final status = (json['status'] ?? '').toString();
//     final results = (json['results'] as List?) ?? const [];

//     if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') return [];
//     if (status != 'OK' && status != 'ZERO_RESULTS') return [];

//     return _markersFromPlacesResults(results);
//   }

//   Future<List<Marker>> _placesNearbySearchAllPages({
//     required double lat,
//     required double lng,
//     required int radius,
//     String? keyword,
//     String? type,
//   }) async {
//     final out = <Marker>[];
//     String? pageToken;
//     int safety = 0;

//     while (safety < 3) {
//       safety++;

//       final params = <String, String>{
//         'key': _googlePlacesApiKey,
//         'location': '$lat,$lng',
//         'radius': '$radius',
//         if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
//         if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
//         if (pageToken != null) 'pagetoken': pageToken!,
//       };

//       final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', params);
//       final res = await http.get(uri);
//       if (res.statusCode != 200) break;

//       final json = jsonDecode(res.body) as Map<String, dynamic>;
//       final status = (json['status'] ?? '').toString();
//       final results = (json['results'] as List?) ?? const [];

//       if (status == 'REQUEST_DENIED' || status == 'INVALID_KEY') break;

//       if (status == 'INVALID_REQUEST' && pageToken != null) {
//         await Future.delayed(const Duration(milliseconds: 1800));
//         continue;
//       }

//       if (status != 'OK' && status != 'ZERO_RESULTS') break;

//       out.addAll(_markersFromPlacesResults(results));

//       pageToken = (json['next_page_token'] as String?)?.trim();
//       if (pageToken == null || pageToken.isEmpty) break;

//       await Future.delayed(const Duration(milliseconds: 1800));
//     }

//     return out;
//   }

//   List<Marker> _markersFromPlacesResults(List results) {
//     final out = <Marker>[];

//     for (final r in results) {
//       final m = (r as Map).cast<String, dynamic>();

//       final placeId = (m['place_id'] ?? '').toString();
//       final name = (m['name'] ?? 'Tyre shop').toString();

//       final loc = ((m['geometry'] as Map?)?['location'] as Map?) ?? const {};
//       final plat = (loc['lat'] as num?)?.toDouble();
//       final plng = (loc['lng'] as num?)?.toDouble();

//       if (placeId.isEmpty || plat == null || plng == null) continue;

//       final id = MarkerId('g_$placeId');

//       out.add(
//         Marker(
//           markerId: id,
//           position: LatLng(plat, plng),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           anchor: const Offset(.5, .5),
//           infoWindow: InfoWindow(title: name),
//           onTap: _hidePopup,
//           zIndex: 2.0,
//         ),
//       );
//     }

//     return out;
//   }

//   void _onCameraMoveThrottled(CameraPosition _) {
//     if (_camTick?.isActive == true) return;
//     _camTick = Timer(const Duration(milliseconds: 35), () async {
//       await _updateMyAnchor();
//       await _updateAnchor();
//     });
//   }

//   Future<void> _updateMyAnchor() async {
//     if (_gm == null || _myLatLng == null) return;
//     final sc = await _gm!.getScreenCoordinate(_myLatLng!);
//     if (!mounted) return;
//     setState(() => _myScreenPx = _toLogicalOffset(sc));
//   }

//   void _buildMarkersFromApi(List<ShopVendorModel> shops) {
//     _vendorByMarker.clear();
//     _vendorMarkers.clear();

//     for (final s in shops) {
//       if (s.latitude == 0 || s.longitude == 0) continue;
//       if (s.latitude.abs() > 90 || s.longitude.abs() > 180) continue;

//       final id = MarkerId(s.id.isNotEmpty ? s.id : '${s.shopName}_${s.latitude}_${s.longitude}');
//       _vendorByMarker[id] = s;

//       _vendorMarkers.add(
//         Marker(
//           markerId: id,
//           position: LatLng(s.latitude, s.longitude),
//           icon: _vendorMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
//           anchor: const Offset(.5, .5),
//           onTap: () async {
//             setState(() {
//               _selected = id;
//               _selectedScreenPx = null;
//             });
//             await _updateAnchor();
//             await _ensureTooltipShowsAbove();
//           },
//           zIndex: 3.0,
//         ),
//       );
//     }

//     if (_selected != null && !_vendorByMarker.containsKey(_selected)) {
//       _selected = null;
//       _selectedScreenPx = null;
//     }

//     if (mounted) setState(() {});
//   }

//   Future<void> _updateAnchor() async {
//     if (_gm == null || _selected == null) return;
//     final selectedMarker = _vendorMarkers.where((m) => m.markerId == _selected).toList();
//     if (selectedMarker.isEmpty) return;

//     final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
//     if (!mounted) return;
//     setState(() => _selectedScreenPx = _toLogicalOffset(sc));
//   }

//   Future<void> _ensureTooltipShowsAbove() async {
//     if (_gm == null || _selected == null) return;

//     final selectedMarker = _vendorMarkers.where((m) => m.markerId == _selected).toList();
//     if (selectedMarker.isEmpty) return;

//     final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
//     final rawAnchor = _toLogicalOffset(sc);
//     final adjustedAnchor = Offset(rawAnchor.dx, rawAnchor.dy - _markerLiftPx);

//     final desiredTop = adjustedAnchor.dy - _tooltipCardH - _tooltipGap;
//     const minTop = 12.0;

//     if (desiredTop < minTop) {
//       final need = (minTop - desiredTop);
//       await _gm!.animateCamera(CameraUpdate.scrollBy(0, need));
//     } else {
//       final targetY = (MediaQuery.of(context).size.height * 0.55);
//       final dy = rawAnchor.dy - targetY;
//       if (dy > 0) await _gm!.animateCamera(CameraUpdate.scrollBy(0, dy));
//     }

//     await _updateAnchor();
//   }

//   void _hidePopup() {
//     if (_selected != null || _selectedScreenPx != null) {
//       setState(() {
//         _selected = null;
//         _selectedScreenPx = null;
//       });
//     }
//   }

//   void _ensureMarkersBuiltIfNeeded(List<ShopVendorModel> shops) {
//     if (shops.isEmpty) return;
//     if (_vendorMarkers.isNotEmpty) return;

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await _ensureVendorMarkerIcon();
//       if (!mounted) return;
//       _buildMarkersFromApi(shops);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pad = MediaQuery.of(context).padding;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       body: SafeArea(
//         top: true,
//         bottom: false,
//         child: BlocConsumer<AuthBloc, AuthState>(
//           listenWhen: (p, c) =>
//               p.homeLat != c.homeLat ||
//               p.homeLng != c.homeLng ||
//               p.homeMapStatus != c.homeMapStatus ||
//               p.shopsStatus != c.shopsStatus ||
//               p.shops.length != c.shops.length,
//           listener: (context, state) async {
//             // ✅ apply home location as soon as ready
//             if (state.homeMapStatus == HomeMapStatus.ready &&
//                 state.homeLat != null &&
//                 state.homeLng != null) {
//               await _applyHomeLocation(state.homeLat!, state.homeLng!);
//             }

//             // ✅ build shop markers as soon as shops arrive
//             if (state.shopsStatus == ShopsStatus.success) {
//               await _ensureVendorMarkerIcon();
//               _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
//               await _updateMyAnchor();
//               await _updateAnchor();
//             }
//           },
//           builder: (context, state) {
//             // ✅ DO NOT BLOCK UI
//             // Use existing location if already set, else use fallback (instant map)
//             final effectiveLatLng = _myLatLng ??
//                 ((state.homeLat != null && state.homeLng != null)
//                     ? LatLng(state.homeLat!, state.homeLng!)
//                     : _fallback);

//             // keep local latlng in sync if bloc already has it
//             if (_myLatLng == null && state.homeLat != null && state.homeLng != null) {
//               _myLatLng = LatLng(state.homeLat!, state.homeLng!);
//             }

//             final loading = state.shopsStatus == ShopsStatus.loading;

//             if (state.shopsStatus == ShopsStatus.success) {
//               _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
//             }

//             final allMarkers = <Marker>{
//               ..._vendorMarkers,
//               ..._nearbyTyreShopMarkers,
//             };

//             return Stack(
//               children: [
//                 Positioned.fill(
//                   child: LayoutBuilder(
//                     builder: (ctx, c) {
//                       final mapW = c.maxWidth;
//                       final mapH = c.maxHeight;

//                       return Stack(
//                         children: [
//                           GoogleMap(
//                             padding: EdgeInsets.only(bottom: _bottomOverlayHeight + pad.bottom),
//                             initialCameraPosition: CameraPosition(
//                               target: effectiveLatLng,
//                               zoom: _myLatLng != null ? 15 : _fallbackZoom,
//                             ),
//                             onMapCreated: (ctrl) async {
//                               _gm = ctrl;
//                               await _gm?.setMapStyle(_mapStyleJson);

//                               // If we already have real location by now, animate quickly
//                               final target = _myLatLng ?? effectiveLatLng;
//                               await Future.delayed(const Duration(milliseconds: 10));
//                               await _gm?.animateCamera(CameraUpdate.newCameraPosition(
//                                 CameraPosition(target: target, zoom: _myLatLng != null ? 15 : _fallbackZoom),
//                               ));

//                               await _updateMyAnchor();
//                               await _updateAnchor();

//                               // load places (non-blocking)
//                               unawaited(_loadGooglePlacesMarkers(force: false));
//                             },
//                             onCameraMove: _onCameraMoveThrottled,
//                             onCameraIdle: () async {
//                               await _updateMyAnchor();
//                               await _updateAnchor();
//                             },
//                             onTap: (_) => _hidePopup(),
//                             markers: allMarkers,
//                             zoomControlsEnabled: false,
//                             compassEnabled: false,
//                             myLocationEnabled: false,
//                             myLocationButtonEnabled: false,
//                             mapToolbarEnabled: false,
//                             buildingsEnabled: false,
//                             trafficEnabled: false,
//                           ),

//                           // ✅ show “you are here” overlay only when real location exists
//                           if (_myLatLng != null && _myScreenPx != null)
//                             _FadingYouAreHereMarker(
//                               mapSize: Size(mapW, mapH),
//                               anchor: _myScreenPx!,
//                               liftPx: _meLiftPx,
//                               size: _meMarkerSize,
//                               fade: _fadeAnim,
//                             ),

//                           if (_selected != null &&
//                               _selectedScreenPx != null &&
//                               _vendorByMarker[_selected] != null)
//                             _TooltipPositioner(
//                               mapSize: Size(mapW, mapH),
//                               anchor: _selectedScreenPx!,
//                               child: _VendorPopupCard(vendor: _vendorByMarker[_selected]!),
//                             ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),

//                 // ✅ Bottom list (same UI as you had in generated version)
//                 Positioned(
//                   left: 4,
//                   right: 0,
//                   bottom: 18 + pad.bottom,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const SizedBox(height: 17),
//                       SizedBox(
//                         height: 195,
//                         child: _BottomCards(
//                           loading: loading,
//                           error: state.shopsStatus == ShopsStatus.failure ? state.shopsError : null,
//                           shops: state.shops.cast<ShopVendorModel>(),
//                           onTapShop: (shop) async {
//                             final markerId = MarkerId(
//                               shop.id.isNotEmpty ? shop.id : '${shop.shopName}_${shop.latitude}_${shop.longitude}',
//                             );
//                             final pos = LatLng(shop.latitude, shop.longitude);

//                             await _gm?.animateCamera(CameraUpdate.newCameraPosition(
//                               CameraPosition(target: pos, zoom: 12.0),
//                             ));

//                             setState(() {
//                               _selected = markerId;
//                               _selectedScreenPx = null;
//                             });
//                             await _updateAnchor();
//                             await _ensureTooltipShowsAbove();
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // ✅ small loading pill (same UI)
//                 if (loading)
//                   Positioned(
//                     top: 14 + pad.top,
//                     right: 14,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(999),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(.08),
//                             blurRadius: 12,
//                             offset: const Offset(0, 6),
//                           ),
//                         ],
//                       ),
//                       child: const Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
//                           SizedBox(width: 8),
//                           Text(
//                             'Loading...',
//                             style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'ClashGrotesk'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// //
// // ===============================
// // ✅ POPUP CARD (tooltip) - SAME
// // ===============================
// class _VendorPopupCard extends StatelessWidget {
//   const _VendorPopupCard({required this.vendor});
//   final ShopVendorModel vendor;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: Container(
//         width: 230,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.12),
//               blurRadius: 18,
//               offset: const Offset(0, 10),
//             )
//           ],
//         ),
//         padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: SizedBox(
//                 height: 118,
//                 width: MediaQuery.of(context).size.width,
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     ClipRRect(
//                       borderRadius: const BorderRadius.only(
//                         topLeft: Radius.circular(5),
//                         topRight: Radius.circular(5),
//                       ),
//                       child: Image.network(
//                         'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                     Positioned(left: 10, top: 10, child: _ratingPillSmall(_safeRating(vendor.rating))),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     vendor.shopName,
//                     maxLines: 3,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 14,
//                       fontWeight: FontWeight.w900,
//                       color: Color(0xFF111827),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 _circleBlueIcon(Icons.call_rounded),
//                 const SizedBox(width: 10),
//                 _circleBlueIcon(Icons.navigation_rounded),
//               ],
//             ),
//             const SizedBox(height: 6),
//             Text(
//               (vendor.services?.trim().isNotEmpty == true) ? vendor.services!.trim() : 'Vehicle inspection service',
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 13.5,
//                 color: Color(0xFF9CA3AF),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 6),
//             const Row(
//               children: [
//                 Text(
//                   'Closed',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 13.5,
//                     color: Color(0xFFEF4444),
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 Text(
//                   ' - Opens 08:00',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 13.5,
//                     color: Color(0xFF111827),
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 30,
//                   height: 30,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border: Border.all(color: const Color(0xFFE5E7EB)),
//                   ),
//                   clipBehavior: Clip.antiAlias,
//                   child: const Image(
//                     image: NetworkImage('https://i.pravatar.cc/100?img=11'),
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     '"Fast car inspection service\nand excellent customer service."',
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 12.5,
//                       color: const Color(0xFF9CA3AF).withOpacity(.95),
//                       fontWeight: FontWeight.w600,
//                       height: 1.2,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   static double _safeRating(double r) {
//     if (r.isNaN || r.isInfinite) return 0.0;
//     return r.clamp(0.0, 5.0);
//   }

//   static Widget _circleBlueIcon(IconData icon) {
//     return Container(
//       width: 34,
//       height: 34,
//       decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
//       child: Icon(icon, size: 18, color: Colors.white),
//     );
//   }
// }

// Widget _ratingPillSmall(double rating) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(999),
//       boxShadow: [
//         BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 10, offset: const Offset(0, 4))
//       ],
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
//         const SizedBox(width: 4),
//         Text(
//           rating.toStringAsFixed(1),
//           style: const TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontWeight: FontWeight.w900,
//             fontSize: 13.5,
//             color: Color(0xFF111827),
//           ),
//         ),
//       ],
//     ),
//   );
// }

// //
// // ===============================
// // ✅ "YOU'RE HERE" MARKER OVERLAY
// // ===============================
// class _FadingYouAreHereMarker extends StatelessWidget {
//   const _FadingYouAreHereMarker({
//     required this.mapSize,
//     required this.anchor,
//     required this.liftPx,
//     required this.size,
//     required this.fade,
//   });

//   final Size mapSize;
//   final Offset anchor;
//   final double liftPx;
//   final double size;
//   final Animation<double> fade;

//   @override
//   Widget build(BuildContext context) {
//     final left = (anchor.dx - size / 2).clamp(6.0, mapSize.width - size - 6.0);
//     final top = (anchor.dy - size / 2 - liftPx).clamp(6.0, mapSize.height - size - 6.0);

//     return Positioned(
//       left: left,
//       top: top,
//       child: IgnorePointer(
//         child: AnimatedBuilder(
//           animation: fade,
//           builder: (_, __) {
//             return Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Opacity(opacity: 0.25 + (fade.value * 0.75), child: _MeDot(size: size)),
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(999),
//                     boxShadow: [
//                       BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 12, offset: const Offset(0, 6)),
//                     ],
//                   ),
//                   child: const Text(
//                     "You're here",
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontWeight: FontWeight.w900,
//                       fontSize: 12.5,
//                       color: Color(0xFF111827),
//                       letterSpacing: 0.1,
//                     ),
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class _MeDot extends StatelessWidget {
//   const _MeDot({required this.size});
//   final double size;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: const Color(0xFF3B82F6),
//         boxShadow: [
//           BoxShadow(color: const Color(0xFF3B82F6).withOpacity(.35), blurRadius: 18, spreadRadius: 2),
//           BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 6)),
//         ],
//         border: Border.all(color: Colors.white, width: 4),
//       ),
//       child: Center(
//         child: Container(
//           width: size * 0.25,
//           height: size * 0.25,
//           decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
//         ),
//       ),
//     );
//   }
// }

// //
// // ===============================
// // ✅ TOOLTIP POSITIONER
// // ===============================
// class _TooltipPositioner extends StatelessWidget {
//   const _TooltipPositioner({
//     required this.mapSize,
//     required this.anchor,
//     required this.child,
//   });

//   final Size mapSize;
//   final Offset anchor;
//   final Widget child;

//   @override
//   Widget build(BuildContext context) {
//     const cardW = _LocationVendorsMapScreenState._tooltipCardW;
//     const cardH = _LocationVendorsMapScreenState._tooltipCardH;
//     const gap = _LocationVendorsMapScreenState._tooltipGap;
//     const markerLiftPx = _LocationVendorsMapScreenState._markerLiftPx;

//     final adjustedAnchor = Offset(anchor.dx, anchor.dy - markerLiftPx);

//     final left = (adjustedAnchor.dx - cardW * .55).clamp(12.0, mapSize.width - cardW - 12.0);
//     final desiredTop = adjustedAnchor.dy - cardH - gap;
//     final top = desiredTop < 12.0 ? 12.0 : desiredTop;

//     return Positioned(left: left, top: top, child: child);
//   }
// }

// //
// // ===============================
// // ✅ BOTTOM LIST
// // ===============================
// class _BottomCards extends StatelessWidget {
//   const _BottomCards({
//     required this.loading,
//     required this.error,
//     required this.shops,
//     required this.onTapShop,
//   });

//   final bool loading;
//   final String? error;
//   final List<ShopVendorModel> shops;
//   final ValueChanged<ShopVendorModel> onTapShop;

//   @override
//   Widget build(BuildContext context) {
//     if (error != null && shops.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 195,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(18),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 14,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           padding: const EdgeInsets.all(14),
//           child: Row(
//             children: [
//               const Icon(Icons.info_outline_rounded, color: Color(0xFF6B7280)),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   error!,
//                   maxLines: 3,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF374151),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(Icons.refresh_rounded, color: Color(0xFF9CA3AF)),
//             ],
//           ),
//         ),
//       );
//     }

//     if (shops.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 195,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(18),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 14,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           padding: const EdgeInsets.all(14),
//           child: Row(
//             children: [
//               if (loading)
//                 const SizedBox(
//                   width: 18,
//                   height: 18,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 )
//               else
//                 const Icon(Icons.storefront, color: Color(0xFF6B7280)),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   loading ? 'Finding nearby shops...' : 'No nearby shops found',
//                   style: const TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w800,
//                     color: Color(0xFF111827),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return ListView.separated(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.only(left: 14, right: 14),
//       itemBuilder: (_, i) => _VendorCard(
//         vendor: shops[i],
//         onTap: () => onTapShop(shops[i]),
//       ),
//       separatorBuilder: (_, __) => const SizedBox(width: 12),
//       itemCount: shops.length,
//     );
//   }
// }

// //
// // ===============================
// // ✅ BOTTOM SINGLE CARD
// // ===============================
// class _VendorCard extends StatelessWidget {
//   const _VendorCard({required this.vendor, required this.onTap});
//   final ShopVendorModel vendor;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final rating = _safeRating(vendor.rating);

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 265,
//         height: 195,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.07),
//               blurRadius: 14,
//               offset: const Offset(0, 9),
//             )
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ClipRRect(
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(18),
//                 topRight: Radius.circular(18),
//               ),
//               child: SizedBox(
//                 height: 108,
//                 width: double.infinity,
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     Image.network(
//                       'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => Container(
//                         color: const Color(0xFFF3F4F6),
//                         child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
//                       ),
//                     ),
//                     Positioned(left: 10, top: 10, child: _ratingPillSmall(rating)),
//                   ],
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
//               child: Text(
//                 vendor.shopName,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontSize: 14,
//                   fontWeight: FontWeight.w900,
//                   color: Color(0xFF111827),
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
//               child: Text(
//                 (vendor.services?.trim().isNotEmpty == true) ? vendor.services!.trim() : 'Vehicle inspection service',
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF6B7280),
//                 ),
//               ),
//             ),
//             const Spacer(),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//               child: Row(
//                 children: [
//                   const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF9CA3AF)),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       'Tap to view on map',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w700,
//                         color: const Color(0xFF111827).withOpacity(.75),
//                       ),
//                     ),
//                   ),
//                   const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   static double _safeRating(double r) {
//     if (r.isNaN || r.isInfinite) return 0.0;
//     return r.clamp(0.0, 5.0);
//   }
// }

// //
// // ===============================
// // ✅ MARKER ICON LOADER
// // ===============================
// Future<BitmapDescriptor> markerFromAssetAtDp(
//   BuildContext context,
//   String assetPath,
//   double logicalDp,
// ) async {
//   final dpr = MediaQuery.of(context).devicePixelRatio;
//   final targetWidthPx = (logicalDp * dpr).round();

//   final data = await rootBundle.load(assetPath);
//   final codec = await ui.instantiateImageCodec(
//     data.buffer.asUint8List(),
//     targetWidth: targetWidthPx,
//   );
//   final frame = await codec.getNextFrame();
//   final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//   return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
// }
/*
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



*/