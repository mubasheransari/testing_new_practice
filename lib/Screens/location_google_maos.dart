import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';



// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ✅ Your project imports
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';

// =====================================================
// LocationVendorsMapScreen
// - Vendor markers: your custom icon + your popup card
// - Google places markers: red marker + CUSTOM popup card
//   - photo + opening hours pulled from Google Place Details API
// =====================================================

class LocationVendorsMapScreen extends StatefulWidget {
  const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
  final bool showFirstTooltipOnLoad;

  static Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('❌ Could not launch dialer');
    }
  }

  static void prewarm(BuildContext context) {
    try {
      _LocationVendorsMapScreenState._preloadVendorIcon(context);

      final box = GetStorage();
      final lat = box.read<double>('last_map_lat');
      final lng = box.read<double>('last_map_lng');

      if (lat != null && lng != null) {
        context.read<AuthBloc>().add(FetchNearbyShopsRequested(latitude: lat, longitude: lng));
        context.read<AuthBloc>().add(
              FetchNearbyPlacesRequested(
                latitude: lat,
                longitude: lng,
                silent: true,
                force: false,
              ),
            );
      }
    } catch (_) {}
  }

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _gm;

  LatLng? _myLatLng;
  Offset? _myScreenPx;

  // ✅ vendor markers (API)
  final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
  final Set<Marker> _vendorMarkers = {};
  BitmapDescriptor? _vendorMarkerIcon;

  // ✅ Places markers -> we keep raw place object by markerId
  final Map<MarkerId, dynamic /* PlaceMarkerData */> _placeByMarker = {};
  MarkerId? _selectedPlaceMarker;
  Offset? _selectedPlaceScreenPx;

  // ✅ place details cache: placeId -> details
  final Map<String, _PlaceDetailsVm> _placeDetailsCache = {};
  final Set<String> _placeDetailsLoading = {};

  // ✅ Prevent overlapping permission/location requests
  bool _locRequestInFlight = false;

  // ✅ If permission denied, still show map using fallback
  bool _locationDenied = false;

  // Change fallback if you want
  static const LatLng _fallbackLatLng = LatLng(37.334606, -122.009102); // Apple Park

  // ✅ selected vendor marker
  MarkerId? _selectedVendorMarker;
  Offset? _selectedVendorScreenPx;

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

  // =====================================================
  // ✅ IMPORTANT: Put your Google Places API Key here
  // Must have: Places API enabled + billing enabled
  // =====================================================
  static const String _placesApiKey = 'AIzaSyBFIEDQXjgT6djAIrXB466aR1oG5EmXojQ';

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

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    // ✅ Never null => no infinite spinner
    _seedInitialLatLngNoPermission();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureVendorMarkerIcon();
      _bootLocationAndMarkersBackground();

      final s = context.read<AuthBloc>().state;
      if (s.places.isEmpty && s.homeLat != null && s.homeLng != null) {
        context.read<AuthBloc>().add(
              FetchNearbyPlacesRequested(
                latitude: s.homeLat!,
                longitude: s.homeLng!,
                silent: false,
                force: false,
              ),
            );
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _camTick?.cancel();
    super.dispose();
  }

  Offset _toLogicalOffset(ScreenCoordinate sc) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Offset(sc.x / dpr, sc.y / dpr);
  }

  // ✅ does NOT ask permission, does NOT call geolocator
  void _seedInitialLatLngNoPermission() {
    final box = GetStorage();
    final cachedLat = box.read<double>('last_map_lat');
    final cachedLng = box.read<double>('last_map_lng');

    final s = context.read<AuthBloc>().state;
    final LatLng start = (cachedLat != null && cachedLng != null)
        ? LatLng(cachedLat, cachedLng)
        : (s.homeLat != null && s.homeLng != null)
            ? LatLng(s.homeLat!, s.homeLng!)
            : _fallbackLatLng;

    _myLatLng = start;

    // ✅ fire early requests
    context.read<AuthBloc>().add(
          FetchNearbyShopsRequested(latitude: start.latitude, longitude: start.longitude),
        );
    context.read<AuthBloc>().add(
          FetchNearbyPlacesRequested(
            latitude: start.latitude,
            longitude: start.longitude,
            silent: true,
            force: false,
          ),
        );

    setState(() {});
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

  Future<bool> _hasLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied && perm != LocationPermission.deniedForever;
  }

  Future<void> _bootLocationAndMarkersBackground() async {
    if (_locRequestInFlight) return;
    _locRequestInFlight = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _locationDenied = true;
        if (mounted) setState(() {});
        return;
      }

      final ok = await _hasLocationPermission();
      if (!ok) {
        _locationDenied = true;
        if (mounted) setState(() {});
        return;
      }

      _locationDenied = false;

      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final newPos = LatLng(p.latitude, p.longitude);

      final changed = _myLatLng == null ||
          (_myLatLng!.latitude - newPos.latitude).abs() > 0.00001 ||
          (_myLatLng!.longitude - newPos.longitude).abs() > 0.00001;

      if (changed) {
        _myLatLng = newPos;

        final box = GetStorage();
        box.write('last_map_lat', p.latitude);
        box.write('last_map_lng', p.longitude);

        if (mounted) setState(() {});
        await _gm?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: newPos, zoom: 15)),
        );
      }

      // ✅ fetch using CURRENT location
      context.read<AuthBloc>().add(FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude));
      context.read<AuthBloc>().add(
            FetchNearbyPlacesRequested(
              latitude: p.latitude,
              longitude: p.longitude,
              silent: true,
              force: false,
            ),
          );

      await _updateMyAnchor();
      await _updateVendorAnchor();
      await _updatePlaceAnchor();
    } catch (e) {
      debugPrint('❌ _bootLocationAndMarkersBackground error: $e');
    } finally {
      _locRequestInFlight = false;
    }
  }

  void _onCameraMoveThrottled(CameraPosition _) {
    if (_camTick?.isActive == true) return;
    _camTick = Timer(const Duration(milliseconds: 35), () async {
      await _updateMyAnchor();
      await _updateVendorAnchor();
      await _updatePlaceAnchor();
    });
  }

  Future<void> _updateMyAnchor() async {
    if (_gm == null || _myLatLng == null) return;
    final sc = await _gm!.getScreenCoordinate(_myLatLng!);
    if (!mounted) return;
    setState(() => _myScreenPx = _toLogicalOffset(sc));
  }

  // =========================
  // ✅ Vendor markers + popup
  // =========================
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
            // close place popup if open
            if (_selectedPlaceMarker != null) {
              setState(() {
                _selectedPlaceMarker = null;
                _selectedPlaceScreenPx = null;
              });
            }

            setState(() {
              _selectedVendorMarker = id;
              _selectedVendorScreenPx = null;
            });

            await _updateVendorAnchor();
            await _ensureVendorTooltipShowsAbove();
          },
          zIndex: 3.0,
        ),
      );
    }

    if (_selectedVendorMarker != null && !_vendorByMarker.containsKey(_selectedVendorMarker)) {
      _selectedVendorMarker = null;
      _selectedVendorScreenPx = null;
    }

    setState(() {});
  }

  Future<void> _updateVendorAnchor() async {
    if (_gm == null || _selectedVendorMarker == null) return;
    final v = _vendorByMarker[_selectedVendorMarker];
    if (v == null) return;

    final sc = await _gm!.getScreenCoordinate(LatLng(v.latitude, v.longitude));
    if (!mounted) return;
    setState(() => _selectedVendorScreenPx = _toLogicalOffset(sc));
  }

  Future<void> _ensureVendorTooltipShowsAbove() async {
    if (_gm == null || _selectedVendorMarker == null) return;
    final v = _vendorByMarker[_selectedVendorMarker];
    if (v == null) return;

    final sc = await _gm!.getScreenCoordinate(LatLng(v.latitude, v.longitude));
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

    await _updateVendorAnchor();
  }

  // ==========================================
  // ✅ Google places markers + CUSTOM popup
  // - Uses Place Details API for photo + hours
  // ==========================================
  Set<Marker> _placesMarkersFromState(AuthState state) {
    _placeByMarker.clear();
    if (state.places.isEmpty) return {};

    return state.places.map((p) {
      // p is PlaceMarkerData (your model)
      final MarkerId id = MarkerId('g_${p.id}');
      _placeByMarker[id] = p;

      return Marker(
        markerId: id,
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(.5, .5),

        // ✅ IMPORTANT: disable default info window (we show custom overlay)
        infoWindow:  InfoWindow.noText,

        onTap: () async {
          // close vendor popup if open
          if (_selectedVendorMarker != null) {
            setState(() {
              _selectedVendorMarker = null;
              _selectedVendorScreenPx = null;
            });
          }

          setState(() {
            _selectedPlaceMarker = id;
            _selectedPlaceScreenPx = null;
          });

          await _updatePlaceAnchor();
          await _ensurePlaceTooltipShowsAbove();

          // ✅ fetch details for this placeId -> image + hours
          await _fetchPlaceDetails(p.id.toString());

          // ✅ re-anchor (card height can change)
          await _updatePlaceAnchor();
          await _ensurePlaceTooltipShowsAbove();
        },
        zIndex: 2.0,
      );
    }).toSet();
  }

  Future<void> _updatePlaceAnchor() async {
    if (_gm == null || _selectedPlaceMarker == null) return;
    final p = _placeByMarker[_selectedPlaceMarker];
    if (p == null) return;

    final sc = await _gm!.getScreenCoordinate(LatLng(p.lat, p.lng));
    if (!mounted) return;
    setState(() => _selectedPlaceScreenPx = _toLogicalOffset(sc));
  }

  Future<void> _ensurePlaceTooltipShowsAbove() async {
    if (_gm == null || _selectedPlaceMarker == null) return;
    final p = _placeByMarker[_selectedPlaceMarker];
    if (p == null) return;

    final sc = await _gm!.getScreenCoordinate(LatLng(p.lat, p.lng));
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
  }

  Future<void> _openDirections(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('❌ Could not open Google Maps directions');
    }
  }

  // ✅ Place Details API (photo + hours)
  Future<_PlaceDetailsVm?> _fetchPlaceDetails(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    // cache hit
    final cached = _placeDetailsCache[placeId];
    if (cached != null) return cached;

    // avoid parallel
    if (_placeDetailsLoading.contains(placeId)) return null;
    _placeDetailsLoading.add(placeId);
    if (mounted) setState(() {});

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,formatted_address,rating,opening_hours,photos'
        '&key=$_placesApiKey',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        debugPrint('❌ Place details HTTP ${res.statusCode}');
        return null;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      if (status != 'OK') {
        debugPrint('❌ Place details status: $status');
        return null;
      }

      final result = (json['result'] ?? {}) as Map<String, dynamic>;

      final name = (result['name'] ?? '').toString();
      final address = result['formatted_address']?.toString();

      final ratingRaw = result['rating'];
      final rating = (ratingRaw is num) ? ratingRaw.toDouble() : null;

      bool? openNow;
      List<String> weekdayText = const [];
      final opening = result['opening_hours'];
      if (opening is Map<String, dynamic>) {
        final on = opening['open_now'];
        if (on is bool) openNow = on;
        final wt = opening['weekday_text'];
        if (wt is List) weekdayText = wt.map((e) => e.toString()).toList();
      }

      String? photoRef;
      final photos = result['photos'];
      if (photos is List && photos.isNotEmpty) {
        final first = photos.first;
        if (first is Map<String, dynamic>) {
          photoRef = first['photo_reference']?.toString();
        }
      }

      final vm = _PlaceDetailsVm(
        placeId: placeId,
        name: name,
        address: address,
        rating: rating,
        openNow: openNow,
        weekdayText: weekdayText,
        photoRef: photoRef,
      );

      _placeDetailsCache[placeId] = vm;
      return vm;
    } catch (e) {
      debugPrint('❌ _fetchPlaceDetails error: $e');
      return null;
    } finally {
      _placeDetailsLoading.remove(placeId);
      if (mounted) setState(() {});
    }
  }

  void _hidePopup() {
    if (_selectedVendorMarker != null || _selectedVendorScreenPx != null) {
      setState(() {
        _selectedVendorMarker = null;
        _selectedVendorScreenPx = null;
      });
    }
    if (_selectedPlaceMarker != null || _selectedPlaceScreenPx != null) {
      setState(() {
        _selectedPlaceMarker = null;
        _selectedPlaceScreenPx = null;
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
          listenWhen: (p, c) =>
              p.shopsStatus != c.shopsStatus ||
              p.shops.length != c.shops.length ||
              p.placesStatus != c.placesStatus ||
              p.places.length != c.places.length,
          listener: (context, state) async {
            if (state.shopsStatus == ShopsStatus.success) {
              await _ensureVendorMarkerIcon();
              _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
              await _updateMyAnchor();
              await _updateVendorAnchor();
              await _updatePlaceAnchor();
            }
          },
          builder: (context, state) {
            final myPos = _myLatLng ?? _fallbackLatLng;
            final loading = state.shopsStatus == ShopsStatus.loading;

            if (state.shopsStatus == ShopsStatus.success) {
              _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
            }

            final placesMarkers = _placesMarkersFromState(state);

            final allMarkers = <Marker>{
              ..._vendorMarkers,
              ...placesMarkers,
            };

            // selected place details for popup
            dynamic selectedPlace;
            _PlaceDetailsVm? selectedDetails;
            bool selectedDetailsLoading = false;
            if (_selectedPlaceMarker != null) {
              selectedPlace = _placeByMarker[_selectedPlaceMarker];
              if (selectedPlace != null) {
                final placeId = selectedPlace.id.toString();
                selectedDetails = _placeDetailsCache[placeId];
                selectedDetailsLoading = _placeDetailsLoading.contains(placeId);
              }
            }

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
                            initialCameraPosition: CameraPosition(target: myPos, zoom: 15),
                            onMapCreated: (ctrl) async {
                              _gm = ctrl;
                              await _gm?.setMapStyle(_mapStyleJson);

                              await _gm?.animateCamera(
                                CameraUpdate.newCameraPosition(CameraPosition(target: myPos, zoom: 15)),
                              );

                              await _updateMyAnchor();
                              await _updateVendorAnchor();
                              await _updatePlaceAnchor();

                              // ✅ request places when map opens
                              context.read<AuthBloc>().add(
                                    FetchNearbyPlacesRequested(
                                      latitude: myPos.latitude,
                                      longitude: myPos.longitude,
                                      silent: true,
                                      force: false,
                                    ),
                                  );
                            },
                            onCameraMove: _onCameraMoveThrottled,
                            onCameraIdle: () async {
                              await _updateMyAnchor();
                              await _updateVendorAnchor();
                              await _updatePlaceAnchor();
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

                          // ✅ current location marker
                          if (_myScreenPx != null)
                            _FadingYouAreHereMarker(
                              mapSize: Size(mapW, mapH),
                              anchor: _myScreenPx!,
                              liftPx: _meLiftPx,
                              size: _meMarkerSize,
                              fade: _fadeAnim,
                            ),

                          // ✅ vendor custom popup
                          if (_selectedVendorMarker != null &&
                              _selectedVendorScreenPx != null &&
                              _vendorByMarker[_selectedVendorMarker] != null)
                            _TooltipPositioner(
                              mapSize: Size(mapW, mapH),
                              anchor: _selectedVendorScreenPx!,
                              child: _VendorPopupCard(vendor: _vendorByMarker[_selectedVendorMarker]!),
                            ),

                          // ✅ place custom popup (photo + hours from Google)
                          if (_selectedPlaceMarker != null &&
                              _selectedPlaceScreenPx != null &&
                              selectedPlace != null)
                            _TooltipPositioner(
                              mapSize: Size(mapW, mapH),
                              anchor: _selectedPlaceScreenPx!,
                              child: _PlacePopupCard(
                                place: selectedPlace,
                                details: selectedDetails,
                                loading: selectedDetailsLoading,
                                placesApiKey: _placesApiKey,
                                onTapDirections: () => _openDirections(selectedPlace.lat, selectedPlace.lng),
                              ),
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
                              CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 12.0)),
                            );

                            // close place popup
                            if (_selectedPlaceMarker != null) {
                              setState(() {
                                _selectedPlaceMarker = null;
                                _selectedPlaceScreenPx = null;
                              });
                            }

                            setState(() {
                              _selectedVendorMarker = markerId;
                              _selectedVendorScreenPx = null;
                            });

                            await _updateVendorAnchor();
                            await _ensureVendorTooltipShowsAbove();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                if (loading)
                  Positioned(
                    top: 14 + pad.top,
                    right: 14,
                    child: _LoadingPill(text: 'Loading...'),
                  ),

                if (state.placesStatus == PlacesStatus.loading && state.places.isEmpty)
                  Positioned(
                    top: 60 + pad.top,
                    right: 14,
                    child: _LoadingPill(text: 'Loading nearby shops...'),
                  ),

                if (_locationDenied)
                  Positioned(
                    top: 106 + pad.top,
                    right: 14,
                    child: _LoadingPill(
                      text: 'Location denied (showing default area)',
                      showSpinner: false,
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

// ==============================
// Place Details ViewModel
// ==============================
class _PlaceDetailsVm {
  final String placeId;
  final String name;
  final String? address;
  final double? rating;
  final bool? openNow;
  final List<String> weekdayText; // "Monday: 9:00 AM – 6:00 PM"
  final String? photoRef;

  const _PlaceDetailsVm({
    required this.placeId,
    required this.name,
    this.address,
    this.rating,
    this.openNow,
    this.weekdayText = const [],
    this.photoRef,
  });
}

// ==============================
// NEW: Place custom popup card
// - Uses Google details (image + hours)
// ==============================
class _PlacePopupCard extends StatelessWidget {
  const _PlacePopupCard({
    required this.place,
    required this.details,
    required this.loading,
    required this.onTapDirections,
    required this.placesApiKey,
  });

  final dynamic place; // PlaceMarkerData
  final _PlaceDetailsVm? details;
  final bool loading;
  final VoidCallback onTapDirections;
  final String placesApiKey;

  String? _todayTimingLine(List<String> weekdayText) {
    if (weekdayText.isEmpty) return null;
    final idx = DateTime.now().weekday - 1; // Mon=0..Sun=6
    if (idx < 0 || idx >= weekdayText.length) return null;
    return weekdayText[idx]; // "Friday: 9:00 AM – 6:00 PM"
  }

  String? _photoUrl(String? photoRef) {
    if (photoRef == null || photoRef.isEmpty) return null;
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=900'
        '&photoreference=$photoRef'
        '&key=$placesApiKey';
  }

  @override
  Widget build(BuildContext context) {
    final title = (details?.name?.trim().isNotEmpty == true)
        ? details!.name
        : (place.name ?? 'Nearby Shop').toString();

    final rating = details?.rating;
    final openNow = details?.openNow;
    final todayLine = _todayTimingLine(details?.weekdayText ?? const []);
    final imgUrl = _photoUrl(details?.photoRef);

    final address = (details?.address?.trim().isNotEmpty == true) ? details!.address! : '';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackHeader(loading: false),
                      loadingBuilder: (ctx, child, prog) {
                        if (prog == null) return child;
                        return _fallbackHeader(loading: true);
                      },
                    )
                  else
                    _fallbackHeader(loading: loading),

                  Positioned(
                    left: 14,
                    top: 14,
                    child: _ratingPillBig(
                      loading: loading || rating == null,
                      rating: rating,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onTapDirections,
                        child: _circleBlueIcon(Icons.navigation_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (address.isNotEmpty)
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text(
                        openNow == null ? 'Hours' : (openNow ? 'Open' : 'Closed'),
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 16,
                          color: openNow == null
                              ? const Color(0xFF111827)
                              : (openNow ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (todayLine != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            // remove "Monday:"
                            todayLine.replaceFirst(RegExp(r'^\w+:\s*'), ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 16,
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackHeader({required bool loading}) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.storefront, size: 42, color: Color(0xFF9CA3AF)),
      ),
    );
  }

  static Widget _circleBlueIcon(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }

  static Widget _ratingPillBig({required bool loading, required double? rating}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFBBF24)),
          const SizedBox(width: 8),
          Text(
            loading ? '--' : (rating ?? 0).toStringAsFixed(1),
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// Your existing UI/helpers
// =======================

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.text, this.showSpinner = true});
  final String text;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'ClashGrotesk',
            ),
          ),
        ],
      ),
    );
  }
}

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
                InkWell(
                  onTap: () => LocationVendorsMapScreen._makePhoneCall(vendor.phoneNumber.toString()),
                  child: _circleBlueIcon(Icons.call_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (vendor.services?.trim().isNotEmpty == true) ? vendor.services!.trim() : 'Vehicle inspection service',
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

Widget _circleBlueIcon(IconData icon) {
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
            return Opacity(
              opacity: 0.25 + (fade.value * 0.75),
              child: _MeDot(size: size),
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
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 6)),
        ],
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
// ignore_for_file: use_build_context_synchronously

// import 'dart:async';
// import 'dart:ui' as ui;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';

// // ✅ Your project imports
// import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
// import 'package:ios_tiretest_ai/Models/shop_vendor.dart';

// class LocationVendorsMapScreen extends StatefulWidget {
//   const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
//   final bool showFirstTooltipOnLoad;

//   static Future<void> _makePhoneCall(String phone) async {
//     final uri = Uri(scheme: 'tel', path: phone);
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri);
//     } else {
//       debugPrint('❌ Could not launch dialer');
//     }
//   }

//   static void prewarm(BuildContext context) {
//     try {
//       _LocationVendorsMapScreenState._preloadVendorIcon(context);

//       final box = GetStorage();
//       final lat = box.read<double>('last_map_lat');
//       final lng = box.read<double>('last_map_lng');

//       if (lat != null && lng != null) {
//         context.read<AuthBloc>().add(
//               FetchNearbyShopsRequested(latitude: lat, longitude: lng),
//             );

//         context.read<AuthBloc>().add(
//               FetchNearbyPlacesRequested(
//                 latitude: lat,
//                 longitude: lng,
//                 silent: true,
//                 force: false,
//               ),
//             );
//       }
//     } catch (_) {}
//   }

//   @override
//   State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
// }

// class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
//     with TickerProviderStateMixin {
//   GoogleMapController? _gm;

//   LatLng? _myLatLng;
//   Offset? _myScreenPx;

//   // ✅ vendor markers (API) - unchanged UI
//   final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
//   final Set<Marker> _vendorMarkers = {};
//   BitmapDescriptor? _vendorMarkerIcon;

//   // ✅ Places marker info window support
//   MarkerId? _selectedPlaceId;

//   // ✅ Prevent overlapping permission/location requests
//   bool _locRequestInFlight = false;

//   // ✅ If permission denied, we still show map using fallback
//   bool _locationDenied = false;

//   // You can change this fallback to your preferred default (Melbourne, etc.)
//   static const LatLng _fallbackLatLng = LatLng(37.334606, -122.009102); // Apple Park

// Set<Marker> _placesMarkersFromState(AuthState state) {
//   if (state.places.isEmpty) return {};

//   return state.places.map((p) {
//     final id = MarkerId('g_${p.id}');

//     return Marker(
//       markerId: id,
//       position: LatLng(p.lat, p.lng),
//       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//       anchor: const Offset(.5, .5),

//       // ✅ Google info window
//       infoWindow: InfoWindow(
//         title: p.name,
//         // ✅ optional: show coords as snippet (always available)
//         snippet: '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
//       ),

//       // ✅ force show info window on tap
//       onTap: () => _onPlaceMarkerTap(id),
//       zIndex: 2.0,
//     );
//   }).toSet();
// }

//   void _onPlaceMarkerTap(MarkerId id) async {
//     _hidePopup(); // hide vendor tooltip if any
//     setState(() => _selectedPlaceId = id);

//     try {
//       await _gm?.showMarkerInfoWindow(id); // ✅ force show
//     } catch (_) {}
//   }

//   MarkerId? _selected;
//   Offset? _selectedScreenPx;

//   static const double _tooltipCardW = 292.0;
//   static const double _tooltipCardH = 235.0;
//   static const double _tooltipGap = 14.0;
//   static const double _markerLiftPx = 62.0;

//   late final AnimationController _fadeCtrl;
//   late final Animation<double> _fadeAnim;

//   static const double _meMarkerSize = 34;
//   static const double _meLiftPx = 12;

//   static const double _bottomOverlayHeight = 195 + 17 + 18;

//   Timer? _camTick;

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

//     // ✅ Set initial position immediately (cache -> bloc home -> fallback)
//     _seedInitialLatLngNoPermission();

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await _ensureVendorMarkerIcon();

//       // ✅ Try location in background (won't block UI and won't crash if denied)
//       _bootLocationAndMarkersBackground();

//       // If places empty but state has home lat/lng, request them (show pill)
//       final s = context.read<AuthBloc>().state;
//       if (s.places.isEmpty && s.homeLat != null && s.homeLng != null) {
//         context.read<AuthBloc>().add(
//               FetchNearbyPlacesRequested(
//                 latitude: s.homeLat!,
//                 longitude: s.homeLng!,
//                 silent: false,
//                 force: false,
//               ),
//             );
//       }
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

//   // ✅ IMPORTANT: does NOT ask for permission, does NOT call geolocator.
//   // It ensures _myLatLng is never null -> no infinite spinner.
//   void _seedInitialLatLngNoPermission() {
//     final box = GetStorage();
//     final cachedLat = box.read<double>('last_map_lat');
//     final cachedLng = box.read<double>('last_map_lng');

//     final s = context.read<AuthBloc>().state;
//     final LatLng start = (cachedLat != null && cachedLng != null)
//         ? LatLng(cachedLat, cachedLng)
//         : (s.homeLat != null && s.homeLng != null)
//             ? LatLng(s.homeLat!, s.homeLng!)
//             : _fallbackLatLng;

//     _myLatLng = start;

//     // ✅ fire shops/places early using available position
//     context.read<AuthBloc>().add(
//           FetchNearbyShopsRequested(latitude: start.latitude, longitude: start.longitude),
//         );
//     context.read<AuthBloc>().add(
//           FetchNearbyPlacesRequested(
//             latitude: start.latitude,
//             longitude: start.longitude,
//             silent: true,
//             force: false,
//           ),
//         );

//     setState(() {});
//   }

//   static Future<void> _preloadVendorIcon(BuildContext context) async {
//     try {
//       await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
//     } catch (_) {}
//   }

//   Future<void> _ensureVendorMarkerIcon() async {
//     if (_vendorMarkerIcon != null) return;
//     _vendorMarkerIcon = await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
//   }

//   Future<bool> _hasLocationPermission() async {
//     var perm = await Geolocator.checkPermission();
//     if (perm == LocationPermission.denied) {
//       perm = await Geolocator.requestPermission();
//     }
//     return perm != LocationPermission.denied && perm != LocationPermission.deniedForever;
//   }

//   Future<void> _bootLocationAndMarkersBackground() async {
//     if (_locRequestInFlight) return;
//     _locRequestInFlight = true;

//     try {
//       final enabled = await Geolocator.isLocationServiceEnabled();
//       if (!enabled) {
//         _locationDenied = true;
//         _locRequestInFlight = false;
//         return;
//       }

//       final ok = await _hasLocationPermission();
//       if (!ok) {
//         // ✅ don't crash, just mark denied and keep current map position
//         _locationDenied = true;
//         _locRequestInFlight = false;
//         if (mounted) setState(() {});
//         return;
//       }

//       _locationDenied = false;

//       final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
//       final newPos = LatLng(p.latitude, p.longitude);

//       final changed = _myLatLng == null ||
//           (_myLatLng!.latitude - newPos.latitude).abs() > 0.00001 ||
//           (_myLatLng!.longitude - newPos.longitude).abs() > 0.00001;

//       if (changed) {
//         _myLatLng = newPos;

//         final box = GetStorage();
//         box.write('last_map_lat', p.latitude);
//         box.write('last_map_lng', p.longitude);

//         if (mounted) setState(() {});
//         await _gm?.animateCamera(
//           CameraUpdate.newCameraPosition(CameraPosition(target: newPos, zoom: 15)),
//         );
//       }

//       // ✅ fetch shops/places using CURRENT location
//       context.read<AuthBloc>().add(
//             FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
//           );
//       context.read<AuthBloc>().add(
//             FetchNearbyPlacesRequested(
//               latitude: p.latitude,
//               longitude: p.longitude,
//               silent: true,
//               force: false,
//             ),
//           );

//       await _updateMyAnchor();
//       await _updateAnchor();
//     } catch (e) {
//       debugPrint('❌ _bootLocationAndMarkersBackground error: $e');
//     } finally {
//       _locRequestInFlight = false;
//     }
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
//             // hide google info window if open
//             if (_selectedPlaceId != null) {
//               try {
//                 await _gm?.hideMarkerInfoWindow(_selectedPlaceId!);
//               } catch (_) {}
//               _selectedPlaceId = null;
//             }

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

//     setState(() {});
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

//     if (_selectedPlaceId != null) {
//       final id = _selectedPlaceId!;
//       _selectedPlaceId = null;
//       try {
//         _gm?.hideMarkerInfoWindow(id);
//       } catch (_) {}
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
//               p.shopsStatus != c.shopsStatus ||
//               p.shops.length != c.shops.length ||
//               p.placesStatus != c.placesStatus ||
//               p.places.length != c.places.length,
//           listener: (context, state) async {
//             if (state.shopsStatus == ShopsStatus.success) {
//               await _ensureVendorMarkerIcon();
//               _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
//               await _updateMyAnchor();
//               await _updateAnchor();
//             }

//             if (_selectedPlaceId != null) {
//               try {
//                 await _gm?.showMarkerInfoWindow(_selectedPlaceId!);
//               } catch (_) {}
//             }
//           },
//           builder: (context, state) {
//             // ✅ Never show infinite loader now
//             final myPos = _myLatLng ?? _fallbackLatLng;

//             final loading = state.shopsStatus == ShopsStatus.loading;

//             if (state.shopsStatus == ShopsStatus.success) {
//               _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
//             }

//             final placesMarkers = _placesMarkersFromState(state);

//             final allMarkers = <Marker>{
//               ..._vendorMarkers,
//               ...placesMarkers,
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
//                             initialCameraPosition: CameraPosition(target: myPos, zoom: 15),
//                             onMapCreated: (ctrl) async {
//                               _gm = ctrl;
//                               await _gm?.setMapStyle(_mapStyleJson);

//                               // move camera to our current seeded position
//                               await _gm?.animateCamera(
//                                 CameraUpdate.newCameraPosition(
//                                   CameraPosition(target: myPos, zoom: 15),
//                                 ),
//                               );

//                               await _updateMyAnchor();
//                               await _updateAnchor();

//                               // ✅ request places when map opens (silent)
//                               context.read<AuthBloc>().add(
//                                     FetchNearbyPlacesRequested(
//                                       latitude: myPos.latitude,
//                                       longitude: myPos.longitude,
//                                       silent: true,
//                                       force: false,
//                                     ),
//                                   );

//                               if (_selectedPlaceId != null) {
//                                 try {
//                                   await _gm?.showMarkerInfoWindow(_selectedPlaceId!);
//                                 } catch (_) {}
//                               }
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

//                           // ✅ CURRENT LOCATION MARKER (only if we have anchor)
//                           if (_myScreenPx != null)
//                             _FadingYouAreHereMarker(
//                               mapSize: Size(mapW, mapH),
//                               anchor: _myScreenPx!,
//                               liftPx: _meLiftPx,
//                               size: _meMarkerSize,
//                               fade: _fadeAnim,
//                             ),

//                           // ✅ vendor tooltip
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

//                 // ✅ bottom overlay cards (unchanged)
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
//                               shop.id.isNotEmpty
//                                   ? shop.id
//                                   : '${shop.shopName}_${shop.latitude}_${shop.longitude}',
//                             );
//                             final pos = LatLng(shop.latitude, shop.longitude);

//                             await _gm?.animateCamera(
//                               CameraUpdate.newCameraPosition(
//                                 CameraPosition(target: pos, zoom: 12.0),
//                               ),
//                             );

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

//                 // ✅ shops loading pill
//                 if (loading)
//                   Positioned(
//                     top: 14 + pad.top,
//                     right: 14,
//                     child: _LoadingPill(text: 'Loading...'),
//                   ),

//                 // ✅ places loading pill
//                 if (state.placesStatus == PlacesStatus.loading && state.places.isEmpty)
//                   Positioned(
//                     top: 60 + pad.top,
//                     right: 14,
//                     child: _LoadingPill(text: 'Loading nearby shops...'),
//                   ),

//                 // ✅ OPTIONAL tiny permission denied pill (doesn’t change layout)
//                 if (_locationDenied)
//                   Positioned(
//                     top: 106 + pad.top,
//                     right: 14,
//                     child: _LoadingPill(
//                       text: 'Location denied (showing default area)',
//                       showSpinner: false,
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

// // ------------------
// // UI helpers (same as yours)
// // ------------------

// class _LoadingPill extends StatelessWidget {
//   const _LoadingPill({required this.text, this.showSpinner = true});
//   final String text;
//   final bool showSpinner;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(999),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.08),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (showSpinner) ...[
//             const SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Text(
//             text,
//             style: const TextStyle(
//               fontWeight: FontWeight.w600,
//               fontFamily: 'ClashGrotesk',
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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
//                     Positioned(left: 10, top: 10, child: _ratingPillSmall(vendor.rating)),
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
//                 InkWell(
//                   onTap: () => LocationVendorsMapScreen._makePhoneCall(vendor.phoneNumber.toString()),
//                   child: _circleBlueIcon(Icons.call_rounded),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 6),
//             Text(
//               (vendor.services?.trim().isNotEmpty == true)
//                   ? vendor.services!.trim()
//                   : 'Vehicle inspection service',
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
//           ],
//         ),
//       ),
//     );
//   }

//   static Widget _circleBlueIcon(IconData icon) {
//     return Container(
//       width: 34,
//       height: 34,
//       decoration: const BoxDecoration(
//         color: Color(0xFF3B82F6),
//         shape: BoxShape.circle,
//       ),
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
//         BoxShadow(
//           color: Colors.black.withOpacity(.08),
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//         )
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
//             return Opacity(
//               opacity: 0.25 + (fade.value * 0.75),
//               child: _MeDot(size: size),
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
//         border: Border.all(color: Colors.white, width: 4),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF3B82F6).withOpacity(.35),
//             blurRadius: 18,
//             spreadRadius: 2,
//           ),
//           BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 6)),
//         ],
//       ),
//     );
//   }
// }

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
//   final void Function(ShopVendorModel shop) onTapShop;

//   bool _isSponsoredOne(ShopVendorModel v) {
//     final dynamic raw = (v as dynamic).isSponsored;
//     if (raw is bool) return raw == true;
//     if (raw is int) return raw == 1;
//     if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
//     return false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (error != null) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 216,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 16,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             error!,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontWeight: FontWeight.w700,
//               color: Colors.redAccent,
//               fontFamily: 'ClashGrotesk',
//             ),
//           ),
//         ),
//       );
//     }

//     final sponsoredShops = shops.where(_isSponsoredOne).toList();

//     if (sponsoredShops.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 216,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 16,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             loading ? 'Loading vendors...' : 'No sponsored vendors found',
//             style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'ClashGrotesk'),
//           ),
//         ),
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.only(left: 14),
//       scrollDirection: Axis.horizontal,
//       physics: const BouncingScrollPhysics(),
//       itemBuilder: (_, i) {
//         final v = sponsoredShops[i];
//         return GestureDetector(
//           onTap: () => onTapShop(v),
//           child: _VendorCard(v: v),
//         );
//       },
//       separatorBuilder: (_, __) => const SizedBox(width: 14),
//       itemCount: sponsoredShops.length,
//     );
//   }
// }

// class _VendorCard extends StatelessWidget {
//   const _VendorCard({required this.v});
//   final ShopVendorModel v;

//   bool get _isSponsoredOne {
//     final dynamic raw = (v as dynamic).isSponsored;
//     if (raw is bool) return raw == true;
//     if (raw is int) return raw == 1;
//     if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
//     return false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 250,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(9),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.06),
//             blurRadius: 16,
//             offset: const Offset(0, 8),
//           )
//         ],
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             height: 122,
//             width: MediaQuery.of(context).size.width,
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 ClipRRect(
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(9),
//                     topRight: Radius.circular(9),
//                   ),
//                   child: Image.network(
//                     'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//                 Positioned(left: 10, top: 10, child: _ratingPill(v.rating)),
//                 if (_isSponsoredOne)
//                   Positioned(
//                     right: 10,
//                     top: 10,
//                     child: _jsonSponsoredPill(),
//                   ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     v.shopName,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w800,
//                       fontSize: 16,
//                       fontFamily: 'ClashGrotesk',
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         width: 10,
//                         height: 10,
//                         margin: const EdgeInsets.only(top: 3),
//                         decoration: const BoxDecoration(
//                           color: Color(0xFF3B82F6),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           v.displayAddress,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             color: Color(0xFF6C7A91),
//                             fontFamily: 'ClashGrotesk',
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _jsonSponsoredPill() {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(
//       gradient: const LinearGradient(
//         colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
//         begin: Alignment.centerLeft,
//         end: Alignment.centerRight,
//       ),
//       borderRadius: BorderRadius.circular(999),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(.12),
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//         )
//       ],
//     ),
//     child: const Text(
//       'Sponsored',
//       style: TextStyle(
//         fontFamily: 'ClashGrotesk',
//         fontWeight: FontWeight.w900,
//         fontSize: 12,
//         color: Colors.white,
//         letterSpacing: .2,
//       ),
//     ),
//   );
// }

// Widget _ratingPill(double rating) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
//     child: Row(
//       children: [
//         const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
//         const SizedBox(width: 4),
//         Text(
//           rating.toStringAsFixed(1),
//           style: const TextStyle(
//             fontWeight: FontWeight.w800,
//             letterSpacing: .2,
//             fontFamily: 'ClashGrotesk',
//           ),
//         ),
//       ],
//     ),
//   );
// }

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

  static Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('❌ Could not launch dialer');
    }
  }

  static void prewarm(BuildContext context) {
    try {
      _LocationVendorsMapScreenState._preloadVendorIcon(context);

      final box = GetStorage();
      final lat = box.read<double>('last_map_lat');
      final lng = box.read<double>('last_map_lng');

      if (lat != null && lng != null) {
        context.read<AuthBloc>().add(
              FetchNearbyShopsRequested(latitude: lat, longitude: lng),
            );

        // ✅ prewarm places too (silent)
        context.read<AuthBloc>().add(
              FetchNearbyPlacesRequested(
                latitude: lat,
                longitude: lng,
                silent: true,
                force: false,
              ),
            );
      }
    } catch (_) {}
  }

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _gm;

  LatLng? _myLatLng;
  Offset? _myScreenPx;

  // ✅ vendor markers (API) - unchanged UI (custom popup)
  final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
  final Set<Marker> _vendorMarkers = {};
  BitmapDescriptor? _vendorMarkerIcon;

  // ✅ Track which google-place marker is "selected" so we can force-show info window
  MarkerId? _selectedPlaceId;

  // ✅ Places markers are FROM BLoC state (red markers)
  Set<Marker> _placesMarkersFromState(AuthState state) {
    if (state.places.isEmpty) return {};

    return state.places.map((p) {
      // expects p.id, p.name, p.lat, p.lng (as you already use)
      final id = MarkerId('g_${p.id}');

      // Best-effort extra fields (optional)
      final dynamic dp = p; // to safely read optional fields if your model has them
      final String? vicinity = (dp is dynamic && dp.vicinity is String) ? dp.vicinity as String : null;
      final double? rating = (dp is dynamic && dp.rating is num) ? (dp.rating as num).toDouble() : null;

      final snippetParts = <String>[];
      if (vicinity != null && vicinity.trim().isNotEmpty) snippetParts.add(vicinity.trim());
      if (rating != null) snippetParts.add('⭐ ${rating.toStringAsFixed(1)}');

      return Marker(
        markerId: id,
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(.5, .5),

        // ✅ This is the Google Map InfoWindow
        infoWindow: InfoWindow(
          title: p.name,
          snippet: snippetParts.isEmpty ? null : snippetParts.join(' • '),
          // Optional: handle user tapping the info-window itself
          onTap: () {
            // if you want, you can navigate or open details screen here later
          },
        ),

        // ✅ IMPORTANT:
        // When you provide onTap, the default "auto show" can be inconsistent,
        // so we explicitly call showMarkerInfoWindow() to guarantee it.
        onTap: () => _onPlaceMarkerTap(id),
        zIndex: 2.0,
      );
    }).toSet();
  }

  void _onPlaceMarkerTap(MarkerId id) async {
    // Hide vendor popup (so it doesn't overlap)
    _hidePopup();

    setState(() => _selectedPlaceId = id);

    // ✅ Force-show Google info window reliably
    try {
      await _gm?.showMarkerInfoWindow(id);
    } catch (_) {}

    // Keep anchors updated (optional)
    await _updateMyAnchor();
    await _updateAnchor();
  }

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

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _seedLocationFromCacheOrLastKnown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootLocationAndMarkersBackground();

      // ✅ If places empty but state has home lat/lng, request them (show pill)
      final s = context.read<AuthBloc>().state;
      if (s.places.isEmpty && s.homeLat != null && s.homeLng != null) {
        context.read<AuthBloc>().add(
              FetchNearbyPlacesRequested(
                latitude: s.homeLat!,
                longitude: s.homeLng!,
                silent: false,
                force: false,
              ),
            );
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _camTick?.cancel();
    super.dispose();
  }

  Offset _toLogicalOffset(ScreenCoordinate sc) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Offset(sc.x / dpr, sc.y / dpr);
  }

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

      // ✅ fire places early (silent)
      context.read<AuthBloc>().add(
            FetchNearbyPlacesRequested(
              latitude: cachedLat,
              longitude: cachedLng,
              silent: true,
              force: false,
            ),
          );

      setState(() {});
      return;
    }

    // try lastKnown quickly (non-blocking)
    Geolocator.getLastKnownPosition().then((p) {
      if (!mounted) return;
      if (p == null) return;
      if (_myLatLng != null) return;

      _myLatLng = LatLng(p.latitude, p.longitude);

      box.write('last_map_lat', p.latitude);
      box.write('last_map_lng', p.longitude);

      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
          );

      context.read<AuthBloc>().add(
            FetchNearbyPlacesRequested(
              latitude: p.latitude,
              longitude: p.longitude,
              silent: true,
              force: false,
            ),
          );

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

        final box = GetStorage();
        box.write('last_map_lat', p.latitude);
        box.write('last_map_lng', p.longitude);

        if (mounted) setState(() {});

        _gm?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: newPos, zoom: 15)),
        );
      }

      // ✅ fetch shops using CURRENT location
      context.read<AuthBloc>().add(
            FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
          );

      // ✅ fetch places from BLoC (silent background)
      context.read<AuthBloc>().add(
            FetchNearbyPlacesRequested(
              latitude: p.latitude,
              longitude: p.longitude,
              silent: true,
              force: false,
            ),
          );

      // overlay anchors
      await _updateMyAnchor();
      await _updateAnchor();
    } catch (e) {
      debugPrint('❌ _bootLocationAndMarkersBackground error: $e');
    }
  }

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
            // Hide any google info window if open (optional)
            if (_selectedPlaceId != null) {
              try {
                await _gm?.hideMarkerInfoWindow(_selectedPlaceId!);
              } catch (_) {}
              _selectedPlaceId = null;
            }

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
    // hide vendor popup
    if (_selected != null || _selectedScreenPx != null) {
      setState(() {
        _selected = null;
        _selectedScreenPx = null;
      });
    }

    // hide google info window (optional)
    if (_selectedPlaceId != null) {
      final id = _selectedPlaceId!;
      _selectedPlaceId = null;
      try {
        _gm?.hideMarkerInfoWindow(id);
      } catch (_) {}
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
          listenWhen: (p, c) =>
              p.shopsStatus != c.shopsStatus ||
              p.shops.length != c.shops.length ||
              p.placesStatus != c.placesStatus ||
              p.places.length != c.places.length,
          listener: (context, state) async {
            if (state.shopsStatus == ShopsStatus.success) {
              await _ensureVendorMarkerIcon();
              _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
              await _updateMyAnchor();
              await _updateAnchor();
            }

            // ✅ If we had a selected place marker, re-show its info window after rebuilds
            if (_selectedPlaceId != null) {
              try {
                await _gm?.showMarkerInfoWindow(_selectedPlaceId!);
              } catch (_) {}
            }
          },
          builder: (context, state) {
            if (_myLatLng == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final loading = state.shopsStatus == ShopsStatus.loading;

            if (state.shopsStatus == ShopsStatus.success) {
              _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
            }

            // ✅ places markers now from bloc state (with InfoWindow on tap)
            final placesMarkers = _placesMarkersFromState(state);

            // ✅ union markers (API markers + Places red markers)
            final allMarkers = <Marker>{
              ..._vendorMarkers,
              ...placesMarkers,
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

                              _gm?.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(target: _myLatLng!, zoom: 15),
                                ),
                              );

                              await _updateMyAnchor();
                              await _updateAnchor();

                              // ✅ ensure places requested when map opens (silent)
                              if (_myLatLng != null) {
                                context.read<AuthBloc>().add(
                                      FetchNearbyPlacesRequested(
                                        latitude: _myLatLng!.latitude,
                                        longitude: _myLatLng!.longitude,
                                        silent: true,
                                        force: false,
                                      ),
                                    );
                              }

                              // ✅ if a place is selected already, show its info window after map is ready
                              if (_selectedPlaceId != null) {
                                try {
                                  await _gm?.showMarkerInfoWindow(_selectedPlaceId!);
                                } catch (_) {}
                              }
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

                // ✅ OPTIONAL: Places loading pill (same style)
                if (state.placesStatus == PlacesStatus.loading && state.places.isEmpty)
                  Positioned(
                    top: 60 + pad.top,
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
                            'Loading nearby shops...',
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
                InkWell(
                  onTap: () {
                    LocationVendorsMapScreen._makePhoneCall(vendor.phoneNumber.toString());
                  },
                  child: _circleBlueIcon(Icons.call_rounded),
                ),
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
*/

// class LocationVendorsMapScreen extends StatefulWidget {
//   const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
//   final bool showFirstTooltipOnLoad;
  
//   Future<void> _makePhoneCall(String phone) async {
//   final uri = Uri(scheme: 'tel', path: phone);
//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri);
//   } else {
//     debugPrint('❌ Could not launch dialer');
//   }
// }
//   static void prewarm(BuildContext context) {
//     try {
//       _LocationVendorsMapScreenState._preloadVendorIcon(context);

//       final box = GetStorage();
//       final lat = box.read<double>('last_map_lat');
//       final lng = box.read<double>('last_map_lng');

//       if (lat != null && lng != null) {
//         context.read<AuthBloc>().add(
//               FetchNearbyShopsRequested(latitude: lat, longitude: lng),
//             );

//         // ✅ prewarm places too (silent)
//         context.read<AuthBloc>().add(
//               FetchNearbyPlacesRequested(
//                 latitude: lat,
//                 longitude: lng,
//                 silent: true,
//                 force: false,
//               ),
//             );
//       }
//     } catch (_) {}
//   }

//   @override
//   State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
// }

// class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen>
//     with TickerProviderStateMixin {
//   GoogleMapController? _gm;

//   LatLng? _myLatLng;
//   Offset? _myScreenPx;

//   // ✅ vendor markers (API) - unchanged UI
//   final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
//   final Set<Marker> _vendorMarkers = {};
//   BitmapDescriptor? _vendorMarkerIcon;

//   // ✅ Places markers are now FROM BLoC state (red markers)
//   Set<Marker> _placesMarkersFromState(AuthState state) {
//     if (state.places.isEmpty) return {};

//     return state.places.map((p) {
//       final id = MarkerId('g_${p.id}');
//       return Marker(
//         markerId: id,
//         position: LatLng(p.lat, p.lng),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//         anchor: const Offset(.5, .5),
//         infoWindow: InfoWindow(title: p.name),
//         onTap: _hidePopup,
//         zIndex: 2.0,
//       );
//     }).toSet();
//   }

//   MarkerId? _selected;
//   Offset? _selectedScreenPx;

//   static const double _tooltipCardW = 292.0;
//   static const double _tooltipCardH = 235.0;
//   static const double _tooltipGap = 14.0;
//   static const double _markerLiftPx = 62.0;

//   late final AnimationController _fadeCtrl;
//   late final Animation<double> _fadeAnim;

//   static const double _meMarkerSize = 34;
//   static const double _meLiftPx = 12;

//   static const double _bottomOverlayHeight = 195 + 17 + 18;

//   Timer? _camTick;

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

//     _seedLocationFromCacheOrLastKnown();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _bootLocationAndMarkersBackground();

//       // ✅ If places empty but state has home lat/lng, request them (show pill)
//       final s = context.read<AuthBloc>().state;
//       if (s.places.isEmpty && s.homeLat != null && s.homeLng != null) {
//         context.read<AuthBloc>().add(
//               FetchNearbyPlacesRequested(
//                 latitude: s.homeLat!,
//                 longitude: s.homeLng!,
//                 silent: false,
//                 force: false,
//               ),
//             );
//       }
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

//   void _seedLocationFromCacheOrLastKnown() {
//     final box = GetStorage();
//     final cachedLat = box.read<double>('last_map_lat');
//     final cachedLng = box.read<double>('last_map_lng');

//     if (cachedLat != null && cachedLng != null) {
//       _myLatLng = LatLng(cachedLat, cachedLng);

//       // fire shops early
//       context.read<AuthBloc>().add(
//             FetchNearbyShopsRequested(latitude: cachedLat, longitude: cachedLng),
//           );

//       // ✅ fire places early (silent)
//       context.read<AuthBloc>().add(
//             FetchNearbyPlacesRequested(
//               latitude: cachedLat,
//               longitude: cachedLng,
//               silent: true,
//               force: false,
//             ),
//           );

//       setState(() {});
//       return;
//     }

//     // try lastKnown quickly (non-blocking)
//     Geolocator.getLastKnownPosition().then((p) {
//       if (!mounted) return;
//       if (p == null) return;
//       if (_myLatLng != null) return;

//       _myLatLng = LatLng(p.latitude, p.longitude);

//       box.write('last_map_lat', p.latitude);
//       box.write('last_map_lng', p.longitude);

//       context.read<AuthBloc>().add(
//             FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
//           );

//       context.read<AuthBloc>().add(
//             FetchNearbyPlacesRequested(
//               latitude: p.latitude,
//               longitude: p.longitude,
//               silent: true,
//               force: false,
//             ),
//           );

//       setState(() {});
//     });
//   }

//   static Future<void> _preloadVendorIcon(BuildContext context) async {
//     try {
//       await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
//     } catch (_) {}
//   }

//   Future<void> _ensureVendorMarkerIcon() async {
//     if (_vendorMarkerIcon != null) return;
//     _vendorMarkerIcon = await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
//   }

//   Future<void> _bootLocationAndMarkersBackground() async {
//     try {
//       await _ensureVendorMarkerIcon();

//       final enabled = await Geolocator.isLocationServiceEnabled();
//       if (!enabled) return;

//       var perm = await Geolocator.checkPermission();
//       if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
//       if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

//       final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

//       final newPos = LatLng(p.latitude, p.longitude);

//       final changed = _myLatLng == null ||
//           (_myLatLng!.latitude - newPos.latitude).abs() > 0.00001 ||
//           (_myLatLng!.longitude - newPos.longitude).abs() > 0.00001;

//       if (changed) {
//         _myLatLng = newPos;

//         final box = GetStorage();
//         box.write('last_map_lat', p.latitude);
//         box.write('last_map_lng', p.longitude);

//         if (mounted) setState(() {});

//         _gm?.animateCamera(
//           CameraUpdate.newCameraPosition(CameraPosition(target: newPos, zoom: 15)),
//         );
//       }

//       // ✅ fetch shops using CURRENT location
//       context.read<AuthBloc>().add(
//             FetchNearbyShopsRequested(latitude: p.latitude, longitude: p.longitude),
//           );

//       // ✅ fetch places from BLoC (silent background)
//       context.read<AuthBloc>().add(
//             FetchNearbyPlacesRequested(
//               latitude: p.latitude,
//               longitude: p.longitude,
//               silent: true,
//               force: false,
//             ),
//           );

//       // overlay anchors
//       await _updateMyAnchor();
//       await _updateAnchor();
//     } catch (e) {
//       debugPrint('❌ _bootLocationAndMarkersBackground error: $e');
//     }
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

//     setState(() {});
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
//               p.shopsStatus != c.shopsStatus ||
//               p.shops.length != c.shops.length ||
//               p.placesStatus != c.placesStatus ||
//               p.places.length != c.places.length,
//           listener: (context, state) async {
//             if (state.shopsStatus == ShopsStatus.success) {
//               await _ensureVendorMarkerIcon();
//               _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
//               await _updateMyAnchor();
//               await _updateAnchor();
//             }
//           },
//           builder: (context, state) {
//             if (_myLatLng == null) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             final loading = state.shopsStatus == ShopsStatus.loading;

//             if (state.shopsStatus == ShopsStatus.success) {
//               _ensureMarkersBuiltIfNeeded(state.shops.cast<ShopVendorModel>());
//             }

//             // ✅ places markers now from bloc state
//             final placesMarkers = _placesMarkersFromState(state);

//             // ✅ union markers (API markers + Places red markers)
//             final allMarkers = <Marker>{
//               ..._vendorMarkers,
//               ...placesMarkers,
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
//                             initialCameraPosition: CameraPosition(target: _myLatLng!, zoom: 15),
//                             onMapCreated: (ctrl) async {
//                               _gm = ctrl;
//                               await _gm?.setMapStyle(_mapStyleJson);

//                               _gm?.animateCamera(
//                                 CameraUpdate.newCameraPosition(
//                                   CameraPosition(target: _myLatLng!, zoom: 15),
//                                 ),
//                               );

//                               await _updateMyAnchor();
//                               await _updateAnchor();

//                               // ✅ ensure places requested when map opens (silent)
//                               if (_myLatLng != null) {
//                                 context.read<AuthBloc>().add(
//                                       FetchNearbyPlacesRequested(
//                                         latitude: _myLatLng!.latitude,
//                                         longitude: _myLatLng!.longitude,
//                                         silent: true,
//                                         force: false,
//                                       ),
//                                     );
//                               }
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

//                           // ✅ CURRENT LOCATION MARKER (unchanged)
//                           if (_myScreenPx != null)
//                             _FadingYouAreHereMarker(
//                               mapSize: Size(mapW, mapH),
//                               anchor: _myScreenPx!,
//                               liftPx: _meLiftPx,
//                               size: _meMarkerSize,
//                               fade: _fadeAnim,
//                             ),

//                           // ✅ vendor tooltip (unchanged)
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

//                 // ✅ bottom overlay cards (unchanged)
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
//                               shop.id.isNotEmpty
//                                   ? shop.id
//                                   : '${shop.shopName}_${shop.latitude}_${shop.longitude}',
//                             );
//                             final pos = LatLng(shop.latitude, shop.longitude);

//                             await _gm?.animateCamera(
//                               CameraUpdate.newCameraPosition(
//                                 CameraPosition(target: pos, zoom: 12.0),
//                               ),
//                             );

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

//                 // ✅ loading pill (unchanged)
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
//                           SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Loading...',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontFamily: 'ClashGrotesk',
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                 // ✅ OPTIONAL: Places loading pill (same style, tiny, no UI change in layout)
//                 if (state.placesStatus == PlacesStatus.loading && state.places.isEmpty)
//                   Positioned(
//                     top: 60 + pad.top,
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
//                           SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Loading nearby shops...',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontFamily: 'ClashGrotesk',
//                             ),
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

// // =======================
// // Everything below is your UI/widgets/helpers (UNCHANGED)
// // =======================

// class _VendorPopupCard extends StatelessWidget {
//   const _VendorPopupCard({required this.vendor});
//   final ShopVendorModel vendor;

//   @override
//   Widget build(BuildContext context) {

//       Future<void> _makePhoneCall(String phone) async {
//   final uri = Uri(scheme: 'tel', path: phone);
//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri);
//   } else {
//     debugPrint('❌ Could not launch dialer');
//   }}
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
//                     Positioned(left: 10, top: 10, child: _ratingPillSmall(vendor.rating)),
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
//                 InkWell(
//                   onTap: (){
//                     _makePhoneCall(vendor.phoneNumber.toString());
//                   },
//                   child: _circleBlueIcon(Icons.call_rounded)),
//                 // const SizedBox(width: 10),
//                 // _circleBlueIcon(Icons.navigation_rounded),
//               ],
//             ),
//             const SizedBox(height: 6),
//             Text(
//               (vendor.services?.trim().isNotEmpty == true)
//                   ? vendor.services!.trim()
//                   : 'Vehicle inspection service',
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

//   static Widget _circleBlueIcon(IconData icon) {
//     return Container(
//       width: 34,
//       height: 34,
//       decoration: const BoxDecoration(
//         color: Color(0xFF3B82F6),
//         shape: BoxShape.circle,
//       ),
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
//         BoxShadow(
//           color: Colors.black.withOpacity(.08),
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//         )
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
//                 Opacity(
//                   opacity: 0.25 + (fade.value * 0.75),
//                   child: _MeDot(size: size),
//                 ),
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(999),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(.10),
//                         blurRadius: 12,
//                         offset: const Offset(0, 6),
//                       ),
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
//           BoxShadow(
//             color: const Color(0xFF3B82F6).withOpacity(.35),
//             blurRadius: 18,
//             spreadRadius: 2,
//           ),
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
//   final void Function(ShopVendorModel shop) onTapShop;

//   bool _isSponsoredOne(ShopVendorModel v) {
//     final dynamic raw = (v as dynamic).isSponsored;
//     if (raw is bool) return raw == true;
//     if (raw is int) return raw == 1;
//     if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
//     return false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (error != null) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 216,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 16,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             error!,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontWeight: FontWeight.w700,
//               color: Colors.redAccent,
//               fontFamily: 'ClashGrotesk',
//             ),
//           ),
//         ),
//       );
//     }

//     final sponsoredShops = shops.where(_isSponsoredOne).toList();

//     if (sponsoredShops.isEmpty) {
//       return Padding(
//         padding: const EdgeInsets.only(left: 14, right: 14),
//         child: Container(
//           height: 216,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(.06),
//                 blurRadius: 16,
//                 offset: const Offset(0, 8),
//               )
//             ],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             loading ? 'Loading vendors...' : 'No sponsored vendors found',
//             style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'ClashGrotesk'),
//           ),
//         ),
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.only(left: 14),
//       scrollDirection: Axis.horizontal,
//       physics: const BouncingScrollPhysics(),
//       itemBuilder: (_, i) {
//         final v = sponsoredShops[i];
//         return GestureDetector(
//           onTap: () => onTapShop(v),
//           child: _VendorCard(v: v),
//         );
//       },
//       separatorBuilder: (_, __) => const SizedBox(width: 14),
//       itemCount: sponsoredShops.length,
//     );
//   }
// }

// class _VendorCard extends StatelessWidget {
//   const _VendorCard({required this.v});
//   final ShopVendorModel v;

//   bool get _isSponsoredOne {
//     final dynamic raw = (v as dynamic).isSponsored;
//     if (raw is bool) return raw == true;
//     if (raw is int) return raw == 1;
//     if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
//     return false;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 250,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(9),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.06),
//             blurRadius: 16,
//             offset: const Offset(0, 8),
//           )
//         ],
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             height: 122,
//             width: MediaQuery.of(context).size.width,
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 ClipRRect(
//                   borderRadius: const BorderRadius.only(
//                     topLeft: Radius.circular(9),
//                     topRight: Radius.circular(9),
//                   ),
//                   child: Image.network(
//                     'https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//                 Positioned(left: 10, top: 10, child: _ratingPill(v.rating)),
//                 if (_isSponsoredOne)
//                   Positioned(
//                     right: 10,
//                     top: 10,
//                     child: _jsonSponsoredPill(),
//                   ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     v.shopName,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w800,
//                       fontSize: 16,
//                       fontFamily: 'ClashGrotesk',
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         width: 10,
//                         height: 10,
//                         margin: const EdgeInsets.only(top: 3),
//                         decoration: const BoxDecoration(
//                           color: Color(0xFF3B82F6),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           v.displayAddress,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             color: Color(0xFF6C7A91),
//                             fontFamily: 'ClashGrotesk',
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _jsonSponsoredPill() {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(
//       gradient: const LinearGradient(
//         colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
//         begin: Alignment.centerLeft,
//         end: Alignment.centerRight,
//       ),
//       borderRadius: BorderRadius.circular(999),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(.12),
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//         )
//       ],
//     ),
//     child: const Text(
//       'Sponsored',
//       style: TextStyle(
//         fontFamily: 'ClashGrotesk',
//         fontWeight: FontWeight.w900,
//         fontSize: 12,
//         color: Colors.white,
//         letterSpacing: .2,
//       ),
//     ),
//   );
// }

// Widget _ratingPill(double rating) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
//     child: Row(
//       children: [
//         const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
//         const SizedBox(width: 4),
//         Text(
//           rating.toStringAsFixed(1),
//           style: const TextStyle(
//             fontWeight: FontWeight.w800,
//             letterSpacing: .2,
//             fontFamily: 'ClashGrotesk',
//           ),
//         ),
//       ],
//     ),
//   );
// }

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
