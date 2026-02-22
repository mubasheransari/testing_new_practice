import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/Screens/location_google_maos.dart';
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
    LocationVendorsMapScreen.prewarm(context);
  });

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
        fit: BoxFit.fitWidth,        
        width: MediaQuery.of(context).size.width,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

