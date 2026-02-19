import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';
import 'dart:convert';


enum _BikeTyrePos { front, back }

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  // tyre ids (come from preferences response)
  final String frontTyreId;
  final String backTyreId;

  // images
  final String frontPath;
  final String backPath;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Inspection Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontTyreId,
    required this.backTyreId,
    required this.frontPath,
    required this.backPath,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState
    extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;
  _BikeTyrePos _active = _BikeTyrePos.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;

    if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing tyre ids. Save preferences again.')),
      );
      return;
    }

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
            final loading =
                state.twoWheelerStatus == TwoWheelerStatus.uploading;

            final resp = state.twoWheelerResponse; // TwoWheelerTyreUploadResponse?
            final data = resp?.data; // ✅ NEW: OBJECT (record_id, front, back)

            // ✅ front/back objects from NEW response
            final front = data?.front;
            final back = data?.back;

            final hasAny = (front != null) || (back != null);

            return Column(
              children: [
                _TopBar(
                  s: s,
                  title: widget.title,
                  onBack: () {
     Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>  AppShell() 
              
        ),
        (route) => false,
      );

                  //  Navigator.of(context).pop();
                  //  Navigator.of(context).pop();
                  //   Navigator.of(context).pop();
                  }
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // _HeaderCard(
                        //   s: s,
                        //   title: "Tyre Inspection Report",
                        //   subtitle: "Bike • Front + Back",
                        // ),
                        //SizedBox(height: 5 * s),

                        _SegmentToggle(
                          s: s,
                          leftLabel: "Front",
                          rightLabel: "Back",
                          isLeft: _active == _BikeTyrePos.front,
                          onLeft: () => setState(() => _active = _BikeTyrePos.front),
                          onRight: () => setState(() => _active = _BikeTyrePos.back),
                        ),
                        SizedBox(height: 12 * s),

                        if (loading) ...[
                          _LoadingCard(s: s),
                          SizedBox(height: 12 * s),
                        ],

                        // ✅ If API not returned anything yet
                        if (!loading && resp == null) ...[
                          _EmptyStateCard(
                            s: s,
                            title: "No report yet",
                            subtitle: "Tap retry to generate the bike report again.",
                            onRetry: () {
                              setState(() => _dispatched = false);
                              _upload();
                            },
                          ),
                        ],

                        // ✅ If response exists but data missing
                        if (!loading && resp != null && !hasAny) ...[
                          _EmptyStateCard(
                            s: s,
                            title: "No data found",
                            subtitle: "Upload succeeded but front/back data is missing.",
                            onRetry: () {
                              setState(() => _dispatched = false);
                              _upload();
                            },
                          ),
                        ],

                        // ✅ Show report
                        if (hasAny) ...[
                          _TyreReportSection(
                            s: s,
                            active: _active,
                            front: front,
                            back: back,
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

class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
  });

  final double s;
  final _BikeTyrePos active;

  // ✅ These types come from your NEW model:
  // data.front, data.back
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  @override
  Widget build(BuildContext context) {
    final side = active == _BikeTyrePos.front ? front : back;

    // If selected side is null, show friendly empty
    if (side == null) {
      return _EmptyStateCard(
        s: s,
        title: "No ${active == _BikeTyrePos.front ? "front" : "back"} tyre data",
        subtitle: "Try scanning again.",
        onRetry: () => Navigator.of(context).pop(),
      );
    }

    final t = _TyreUi.fromSide(
      title: active == _BikeTyrePos.front ? "Front" : "Back",
      side: side,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TyreImageCard(
          s: s,
          title: t.title,
          imageUrl: t.imageUrl,
        ),
        SizedBox(height: 12 * s),

        Row(
          children: [
            Expanded(
              child: _SmallMetricCard(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText, // ✅ show condition here
              ),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: _SmallMetricCard(
                s: s,
                title: "Tire Pressure",
                value: t.pressureValueText,
                status: t.pressureStatusText,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),

        _SmallMetricCard(
          s: s,
          title: "Damage Check",
          value: t.wearPatternsText,
          status: t.damageStatusText,
        ),
        SizedBox(height: 10 * s),

        _SummaryCard(
          s: s,
          title: "Report Summary:",
          summary: t.summaryText,
        ),
      ],
    );
  }
}

class _TyreUi {
  final String title;

  final String treadDepthText;
  final String conditionText;

  final String wearPatternsText;
  final String damageStatusText;

  final String summaryText;

  final String imageUrl;

  final String pressureValueText; // API doesn't return numeric PSI -> "N/A" unless you add later
  final String pressureStatusText;
  final String pressureReasonText;
  final String pressureConfidenceText;

  const _TyreUi({
    required this.title,
    required this.treadDepthText,
    required this.conditionText,
    required this.wearPatternsText,
    required this.damageStatusText,
    required this.summaryText,
    required this.imageUrl,
    required this.pressureValueText,
    required this.pressureStatusText,
    required this.pressureReasonText,
    required this.pressureConfidenceText,
  });

  factory _TyreUi.fromSide({
    required String title,
    required TwoWheelerTyreSide side,
  }) {
    String str(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.toLowerCase() == 'null') return '';
      return s;
    }

    // tread depth is double in API
    final td = side.treadDepth;
    final tread = (td == null) ? '' : td.toString();

    final pressure = side.pressureAdvisory;

    final status = str(pressure?.status);
    final reason = str(pressure?.reason);
    final confidence = str(pressure?.confidence);

    // ✅ "Tire Pressure" card shows ALL details in a nice format:
    // Value: N/A (no PSI)
    // Status: Possible Under-Inflation
    // (reason/confidence appended to value so user sees everything)
    final valueLines = <String>[];
    valueLines.add('Value: N/A');
    if (reason.isNotEmpty) valueLines.add('Reason: $reason');
    if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

    return _TyreUi(
      title: title,
      treadDepthText: tread.isEmpty ? "N/A" : "$tread mm",
      conditionText: str(side.condition).isEmpty ? "" : "Status: ${str(side.condition)}",
      wearPatternsText: str(side.wearPatterns).isEmpty ? "N/A" : str(side.wearPatterns),
      damageStatusText: str(side.condition).isEmpty ? "" : str(side.condition),
      summaryText: str(side.summary).isEmpty ? "N/A" : str(side.summary),
      imageUrl: str(side.imageUrl),
      pressureValueText: valueLines.join('\n'),
      pressureStatusText: status.isEmpty ? "" : status,
      pressureReasonText: reason,
      pressureConfidenceText: confidence,
    );
  }
}

/* ============================ UI WIDGETS (unchanged) ============================ */

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
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                        ),
              // style: TextStyle(
              //   fontFamily: 'ClashGrotesk',
              //   fontSize: 18 * s,
              //   fontWeight: FontWeight.w900,
              //   color: const Color(0xFF111827),
              // ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.s,
    required this.title,
    required this.subtitle,
  });

  final double s;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * s),
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F53FD).withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 18 * s,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(.92),
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

class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle({
    required this.s,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeft,
    required this.onLeft,
    required this.onRight,
  });

  final double s;
  final String leftLabel;
  final String rightLabel;
  final bool isLeft;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44 * s,
      padding: EdgeInsets.all(4 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _seg(label: leftLabel, active: isLeft, onTap: onLeft),
          ),
          Expanded(
            child: _seg(label: rightLabel, active: !isLeft, onTap: onRight),
          ),
        ],
      ),
    );
  }

  Widget _seg({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final double s;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
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
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A6F7B),
            ),
          ),
          SizedBox(height: 12 * s),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              height: 44 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12 * s),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "Retry",
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 14 * s,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _TyreImageCard extends StatelessWidget {
  const _TyreImageCard({
    required this.s,
    required this.title,
    required this.imageUrl,
  });

  final double s;
  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final img = _imageWidget(imageUrl);

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
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
              color: const Color(0xFF00C6FF),
            ),
          ),
          SizedBox(height: 10 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(14 * s),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: img,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageWidget(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color: const Color(0xFFF0F1F5),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    if (url.startsWith("data:image")) {
      try {
        final comma = url.indexOf(',');
        final b64 = comma >= 0 ? url.substring(comma + 1) : url;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: const Color(0xFFF0F1F5),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF0F1F5),
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF0F1F5),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
  });

  final double s;
  final String title;
  final String value;
  final String status;

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
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF00C6FF),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            value.trim().isEmpty ? "N/A" : value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.35,
            ),
          ),
          if (status.trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              status.startsWith("Status:") ? status : "Status: $status",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
          ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: Color(0xFF00C6FF)),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 20 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF111827)),
            ],
          ),
          SizedBox(height: 10 * s),
          Text(
            summary.trim().isEmpty ? "N/A" : summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}


// enum _BikeTyrePos { front, back }

// class TwoWheelerReportResultScreen extends StatefulWidget {
//   final String title;

//   // required for upload
//   final String userId;
//   final String vehicleId;
//   final String token;
//   final String vin;
//   final String vehicleType;

//   // tyre ids (come from preferences response)
//   final String frontTyreId;
//   final String backTyreId;

//   // images
//   final String frontPath;
//   final String backPath;

//   const TwoWheelerReportResultScreen({
//     super.key,
//     this.title = "Bike Report",
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     this.vehicleType = "bike",
//     required this.frontTyreId,
//     required this.backTyreId,
//     required this.frontPath,
//     required this.backPath,
//   });

//   @override
//   State<TwoWheelerReportResultScreen> createState() =>
//       _TwoWheelerReportResultScreenState();
// }

// class _TwoWheelerReportResultScreenState extends State<TwoWheelerReportResultScreen> {
//   bool _dispatched = false;
//   _BikeTyrePos _active = _BikeTyrePos.front;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
//   }

//   void _upload() {
//     if (_dispatched) return;
//     _dispatched = true;

//     if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Missing tyre ids. Save preferences again.')),
//       );
//       return;
//     }

//     context.read<AuthBloc>().add(
//           UploadTwoWheelerRequested(
//             userId: widget.userId,
//             vehicleId: widget.vehicleId,
//             token: widget.token,
//             vin: widget.vin,
//             vehicleType: widget.vehicleType,
//             frontPath: widget.frontPath,
//             backPath: widget.backPath,
//             frontTyreId: widget.frontTyreId,
//             backTyreId: widget.backTyreId,
//           ),
//         );
//   }

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
//                 state.twoWheelerError.trim().isNotEmpty) {
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

//             final rec = _pickBestRecord(resp);

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
//                             subtitle: "Tap retry to generate the bike report again.",
//                             onRetry: () {
//                               setState(() => _dispatched = false);
//                               _upload();
//                             },
//                           ),
//                         ],

//                         if (!loading && resp != null && rec == null) ...[
//                           _EmptyStateCard(
//                             s: s,
//                             title: "No data found",
//                             subtitle: "API returned empty data list.",
//                             onRetry: () {
//                               setState(() => _dispatched = false);
//                               _upload();
//                             },
//                           ),
//                         ],

//                         if (rec != null) ...[
//                           _TyreReportSection(
//                             s: s,
//                             active: _active,
//                             record: rec,
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

//   /// ✅ API returns: data: [ {...}, {...} ]
//   /// We pick latest by Record ID if available; otherwise take first.
//   TwoWheelerRecord? _pickBestRecord(TwoWheelerTyreUploadResponse? resp) {
//     final list = resp?.data;
//     if (list == null || list.isEmpty) return null;

//     // If recordId exists, pick highest
//     try {
//       final sorted = List<TwoWheelerRecord>.from(list);
//       sorted.sort((a, b) => (b.recordId ?? 0).compareTo(a.recordId ?? 0));
//       return sorted.first;
//     } catch (_) {
//       return list.first;
//     }
//   }
// }

// class _TyreReportSection extends StatelessWidget {
//   const _TyreReportSection({
//     required this.s,
//     required this.active,
//     required this.record,
//   });

//   final double s;
//   final _BikeTyrePos active;
//   final TwoWheelerRecord record;

//   @override
//   Widget build(BuildContext context) {
//     final t = _uiFor(active, record);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _TyreImageCard(
//           s: s,
//           title: t.title,
//           imageUrl: t.imageUrl,
//         ),
//         SizedBox(height: 12 * s),

//         Row(
//           children: [
//             Expanded(
//               child: _SmallMetricCard(
//                 s: s,
//                 title: "Tread Depth",
//                 value: t.tread.trim().isEmpty ? "N/A" : t.tread,
//                 status: "",
//               ),
//             ),
//             SizedBox(width: 10 * s),
//             Expanded(
//               child: _SmallMetricCard(
//                 s: s,
//                 title: "Tire Pressure",
//                 value: t.pressure.trim().isEmpty ? "N/A" : t.pressure,
//                 status: t.pressureStatus.trim().isEmpty ? "" : t.pressureStatus,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 10 * s),

//         _SmallMetricCard(
//           s: s,
//           title: "Damage Check",
//           value: t.wearPatterns.trim().isEmpty ? "N/A" : t.wearPatterns,
//           status: t.status.trim().isEmpty ? "" : t.status,
//         ),
//         SizedBox(height: 10 * s),

//         _SummaryCard(
//           s: s,
//           title: "Report Summary:",
//           summary: t.summary.trim().isEmpty ? "N/A" : t.summary.trim(),
//         ),
//       ],
//     );
//   }

//   _TyreUi _uiFor(_BikeTyrePos pos, TwoWheelerRecord r) {
//     final isFront = pos == _BikeTyrePos.front;

//     return _TyreUi(
//       title: isFront ? "Front" : "Back",
//       tread: isFront ? _str(r.frontTyreTread) : _str(r.backTyreTread),
//       wearPatterns: isFront ? _str(r.frontTyreWearPatterns) : _str(r.backTyreWearPatterns),
//       pressure: isFront ? _str(r.frontTyrePressure) : _str(r.backTyrePressure),
//       // Your API has: "Front Tyre status": "Safe"
//       status: isFront ? _str(r.frontTyreStatus) : _str(r.backTyreStatus),

//       // if you want a "Status: Optimal" like mock UI, you can map:
//       // Safe -> Safe, else -> Attention
//       pressureStatus: (isFront ? _str(r.frontTyreStatus) : _str(r.backTyreStatus)),

//       summary: isFront ? _str(r.frontTyreSummary) : _str(r.backTyreSummary),

//       // image keys:
//       // "Front Wheel": "...url..."
//       imageUrl: isFront ? _str(r.frontWheelUrl) : _str(r.backWheelUrl),
//     );
//   }

//   String _str(dynamic v) {
//     if (v == null) return '';
//     final s = v.toString().trim();
//     if (s.toLowerCase() == 'null') return '';
//     return s;
//   }
// }

// class _TyreUi {
//   final String title;

//   final String tread;
//   final String wearPatterns;
//   final String pressure;
//   final String pressureStatus;
//   final String status;
//   final String summary;
//   final String imageUrl;

//   const _TyreUi({
//     required this.title,
//     required this.tread,
//     required this.wearPatterns,
//     required this.pressure,
//     required this.pressureStatus,
//     required this.status,
//     required this.summary,
//     required this.imageUrl,
//   });
// }

// /* ============================ UI WIDGETS ============================ */

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
//             child: _seg(label: leftLabel, active: isLeft, onTap: onLeft),
//           ),
//           Expanded(
//             child: _seg(label: rightLabel, active: !isLeft, onTap: onRight),
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
//             ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
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
//               "Status: $status",
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14 * s,
//                 fontWeight: FontWeight.w800,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
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
//           Row(
//             children: [
//               const Icon(Icons.assignment_outlined, color: Color(0xFF00C6FF)),
//               SizedBox(width: 10 * s),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 20 * s,
//                     fontWeight: FontWeight.w900,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//               ),
//               const Icon(Icons.chevron_right_rounded, color: Color(0xFF111827)),
//             ],
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
