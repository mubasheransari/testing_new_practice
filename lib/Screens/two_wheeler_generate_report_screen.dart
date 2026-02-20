import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/scanner_front_tire_screen.dart';
import 'package:ios_tiretest_ai/Widgets/bottom_action_bar.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'two_wheeler_report_result_screen.dart'; 

enum TwoTyrePos { front, back }

class TwoWheelerGenerateReportScreen extends StatefulWidget {
  final String title;

  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

  const TwoWheelerGenerateReportScreen({
    super.key,
    this.title = "Bike Tyre Scanner",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
  });

  @override
  State<TwoWheelerGenerateReportScreen> createState() =>
      _TwoWheelerGenerateReportScreenState();
}

class _TwoWheelerGenerateReportScreenState extends State<TwoWheelerGenerateReportScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;

  bool _ready = false;
  bool _stopping = false;

  XFile? _front;
  XFile? _back;

  TwoTyrePos _active = TwoTyrePos.front;

  String? _error;
  bool _navigated = false;

  final ImagePicker _picker = ImagePicker();

  bool get _bothCaptured => _front != null && _back != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCam();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCameraSafely();
    } else if (state == AppLifecycleState.resumed) {
      if (!_stopping && mounted) {
        _initCam();
      }
    }
  }

  Future<void> _initCam() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        if (mounted) setState(() => _ready = true);
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'No camera found on device.');
        return;
      }

      final backCam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final c = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
        _ready = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera not available: $e';
        _ready = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera not available: $e')),
      );
    }
  }

  Future<void> _stopCameraSafely() async {
    if (_stopping) return;
    _stopping = true;

    final c = _controller;
    if (c == null) {
      _stopping = false;
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _ready = false;
          _controller = null;
        });
      }

      try {
        await c.pausePreview();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 80));
      await c.dispose();
    } catch (_) {
      // ignore
    } finally {
      _stopping = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCameraSafely();
    super.dispose();
  }

  void _setFileForNextSlot(XFile file) {
    setState(() {
      _error = null;

      if (_front == null) {
        _front = file;
        _active = TwoTyrePos.back;
        return;
      }

      if (_back == null) {
        _back = file;
        _active = TwoTyrePos.back;
        return;
      }

      // ✅ if both exist and user picks again, replace active slot
      if (_active == TwoTyrePos.front) {
        _front = file;
      } else {
        _back = file;
      }
    });
  }

  Future<void> _capture() async {
    if (_stopping) return;

    if (!_ready || _controller == null) {
      setState(() => _error = 'Camera not ready. Use Gallery instead.');
      return;
    }

    try {
      final shot = await _controller!.takePicture();
      if (!mounted) return;

      _setFileForNextSlot(shot);

      if (_bothCaptured) {
        await _goGenerateReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_stopping) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (!mounted) return;
      if (picked == null) return;

      _setFileForNextSlot(picked);

      if (_bothCaptured) {
        await _goGenerateReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gallery pick failed: $e');
    }
  }

  Future<void> _goGenerateReport() async {
    if (_navigated) return;
    if (_front == null || _back == null) return;

    _navigated = true;

    await _stopCameraSafely();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TwoWheelerReportResultScreen(
          frontPath: _front!.path,
          backPath: _back!.path,
          userId: widget.userId,
          vehicleId: widget.vehicleId,
          token: widget.token,
          vin: widget.vin,
          vehicleType: widget.vehicleType,
          frontTyreId: widget.frontTyreId,
          backTyreId: widget.backTyreId,
        ),
      ),
    );

    // ✅ after coming back, allow scanning again
    _navigated = false;

    if (mounted) {
      setState(() {
        _front = null;
        _back = null;
        _active = TwoTyrePos.front;
        _error = null;
      });
    }

    if (mounted) _initCam();
  }

  void _retake(TwoTyrePos pos) {
    setState(() {
      if (pos == TwoTyrePos.front) {
        _front = null;
        _back = null;
        _active = TwoTyrePos.front;
      } else {
        _back = null;
        _active = TwoTyrePos.back;
      }
      _error = null;
    });
  }

  String _stepText() {
    if (_bothCaptured) return 'Both tyres selected ✅';
    if (_front == null) return 'Select FRONT tyre image';
    return 'Now select BACK tyre image';
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final canPreview = _ready && _controller != null && !_stopping;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: canPreview
                ? _CameraPreviewCover(controller: _controller!)
                : const ColoredBox(color: Colors.black),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 0),
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

          // keep if exists
          const ScanOverlay(),

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

          Positioned(
            top: 120,
            left: 16 * s,
            right: 16 * s,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Text(
                _stepText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 13 * s,
                ),
              ),
            ),
          ),

          Positioned(
            top: 175,
            left: 16 * s,
            right: 16 * s,
            child: _CapturedTwoThumbsRow(
              s: s,
              active: _active,
              front: _front,
              back: _back,
              onSelect: (pos) => setState(() => _active = pos),
              onDelete: _retake,
            ),
          ),

          Positioned(
            left: 16 * s,
            right: 16 * s,
            bottom: 14 * s,
            child: BottomActionBar(
              enabled: !_stopping,
              onPickGallery: _pickFromGallery,
              onCapture: _capture,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CapturedTwoThumbsRow extends StatelessWidget {
  const _CapturedTwoThumbsRow({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
    required this.onSelect,
    required this.onDelete,
  });

  final double s;
  final TwoTyrePos active;
  final XFile? front;
  final XFile? back;

  final ValueChanged<TwoTyrePos> onSelect;
  final ValueChanged<TwoTyrePos> onDelete;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
          Expanded(child: _thumb("FRONT", TwoTyrePos.front, front)),
          SizedBox(width: 8 * s),
          Expanded(child: _thumb("BACK", TwoTyrePos.back, back)),
        ],
      ),
    );
  }

  Widget _thumb(String label, TwoTyrePos pos, XFile? file) {
    final selected = active == pos;

    return InkWell(
      onTap: () => onSelect(pos),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(2.2 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected ? _grad : null,
          color: selected ? null : Colors.white.withOpacity(.08),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withOpacity(.12),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null)
                  Image.file(File(file.path), fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white.withOpacity(.08),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          color: Colors.white.withOpacity(.9),
                          fontWeight: FontWeight.w800,
                          fontSize: 12 * s,
                        ),
                      ),
                    ),
                  ),
                if (file != null)
                  Positioned(
                    right: 6 * s,
                    top: 6 * s,
                    child: GestureDetector(
                      onTap: () => onDelete(pos),
                      child: Container(
                        width: 24 * s,
                        height: 24 * s,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(.12)),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16 * s,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// enum _BikeTyrePos { front, back }

// class TwoWheelerGenerateReportScreen extends StatefulWidget {
//   final String title;

//   // required for upload
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

//   // ✅ NEW: tyre ids (come from preferences API response)
//   final String frontTyreId;
//   final String backTyreId;

//   // images
//   final String frontPath;
//   final String backPath;

//   const TwoWheelerGenerateReportScreen({
//     super.key,
//     this.title = "Bike Report",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     this.vehicleType = "bike",

//     // ✅ REQUIRED
//     required this.frontTyreId,
//     required this.backTyreId,

//     required this.frontPath,
//     required this.backPath,
//   });

//   @override
//   State<TwoWheelerGenerateReportScreen> createState() =>
//       _TwoWheelerGenerateReportScreenState();
// }


//   @override
//   State<TwoWheelerGenerateReportScreen> createState() =>
//       _TwoWheelerGenerateReportScreenState();


// class _TwoWheelerGenerateReportScreenState
//     extends State<TwoWheelerGenerateReportScreen> {
//   bool _dispatched = false;
//   _BikeTyrePos _active = _BikeTyrePos.front;

//   @override
//   void initState() {
//     super.initState();
//     // Dispatch after first frame to avoid context issues
//     WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
//   }
// void _upload() {
//   if (_dispatched) return;
//   _dispatched = true;

//   // ✅ guard (prevents useless API call + gives clear message)
//   if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Missing tyre ids. Save preferences again.'),
//       ),
//     );
//     return;
//   }

//   context.read<AuthBloc>().add(
//         UploadTwoWheelerRequested(
//           userId: widget.userId,
//           vehicleId: widget.vehicleId,
//           token: widget.token,
//           vin: widget.vin,
//           vehicleType: widget.vehicleType,
//           frontPath: widget.frontPath,
//           backPath: widget.backPath,

//           // ✅ NEW REQUIRED FIELDS
//           frontTyreId: widget.frontTyreId,
//           backTyreId: widget.backTyreId,
//         ),
//       );
// }

//   // void _upload() {
//   //   if (_dispatched) return;
//   //   _dispatched = true;

//   //   context.read<AuthBloc>().add(
//   //         UploadTwoWheelerRequested(
//   //           userId: widget.userId,
//   //           vehicleId: widget.vehicleId,
//   //           token: widget.token,
//   //           vin: widget.vin,
//   //           vehicleType: widget.vehicleType,
//   //           frontPath: widget.frontPath,
//   //           backPath: widget.backPath,
//   //         ),
//   //       );
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       body: SafeArea(
//         child: BlocConsumer<AuthBloc, AuthState>(
//           listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
//           listener: (context, state) {
//             if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
//                 (state.twoWheelerError).trim().isNotEmpty) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text(state.twoWheelerError)),
//               );
//             }
//           },
//           buildWhen: (p, c) =>
//               p.twoWheelerStatus != c.twoWheelerStatus ||
//               p.twoWheelerResponse != c.twoWheelerResponse,
//           builder: (context, state) {
//             final loading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
//             final resp = state.twoWheelerResponse;

//             return Column(
//               children: [
//                 _TopBar(
//                   s: s,
//                   title: widget.title,
//                   onBack: () => Navigator.of(context).pop(),
//                 ),

//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _HeaderCard(
//                           s: s,
//                           title: "Tyre Inspection Report",
//                           subtitle: "Bike • Front + Back",
//                         ),
//                         SizedBox(height: 12 * s),

//                         // Toggle front/back once data available (or even before)
//                         _SegmentToggle(
//                           s: s,
//                           leftLabel: "Front",
//                           rightLabel: "Back",
//                           isLeft: _active == _BikeTyrePos.front,
//                           onLeft: () => setState(() => _active = _BikeTyrePos.front),
//                           onRight: () => setState(() => _active = _BikeTyrePos.back),
//                         ),
//                         SizedBox(height: 12 * s),

//                         if (loading) ...[
//                           _LoadingCard(s: s),
//                           SizedBox(height: 12 * s),
//                         ],

//                         if (!loading && resp == null) ...[
//                           _EmptyStateCard(
//                             s: s,
//                             title: "No report yet",
//                             subtitle:
//                                 "Tap retry to generate the bike report again.",
//                             onRetry: () {
//                               setState(() => _dispatched = false);
//                               _upload();
//                             },
//                           ),
//                         ],

//                         if (resp != null) ...[
//                           _TyreReportSection(
//                             s: s,
//                             active: _active,
//                             resp: resp,
//                           ),
//                         ],
//                       ],
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

// class _TyreReportSection extends StatelessWidget {
//   const _TyreReportSection({
//     required this.s,
//     required this.active,
//     required this.resp,
//   });

//   final double s;
//   final _BikeTyrePos active;
//   final TwoWheelerTyreUploadResponse resp;

//   @override
//   Widget build(BuildContext context) {
//     final t = _uiFor(active, resp);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Image Preview (base64 or url)
//         _TyreImageCard(s: s, title: t.title, imageUrl: t.imageUrl),
//         SizedBox(height: 12 * s),

//         // Condition / Tread / Wear
//         Row(
//           children: [
//             Expanded(
//               child: _SmallMetricCard(
//                 s: s,
//                 title: "Condition",
//                 value: t.condition.trim().isEmpty ? "—" : t.condition,
//                 status: "",
//               ),
//             ),
//             SizedBox(width: 10 * s),
//             Expanded(
//               child: _SmallMetricCard(
//                 s: s,
//                 title: "Tread Depth",
//                 value: t.treadDepth <= 0 ? "—" : "${t.treadDepth.toStringAsFixed(2)} mm",
//                 status: "",
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 10 * s),

//         _SmallMetricCard(
//           s: s,
//           title: "Wear Patterns",
//           value: t.wearPatterns.trim().isEmpty ? "—" : t.wearPatterns,
//           status: "",
//         ),
//         SizedBox(height: 10 * s),

//         // ✅ NEW CARD: Tire Pressure (full details)
//         _TyrePressureCard(
//           s: s,
//           title: "Tire Pressure",
//           composed: _composeSelectedSummary(t),
//         ),
//         SizedBox(height: 10 * s),

//         // Summary
//         _SummaryCard(
//           s: s,
//           title: "Summary",
//           summary: t.summary.trim().isEmpty ? "—" : t.summary.trim(),
//         ),
//       ],
//     );
//   }

//   _TyreUi _uiFor(_BikeTyrePos pos, TwoWheelerTyreUploadResponse resp) {
//     final data = resp.data;
//     final tyre = pos == _BikeTyrePos.front ? data!.front : data!.back;

//     return _TyreUi(
//       title: pos == _BikeTyrePos.front ? "Front Tyre" : "Back Tyre",
//       condition: tyre.condition,
//       treadDepth: tyre.treadDepth,
//       wearPatterns: tyre.wearPatterns,
//       summary: tyre.summary,
//       imageUrl: tyre.imageUrl,
//       pressureStatus: tyre.pressureAdvisory!.status,
//       pressureReason: tyre.pressureAdvisory!.reason,
//       pressureConfidence: tyre.pressureAdvisory!.confidence,
//       pressureValue: "—", // backend doesn’t provide numeric PSI in your model
//     );
//   }

//   // ✅ You asked to show this logic in Tire Pressure card
//   String _composeSelectedSummary(_TyreUi t) {
//     final parts = <String>[];

//     if (t.summary.trim().isNotEmpty && t.summary != '—') {
//       parts.add(t.summary.trim());
//     }

//     if (t.pressureStatus != '—' ||
//         t.pressureReason.trim().isNotEmpty ||
//         t.pressureConfidence.trim().isNotEmpty) {
//       parts.add([
//         'Tire pressure:',
//         '• Status: ${t.pressureStatus.trim().isEmpty ? "—" : t.pressureStatus}',
//         if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
//         if (t.pressureConfidence.trim().isNotEmpty)
//           '• Confidence: ${t.pressureConfidence}',
//       ].join('\n'));
//     }

//     return parts.isEmpty ? '—' : parts.join('\n\n');
//   }
// }

// class _TyreUi {
//   final String title;

//   final String condition;
//   final double treadDepth;
//   final String wearPatterns;
//   final String summary;
//   final String imageUrl;

//   final String pressureValue;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;

//   const _TyreUi({
//     required this.title,
//     required this.condition,
//     required this.treadDepth,
//     required this.wearPatterns,
//     required this.summary,
//     required this.imageUrl,
//     required this.pressureValue,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//   });
// }

// class _TopBar extends StatelessWidget {
//   const _TopBar({
//     required this.s,
//     required this.title,
//     required this.onBack,
//   });

//   final double s;
//   final String title;
//   final VoidCallback onBack;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(10 * s, 6 * s, 10 * s, 0),
//       child: Row(
//         children: [
//           IconButton(
//             onPressed: onBack,
//             icon: const Icon(Icons.chevron_left_rounded, size: 34),
//           ),
//           Expanded(
//             child: Text(
//               title,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 18 * s,
//                 fontWeight: FontWeight.w900,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ),
//           const SizedBox(width: 48),
//         ],
//       ),
//     );
//   }
// }

// class _HeaderCard extends StatelessWidget {
//   const _HeaderCard({
//     required this.s,
//     required this.title,
//     required this.subtitle,
//   });

//   final double s;
//   final String title;
//   final String subtitle;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18 * s),
//         gradient: const LinearGradient(
//           colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF7F53FD).withOpacity(.25),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
//           SizedBox(width: 10 * s),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 18 * s,
//                     fontWeight: FontWeight.w900,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(height: 4 * s),
//                 Text(
//                   subtitle,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 13 * s,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.white.withOpacity(.92),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SegmentToggle extends StatelessWidget {
//   const _SegmentToggle({
//     required this.s,
//     required this.leftLabel,
//     required this.rightLabel,
//     required this.isLeft,
//     required this.onLeft,
//     required this.onRight,
//   });

//   final double s;
//   final String leftLabel;
//   final String rightLabel;
//   final bool isLeft;
//   final VoidCallback onLeft;
//   final VoidCallback onRight;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 44 * s,
//       padding: EdgeInsets.all(4 * s),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F1F5),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: _seg(
//               label: leftLabel,
//               active: isLeft,
//               onTap: onLeft,
//             ),
//           ),
//           Expanded(
//             child: _seg(
//               label: rightLabel,
//               active: !isLeft,
//               onTap: onRight,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _seg({
//     required String label,
//     required bool active,
//     required VoidCallback onTap,
//   }) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 180),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(999),
//         gradient: active
//             ? const LinearGradient(
//                 colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//               )
//             : null,
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(999),
//           onTap: onTap,
//           child: Center(
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14 * s,
//                 fontWeight: FontWeight.w900,
//                 color: active ? Colors.white : const Color(0xFF4B5563),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _LoadingCard extends StatelessWidget {
//   const _LoadingCard({required this.s});
//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.06),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Row(
//         children: [
//           const SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(strokeWidth: 2.6),
//           ),
//           SizedBox(width: 12 * s),
//           Expanded(
//             child: Text(
//               "Generating report… Please wait",
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14 * s,
//                 fontWeight: FontWeight.w800,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _EmptyStateCard extends StatelessWidget {
//   const _EmptyStateCard({
//     required this.s,
//     required this.title,
//     required this.subtitle,
//     required this.onRetry,
//   });

//   final double s;
//   final String title;
//   final String subtitle;
//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.06),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 18 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13 * s,
//               fontWeight: FontWeight.w600,
//               color: const Color(0xFF6A6F7B),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           GestureDetector(
//             onTap: onRetry,
//             child: Container(
//               height: 44 * s,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12 * s),
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//                 ),
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 "Retry",
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontSize: 14 * s,
//                   fontWeight: FontWeight.w900,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

// class _TyreImageCard extends StatelessWidget {
//   const _TyreImageCard({
//     required this.s,
//     required this.title,
//     required this.imageUrl,
//   });

//   final double s;
//   final String title;
//   final String imageUrl;

//   @override
//   Widget build(BuildContext context) {
//     final img = _imageWidget(imageUrl);

//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.06),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 18 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF00C6FF),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(14 * s),
//             child: AspectRatio(
//               aspectRatio: 16 / 10,
//               child: img,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _imageWidget(String url) {
//     if (url.trim().isEmpty) {
//       return Container(
//         color: const Color(0xFFF0F1F5),
//         child: const Center(child: Icon(Icons.image_not_supported_outlined)),
//       );
//     }

//     // base64 data url
//     if (url.startsWith("data:image")) {
//       try {
//         final comma = url.indexOf(',');
//         final b64 = comma >= 0 ? url.substring(comma + 1) : url;
//         final bytes = base64Decode(b64);
//         return Image.memory(bytes, fit: BoxFit.cover);
//       } catch (_) {
//         return Container(
//           color: const Color(0xFFF0F1F5),
//           child: const Center(child: Icon(Icons.broken_image_outlined)),
//         );
//       }
//     }

//     // normal URL
//     return Image.network(
//       url,
//       fit: BoxFit.cover,
//       errorBuilder: (_, __, ___) => Container(
//         color: const Color(0xFFF0F1F5),
//         child: const Center(child: Icon(Icons.broken_image_outlined)),
//       ),
//       loadingBuilder: (context, child, progress) {
//         if (progress == null) return child;
//         return Container(
//           color: const Color(0xFFF0F1F5),
//           child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
//         );
//       },
//     );
//   }
// }

// // ✅ keep your existing card as-is (used above)
// class _SmallMetricCard extends StatelessWidget {
//   const _SmallMetricCard({
//     required this.s,
//     required this.title,
//     required this.value,
//     required this.status,
//   });

//   final double s;
//   final String title;
//   final String value;
//   final String status;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 22 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF00C6FF),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             value,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           if (status.trim().isNotEmpty) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               status,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 16 * s,
//                 fontWeight: FontWeight.w700,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// /// ✅ NEW CARD (your request): Tire Pressure full data in ONE card
// /// (No change to other classes)
// class _TyrePressureCard extends StatelessWidget {
//   const _TyrePressureCard({
//     required this.s,
//     required this.title,
//     required this.composed,
//   });

//   final double s;
//   final String title;
//   final String composed;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 22 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF00C6FF),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             composed.trim().isEmpty ? "—" : composed,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//               height: 1.35,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SummaryCard extends StatelessWidget {
//   const _SummaryCard({
//     required this.s,
//     required this.title,
//     required this.summary,
//   });

//   final double s;
//   final String title;
//   final String summary;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.08),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF00C6FF),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//               height: 1.35,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
