import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'dart:ui';


import 'dart:ui';
import 'package:flutter/material.dart';

import 'dart:ui';
import 'package:flutter/material.dart';

enum BottomTab { home, reports, map, about, profile }

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.active,
    required this.onChanged,
    this.scale,
  });

  final BottomTab active;
  final ValueChanged<BottomTab> onChanged;
  final double? scale;

  void _go(BottomTab tab) {
    if (tab == active) return;
    onChanged(tab);
  }

  // Icons
  static const Map<BottomTab, String> _iconPath = {
    BottomTab.home:    'assets/icons8-home-50.png',
    BottomTab.reports: 'assets/history_bottom_icon.png',
    BottomTab.map:     'assets/location_bottom_bar.png',
    BottomTab.about:   'assets/technician_bottom_bar.png',
    BottomTab.profile: 'assets/profile_bottom_bar.png',
  };

  // Optional halos for inactive chips
  static const Map<BottomTab, Color?> _halo = {
    BottomTab.home:    Color(0xFFE3F7F3),
    BottomTab.reports: Color(0xFFE4F2FF),
    BottomTab.map:     null,
    BottomTab.about:   Color(0xFFE4F2FF),
    BottomTab.profile: Color(0xFFE4F2FF),
  };

  @override
  Widget build(BuildContext context) {
    final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

    // ✅ Ensure the currently active icon is decoded and ready on first frame
    precacheImage(AssetImage(_iconPath[active]!), context);

    Widget _chip({
      required String asset,
      required VoidCallback onTap,
      Color? haloColor,
      Color? iconColor, // null = keep original asset colors
      bool lift = false,
    }) {
      final size = 56 * s;

      final chip = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 18 * s,
              offset: Offset(0, 10 * s),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            asset,
            width: 26 * s,
            height: 26 * s,
            color: iconColor,
            colorBlendMode: iconColor != null ? BlendMode.srcIn : null,
            fit: BoxFit.contain,
          ),
        ),
      );

      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (haloColor != null)
                Container(
                  width: size + 14 * s,
                  height: size + 14 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: haloColor.withOpacity(0.45),
                  ),
                ),
              if (lift)
                Transform.translate(offset: Offset(0, -10 * s), child: chip)
              else
                chip,
            ],
          ),
        ),
      );
    }

    // Active gradient chip (icon = solid white)
    Widget _gradientChip({
      required String asset,
      required VoidCallback onTap,
      bool lift = true,
    }) {
      final size = 60 * s;

      final chip = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF6DD5FF), Color(0xFF7F53FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (Rect r) =>
                const LinearGradient(colors: [Colors.white, Colors.white]).createShader(r),
            blendMode: BlendMode.srcATop,
            child: Image.asset(
              asset,
              width: 26 * s,
              height: 26 * s,
              fit: BoxFit.contain,
              // ✅ If the asset isn't ready/missing, show a white Material icon so the default tab isn’t blank
              errorBuilder: (_, __, ___) => Icon(
                Icons.circle, // or Icons.home_filled if you want
                size: 22 * s,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Transform.translate(offset: Offset(0, -7 * s), child: chip),
        ),
      );
    }

    Widget _buildItem(BottomTab tab) {
      final asset = _iconPath[tab]!;
      final isActive = active == tab;

      if (isActive) {
        return _gradientChip(asset: asset, onTap: () => _go(tab), lift: true);
      }
      return _chip(
        asset: asset,
        onTap: () => _go(tab),
        haloColor: _halo[tab],
        iconColor: Colors.black,
        lift: false,
      );
    }

    return SafeArea(
      minimum: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 5 * s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44 * s),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
          child: Container(
            height: 78 * s,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(44 * s),
              border: Border.all(color: const Color(0xFFE9ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 20 * s,
                  offset: Offset(0, 10 * s),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16 * s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildItem(BottomTab.home),
                _buildItem(BottomTab.reports),
                _buildItem(BottomTab.map),
                _buildItem(BottomTab.about),
                _buildItem(BottomTab.profile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// enum BottomTab { home, reports, map, about, profile }

// class BottomBar extends StatelessWidget {
//   const BottomBar({
//     super.key,
//     required this.active,
//     required this.onChanged,
//     this.scale,
//   });

//   final BottomTab active;
//   final ValueChanged<BottomTab> onChanged;
//   final double? scale;

//   void _go(BottomTab tab) {
//     if (tab == active) return;
//     onChanged(tab);
//   }

//   // Icons
//   static const Map<BottomTab, String> _iconPath = {
//     BottomTab.home:    'assets/home_bottom_icon.png',
//     BottomTab.reports: 'assets/history_bottom_icon.png',
//     BottomTab.map:     'assets/location_bottom_bar.png',
//     BottomTab.about:   'assets/technician_bottom_bar.png',
//     BottomTab.profile: 'assets/profile_bottom_bar.png',
//   };

//   // Optional halos for inactive chips
//   static const Map<BottomTab, Color?> _halo = {
//     BottomTab.home:    Color(0xFFE3F7F3),
//     BottomTab.reports: Color(0xFFE4F2FF),
//     BottomTab.map:     null,
//     BottomTab.about:   Color(0xFFE4F2FF),
//     BottomTab.profile: Color(0xFFE4F2FF),
//   };

//   @override
//   Widget build(BuildContext context) {
//     final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

//     Widget _chip({
//       required String asset,
//       required VoidCallback onTap,
//       Color? haloColor,
//       Color? iconColor, // null = keep original asset colors
//       bool lift = false,
//     }) {
//       final size = 56 * s;

//       final chip = Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white,
//           border: Border.all(color: const Color(0xFFE9ECF2)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.08),
//               blurRadius: 18 * s,
//               offset: Offset(0, 10 * s),
//             ),
//           ],
//         ),
//         child: Center(
//           child: Image.asset(
//             asset,
//             width: 26 * s,
//             height: 26 * s,
//             color: iconColor,
//             colorBlendMode: iconColor != null ? BlendMode.srcIn : null,
//           ),
//         ),
//       );

//       return Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           customBorder: const CircleBorder(),
//           onTap: onTap,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               if (haloColor != null)
//                 Container(
//                   width: size + 14 * s,
//                   height: size + 14 * s,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: haloColor.withOpacity(0.45),
//                   ),
//                 ),
//               if (lift)
//                 Transform.translate(offset: Offset(0, -10 * s), child: chip)
//               else
//                 chip,
//             ],
//           ),
//         ),
//       );
//     }

//     // Active gradient chip (icon = solid white via ShaderMask)
//     Widget _gradientChip({
//       required String asset,
//       required VoidCallback onTap,
//       bool lift = true,
//     }) {
//       final size = 60 * s;

//       final chip = Container(
//         width: size,
//         height: size,
//         decoration: const BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: LinearGradient(
//             colors: [Color(0xFF6DD5FF), Color(0xFF7F53FD)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: ShaderMask(
//             shaderCallback: (Rect bounds) =>
//                 const LinearGradient(colors: [Colors.white, Colors.white])
//                     .createShader(bounds),
//             blendMode: BlendMode.srcATop,
//             child: Image.asset(
//               asset,
//               width: 26 * s,
//               height: 26 * s,
//               fit: BoxFit.contain,
//             ),
//           ),
//         ),
//       );

//       return Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           customBorder: const CircleBorder(),
//           onTap: onTap,
//           child: Transform.translate(offset: Offset(0, -7 * s), child: chip),
//         ),
//       );
//     }

//     Widget _buildItem(BottomTab tab) {
//       final asset = _iconPath[tab]!;
//       final isActive = active == tab;

//       if (isActive) {
//         return _gradientChip(asset: asset, onTap: () => _go(tab), lift: true);
//       }
//       return _chip(
//         asset: asset,
//         onTap: () => _go(tab),
//         haloColor: _halo[tab],
//         iconColor: Colors.black,
//         lift: false,
//       );
//     }

//     return SafeArea(
//       minimum: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 5 * s),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(44 * s),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
//           child: Container(
//             height: 78 * s,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.92),
//               borderRadius: BorderRadius.circular(44 * s),
//               border: Border.all(color: const Color(0xFFE9ECF2)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.08),
//                   blurRadius: 20 * s,
//                   offset: Offset(0, 10 * s),
//                 ),
//               ],
//             ),
//             padding: EdgeInsets.symmetric(horizontal: 16 * s),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 _buildItem(BottomTab.home),
//                 _buildItem(BottomTab.reports),
//                 _buildItem(BottomTab.map),
//                 _buildItem(BottomTab.about),
//                 _buildItem(BottomTab.profile),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



// import 'dart:ui';
// import 'package:flutter/material.dart';

// enum BottomTab { home, reports, map, about, profile }

// class BottomBar extends StatelessWidget {
//   const BottomBar({
//     super.key,
//     required this.active,
//     required this.onChanged,
//     this.scale,
//   });

//   final BottomTab active;
//   final ValueChanged<BottomTab> onChanged;
//   final double? scale;

//   void _go(BottomTab tab) {
//     if (tab == active) return;
//     onChanged(tab);
//   }

//   // UPDATE these to your actual assets (transparent PNG/SVG)
//   static const Map<BottomTab, String> _iconPath = {
//     BottomTab.home:    'assets/home_bottom_icon.png',
//     BottomTab.reports: 'assets/history_bottom_icon.png',
//     BottomTab.map:     'assets/location_bottom_bar.png', // white glyph recommended
//     BottomTab.about:   'assets/technician_bottom_bar.png',
//     BottomTab.profile: 'assets/profile_bottom_bar.png',
//   };

//   @override
//   Widget build(BuildContext context) {
//     final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

//     // Standard white chip (with optional soft halo)
//     Widget _chip({
//       required String asset,
//       required VoidCallback onTap,
//       Color? haloColor,
//       Color? iconColor = const Color(0xFF111111),
//       bool lift = false,
//     }) {
//       final size = 56 * s;
//       final iconSize = 26 * s;

//       final chip = Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white,
//           border: Border.all(color: const Color(0xFFE9ECF2)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.08),
//               blurRadius: 18 * s,
//               offset: Offset(0, 10 * s),
//             ),
//           ],
//         ),
//         child: Center(
//           child: Image.asset(
//             asset,
//             width: 67,
//             height: 67,
//            // fit: BoxFit.contain,
//             // If your PNGs are multicolor, remove this 'color' line
//            // color: iconColor,
//           ),
//         ),
//       );

//       return Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           customBorder: const CircleBorder(),
//           onTap: onTap,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               if (haloColor != null)
//                 Container(
//                   width: size + 14 * s,
//                   height: size + 14 * s,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: haloColor.withOpacity(0.45),
//                   ),
//                 ),
//               if (lift) Transform.translate(offset: Offset(0, -10 * s), child: chip) else chip,
//             ],
//           ),
//         ),
//       );
//     }

//     // Gradient chip for the ACTIVE tab (matches the center one in screenshot)
//     Widget _gradientChip({
//       required String asset,
//       required VoidCallback onTap,
//       bool lift = true,
//     }) {
//       final size = 60 * s;
//       final iconSize = 26 * s;

//       final chip = Container(
//         width: size,
//         height: size,
//         decoration: const BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: LinearGradient(
//             colors: [Color(0xFF6DD5FF), Color(0xFF7F53FD)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: Image.asset(
//             asset,
//             width: iconSize,
//             height: iconSize,
//            // fit: BoxFit.contain,
//         //    color: Colors.white, // white glyph on gradient
//           ),
//         ),
//       );

//       return Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           customBorder: const CircleBorder(),
//           onTap: onTap,
//           child:  Transform.translate(offset: Offset(0, -7 * s), child: chip) ,
//         ),
//       );
//     }

//     // Bar background: white rounded pill with light border & soft shadow
//     return SafeArea(
//       minimum: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 5 * s),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(44 * s),
//         child: BackdropFilter(
//           filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0), // subtle (can increase to 6–8 for frost)
//           child: Container(
//             height: 78 * s,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.92),
//               borderRadius: BorderRadius.circular(44 * s),
//               border: Border.all(color: const Color(0xFFE9ECF2)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.08),
//                   blurRadius: 20 * s,
//                   offset: Offset(0, 10 * s),
//                 ),
//               ],
//             ),
//             padding: EdgeInsets.symmetric(horizontal: 16 * s),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 // Left: white chip with mint halo
//                 _chip(
//                   asset: _iconPath[BottomTab.home]!,
//                   onTap: () => _go(BottomTab.home),
//                   haloColor: const Color(0xFFE3F7F3),
//                 ),
//                 // Second: white chip with light-blue halo
//                 _chip(
//                   asset: _iconPath[BottomTab.reports]!,
//                   onTap: () => _go(BottomTab.reports),
//                   haloColor: const Color(0xFFE4F2FF),
//                 ),
//                 // Center: active shows gradient; otherwise white
//                 // active == BottomTab.map
//                 //     ? 
//                     Padding(
//                       padding: const EdgeInsets.only(right:8.0),
//                       child: _gradientChip(
//                           asset: _iconPath[BottomTab.map]!,
//                           onTap: () => _go(BottomTab.map),
//                         ),
//                     ),
//                     // : _chip(
//                     //     asset: _iconPath[BottomTab.map]!,
//                     //     onTap: () => _go(BottomTab.map),
//                     //     iconColor: const Color(0xFF111111),
//                     //     // no halo when inactive in screenshot
//                     //   ),
//                 // Fourth: white chip
//                 _chip(
//                   asset: _iconPath[BottomTab.about]!,
//                   onTap: () => _go(BottomTab.about),
//                              haloColor: const Color(0xFFE4F2FF),
//                 ),
//                 // Fifth: white chip
//                 _chip(
//                   asset: _iconPath[BottomTab.profile]!,
//                   onTap: () => _go(BottomTab.profile),
//                              haloColor: const Color(0xFFE4F2FF),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



/*
enum BottomTab { home, reports, map, about, profile }

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.active,
    required this.onChanged,
    this.scale,
    this.activeIconColor = const Color(0xFF3A49A1),
    this.inactiveIconColor = const Color(0xFF58627A),
    this.tintIcons = true, // set false to keep original PNG colors
  });

  final BottomTab active;
  final ValueChanged<BottomTab> onChanged;
  final double? scale;

  final Color activeIconColor;
  final Color inactiveIconColor;
  final bool tintIcons;

  void _go(BottomTab tab) {
    if (tab == active) return;
    onChanged(tab);
  }

  // One asset per tab (must be PNG/SVG with transparent background)
  static const Map<BottomTab, String> _icon = {
    BottomTab.home:    'assets/home_bottom_icon.png',
    BottomTab.reports: 'assets/reports_bottom_icon.png',
    BottomTab.map:     'assets/map_bottom_icon.png',
    BottomTab.about:   'assets/about_bottom_icon.png',
    BottomTab.profile: 'assets/profile_bottom_icon.png',
  };

  @override
  Widget build(BuildContext context) {
    final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

    Widget _pngIcon(String path, double size, Color color) {
      final img = Image.asset(path, width: size, height: size, fit: BoxFit.contain);
      return tintIcons
          ? ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: img)
          : img;
    }

    Widget circle({
      required BottomTab tab,
      required VoidCallback onTap,
      required bool isActive,
      bool big = false,
    }) {
      final size = (big ? 64 : 54) * s;
      final iconSize = (big ? 28 : 24) * s;

      return Material(
        color: Colors.transparent, // keep ripple but no background fill
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Image.asset(_icon[tab]!, width: size, height: size, fit: BoxFit.contain)
              
              // _pngIcon(
              //   _icon[tab]!,
              //   iconSize,
              //   isActive ? activeIconColor : inactiveIconColor,
              // ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      minimum: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
      child: Container(
        height: 78 * s,
        decoration: BoxDecoration(
          color: Colors.white, // bar background (not the icons)
          borderRadius: BorderRadius.circular(44 * s),
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 20 * s, offset: Offset(0, 10 * s)),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 16 * s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            circle(tab: BottomTab.home,    onTap: () => _go(BottomTab.home),    isActive: active == BottomTab.home),
            circle(tab: BottomTab.reports, onTap: () => _go(BottomTab.reports), isActive: active == BottomTab.reports),
            Transform.translate(
              offset: Offset(0, -8 * s),
              child: circle(tab: BottomTab.map, onTap: () => _go(BottomTab.map), isActive: active == BottomTab.map, big: true),
            ),
            circle(tab: BottomTab.about,   onTap: () => _go(BottomTab.about),   isActive: active == BottomTab.about),
            circle(tab: BottomTab.profile, onTap: () => _go(BottomTab.profile), isActive: active == BottomTab.profile),
          ],
        ),
      ),
    );
  }
}

*/


// import 'package:flutter/material.dart';

// enum BottomTab { home, reports, map, about, profile }

// class BottomBar extends StatelessWidget {
//   const BottomBar({
//     super.key,
//     required this.active,
//     required this.onChanged,
//     this.scale,
//     this.activeIconColor = const Color(0xFF3A49A1),
//     this.inactiveIconColor = const Color(0xFF58627A),
//     this.activeBgColor = const Color(0xFFE8EEFF),
//     this.inactiveBgColor = const Color(0x33FFFFFF), // white @ 20%
//     this.activeBorderColor = const Color(0xFFD5DFFC),
//     this.inactiveBorderColor = const Color(0xFFE9ECF2),
//   });

//   final BottomTab active;
//   final ValueChanged<BottomTab> onChanged;
//   final double? scale;

//   // Colors (customizable via constructor)
//   final Color activeIconColor;
//   final Color inactiveIconColor;
//   final Color activeBgColor;
//   final Color inactiveBgColor;
//   final Color activeBorderColor;
//   final Color inactiveBorderColor;

//   void _go(BottomTab tab) {
//     if (tab == active) return;
//     onChanged(tab);
//   }

//   static const Map<BottomTab, String> _icon = {
    // BottomTab.home:    'assets/home_bottom_icon.png',
    // BottomTab.reports: 'assets/home_bottom_icon.png',
    // BottomTab.map:     'assets/home_bottom_icon.png',
    // BottomTab.about:   'assets/home_bottom_icon.png',
    // BottomTab.profile: 'assets/home_bottom_icon.png',
//   };

//   @override
//   Widget build(BuildContext context) {
//     final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

//     Widget circle({
//       required BottomTab tab,
//       required VoidCallback onTap,
//       required bool isActive,
//       bool big = false,
//     }) {
//       final size = (big ? 64 : 54) * s;
//       final iconSize = (big ? 28 : 24) * s;

//       return Material(
//         color: Colors.transparent,
//         shape: const CircleBorder(),
//         child: InkWell(
//           customBorder: const CircleBorder(),
//           onTap: onTap,
//           child: Container(
//             width: size,
//             height: size,
//             alignment: Alignment.center,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: isActive ? activeBgColor : inactiveBgColor,
//               border: Border.all(
//                 color: isActive ? activeBorderColor : inactiveBorderColor,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.08),
//                   blurRadius: 18 * s,
//                   offset: Offset(0, 10 * s),
//                 ),
//               ],
//             ),
//             child: Image.asset(
//               _icon[tab]!,
//               width: iconSize,
//               height: iconSize,
//               fit: BoxFit.contain,
//               color: isActive ? activeIconColor : inactiveIconColor,
//             ),
//           ),
//         ),
//       );
//     }

//     return SafeArea(
//       minimum: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
//       child: Container(
//         height: 78 * s,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(44 * s),
//           border: Border.all(color: const Color(0xFFE9ECF2)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.08),
//               blurRadius: 20 * s,
//               offset: Offset(0, 10 * s),
//             ),
//           ],
//         ),
//         padding: EdgeInsets.symmetric(horizontal: 16 * s),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             circle(
//               tab: BottomTab.home,
//               onTap: () => _go(BottomTab.home),
//               isActive: active == BottomTab.home,
//             ),
//             circle(
//               tab: BottomTab.reports,
//               onTap: () => _go(BottomTab.reports),
//               isActive: active == BottomTab.reports,
//             ),
//             // lifted center button (no Positioned)
//             Transform.translate(
//               offset: Offset(0, -8 * s),
//               child: circle(
//                 tab: BottomTab.map,
//                 onTap: () => _go(BottomTab.map),
//                 isActive: active == BottomTab.map,
//                 big: true,
//               ),
//             ),
//             circle(
//               tab: BottomTab.about,
//               onTap: () => _go(BottomTab.about),
//               isActive: active == BottomTab.about,
//             ),
//             circle(
//               tab: BottomTab.profile,
//               onTap: () => _go(BottomTab.profile),
//               isActive: active == BottomTab.profile,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }





// enum BottomTab { home, reports, map, about, profile }

// class BottomBar extends StatelessWidget {
//   const BottomBar({
//     super.key,
//     required this.active,
//     required this.onChanged,
//     this.scale,
//   });

//   final BottomTab active;
//   final ValueChanged<BottomTab> onChanged;
//   final double? scale;

//   void _go(BottomTab tab) {
//     if (tab == active) return;
//     onChanged(tab);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

//     Widget _circle(
//       String i, {
//       bool big = false,
//       required VoidCallback onTap,
//       required bool isActive,
//     }) {
//       final base = Container(
//         width: (big ? 64 : 54) * s,
//         height: (big ? 64 : 54) * s,
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.20),
//           shape: BoxShape.circle,
//           // boxShadow: [
//           //   BoxShadow(
//           //     color: Colors.black.withOpacity(.08),
//           //     blurRadius: 18 * s,
//           //     offset: Offset(0, 10 * s),
//           //   ),
//           // ],
//           border: Border.all(color: const Color(0xFFE9ECF2)),
//           gradient: big
//               ? const LinearGradient(
//                   colors: [Color(0xFF7FD1FF), Color(0xFF7F53FD)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 )
//               : null,
//         ),
//         child: Image.asset(
//           i,
//           //size: (big ? 28 : 24) * s,
//           color: big
//               ? Colors.white
//               : (isActive ? const Color(0xFF3A49A1) : const Color(0xFF58627A)),
//         ),
//       );
//       return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: base);
//     }

//     return SafeArea(
//       minimum: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
//       child: Container(
//         height: 78 * s,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(44 * s),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.08),
//               blurRadius: 20 * s,
//               offset: Offset(0, 10 * s),
//             )
//           ],
//           border: Border.all(color: const Color(0xFFE9ECF2)),
//         ),
//         padding: EdgeInsets.symmetric(horizontal: 16 * s),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             _circle("assets/home_bottom_icon.png",
//                 onTap: () => _go(BottomTab.home),
//                 isActive: active == BottomTab.home),
//             _circle("assets/home_bottom_icon.png",
//                 onTap: () => _go(BottomTab.reports),
//                 isActive: active == BottomTab.reports),
//             _circle("assets/home_bottom_icon.png",
//                 big: true,
//                 onTap: () => _go(BottomTab.map),
//                 isActive: active == BottomTab.map),
//             _circle("assets/home_bottom_icon.png",
//                 onTap: () => _go(BottomTab.about),
//                 isActive: active == BottomTab.about),
//             _circle("assets/home_bottom_icon.png",
//                 onTap: () => _go(BottomTab.profile),
//                 isActive: active == BottomTab.profile),
//           ],
//         ),
//       ),
//     );
//   }
// }
