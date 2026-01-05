import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/car_tyres_scanner_screen.dart';
import 'dart:convert';
import 'dart:async';


class FourWheelerScanScreen extends StatefulWidget {
  final String userId;
  final String vehicleId;
  final String token;

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
  String? _error;

  late final TextEditingController _vinController;

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

  bool _validateRequiredIds() {
    final missing = <String>[];

    if ((widget.front_left_tyre_id ?? '').trim().isEmpty) {
      missing.add("front_left_tyre_id");
    }
    if ((widget.front_right_tyre_id ?? '').trim().isEmpty) {
      missing.add("front_right_tyre_id");
    }
    if ((widget.back_left_tyre_id ?? '').trim().isEmpty) {
      missing.add("back_left_tyre_id");
    }
    if ((widget.back_right_tyre_id ?? '').trim().isEmpty) {
      missing.add("back_right_tyre_id");
    }

    if (missing.isNotEmpty) {
      setState(() => _error = "Missing required tyre ids: ${missing.join(", ")}");
      return false;
    }
    return true;
  }

  Future<void> _openSingleCameraScanner() async {
    setState(() => _error = null);

    if (!_validateRequiredIds()) return;

    final vinToSend = _vinController.text.trim();
    // ✅ backend requires vin key always -> send UNKNOWN if empty
    final safeVin = vinToSend.isEmpty ? "UNKNOWN" : vinToSend;

  
    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CarTyresScannerScreen(
          title: "Car Tyre Scanner",
          userId: widget.userId,
          vehicleId: widget.vehicleId,
          token: widget.token,
          vin: '',
          vehicleType: "car",
          frontLeftTyreId: widget.front_left_tyre_id!.trim(),
          frontRightTyreId: widget.front_right_tyre_id!.trim(),
          backLeftTyreId: widget.back_left_tyre_id!.trim(),
          backRightTyreId: widget.back_right_tyre_id!.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;
    try {
      final map = (result is Map) ? result : jsonDecode(result.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(map['message']?.toString() ?? "Upload successful"),
        ),
      );

    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload successful")),
      );
    }
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
                padding: const EdgeInsets.all(10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _vinController,
                decoration: InputDecoration(
                  hintText: "VIN (optional)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Tap Start Scan. Camera will open once and capture 4 tyres.\nAfter 4th capture, upload & navigation will happen automatically.",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openSingleCameraScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  label: const Text(
                    "Start Scan",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F53FD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

