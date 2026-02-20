import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart' show AppShell;
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart' as fw;


class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.vehicleId,
    required this.userId,
    required this.token,
    this.response,
    this.fourWheelerRaw,
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String vehicleId;
  final String userId;
  final String token;

  final dynamic response; // can be fw.ResponseFourWheeler OR Map OR json string
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  static const _bg = Color(0xFFF2F2F2);

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  int _selected = 0;

  @override
  void initState() {
    super.initState();

    // Keeping your existing behavior
    try {
      final userid = context.read<AuthBloc>().state.profile?.userId.toString();
      if (userid != null && userid.isNotEmpty) {
        context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    // ✅ Parse response into STRONGLY-TYPED model (fixes pressure showing "—")
    final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
    final d = parsed?.data;

    // ✅ chip order: Front Left, Front Right, Back Left, Back Right
    final tyreByChipIndex = <int, _TyreUi>{
      0: _tyreUiFromModel(
        label: 'Front Left',
        treadDepth: d?.frontLeftTreadDepth,
        tyreStatus: d?.frontLeftTyreStatus,
        damageValue: d?.frontLeftWearPatterns,
        summary: d?.frontLeftSummary,
        tp: d?.frontLeftTirePressure,
      ),
      1: _tyreUiFromModel(
        label: 'Front Right',
        treadDepth: d?.frontRightTreadDepth,
        tyreStatus: d?.frontRightTyreStatus,
        damageValue: d?.frontRightWearPatterns,
        summary: d?.frontRightSummary,
        tp: d?.frontRightTirePressure,
      ),
      2: _tyreUiFromModel(
        label: 'Back Left',
        treadDepth: d?.backLeftTreadDepth,
        tyreStatus: d?.backLeftTyreStatus,
        damageValue: d?.backLeftWearPatterns,
        summary: d?.backLeftSummary,
        tp: d?.backLeftTirePressure,
      ),
      3: _tyreUiFromModel(
        label: 'Back Right',
        treadDepth: d?.backRightTreadDepth,
        tyreStatus: d?.backRightTyreStatus,
        damageValue: d?.backRightWearPatterns,
        summary: d?.backRightSummary,
        tp: d?.backRightTirePressure,
      ),
    };

    final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

    // ✅ Images: your API returns filenames, so we keep local fallback
    final flImg =
        _imgProvider(localPath: widget.frontLeftPath, apiValue: d?.frontLeftWheel);
    final frImg =
        _imgProvider(localPath: widget.frontRightPath, apiValue: d?.frontRightWheel);
    final blImg =
        _imgProvider(localPath: widget.backLeftPath, apiValue: d?.backLeftWheel);
    final brImg =
        _imgProvider(localPath: widget.backRightPath, apiValue: d?.backRightWheel);

    final wheelImages = <_WheelCardData>[
      _WheelCardData(image: flImg, label: 'Front Left'),
      _WheelCardData(image: frImg, label: 'Front Right'),
      _WheelCardData(image: blImg, label: 'Back Left'),
      _WheelCardData(image: brImg, label: 'Back Right'),
    ];

    final summaryText = _composeSelectedSummary(selectedTyre);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => AppShell()),
              (route) => false,
            );
          },
        ),
        centerTitle: true,
        title: Text(
          'Inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
          child: Column(
            children: [
              SizedBox(
                height: 190 * s,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wheelImages.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12 * s),
                  itemBuilder: (_, i) {
                    final item = wheelImages[i];
                    return _WheelImageCard(
                      s: s,
                      image: item.image,
                      label: item.label,
                      gradient: _brandGrad,
                    );
                  },
                ),
              ),

              SizedBox(height: 10 * s),

              _TyreChips(
                s: s,
                labels: const ['Front Left', 'Front Right', 'Back Left', 'Back Right'],
                selected: _selected,
                gradient: _brandGrad,
                onSelect: (i) => setState(() => _selected = i),
              ),

              SizedBox(height: 12 * s),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ✅ FIX: No stretch (infinite height inside ListView)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BigTreadCard(
                            s: s,
                            gradient: _brandGrad,
                            treadValue: selectedTyre.treadDepth,
                            treadStatus: selectedTyre.tyreStatus,
                            reason: '',
                            confidence: '',
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // ✅ important in scroll
                            children: [
                              _SmallMetricCardPressure(
                                gradient: _brandGrad,
                                s: s,
                                title: 'Tire Pressure',
                                status: 'Status: ${selectedTyre.pressureStatus}',
                                reason: selectedTyre.pressureReason.trim().isEmpty
                                    ? ''
                                    : 'Reason: ${selectedTyre.pressureReason}',
                                confidence: selectedTyre.pressureConfidence.trim().isEmpty
                                    ? ''
                                    : 'Confidence: ${selectedTyre.pressureConfidence}',
                              ),
                              SizedBox(height: 12 * s),
                              _SmallMetricCard(
                                s: s,
                                gradient: _brandGrad,
                                title: 'Damage Check',
                                value: 'Value: ${selectedTyre.damageValue}',
                                status: 'Status: ${selectedTyre.damageStatus}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16 * s),

                    _ReportSummaryCard(
                      s: s,
                      gradient: _brandGrad,
                      tyre: selectedTyre,
                      summary: summaryText,
                    ),

                    SizedBox(height: 6 * s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // ✅ Convert model to UI holder
  // -----------------------------
  _TyreUi _tyreUiFromModel({
    required String label,
    required String? treadDepth,
    required String? tyreStatus,
    required String? damageValue,
    required String? summary,
    required fw.TirePressure? tp,
  }) {
    final status = (tyreStatus ?? '').trim().isEmpty ? '—' : tyreStatus!.trim();
    final pressureStatus = (tp?.status ?? '').trim().isEmpty ? '—' : tp!.status.trim();

    // API has no psi/value -> show status as "Value"
    final pressureValue = pressureStatus;

    return _TyreUi(
      label: label,
      treadDepth: (treadDepth ?? '').trim().isEmpty ? '—' : treadDepth!.trim(),
      tyreStatus: status,
      damageValue: (damageValue ?? '').trim().isEmpty ? '—' : damageValue!.trim(),
      damageStatus: status,
      pressureValue: pressureValue,
      pressureStatus: pressureStatus,
      pressureReason: (tp?.reason ?? '').trim(),
      pressureConfidence: (tp?.confidence ?? '').trim(),
      summary: (summary ?? '').trim().isEmpty ? '—' : summary!.trim(),
    );
  }

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
        '• Status: ${t.pressureStatus}',
        if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
        if (t.pressureConfidence.trim().isNotEmpty)
          '• Confidence: ${t.pressureConfidence}',
      ].join('\n'));
    }

    return parts.isEmpty ? '—' : parts.join('\n\n');
  }

  // -----------------------------
  // ✅ Parse response safely
  // -----------------------------
  fw.ResponseFourWheeler? _parseFourWheeler(
    Map<String, dynamic>? rawOverride,
    dynamic response,
  ) {
    try {
      if (response is fw.ResponseFourWheeler) return response;

      final raw = rawOverride ?? _safeToJson(response);
      if (raw == null) return null;

      // Sometimes you may pass only {"data":{...}} without "message"
      if (raw.containsKey('data') && !raw.containsKey('message')) {
        return fw.ResponseFourWheeler.fromJson({'data': raw['data'], 'message': ''});
      }

      return fw.ResponseFourWheeler.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
    final apiStr = _asNonEmptyString(apiValue);

    if (apiStr != null) {
      if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
        return NetworkImage(apiStr);
      }
      if (apiStr.startsWith('data:image')) {
        try {
          final base64Part = apiStr.split(',').last;
          final bytes = base64Decode(base64Part);
          return MemoryImage(bytes);
        } catch (_) {}
      }
    }

    // API returns filenames -> keep local fallback
    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;

    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);

    if (obj is String) {
      try {
        final decoded = jsonDecode(obj);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    try {
      final j = (obj as dynamic).toJson();
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}

    try {
      final encoded = jsonEncode(obj);
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return null;
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
}

// =============================
// UI WIDGETS
// =============================

class _WheelCardData {
  const _WheelCardData({required this.image, required this.label});
  final ImageProvider image;
  final String label;
}

class _WheelImageCard extends StatelessWidget {
  const _WheelImageCard({
    required this.s,
    required this.image,
    required this.label,
    required this.gradient,
  });

  final double s;
  final ImageProvider image;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120 * s,
      child: Column(
        children: [
          Container(
            height: 140 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * s),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18 * s),
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 10 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8 * s),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10 * s),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 14 * s,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreChips extends StatelessWidget {
  const _TyreChips({
    super.key,
    required this.s,
    required this.labels,
    required this.selected,
    required this.gradient,
    required this.onSelect,
  });

  final double s;
  final List<String> labels;
  final int selected;
  final LinearGradient gradient;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isSel = i == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(12 * s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10 * s),
                decoration: BoxDecoration(
                  gradient: isSel ? gradient : null,
                  color: isSel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSel ? .10 : .05),
                      blurRadius: isSel ? 16 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.5 * s,
                      fontWeight: FontWeight.w900,
                      color: isSel ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BigTreadCard extends StatelessWidget {
  const _BigTreadCard({
    required this.s,
    required this.gradient,
    required this.treadValue,
    required this.treadStatus,
    required this.reason,
    required this.confidence,
  });

  final double s;
  final LinearGradient gradient;
  final String treadValue;
  final String treadStatus;
  final String reason;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset(
                  "assets/thread_depth.png",
                  height: 26 * s,
                  width: 26 * s,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 3 * s),
              Text(
                'Thread Depth',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 19 * s,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..shader =
                        gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            'Value: $treadValue',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            'Status: $treadStatus',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallMetricCardPressure extends StatelessWidget {
  const _SmallMetricCardPressure({
    required this.s,
    required this.title,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.gradient,
  });

  final double s;
  final String title;
  final String status;
  final String reason;
  final String confidence;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

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
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
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
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
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
  final LinearGradient gradient;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
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
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.s,
    required this.gradient,
    required this.tyre,
    required this.summary,
  });

  final double s;
  final LinearGradient gradient;
  final _TyreUi tyre;
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
            color: Colors.black.withOpacity(.10),
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
              Container(
                width: 46 * s,
                height: 46 * s,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                child: Icon(Icons.description_outlined, color: Colors.white, size: 24 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  'Report Summary',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 22 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreUi {
  _TyreUi({
    required this.label,
    required this.treadDepth,
    required this.tyreStatus,
    required this.damageValue,
    required this.damageStatus,
    required this.pressureValue,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
  });

  final String label;
  final String treadDepth;
  final String tyreStatus;

  final String damageValue;
  final String damageStatus;

  final String pressureValue;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;

  final String summary;
}

// ======================================================
// ✅ GenerateReportScreen (fixed: backRightTyreId + same file)
// ======================================================

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = 'car',
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String userId;
  final String vehicleId;
  final String token;

  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String vehicleType;

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  bool _fired = false;
  bool _navigated = false;

  fw.ResponseFourWheeler? _apiResponse;

  VideoPlayerController? _videoCtrl;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
    _startUpload();
  }

  void _startUpload() {
    if (_fired) return;
    _fired = true;

    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,
        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backRightTyreId, // ✅ FIXED
        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
      ),
    );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentUrl == u && _videoCtrl != null) return;

    _currentUrl = u;

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

      setState(() => _videoCtrl = ctrl);
      await old?.dispose();
    } catch (_) {}
  }

  void _navigateToResult() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          frontLeftPath: widget.frontLeftPath,
          frontRightPath: widget.frontRightPath,
          backLeftPath: widget.backLeftPath,
          backRightPath: widget.backRightPath,
          vehicleId: widget.vehicleId,
          userId: widget.userId,
          token: widget.token,
          response: _apiResponse,
        ),
      ),
    );
  }

  @override
  void dispose() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media || p.adsStatus != c.adsStatus,
            listener: (context, state) {
              final media = state.selectedAd?.media ?? '';
              if (media.trim().isNotEmpty) {
                _playVideo(media);
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
                _navigateToResult();
              }
            },
          ),
        ],
        child: _FullscreenVideoOnly(controller: _videoCtrl),
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
/*
class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.vehicleId,
    required this.userId,
    required this.token,
    this.response,
    this.fourWheelerRaw,
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String vehicleId;
  final String userId;
  final String token;

  final dynamic response; // can be fw.ResponseFourWheeler OR Map OR json string
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  static const _bg = Color(0xFFF2F2F2);

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  int _selected = 0;

  @override
  void initState() {
    super.initState();

    try {
      final userid = context.read<AuthBloc>().state.profile?.userId.toString();
      if (userid != null && userid.isNotEmpty) {
        context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    // ✅ Parse response into STRONGLY-TYPED model (fixes pressure showing "—")
    final parsed = _parseFourWheeler(widget.fourWheelerRaw, widget.response);
    final d = parsed?.data;

    // ✅ chip order: Front Left, Front Right, Back Left, Back Right
    final tyreByChipIndex = <int, _TyreUi>{
      0: _tyreUiFromModel(
        label: 'Front Left',
        treadDepth: d?.frontLeftTreadDepth,
        tyreStatus: d?.frontLeftTyreStatus,
        damageValue: d?.frontLeftWearPatterns,
        summary: d?.frontLeftSummary,
        tp: d?.frontLeftTirePressure,
      ),
      1: _tyreUiFromModel(
        label: 'Front Right',
        treadDepth: d?.frontRightTreadDepth,
        tyreStatus: d?.frontRightTyreStatus,
        damageValue: d?.frontRightWearPatterns,
        summary: d?.frontRightSummary,
        tp: d?.frontRightTirePressure,
      ),
      2: _tyreUiFromModel(
        label: 'Back Left',
        treadDepth: d?.backLeftTreadDepth,
        tyreStatus: d?.backLeftTyreStatus,
        damageValue: d?.backLeftWearPatterns,
        summary: d?.backLeftSummary,
        tp: d?.backLeftTirePressure,
      ),
      3: _tyreUiFromModel(
        label: 'Back Right',
        treadDepth: d?.backRightTreadDepth,
        tyreStatus: d?.backRightTyreStatus,
        damageValue: d?.backRightWearPatterns,
        summary: d?.backRightSummary,
        tp: d?.backRightTirePressure,
      ),
    };

    final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

    // ✅ Images: your API returns filenames, so we keep local fallback
    final flImg =
        _imgProvider(localPath: widget.frontLeftPath, apiValue: d?.frontLeftWheel);
    final frImg =
        _imgProvider(localPath: widget.frontRightPath, apiValue: d?.frontRightWheel);
    final blImg =
        _imgProvider(localPath: widget.backLeftPath, apiValue: d?.backLeftWheel);
    final brImg =
        _imgProvider(localPath: widget.backRightPath, apiValue: d?.backRightWheel);

    final wheelImages = <_WheelCardData>[
      _WheelCardData(image: flImg, label: 'Front Left'),
      _WheelCardData(image: frImg, label: 'Front Right'),
      _WheelCardData(image: blImg, label: 'Back Left'),
      _WheelCardData(image: brImg, label: 'Back Right'),
    ];

    final summaryText = _composeSelectedSummary(selectedTyre);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22,
            color: Colors.black,
          ),
          onPressed: () {
            // Keeping your behavior (no text/data change).
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => AppShell()),
              (route) => false,
            );
          },
        ),
        centerTitle: true,
        title: Text(
          'Inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 20 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
          child: Column(
            children: [
              SizedBox(
                height: 190 * s,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wheelImages.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12 * s),
                  itemBuilder: (_, i) {
                    final item = wheelImages[i];
                    return _WheelImageCard(
                      s: s,
                      image: item.image,
                      label: item.label,
                      gradient: _brandGrad,
                    );
                  },
                ),
              ),

              SizedBox(height: 10 * s), // ✅ slightly tighter

              _TyreChips(
                s: s,
                labels: const ['Front Left', 'Front Right', 'Back Left', 'Back Right'],
                selected: _selected,
                gradient: _brandGrad,
                onSelect: (i) => setState(() => _selected = i),
              ),

              SizedBox(height: 12 * s), 

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      _BigTreadCard(
                            s: s,
                            gradient: _brandGrad,
                            treadValue: selectedTyre.treadDepth,
                            treadStatus: selectedTyre.tyreStatus,
                            reason: '',
                            confidence: '',
                          ),
                        
                        SizedBox(width: 12 * s),
                        Column(
                            children: [
                              _SmallMetricCardPressure(
                                gradient: _brandGrad,
                                s: s,
                                title: 'Tire Pressure',
                                status: 'Status: ${selectedTyre.pressureStatus}',
                                reason: selectedTyre.pressureReason.trim().isEmpty
                                    ? ''
                                    : 'Reason: ${selectedTyre.pressureReason}',
                                confidence: selectedTyre.pressureConfidence.trim().isEmpty
                                    ? ''
                                    : 'Confidence: ${selectedTyre.pressureConfidence}',
                              ),
                              SizedBox(height: 12 * s),

                            _SmallMetricCard(
                                  s: s,
                                  gradient: _brandGrad,
                                  title: 'Damage Check',
                                  value: 'Value: ${selectedTyre.damageValue}',
                                  status: 'Status: ${selectedTyre.damageStatus}',
                                ),
                              
                            ],
                          ),
                        
                      ],
                    ),

                    SizedBox(height: 16 * s),

                    _ReportSummaryCard(
                      s: s,
                      gradient: _brandGrad,
                      tyre: selectedTyre,
                      summary: summaryText,
                    ),

                    SizedBox(height: 6 * s), // ✅ tighter bottom
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // ✅ Convert model to UI holder
  // -----------------------------
  _TyreUi _tyreUiFromModel({
    required String label,
    required String? treadDepth,
    required String? tyreStatus,
    required String? damageValue,
    required String? summary,
    required fw.TirePressure? tp,
  }) {
    final status = (tyreStatus ?? '').trim().isEmpty ? '—' : tyreStatus!.trim();

    final pressureStatus = (tp?.status ?? '').trim().isEmpty ? '—' : tp!.status.trim();

    // API has no psi/value -> show status as "Value"
    final pressureValue = pressureStatus;

    return _TyreUi(
      label: label,
      treadDepth: (treadDepth ?? '').trim().isEmpty ? '—' : treadDepth!.trim(),
      tyreStatus: status,
      damageValue: (damageValue ?? '').trim().isEmpty ? '—' : damageValue!.trim(),
      damageStatus: status,
      pressureValue: pressureValue,
      pressureStatus: pressureStatus,
      pressureReason: (tp?.reason ?? '').trim(),
      pressureConfidence: (tp?.confidence ?? '').trim(),
      summary: (summary ?? '').trim().isEmpty ? '—' : summary!.trim(),
    );
  }

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
        '• Status: ${t.pressureStatus}',
        if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
        if (t.pressureConfidence.trim().isNotEmpty)
          '• Confidence: ${t.pressureConfidence}',
      ].join('\n'));
    }

    return parts.isEmpty ? '—' : parts.join('\n\n');
  }

  // -----------------------------
  // ✅ Parse response safely
  // -----------------------------
  fw.ResponseFourWheeler? _parseFourWheeler(
    Map<String, dynamic>? rawOverride,
    dynamic response,
  ) {
    try {
      if (response is fw.ResponseFourWheeler) return response;

      final raw = rawOverride ?? _safeToJson(response);
      if (raw == null) return null;

      // Sometimes you may pass only {"data":{...}} without "message"
      if (raw.containsKey('data') && !raw.containsKey('message')) {
        return fw.ResponseFourWheeler.fromJson({'data': raw['data'], 'message': ''});
      }

      return fw.ResponseFourWheeler.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
    final apiStr = _asNonEmptyString(apiValue);

    if (apiStr != null) {
      if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
        return NetworkImage(apiStr);
      }
      if (apiStr.startsWith('data:image')) {
        try {
          final base64Part = apiStr.split(',').last;
          final bytes = base64Decode(base64Part);
          return MemoryImage(bytes);
        } catch (_) {}
      }
    }

    // API returns filenames -> keep local fallback
    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;

    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);

    if (obj is String) {
      try {
        final decoded = jsonDecode(obj);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    try {
      final j = (obj as dynamic).toJson();
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}

    try {
      final encoded = jsonEncode(obj);
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return null;
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }
}

// =============================
// UI WIDGETS
// =============================

class _WheelCardData {
  const _WheelCardData({required this.image, required this.label});
  final ImageProvider image;
  final String label;
}

class _WheelImageCard extends StatelessWidget {
  const _WheelImageCard({
    required this.s,
    required this.image,
    required this.label,
    required this.gradient,
  });

  final double s;
  final ImageProvider image;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120 * s,
      child: Column(
        children: [
          Container(
            height: 140 * s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * s),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18 * s),
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 10 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8 * s),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10 * s),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 14 * s,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreChips extends StatelessWidget {
  const _TyreChips({
    super.key,
    required this.s,
    required this.labels,
    required this.selected,
    required this.gradient,
    required this.onSelect,
  });

  final double s;
  final List<String> labels;
  final int selected;
  final LinearGradient gradient;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isSel = i == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(12 * s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10 * s),
                decoration: BoxDecoration(
                  gradient: isSel ? gradient : null,
                  color: isSel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12 * s),
                  border: Border.all(
                    color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSel ? .10 : .05),
                      blurRadius: isSel ? 16 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.5 * s,
                      fontWeight: FontWeight.w900,
                      color: isSel ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BigTreadCard extends StatelessWidget {
  const _BigTreadCard({
    required this.s,
    required this.gradient,
    required this.treadValue,
    required this.treadStatus,
    required this.reason,
    required this.confidence,
  });

  final double s;
  final LinearGradient gradient;
  final String treadValue;
  final String treadStatus;
  final String reason;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset(
                  "assets/thread_depth.png",
                  height: 26 * s, // ✅ slightly tighter than 30
                  width: 26 * s,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8 * s),
              Text(
                'Tread Depth',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 22 * s,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..shader =
                        gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Text(
            'Value: $treadValue',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            'Status: $treadStatus',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallMetricCardPressure extends StatelessWidget {
  const _SmallMetricCardPressure({
    required this.s,
    required this.title,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.gradient,
  });

  final double s;
  final String title;
  final String status;
  final String reason;
  final String confidence;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
    final hasConfidence =
        confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

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
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
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
          if (hasReason) ...[
            SizedBox(height: 8 * s),
            Text(
              reason,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ],
          if (hasConfidence) ...[
            SizedBox(height: 8 * s),
            Text(
              confidence,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14.5 * s,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
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
  final LinearGradient gradient;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
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
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.s,
    required this.gradient,
    required this.tyre,
    required this.summary,
  });

  final double s;
  final LinearGradient gradient;
  final _TyreUi tyre;
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
            color: Colors.black.withOpacity(.10),
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
              Container(
                width: 46 * s,
                height: 46 * s,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                child: Icon(Icons.description_outlined, color: Colors.white, size: 24 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  'Report Summary',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 22 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreUi {
  _TyreUi({
    required this.label,
    required this.treadDepth,
    required this.tyreStatus,
    required this.damageValue,
    required this.damageStatus,
    required this.pressureValue,
    required this.pressureStatus,
    required this.pressureReason,
    required this.pressureConfidence,
    required this.summary,
  });

  final String label;
  final String treadDepth;
  final String tyreStatus;

  final String damageValue;
  final String damageStatus;

  final String pressureValue;
  final String pressureStatus;
  final String pressureReason;
  final String pressureConfidence;

  final String summary;
}

// ======================================================
// ✅ GenerateReportScreen (unchanged)
// ======================================================

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({
    super.key,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    this.vehicleType = 'car',
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String userId;
  final String vehicleId;
  final String token;

  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String vehicleType;

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  bool _fired = false;
  bool _navigated = false;

  fw.ResponseFourWheeler? _apiResponse;

  VideoPlayerController? _videoCtrl;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));
    _startUpload();
  }

  void _startUpload() {
    if (_fired) return;
    _fired = true;

    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,
        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backLeftTyreId,
        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
      ),
    );
  }

  Future<void> _playVideo(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentUrl == u && _videoCtrl != null) return;

    _currentUrl = u;

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

      setState(() => _videoCtrl = ctrl);
      await old?.dispose();
    } catch (_) {}
  }

  void _navigateToResult() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InspectionResultScreen(
          frontLeftPath: widget.frontLeftPath,
          frontRightPath: widget.frontRightPath,
          backLeftPath: widget.backLeftPath,
          backRightPath: widget.backRightPath,
          vehicleId: widget.vehicleId,
          userId: widget.userId,
          token: widget.token,
          response: _apiResponse,
        ),
      ),
    );
  }

  @override
  void dispose() {
    final vc = _videoCtrl;
    _videoCtrl = null;
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media || p.adsStatus != c.adsStatus,
            listener: (context, state) {
              final media = state.selectedAd?.media ?? '';
              if (media.trim().isNotEmpty) {
                _playVideo(media);
              }
            },
          ),
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiResponse = state.fourWheelerResponse as fw.ResponseFourWheeler?;
                _navigateToResult();
              }
            },
          ),
        ],
        child: _FullscreenVideoOnly(controller: _videoCtrl),
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
}*/