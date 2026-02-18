import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart'; // <-- your model file

enum _BikeTyrePos { front, back }

class TwoWheelerGenerateReportScreen extends StatefulWidget {
  final String title;

  // required for upload
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType; // "bike"

  // images
  final String frontPath;
  final String backPath;

  const TwoWheelerGenerateReportScreen({
    super.key,
    this.title = "Bike Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontPath,
    required this.backPath,
  });

  @override
  State<TwoWheelerGenerateReportScreen> createState() =>
      _TwoWheelerGenerateReportScreenState();
}

class _TwoWheelerGenerateReportScreenState
    extends State<TwoWheelerGenerateReportScreen> {
  bool _dispatched = false;
  _BikeTyrePos _active = _BikeTyrePos.front;

  @override
  void initState() {
    super.initState();
    // Dispatch after first frame to avoid context issues
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
                (state.twoWheelerError).trim().isNotEmpty) {
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
            final resp = state.twoWheelerResponse;

            return Column(
              children: [
                _TopBar(
                  s: s,
                  title: widget.title,
                  onBack: () => Navigator.of(context).pop(),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderCard(
                          s: s,
                          title: "Tyre Inspection Report",
                          subtitle: "Bike • Front + Back",
                        ),
                        SizedBox(height: 12 * s),

                        // Toggle front/back once data available (or even before)
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

                        if (!loading && resp == null) ...[
                          _EmptyStateCard(
                            s: s,
                            title: "No report yet",
                            subtitle:
                                "Tap retry to generate the bike report again.",
                            onRetry: () {
                              setState(() => _dispatched = false);
                              _upload();
                            },
                          ),
                        ],

                        if (resp != null) ...[
                          _TyreReportSection(
                            s: s,
                            active: _active,
                            resp: resp,
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
    required this.resp,
  });

  final double s;
  final _BikeTyrePos active;
  final TwoWheelerTyreUploadResponse resp;

  @override
  Widget build(BuildContext context) {
    final t = _uiFor(active, resp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Preview (base64 or url)
        _TyreImageCard(s: s, title: t.title, imageUrl: t.imageUrl),
        SizedBox(height: 12 * s),

        // Condition / Tread / Wear
        Row(
          children: [
            Expanded(
              child: _SmallMetricCard(
                s: s,
                title: "Condition",
                value: t.condition.trim().isEmpty ? "—" : t.condition,
                status: "",
              ),
            ),
            SizedBox(width: 10 * s),
            Expanded(
              child: _SmallMetricCard(
                s: s,
                title: "Tread Depth",
                value: t.treadDepth <= 0 ? "—" : "${t.treadDepth.toStringAsFixed(2)} mm",
                status: "",
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),

        _SmallMetricCard(
          s: s,
          title: "Wear Patterns",
          value: t.wearPatterns.trim().isEmpty ? "—" : t.wearPatterns,
          status: "",
        ),
        SizedBox(height: 10 * s),

        // ✅ NEW CARD: Tire Pressure (full details)
        _TyrePressureCard(
          s: s,
          title: "Tire Pressure",
          composed: _composeSelectedSummary(t),
        ),
        SizedBox(height: 10 * s),

        // Summary
        _SummaryCard(
          s: s,
          title: "Summary",
          summary: t.summary.trim().isEmpty ? "—" : t.summary.trim(),
        ),
      ],
    );
  }

  _TyreUi _uiFor(_BikeTyrePos pos, TwoWheelerTyreUploadResponse resp) {
    final data = resp.data;
    final tyre = pos == _BikeTyrePos.front ? data.front : data.back;

    return _TyreUi(
      title: pos == _BikeTyrePos.front ? "Front Tyre" : "Back Tyre",
      condition: tyre.condition,
      treadDepth: tyre.treadDepth,
      wearPatterns: tyre.wearPatterns,
      summary: tyre.summary,
      imageUrl: tyre.imageUrl,
      pressureStatus: tyre.pressureAdvisory.status,
      pressureReason: tyre.pressureAdvisory.reason,
      pressureConfidence: tyre.pressureAdvisory.confidence,
      pressureValue: "—", // backend doesn’t provide numeric PSI in your model
    );
  }

  // ✅ You asked to show this logic in Tire Pressure card
  String _composeSelectedSummary(_TyreUi t) {
    final parts = <String>[];

    if (t.summary.trim().isNotEmpty && t.summary != '—') {
      parts.add(t.summary.trim());
    }

    if (t.pressureStatus != '—' ||
        t.pressureReason.trim().isNotEmpty ||
        t.pressureConfidence.trim().isNotEmpty) {
      parts.add([
        'Tire pressure:',
        '• Status: ${t.pressureStatus.trim().isEmpty ? "—" : t.pressureStatus}',
        if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
        if (t.pressureConfidence.trim().isNotEmpty)
          '• Confidence: ${t.pressureConfidence}',
      ].join('\n'));
    }

    return parts.isEmpty ? '—' : parts.join('\n\n');
  }
}

class _TyreUi {
  final String title;

  final String condition;
  final double treadDepth;
  final String wearPatterns;
  final String summary;
  final String imageUrl;

  final String pressureValue;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;

  const _TyreUi({
    required this.title,
    required this.condition,
    required this.treadDepth,
    required this.wearPatterns,
    required this.summary,
    required this.imageUrl,
    required this.pressureValue,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
  });
}

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
            child: _seg(
              label: leftLabel,
              active: isLeft,
              onTap: onLeft,
            ),
          ),
          Expanded(
            child: _seg(
              label: rightLabel,
              active: !isLeft,
              onTap: onRight,
            ),
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

    // base64 data url
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

    // normal URL
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

// ✅ keep your existing card as-is (used above)
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
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          if (status.trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              status,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16 * s,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ✅ NEW CARD (your request): Tire Pressure full data in ONE card
/// (No change to other classes)
class _TyrePressureCard extends StatelessWidget {
  const _TyrePressureCard({
    required this.s,
    required this.title,
    required this.composed,
  });

  final double s;
  final String title;
  final String composed;

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
            composed.trim().isEmpty ? "—" : composed,
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
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 20 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF00C6FF),
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            summary,
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
