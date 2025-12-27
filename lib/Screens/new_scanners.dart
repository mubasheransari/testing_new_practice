import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart'; // for ScanOverlay (as you had)

class ScannerFourTyreScreen extends StatefulWidget {
  final String title;

  // ✅ required for auto API call
  final String userId;
  final String vehicleId;
  final String token;

  // ✅ backend requires vin
  final String vin;

  // ✅ tyre ids required by API
  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  // ✅ optional: API may expect "Car" or "car"
  final String vehicleType;

  // ✅ navigate after success
  final VoidCallback? onUploadSuccessNavigate;

  const ScannerFourTyreScreen({
    super.key,
    this.title = "Car Tyre Scanner",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = "Car",
    this.onUploadSuccessNavigate,
  });

  @override
  State<ScannerFourTyreScreen> createState() => _ScannerFourTyreScreenState();
}

class _ScannerFourTyreScreenState extends State<ScannerFourTyreScreen> {
  CameraController? _controller;
  bool _ready = false;

  XFile? _frontLeft;
  XFile? _frontRight;
  XFile? _backLeft;
  XFile? _backRight;

  TyrePos _active = TyrePos.frontLeft;

  bool _uploading = false;
  bool _uploaded = false;
  String? _error;

  bool get _allCaptured =>
      _frontLeft != null &&
      _frontRight != null &&
      _backLeft != null &&
      _backRight != null;

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
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
    if (_uploading || _uploaded) return;

    try {
      final shot = await _controller!.takePicture();
      if (!mounted) return;

      setState(() {
        switch (_active) {
          case TyrePos.frontLeft:
            _frontLeft = shot;
            _active = TyrePos.frontRight;
            break;
          case TyrePos.frontRight:
            _frontRight = shot;
            _active = TyrePos.backLeft;
            break;
          case TyrePos.backLeft:
            _backLeft = shot;
            _active = TyrePos.backRight;
            break;
          case TyrePos.backRight:
            _backRight = shot;
            break;
        }
      });

      // ✅ AUTO UPLOAD after 4th pic
      if (_allCaptured) {
        await _autoUploadAndNavigate();
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _autoUploadAndNavigate() async {
    if (_uploading || _uploaded) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uri =
          Uri.parse('http://54.162.208.215/app/tyre/four_wheeler_upload/');
      final req = http.MultipartRequest('POST', uri);

      // ✅ headers
      req.headers[HttpHeaders.acceptHeader] = 'application/json';

      // keep auth only if token exists
      final tok = widget.token.trim();
      if (tok.isNotEmpty) {
        req.headers[HttpHeaders.authorizationHeader] = 'Bearer $tok';
      }

      // ✅ MUST send vin always (backend expects request.data['vin'])
      final vinValue = widget.vin.trim().isEmpty ? "UNKNOWN" : widget.vin.trim();

      // ✅ some backends are strict about vehicle_type casing.
      // We send what you pass, but also ensure it's not empty.
      final vehicleTypeValue =
          widget.vehicleType.trim().isEmpty ? "Car" : widget.vehicleType.trim();

      // ✅ fields
      req.fields.addAll({
        'user_id': widget.userId,
        'vehicle_id': widget.vehicleId,

        // IMPORTANT:
        // if backend expects "Car" keep it as "Car"
        // if backend expects "car", change widget.vehicleType to "car" when calling screen
        'vehicle_type': vehicleTypeValue,

        'vin': vinValue,

        'front_left_tyre_id': widget.frontLeftTyreId.trim(),
        'front_right_tyre_id': widget.frontRightTyreId.trim(),
        'back_left_tyre_id': widget.backLeftTyreId.trim(),
        'back_right_tyre_id': widget.backRightTyreId.trim(),
      });

      Future<http.MultipartFile> _filePart(String field, XFile x) async {
        final mime = lookupMimeType(x.path) ?? 'image/jpeg';
        return http.MultipartFile.fromPath(
          field,
          x.path,
          contentType: MediaType.parse(mime),
        );
      }

      // ✅ add files
      req.files.addAll([
        await _filePart('front_left', _frontLeft!),
        await _filePart('front_right', _frontRight!),
        await _filePart('back_left', _backLeft!),
        await _filePart('back_right', _backRight!),
      ]);

      // debug
      debugPrint('==[4W-UPLOAD]==> POST $uri');
      debugPrint('Headers: ${req.headers}');
      debugPrint('Fields: ${req.fields}');
      debugPrint(
          'Files: FL=${_frontLeft!.path}, FR=${_frontRight!.path}, BL=${_backLeft!.path}, BR=${_backRight!.path}');

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      debugPrint('<==[4W-UPLOAD]== status: ${res.statusCode}');
      debugPrint('<== body: ${res.body}');

      if (!mounted) return;

      // ✅ success on 200 or 201
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _uploaded = true;
          _uploading = false;
        });

        // optional toast
        String okMsg = "Upload successful";
        try {
          final j = jsonDecode(res.body);
          if (j is Map && j['message'] != null) okMsg = j['message'].toString();
        } catch (_) {}

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(okMsg)));

        // ✅ navigate after success
        if (widget.onUploadSuccessNavigate != null) {
          widget.onUploadSuccessNavigate!.call();
        } else {
          // keep your old behavior: pop result back
          Navigator.of(context).pop(true);
        }
        return;
      }

      // ✅ failure: show real backend error
      String msg = "Upload failed (${res.statusCode})";
      try {
        final j = jsonDecode(res.body);
        if (j is Map) {
          if (j['message'] != null) msg = j['message'].toString();
          else if (j['error'] != null) msg = j['error'].toString();
          else if (j['detail'] != null) msg = j['detail'].toString();
        }
      } catch (_) {
        // if it's HTML or plain text
        if (res.body.trim().isNotEmpty) {
          msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
        }
      }

      setState(() {
        _uploading = false;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = "Upload error: $e";
      });
    }
  }

  void _retake(TyrePos pos) {
    if (_uploading) return;
    setState(() {
      switch (pos) {
        case TyrePos.frontLeft:
          _frontLeft = null;
          break;
        case TyrePos.frontRight:
          _frontRight = null;
          break;
        case TyrePos.backLeft:
          _backLeft = null;
          break;
        case TyrePos.backRight:
          _backRight = null;
          break;
      }
      _active = pos;
      _uploaded = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      body: Stack(
        children: [
          // camera preview (OLD UI)
          if (_ready && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // header (OLD UI)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _uploading ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
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

          // overlay (OLD UI)
          const ScanOverlay(),

          // error banner (OLD UI)
          if (_error != null)
            Positioned(
              top: 92,
              left: 16 * s,
              right: 16 * s,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // tyre selector bar (OLD UI)
          Positioned(
            top: 115,
            left: 16 * s,
            right: 16 * s,
            child: _TyreSelectorBar(
              s: s,
              active: _active,
              frontLeft: _frontLeft != null,
              frontRight: _frontRight != null,
              backLeft: _backLeft != null,
              backRight: _backRight != null,
              disabled: _uploading,
              onSelect: (pos) => setState(() => _active = pos),
              onRetake: _retake,
            ),
          ),

          // bottom action bar (OLD UI)
          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: _ready && !_uploading,
              onPickGallery: () {},
              onPickDocs: () {},
              onCapture: _capture,
              galleryIconAsset: 'assets/gallery_icon.png',
              captureIconAsset: 'assets/image_capture_icon.png',
              docsIconAsset: 'assets/document_icon.png',
            ),
          ),

          // uploading overlay (OLD UI)
          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.55),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      "Uploading… Please wait",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                      ),
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

enum TyrePos { frontLeft, frontRight, backLeft, backRight }

class _TyreSelectorBar extends StatelessWidget {
  const _TyreSelectorBar({
    required this.s,
    required this.active,
    required this.frontLeft,
    required this.frontRight,
    required this.backLeft,
    required this.backRight,
    required this.onSelect,
    required this.onRetake,
    required this.disabled,
  });

  final double s;
  final TyrePos active;
  final bool frontLeft;
  final bool frontRight;
  final bool backLeft;
  final bool backRight;
  final ValueChanged<TyrePos> onSelect;
  final ValueChanged<TyrePos> onRetake;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.35),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Expanded(child: _chip("Front Left", TyrePos.frontLeft, frontLeft)),
          SizedBox(width: 8 * s),
          Expanded(child: _chip("Front Right", TyrePos.frontRight, frontRight)),
          SizedBox(width: 8 * s),
          Expanded(child: _chip("Back Left", TyrePos.backLeft, backLeft)),
          SizedBox(width: 8 * s),
          Expanded(child: _chip("Back Right", TyrePos.backRight, backRight)),
        ],
      ),
    );
  }

  Widget _chip(String label, TyrePos pos, bool done) {
    final selected = active == pos;

    final bg = done
        ? Colors.green.withOpacity(.85)
        : selected
            ? Colors.white.withOpacity(.20)
            : Colors.white.withOpacity(.10);

    final brd = selected ? Colors.white.withOpacity(.28) : Colors.transparent;

    return InkWell(
      onTap: disabled ? null : () => onSelect(pos),
      onLongPress: disabled || !done ? null : () => onRetake(pos),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// class ScannerFourTyreScreen extends StatefulWidget {
//   final String title;

//   final String userId;
//   final String vehicleId;
//   final String token;

//   final String vin;

//   final String frontLeftTyreId;
//   final String frontRightTyreId;
//   final String backLeftTyreId;
//   final String backRightTyreId;

//   final String vehicleType; // expect "car"
//   final VoidCallback? onUploadSuccessNavigate;

//   const ScannerFourTyreScreen({
//     super.key,
//     this.title = "Car Tyre Scanner",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     required this.frontLeftTyreId,
//     required this.frontRightTyreId,
//     required this.backLeftTyreId,
//     required this.backRightTyreId,
//     this.vehicleType = "car",
//     this.onUploadSuccessNavigate,
//   });

//   @override
//   State<ScannerFourTyreScreen> createState() => _ScannerFourTyreScreenState();
// }

// class _ScannerFourTyreScreenState extends State<ScannerFourTyreScreen> {
//   CameraController? _controller;
//   bool _ready = false;

//   XFile? _frontLeft;
//   XFile? _frontRight;
//   XFile? _backLeft;
//   XFile? _backRight;

//   TyrePos _active = TyrePos.frontLeft;

//   bool _uploading = false;
//   bool _uploaded = false;
//   String? _error;

//   bool get _allCaptured =>
//       _frontLeft != null &&
//       _frontRight != null &&
//       _backLeft != null &&
//       _backRight != null;

//   @override
//   void initState() {
//     super.initState();
//     _initCam();
//   }

//   Future<void> _initCam() async {
//     try {
//       final cams = await availableCameras();
//       final cam = cams.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.back,
//         orElse: () => cams.first,
//       );

//       final controller = CameraController(
//         cam,
//         ResolutionPreset.high,
//         enableAudio: false,
//       );

//       await controller.initialize();
//       if (!mounted) return;

//       setState(() {
//         _controller = controller;
//         _ready = true;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Camera error: $e')),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   Future<void> _capture() async {
//     if (!_ready || _controller == null || _uploading || _uploaded) return;

//     try {
//       final shot = await _controller!.takePicture();
//       if (!mounted) return;

//       setState(() {
//         switch (_active) {
//           case TyrePos.frontLeft:
//             _frontLeft = shot;
//             _active = TyrePos.frontRight;
//             break;
//           case TyrePos.frontRight:
//             _frontRight = shot;
//             _active = TyrePos.backLeft;
//             break;
//           case TyrePos.backLeft:
//             _backLeft = shot;
//             _active = TyrePos.backRight;
//             break;
//           case TyrePos.backRight:
//             _backRight = shot;
//             break;
//         }
//       });

//       if (_allCaptured) {
//         await _autoUploadAndNavigate();
//       }
//     } catch (_) {}
//   }

//   Future<void> _autoUploadAndNavigate() async {
//     if (_uploading || _uploaded) return;

//     setState(() {
//       _uploading = true;
//       _error = null;
//     });

//     try {
//       final uri =
//           Uri.parse('http://54.162.208.215/app/tyre/four_wheeler_upload/');
//       final req = http.MultipartRequest('POST', uri);

//       if (widget.token.trim().isNotEmpty) {
//         req.headers[HttpHeaders.authorizationHeader] =
//             'Bearer ${widget.token}';
//       }
//       req.headers[HttpHeaders.acceptHeader] = 'application/json';

//       final vinValue =
//           widget.vin.trim().isEmpty ? "UNKNOWN" : widget.vin.trim();

//       req.fields.addAll({
//         'user_id': widget.userId,
//         'vehicle_id': widget.vehicleId,
//         'vehicle_type': widget.vehicleType.toLowerCase(),
//         'vin': vinValue,
//         'front_left_tyre_id': widget.frontLeftTyreId,
//         'front_right_tyre_id': widget.frontRightTyreId,
//         'back_left_tyre_id': widget.backLeftTyreId,
//         'back_right_tyre_id': widget.backRightTyreId,
//       });

//       Future<http.MultipartFile> _file(String key, XFile file) async {
//         final mime = lookupMimeType(file.path) ?? 'image/jpeg';
//         return http.MultipartFile.fromPath(
//           key,
//           file.path,
//           contentType: MediaType.parse(mime),
//         );
//       }

//       req.files.addAll([
//         await _file('front_left', _frontLeft!),
//         await _file('front_right', _frontRight!),
//         await _file('back_left', _backLeft!),
//         await _file('back_right', _backRight!),
//       ]);

//       debugPrint('==[UPLOAD]==> POST $uri');
//       debugPrint('FIELDS: ${req.fields}');

//       final streamed = await req.send();
//       final res = await http.Response.fromStream(streamed);

//       debugPrint('<== STATUS: ${res.statusCode}');
//       debugPrint('<== BODY: ${res.body}');

//       if (!mounted) return;

//       if (res.statusCode == 200 || res.statusCode == 201) {
//         setState(() {
//           _uploaded = true;
//           _uploading = false;
//         });

//         if (widget.onUploadSuccessNavigate != null) {
//           widget.onUploadSuccessNavigate!.call();
//         } else {
//           Navigator.of(context).pop(true);
//         }
//         return;
//       }

//       setState(() {
//         _uploading = false;
//         _error = 'Upload failed (${res.statusCode})';
//       });

//       try {
//         final j = jsonDecode(res.body);
//         if (j is Map && j['message'] != null) {
//           _error = j['message'].toString();
//         }
//       } catch (_) {}
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _uploading = false;
//         _error = 'Upload error: $e';
//       });
//     }
//   }

//   void _retake(TyrePos pos) {
//     if (_uploading) return;
//     setState(() {
//       switch (pos) {
//         case TyrePos.frontLeft:
//           _frontLeft = null;
//           break;
//         case TyrePos.frontRight:
//           _frontRight = null;
//           break;
//         case TyrePos.backLeft:
//           _backLeft = null;
//           break;
//         case TyrePos.backRight:
//           _backRight = null;
//           break;
//       }
//       _active = pos;
//       _uploaded = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       body: Stack(
//         children: [
//           if (_ready && _controller != null)
//             Positioned.fill(child: CameraPreview(_controller!))
//           else
//             const Center(child: CircularProgressIndicator()),

//           if (_error != null)
//             Positioned(
//               top: 90,
//               left: 16,
//               right: 16,
//               child: Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(.9),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(
//                       color: Colors.white, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),

//           Positioned(
//             bottom: 16,
//             left: 16,
//             right: 16,
//             child: BottomActionBar(
//               enabled: _ready && !_uploading,
//               onCapture: _capture,
//               onPickGallery: () {},
//               onPickDocs: () {},
//               galleryIconAsset: 'assets/gallery_icon.png',
//               captureIconAsset: 'assets/image_capture_icon.png',
//               docsIconAsset: 'assets/document_icon.png',
//             ),
//           ),

//           if (_uploading)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black54,
//                 alignment: Alignment.center,
//                 child: const CircularProgressIndicator(color: Colors.white),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// enum TyrePos { frontLeft, frontRight, backLeft, backRight }


// class ScannerFourTyreScreen extends StatefulWidget {
//   final String title;

//   // ✅ required for auto API call
//   final String userId;
//   final String vehicleId;
//   final String token;

//   // ✅ backend requires vin (your 500 error)
//   final String vin;

//   // ✅ tyre ids required by your API
//   final String frontLeftTyreId;
//   final String frontRightTyreId;
//   final String backLeftTyreId;
//   final String backRightTyreId;

//   // optional: if your API needs this exact string
//   final String vehicleType; // e.g. "Car"

//   // ✅ where to go after success (optional)
//   final VoidCallback? onUploadSuccessNavigate;

//   const ScannerFourTyreScreen({
//     super.key,
//     this.title = "Car Tyre Scanner",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     required this.frontLeftTyreId,
//     required this.frontRightTyreId,
//     required this.backLeftTyreId,
//     required this.backRightTyreId,
//     this.vehicleType = "Car",
//     this.onUploadSuccessNavigate,
//   });

//   @override
//   State<ScannerFourTyreScreen> createState() => _ScannerFourTyreScreenState();
// }

// class _ScannerFourTyreScreenState extends State<ScannerFourTyreScreen> {
//   CameraController? _controller;
//   bool _ready = false;

//   XFile? _frontLeft;
//   XFile? _frontRight;
//   XFile? _backLeft;
//   XFile? _backRight;

//   TyrePos _active = TyrePos.frontLeft;

//   bool _uploading = false;
//   bool _uploaded = false;
//   String? _error;

//   bool get _allCaptured =>
//       _frontLeft != null &&
//       _frontRight != null &&
//       _backLeft != null &&
//       _backRight != null;

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

//       final c = CameraController(
//         back,
//         ResolutionPreset.high,
//         enableAudio: false,
//       );

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
//     if (_uploading || _uploaded) return;

//     try {
//       final shot = await _controller!.takePicture();
//       if (!mounted) return;

//       setState(() {
//         switch (_active) {
//           case TyrePos.frontLeft:
//             _frontLeft = shot;
//             _active = TyrePos.frontRight;
//             break;
//           case TyrePos.frontRight:
//             _frontRight = shot;
//             _active = TyrePos.backLeft;
//             break;
//           case TyrePos.backLeft:
//             _backLeft = shot;
//             _active = TyrePos.backRight;
//             break;
//           case TyrePos.backRight:
//             _backRight = shot;
//             break;
//         }
//       });

//       // ✅ AUTO: when all 4 captured, start upload immediately
//       if (_allCaptured) {
//         await _autoUploadAndNavigate();
//       }
//     } catch (_) {
//       // ignore
//     }
//   }

//   Future<void> _autoUploadAndNavigate() async {
//     if (_uploading || _uploaded) return;

//     setState(() {
//       _uploading = true;
//       _error = null;
//     });

//     try {
//       // ✅ endpoint
//       final uri = Uri.parse('http://54.162.208.215/app/tyre/four_wheeler_upload/');
//       final req = http.MultipartRequest('POST', uri);

//       // ✅ headers
//       req.headers.addAll({
//         HttpHeaders.authorizationHeader: 'Bearer ${widget.token}',
//         HttpHeaders.acceptHeader: 'application/json',
//       });

//       // ✅ ALWAYS send vin (fix backend MultiValueDictKeyError)
//       final vinValue = widget.vin.trim().isEmpty ? "UNKNOWN" : widget.vin.trim();

//       // ✅ fields (match what you logged)
//       req.fields.addAll({
//         'user_id': widget.userId,
//         'vehicle_id': widget.vehicleId,
//         'vehicle_type': widget.vehicleType, // "Car"
//         'vin': vinValue,

//         'front_left_tyre_id': widget.frontLeftTyreId,
//         'front_right_tyre_id': widget.frontRightTyreId,
//         'back_left_tyre_id': widget.backLeftTyreId,
//         'back_right_tyre_id': widget.backRightTyreId,
//       });

//       Future<http.MultipartFile> _filePart(String field, XFile x) async {
//         final path = x.path;
//         final mime = lookupMimeType(path) ?? 'image/jpeg';
//         final media = MediaType.parse(mime);
//         return http.MultipartFile.fromPath(field, path, contentType: media);
//       }

//       // ✅ add files (same field names backend expects)
//       req.files.addAll([
//         await _filePart('front_left', _frontLeft!),
//         await _filePart('front_right', _frontRight!),
//         await _filePart('back_left', _backLeft!),
//         await _filePart('back_right', _backRight!),
//       ]);

//       // ✅ send
//       final streamed = await req.send();
//       final res = await http.Response.fromStream(streamed);

//       if (!mounted) return;

//       if (res.statusCode == 200) {
//         setState(() {
//           _uploaded = true;
//           _uploading = false;
//         });

//         // ✅ optional: parse response
//         Map<String, dynamic>? j;
//         try {
//           j = jsonDecode(res.body) as Map<String, dynamic>;
//         } catch (_) {}

//         // ✅ AUTO NAVIGATE
//         // option A: call a callback that pushes next screen
//         if (widget.onUploadSuccessNavigate != null) {
//           widget.onUploadSuccessNavigate!.call();
//           return;
//         }

//         // option B: pop back after success
//         Navigator.of(context).pop(j ?? {"success": true});
//         return;
//       }

//       // ✅ failure
//       setState(() {
//         _uploading = false;
//         _error = "Upload failed (${res.statusCode})";
//       });

//       // show server message if any
//       try {
//         final jj = jsonDecode(res.body);
//         if (jj is Map && jj['message'] != null) {
//           setState(() => _error = jj['message'].toString());
//         }
//       } catch (_) {}
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _uploading = false;
//         _error = "Upload error: $e";
//       });
//     }
//   }

//   void _retake(TyrePos pos) {
//     if (_uploading) return;
//     setState(() {
//       switch (pos) {
//         case TyrePos.frontLeft:
//           _frontLeft = null;
//           break;
//         case TyrePos.frontRight:
//           _frontRight = null;
//           break;
//         case TyrePos.backLeft:
//           _backLeft = null;
//           break;
//         case TyrePos.backRight:
//           _backRight = null;
//           break;
//       }
//       _active = pos;
//       _uploaded = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       body: Stack(
//         children: [
//           // camera preview
//           if (_ready && _controller != null)
//             Positioned.fill(child: CameraPreview(_controller!))
//           else
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black,
//                 alignment: Alignment.center,
//                 child: const CircularProgressIndicator(color: Colors.white),
//               ),
//             ),

//           // header
//           SafeArea(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
//               child: Row(
//                 children: [
//                   IconButton(
//                     onPressed: _uploading ? null : () => Navigator.pop(context),
//                     icon: const Icon(
//                       Icons.chevron_left_rounded,
//                       color: Colors.white,
//                       size: 32,
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       widget.title,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                         fontSize: 20 * s,
//                         color: Colors.white,
//                         shadows: const [
//                           Shadow(color: Colors.black54, blurRadius: 8),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 46),
//                 ],
//               ),
//             ),
//           ),

//           // overlay (your existing overlay widget)
//           const ScanOverlay(),

//           // error banner
//           if (_error != null)
//             Positioned(
//               top: 92,
//               left: 16 * s,
//               right: 16 * s,
//               child: Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(.85),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ),

//           // tyre selector
//           Positioned(
//             top: 115,
//             left: 16 * s,
//             right: 16 * s,
//             child: _TyreSelectorBar(
//               s: s,
//               active: _active,
//               frontLeft: _frontLeft != null,
//               frontRight: _frontRight != null,
//               backLeft: _backLeft != null,
//               backRight: _backRight != null,
//               disabled: _uploading,
//               onSelect: (pos) => setState(() => _active = pos),
//               onRetake: _retake,
//             ),
//           ),

//           // bottom action bar (capture triggers auto upload when complete)
//           Positioned(
//             left: 16 * s,
//             right: 16 * s,
//             bottom: 14 * s,
//             child: BottomActionBar(
//               enabled: _ready && !_uploading,
//               onPickGallery: () {},
//               onPickDocs: () {},
//               onCapture: _capture,
//               galleryIconAsset: 'assets/gallery_icon.png',
//               captureIconAsset: 'assets/image_capture_icon.png',
//               docsIconAsset: 'assets/document_icon.png',
//             ),
//           ),

//           // ✅ Uploading overlay (blocks UI)
//           if (_uploading)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(.55),
//                 alignment: Alignment.center,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: const [
//                     CircularProgressIndicator(color: Colors.white),
//                     SizedBox(height: 12),
//                     Text(
//                       "Uploading… Please wait",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// enum TyrePos { frontLeft, frontRight, backLeft, backRight }

// class _TyreSelectorBar extends StatelessWidget {
//   const _TyreSelectorBar({
//     required this.s,
//     required this.active,
//     required this.frontLeft,
//     required this.frontRight,
//     required this.backLeft,
//     required this.backRight,
//     required this.onSelect,
//     required this.onRetake,
//     required this.disabled,
//   });

//   final double s;
//   final TyrePos active;
//   final bool frontLeft;
//   final bool frontRight;
//   final bool backLeft;
//   final bool backRight;
//   final ValueChanged<TyrePos> onSelect;
//   final ValueChanged<TyrePos> onRetake;
//   final bool disabled;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(10 * s),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(.35),
//         borderRadius: BorderRadius.circular(14 * s),
//         border: Border.all(color: Colors.white.withOpacity(.10)),
//       ),
//       child: Row(
//         children: [
//           Expanded(child: _chip("Front Left", TyrePos.frontLeft, frontLeft)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _chip("Front Right", TyrePos.frontRight, frontRight)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _chip("Back Left", TyrePos.backLeft, backLeft)),
//           SizedBox(width: 8 * s),
//           Expanded(child: _chip("Back Right", TyrePos.backRight, backRight)),
//         ],
//       ),
//     );
//   }

//   Widget _chip(String label, TyrePos pos, bool done) {
//     final selected = active == pos;

//     final bg = done
//         ? Colors.green.withOpacity(.85)
//         : selected
//             ? Colors.white.withOpacity(.20)
//             : Colors.white.withOpacity(.10);

//     final brd = selected ? Colors.white.withOpacity(.28) : Colors.transparent;

//     return InkWell(
//       onTap: disabled ? null : () => onSelect(pos),
//       onLongPress: disabled || !done ? null : () => onRetake(pos),
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: brd),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               done ? Icons.check_circle : Icons.radio_button_unchecked,
//               color: Colors.white,
//               size: 16,
//             ),
//             const SizedBox(height: 6),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 color: Colors.white,
//                 fontWeight: FontWeight.w800,
//                 fontSize: 11.5,
//                 height: 1.05,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
