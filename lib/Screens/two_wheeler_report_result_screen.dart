import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';
import 'dart:convert';
import 'dart:async';
import 'package:video_player/video_player.dart';

enum _BikeTyrePos { front, back }

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontTyreId;
  final String backTyreId;

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

  // ✅ VIDEO STATE (ad video while generating)
  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  @override
  void initState() {
    super.initState();

    // ✅ Fetch Ads (video)
    context.read<AuthBloc>().add(
      AdsFetchRequested(token: widget.token, silent: true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;
    if (widget.frontTyreId.trim().isEmpty || widget.backTyreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing tyre ids. Save preferences again.'),
        ),
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

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentVideoUrl == u && _videoCtrl != null) return;

    _currentVideoUrl = u;

    try {
      final old = _videoCtrl;

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _videoCtrl = ctrl;
      });

      await old?.dispose();
    } catch (_) {
      // fallback: keep black screen
    }
  }

  void _stopVideo() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    _currentVideoUrl = '';
    _adPlayStarted = false;
    vc?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Container(
          // ✅ Modern subtle background (no data changes)
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F8FC), Color(0xFFF3F4F7)],
            ),
          ),
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (p, c) =>
                    p.selectedAd?.media != c.selectedAd?.media ||
                    p.adsStatus != c.adsStatus ||
                    p.twoWheelerStatus != c.twoWheelerStatus,
                listener: (context, state) {
                  if (state.twoWheelerStatus == TwoWheelerStatus.success) {
                    context.read<AuthBloc>().add(
                      FetchTyreHistoryRequested(
                        userId: widget.userId,
                        vehicleId: "ALL",
                      ),
                    );
                  }
                  final isLoading =
                      state.twoWheelerStatus == TwoWheelerStatus.uploading;
                  final media = state.selectedAd?.media.trim() ?? '';

                  if (isLoading && media.isNotEmpty && !_adPlayStarted) {
                    _adPlayStarted = true;
                    _playVideo(media);
                  }
                  if (!isLoading) _stopVideo();
                },
              ),
              BlocListener<AuthBloc, AuthState>(
                listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
                listener: (context, state) {
                  if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
                      state.twoWheelerError.trim().isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.twoWheelerError)),
                    );
                  }
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (p, c) =>
                  p.twoWheelerStatus != c.twoWheelerStatus ||
                  p.twoWheelerResponse != c.twoWheelerResponse,
              builder: (context, state) {
                final loading =
                    state.twoWheelerStatus == TwoWheelerStatus.uploading;

                // ✅ SHOW FULLSCREEN VIDEO DURING LOADING
                if (loading) {
                  return Stack(
                    children: [
                      _FullscreenVideoOnly(controller: _videoCtrl),
                      Positioned(
                        left: 16 * s,
                        right: 16 * s,
                        bottom: 22 * s,
                        child: _GeneratingOverlayModern(s: s),
                      ),
                    ],
                  );
                }

                final resp = state.twoWheelerResponse;
                final data = resp?.data;
                final front = data?.front;
                final back = data?.back;
                final hasAny = (front != null) || (back != null);

                return Column(
                  children: [
                    _TopBarModern(
                      s: s,
                      title: widget.title,
                      onBack: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false,
                        );
                      },
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16 * s,
                          10 * s,
                          16 * s,
                          20 * s,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SegmentToggleModern(
                              s: s,
                              leftLabel: "Front",
                              rightLabel: "Back",
                              isLeft: _active == _BikeTyrePos.front,
                              onLeft: () =>
                                  setState(() => _active = _BikeTyrePos.front),
                              onRight: () =>
                                  setState(() => _active = _BikeTyrePos.back),
                            ),
                            SizedBox(height: 12 * s),

                            if (!loading && resp == null) ...[
                              _EmptyStateCardModern(
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

                            if (!loading && resp != null && !hasAny) ...[
                              _EmptyStateCardModern(
                                s: s,
                                title: "No data found",
                                subtitle:
                                    "Upload succeeded but front/back data is missing.",
                                onRetry: () {
                                  setState(() => _dispatched = false);
                                  _upload();
                                },
                              ),
                            ],

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
        ),
      ),
    );
  }
}

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

// ✅ Modern overlay (same text, nicer look)
class _GeneratingOverlayModern extends StatelessWidget {
  const _GeneratingOverlayModern({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.40),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// ✅ REPORT SECTION (DATA SAME)
// ===============================

class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
  });

  final double s;
  final _BikeTyrePos active;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  @override
  Widget build(BuildContext context) {
    final side = active == _BikeTyrePos.front ? front : back;

    if (side == null) {
      return _EmptyStateCardModern(
        s: s,
        title:
            "No ${active == _BikeTyrePos.front ? "front" : "back"} tyre data",
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
        _TyreImageCardModern(
          s: s,
          title: t.title,
          imageUrl: t.imageUrl,
          // ✅ optional tiny line under title
          subtitle: (t.conditionText.trim().isEmpty)
              ? null
              : t.conditionText.replaceFirst("Status:", "Status"),
        ),
        SizedBox(height: 12 * s),
        SizedBox(height: 2 * s),

        // ✅ same row, but equal height + better spacing + better alignment
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tread Depth",
                value: t.treadDepthText,
                status: t.conditionText,
                icon: Icons.straighten_rounded,
                minHeight: 190 * s, // ✅ tweak if needed
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _MetricTile(
                s: s,
                title: "Tire Pressure",
                value: t.pressureValueText,
                status: t.pressureStatusText,
                icon: Icons.speed_rounded,
                minHeight: 190 * s,
              ),
            ),
          ],
        ),

        SizedBox(height: 10 * s),
        _MetricCardModern(
          s: s,
          title: "Damage Check",
          value: t.wearPatternsText,
          status: t.damageStatusText,
          icon: Icons.report_gmailerrorred_rounded,
        ),
        SizedBox(height: 10 * s),
        _SummaryCardModern(
          s: s,
          title: "Report Summary",
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

  final String pressureValueText;
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

    final td = side.treadDepth;
    final tread = (td == null) ? '' : td.toString();

    final pressure = side.pressureAdvisory;

    final status = str(pressure?.status);
    final reason = str(pressure?.reason);
    final confidence = str(pressure?.confidence);

    final valueLines = <String>[];
    valueLines.add('Value: N/A');
    if (reason.isNotEmpty) valueLines.add('Reason: $reason');
    if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

    return _TyreUi(
      title: title,
      treadDepthText: tread.isEmpty ? "N/A" : "$tread mm",
      conditionText: str(side.condition).isEmpty
          ? ""
          : "Status: ${str(side.condition)}",
      wearPatternsText: str(side.wearPatterns).isEmpty
          ? "N/A"
          : str(side.wearPatterns),
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

// ===============================
// ✅ MODERN DESIGN TOKENS
// ===============================

class _Ui {
  static const Color ink = Color(0xFF111827);
  static const Color subInk = Color(0xFF6B7280);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE8EAF0);

  static const LinearGradient brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxShadow softShadow = BoxShadow(
    color: Colors.black.withOpacity(.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  static BoxDecoration cardDeco(double r) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: line),
    boxShadow: [softShadow],
  );
}

// ===============================
// ✅ UI WIDGETS (DESIGN UPDATED)
// ===============================

class _TopBarModern extends StatelessWidget {
  const _TopBarModern({
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
      padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 6 * s),
      child: Row(
        children: [
          _IconPill(s: s, icon: Icons.chevron_left_rounded, onTap: onBack),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 20.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 46 * s),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.s, required this.icon, required this.onTap});

  final double s;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.9),
      borderRadius: BorderRadius.circular(14 * s),
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * s),
        onTap: onTap,
        child: Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: _Ui.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 28 * s, color: _Ui.ink),
        ),
      ),
    );
  }
}

class _SegmentToggleModern extends StatelessWidget {
  const _SegmentToggleModern({
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
      height: 48 * s,
      padding: EdgeInsets.all(5 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Ui.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
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
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active ? _Ui.brandGrad : null,
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
                fontSize: 13.5 * s,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : _Ui.subInk,
                letterSpacing: .2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCardModern extends StatelessWidget {
  const _EmptyStateCardModern({
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
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: _Ui.subInk,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14 * s),
          _PrimaryButton(s: s, text: "Retry", onTap: onRetry),
        ],
      ),
    );
  }
}

class _GradDot extends StatelessWidget {
  const _GradDot({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * s,
      height: 12 * s,
      decoration: BoxDecoration(
        gradient: _Ui.brandGrad,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.s,
    required this.text,
    required this.onTap,
  });

  final double s;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          gradient: _Ui.brandGrad,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: .2,
          ),
        ),
      ),
    );
  }
}

class _TyreImageCardModern extends StatelessWidget {
  const _TyreImageCardModern({
    required this.s,
    required this.title,
    required this.imageUrl,
    this.subtitle,
  });

  final double s;
  final String title;
  final String imageUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final img = _imageWidget(imageUrl);

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Title with gradient text feel (same data)
          Row(
            children: [
              _GradDot(s: s),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * s,
                  vertical: 6 * s,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: _Ui.line),
                ),
                child: Text(
                  "Tyre",
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w800,
                    color: _Ui.subInk,
                  ),
                ),
              ),
            ],
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 8 * s),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w700,
                color: _Ui.subInk,
              ),
            ),
          ],
          SizedBox(height: 12 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(16 * s),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img,
                  // ✅ soft overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.05),
                            Colors.black.withOpacity(.22),
                          ],
                        ),
                      ),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    this.minHeight = 190,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value.trim();
    final st = status.trim();

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ critical in scroll views
        children: [
          Row(
            children: [
              Container(
                width: 36 * s,
                height: 36 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(icon, size: 18 * s, color: Colors.white),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * s),

          // ✅ no Expanded here (prevents infinite height crash)
          Text(
            v,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.2 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),

          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCardModern extends StatelessWidget {
  const _MetricCardModern({
    required this.s,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  final double s;
  final String title;
  final String value;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "N/A" : value;
    final st = status.trim();

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            children: [
              Container(
                width: 34 * s,
                height: 34 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(icon, size: 18 * s, color: Colors.white),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14.5 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),

          Text(
            v,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.35,
            ),
          ),

          if (st.isNotEmpty) ...[
            SizedBox(height: 10 * s),
            _StatusPill(
              s: s,
              text: st.startsWith("Status:") ? st : "Status: $st",
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.s, required this.text});
  final double s;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: _Ui.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8 * s,
            height: 8 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Ui.brandGrad,
            ),
          ),
          SizedBox(width: 8 * s),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w800,
                color: _Ui.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardModern extends StatelessWidget {
  const _SummaryCardModern({
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
      decoration: _Ui.cardDeco(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34 * s,
                height: 34 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 * s),
                  gradient: _Ui.brandGrad,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 18 * s,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w900,
                    color: _Ui.ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _Ui.subInk,
                size: 22 * s,
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            summary.trim().isEmpty ? "N/A" : summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13.5 * s,
              fontWeight: FontWeight.w700,
              color: _Ui.ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

















/*
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
  

  // ✅ VIDEO STATE (ad video while generating)
  VideoPlayerController? _videoCtrl;
  String _currentVideoUrl = '';
  bool _adPlayStarted = false;

  @override
  void initState() {
    super.initState();

    // ✅ Fetch Ads (video)
    context.read<AuthBloc>().add(
          AdsFetchRequested(token: widget.token, silent: true),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  void dispose() {
    _stopVideo();
    super.dispose();
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

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentVideoUrl == u && _videoCtrl != null) return;

    _currentVideoUrl = u;

    try {
      final old = _videoCtrl;

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _videoCtrl = ctrl;
      });

      await old?.dispose();
    } catch (_) {
      // fallback: keep black screen
    }
  }

  void _stopVideo() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    _currentVideoUrl = '';
    _adPlayStarted = false;
    vc?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            // ✅ Start playing ad when selectedAd changes OR ads loaded
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (p, c) =>
                  p.selectedAd?.media != c.selectedAd?.media ||
                  p.adsStatus != c.adsStatus ||
                  p.twoWheelerStatus != c.twoWheelerStatus,
              listener: (context, state) {
                final isLoading =
                    state.twoWheelerStatus == TwoWheelerStatus.uploading;
                final media = state.selectedAd?.media?.trim() ?? '';

                if (isLoading && media.isNotEmpty && !_adPlayStarted) {
                  _adPlayStarted = true;
                  _playVideo(media);
                }

                // Stop video when not loading
                if (!isLoading) {
                  _stopVideo();
                }
              },
            ),

            // ✅ Show failure message
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
              listener: (context, state) {
                if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
                    state.twoWheelerError.trim().isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.twoWheelerError)),
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (p, c) =>
                p.twoWheelerStatus != c.twoWheelerStatus ||
                p.twoWheelerResponse != c.twoWheelerResponse,
            builder: (context, state) {
              final loading =
                  state.twoWheelerStatus == TwoWheelerStatus.uploading;

              // ✅ SHOW FULLSCREEN VIDEO DURING LOADING
              if (loading) {
                return Stack(
                  children: [
                    _FullscreenVideoOnly(controller: _videoCtrl),
                    // Positioned(
                    //   left: 16 * s,
                    //   right: 16 * s,
                    //   bottom: 26 * s,
                    //   child: _GeneratingOverlay(s: s),
                    // ),
                  ],
                );
              }

              // ✅ Once not loading, show report UI
              final resp = state.twoWheelerResponse; // TwoWheelerTyreUploadResponse?
              final data = resp?.data; // has record_id, front, back

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
                        MaterialPageRoute(builder: (_) => const AppShell()),
                        (route) => false,
                      );
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SegmentToggle(
                            s: s,
                            leftLabel: "Front",
                            rightLabel: "Back",
                            isLeft: _active == _BikeTyrePos.front,
                            onLeft: () => setState(() => _active = _BikeTyrePos.front),
                            onRight: () => setState(() => _active = _BikeTyrePos.back),
                          ),
                          SizedBox(height: 12 * s),

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
      ),
    );
  }
}

// ===============================
// ✅ FULLSCREEN VIDEO WIDGET
// ===============================

class _FullscreenVideoOnly extends StatelessWidget {
  const _FullscreenVideoOnly({required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(16 * s),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              "Generating report… Please wait",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// ✅ REPORT SECTION (UNCHANGED UI)
// ===============================

class _TyreReportSection extends StatelessWidget {
  const _TyreReportSection({
    required this.s,
    required this.active,
    required this.front,
    required this.back,
  });

  final double s;
  final _BikeTyrePos active;
  final TwoWheelerTyreSide? front;
  final TwoWheelerTyreSide? back;

  @override
  Widget build(BuildContext context) {
    final side = active == _BikeTyrePos.front ? front : back;

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
                status: t.conditionText,
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

  final String pressureValueText;
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

    final td = side.treadDepth;
    final tread = (td == null) ? '' : td.toString();

    final pressure = side.pressureAdvisory;

    final status = str(pressure?.status);
    final reason = str(pressure?.reason);
    final confidence = str(pressure?.confidence);

    final valueLines = <String>[];
    valueLines.add('Value: N/A');
    if (reason.isNotEmpty) valueLines.add('Reason: $reason');
    if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

    return _TyreUi(
      title: title,
      treadDepthText: tread.isEmpty ? "N/A" : "$tread mm",
      conditionText:
          str(side.condition).isEmpty ? "" : "Status: ${str(side.condition)}",
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

// ===============================
// ✅ UI WIDGETS (SAME AS YOURS)
// ===============================

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
            ),
          ),
          const SizedBox(width: 48),
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
          Expanded(child: _seg(label: leftLabel, active: isLeft, onTap: onLeft)),
          Expanded(
              child: _seg(label: rightLabel, active: !isLeft, onTap: onRight)),
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
            ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
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
*/






































































































// enum _BikeTyrePos { front, back }

// class TwoWheelerReportResultScreen extends StatefulWidget {
//   final String title;
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
//     this.title = "Inspection Report",
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

// class _TwoWheelerReportResultScreenState
//     extends State<TwoWheelerReportResultScreen> {
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
//             final loading =
//                 state.twoWheelerStatus == TwoWheelerStatus.uploading;

//             final resp = state.twoWheelerResponse; // TwoWheelerTyreUploadResponse?
//             final data = resp?.data; // ✅ NEW: OBJECT (record_id, front, back)

//             // ✅ front/back objects from NEW response
//             final front = data?.front;
//             final back = data?.back;

//             final hasAny = (front != null) || (back != null);

//             return Column(
//               children: [
//                 _TopBar(
//                   s: s,
//                   title: widget.title,
//                   onBack: () {
//      Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(
//           builder: (_) =>  AppShell() 
              
//         ),
//         (route) => false,
//       );

//                   //  Navigator.of(context).pop();
//                   //  Navigator.of(context).pop();
//                   //   Navigator.of(context).pop();
//                   }
//                 ),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // _HeaderCard(
//                         //   s: s,
//                         //   title: "Tyre Inspection Report",
//                         //   subtitle: "Bike • Front + Back",
//                         // ),
//                         //SizedBox(height: 5 * s),

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

//                         // ✅ If API not returned anything yet
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

//                         // ✅ If response exists but data missing
//                         if (!loading && resp != null && !hasAny) ...[
//                           _EmptyStateCard(
//                             s: s,
//                             title: "No data found",
//                             subtitle: "Upload succeeded but front/back data is missing.",
//                             onRetry: () {
//                               setState(() => _dispatched = false);
//                               _upload();
//                             },
//                           ),
//                         ],

//                         // ✅ Show report
//                         if (hasAny) ...[
//                           _TyreReportSection(
//                             s: s,
//                             active: _active,
//                             front: front,
//                             back: back,
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
//     required this.front,
//     required this.back,
//   });

//   final double s;
//   final _BikeTyrePos active;

//   // ✅ These types come from your NEW model:
//   // data.front, data.back
//   final TwoWheelerTyreSide? front;
//   final TwoWheelerTyreSide? back;

//   @override
//   Widget build(BuildContext context) {
//     final side = active == _BikeTyrePos.front ? front : back;

//     // If selected side is null, show friendly empty
//     if (side == null) {
//       return _EmptyStateCard(
//         s: s,
//         title: "No ${active == _BikeTyrePos.front ? "front" : "back"} tyre data",
//         subtitle: "Try scanning again.",
//         onRetry: () => Navigator.of(context).pop(),
//       );
//     }

//     final t = _TyreUi.fromSide(
//       title: active == _BikeTyrePos.front ? "Front" : "Back",
//       side: side,
//     );

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
//                 value: t.treadDepthText,
//                 status: t.conditionText, // ✅ show condition here
//               ),
//             ),
//             SizedBox(width: 10 * s),
//             Expanded(
//               child: _SmallMetricCard(
//                 s: s,
//                 title: "Tire Pressure",
//                 value: t.pressureValueText,
//                 status: t.pressureStatusText,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 10 * s),

//         _SmallMetricCard(
//           s: s,
//           title: "Damage Check",
//           value: t.wearPatternsText,
//           status: t.damageStatusText,
//         ),
//         SizedBox(height: 10 * s),

//         _SummaryCard(
//           s: s,
//           title: "Report Summary:",
//           summary: t.summaryText,
//         ),
//       ],
//     );
//   }
// }

// class _TyreUi {
//   final String title;

//   final String treadDepthText;
//   final String conditionText;

//   final String wearPatternsText;
//   final String damageStatusText;

//   final String summaryText;

//   final String imageUrl;

//   final String pressureValueText; // API doesn't return numeric PSI -> "N/A" unless you add later
//   final String pressureStatusText;
//   final String pressureReasonText;
//   final String pressureConfidenceText;

//   const _TyreUi({
//     required this.title,
//     required this.treadDepthText,
//     required this.conditionText,
//     required this.wearPatternsText,
//     required this.damageStatusText,
//     required this.summaryText,
//     required this.imageUrl,
//     required this.pressureValueText,
//     required this.pressureStatusText,
//     required this.pressureReasonText,
//     required this.pressureConfidenceText,
//   });

//   factory _TyreUi.fromSide({
//     required String title,
//     required TwoWheelerTyreSide side,
//   }) {
//     String str(dynamic v) {
//       if (v == null) return '';
//       final s = v.toString().trim();
//       if (s.toLowerCase() == 'null') return '';
//       return s;
//     }

//     // tread depth is double in API
//     final td = side.treadDepth;
//     final tread = (td == null) ? '' : td.toString();

//     final pressure = side.pressureAdvisory;

//     final status = str(pressure?.status);
//     final reason = str(pressure?.reason);
//     final confidence = str(pressure?.confidence);

//     // ✅ "Tire Pressure" card shows ALL details in a nice format:
//     // Value: N/A (no PSI)
//     // Status: Possible Under-Inflation
//     // (reason/confidence appended to value so user sees everything)
//     final valueLines = <String>[];
//     valueLines.add('Value: N/A');
//     if (reason.isNotEmpty) valueLines.add('Reason: $reason');
//     if (confidence.isNotEmpty) valueLines.add('Confidence: $confidence');

//     return _TyreUi(
//       title: title,
//       treadDepthText: tread.isEmpty ? "N/A" : "$tread mm",
//       conditionText: str(side.condition).isEmpty ? "" : "Status: ${str(side.condition)}",
//       wearPatternsText: str(side.wearPatterns).isEmpty ? "N/A" : str(side.wearPatterns),
//       damageStatusText: str(side.condition).isEmpty ? "" : str(side.condition),
//       summaryText: str(side.summary).isEmpty ? "N/A" : str(side.summary),
//       imageUrl: str(side.imageUrl),
//       pressureValueText: valueLines.join('\n'),
//       pressureStatusText: status.isEmpty ? "" : status,
//       pressureReasonText: reason,
//       pressureConfidenceText: confidence,
//     );
//   }
// }

// /* ============================ UI WIDGETS (unchanged) ============================ */

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
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 20 * s,
//                           fontWeight: FontWeight.w900,
//                       color: const Color(0xFF111827),
//                         ),
//               // style: TextStyle(
//               //   fontFamily: 'ClashGrotesk',
//               //   fontSize: 18 * s,
//               //   fontWeight: FontWeight.w900,
//               //   color: const Color(0xFF111827),
//               // ),
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
//             value.trim().isEmpty ? "N/A" : value,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//               height: 1.35,
//             ),
//           ),
//           if (status.trim().isNotEmpty) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               status.startsWith("Status:") ? status : "Status: $status",
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
//             summary.trim().isEmpty ? "N/A" : summary,
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
