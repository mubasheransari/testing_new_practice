import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/inspection_result_screen.dart';



import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// import your own bloc/models/screens
// import 'auth_bloc.dart';
// import 'inspection_result_screen.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({
    super.key,
    required this.frontPath,
    required this.backPath,
    required this.userId,
    required this.vehicleId,
    required this.token,
  });

  final String frontPath;
  final String backPath;
  final String userId;
  final String vehicleId;
  final String token;

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen>
    with SingleTickerProviderStateMixin {
  int _counter = 5;
  Timer? _timer;

  late final AnimationController _progressCtrl; // 0 → 1 in 5s
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _progress = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOutCubic,
    );
    _progressCtrl.forward(); // start bar fill immediately

    _startCountdownAndUpload();
  }

  void _startCountdownAndUpload() {
    // Fire upload immediately
    context.read<AuthBloc>().add(UploadTwoWheelerRequested(
          userId: widget.userId,
          vehicleId: widget.vehicleId,
          token: widget.token,
          frontPath: widget.frontPath,
          backPath: widget.backPath,
          vehicleType: 'bike',
        ));

    // Visible countdown 5 → 0
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _counter--);
      if (_counter <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
        listener: (context, state) {
          if (state.twoWheelerStatus == TwoWheelerStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error ?? 'Upload failed')),
            );
          }
          if (state.twoWheelerStatus == TwoWheelerStatus.success) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => InspectionResultScreen(
                  frontPath: widget.frontPath,
                  backPath: widget.backPath,
                  response: state.twoWheelerResponse,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background photo
              Image.asset(
                'assets/generating_report_bg.png', // your image
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),

              // Dim overlay for readability
              Container(color: Colors.black.withOpacity(.40)),

              // Top bar
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Center: title + concentric counter
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 190),
                    Text(
                      'Generating Report in',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22 * s,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    _concentricCounter(
                      s: s,
                      valueText: '${_counter.clamp(0, 9)}',
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Bottom-left: 5s animated progress pill
              Positioned(
                left: 16 * s,
                bottom: 16 * s + bottom,
                child: _BottomLeftProgressPill(
                  scale: s,
                  progress: _progress, // animated 0 → 1 in 5s
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Concentric translucent circles + big number like the mock
  Widget _concentricCounter({required double s, required String valueText}) {
    final base = 260.0 * s; // outermost diameter
    final rings = <double>[1.0, .76, .55]; // relative sizes

    return SizedBox(
      width: base,
      height: base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft blue layered circles
          for (final r in rings)
            Container(
              width: base * r,
              height: base * r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.20 * r + .05),
              ),
            ),
          // Inner solid circle
          Container(
            width: base * .42,
            height: base * .42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2563EB),
            ),
          ),
          // Big white number
          Text(
            valueText,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 84 * s,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated 5s fill pill used at the bottom-left
class _BottomLeftProgressPill extends StatelessWidget {
  const _BottomLeftProgressPill({
    required this.scale,
    required this.progress,
  });

  final double scale;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final totalW = MediaQuery.of(context).size.width *0.95;
    final h = 10 * scale;

    return Container(
      width: totalW,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.25), // track
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, __) {
          final w = (totalW * progress.value).clamp(0.0, totalW);
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: w,
              height: h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F7BFF), Color(0xFFA270FF)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// import your bloc + result screen as you already do

// class GenerateReportScreen extends StatefulWidget {
//   const GenerateReportScreen({
//     super.key,
//     required this.frontPath,
//     required this.backPath,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     this.backgroundAsset = 'assets/sample/garage_bg.jpg', // your image
//   });

//   final String frontPath;
//   final String backPath;
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String backgroundAsset;

//   @override
//   State<GenerateReportScreen> createState() => _GenerateReportScreenState();
// }

// class _GenerateReportScreenState extends State<GenerateReportScreen> {
//   int _counter = 5;
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     _startCountdownAndUpload();
//   }

//   void _startCountdownAndUpload() {
//     // fire upload immediately
//     context.read<AuthBloc>().add(UploadTwoWheelerRequested(
//           userId: widget.userId,
//           vehicleId: widget.vehicleId,
//           token: widget.token,
//           frontPath: widget.frontPath,
//           backPath: widget.backPath,
//           vehicleType: 'bike',
//         ));

//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (!mounted) return;
//       setState(() => _counter--);
//       if (_counter <= 0) t.cancel();
//     });
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       body: BlocConsumer<AuthBloc, AuthState>(
//         listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
//         listener: (context, state) {
//           if (state.twoWheelerStatus == TwoWheelerStatus.failure) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(state.error ?? 'Upload failed')),
//             );
//           }
//           if (state.twoWheelerStatus == TwoWheelerStatus.success) {
//             Navigator.of(context).pushReplacement(MaterialPageRoute(
//               builder: (_) => InspectionResultScreen(
//                 frontPath: widget.frontPath,
//                 backPath: widget.backPath,
//                 response: state.twoWheelerResponse,
//               ),
//             ));
//           }
//         },
//         builder: (context, state) {
//           return Stack(
//             fit: StackFit.expand,
//             children: [
//               // Background image exactly like the mock
//               Image.asset(
//                 widget.backgroundAsset,
//                 fit: BoxFit.cover,
//                 errorBuilder: (_, __, ___) => Container(color: Colors.black),
//               ),

//               // Slight darkening for text legibility (lighter than before)
//               Container(color: Colors.black.withOpacity(.20)),

//               // // Header
//               // SafeArea(
//               //   child: Padding(
//               //     padding: EdgeInsets.fromLTRB(6 * s, 6 * s, 6 * s, 0),
//               //     child: Row(
//               //       children: [
//               //         IconButton(
//               //           onPressed: () => Navigator.pop(context),
//               //           icon: const Icon(Icons.chevron_left_rounded,
//               //               color: Colors.white, size: 28),
//               //         ),
//               //         Expanded(child: SizedBox(height: 0)),
//               //         // right side left empty to keep title perfectly centered
//               //       ],
//               //     ),
//               //   ),
//               // ),

//               // Title + Orb + Progress pill
//               SafeArea(
//                 child: Column(
//                   children: [
//                     SizedBox(height: 44 * s),
//                     Text(
//                       'Generating Report in',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         color: Colors.white,
//                         fontWeight: FontWeight.w800,
//                         fontSize: 22 * s,
//                         shadows: const [
//                           Shadow(color: Colors.black54, blurRadius: 8),
//                         ],
//                       ),
//                     ),
//                     SizedBox(height: 20 * s),

//                     // Concentric translucent FILLED circles (exact mock vibe)
//                     _orbCountdown(
//                       s: s,
//                       text: (_counter.clamp(0, 9)).toString(),
//                     ),

//                     const Spacer(),

//                     // Small rounded gradient pill at bottom-left (not full width)
//                     Align(
//                       alignment: Alignment.bottomLeft,
//                       child: Container(
//                         height: 10 * s,
//                         width: 86 * s,
//                         margin: EdgeInsets.only(
//                           left: 16 * s,
//                           bottom: 16 * s,
//                         ),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(12 * s),
//                           gradient: const LinearGradient(
//                             colors: [Color(0xFF4F7BFF), Color(0xFFA270FF)],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   /// Big, soft, translucent blue orb that contains the countdown number.
//   Widget _orbCountdown({required double s, required String text}) {
//     final base = 260.0 * s; // overall diameter

//     // Helper to build a filled translucent circle with gradient
//     Widget ring(double size, List<Color> colors, {double blur = 0}) {
//       final circle = Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: LinearGradient(
//             colors: colors,
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//       );
//       // soft shadow glow (subtle)
//       return blur > 0
//           ? Container(
//               width: size,
//               height: size,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: colors.last.withOpacity(.35),
//                     blurRadius: blur,
//                     spreadRadius: blur * .10,
//                   ),
//                 ],
//               ),
//               child: circle,
//             )
//           : circle;
//     }

//     return SizedBox(
//       width: base,
//       height: base,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           // Outer (lightest)
//           ring(
//             base,
//             [
//               const Color(0xFF2563EB).withOpacity(.20), // blue 600 @20%
//               const Color(0xFF7C3AED).withOpacity(.20), // violet 600 @20%
//             ],
//             blur: 18,
//           ),
//           // Middle
//           ring(
//             base * .76,
//             [
//               const Color(0xFF2563EB).withOpacity(.30),
//               const Color(0xFF7C3AED).withOpacity(.30),
//             ],
//             blur: 14,
//           ),
//           // Inner (most visible)
//           ring(
//             base * .54,
//             [
//               const Color(0xFF22D3EE).withOpacity(.38), // cyan accent
//               const Color(0xFF60A5FA).withOpacity(.38), // blue accent
//             ],
//             blur: 10,
//           ),

//           // Countdown number
//           Text(
//             text,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w900,
//               fontSize: 96 * s,
//               height: 1,
//               color: Colors.white,
//               shadows: const [
//                 Shadow(color: Colors.black54, blurRadius: 10),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



// class GenerateReportScreen extends StatefulWidget {
//   const GenerateReportScreen({
//     super.key,
//     required this.frontPath,
//     required this.backPath,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//   });

//   final String frontPath;
//   final String backPath;
//   final String userId;
//   final String vehicleId;
//   final String token;

//   @override
//   State<GenerateReportScreen> createState() => _GenerateReportScreenState();
// }

// class _GenerateReportScreenState extends State<GenerateReportScreen> {
//   int _counter = 5;
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     _startCountdownAndUpload();
//   }

//   void _startCountdownAndUpload() {
//     // Kick the upload immediately (don’t wait for countdown)
//     context.read<AuthBloc>().add(UploadTwoWheelerRequested(
//           userId: widget.userId,
//           vehicleId: widget.vehicleId,
//           token: widget.token,
//           frontPath: widget.frontPath,
//           backPath: widget.backPath,
//           vehicleType: 'bike', // change to 'car' if needed by backend
//         ));

//     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
//       setState(() => _counter--);
//       if (_counter <= 0) t.cancel();
//     });
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;
//     return Scaffold(
//       body: BlocConsumer<AuthBloc, AuthState>(
//         listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
//         listener: (context, state) {
//           if (state.twoWheelerStatus == TwoWheelerStatus.failure) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(state.error ?? 'Upload failed')),
//             );
//           }
//           if (state.twoWheelerStatus == TwoWheelerStatus.success) {
//             Navigator.of(context).pushReplacement(MaterialPageRoute(
//               builder: (_) => InspectionResultScreen(
//                 frontPath: widget.frontPath,
//                 backPath: widget.backPath,
//                 response: state.twoWheelerResponse,
//               ),
//             ));
//           }
//         },
//         builder: (context, state) {
//           return Stack(
//             fit: StackFit.expand,
//             children: [
//               // pretty background image – use your own
//               Image.asset(
//                 'assets/sample/garage_bg.jpg',
//                 fit: BoxFit.cover,
//                 errorBuilder: (_, __, ___) => Container(color: Colors.black),
//               ),
//               Container(color: Colors.black.withOpacity(.45)),
//               SafeArea(
//                 child: Column(
//                   children: [
//                     Align(
//                       alignment: Alignment.centerLeft,
//                       child: IconButton(
//                         icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                     ),
//                     const Spacer(),
//                     Text('Generating Report in',
//                         style: TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           color: Colors.white,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 20 * s,
//                         )),
//                     SizedBox(height: 10 * s),
//                     _concentricCircle(s, text: '${_counter.clamp(0, 9)}'),
//                     const Spacer(),
//                     // thin gradient bar like mock
//                     Container(
//                       height: 8 * s,
//                       margin: EdgeInsets.fromLTRB(20 * s, 0, 20 * s, 26 * s),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(8 * s),
//                         gradient: const LinearGradient(
//                           colors: [Color(0xFF4F7BFF), Color(0xFFA270FF)],
//                         ),
//                       ),
//                     )
//                   ],
//                 ),
//               )
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _concentricCircle(double s, {required String text}) {
//     final List<double> radii = [120, 92, 64];
//     return SizedBox(
//       width: radii.first * s,
//       height: radii.first * s,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           for (final r in radii)
//             Container(
//               width: r * s,
//               height: r * s,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(.10),
//                 border: Border.all(color: Colors.white.withOpacity(.30), width: 2),
//               ),
//             ),
//           Text(text,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//                 fontSize: 56 * s,
//               )),
//         ],
//       ),
//     );
//   }
// }
