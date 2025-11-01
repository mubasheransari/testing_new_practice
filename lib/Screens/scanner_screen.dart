import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Screens/generate_report_screen.dart';
import 'package:ios_tiretest_ai/Widgets/scan_overlay.dart';



import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Screens/generate_report_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'package:ios_tiretest_ai/Widgets/scan_overlay.dart';

class ScannerFrontTireScreen extends StatefulWidget {
  const ScannerFrontTireScreen({super.key});

  @override
  State<ScannerFrontTireScreen> createState() => _ScannerFrontTireScreenState();
}

class _ScannerFrontTireScreenState extends State<ScannerFrontTireScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _ready = false;
  XFile? _front;
  XFile? _back;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (!_ready || _controller == null) return;
    try {
      final shot = await _controller!.takePicture();
      if (_front == null) {
        setState(() => _front = shot);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Front tire captured. Capture back tire.'),
          ),
        );
      } else {
        setState(() => _back = shot);
        _goCountdownAndUpload();
      }
    } catch (e) {
      // ignore for now
    }
  }

  void _goCountdownAndUpload() {
    final auth = context.read<AuthBloc>().state;
    final token = auth.loginResponse?.token ?? '';
    final userId = ''; // fill from your login model
    final vehicleId = 'vehicle-001'; // pass real one

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GenerateReportScreen(
          frontPath: _front!.path,
          backPath: _back!.path,
          userId: userId,
          vehicleId: vehicleId,
          token: token,
        ),
      ),
    )
        .then((_) {
      // reset for new capture
      setState(() {
        _front = null;
        _back = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    return Scaffold(
      body: Stack(
        children: [
          // camera
          if (_ready && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child:
                    const CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // header
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Tire inspection Scanner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 20 * s,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),

          // overlay
          const ScanOverlay(),

          // captured badges
          Positioned(
            top: 120,
            right: 35,
            child: Column(
              children: [
                _thumbBadge('Front', _front?.path),
                const SizedBox(height: 10),
                _thumbBadge('Back', _back?.path),
              ],
            ),
          ),

          // bottom scan/gallery/docs bar
          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: _ready,
              onPickGallery: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Pick from gallery (optional).')),
              ),
              onPickDocs: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Pick documents (optional).')),
              ),
              onCapture: _capture,
              galleryIconAsset: 'assets/gallery_icon.png',
              captureIconAsset: 'assets/image_capture_icon.png',
              docsIconAsset: 'assets/document_icon.png',
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbBadge(String label, String? path) {
    final has = path != null;
    return Container(
      width: 70,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: has ? Colors.green : Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            has ? Icons.check_circle : Icons.radio_button_unchecked,
            color: has ? Colors.white : Colors.black,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: has ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// class ScannerFrontTireScreen extends StatefulWidget {
//   const ScannerFrontTireScreen({super.key});

//   @override
//   State<ScannerFrontTireScreen> createState() => _ScannerFrontTireScreenState();
// }

// class _ScannerFrontTireScreenState extends State<ScannerFrontTireScreen>
//     with WidgetsBindingObserver {
//   CameraController? _controller;
//   bool _ready = false;
//   XFile? _front;
//   XFile? _back;

//   @override
//   void initState() {
//     super.initState();
//     _initCam();
//   }

//   Future<void> _initCam() async {
//     try {
//       final cams = await availableCameras();
//       final back = cams.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.back,
//         orElse: () => cams.first,
//       );
//       final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
//       await c.initialize();
//       if (!mounted) return;
//       setState(() {
//         _controller = c;
//         _ready = true;
//       });
//     } catch (_) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Camera not available')),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   Future<void> _capture() async {
//     if (!_ready || _controller == null) return;
//     try {
//       final shot = await _controller!.takePicture();
//       if (_front == null) {
//         setState(() => _front = shot);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Front tire captured. Capture back tire.')),
//         );
//       } else {
//         setState(() => _back = shot);
//         _goCountdownAndUpload();
//       }
//     } catch (_) {
//       // ignore for now
//     }
//   }

//   void _goCountdownAndUpload() {
//     final auth = context.read<AuthBloc>().state;
//     final token = auth.loginResponse?.token ?? '';
//     final userId = '';
//     final vehicleId = 'vehicle-001';

//     Navigator.of(context)
//         .push(
//           MaterialPageRoute(
//             builder: (_) => GenerateReportScreen(
//               frontPath: _front!.path,
//               backPath: _back!.path,
//               userId: userId,
//               vehicleId: vehicleId,
//               token: token,
//             ),
//           ),
//         )
//         .then((_) {
//       setState(() {
//         _front = null;
//         _back = null;
//       });
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;
//     return Scaffold(
//       // 👇 no bottomNavigationBar here
//       body: Stack(
//         children: [
//           // camera
//           if (_ready && _controller != null)
//             Positioned.fill(child: CameraPreview(_controller!))
//           else
//             const Positioned.fill(
//               child: ColoredBox(
//                 color: Colors.black,
//                 child: Center(
//                   child: CircularProgressIndicator(color: Colors.white),
//                 ),
//               ),
//             ),

//           // header
//           SafeArea(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 0),
//               child: Row(
//                 children: [
//                   IconButton(
//                     onPressed: () => Navigator.pop(context),
//                     icon: const Icon(Icons.chevron_left_rounded,
//                         color: Colors.white, size: 32),
//                   ),
//                   Expanded(
//                     child: Text(
//                       'Tire inspection Scanner',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                         fontSize: 20 * s,
//                         color: Colors.white,
//                         shadows: const [
//                           Shadow(color: Colors.black54, blurRadius: 8)
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 46),
//                 ],
//               ),
//             ),
//           ),

//           // overlay
//           const ScanOverlay(),

//           // captured badges
//           Positioned(
//             top: 120,
//             right: 35,
//             child: Column(
//               children: [
//                 _thumbBadge('Front', _front?.path),
//                 const SizedBox(height: 10),
//                 _thumbBadge('Back', _back?.path),
//               ],
//             ),
//           ),

//           // 👇 simple floating capture button (no nav style)
//           Positioned(
//             bottom: 34 * s,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: GestureDetector(
//                 onTap: _ready ? _capture : null,
//                 child: Container(
//                   width: 78 * s,
//                   height: 78 * s,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: _ready
//                         ? const LinearGradient(
//                             colors: [Color(0xFF4CA6FF), Color(0xFF6B8CFF)],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           )
//                         : LinearGradient(
//                             colors: [
//                               Colors.grey.shade500,
//                               Colors.grey.shade400
//                             ],
//                           ),
//                     boxShadow: const [
//                       BoxShadow(
//                         color: Colors.black26,
//                         blurRadius: 16,
//                         offset: Offset(0, 6),
//                       )
//                     ],
//                   ),
//                   child: Center(
//                     child: Container(
//                       width: 58 * s,
//                       height: 58 * s,
//                       decoration: const BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _thumbBadge(String label, String? path) {
//     final has = path != null;
//     return Container(
//       width: 70,
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(
//         color: has ? Colors.green : Colors.white.withOpacity(.92),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             has ? Icons.check_circle : Icons.radio_button_unchecked,
//             color: has ? Colors.white : Colors.black,
//             size: 16,
//           ),
//           const SizedBox(width: 6),
//           Text(
//             label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               color: has ? Colors.white : Colors.black,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

