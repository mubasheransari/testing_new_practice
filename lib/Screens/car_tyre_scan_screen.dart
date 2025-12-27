import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';


import 'dart:convert';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class FourWheelerScanScreen extends StatefulWidget {
  final String userId;
  final String vehicleId;
  final String token; // optional if backend needs it

  final String? vin;

  final String? front_left_tyre_id;
  final String? front_right_tyre_id;
  final String? back_left_tyre_id;
  final String? back_right_tyre_id;

  const FourWheelerScanScreen({
    super.key,
    required this.userId,
    required this.vehicleId,
    required this.token,
    this.vin,
    required this.front_left_tyre_id,
    required this.front_right_tyre_id,
    required this.back_left_tyre_id,
    required this.back_right_tyre_id,
  });

  @override
  State<FourWheelerScanScreen> createState() => _FourWheelerScanScreenState();
}

class _FourWheelerScanScreenState extends State<FourWheelerScanScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontLeft;
  XFile? _frontRight;
  XFile? _backLeft;
  XFile? _backRight;

  bool _uploading = false;
  String? _error;

  // ✅ allow user to type vin (optional)
  late final TextEditingController _vinController;

  bool get _allCaptured =>
      _frontLeft != null &&
      _frontRight != null &&
      _backLeft != null &&
      _backRight != null;

  static const String _baseUrl = "http://54.162.208.215";
  static const String _endpoint = "/app/tyre/four_wheeler_upload/";

  @override
  void initState() {
    super.initState();
    _vinController = TextEditingController(text: widget.vin ?? "");
  }

  @override
  void dispose() {
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _pickTyre(String position) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );
      if (file == null) return;

      setState(() {
        switch (position) {
          case 'front_left':
            _frontLeft = file;
            break;
          case 'front_right':
            _frontRight = file;
            break;
          case 'back_left':
            _backLeft = file;
            break;
          case 'back_right':
            _backRight = file;
            break;
        }
      });
    } catch (e) {
      setState(() => _error = 'Failed to open camera: $e');
    }
  }

  Future<http.MultipartFile> _filePart(String field, XFile x) async {
    final path = x.path;
    final mime = lookupMimeType(path) ?? 'image/jpeg';
    final media = MediaType.parse(mime);
    return http.MultipartFile.fromPath(field, path, contentType: media);
  }

  bool _validateRequiredIds() {
    final missing = <String>[];

    if ((widget.front_left_tyre_id ?? '').trim().isEmpty) missing.add("front_left_tyre_id");
    if ((widget.front_right_tyre_id ?? '').trim().isEmpty) missing.add("front_right_tyre_id");
    if ((widget.back_left_tyre_id ?? '').trim().isEmpty) missing.add("back_left_tyre_id");
    if ((widget.back_right_tyre_id ?? '').trim().isEmpty) missing.add("back_right_tyre_id");

    if (missing.isNotEmpty) {
      setState(() => _error = "Missing required tyre ids: ${missing.join(", ")}");
      return false;
    }
    return true;
  }

  Future<void> _upload() async {
    if (!_allCaptured) {
      setState(() => _error = 'Please capture all 4 tyres first.');
      return;
    }
    if (!_validateRequiredIds()) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    final uri = Uri.parse("$_baseUrl$_endpoint");
    final request = http.MultipartRequest('POST', uri);

    // headers
    request.headers[HttpHeaders.acceptHeader] = 'application/json';

    // if backend requires Bearer token, keep it
    if (widget.token.trim().isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer ${widget.token}';
    }

    // ✅ IMPORTANT FIX:
    // Backend is doing request.data['vin'] so we MUST send vin always.
    final vinToSend = _vinController.text.trim(); // will be "" if empty

    request.fields.addAll({
      'user_id': widget.userId,
      'vehicle_id': widget.vehicleId,
      'front_left_tyre_id': widget.front_left_tyre_id!.trim(),
      'front_right_tyre_id': widget.front_right_tyre_id!.trim(),
      'back_left_tyre_id': widget.back_left_tyre_id!.trim(),
      'back_right_tyre_id': widget.back_right_tyre_id!.trim(),
      'vehicle_type': 'Car',

      // ✅ always present (even if empty)
      'vin': vinToSend,
    });

    request.files.addAll([
      await _filePart('front_left', _frontLeft!),
      await _filePart('front_right', _frontRight!),
      await _filePart('back_left', _backLeft!),
      await _filePart('back_right', _backRight!),
    ]);

    debugPrint('==[4W-UPLOAD]==> POST $uri');
    debugPrint('Fields: ${request.fields}');
    debugPrint('Files: FL=${_frontLeft!.path}, FR=${_frontRight!.path}, BL=${_backLeft!.path}, BR=${_backRight!.path}');

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      debugPrint('<==[4W-UPLOAD]== status: ${res.statusCode}');
      debugPrint('<== body: ${res.body}');

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        String msg = "Upload successful";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['message'] != null) {
            msg = decoded['message'].toString();
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => _uploading = false);
      } else {
        String msg = 'Upload failed (${res.statusCode})';
        try {
          final j = jsonDecode(res.body);
          if (j is Map) {
            if (j['message'] != null) msg = j['message'].toString();
            if (j['error'] != null) msg = j['error'].toString();
            if (j['detail'] != null) msg = j['detail'].toString();
          }
        } catch (_) {}

        setState(() {
          _uploading = false;
          _error = msg;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Upload error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  Widget _tyreTile(String label, XFile? file, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: _uploading ? null : onTap,
        child: Container(
          height: 120,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: file == null ? Colors.grey.shade300 : Colors.green,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (file != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 32)
              else
                const Icon(Icons.camera_alt_rounded, color: Colors.black54, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              if (file != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text('Captured', style: TextStyle(fontSize: 12, color: Colors.green)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Car Tyre Scan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.3,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 10),

            // ✅ Optional VIN input (so you can send vin always)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _vinController,
                enabled: !_uploading,
                decoration: InputDecoration(
                  hintText: "VIN (optional)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Capture all four tyres of the car.\nTap each card to open the camera.',
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _tyreTile('Front Left', _frontLeft, () => _pickTyre('front_left')),
                        _tyreTile('Front Right', _frontRight, () => _pickTyre('front_right')),
                      ],
                    ),
                    Row(
                      children: [
                        _tyreTile('Back Left', _backLeft, () => _pickTyre('back_left')),
                        _tyreTile('Back Right', _backRight, () => _pickTyre('back_right')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allCaptured ? const Color(0xFF7F53FD) : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _allCaptured ? 'Upload Tyre Images' : 'Capture all 4 tyres',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/*

class FourWheelerScanScreen extends StatefulWidget {
  final String userId;
  final String vehicleId;
  final String token;      // Bearer JWT from login
  final String? vin; 
  final String? front_left_tyre_id;
  final String? front_right_tyre_id;
  final String? back_left_tyre_id;
  final String? back_right_tyre_id;

  const FourWheelerScanScreen({
    super.key,
    required this.userId,
    required this.vehicleId,
    required this.token,
    this.vin,
    required this.front_left_tyre_id,
    required this.front_right_tyre_id,
    required this.back_left_tyre_id,
    required this.back_right_tyre_id,
    
  });

  @override
  State<FourWheelerScanScreen> createState() => _FourWheelerScanScreenState();
}

class _FourWheelerScanScreenState extends State<FourWheelerScanScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontLeft;
  XFile? _frontRight;
  XFile? _backLeft;
  XFile? _backRight;

  bool _uploading = false;
  String? _error;

  bool get _allCaptured =>
      _frontLeft != null &&
      _frontRight != null &&
      _backLeft != null &&
      _backRight != null;


      Future<void> _pickTyre(String position) async {
  try {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      // ⬇️ use `rear` instead of `back`
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() {
      switch (position) {
        case 'front_left':
          _frontLeft = file;
          break;
        case 'front_right':
          _frontRight = file;
          break;
        case 'back_left':
          _backLeft = file;
          break;
        case 'back_right':
          _backRight = file;
          break;
      }
    });
  } catch (e) {
    setState(() => _error = 'Failed to open camera: $e');
  }
}


  // Future<void> _pickTyre(String position) async {
  //   try {
  //     final XFile? file = await _picker.pickImage(
  //       source: ImageSource.camera,
  //       preferredCameraDevice: CameraDevice.back,
  //       imageQuality: 90,
  //     );
  //     if (file == null) return;

  //     setState(() {
  //       switch (position) {
  //         case 'front_left':
  //           _frontLeft = file;
  //           break;
  //         case 'front_right':
  //           _frontRight = file;
  //           break;
  //         case 'back_left':
  //           _backLeft = file;
  //           break;
  //         case 'back_right':
  //           _backRight = file;
  //           break;
  //       }
  //     });
  //   } catch (e) {
  //     setState(() => _error = 'Failed to open camera: $e');
  //   }
  // }

  Future<void> _upload() async {
    if (!_allCaptured) {
      setState(() {
        _error = 'Please capture all 4 tyres first.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    // ✅ Correct Django four-wheeler endpoint (from your 404 page) Testing@123
    final uri = Uri.parse('http://54.162.208.215/app/tyre/four_wheeler_upload/');


    final request = http.MultipartRequest('POST', uri);

    // Masked token for logs
    final tok = widget.token;
    final masked = tok.length > 12
        ? '${tok.substring(0, 6)}…${tok.substring(tok.length - 4)}'
        : '***';

    request.headers.addAll({
      HttpHeaders.authorizationHeader: 'Bearer ${widget.token}',
      HttpHeaders.acceptHeader: 'application/json',
      // Do NOT set content-type; MultipartRequest will handle boundary
    });

    request.fields.addAll({
      'user_id': widget.userId,
      'vehicle_type': 'car',
      'vehicle_id': widget.vehicleId,
      if (widget.vin != null && widget.vin!.trim().isNotEmpty)
        'vin': widget.vin!.trim(),
    });

    // Helper to create file part with correct mime
    Future<http.MultipartFile> _filePart(String field, XFile x) async {
      final path = x.path;
      final mime = lookupMimeType(path) ?? 'image/jpeg';
      final media = MediaType.parse(mime);
      return http.MultipartFile.fromPath(field, path, contentType: media);
    }

    if (_frontLeft == null ||
        _frontRight == null ||
        _backLeft == null ||
        _backRight == null) {
      setState(() {
        _uploading = false;
        _error = 'All four images must be captured before upload.';
      });
      return;
    }

    request.files.addAll([
      await _filePart('front_left', _frontLeft!),
      await _filePart('front_right', _frontRight!),
      await _filePart('back_left', _backLeft!),
      await _filePart('back_right', _backRight!),
    ]);

    // Debug logs
    debugPrint('==[4W-UPLOAD]==> POST $uri');
    debugPrint('Headers: {Authorization: Bearer $masked, Accept: application/json}');
    debugPrint('Fields: ${request.fields}');
    debugPrint(
        'Files: FL=${_frontLeft!.path}, FR=${_frontRight!.path}, BL=${_backLeft!.path}, BR=${_backRight!.path}');

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      debugPrint('<==[4W-UPLOAD]== status: ${res.statusCode}');
      debugPrint('<== body: ${res.body}');

      if (!mounted) return;

      if (res.statusCode == 200) {
        Map<String, dynamic> json;
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload succeeded but response could not be parsed'),
            ),
          );
          setState(() => _uploading = false);
          return;
        }

        final message = json['message']?.toString() ?? 'successful';
        final data = json['data'];

        String summary = message;
        if (data is Map<String, dynamic>) {
          summary +=
              '\nFront Left: ${data['Front Left Tyre status'] ?? ''}'
              '\nFront Right: ${data['Front Right Tyre status'] ?? ''}'
              '\nBack Left: ${data['Back Left Tyre status'] ?? ''}'
              '\nBack Right: ${data['Back Right Tyre status'] ?? ''}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(summary)),
        );

        setState(() => _uploading = false);

        // Optionally pop or navigate somewhere else
        // Navigator.of(context).pop(); 
      } else {
        String msg = 'Upload failed (${res.statusCode})';
        try {
          final j = jsonDecode(res.body);
          if (j is Map && j['message'] != null) {
            msg = j['message'].toString();
          } else if (j is Map && j['error'] != null) {
            msg = j['error'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() {
          _uploading = false;
          _error = msg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Upload error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: $e')),
      );
    }
  }

  Widget _tyreTile(String label, XFile? file, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: _uploading ? null : onTap,
        child: Container(
          height: 120,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: file == null ? Colors.grey.shade300 : Colors.green,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (file != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 32)
              else
                const Icon(Icons.camera_alt_rounded,
                    color: Colors.black54, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              if (file != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Captured',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Car Tyre Scan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.3,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text("font tyre id ${widget.front_left_tyre_id}"),
            if (_error != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Capture all four tyres of the car.\nTap each card to open the camera.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _tyreTile(
                          'Front Left',
                          _frontLeft,
                          () => _pickTyre('front_left'),
                        ),
                        _tyreTile(
                          'Front Right',
                          _frontRight,
                          () => _pickTyre('front_right'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _tyreTile(
                          'Back Left',
                          _backLeft,
                          () => _pickTyre('back_left'),
                        ),
                        _tyreTile(
                          'Back Right',
                          _backRight,
                          () => _pickTyre('back_right'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allCaptured
                        ? const Color(0xFF7F53FD)
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _allCaptured
                              ? 'Upload Tyre Images'
                              : 'Capture all 4 tyres',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/



























































// class CarTyreScanScreen extends StatefulWidget {
//   const CarTyreScanScreen({
//     super.key,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     this.vin,
//   });

//   final String userId;
//   final String vehicleId;
//   final String token; // Bearer JWT
//   final String? vin;

//   @override
//   State<CarTyreScanScreen> createState() => _CarTyreScanScreenState();
// }

// class _CarTyreScanScreenState extends State<CarTyreScanScreen> {
//   final ImagePicker _picker = ImagePicker();

//   XFile? _frontLeft;
//   XFile? _frontRight;
//   XFile? _backLeft;
//   XFile? _backRight;

//   bool _uploading = false;
//   String? _error;

//   Future<void> _pickFrontLeft() async {
//     final file = await _picker.pickImage(source: ImageSource.camera);
//     if (file != null) {
//       setState(() {
//         _frontLeft = file;
//       });
//     }
//   }

//   Future<void> _pickFrontRight() async {
//     final file = await _picker.pickImage(source: ImageSource.camera);
//     if (file != null) {
//       setState(() {
//         _frontRight = file;
//       });
//     }
//   }

//   Future<void> _pickBackLeft() async {
//     final file = await _picker.pickImage(source: ImageSource.camera);
//     if (file != null) {
//       setState(() {
//         _backLeft = file;
//       });
//     }
//   }

//   Future<void> _pickBackRight() async {
//     final file = await _picker.pickImage(source: ImageSource.camera);
//     if (file != null) {
//       setState(() {
//         _backRight = file;
//       });
//     }
//   }

//   bool get _allCaptured =>
//       _frontLeft != null &&
//       _frontRight != null &&
//       _backLeft != null &&
//       _backRight != null;

//   Future<void> _upload() async {
//     if (!_allCaptured) {
//       setState(() {
//         _error = 'Please capture all 4 tyres first.';
//       });
//       return;
//     }

//     setState(() {
//       _uploading = true;
//       _error = null;
//     });

//     final uri = Uri.parse('http://54.162.208.215/app/tyre/fourwheeler/upload');
//     final request = http.MultipartRequest('POST', uri);

//     // Headers (Bearer token)
//     request.headers.addAll({
//       'Authorization': 'Bearer ${widget.token}',
//       'Accept': 'application/json',
//     });

//     // Fields
//     request.fields.addAll({
//       'user_id': widget.userId,
//       'vehicle_type': 'car',
//       'vehicle_id': widget.vehicleId,
//       if (widget.vin != null && widget.vin!.trim().isNotEmpty)
//         'vin': widget.vin!.trim(),
//     });

//     Future<http.MultipartFile> _fileField(String field, XFile file) async {
//       final mime = lookupMimeType(file.path) ?? 'image/jpeg';
//       final media = MediaType.parse(mime);
//       return http.MultipartFile.fromPath(
//         field,
//         file.path,
//         contentType: media,
//       );
//     }

//     try {
//       request.files.addAll([
//         await _fileField('front_left', _frontLeft!),
//         await _fileField('front_right', _frontRight!),
//         await _fileField('back_left', _backLeft!),
//         await _fileField('back_right', _backRight!),
//       ]);

//       debugPrint('==[4W-UPLOAD]==> POST $uri');
//       debugPrint('Headers: ${request.headers}');
//       debugPrint('Fields: ${request.fields}');
//       debugPrint(
//           'Files: FL=${_frontLeft!.path}, FR=${_frontRight!.path}, BL=${_backLeft!.path}, BR=${_backRight!.path}');

//       final streamed = await request.send();
//       final res = await http.Response.fromStream(streamed);

//       debugPrint('<==[4W-UPLOAD]== status: ${res.statusCode}');
//       debugPrint('<== body: ${res.body}');

//       if (!mounted) return;

//       if (res.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Tyre scan uploaded successfully')),
//         );
//         // OPTION: parse JSON + navigate to result screen
//         // final Map<String,dynamic> json = jsonDecode(res.body);
//         // ...
//       } else {
//         setState(() {
//           _error = 'Upload failed (${res.statusCode})';
//         });
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _error = 'Upload error: $e';
//       });
//     } finally {
//       if (mounted) {
//         setState(() => _uploading = false);
//       }
//     }
//   }

//   Widget _slot(String label, XFile? file, VoidCallback onTap) {
//     return Expanded(
//       child: InkWell(
//         onTap: _uploading ? null : onTap,
//         child: Container(
//           height: 120,
//           margin: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF0F1F5),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: file == null ? Colors.grey.shade400 : Colors.green,
//               width: 1.2,
//             ),
//           ),
//           child: file == null
//               ? Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.camera_alt_rounded, size: 28),
//                     const SizedBox(height: 8),
//                     Text(
//                       label,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 )
//               : ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: Image.file(
//                     File(file.path),
//                     fit: BoxFit.cover,
//                     width: double.infinity,
//                     height: double.infinity,
//                   ),
//                 ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     const bg = Color(0xFFF6F7FA);

//     return Scaffold(
//       backgroundColor: bg,
//       appBar: AppBar(
//         title: const Text('Car Tyre Scan'),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             const SizedBox(height: 12),
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 'Capture all four tyres: front left, front right, back left and back right.',
//                 style: TextStyle(fontSize: 14),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // 2x2 grid of capture slots
//             Expanded(
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       _slot('Front Left', _frontLeft, _pickFrontLeft),
//                       _slot('Front Right', _frontRight, _pickFrontRight),
//                     ],
//                   ),
//                   Row(
//                     children: [
//                       _slot('Back Left', _backLeft, _pickBackLeft),
//                       _slot('Back Right', _backRight, _pickBackRight),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             if (_error != null)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),

//             const SizedBox(height: 8),

//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
//               child: SizedBox(
//                 height: 48,
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: (!_allCaptured || _uploading) ? null : _upload,
//                   child: _uploading
//                       ? const SizedBox(
//                           height: 22,
//                           width: 22,
//                           child: CircularProgressIndicator(strokeWidth: 2.5),
//                         )
//                       : const Text('Upload Tyre Scan'),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
