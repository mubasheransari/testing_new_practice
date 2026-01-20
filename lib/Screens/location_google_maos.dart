import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import '../Bloc/auth_bloc.dart';
import '../Bloc/auth_event.dart';
import '../Bloc/auth_state.dart';

class LocationVendorsMapScreen extends StatefulWidget {
  const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
  final bool showFirstTooltipOnLoad;

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen> {
  GoogleMapController? _gm;

  // ✅ USA Center lat/lng
  static const LatLng usaCenter = LatLng(39.8283, -98.5795);



  static const double _initialZoom = 4.6;

  final Map<MarkerId, ShopVendorModel> _vendorByMarker = {};
  final Set<Marker> _markers = {};

  MarkerId? _selected;
  Offset? _selectedScreenPx;

  BitmapDescriptor? _markerIcon;

  // --- Tooltip sizing constants (USED ONLY FOR POSITIONING) ---
  static const double _tooltipCardW = 292.0; // keep as your original positioning width
  static const double _tooltipCardH = 235.0; // keep as your original positioning height
  static const double _tooltipGap = 14.0; // small gap between marker and card

  // --- Marker lift (to align screenCoordinate with visible marker top) ---
  static const double _markerLiftPx = 62.0; // tune for your custom marker (62dp asset)

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _markerIcon ??= await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);

      // ✅ Trigger API (replace with device current location later)
      context.read<AuthBloc>().add(const FetchNearbyShopsRequested(
            latitude: 24.91767709433974,
            longitude: 67.1005464655281,
          ));
    });
  }

  void _buildMarkersFromApi(List<ShopVendorModel> shops) {
    _vendorByMarker.clear();
    _markers.clear();

    for (final s in shops) {
      if (s.latitude == 0 || s.longitude == 0) continue;
      if (s.latitude.abs() > 90 || s.longitude.abs() > 180) continue;

      final id = MarkerId(s.id.isNotEmpty ? s.id : '${s.shopName}_${s.latitude}_${s.longitude}');
      _vendorByMarker[id] = s;

      _markers.add(
        Marker(
          markerId: id,
          position: LatLng(s.latitude, s.longitude),
          icon: _markerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

          // ⚠️ Keep your current anchor (no functional change)
          anchor: const Offset(.5, .5),

          // ✅ show popup on marker tap
          onTap: () async {
            setState(() {
              _selected = id;
              _selectedScreenPx = null; // reset until we calculate anchor
            });

            // ensure anchor is calculated after selection
            await _updateAnchor();

            // ✅ NEW: ensure there is space ABOVE marker so tooltip always appears above
            await _ensureTooltipShowsAbove();
          },
        ),
      );
    }

    // if selected marker removed
    if (_selected != null && !_vendorByMarker.containsKey(_selected)) {
      _selected = null;
      _selectedScreenPx = null;
    }

    setState(() {});
  }

  Future<void> _updateAnchor() async {
    if (_gm == null || _selected == null) return;
    final selectedMarker = _markers.where((m) => m.markerId == _selected).toList();
    if (selectedMarker.isEmpty) return;

    final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
    setState(() => _selectedScreenPx = Offset(sc.x.toDouble(), sc.y.toDouble()));
  }

  /// ✅ KEY FIX (no functional change):
  /// Always show tooltip ABOVE marker.
  /// If there's not enough room above (because marker is near top or bottom overlays),
  /// we nudge the camera so the tooltip can fit above.
  Future<void> _ensureTooltipShowsAbove() async {
    if (_gm == null || _selected == null) return;

    final selectedMarker = _markers.where((m) => m.markerId == _selected).toList();
    if (selectedMarker.isEmpty) return;

    // Recompute anchor
    final sc = await _gm!.getScreenCoordinate(selectedMarker.first.position);
    final rawAnchor = Offset(sc.x.toDouble(), sc.y.toDouble());

    // Adjust anchor upward to match the visible marker
    final adjustedAnchor = Offset(rawAnchor.dx, rawAnchor.dy - _markerLiftPx);

    // If tooltip top would go above the screen, scroll map down a bit (so marker goes lower)
    final desiredTop = adjustedAnchor.dy - _tooltipCardH - _tooltipGap;

    // 12px safe min
    const minTop = 12.0;

    if (desiredTop < minTop) {
      final need = (minTop - desiredTop);

      // To create space above, move camera DOWN (positive dy scroll)
      await _gm!.animateCamera(CameraUpdate.scrollBy(0, need));
    } else {
      // Also handle the other case: marker is very low due to bottom cards,
      // and the tooltip is being visually forced down by lack of space.
      // Move camera UP so marker is higher and tooltip sits above clearly.
      //
      // We want the marker Y to be at least (tooltipCardH + gap + minTop) from the top.
      final desiredMarkerY = _tooltipCardH + _tooltipGap + minTop + _markerLiftPx;

      if (rawAnchor.dy < desiredMarkerY) {
        // Already okay (marker is higher), do nothing
      } else {
        // If marker is too low, lift camera UP so marker shifts up and tooltip is clearly above
        // target marker Y near mid-screen:
        final targetY = (MediaQuery.of(context).size.height * 0.55);
        final dy = rawAnchor.dy - targetY;

        if (dy > 0) {
          await _gm!.animateCamera(CameraUpdate.scrollBy(0, dy));
        }
      }
    }

    // Refresh anchor after camera movement
    await _updateAnchor();
  }

  Future<void> _focusFirstShop(List<ShopVendorModel> shops) async {
    if (_gm == null) return;
    if (shops.isEmpty) return;

    final first = shops.firstWhere(
      (x) => x.latitude != 0 && x.longitude != 0 && x.latitude.abs() <= 90 && x.longitude.abs() <= 180,
      orElse: () => shops.first,
    );

    await _gm?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(first.latitude, first.longitude),
          zoom: 11,
        ),
      ),
    );
  }

  void _hidePopup() {
    if (_selected != null || _selectedScreenPx != null) {
      setState(() {
        _selected = null;
        _selectedScreenPx = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        top: true,
        bottom: false,
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (p, c) => p.shopsStatus != c.shopsStatus || p.shops.length != c.shops.length,
          listener: (context, state) async {
            if (state.shopsStatus == ShopsStatus.success) {
              _buildMarkersFromApi(state.shops.cast<ShopVendorModel>());
              await _focusFirstShop(state.shops.cast<ShopVendorModel>());
              await _updateAnchor();
            }
          },
          builder: (context, state) {
            final loading = state.shopsStatus == ShopsStatus.loading;

            return Stack(
              children: [
                // ---------------- MAP ----------------
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final mapW = c.maxWidth;
                      final mapH = c.maxHeight;

                      return Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: usaCenter, // ✅ USA default
                              zoom: _initialZoom,
                            ),
                            onMapCreated: (ctrl) async {
                              _gm = ctrl;
                              await _gm?.setMapStyle(_mapStyleJson);
                              await _updateAnchor();
                            },
                            onCameraIdle: _updateAnchor,
                            onTap: (_) => _hidePopup(),
                            markers: _markers,
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            buildingsEnabled: false,
                            trafficEnabled: false,
                          ),

                          // ✅ POPUP (ALWAYS ABOVE MARKER NOW)
                          if (_selected != null && _selectedScreenPx != null && _vendorByMarker[_selected] != null)
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

                // ---------------- BOTTOM UI ----------------
                Positioned(
                  left: 4,
                  right: 0,
                  bottom: 18 + pad.bottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                              topRight: Radius.circular(999),
                              bottomRight: Radius.circular(999),
                            ),
                            boxShadow: [
                              BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            'Sponsored vendors :',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: Colors.white,
                              fontSize: 19 * s,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      SizedBox(
                        height: 216,
                        child: _BottomCards(
                          loading: loading,
                          error: state.shopsStatus == ShopsStatus.failure ? state.shopsError : null,
                          shops: state.shops,
                          onTapShop: (shop) async {
                            final markerId = MarkerId(
                              shop.id.isNotEmpty ? shop.id : '${shop.shopName}_${shop.latitude}_${shop.longitude}',
                            );
                            final pos = LatLng(shop.latitude, shop.longitude);

                            await _gm?.animateCamera(
                              CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 12.0)),
                            );

                            // ✅ also show popup when tapping card (same as before)
                            setState(() {
                              _selected = markerId;
                              _selectedScreenPx = null;
                            });
                            await _updateAnchor();

                            // ✅ NEW: ensure tooltip is above marker
                            await _ensureTooltipShowsAbove();
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Loading...', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'ClashGrotesk')),
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

// -------------------------- Bottom cards --------------------------
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
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent, fontFamily: 'ClashGrotesk'),
          ),
        ),
      );
    }

    if (shops.isEmpty) {
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
            loading ? 'Loading vendors...' : 'No vendors found',
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
        final v = shops[i];
        return GestureDetector(
          onTap: () => onTapShop(v),
          child: _VendorCard(v: v),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemCount: shops.length,
    );
  }
}

// -------------------------- Popup card (MATCH screenshot) --------------------------
class _VendorPopupCard extends StatelessWidget {
  const _VendorPopupCard({required this.vendor});
  final ShopVendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final img = vendor.shopImageUrl;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230, // ✅ same as screenshot
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
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                  child:        Image.network('https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',fit:  BoxFit.cover,), //_imgOrPlaceholder(img),
                ),
                //  Image.network('https://images.stockcake.com/public/e/6/0/e6043409-056d-4c51-9bce-d49aad63dad0_large/tire-shop-interior-stockcake.jpg',fit: BoxFit.contain,), // _imgOrPlaceholder(img),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _ratingPillSmall(vendor.rating),
                    ),
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

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.v});
  final ShopVendorModel v;

  @override
  Widget build(BuildContext context) {
    final img = v.shopImageUrl;

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



Widget _ratingPill(double rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
    child: Row(children: [
      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
      const SizedBox(width: 4),
      Text(
        rating.toStringAsFixed(1),
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2,   fontFamily: 'ClashGrotesk',),
      ),
    ]),
  );
}

/// ✅ Updated positioner: ALWAYS above marker (no "flip to bottom")
/// It uses a marker lift to align with your custom marker visual.
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

    final left = (adjustedAnchor.dx - cardW * .55).clamp(
      12.0,
      mapSize.width - cardW - 12.0,
    );

    // Always above marker; only clamp to top minimum (do not clamp to bottom)
    final desiredTop = adjustedAnchor.dy - cardH - gap;
    final top = desiredTop < 12.0 ? 12.0 : desiredTop;

    return Positioned(left: left, top: top, child: child);
  }
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

