import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/inspection_result_screen.dart';
import 'dart:io';


class InspectionResultScreen extends StatelessWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontPath,
    required this.backPath,
    required this.vehicleId,
    required this.userId,
    required this.token,
    this.response,
  });

  final String frontPath;
  final String backPath,vehicleId,userId,token;
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

            print("SUCCESS PRINT");
            print("SUCCESS PRINT");
            print("SUCCESS PRINT");
            print("SUCCESS PRINT");
            // Navigator.of(context).pushReplacement(
            //   MaterialPageRoute(
            //     builder: (_) => InspectionResultScreen(
            //       frontPath: widget.frontPath,
            //       backPath: widget.backPath,
            //       response: state.twoWheelerResponse,
            //     ),
            //   ),
            // );
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
