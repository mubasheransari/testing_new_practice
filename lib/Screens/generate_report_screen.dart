import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart' as m;
import 'dart:io';
import 'dart:convert';
import 'package:ios_tiretest_ai/models/tyre_upload_response.dart' as m;
import 'package:video_player/video_player.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';

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

  final dynamic response;
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  @override
  void initState() {
    super.initState();
    final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
    if (userid != null && userid.isNotEmpty) {
      context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    final raw = widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? const <String, dynamic>{};

    // API shape: { data: {...} } (from your screenshot)
    final data = _tryReadMap(raw, const ['data', 'result', 'payload']) ?? raw;

    // ---- wheel images (api may return url/base64 or you already have local paths)
    final flImg = _imgProvider(localPath: widget.frontLeftPath, apiValue: _pickAny(data, const [
      'Front Left wheel',
      'frontLeftWheelUrl',
      'front_left_wheel_url',
      'frontLeftUrl',
      'front_left_image_url',
      'front_left_image',
    ]));

    final frImg = _imgProvider(localPath: widget.frontRightPath, apiValue: _pickAny(data, const [
      'Front Right wheel',
      'frontRightWheelUrl',
      'front_right_wheel_url',
      'frontRightUrl',
      'front_right_image_url',
      'front_right_image',
    ]));

    final blImg = _imgProvider(localPath: widget.backLeftPath, apiValue: _pickAny(data, const [
      'Back Left wheel',
      'backLeftWheelUrl',
      'back_left_wheel_url',
      'backLeftUrl',
      'back_left_image_url',
      'back_left_image',
    ]));

    final brImg = _imgProvider(localPath: widget.backRightPath, apiValue: _pickAny(data, const [
      'Back Right wheel',
      'backRightWheelUrl',
      'back_right_wheel_url',
      'backRightUrl',
      'back_right_image_url',
      'back_right_image',
    ]));

    // ---- per-tyre details
    final tyres = <_TyreUi>[
      _buildTyreUi(data, label: 'Front Left', keyPrefix: 'Front Left'),
      _buildTyreUi(data, label: 'Front Right', keyPrefix: 'Front Right'),
      _buildTyreUi(data, label: 'Back Left', keyPrefix: 'Back Left'),
      _buildTyreUi(data, label: 'Back Right', keyPrefix: 'Back Right'),
    ];

    // Combined general summary (optional) if you still want:
    final overallSummary = _asNonEmptyString(_pickAny(raw, const [
          'message',
          'summary',
          'reportSummary',
          'report_summary',
        ])) ??
        'Inspection generated successfully.';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Inspection Report',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 18 * s,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 20 * s),
        children: [
          // ✅ 4 images (top)
          _TopFourImagesRow(
            s: s,
            fl: flImg,
            fr: frImg,
            bl: blImg,
            br: brImg,
          ),
          SizedBox(height: 14 * s),

          // ✅ Cards like your design: left big + right 2 stacked
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: _MetricCardBig(
                  s: s,
                  icon: Icons.blur_circular_rounded,
                  title: 'Tread Depth',
                  // show average-ish summary (but data is per tyre below)
                  value: _bestTreadValue(tyres),
                  status: _bestTreadStatus(tyres),
                ),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    _MetricCardSmall(
                      s: s,
                      title: 'Tire Pressure',
                      value: _bestPressureValue(tyres),
                      status: _bestPressureStatus(tyres),
                    ),
                    SizedBox(height: 10 * s),
                    _MetricCardSmall(
                      s: s,
                      title: 'Damage Check',
                      value: _bestDamageValue(tyres),
                      status: _bestDamageStatus(tyres),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 14 * s),

          // ✅ Report Summary section (overall + each tyre summary one-by-one)
          _SectionCard(
            s: s,
            title: 'Report Summary:',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   overallSummary,
                //   style: TextStyle(
                //     fontFamily: 'ClashGrotesk',
                //     fontWeight: FontWeight.w600,
                //     fontSize: 13.3 * s,
                //     height: 1.35,
                //     color: const Color(0xFF374151),
                //   ),
                // ),
                SizedBox(height: 12 * s),
                       ...tyres.map((t) => _TyreDetailCard(s: s, tyre: t)).toList(),
                // ...tyres.map((t) => _TyreSummaryTile(s: s, tyre: t)).toList(),
              ],
            ),
          ),

      /*    SizedBox(height: 14 * s),

          // ✅ Per-tyre details (pressure/status/summary per tyre)
          Text(
            'Tyre Details',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 16 * s,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 10 * s),
          ...tyres.map((t) => _TyreDetailCard(s: s, tyre: t)).toList(),

          SizedBox(height: 18 * s),*/
        ],
      ),
    );
  }

  // -----------------------------
  // Build per-tyre UI from API map
  // -----------------------------
  _TyreUi _buildTyreUi(Map<String, dynamic> data, {required String label, required String keyPrefix}) {
    // Tread depth
    final treadDepth = _asNonEmptyString(_pickAny(data, [
      '$keyPrefix Tread depth',
      '$keyPrefix Tread Depth',
      '${keyPrefix}_tread_depth',
      '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_tread_depth',
    ]));

    // Tyre status (Safe/Unsafe etc)
    final tyreStatus = _asNonEmptyString(_pickAny(data, [
      '$keyPrefix Tyre status',
      '$keyPrefix Tire status',
      '$keyPrefix tyre status',
      '$keyPrefix tire status',
    ]));

    // Damage / wear patterns
    final damageValue = _asNonEmptyString(_pickAny(data, [
      '$keyPrefix wear patterns',
      '$keyPrefix Wear patterns',
      '$keyPrefix wearPatterns',
      '${keyPrefix}_wear_patterns',
    ]));

    // Pressure object
    final pressureObj = _pickAny(data, [
      '$keyPrefix Tire pressure',
      '$keyPrefix Tyre pressure',
      '$keyPrefix tire pressure',
      '$keyPrefix tyre pressure',
    ]);

    String? pressureStatus;
    String? pressureReason;
    String? pressureConfidence;
    String? pressureValue; // if API ever returns psi/number, we will show it

    if (pressureObj is Map) {
      final m = Map<String, dynamic>.from(pressureObj);
      pressureStatus = _asNonEmptyString(m['status']);
      pressureReason = _asNonEmptyString(m['reason']);
      pressureConfidence = _asNonEmptyString(m['confidence']);
      pressureValue = _asNonEmptyString(m['value']) ?? _asNonEmptyString(m['psi']);
    } else {
      // sometimes backend might send as string
      pressureStatus = _asNonEmptyString(pressureObj);
    }

    // Per-tyre summary
    final summary = _asNonEmptyString(_pickAny(data, [
      '$keyPrefix Summary',
      '$keyPrefix summary',
      '${keyPrefix}_summary',
      '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_summary',
    ]));

    return _TyreUi(
      label: label,
      treadDepth: treadDepth ?? '—',
      tyreStatus: tyreStatus ?? '—',
      damageValue: damageValue ?? '—',
      damageStatus: tyreStatus ?? '—',
      pressureValue: pressureValue ?? '—',
      pressureStatus: pressureStatus ?? '—',
      pressureReason: pressureReason ?? '',
      pressureConfidence: pressureConfidence ?? '',
      summary: summary ?? '—',
    );
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
    // 1) if api value is url
    final apiStr = _asNonEmptyString(apiValue);
    if (apiStr != null) {
      if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
        return NetworkImage(apiStr);
      }
      // 2) if api value is base64 data url
      if (apiStr.startsWith('data:image')) {
        try {
          final base64Part = apiStr.split(',').last;
          final bytes = base64Decode(base64Part);
          return MemoryImage(bytes);
        } catch (_) {}
      }
      // 3) sometimes api returns filename only (not useful) -> fallback local
    }

    // fallback local file
    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);

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

  Map<String, dynamic>? _tryReadMap(Map<String, dynamic> root, List<String> keys) {
    for (final k in keys) {
      final v = root[k];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  dynamic _pickAny(Map<String, dynamic> root, List<String> keys) {
    for (final k in keys) {
      if (root.containsKey(k)) return root[k];
    }
    return null;
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  // --------- small "summary" values for top cards ----------
  String _bestTreadValue(List<_TyreUi> tyres) {
    // show front-left tread depth if available else first non-empty
    final t = tyres.map((e) => e.treadDepth).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return 'Value: $t';
  }

  String _bestTreadStatus(List<_TyreUi> tyres) {
    final t = tyres.map((e) => e.tyreStatus).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return 'Status: $t';
  }

  String _bestPressureValue(List<_TyreUi> tyres) {
    // if PSI exists show it else —
    final v = tyres.map((e) => e.pressureValue).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return v == '—' ? 'Value: —' : 'Value: $v';
  }

  String _bestPressureStatus(List<_TyreUi> tyres) {
    final t = tyres.map((e) => e.pressureStatus).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return 'Status: $t';
  }

  String _bestDamageValue(List<_TyreUi> tyres) {
    final t = tyres.map((e) => e.damageValue).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return 'Value: $t';
  }

  String _bestDamageStatus(List<_TyreUi> tyres) {
    final t = tyres.map((e) => e.damageStatus).firstWhere((x) => x.trim() != '—', orElse: () => '—');
    return 'Status: $t';
  }
}

// =============================
// UI widgets (design like image)
// =============================

class _TopFourImagesRow extends StatelessWidget {
  const _TopFourImagesRow({
    required this.s,
    required this.fl,
    required this.fr,
    required this.bl,
    required this.br,
  });

  final double s;
  final ImageProvider fl, fr, bl, br;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _WheelImageCard(s: s, image: fl, label: 'Front Left')),
        SizedBox(width: 10 * s),
        Expanded(child: _WheelImageCard(s: s, image: fr, label: 'Front Right')),
        SizedBox(width: 10 * s),
        Expanded(child: _WheelImageCard(s: s, image: bl, label: 'Back Left')),
        SizedBox(width: 10 * s),
        Expanded(child: _WheelImageCard(s: s, image: br, label: 'Back Right')),
      ],
    );
  }
}

class _WheelImageCard extends StatelessWidget {
  const _WheelImageCard({
    required this.s,
    required this.image,
    required this.label,
  });

  final double s;
  final ImageProvider image;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 150 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
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
        SizedBox(height: 8 * s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10 * s),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 12.5 * s,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCardBig extends StatelessWidget {
  const _MetricCardBig({
    required this.s,
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
  });

  final double s;
  final IconData icon;
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46 * s,
                height: 46 * s,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14 * s),
                ),
                child: Icon(icon, color: Colors.white, size: 24 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 18 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCardSmall extends StatelessWidget {
  const _MetricCardSmall({
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
      width: double.infinity,
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16 * s,
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white.withOpacity(.95),
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.s,
    required this.title,
    required this.child,
  });

  final double s;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44 * s,
                height: 44 * s,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14 * s),
                ),
                child: Icon(Icons.description_rounded, color: Colors.white, size: 22 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 18 * s,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          child,
        ],
      ),
    );
  }
}

class _TyreSummaryTile extends StatelessWidget {
  const _TyreSummaryTile({required this.s, required this.tyre});
  final double s;
  final _TyreUi tyre;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10 * s),
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFE5EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 14.5 * s,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            tyre.summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13 * s,
              height: 1.35,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreDetailCard extends StatelessWidget {
  const _TyreDetailCard({required this.s, required this.tyre});
  final double s;
  final _TyreUi tyre;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * s),
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: const Color(0xFFEAF1FF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10 * s,
                height: 10 * s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
                  ),
                ),
              ),
              SizedBox(width: 10 * s),
              Text(
                tyre.label,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5 * s,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),

          _kv(s, 'Tread Depth', 'Value: ${tyre.treadDepth}', 'Status: ${tyre.tyreStatus}'),
          SizedBox(height: 10 * s),
          _kv(s, 'Damage Check', 'Value: ${tyre.damageValue}', 'Status: ${tyre.damageStatus}'),
          SizedBox(height: 10 * s),

          // ✅ Pressure per tyre (status/reason/confidence)
          _pressureBlock(s, tyre),

          SizedBox(height: 10 * s),
          Text(
            'Summary',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 13.5 * s,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            tyre.summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13 * s,
              height: 1.35,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(double s, String title, String value, String status) {
    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0xFFE5EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 14.5 * s,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 13 * s,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 13 * s,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pressureBlock(double s, _TyreUi tyre) {
    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DA3FF), Color(0xFF6D63FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tire Pressure',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w900,
              fontSize: 14.5 * s,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            tyre.pressureValue == '—' ? 'Value: —' : 'Value: ${tyre.pressureValue}',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 13 * s,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Status: ${tyre.pressureStatus}',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 13 * s,
              color: Colors.white.withOpacity(.95),
            ),
          ),
          if (tyre.pressureReason.trim().isNotEmpty) ...[
            SizedBox(height: 6 * s),
            Text(
              'Reason: ${tyre.pressureReason}',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w600,
                fontSize: 12.5 * s,
                height: 1.25,
                color: Colors.white.withOpacity(.92),
              ),
            ),
          ],
          if (tyre.pressureConfidence.trim().isNotEmpty) ...[
            SizedBox(height: 6 * s),
            Text(
              'Confidence: ${tyre.pressureConfidence}',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 12.5 * s,
                color: Colors.white.withOpacity(.95),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================
// Data holder
// =============================
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

    // ✅ NEW: pass raw 4-wheeler API json here (from Dio response)
    this.fourWheelerRaw,
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String vehicleId;
  final String userId;
  final String token;

  final dynamic response; // keep your type if you want: m.TyreUploadResponse?
  final Map<String, dynamic>? fourWheelerRaw;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {

    @override
  void initState() {
    super.initState();
    var userid = context.read<AuthBloc>().state.profile!.userId.toString();
    context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
  }
  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    // ✅ 1) prefer raw api json, fallback to response?.toJson(), fallback to response?.data
    final raw = widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? {};
    final data = _tryReadMap(raw, ['data', 'result', 'payload']) ??
        _safeToJson((widget.response as dynamic?)?.data) ??
        {};

    // ✅ URL extraction stays same
    final flUrl = _pickStringFromData(data, [
      'frontLeftWheelUrl',
      'front_left_wheel_url',
      'front_left_url',
      'front_left',
      'frontLeftUrl',
      'front_left_image',
      'front_left_image_url',
    ]);

    final frUrl = _pickStringFromData(data, [
      'frontRightWheelUrl',
      'front_right_wheel_url',
      'front_right_url',
      'front_right',
      'frontRightUrl',
      'front_right_image',
      'front_right_image_url',
    ]);

    final blUrl = _pickStringFromData(data, [
      'backLeftWheelUrl',
      'back_left_wheel_url',
      'back_left_url',
      'back_left',
      'backLeftUrl',
      'back_left_image',
      'back_left_image_url',
    ]);

    final brUrl = _pickStringFromData(data, [
      'backRightWheelUrl',
      'back_right_wheel_url',
      'back_right_url',
      'back_right',
      'backRightUrl',
      'back_right_image',
      'back_right_image_url',
    ]);

    final flImg = _imgProvider(localPath: widget.frontLeftPath, url: flUrl);
    final frImg = _imgProvider(localPath: widget.frontRightPath, url: frUrl);
    final blImg = _imgProvider(localPath: widget.backLeftPath, url: blUrl);
    final brImg = _imgProvider(localPath: widget.backRightPath, url: brUrl);

    // ✅ 2) Extract TEXT from raw/data using deep search
    // You can add more keys here if backend uses different names
    final treadDepth = _deepPickString(raw, [
          'treadDepth',
          'tread_depth',
          'tread.depth',
          'data.treadDepth',
          'data.tread_depth',
        ]) ??
        '—';

    final treadStatus = _deepPickString(raw, [
          'treadStatus',
          'tread_status',
          'tread.status',
          'data.treadStatus',
          'data.tread_status',
        ]) ??
        '—';

    final tyrePressure = _deepPickString(raw, [
          'tyrePressure',
          'tirePressure',
          'pressure',
          'data.tyrePressure',
          'data.pressure',
        ]) ??
        '—';

    final tyrePressureStatus = _deepPickString(raw, [
          'tyrePressureStatus',
          'tirePressureStatus',
          'pressure_status',
          'data.tyrePressureStatus',
          'data.pressure_status',
        ]) ??
        '—';

    final damageCheck = _deepPickString(raw, [
          'damageCheck',
          'damage_check',
          'damage',
          'data.damageCheck',
        ]) ??
        '—';

    final damageStatus = _deepPickString(raw, [
          'damageStatus',
          'damage_status',
          'data.damageStatus',
        ]) ??
        '—';

    final summary =
        _deepPickString(raw, ['message', 'summary', 'reportSummary', 'report_summary']) ??
            'Report generated.';

    // ✅ 3) Show FULL json string (not only response.toJson)
    final prettyJson = const JsonEncoder.withIndent('  ').convert(raw.isEmpty ? data : raw);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 22, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 28 * s),
        children: [
          _PhotosGrid4(s: s, fl: flImg, fr: frImg, bl: blImg, br: brImg),
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
                      title: 'Tyre Pressure',
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

          _ReportSummaryCard(s: s, title: 'Report Summary:', summary: summary),
          SizedBox(height: 18 * s),

          _ApiResponseCard(
            s: s,
            title: 'Four-wheeler API Response (Full)',
            jsonText: prettyJson,
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

  // ==========================
  ImageProvider _imgProvider({required String localPath, String? url}) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'))) {
      return NetworkImage(u);
    }
    return FileImage(File(localPath));
  }

  Map<String, dynamic>? _safeToJson(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) return Map<String, dynamic>.from(obj);

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

  Map<String, dynamic>? _tryReadMap(Map<String, dynamic> root, List<String> keys) {
    for (final k in keys) {
      final v = root[k];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  String? _pickStringFromData(dynamic data, List<String> keys) {
    if (data == null) return null;

    Map<String, dynamic>? map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data as Map);
    } else {
      map = _safeToJson(data);
    }
    if (map == null) return null;

    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return null;
  }

  // ✅ Deep search: supports keys like "data.treadDepth" and will also search any nested maps/lists
  String? _deepPickString(Map<String, dynamic> root, List<String> keys) {
    // 1) dot-path exact
    for (final k in keys) {
      final v = _readByPath(root, k);
      final s = _asNonEmptyString(v);
      if (s != null) return s;
    }

    // 2) fallback: search anywhere (by key name)
    for (final k in keys) {
      final keyName = k.contains('.') ? k.split('.').last : k;
      final v = _findKeyAnywhere(root, keyName);
      final s = _asNonEmptyString(v);
      if (s != null) return s;
    }

    return null;
  }

  dynamic _readByPath(Map<String, dynamic> root, String path) {
    if (!path.contains('.')) return root[path];

    dynamic cur = root;
    for (final part in path.split('.')) {
      if (cur is Map) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }

  dynamic _findKeyAnywhere(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node[key];
      for (final v in node.values) {
        final found = _findKeyAnywhere(v, key);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final v in node) {
        final found = _findKeyAnywhere(v, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}
*/



  ImageProvider _imgProvider({required String localPath, String? url}) {
    final u = (url ?? '').trim();
    if (u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'))) {
      return NetworkImage(u);
    }
    return FileImage(File(localPath));
  }

  String? _pickStringFromData(dynamic data, List<String> keys) {
    if (data == null) return null;

    Map<String, dynamic>? map;

    if (data is Map) {
      map = Map<String, dynamic>.from(data as Map);
    } else {
      try {
        final dynamic j = (data as dynamic).toJson();
        if (j is Map) map = Map<String, dynamic>.from(j as Map);
      } catch (_) {
        map = null;
      }
    }

    if (map == null) return null;

    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return null;
  }

  String _prettyResponseJson(m.TyreUploadResponse? response) {
    if (response == null) return 'No response (null)';
    try {
      final dynamic j = (response as dynamic).toJson();
      return const JsonEncoder.withIndent('  ').convert(j);
    } catch (_) {
      return 'message: ${response.message}\n'
          'data: ${response.data}\n'
          '(Tip: add toJson() in TyreUploadResponse for full JSON)';
    }
  }

  // void _toast(BuildContext ctx, String msg) =>
  //     ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));


// class _PhotosGrid4 extends StatelessWidget {
//   const _PhotosGrid4({
//     required this.s,
//     required this.fl,
//     required this.fr,
//     required this.bl,
//     required this.br,
//   });

//   final double s;
//   final ImageProvider fl, fr, bl, br;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: _PhotoCard(
//                 s: s,
//                 image: fl,
//                 label: 'Front Left',
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF30C5FF), Color(0xFF4676FF)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//             SizedBox(width: 12 * s),
//             Expanded(
//               child: _PhotoCard(
//                 s: s,
//                 image: fr,
//                 label: 'Front Right',
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFFFF7E6D), Color(0xFFFF57B5)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 12 * s),
//         Row(
//           children: [
//             Expanded(
//               child: _PhotoCard(
//                 s: s,
//                 image: bl,
//                 label: 'Back Left',
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF39D2C0), Color(0xFF7993FF)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//             SizedBox(width: 12 * s),
//             Expanded(
//               child: _PhotoCard(
//                 s: s,
//                 image: br,
//                 label: 'Back Right',
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF7C3AED), Color(0xFF60A5FA)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// class _ApiResponseCard extends StatelessWidget {
//   const _ApiResponseCard({
//     required this.s,
//     required this.title,
//     required this.jsonText,
//   });

//   final double s;
//   final String title;
//   final String jsonText;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         border: Border.all(color: const Color(0xFFE3E7F3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 15 * s,
//               fontWeight: FontWeight.w800,
//               color: Colors.black,
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.all(12 * s),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF6F7FB),
//               borderRadius: BorderRadius.circular(12 * s),
//               border: Border.all(color: const Color(0xFFE6EAF6)),
//             ),
//             child: SelectableText(
//               jsonText,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 12.5 * s,
//                 height: 1.25,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _PhotoCard extends StatelessWidget {
//   const _PhotoCard({
//     required this.s,
//     required this.image,
//     required this.label,
//     required this.gradient,
//   });

//   final double s;
//   final ImageProvider image;
//   final String label;
//   final Gradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 140 * s,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18 * s),
//         gradient: gradient,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.08),
//             blurRadius: 14,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18 * s),
//         child: Stack(
//           children: [
//             Positioned.fill(
//               child: Image(image: image, fit: BoxFit.cover),
//             ),
//             Positioned(
//               left: 10 * s,
//               bottom: 10 * s,
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(.45),
//                   borderRadius: BorderRadius.circular(999),
//                 ),
//                 child: Text(
//                   label,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     color: Colors.white,
//                     fontWeight: FontWeight.w800,
//                     fontSize: 12.5 * s,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _BigMetricCard extends StatelessWidget {
//   const _BigMetricCard({
//     required this.s,
//     required this.iconBg,
//     required this.icon,
//     required this.title,
//     required this.value,
//     required this.status,
//   });

//   final double s;
//   final Gradient iconBg;
//   final IconData icon;
//   final String title;
//   final String value;
//   final String status;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18 * s),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 40 * s,
//                 height: 40 * s,
//                 decoration: BoxDecoration(
//                   gradient: iconBg,
//                   borderRadius: BorderRadius.circular(12 * s),
//                 ),
//                 child: Icon(icon, color: Colors.white, size: 22 * s),
//               ),
//               SizedBox(width: 10 * s),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 14.5 * s,
//                     fontWeight: FontWeight.w800,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             value,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 13 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF6B7280),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SmallMetricCard extends StatelessWidget {
//   const _SmallMetricCard({
//     required this.s,
//     required this.title,
//     required this.value,
//     required this.status,
//     required this.gradient,
//   });

//   final double s;
//   final String title;
//   final String value;
//   final String status;
//   final Gradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         gradient: gradient,
//         borderRadius: BorderRadius.circular(18 * s),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               color: Colors.white,
//               fontWeight: FontWeight.w800,
//               fontSize: 13.5 * s,
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Text(
//             value,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               color: Colors.white,
//               fontWeight: FontWeight.w700,
//               fontSize: 12.5 * s,
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               color: Colors.white.withOpacity(.9),
//               fontWeight: FontWeight.w700,
//               fontSize: 12.5 * s,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ReportSummaryCard extends StatelessWidget {
//   const _ReportSummaryCard({
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
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//               fontSize: 15 * s,
//               color: Colors.black,
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w600,
//               fontSize: 13.5 * s,
//               height: 1.35,
//               color: const Color(0xFF374151),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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

  m.ResponseFourWheeler? _apiResponse;

  VideoPlayerController? _videoCtrl;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();

    // 1) fetch ads immediately (silent)
    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));

    // 2) fire your four-wheeler upload immediately
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
        backRightTyreId: widget.backRightTyreId,
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

      // Optional: better iOS behavior (remove if you don't want)
      // await ctrl.setVolume(1.0);

      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() => _videoCtrl = ctrl);
      await old?.dispose();
    } catch (_) {
      // If ad fails, we keep fallback black screen
    }
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
          // ✅ listen for Ads and play video
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media ||
                p.adsStatus != c.adsStatus,
            listener: (context, state) {
              final media = state.selectedAd?.media ?? '';
              if (media.trim().isNotEmpty) {
                _playVideo(media);
              }
            },
          ),

          // ✅ listen for four-wheeler result and navigate immediately
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiResponse = state.fourWheelerResponse;
                _navigateToResult();
              }
              if (state.fourWheelerStatus == FourWheelerStatus.failure) {
                // If you want ZERO UI, remove this SnackBar.
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text(state.fourWheelerError ?? 'Upload failed')),
                // );
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

    // Video not ready yet -> pure black screen (no text, no loader)
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

class _GenerateReportScreenState extends State<GenerateReportScreen>
    with SingleTickerProviderStateMixin {
  int _counter = 5;
  Timer? _timer;

  late final AnimationController _progressCtrl;
  late final Animation<double> _progress;

  bool _fired = false;
  bool _countdownDone = false;
  bool _apiDone = false;
  bool _navigated = false;

  m.ResponseFourWheeler? _apiResponse;

  VideoPlayerController? _videoCtrl;
  String _currentMediaUrl = '';

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _progress = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOutCubic);
    _progressCtrl.forward();

    // ✅ fetch ads immediately (uses token)
    context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));

    _startCountdownAndUpload();
  }

  void _startCountdownAndUpload() {
    if (_fired) return;
    _fired = true;

    // ✅ call 4-wheeler upload immediately
    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,
        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backRightTyreId,
        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
      ),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _counter--);

      if (_counter <= 0) {
        t.cancel();
        _countdownDone = true;
        _tryNavigate();
      }
    });
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;

    // ✅ navigate only when both done (as your existing logic)
    if (_countdownDone && _apiDone) {
      _navigated = true;
      _disposeVideo();

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
  }

  Future<void> _playAd(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (_currentMediaUrl == u && _videoCtrl != null) return;

    _currentMediaUrl = u;

    try {
      final old = _videoCtrl;
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(u));

      await _videoCtrl!.initialize();
      await _videoCtrl!.setLooping(true);
      await _videoCtrl!.play();

      setState(() {});
      await old?.dispose();
    } catch (_) {
      // if video fails, keep fallback UI
    }
  }

  void _disposeVideo() {
    final v = _videoCtrl;
    _videoCtrl = null;
    v?.dispose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressCtrl.dispose();
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
            listener: (context, state) {
              if (state.fourWheelerStatus == FourWheelerStatus.failure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.fourWheelerError ?? 'Upload failed')),
                );
              }
              if (state.fourWheelerStatus == FourWheelerStatus.success) {
                _apiDone = true;
                _apiResponse = state.fourWheelerResponse;
                _tryNavigate();
              }
            },
          ),

          // ✅ when ad arrives, play it
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (p, c) =>
                p.selectedAd?.media != c.selectedAd?.media ||
                p.adsStatus != c.adsStatus,
            listener: (context, state) {
              final media = state.selectedAd?.media ?? '';
              if (media.trim().isNotEmpty) {
                _playAd(media);
              }
            },
          ),
        ],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ VIDEO BACKGROUND
            _AdVideoBackground(controller: _videoCtrl),

            // ✅ dark overlay for text readability
            Container(color: Colors.black.withOpacity(.35)),

            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  _concentricCounter(s: s, valueText: '${_counter.clamp(0, 9)}'),
                  const Spacer(),
                ],
              ),
            ),

            Positioned(
              left: 16 * s,
              bottom: 16 * s + bottom,
              child: _BottomLeftProgressPill(scale: s, progress: _progress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _concentricCounter({required double s, required String valueText}) {
    final base = 260.0 * s;
    final rings = <double>[1.0, .76, .55];

    return SizedBox(
      width: base,
      height: base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final r in rings)
            Container(
              width: base * r,
              height: base * r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.20 * r + .05),
              ),
            ),
          Container(
            width: base * .42,
            height: base * .42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2563EB),
            ),
          ),
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
}*/

class _AdVideoBackground extends StatelessWidget {
  const _AdVideoBackground({required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      // fallback
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _BottomLeftProgressPill extends StatelessWidget {
  const _BottomLeftProgressPill({required this.scale, required this.progress});

  final double scale;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160 * scale,
      height: 46 * scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: Colors.white.withOpacity(.22)),
            AnimatedBuilder(
              animation: progress,
              builder: (_, __) {
                return FractionallySizedBox(
                  widthFactor: progress.value.clamp(0, 1),
                  child: Container(color: Colors.white.withOpacity(.35)),
                );
              },
            ),
            Center(
              child: Text(
                'Generating…',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.white,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w800,
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

    // ✅ required by backend / event
    required this.vin,

    // ✅ ids required by api
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,

    // ✅ "Car" or "car"
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

class _GenerateReportScreenState extends State<GenerateReportScreen>
    with SingleTickerProviderStateMixin {
  int _counter = 5;
  Timer? _timer;

  late final AnimationController _progressCtrl;
  late final Animation<double> _progress;

  bool _fired = false;

  // ✅ NEW: gates
  bool _countdownDone = false;
  bool _apiDone = false;
  bool _navigated = false;

  // ✅ store response to pass to result screen
  m.ResponseFourWheeler? _apiResponse;

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

    _progressCtrl.forward();

    _startCountdownAndUpload();
  }

  void _startCountdownAndUpload() {
    if (_fired) return;
    _fired = true;

    // ✅ fire upload immediately
    context.read<AuthBloc>().add(
      UploadFourWheelerRequested(
        vehicleId: widget.vehicleId,
        vehicleType: widget.vehicleType,
        vin: widget.vin,

        frontLeftTyreId: widget.frontLeftTyreId,
        frontRightTyreId: widget.frontRightTyreId,
        backLeftTyreId: widget.backLeftTyreId,
        backRightTyreId: widget.backRightTyreId,

        frontLeftPath: widget.frontLeftPath,
        frontRightPath: widget.frontRightPath,
        backLeftPath: widget.backLeftPath,
        backRightPath: widget.backRightPath,
      ),
    );

    // ✅ countdown 5 → 0
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() {
        _counter--;
      });

      if (_counter <= 0) {
        t.cancel();
        _countdownDone = true;
        _tryNavigate();
      }
    });
  }

  void _tryNavigate() {
    if (!mounted) return;
    if (_navigated) return;

    // ✅ navigate ONLY when BOTH conditions are met
    if (_countdownDone && _apiDone) {
      _navigated = true;

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
            response: _apiResponse, // ✅ api response
          ),
        ),
      );
    }
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
        listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
        listener: (context, state) {
          if (state.fourWheelerStatus == FourWheelerStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.fourWheelerError ?? 'Upload failed'),
              ),
            );
          }

          if (state.fourWheelerStatus == FourWheelerStatus.success) {
            // ✅ mark API done, store response, then try navigate (waits for counter=0 too)
            _apiDone = true;
            _apiResponse = state.fourWheelerResponse;
            _tryNavigate();
          }
        },
        builder: (context, state) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/generating_report_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),

              Container(color: Colors.black.withOpacity(.40)),

              // SafeArea(
              //   child: Align(
              //     alignment: Alignment.topLeft,
              //     child: IconButton(
              //       icon: const Icon(
              //         Icons.chevron_left_rounded,
              //         color: Colors.white,
              //         size: 32,
              //       ),
              //       onPressed: () => Navigator.pop(context),
              //     ),
              //   ),
              // ),

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

              Positioned(
                left: 16 * s,
                bottom: 16 * s + bottom,
                child: _BottomLeftProgressPill(scale: s, progress: _progress),
              ),

              if (state.fourWheelerStatus == FourWheelerStatus.failure &&
                  (state.fourWheelerError?.isNotEmpty ?? false))
                Positioned(
                  left: 16 * s,
                  right: 16 * s,
                  top: 110 * s,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.fourWheelerError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _concentricCounter({required double s, required String valueText}) {
    final base = 260.0 * s;
    final rings = <double>[1.0, .76, .55];

    return SizedBox(
      width: base,
      height: base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final r in rings)
            Container(
              width: base * r,
              height: base * r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.20 * r + .05),
              ),
            ),
          Container(
            width: base * .42,
            height: base * .42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2563EB),
            ),
          ),
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
}*/

// class _BottomLeftProgressPill extends StatelessWidget {
//   const _BottomLeftProgressPill({required this.scale, required this.progress});

//   final double scale;
//   final Animation<double> progress;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 160 * scale,
//       height: 46 * scale,
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(999),
//         child: Stack(
//           children: [
//             Container(color: Colors.white.withOpacity(.22)),
//             AnimatedBuilder(
//               animation: progress,
//               builder: (_, __) {
//                 return FractionallySizedBox(
//                   widthFactor: progress.value.clamp(0, 1),
//                   child: Container(color: Colors.white.withOpacity(.35)),
//                 );
//               },
//             ),
//             Center(
//               child: Text(
//                 'Generating…',
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   color: Colors.white,
//                   fontSize: 14 * scale,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
