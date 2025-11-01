import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/inspection_result_screen.dart';




import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart' hide TyreUploadResponse; // ✅ use your real model

class InspectionResultScreen extends StatelessWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontPath,
    required this.backPath,
    this.response,
  });

  final String frontPath;
  final String backPath;
  final TyreUploadResponse? response;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;
    final data = response?.data;

    // 👇 adjust field names here if your model is slightly different
    final frontImg = (data?.frontWheelUrl != null && data!.frontWheelUrl!.isNotEmpty)
        ? NetworkImage(data.frontWheelUrl!)
        : FileImage(File(frontPath)) as ImageProvider;

    final backImg = (data?.backWheelUrl != null && data!.backWheelUrl!.isNotEmpty)
        ? NetworkImage(data.backWheelUrl!)
        : FileImage(File(backPath)) as ImageProvider;

    final extraImg = const AssetImage('assets/bike_wheel.png');

    final treadDepth = data?.treadDepth ?? '7.2 mm';
    final treadStatus = data?.treadStatus ?? 'Good';
    final tyrePressure = (data?.tyrePressure ?? '32').toString();
    final tyrePressureStatus = data?.tyrePressureStatus ?? 'Optimal';
    final damageCheck = data?.damageCheck ?? 'No cracks';
    final damageStatus = data?.damageStatus ?? 'Safe';

    final summary = response?.message ??
        'Your wheel is in good condition with optimal tread depth and balanced pressure. '
            'No major wear or cracks detected.';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 28 * s),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PhotoCard(
                s: s,
                image: frontImg,
                label: 'left',
                gradient: const LinearGradient(
                  colors: [Color(0xFF30C5FF), Color(0xFF4676FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              SizedBox(width: 12 * s),
              _PhotoCard(
                s: s,
                image: backImg,
                label: 'Front',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7E6D), Color(0xFFFF57B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              // SizedBox(width: 12 * s),
              // Expanded(
              //   child: _PhotoCard(
              //     s: s,
              //     image: extraImg,
              //     label: 'middle',
              //     gradient: const LinearGradient(
              //       colors: [Color(0xFF39D2C0), Color(0xFF7993FF)],
              //       begin: Alignment.topLeft,
              //       end: Alignment.bottomRight,
              //     ),
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 18 * s),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: _BigMetricCard(
                  s: s,
                  iconBg: const LinearGradient(
                    colors: [Color(0xFF4F7BFF), Color(0xFFA6C8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.sync,
                  title: 'Tread Depth',
                  value: 'Value: $treadDepth',
                  status: 'Status: $treadStatus',
                ),
              ),
              SizedBox(width: 14 * s),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    _SmallMetricCard(
                      s: s,
                      title: 'Tire Pressure',
                      value: 'Value: $tyrePressure',
                      status: 'Status: $tyrePressureStatus',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F7BFF), Color(0xFF80B3FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    _SmallMetricCard(
                      s: s,
                      title: 'Damage Check',
                      value: 'Value: $damageCheck',
                      status: 'Status: $damageStatus',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF69A3FF), Color(0xFF9C7FFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * s),

          _ReportSummaryCard(
            s: s,
            title: 'Report Summary:',
            summary: summary,
          ),
          SizedBox(height: 18 * s),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB8C1D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14 * s),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF4F7BFF)),
                  label: Text(
                    'Share Report',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F7BFF),
                    ),
                  ),
                  onPressed: () => _toast(context, 'Share pressed'),
                ),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F7BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15 * s),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download PDF',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 14 * s,
                    ),
                  ),
                  onPressed: () => _toast(context, 'Download pressed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}

/* === widgets from previous answer (unchanged) === */

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.s,
    required this.image,
    required this.label,
    required this.gradient,
  });

  final double s;
  final ImageProvider image;
  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
       width: MediaQuery.of(context).size.width *0.40,
      // height: 252,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8 * s,
            offset: Offset(0, 3 * s),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12 * s),
            child: Image(image: image, fit: BoxFit.cover,height: 252),
          ),
          SizedBox(height: 8 * s),
          Container(
            height: 28 * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13 * s,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigMetricCard extends StatelessWidget {
  const _BigMetricCard({
    required this.s,
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });

  final double s;
  final Gradient iconBg;
  final IconData icon;
  final String title;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 165 * s,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14 * s,
            offset: Offset(0, 8 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50 * s,
            height: 50 * s,
            decoration: BoxDecoration(
              gradient: iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B9BFF).withOpacity(.35),
                  blurRadius: 12 * s,
                  offset: Offset(0, 5 * s),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26 * s),
          ),
          SizedBox(height: 12 * s),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 20 * s,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4F7BFF),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 15 * s,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            status,
            style: TextStyle(
              color: Colors.black.withOpacity(.8),
              fontSize: 14 * s,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.gradient,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(13 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: const Color(0xFFE8E9F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 9 * s,
            offset: Offset(0, 5 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (r) => gradient.createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w800,
                fontSize: 17 * s,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 14.5 * s,
              color: const Color(0xFF111826),
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            status,
            style: TextStyle(
              color: Colors.black.withOpacity(.5),
              fontSize: 13 * s,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.s,
    required this.title,
    required this.summary,
  });

  final double s;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54 * s,
            height: 54 * s,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7BFF), Color(0xFF5FD1FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7BFF).withOpacity(.35),
                  blurRadius: 14 * s,
                  offset: Offset(0, 6 * s),
                ),
              ],
            ),
            child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26 * s),
          ),
          SizedBox(width: 14 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 18 * s,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: Colors.black, size: 24 * s),
                  ],
                ),
                SizedBox(height: 6 * s),
                Text(
                  summary,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14.5 * s,
                    color: Colors.black.withOpacity(.75),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
