import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/Screens/home_screen.dart';

// Replace these with your actual screens:
import 'auth_screen.dart';                  // <- your auth/login screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

// TODO: replace with your actual screens
import 'auth_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  static const _upperPath  = 'assets/splash_upper_view.png';
  static const _bottomPath = 'assets/splash_bottom_view.png';
  static const _logoPath   = 'assets/tiretest_logo.png';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final token = (GetStorage().read<String>('auth_token') ?? '').trim();
      final hasToken = token.isNotEmpty;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => hasToken
              ? const AppShell() //InspectionHomePixelPerfect()
              : const AuthScreen(),
        ),
        (route) => false,
      );
    });
  }

  // @override
  // void dispose() {
  //   _fadeCtrl.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    // Full-bleed canvas; no SafeArea cropping to keep exact look
    return Scaffold(
    
      body: Stack(
        fit: StackFit.expand,
        children: [
          // UPPER BACKGROUND (full bleed)
          const _UpperBackground(imagePath: _upperPath),
      
          // CENTER LOGO (fixed width relative to screen; tweak if needed)
          Align(
            alignment: const Alignment(0, -0.05), // slight optical lift
            child: LayoutBuilder(
              builder: (context, c) {
                final w = MediaQuery.of(context).size.width;
                final logoW = w * 0.64; // 64% of screen width (looks like your mock)
                return Image.asset(
                  _logoPath,
                  width: logoW,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
          ),
      
          // BOTTOM DECOR (stick to bottom, match width, keep aspect)
          const _BottomDecor(imagePath: _bottomPath),
        ],
      ),
      backgroundColor: Colors.white, // exact white canvas under images
    );
  }
}

class _UpperBackground extends StatelessWidget {
  const _UpperBackground({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,               // fill entire screen like your design
      filterQuality: FilterQuality.high,
    );
  }
}

class _BottomDecor extends StatelessWidget {
  const _BottomDecor({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Image.asset(
        imagePath,
        fit: BoxFit.fitWidth,          // match device width, keep aspect ratio
        width: MediaQuery.of(context).size.width,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}



// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();

//     // Decide where to go (token in default GetStorage box)
//     final token = (GetStorage().read<String>('auth_token') ?? '').trim();
//     final hasToken = token.isNotEmpty;

//     // Brief delay so the splash is visible (tweak if you like)
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await Future.delayed(const Duration(milliseconds: 1200));
//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(
//           builder: (_) =>
//               hasToken ? const InspectionHomePixelPerfect() : const AuthScreen(),
//         ),
//         (route) => false,
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         fit: StackFit.expand,
//         children: const [
//           // EXACT IMAGE: will look exactly like your provided design
//           _ExactSplashBackground(),
//         ],
//       ),
//     );
//   }
// }

// class _ExactSplashBackground extends StatelessWidget {
//   const _ExactSplashBackground();

//   @override
//   Widget build(BuildContext context) {
//     return Image.asset(
//       'assets/splash/tiretest_splash.png',  // <-- your exact design PNG
//       fit: BoxFit.cover,                    // full bleed
//       filterQuality: FilterQuality.high,
//     );
//   }
// }
