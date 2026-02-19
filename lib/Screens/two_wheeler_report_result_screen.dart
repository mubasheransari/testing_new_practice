import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';

// class TwoWheelerReportResultScreen extends StatefulWidget {
//   final String title;

//   // upload args
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

//   // images
//   final String frontPath;
//   final String backPath;

//   // ✅ REQUIRED tyre IDs
//   final String frontTyreId;
//   final String backTyreId;

//   const TwoWheelerReportResultScreen({
//     super.key,
//     this.title = "Bike Report",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     this.vehicleType = "bike",
//     required this.frontPath,
//     required this.backPath,
//     required this.frontTyreId,
//     required this.backTyreId,
//   });

//   @override
//   State<TwoWheelerReportResultScreen> createState() =>
//       _TwoWheelerReportResultScreenState();
// }

// class _TwoWheelerReportResultScreenState extends State<TwoWheelerReportResultScreen> {
//   bool _dispatched = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
//   }

//   void _upload() {
//     if (_dispatched) return;
//     _dispatched = true;

//     context.read<AuthBloc>().add(
//           UploadTwoWheelerRequested(
//             userId: widget.userId,
//             vehicleId: widget.vehicleId,
//             token: widget.token,
//             vin: widget.vin,
//             vehicleType: widget.vehicleType,
//             frontPath: widget.frontPath,
//             backPath: widget.backPath,

//             // ✅ add these in event
//             frontTyreId: widget.frontTyreId,
//             backTyreId: widget.backTyreId,
//           ),
//         );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       appBar: AppBar(
//         title: Text(widget.title),
//       ),
//       body: BlocConsumer<AuthBloc, AuthState>(
//         listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
//         listener: (context, state) {
//           if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
//               state.twoWheelerError.trim().isNotEmpty) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text(state.twoWheelerError)),
//             );
//           }
//         },
//         builder: (context, state) {
//           final loading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
//           final TwoWheelerTyreUploadResponse? resp = state.twoWheelerResponse;

//           if (loading) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (resp == null) {
//             return Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   setState(() => _dispatched = false);
//                   _upload();
//                 },
//                 child: const Text("Retry"),
//               ),
//             );
//           }

//           // ✅ You can replace this UI with your existing report widgets/cards
//           return Padding(
//             padding: const EdgeInsets.all(16),
//             child: SingleChildScrollView(
//               child: Text(resp.toString()),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;

  // upload args
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  // images from scanner
  final String frontPath;
  final String backPath;

  // tyre ids required by API
  final String frontTyreId;
  final String backTyreId;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Bike Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontPath,
    required this.backPath,
    required this.frontTyreId,
    required this.backTyreId,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;

    context.read<AuthBloc>().add(
          UploadTwoWheelerRequested(
            userId: widget.userId,
            vehicleId: widget.vehicleId,
            token: widget.token,
            vin: widget.vin,
            vehicleType: widget.vehicleType,
            frontPath: widget.frontPath,
            backPath: widget.backPath,
            frontTyreId: widget.frontTyreId,
            backTyreId: widget.backTyreId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
          listener: (context, state) {
            if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
                state.twoWheelerError.trim().isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.twoWheelerError)),
              );
            }
          },
          buildWhen: (p, c) =>
              p.twoWheelerStatus != c.twoWheelerStatus ||
              p.twoWheelerResponse != c.twoWheelerResponse,
          builder: (context, state) {
            final loading = state.twoWheelerStatus == TwoWheelerStatus.uploading;

            return Column(
              children: [
                _TopBar(
                  s: s,
                  title: widget.title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 18 * s),
                    child: Column(
                      children: [
                        // ✅ Top images row (exact like screenshot)
                        _TopImagesRow(
                          s: s,
                          leftImage: widget.frontPath,
                          frontImage: widget.backPath,
                          middleImage: widget.frontPath,
                        ),
                        SizedBox(height: 14 * s),

                        // ✅ Cards area (exact layout)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _BigMetricCard(
                                s: s,
                                icon: Icons.circle_outlined,
                                title: "Tread Depth",
                                valueLine: "Value: 7.2 mm",
                                statusLine: "Status: Good",
                              ),
                            ),
                            SizedBox(width: 12 * s),
                            Expanded(
                              child: Column(
                                children: [
                                  _SmallMetricCard(
                                    s: s,
                                    title: "Tire Pressure",
                                    valueLine: "Value: 32 psi",
                                    statusLine: "Status: Optimal",
                                  ),
                                  SizedBox(height: 12 * s),
                                  _SmallMetricCard(
                                    s: s,
                                    title: "Damage Check",
                                    valueLine: "Value: No cracks",
                                    statusLine: "Status: Safe",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 14 * s),

                        // ✅ Report Summary (exact like screenshot)
                        _SummaryCard(
                          s: s,
                          title: "Report Summary:",
                          summary:
                              "Your wheel is in good condition with optimal tread depth and balanced pressure. No major wear or cracks detected.",
                        ),

                        SizedBox(height: 18 * s),

                        if (loading) ...[
                          const SizedBox(height: 10),
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 10),
                        ],

                        // Optional retry if response is null and not loading
                        if (!loading && state.twoWheelerResponse == null) ...[
                          SizedBox(height: 10 * s),
                          _RetryButton(
                            s: s,
                            onTap: () {
                              setState(() => _dispatched = false);
                              _upload();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- UI WIDGETS (MATCH SCREENSHOT) ---------------- */

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.s,
    required this.title,
    required this.onBack,
  });

  final double s;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10 * s, 6 * s, 10 * s, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 34),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 18 * s,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TopImagesRow extends StatelessWidget {
  const _TopImagesRow({
    required this.s,
    required this.leftImage,
    required this.frontImage,
    required this.middleImage,
  });

  final double s;
  final String leftImage;
  final String frontImage;
  final String middleImage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ImgCard(s: s, img: leftImage, label: "Front")),
        SizedBox(width: 10 * s),
        Expanded(child: _ImgCard(s: s, img: frontImage, label: "Back")),
        // SizedBox(width: 10 * s),
        // Expanded(child: _ImgCard(s: s, img: middleImage, label: "middle")),
      ],
    );
  }
}

class _ImgCard extends StatelessWidget {
  const _ImgCard({required this.s, required this.img, required this.label});

  final double s;
  final String img;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 150 * s,
          width: MediaQuery.of(context).size.width *0.35,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _smartImage(img),
        ),
        SizedBox(height: 8 * s),
        Container(
          height: 34 * s,
          width: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF29B6F6),
            borderRadius: BorderRadius.circular(10 * s),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smartImage(String src) {
    final s = src.trim();
    if (s.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF0F1F5),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    if (s.startsWith("http")) {
      return Image.network(
        s,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFF0F1F5),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }

    final f = File(s);
    if (f.existsSync()) {
      return Image.file(f, fit: BoxFit.cover);
    }

    return const ColoredBox(
      color: Color(0xFFF0F1F5),
      child: Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _BigMetricCard extends StatelessWidget {
  const _BigMetricCard({
    required this.s,
    required this.icon,
    required this.title,
    required this.valueLine,
    required this.statusLine,
  });

  final double s;
  final IconData icon;
  final String title;
  final String valueLine;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190 * s,
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 46 * s,
              height: 46 * s,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Icon(icon, color: const Color(0xFF29B6F6), size: 26 * s),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 20 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF29B6F6),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            valueLine,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            statusLine,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
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
    required this.valueLine,
    required this.statusLine,
  });

  final double s;
  final String title;
  final String valueLine;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 18 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF29B6F6),
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            valueLine,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            statusLine,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44 * s,
            height: 44 * s,
            decoration: const BoxDecoration(
              color: Color(0xFF29B6F6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.list_alt_rounded, color: Colors.white, size: 24 * s),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 22 * s,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 28 * s, color: const Color(0xFF111827)),
                  ],
                ),
                SizedBox(height: 8 * s),
                Text(
                  summary,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6A6F7B),
                    height: 1.35,
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

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.s, required this.onTap});
  final double s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * s),
          gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 14 * s,
              offset: Offset(0, 8 * s),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          "Retry",
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 15 * s,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
