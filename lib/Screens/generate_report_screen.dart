import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart' show AppShell;
import 'package:ios_tiretest_ai/models/response_four_wheeler.dart' as m;
import 'dart:io';
import 'dart:convert';
import 'package:ios_tiretest_ai/models/tyre_upload_response.dart' as m;
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

    // keep your existing behavior
    try {
      final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
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

    // ✅ chip order: Left, Front, Back, Right
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

    // ✅ Images: your API returns filenames, so we keep local fallback (UI unchanged)
    final flImg = _imgProvider(localPath: widget.frontLeftPath, apiValue: d?.frontLeftWheel);
    final frImg = _imgProvider(localPath: widget.frontRightPath, apiValue: d?.frontRightWheel);
    final blImg = _imgProvider(localPath: widget.backLeftPath, apiValue: d?.backLeftWheel);
    final brImg = _imgProvider(localPath: widget.backRightPath, apiValue: d?.backRightWheel);

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
        MaterialPageRoute(
          builder: (_) =>  AppShell() 
              
        ),
        (route) => false,
      );

                  //  Navigator.of(context).pop();
                  //  Navigator.of(context).pop();
                  //   Navigator.of(context).pop();
                  }//=> Navigator.pop(context),
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
              SizedBox(height: 12 * s),
              _TyreChips(
                s: s,
                labels: const ['Front Left', 'Front Right', 'Back Left', 'Back Right'],
                selected: _selected,
                gradient: _brandGrad,
                onSelect: (i) => setState(() => _selected = i),
              ),
              SizedBox(height: 14 * s),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 12,
                          child: _BigTreadCard(
                            s: s,
                            gradient: _brandGrad,
                            treadValue: selectedTyre.treadDepth,
                            treadStatus: selectedTyre.tyreStatus, reason: '', confidence: '',
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          flex: 10,
                          child: Column(
                            children: [
                          _SmallMetricCardPressure(
                            gradient: _brandGrad,
  s: s,
  title: 'Tire Pressure',
  // value: 'Value: ${selectedTyre.pressureValue}',
  status: 'Status: ${selectedTyre.pressureStatus}',
  reason: selectedTyre.pressureReason.trim().isEmpty
      ? ''
      : 'Reason: ${selectedTyre.pressureReason}',
  confidence: selectedTyre.pressureConfidence.trim().isEmpty
      ? ''
      : 'Confidence: ${selectedTyre.pressureConfidence}',
),

                              SizedBox(height: 12 * s),
                              // _SmallMetricCard(
                              //   s: s,
                              //   title: 'Damage Check',
                              //   value: 'Value: ${selectedTyre.damageValue}',
                              //   status: 'Status: ${selectedTyre.damageStatus}',
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                        SizedBox(height: 12 * s),
                      _SmallMetricCard(
                                s: s,
                                title: 'Damage Check',
                                value: 'Value: ${selectedTyre.damageValue}',
                                status: 'Status: ${selectedTyre.damageStatus}',
                              ),
                    SizedBox(height: 16 * s),
                    _ReportSummaryCard(
                      s: s,
                      gradient: _brandGrad,
                      tyre: selectedTyre,
                      summary: summaryText,
                    ),
                    SizedBox(height: 10 * s),
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
// UI WIDGETS (UNCHANGED)
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
    final hasReason =
        reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
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
        mainAxisSize: MainAxisSize.min, // 🔑 critical
        children: [
          /// ✅ Title row (same as pressure)
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset(
                  "assets/thread_depth.png",
                  height: 30 * s,
                  width: 30 * s,
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
                    ..shader = gradient.createShader(
                      const Rect.fromLTWH(0, 0, 200, 40),
                    ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8 * s),

          /// ✅ SINGLE combined line (same vertical count as pressure)
          Text(
            'Value: $treadValue',
          //  maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
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

          /// ✅ Reason (only if pressure also shows it)
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

          /// ✅ Confidence (same rule)
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

/*
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
    final hasReason =
        reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
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
          /// ✅ Title row with SMALL thread icon (same height as pressure)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset(
                  "assets/thread_depth.png",
                  height: 28 * s, // 🔑 same visual weight as text
                  width: 28 * s,
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
                    ..shader = gradient.createShader(
                      const Rect.fromLTWH(0, 0, 200, 40),
                    ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8 * s),

          /// ✅ Value
          Text(
            'Value: $treadValue',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),

          SizedBox(height: 8 * s),

          /// ✅ Status
          Text(
            'Status: $treadStatus',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),

          /// ✅ Reason
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

          /// ✅ Confidence
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
*/


// class _BigTreadCard extends StatelessWidget {
//   const _BigTreadCard({
//     required this.s,
//     required this.gradient,
//     required this.treadValue,
//     required this.treadStatus,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final String treadValue;
//   final String treadStatus;

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
//           Container(
//             width: 62 * s,
//             height: 62 * s,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 )
//               ],
//             ),
//             child: Center(
//               child: ShaderMask(
//                 shaderCallback: (r) => gradient.createShader(r),
//                 child: Image.asset("assets/thread_depth.png", height: 34, width: 34),
//               ),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Tread Depth',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()
//                 ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Value: $treadValue',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Status: $treadStatus',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
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
          /// ✅ Gradient title (same visual weight as tread card)
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

          /// ✅ Status
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 16 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),

          /// ✅ Reason
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

          /// ✅ Confidence
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


// class _SmallMetricCardPressure extends StatelessWidget {
//   const _SmallMetricCardPressure({
//     required this.s,
//     required this.title,
//    // required this.value,
//     required this.status,
//     required this.reason,
//     required this.confidence,
//   });

//   final double s;
//   final String title;

//   // keep same idea as previous card
//  // final String value;       // e.g. "Value: Normal"
//   final String status;      // e.g. "Status: Normal"
//   final String reason;      // e.g. "Reason: Even wear detected..."
//   final String confidence;  // e.g. "Confidence: Medium"

//   @override
//   Widget build(BuildContext context) {
//     final hasReason = reason.trim().isNotEmpty && reason.trim() != 'Reason: —';
//     final hasConfidence =
//         confidence.trim().isNotEmpty && confidence.trim() != 'Confidence: —';

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
//           // SizedBox(height: 12 * s),

//           // // ✅ Value (line 1)
//           // Text(
//           //   value,
//           //   style: TextStyle(
//           //     fontFamily: 'ClashGrotesk',
//           //     fontSize: 16 * s,
//           //     fontWeight: FontWeight.w700,
//           //     color: const Color(0xFF111827),
//           //   ),
//           // ),
//           SizedBox(height: 8 * s),

//           // ✅ Status (line 2)
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),

//           // ✅ Reason (line 3)
//           if (hasReason) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               reason,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 height: 1.25,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],

//           // ✅ Confidence (line 4)
//           if (hasConfidence) ...[
//             SizedBox(height: 8 * s),
//             Text(
//               confidence,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 14.5 * s,
//                 fontWeight: FontWeight.w600,
//                 color: const Color(0xFF111827),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }


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
            //  Icon(Icons.chevron_right_rounded, size: 30 * s, color: const Color(0xFF111827)),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
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
// ✅ GenerateReportScreen (UI unchanged)
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

// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
// import 'package:ios_tiretest_ai/Bloc/auth_state.dart';

// class InspectionResultScreen extends StatefulWidget {
//   const InspectionResultScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.vehicleId,
//     required this.userId,
//     required this.token,
//     this.response,
//     this.fourWheelerRaw,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final dynamic response;
//   final Map<String, dynamic>? fourWheelerRaw;

//   @override
//   State<InspectionResultScreen> createState() => _InspectionResultScreenState();
// }

// class _InspectionResultScreenState extends State<InspectionResultScreen> {
//   static const _bg = Color(0xFFF2F2F2);

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   int _selected = 0;

//   @override
//   void initState() {
//     super.initState();

//     // keep your existing behavior
//     try {
//       final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
//       if (userid != null && userid.isNotEmpty) {
//         context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
//       }
//     } catch (_) {}
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     final raw =
//         widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? const <String, dynamic>{};

//     // ✅ your response is { "data": { ...flat keys... } }
//     final data = _unwrapApiRoot(raw);

//     print("DATA CHECK ${data['User ID']}");
//     print("DATA CHECK ${data['Front Left Tyre status']}");
//     print("DATA CHECK ${data['Back Left Tire pressure']}");

//     // ✅ chip order: Left, Front, Back, Right
//     final tyreByChipIndex = <int, _TyreUi>{
//       0: _buildTyreUi(data, label: 'Front Left', keyPrefix: 'Front Left'),
//       1: _buildTyreUi(data, label: 'Front Right', keyPrefix: 'Front Right'),
//       2: _buildTyreUi(data, label: 'Back Left', keyPrefix: 'Back Left'),
//       3: _buildTyreUi(data, label: 'Back Right', keyPrefix: 'Back Right'),
//     };

//     final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;


//     final flImg = _imgProvider(
//       localPath: widget.frontLeftPath,
//       apiValue: _getAnyKey(data, const ['Front Left Wheel', 'Front Left wheel']),
//     );
//     final frImg = _imgProvider(
//       localPath: widget.frontRightPath,
//       apiValue: _getAnyKey(data, const ['Front Right Wheel', 'Front Right wheel']),
//     );
//     final blImg = _imgProvider(
//       localPath: widget.backLeftPath,
//       apiValue: _getAnyKey(data, const ['Back Left Wheel', 'Back Left wheel']),
//     );
//     final brImg = _imgProvider(
//       localPath: widget.backRightPath,
//       apiValue: _getAnyKey(data, const ['Back Right Wheel', 'Back Right wheel']),
//     );

//     final wheelImages = <_WheelCardData>[
//       _WheelCardData(image: flImg, label: 'left'),
//       _WheelCardData(image: frImg, label: 'Front'),
//       _WheelCardData(image: blImg, label: 'Back'),
//       _WheelCardData(image: brImg, label: 'Right'),
//     ];

//     final summaryText = _composeSelectedSummary(selectedTyre);

//     return Scaffold(
//       backgroundColor: _bg,
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
//           child: Column(
//             children: [
//               SizedBox(
//                 height: 190 * s,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: wheelImages.length,
//                   separatorBuilder: (_, __) => SizedBox(width: 12 * s),
//                   itemBuilder: (_, i) {
//                     final item = wheelImages[i];
//                     return _WheelImageCard(
//                       s: s,
//                       image: item.image,
//                       label: item.label,
//                       gradient: _brandGrad,
//                     );
//                   },
//                 ),
//               ),
//               SizedBox(height: 12 * s),

//               _TyreChips(
//                 s: s,
//                 labels: const ['Left', 'Front', 'Back', 'Right'],
//                 selected: _selected,
//                 gradient: _brandGrad,
//                 onSelect: (i) => setState(() => _selected = i),
//               ),

//               SizedBox(height: 14 * s),

//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           flex: 11,
//                           child: _BigTreadCard(
//                             s: s,
//                             gradient: _brandGrad,
//                             treadValue: selectedTyre.treadDepth,
//                             treadStatus: selectedTyre.tyreStatus,
//                           ),
//                         ),
//                         SizedBox(width: 12 * s),
//                         Expanded(
//                           flex: 10,
//                           child: Column(
//                             children: [
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Tire Pressure',
//                                 value: 'Value: ${selectedTyre.pressureValue}',
//                                 status: 'Status: ${selectedTyre.pressureStatus}',
//                               ),
//                               SizedBox(height: 12 * s),
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Damage Check',
//                                 value: 'Value: ${selectedTyre.damageValue}',
//                                 status: 'Status: ${selectedTyre.damageStatus}',
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 16 * s),

//                     _ReportSummaryCard(
//                       s: s,
//                       gradient: _brandGrad,
//                       tyre: selectedTyre,
//                       summary: summaryText,
//                     ),
//                     SizedBox(height: 10 * s),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ✅ EXACT KEYS based on your API response
//   _TyreUi _buildTyreUi(
//     Map<String, dynamic> data, {
//     required String label,
//     required String keyPrefix, // "Front Left"
//   }) {
//     final treadDepth = _asNonEmptyString(_getAnyKey(data, [
//       '$keyPrefix Tread depth',
//       '$keyPrefix Tread Depth',
//     ]));

//     final tyreStatus = _asNonEmptyString(_getAnyKey(data, [
//       '$keyPrefix Tyre status',
//       '$keyPrefix Tire status',
//     ]));

//     final wearPatterns = _asNonEmptyString(_getAnyKey(data, [
//       '$keyPrefix Wear patterns',
//       '$keyPrefix wear patterns',
//       '$keyPrefix Wear Patterns',
//     ]));

//     final summary = _asNonEmptyString(_getAnyKey(data, [
//       '$keyPrefix Summary',
//       '$keyPrefix summary',
//     ]));

//     final pressureObj = _getAnyKey(data, [
//       '$keyPrefix Tire pressure',
//       '$keyPrefix Tyre pressure',
//       '$keyPrefix tire pressure',
//       '$keyPrefix tyre pressure',
//     ]);

//     String pressureStatus = '—';
//     String pressureReason = '';
//     String pressureConfidence = '';
//     String pressureValue = '—';

//     if (pressureObj is Map) {
//       final m = Map<String, dynamic>.from(pressureObj);
//       pressureStatus = _asNonEmptyString(m['status']) ?? '—';
//       pressureReason = _asNonEmptyString(m['reason']) ?? '';
//       pressureConfidence = _asNonEmptyString(m['confidence']) ?? '';
//       pressureValue = _asNonEmptyString(m['value']) ??
//           _asNonEmptyString(m['psi']) ??
//           pressureStatus; // your API has no psi/value -> show status as value
//     } else {
//       final s = _asNonEmptyString(pressureObj);
//       if (s != null) {
//         pressureStatus = s;
//         pressureValue = s;
//       }
//     }

//     return _TyreUi(
//       label: label,
//       treadDepth: treadDepth ?? '—',
//       tyreStatus: tyreStatus ?? '—',
//       damageValue: wearPatterns ?? '—',
//       damageStatus: tyreStatus ?? '—',
//       pressureValue: pressureValue,
//       pressureStatus: pressureStatus,
//       pressureReason: pressureReason,
//       pressureConfidence: pressureConfidence,
//       summary: summary ?? '—',
//     );
//   }

//   String _composeSelectedSummary(_TyreUi t) {
//     final parts = <String>[];

//     if (t.summary.trim().isNotEmpty && t.summary != '—') {
//       parts.add(t.summary.trim());
//     }

//     // include full pressure info inside same summary text (UI unchanged)
//     if (t.pressureStatus != '—' ||
//         t.pressureReason.trim().isNotEmpty ||
//         t.pressureConfidence.trim().isNotEmpty) {
//       parts.add([
//         'Tire pressure:',
//         '• Status: ${t.pressureStatus}',
//         if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
//         if (t.pressureConfidence.trim().isNotEmpty)
//           '• Confidence: ${t.pressureConfidence}',
//       ].join('\n'));
//     }

//     return parts.isEmpty ? '—' : parts.join('\n\n');
//   }

//   // -----------------------------
//   // Helpers
//   // -----------------------------
//   Map<String, dynamic> _unwrapApiRoot(Map<String, dynamic> raw) {
//     Map<String, dynamic> cur = raw;
//     for (int i = 0; i < 6; i++) {
//       final next = _tryReadMap(cur, const ['data', 'result', 'payload']);
//       if (next == null) break;
//       cur = next;
//     }
//     return cur;
//   }

//   // ✅ Get by exact key OR normalized key (spaces/case/underscore/dash)
//   dynamic _getAnyKey(Map<String, dynamic> root, List<String> keys) {
//     for (final k in keys) {
//       if (root.containsKey(k)) return root[k];
//     }

//     String norm(String x) => x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
//     final idx = <String, String>{};
//     for (final actual in root.keys) {
//       idx[norm(actual)] = actual;
//     }

//     for (final want in keys) {
//       final hit = idx[norm(want)];
//       if (hit != null) return root[hit];
//     }

//     return null;
//   }

//   ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
//     final apiStr = _asNonEmptyString(apiValue);

//     // if backend returns full URL/base64, show it
//     if (apiStr != null) {
//       if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
//         return NetworkImage(apiStr);
//       }
//       if (apiStr.startsWith('data:image')) {
//         try {
//           final base64Part = apiStr.split(',').last;
//           final bytes = base64Decode(base64Part);
//           return MemoryImage(bytes);
//         } catch (_) {}
//       }
//     }

//     // otherwise your API returns filename string -> keep local fallback
//     return FileImage(File(localPath));
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;
//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);

//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map<String, dynamic>) return j;
//       if (j is Map) return Map<String, dynamic>.from(j);
//     } catch (_) {}

//     try {
//       final encoded = jsonEncode(obj);
//       final decoded = jsonDecode(encoded);
//       if (decoded is Map<String, dynamic>) return decoded;
//       if (decoded is Map) return Map<String, dynamic>.from(decoded);
//     } catch (_) {}

//     return null;
//   }

//   Map<String, dynamic>? _tryReadMap(Map<String, dynamic> root, List<String> keys) {
//     for (final k in keys) {
//       final v = root[k];
//       if (v is Map<String, dynamic>) return v;
//       if (v is Map) return Map<String, dynamic>.from(v);
//     }
//     return null;
//   }

//   String? _asNonEmptyString(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return null;
//     return s;
//   }
// }

// // =============================
// // UI WIDGETS (UNCHANGED)
// // =============================

// class _WheelCardData {
//   const _WheelCardData({required this.image, required this.label});
//   final ImageProvider image;
//   final String label;
// }

// class _WheelImageCard extends StatelessWidget {
//   const _WheelImageCard({
//     required this.s,
//     required this.image,
//     required this.label,
//     required this.gradient,
//   });

//   final double s;
//   final ImageProvider image;
//   final String label;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 120 * s,
//       child: Column(
//         children: [
//           Container(
//             height: 140 * s,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(18 * s),
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(18 * s),
//               child: Image(image: image, fit: BoxFit.cover),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.symmetric(vertical: 8 * s),
//             decoration: BoxDecoration(
//               gradient: gradient,
//               borderRadius: BorderRadius.circular(10 * s),
//             ),
//             child: Center(
//               child: Text(
//                 label,
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w900,
//                   fontSize: 14 * s,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreChips extends StatelessWidget {
//   const _TyreChips({
//     super.key,
//     required this.s,
//     required this.labels,
//     required this.selected,
//     required this.gradient,
//     required this.onSelect,
//   });

//   final double s;
//   final List<String> labels;
//   final int selected;
//   final LinearGradient gradient;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: List.generate(labels.length, (i) {
//         final isSel = i == selected;
//         return Expanded(
//           child: Padding(
//             padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
//             child: InkWell(
//               onTap: () => onSelect(i),
//               borderRadius: BorderRadius.circular(12 * s),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding: EdgeInsets.symmetric(vertical: 10 * s),
//                 decoration: BoxDecoration(
//                   gradient: isSel ? gradient : null,
//                   color: isSel ? null : Colors.white,
//                   borderRadius: BorderRadius.circular(12 * s),
//                   border: Border.all(
//                     color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(isSel ? .10 : .05),
//                       blurRadius: isSel ? 16 : 10,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     labels[i],
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 13.5 * s,
//                       fontWeight: FontWeight.w900,
//                       color: isSel ? Colors.white : const Color(0xFF111827),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

// class _BigTreadCard extends StatelessWidget {
//   const _BigTreadCard({
//     required this.s,
//     required this.gradient,
//     required this.treadValue,
//     required this.treadStatus,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final String treadValue;
//   final String treadStatus;

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
//           Container(
//             width: 62 * s,
//             height: 62 * s,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 )
//               ],
//             ),
//             child: Center(
//               child: ShaderMask(
//                 shaderCallback: (r) => gradient.createShader(r),
//                 child: Image.asset("assets/thread_depth.png", height: 34, width: 34),
//               ),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Tread Depth',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Value: $treadValue',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Status: $treadStatus',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//           SizedBox(height: 8 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//     required this.gradient,
//     required this.tyre,
//     required this.summary,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final _TyreUi tyre;
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
//             color: Colors.black.withOpacity(.10),
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
//               Container(
//                 width: 52 * s,
//                 height: 52 * s,
//                 decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
//                 child: Icon(Icons.description_outlined, color: Colors.white, size: 26 * s),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: Text(
//                   'Report Summary:',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 26 * s,
//                     fontWeight: FontWeight.w900,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//               ),
//               Icon(Icons.chevron_right_rounded, size: 30 * s, color: const Color(0xFF111827)),
//             ],
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             tyre.label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w600,
//               height: 1.35,
//               color: const Color(0xFF222222),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreUi {
//   _TyreUi({
//     required this.label,
//     required this.treadDepth,
//     required this.tyreStatus,
//     required this.damageValue,
//     required this.damageStatus,
//     required this.pressureValue,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//     required this.summary,
//   });

//   final String label;
//   final String treadDepth;
//   final String tyreStatus;

//   final String damageValue;
//   final String damageStatus;

//   final String pressureValue;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;

//   final String summary;
// }


// class GenerateReportScreen extends StatefulWidget {
//   const GenerateReportScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.vin,
//     required this.frontLeftTyreId,
//     required this.frontRightTyreId,
//     required this.backLeftTyreId,
//     required this.backRightTyreId,
//     this.vehicleType = 'car',
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String userId;
//   final String vehicleId;
//   final String token;

//   final String vin;

//   final String frontLeftTyreId;
//   final String frontRightTyreId;
//   final String backLeftTyreId;
//   final String backRightTyreId;

//   final String vehicleType;

//   @override
//   State<GenerateReportScreen> createState() => _GenerateReportScreenState();
// }

// class _GenerateReportScreenState extends State<GenerateReportScreen> {
//   bool _fired = false;
//   bool _navigated = false;

//   m.ResponseFourWheeler? _apiResponse;

//   VideoPlayerController? _videoCtrl;
//   String _currentUrl = '';

//   @override
//   void initState() {
//     super.initState();

//     // 1) fetch ads immediately (silent)
//     context.read<AuthBloc>().add(AdsFetchRequested(token: widget.token, silent: true));

//     // 2) fire your four-wheeler upload immediately
//     _startUpload();
//   }

//   void _startUpload() {
//     if (_fired) return;
//     _fired = true;

//     context.read<AuthBloc>().add(
//       UploadFourWheelerRequested(
//         vehicleId: widget.vehicleId,
//         vehicleType: widget.vehicleType,
//         vin: widget.vin,
//         frontLeftTyreId: widget.frontLeftTyreId,
//         frontRightTyreId: widget.frontRightTyreId,
//         backLeftTyreId: widget.backLeftTyreId,
//         backRightTyreId: widget.backRightTyreId,
//         frontLeftPath: widget.frontLeftPath,
//         frontRightPath: widget.frontRightPath,
//         backLeftPath: widget.backLeftPath,
//         backRightPath: widget.backRightPath,
//       ),
//     );
//   }

//   Future<void> _playVideo(String url) async {
//     final u = url.trim();
//     if (u.isEmpty) return;
//     if (_currentUrl == u && _videoCtrl != null) return;

//     _currentUrl = u;

//     try {
//       final old = _videoCtrl;

//       final ctrl = VideoPlayerController.networkUrl(Uri.parse(u));

//       await ctrl.initialize();
//       await ctrl.setLooping(true);
//       await ctrl.play();

//       if (!mounted) {
//         await ctrl.dispose();
//         return;
//       }

//       setState(() => _videoCtrl = ctrl);
//       await old?.dispose();
//     } catch (_) {}
//   }

//   void _navigateToResult() {
//     if (!mounted || _navigated) return;
//     _navigated = true;

//     final vc = _videoCtrl;
//     _videoCtrl = null;
//     vc?.dispose();

//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (_) => InspectionResultScreen(
//           frontLeftPath: widget.frontLeftPath,
//           frontRightPath: widget.frontRightPath,
//           backLeftPath: widget.backLeftPath,
//           backRightPath: widget.backRightPath,
//           vehicleId: widget.vehicleId,
//           userId: widget.userId,
//           token: widget.token,
//           response: _apiResponse,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     final vc = _videoCtrl;
//     _videoCtrl = null;
//     vc?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: MultiBlocListener(
//         listeners: [
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) =>
//                 p.selectedAd?.media != c.selectedAd?.media || p.adsStatus != c.adsStatus,
//             listener: (context, state) {
//               final media = state.selectedAd?.media ?? '';
//               if (media.trim().isNotEmpty) {
//                 _playVideo(media);
//               }
//             },
//           ),
//           BlocListener<AuthBloc, AuthState>(
//             listenWhen: (p, c) => p.fourWheelerStatus != c.fourWheelerStatus,
//             listener: (context, state) {
//               if (state.fourWheelerStatus == FourWheelerStatus.success) {
//                 _apiResponse = state.fourWheelerResponse;
//                 _navigateToResult();
//               }
//               if (state.fourWheelerStatus == FourWheelerStatus.failure) {
//                 // keep silent
//               }
//             },
//           ),
//         ],
//         child: _FullscreenVideoOnly(controller: _videoCtrl),
//       ),
//     );
//   }
// }

// class _FullscreenVideoOnly extends StatelessWidget {
//   const _FullscreenVideoOnly({required this.controller});
//   final VideoPlayerController? controller;

//   @override
//   Widget build(BuildContext context) {
//     final c = controller;

//     if (c == null || !c.value.isInitialized) {
//       return const ColoredBox(color: Colors.black);
//     }

//     return SizedBox.expand(
//       child: FittedBox(
//         fit: BoxFit.cover,
//         child: SizedBox(
//           width: c.value.size.width,
//           height: c.value.size.height,
//           child: VideoPlayer(c),
//         ),
//       ),
//     );
//   }
// }

// class _AdVideoBackground extends StatelessWidget {
//   const _AdVideoBackground({required this.controller});
//   final VideoPlayerController? controller;

//   @override
//   Widget build(BuildContext context) {
//     final c = controller;
//     if (c == null || !c.value.isInitialized) {
//       return Container(
//         color: Colors.black,
//         child: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     return FittedBox(
//       fit: BoxFit.cover,
//       child: SizedBox(
//         width: c.value.size.width,
//         height: c.value.size.height,
//         child: VideoPlayer(c),
//       ),
//     );
//   }
// }

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


/*
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

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

    // ✅ keep your existing behavior
    try {
      final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
      if (userid != null && userid.isNotEmpty) {
        context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    final raw =
        widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? const <String, dynamic>{};

    // ✅ unwrap {data:{...}} / {result:{...}} / {payload:{...}} (even nested)
    final data = _unwrapApiRoot(raw);

    // ✅ chip order fixed: Left, Front, Back, Right
    final tyreByChipIndex = <int, _TyreUi>{
      0: _buildTyreUi(data, label: 'Front Left', keyPrefix: 'Front Left'),
      1: _buildTyreUi(data, label: 'Front Right', keyPrefix: 'Front Right'),
      2: _buildTyreUi(data, label: 'Back Left', keyPrefix: 'Back Left'),
      3: _buildTyreUi(data, label: 'Back Right', keyPrefix: 'Back Right'),
    };

    final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

    final flImg = _imgProvider(
      localPath: widget.frontLeftPath,
      apiValue: _pickAnyDeep(data, const ['Front Left wheel', 'frontLeftWheelUrl', 'front_left_wheel_url']),
    );
    final frImg = _imgProvider(
      localPath: widget.frontRightPath,
      apiValue: _pickAnyDeep(data, const ['Front Right wheel', 'frontRightWheelUrl', 'front_right_wheel_url']),
    );
    final blImg = _imgProvider(
      localPath: widget.backLeftPath,
      apiValue: _pickAnyDeep(data, const ['Back Left wheel', 'backLeftWheelUrl', 'back_left_wheel_url']),
    );
    final brImg = _imgProvider(
      localPath: widget.backRightPath,
      apiValue: _pickAnyDeep(data, const ['Back Right wheel', 'backRightWheelUrl', 'back_right_wheel_url']),
    );

    final wheelImages = <_WheelCardData>[
      _WheelCardData(image: flImg, label: 'left'),
      _WheelCardData(image: frImg, label: 'Front'),
      _WheelCardData(image: blImg, label: 'Back'),
      _WheelCardData(image: brImg, label: 'Right'),
    ];

    // ✅ show ONLY selected tyre summary + full pressure details (same UI)
    final summaryText = _composeSelectedSummary(selectedTyre);

    return Scaffold(
      backgroundColor: _bg,
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
              SizedBox(height: 12 * s),

              _TyreChips(
                s: s,
                labels: const ['Left', 'Front', 'Back', 'Right'],
                selected: _selected,
                gradient: _brandGrad,
                onSelect: (i) => setState(() => _selected = i),
              ),

              SizedBox(height: 14 * s),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _BigTreadCard(
                            s: s,
                            gradient: _brandGrad,
                            treadValue: selectedTyre.treadDepth,
                            treadStatus: selectedTyre.tyreStatus,
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          flex: 10,
                          child: Column(
                            children: [
                              _SmallMetricCard(
                                s: s,
                                title: 'Tire Pressure',
                                value: 'Value: ${selectedTyre.pressureValue}',
                                status: 'Status: ${selectedTyre.pressureStatus}',
                              ),
                              SizedBox(height: 12 * s),
                              _SmallMetricCard(
                                s: s,
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

                    SizedBox(height: 10 * s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ IMPORTANT: this now matches your API EXACTLY
  _TyreUi _buildTyreUi(
    Map<String, dynamic> data, {
    required String label,
    required String keyPrefix,
  }) {
    final treadDepth = _asNonEmptyString(_pickAnyDeep(data, [
      '$keyPrefix Tread depth',
      '$keyPrefix Tread Depth',
      '${keyPrefix}_tread_depth',
      '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_tread_depth',
    ]));

    final tyreStatus = _asNonEmptyString(_pickAnyDeep(data, [
      '$keyPrefix Tyre status',
      '$keyPrefix Tire status',
      '$keyPrefix tyre status',
      '$keyPrefix tire status',
    ]));

    final damageValue = _asNonEmptyString(_pickAnyDeep(data, [
      '$keyPrefix wear patterns',
      '$keyPrefix Wear patterns',
      '$keyPrefix wearPatterns',
      '${keyPrefix}_wear_patterns',
    ]));

    // ✅ "Front Left Tire pressure": { status, reason, confidence }
    final pressureObj = _pickAnyDeep(data, [
      '$keyPrefix Tire pressure',
      '$keyPrefix Tyre pressure',
      '$keyPrefix tire pressure',
      '$keyPrefix tyre pressure',
      '$keyPrefix Tire Pressure',
    ]);

    String pressureStatus = '—';
    String pressureReason = '';
    String pressureConfidence = '';
    String pressureValue = '—';

    if (pressureObj is Map) {
      final m = Map<String, dynamic>.from(pressureObj);

      pressureStatus = _asNonEmptyString(m['status']) ?? '—';
      pressureReason = _asNonEmptyString(m['reason']) ?? '';
      pressureConfidence = _asNonEmptyString(m['confidence']) ?? '';

      // If API doesn't provide numeric psi, use status as displayed value
      pressureValue = _asNonEmptyString(m['value']) ??
          _asNonEmptyString(m['psi']) ??
          pressureStatus;
    } else {
      final s = _asNonEmptyString(pressureObj);
      if (s != null) {
        pressureStatus = s;
        pressureValue = s;
      }
    }

    // ✅ "Front Left Summary": "...."
    final summary = _asNonEmptyString(_pickAnyDeep(data, [
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
      pressureValue: pressureValue,
      pressureStatus: pressureStatus,
      pressureReason: pressureReason,
      pressureConfidence: pressureConfidence,
      summary: summary ?? '—',
    );
  }

  // ✅ One text block (UI unchanged) but includes full tyre-pressure details too
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
        if (t.pressureConfidence.trim().isNotEmpty) '• Confidence: ${t.pressureConfidence}',
      ].join('\n'));
    }

    return parts.isEmpty ? '—' : parts.join('\n\n');
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  Map<String, dynamic> _unwrapApiRoot(Map<String, dynamic> raw) {
    Map<String, dynamic> cur = raw;
    for (int i = 0; i < 5; i++) {
      final next = _tryReadMap(cur, const ['data', 'result', 'payload']);
      if (next == null) break;
      cur = next;
    }
    return cur;
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

  String? _asNonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  // ✅ FIX: strongest key matching (removes ALL non-alphanumeric)
  dynamic _pickAnyDeep(Map<String, dynamic> root, List<String> keys) {
    // 1) direct
    for (final k in keys) {
      if (root.containsKey(k)) return root[k];
    }

    // 2) normalized lookup
    String norm(String x) => x
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // 🔥 everything removed except letters/numbers

    final normalizedIndex = <String, String>{};
    for (final actual in root.keys) {
      normalizedIndex[norm(actual)] = actual;
    }

    for (final want in keys) {
      final hit = normalizedIndex[norm(want)];
      if (hit != null) return root[hit];
    }

    // 3) deep search in nested maps (some APIs nest fields)
    for (final v in root.values) {
      if (v is Map) {
        final found = _pickAnyDeep(Map<String, dynamic>.from(v), keys);
        if (found != null) return found;
      }
    }

    return null;
  }
}

// =============================
// UI WIDGETS (UNCHANGED)
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
  });

  final double s;
  final LinearGradient gradient;
  final String treadValue;
  final String treadStatus;

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
          Container(
            width: 62 * s,
            height: 62 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Image.asset("assets/thread_depth.png", height: 34, width: 34),
              ),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            'Tread Depth',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 20 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
            ),
          ),
          SizedBox(height: 12 * s),
          Text(
            'Value: $treadValue',
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
                width: 52 * s,
                height: 52 * s,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                child: Icon(Icons.description_outlined, color: Colors.white, size: 26 * s),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  'Report Summary:',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 26 * s,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 30 * s, color: const Color(0xFF111827)),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            tyre.label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w900,
              foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
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


// ✅ InspectionResultScreen (UPDATED)
// - UI stays SAME as your model screen
// - When you select Left/Front/Back/Right -> shows ONLY that tyre’s pressure + summary
// - Tire Pressure shows Value + Status on the card (like model)
// - Full pressure details (Status/Reason/Confidence) shown inside the SAME summary text (no layout change)
// - Fix: previously you were sending damageValue as summary. Now uses selectedTyre.summary.
// - Fix: data was showing "-" because API can be nested (data->data). Now unwrapped safely.

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';

// class InspectionResultScreen extends StatefulWidget {
//   const InspectionResultScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.vehicleId,
//     required this.userId,
//     required this.token,
//     this.response,
//     this.fourWheelerRaw,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final dynamic response;
//   final Map<String, dynamic>? fourWheelerRaw;

//   @override
//   State<InspectionResultScreen> createState() => _InspectionResultScreenState();
// }

// class _InspectionResultScreenState extends State<InspectionResultScreen> {
//   static const _bg = Color(0xFFF2F2F2);

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   int _selected = 0;

//   @override
//   void initState() {
//     super.initState();

//     // ✅ keep your existing behavior
//     try {
//       final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
//       if (userid != null && userid.isNotEmpty) {
//         context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
//       }
//     } catch (_) {
//       // ignore if bloc not available in this context
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     final raw =
//         widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? const <String, dynamic>{};

//     // ✅ Unwrap deep possible nests: {data:{data:{...}}} or {result:{...}} etc.
//     final data = _unwrapApiRoot(raw);

//     // ✅ IMPORTANT: chip order is ['Left','Front','Back','Right']
//     // Map to: Front Left, Front Right, Back Left, Back Right
//     final tyreByChipIndex = <int, _TyreUi>{
//       0: _buildTyreUi(data, label: 'Front Left', keyPrefix: 'Front Left'), // Left
//       1: _buildTyreUi(data, label: 'Front Right', keyPrefix: 'Front Right'), // Front
//       2: _buildTyreUi(data, label: 'Back Left', keyPrefix: 'Back Left'), // Back
//       3: _buildTyreUi(data, label: 'Back Right', keyPrefix: 'Back Right'), // Right
//     };

//     final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

//     // ---- images (api may return url/base64; fallback local paths)
//     final flImg = _imgProvider(
//       localPath: widget.frontLeftPath,
//       apiValue: _pickAnyLoose(data, const ['Front Left wheel', 'frontLeftWheelUrl', 'front_left_wheel_url']),
//     );
//     final frImg = _imgProvider(
//       localPath: widget.frontRightPath,
//       apiValue: _pickAnyLoose(data, const ['Front Right wheel', 'frontRightWheelUrl', 'front_right_wheel_url']),
//     );
//     final blImg = _imgProvider(
//       localPath: widget.backLeftPath,
//       apiValue: _pickAnyLoose(data, const ['Back Left wheel', 'backLeftWheelUrl', 'back_left_wheel_url']),
//     );
//     final brImg = _imgProvider(
//       localPath: widget.backRightPath,
//       apiValue: _pickAnyLoose(data, const ['Back Right wheel', 'backRightWheelUrl', 'back_right_wheel_url']),
//     );

//     final wheelImages = <_WheelCardData>[
//       _WheelCardData(image: flImg, label: 'left'),
//       _WheelCardData(image: frImg, label: 'Front'),
//       _WheelCardData(image: blImg, label: 'Back'),
//       _WheelCardData(image: brImg, label: 'Right'),
//     ];

//     // ✅ Full pressure details text (NO UI layout change: still a single summary paragraph)
//     final pressureDetailsText = _buildPressureDetailsText(selectedTyre);

//     // ✅ Summary shown is TYRE-wise summary only
//     final tyreWiseSummary = selectedTyre.summary == '—' ? '' : selectedTyre.summary;

//     // ✅ Combine: tyre summary + pressure details (still ONE Text widget)
//     final summaryText = [
//       if (tyreWiseSummary.trim().isNotEmpty) tyreWiseSummary.trim(),
//       if (pressureDetailsText.trim().isNotEmpty) pressureDetailsText.trim(),
//     ].join('\n\n');

//     return Scaffold(
//       backgroundColor: _bg,
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
//           child: Column(
//             children: [
//               // ======= TOP IMAGES (like model) =======
//               SizedBox(
//                 height: 190 * s,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: wheelImages.length,
//                   separatorBuilder: (_, __) => SizedBox(width: 12 * s),
//                   itemBuilder: (_, i) {
//                     final item = wheelImages[i];
//                     return _WheelImageCard(
//                       s: s,
//                       image: item.image,
//                       label: item.label,
//                       gradient: _brandGrad,
//                     );
//                   },
//                 ),
//               ),

//               SizedBox(height: 12 * s),

//               // ======= CHIPS (same style) =======
//               _TyreChips(
//                 s: s,
//                 labels: const ['Left', 'Front', 'Back', 'Right'],
//                 selected: _selected,
//                 gradient: _brandGrad,
//                 onSelect: (i) => setState(() => _selected = i),
//               ),

//               SizedBox(height: 14 * s),

//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     // ======= METRIC CARDS (same layout) =======
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           flex: 11,
//                           child: _BigTreadCard(
//                             s: s,
//                             gradient: _brandGrad,
//                             treadValue: selectedTyre.treadDepth,
//                             treadStatus: selectedTyre.tyreStatus,
//                           ),
//                         ),
//                         SizedBox(width: 12 * s),
//                         Expanded(
//                           flex: 10,
//                           child: Column(
//                             children: [
//                               // ✅ Tire Pressure: show Value + Status (like model)
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Tire Pressure',
//                                 value: 'Value: ${selectedTyre.pressureValue}',
//                                 status: 'Status: ${selectedTyre.pressureStatus}',
//                               ),
//                               SizedBox(height: 12 * s),
//                               // ✅ Damage Check: show Value + Status (like model)
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Damage Check',
//                                 value: 'Value: ${selectedTyre.damageValue}',
//                                 status: 'Status: ${selectedTyre.damageStatus}',
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),

//                     SizedBox(height: 16 * s),

//                     // ✅ REPORT SUMMARY: ONLY selected tyre summary + pressure details (same card)
//                     _ReportSummaryCard(
//                       s: s,
//                       gradient: _brandGrad,
//                       tyre: selectedTyre,
//                       summary: summaryText.isEmpty ? '—' : summaryText,
//                     ),

//                     SizedBox(height: 10 * s),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // -----------------------------
//   // Build per-tyre UI from API map
//   // -----------------------------
//   _TyreUi _buildTyreUi(
//     Map<String, dynamic> data, {
//     required String label,
//     required String keyPrefix,
//   }) {
//     final treadDepth = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Tread depth',
//       '$keyPrefix Tread Depth',
//       '${keyPrefix}_tread_depth',
//       '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_tread_depth',
//     ]));

//     final tyreStatus = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Tyre status',
//       '$keyPrefix Tire status',
//       '$keyPrefix tyre status',
//       '$keyPrefix tire status',
//     ]));

//     final damageValue = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix wear patterns',
//       '$keyPrefix Wear patterns',
//       '$keyPrefix wearPatterns',
//       '${keyPrefix}_wear_patterns',
//     ]));

//     // ✅ Pressure object EXACT from your API:
//     // "Front Left Tire pressure": { status, reason, confidence }
//     final pressureObj = _pickAnyLoose(data, [
//       '$keyPrefix Tire pressure',
//       '$keyPrefix Tyre pressure',
//       '$keyPrefix tire pressure',
//       '$keyPrefix tyre pressure',
//     ]);

//     String? pressureStatus;
//     String? pressureReason;
//     String? pressureConfidence;
//     String? pressureValue;

//     if (pressureObj is Map) {
//       final m = Map<String, dynamic>.from(pressureObj);
//       pressureStatus = _asNonEmptyString(m['status']);
//       pressureReason = _asNonEmptyString(m['reason']);
//       pressureConfidence = _asNonEmptyString(m['confidence']);

//       // API usually doesn't provide PSI number, so keep same behavior:
//       // show psi/value if ever exists, otherwise show status as "Value"
//       pressureValue = _asNonEmptyString(m['value']) ??
//           _asNonEmptyString(m['psi']) ??
//           pressureStatus;
//     } else {
//       pressureStatus = _asNonEmptyString(pressureObj);
//       pressureValue = pressureStatus;
//     }

//     // ✅ Summary EXACT from your API:
//     // "Front Left Summary": "...."
//     final summary = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Summary',
//       '$keyPrefix summary',
//       '${keyPrefix}_summary',
//       '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_summary',
//     ]));

//     return _TyreUi(
//       label: label,
//       treadDepth: treadDepth ?? '—',
//       tyreStatus: tyreStatus ?? '—',
//       damageValue: damageValue ?? '—',
//       damageStatus: tyreStatus ?? '—',
//       pressureValue: pressureValue ?? '—',
//       pressureStatus: pressureStatus ?? '—',
//       pressureReason: pressureReason ?? '',
//       pressureConfidence: pressureConfidence ?? '',
//       summary: summary ?? '—',
//     );
//   }

//   // ✅ build the pressure details as shown in your “full details” screenshot (text only)
//   String _buildPressureDetailsText(_TyreUi t) {
//     final hasAny =
//         t.pressureStatus.trim().isNotEmpty ||
//         t.pressureReason.trim().isNotEmpty ||
//         t.pressureConfidence.trim().isNotEmpty;

//     if (!hasAny || (t.pressureStatus == '—' && t.pressureReason.isEmpty && t.pressureConfidence.isEmpty)) {
//       return '';
//     }

//     final lines = <String>[
//       'Tire pressure:',
//       '• Status: ${t.pressureStatus}',
//       if (t.pressureReason.trim().isNotEmpty) '• Reason: ${t.pressureReason}',
//       if (t.pressureConfidence.trim().isNotEmpty) '• Confidence: ${t.pressureConfidence}',
//     ];

//     return lines.join('\n');
//   }

//   // -----------------------------
//   // Helpers
//   // -----------------------------
//   Map<String, dynamic> _unwrapApiRoot(Map<String, dynamic> raw) {
//     Map<String, dynamic> cur = raw;
//     // try few layers safely
//     for (int i = 0; i < 4; i++) {
//       final next = _tryReadMap(cur, const ['data', 'result', 'payload']);
//       if (next == null) break;
//       cur = next;
//     }
//     return cur;
//   }

//   ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
//     final apiStr = _asNonEmptyString(apiValue);
//     if (apiStr != null) {
//       if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
//         return NetworkImage(apiStr);
//       }
//       if (apiStr.startsWith('data:image')) {
//         try {
//           final base64Part = apiStr.split(',').last;
//           final bytes = base64Decode(base64Part);
//           return MemoryImage(bytes);
//         } catch (_) {}
//       }
//     }
//     return FileImage(File(localPath));
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;
//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);

//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map<String, dynamic>) return j;
//       if (j is Map) return Map<String, dynamic>.from(j);
//     } catch (_) {}

//     try {
//       final encoded = jsonEncode(obj);
//       final decoded = jsonDecode(encoded);
//       if (decoded is Map<String, dynamic>) return decoded;
//       if (decoded is Map) return Map<String, dynamic>.from(decoded);
//     } catch (_) {}

//     return null;
//   }

//   Map<String, dynamic>? _tryReadMap(Map<String, dynamic> root, List<String> keys) {
//     for (final k in keys) {
//       final v = root[k];
//       if (v is Map<String, dynamic>) return v;
//       if (v is Map) return Map<String, dynamic>.from(v);
//     }
//     return null;
//   }

//   String? _asNonEmptyString(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return null;
//     return s;
//   }

//   // ✅ Loose key matcher (handles spaces/case/underscore/dash)
//   dynamic _pickAnyLoose(Map<String, dynamic> root, List<String> keys) {
//     // direct check first
//     for (final k in keys) {
//       if (root.containsKey(k)) return root[k];
//     }
//     // loose check
//     String norm(String x) => x.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
//     final mapNorm = <String, String>{};
//     for (final actual in root.keys) {
//       mapNorm[norm(actual)] = actual;
//     }
//     for (final want in keys) {
//       final hit = mapNorm[norm(want)];
//       if (hit != null) return root[hit];
//     }
//     return null;
//   }
// }

// // =============================
// // MODEL UI WIDGETS (UI unchanged)
// // =============================

// class _WheelCardData {
//   const _WheelCardData({required this.image, required this.label});
//   final ImageProvider image;
//   final String label;
// }

// class _WheelImageCard extends StatelessWidget {
//   const _WheelImageCard({
//     required this.s,
//     required this.image,
//     required this.label,
//     required this.gradient,
//   });

//   final double s;
//   final ImageProvider image;
//   final String label;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 120 * s,
//       child: Column(
//         children: [
//           Container(
//             height: 140 * s,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(18 * s),
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(18 * s),
//               child: Image(image: image, fit: BoxFit.cover),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.symmetric(vertical: 8 * s),
//             decoration: BoxDecoration(
//               gradient: gradient,
//               borderRadius: BorderRadius.circular(10 * s),
//             ),
//             child: Center(
//               child: Text(
//                 label,
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w900,
//                   fontSize: 14 * s,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreChips extends StatelessWidget {
//   const _TyreChips({
//     super.key,
//     required this.s,
//     required this.labels,
//     required this.selected,
//     required this.gradient,
//     required this.onSelect,
//   });

//   final double s;
//   final List<String> labels;
//   final int selected;
//   final LinearGradient gradient;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: List.generate(labels.length, (i) {
//         final isSel = i == selected;
//         return Expanded(
//           child: Padding(
//             padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
//             child: InkWell(
//               onTap: () => onSelect(i),
//               borderRadius: BorderRadius.circular(12 * s),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding: EdgeInsets.symmetric(vertical: 10 * s),
//                 decoration: BoxDecoration(
//                   gradient: isSel ? gradient : null,
//                   color: isSel ? null : Colors.white,
//                   borderRadius: BorderRadius.circular(12 * s),
//                   border: Border.all(
//                     color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(isSel ? .10 : .05),
//                       blurRadius: isSel ? 16 : 10,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     labels[i],
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 13.5 * s,
//                       fontWeight: FontWeight.w900,
//                       color: isSel ? Colors.white : const Color(0xFF111827),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

// class _BigTreadCard extends StatelessWidget {
//   const _BigTreadCard({
//     required this.s,
//     required this.gradient,
//     required this.treadValue,
//     required this.treadStatus,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final String treadValue;
//   final String treadStatus;

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
//           Container(
//             width: 62 * s,
//             height: 62 * s,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 )
//               ],
//             ),
//             child: Center(
//               child: ShaderMask(
//                 shaderCallback: (r) => gradient.createShader(r),
//                 child: Image.asset("assets/thread_depth.png", height: 34, width: 34),
//               ),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Tread Depth',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Value: $treadValue',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Status: $treadStatus',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//           SizedBox(height: 8 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//     required this.gradient,
//     required this.tyre,
//     required this.summary,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final _TyreUi tyre;
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
//             color: Colors.black.withOpacity(.10),
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
//               Container(
//                 width: 52 * s,
//                 height: 52 * s,
//                 decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
//                 child: Icon(Icons.description_outlined, color: Colors.white, size: 26 * s),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: Text(
//                   'Report Summary:',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 26 * s,
//                     fontWeight: FontWeight.w900,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//               ),
//               Icon(Icons.chevron_right_rounded, size: 30 * s, color: const Color(0xFF111827)),
//             ],
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             tyre.label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w600,
//               height: 1.35,
//               color: const Color(0xFF222222),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // =============================
// // Data holder
// // =============================
// class _TyreUi {
//   _TyreUi({
//     required this.label,
//     required this.treadDepth,
//     required this.tyreStatus,
//     required this.damageValue,
//     required this.damageStatus,
//     required this.pressureValue,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//     required this.summary,
//   });

//   final String label;

//   final String treadDepth;
//   final String tyreStatus;

//   final String damageValue;
//   final String damageStatus;

//   final String pressureValue;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;

//   final String summary;
// }



// class InspectionResultScreen extends StatefulWidget {
//   const InspectionResultScreen({
//     super.key,
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,
//     required this.vehicleId,
//     required this.userId,
//     required this.token,
//     this.response,
//     this.fourWheelerRaw,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final dynamic response;
//   final Map<String, dynamic>? fourWheelerRaw;

//   @override
//   State<InspectionResultScreen> createState() => _InspectionResultScreenState();
// }

// class _InspectionResultScreenState extends State<InspectionResultScreen> {
//   static const _bg = Color(0xFFF2F2F2);

//   static const LinearGradient _brandGrad = LinearGradient(
//     colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   int _selected = 0;

//   @override
//   void initState() {
//     super.initState();

//     // ✅ keep your existing behavior
//     try {
//       final userid = context.read<AuthBloc>().state.profile?.userId?.toString();
//       if (userid != null && userid.isNotEmpty) {
//         context.read<AuthBloc>().add(FetchTyreHistoryRequested(userId: userid));
//       }
//     } catch (_) {
//       // ignore if bloc not available in this context
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     final raw =
//         widget.fourWheelerRaw ?? _safeToJson(widget.response) ?? const <String, dynamic>{};

//     // API shape: { data: {...} }
//     final data = _tryReadMap(raw, const ['data', 'result', 'payload']) ?? raw;

//     // ✅ IMPORTANT: chip order is ['Left','Front','Back','Right']
//     // and must map to: Front Left, Front Right, Back Left, Back Right
//     final tyreByChipIndex = <int, _TyreUi>{
//       0: _buildTyreUi(data, label: 'Front Left', keyPrefix: 'Front Left'), // Left
//       1: _buildTyreUi(data, label: 'Front Right', keyPrefix: 'Front Right'), // Front
//       2: _buildTyreUi(data, label: 'Back Left', keyPrefix: 'Back Left'), // Back
//       3: _buildTyreUi(data, label: 'Back Right', keyPrefix: 'Back Right'), // Right
//     };

//     final tyres = tyreByChipIndex.values.toList();
//     final selectedTyre = tyreByChipIndex[_selected] ?? tyreByChipIndex[0]!;

//     // ---- images (api may return url/base64; fallback local paths)
//     final flImg = _imgProvider(
//       localPath: widget.frontLeftPath,
//       apiValue: _pickAnyLoose(data, const ['Front Left wheel', 'frontLeftWheelUrl', 'front_left_wheel_url']),
//     );
//     final frImg = _imgProvider(
//       localPath: widget.frontRightPath,
//       apiValue: _pickAnyLoose(data, const ['Front Right wheel', 'frontRightWheelUrl', 'front_right_wheel_url']),
//     );
//     final blImg = _imgProvider(
//       localPath: widget.backLeftPath,
//       apiValue: _pickAnyLoose(data, const ['Back Left wheel', 'backLeftWheelUrl', 'back_left_wheel_url']),
//     );
//     final brImg = _imgProvider(
//       localPath: widget.backRightPath,
//       apiValue: _pickAnyLoose(data, const ['Back Right wheel', 'backRightWheelUrl', 'back_right_wheel_url']),
//     );

//     final wheelImages = <_WheelCardData>[
//       _WheelCardData(image: flImg, label: 'left'),
//       _WheelCardData(image: frImg, label: 'Front'),
//       _WheelCardData(image: blImg, label: 'Back'),
//       _WheelCardData(image: brImg, label: 'Right'),
//     ];

//     return Scaffold(
//       backgroundColor: _bg,
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
//           child: Column(
//             children: [
//               // ======= TOP IMAGES (like model) =======
//               SizedBox(
//                 height: 190 * s,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: wheelImages.length,
//                   separatorBuilder: (_, __) => SizedBox(width: 12 * s),
//                   itemBuilder: (_, i) {
//                     final item = wheelImages[i];
//                     return _WheelImageCard(
//                       s: s,
//                       image: item.image,
//                       label: item.label,
//                       gradient: _brandGrad,
//                     );
//                   },
//                 ),
//               ),

//               SizedBox(height: 12 * s),

//               // ======= CHIPS (same style) =======
//               _TyreChips(
//                 s: s,
//                 labels: const ['Left', 'Front', 'Back', 'Right'],
//                 selected: _selected,
//                 gradient: _brandGrad,
//                 onSelect: (i) => setState(() => _selected = i),
//               ),

//               SizedBox(height: 14 * s),

//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     // ======= METRIC CARDS (same layout) =======
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           flex: 11,
//                           child: _BigTreadCard(
//                             s: s,
//                             gradient: _brandGrad,
//                             treadValue: selectedTyre.treadDepth,
//                             treadStatus: selectedTyre.tyreStatus,
//                           ),
//                         ),
//                         SizedBox(width: 12 * s),
//                         Expanded(
//                           flex: 10,
//                           child: Column(
//                             children: [
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Tire Pressure',
//                                 // value: selectedTyre.pressureValue == '—'
//                                 //     ? 'Value: —'
//                                 //     : 'Value: ${selectedTyre.pressureValue}',
//                                 status: 'Status: ${selectedTyre.pressureStatus}',
//                               ),
//                               SizedBox(height: 12 * s),
//                               _SmallMetricCard(
//                                 s: s,
//                                 title: 'Damage Check',
//                               //  value: 'Value: ${selectedTyre.damageValue}',
//                                 status: 'Status: ${selectedTyre.damageStatus}',
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),

//                     SizedBox(height: 16 * s),

//                     // ✅ REPORT SUMMARY: show ONLY selected tyre summary (UI same card)
//                     _ReportSummaryCard(
//                       summary: selectedTyre.damageValue,
//                       s: s,
//                       gradient: _brandGrad,
//                       tyre: selectedTyre,
//                     ),

//                     SizedBox(height: 10 * s),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // -----------------------------
//   // Build per-tyre UI from API map
//   // -----------------------------
//   _TyreUi _buildTyreUi(
//     Map<String, dynamic> data, {
//     required String label,
//     required String keyPrefix,
//   }) {
//     final treadDepth = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Tread depth',
//       '$keyPrefix Tread Depth',
//       '${keyPrefix}_tread_depth',
//       '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_tread_depth',
//     ]));

//     final tyreStatus = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Tyre status',
//       '$keyPrefix Tire status',
//       '$keyPrefix tyre status',
//       '$keyPrefix tire status',
//     ]));

//     final damageValue = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix wear patterns',
//       '$keyPrefix Wear patterns',
//       '$keyPrefix wearPatterns',
//       '${keyPrefix}_wear_patterns',
//     ]));

//     // ✅ Pressure object EXACT from your API:
//     // "Front Left Tire pressure": { status, reason, confidence }
//     final pressureObj = _pickAnyLoose(data, [
//       '$keyPrefix Tire pressure',
//       '$keyPrefix Tyre pressure',
//     ]);

//     String? pressureStatus;
//     String? pressureReason;
//     String? pressureConfidence;

//     // ✅ Value shown in UI (API doesn't provide psi/value -> use status as "Value")
//     String? pressureValue;

//     if (pressureObj is Map) {
//       final m = Map<String, dynamic>.from(pressureObj);
//       pressureStatus = _asNonEmptyString(m['status']);
//       pressureReason = _asNonEmptyString(m['reason']);
//       pressureConfidence = _asNonEmptyString(m['confidence']);

//       pressureValue =
//           _asNonEmptyString(m['value']) ?? _asNonEmptyString(m['psi']) ?? pressureStatus;
//     } else {
//       pressureStatus = _asNonEmptyString(pressureObj);
//       pressureValue = pressureStatus;
//     }

//     // ✅ Summary EXACT from your API:
//     // "Front Left Summary": "...."
//     final summary = _asNonEmptyString(_pickAnyLoose(data, [
//       '$keyPrefix Summary',
//       '$keyPrefix summary',
//       '${keyPrefix}_summary',
//       '${keyPrefix.toLowerCase().replaceAll(' ', '_')}_summary',
//     ]));

//     return _TyreUi(
//       label: label,
//       treadDepth: treadDepth ?? '—',
//       tyreStatus: tyreStatus ?? '—',
//       damageValue: damageValue ?? '—',
//       damageStatus: tyreStatus ?? '—',
//       pressureValue: pressureValue ?? '—',
//       pressureStatus: pressureStatus ?? '—',
//       pressureReason: pressureReason ?? '',
//       pressureConfidence: pressureConfidence ?? '',
//       summary: summary ?? '—',
//     );
//   }

//   // -----------------------------
//   // Helpers (same behavior)
//   // -----------------------------
//   ImageProvider _imgProvider({required String localPath, dynamic apiValue}) {
//     final apiStr = _asNonEmptyString(apiValue);
//     if (apiStr != null) {
//       if (apiStr.startsWith('http://') || apiStr.startsWith('https://')) {
//         return NetworkImage(apiStr);
//       }
//       if (apiStr.startsWith('data:image')) {
//         try {
//           final base64Part = apiStr.split(',').last;
//           final bytes = base64Decode(base64Part);
//           return MemoryImage(bytes);
//         } catch (_) {}
//       }
//     }
//     return FileImage(File(localPath));
//   }

//   Map<String, dynamic>? _safeToJson(dynamic obj) {
//     if (obj == null) return null;
//     if (obj is Map<String, dynamic>) return obj;
//     if (obj is Map) return Map<String, dynamic>.from(obj);

//     try {
//       final j = (obj as dynamic).toJson();
//       if (j is Map<String, dynamic>) return j;
//       if (j is Map) return Map<String, dynamic>.from(j);
//     } catch (_) {}

//     try {
//       final encoded = jsonEncode(obj);
//       final decoded = jsonDecode(encoded);
//       if (decoded is Map<String, dynamic>) return decoded;
//       if (decoded is Map) return Map<String, dynamic>.from(decoded);
//     } catch (_) {}

//     return null;
//   }

//   Map<String, dynamic>? _tryReadMap(Map<String, dynamic> root, List<String> keys) {
//     for (final k in keys) {
//       final v = root[k];
//       if (v is Map<String, dynamic>) return v;
//       if (v is Map) return Map<String, dynamic>.from(v);
//     }
//     return null;
//   }

//   String? _asNonEmptyString(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     if (s.isEmpty || s == 'null') return null;
//     return s;
//   }

//   // ✅ New: loose key matcher (handles spaces/case)
//   dynamic _pickAnyLoose(Map<String, dynamic> root, List<String> keys) {
//     // direct check first
//     for (final k in keys) {
//       if (root.containsKey(k)) return root[k];
//     }
//     // loose check
//     String norm(String x) => x.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
//     final mapNorm = <String, String>{};
//     for (final actual in root.keys) {
//       mapNorm[norm(actual)] = actual;
//     }
//     for (final want in keys) {
//       final hit = mapNorm[norm(want)];
//       if (hit != null) return root[hit];
//     }
//     return null;
//   }
// }

// // =============================
// // MODEL UI WIDGETS (UI unchanged)
// // =============================

// class _WheelCardData {
//   const _WheelCardData({required this.image, required this.label});
//   final ImageProvider image;
//   final String label;
// }

// class _WheelImageCard extends StatelessWidget {
//   const _WheelImageCard({
//     required this.s,
//     required this.image,
//     required this.label,
//     required this.gradient,
//   });

//   final double s;
//   final ImageProvider image;
//   final String label;
//   final LinearGradient gradient;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 120 * s,
//       child: Column(
//         children: [
//           Container(
//             height: 140 * s,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(18 * s),
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(18 * s),
//               child: Image(image: image, fit: BoxFit.cover),
//             ),
//           ),
//           SizedBox(height: 10 * s),
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.symmetric(vertical: 8 * s),
//             decoration: BoxDecoration(
//               gradient: gradient,
//               borderRadius: BorderRadius.circular(10 * s),
//             ),
//             child: Center(
//               child: Text(
//                 label,
//                 style: TextStyle(
//                   fontFamily: 'ClashGrotesk',
//                   fontWeight: FontWeight.w900,
//                   fontSize: 14 * s,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TyreChips extends StatelessWidget {
//   const _TyreChips({
//     super.key,
//     required this.s,
//     required this.labels,
//     required this.selected,
//     required this.gradient,
//     required this.onSelect,
//   });

//   final double s;
//   final List<String> labels;
//   final int selected;
//   final LinearGradient gradient;
//   final ValueChanged<int> onSelect;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: List.generate(labels.length, (i) {
//         final isSel = i == selected;
//         return Expanded(
//           child: Padding(
//             padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10 * s),
//             child: InkWell(
//               onTap: () => onSelect(i),
//               borderRadius: BorderRadius.circular(12 * s),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding: EdgeInsets.symmetric(vertical: 10 * s),
//                 decoration: BoxDecoration(
//                   gradient: isSel ? gradient : null,
//                   color: isSel ? null : Colors.white,
//                   borderRadius: BorderRadius.circular(12 * s),
//                   border: Border.all(
//                     color: isSel ? Colors.transparent : const Color(0xFFE7E7E7),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(isSel ? .10 : .05),
//                       blurRadius: isSel ? 16 : 10,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     labels[i],
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontSize: 13.5 * s,
//                       fontWeight: FontWeight.w900,
//                       color: isSel ? Colors.white : const Color(0xFF111827),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       }),
//     );
//   }
// }

// class _BigTreadCard extends StatelessWidget {
//   const _BigTreadCard({
//     required this.s,
//     required this.gradient,
//     required this.treadValue,
//     required this.treadStatus,
//   });

//   final double s;
//   final LinearGradient gradient;
//   final String treadValue;
//   final String treadStatus;

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
//           // icon circle
//           Container(
//             width: 62 * s,
//             height: 62 * s,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.10),
//                   blurRadius: 18,
//                   offset: const Offset(0, 10),
//                 )
//               ],
//             ),
//             child: Center(
//               child: ShaderMask(
//                 shaderCallback: (r) => gradient.createShader(r),
//                 child: Image.asset(
//                   "assets/thread_depth.png",
//                   height: 34,
//                   width: 34,
//                 ),
//               ),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Tread Depth',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()
//                 ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 200, 40)),
//             ),
//           ),
//           SizedBox(height: 12 * s),
//           Text(
//             'Value: $treadValue',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             'Status: $treadStatus',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//    /// required this.value,
//     required this.status,
//   });

//   final double s;
//   final String title;
//   //final String value;
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
//           // Text(
//           //   value,
//           //   style: TextStyle(
//           //     fontFamily: 'ClashGrotesk',
//           //     fontSize: 16 * s,
//           //     fontWeight: FontWeight.w700,
//           //     color: const Color(0xFF111827),
//           //   ),
//           // ),
//           // SizedBox(height: 8 * s),
//           Text(
//             status,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 16 * s,
//               fontWeight: FontWeight.w700,
//               color: const Color(0xFF111827),
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
//     required this.gradient,
//     required this.tyre,
//     required this.summary
//   });

//   final double s;
//   final LinearGradient gradient;
//   final _TyreUi tyre;
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
//             color: Colors.black.withOpacity(.10),
//             blurRadius: 18,
//             offset: const Offset(0, 10),
//           )
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // header row like model
//           Row(
//             children: [
//               Container(
//                 width: 52 * s,
//                 height: 52 * s,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient: gradient,
//                 ),
//                 child: Icon(Icons.description_outlined, color: Colors.white, size: 26 * s),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: Text(
//                   'Report Summary:',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 26 * s,
//                     fontWeight: FontWeight.w900,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//               ),
//               Icon(Icons.chevron_right_rounded, size: 30 * s, color: const Color(0xFF111827)),
//             ],
//           ),

//           SizedBox(height: 12 * s),

//           // ✅ Only selected tyre summary (no UI change)
//           Text(
//             tyre.label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w900,
//               foreground: Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 220, 40)),
//             ),
//           ),
//           SizedBox(height: 6 * s),
//           Text(
//             summary,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 14.5 * s,
//               fontWeight: FontWeight.w600,
//               height: 1.35,
//               color: const Color(0xFF222222),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // =============================
// // Data holder
// // =============================
// class _TyreUi {
//   _TyreUi({
//     required this.label,
//     required this.treadDepth,
//     required this.tyreStatus,
//     required this.damageValue,
//     required this.damageStatus,
//     required this.pressureValue,
//     required this.pressureStatus,
//     required this.pressureReason,
//     required this.pressureConfidence,
//     required this.summary,
//   });

//   final String label;

//   final String treadDepth;
//   final String tyreStatus;

//   final String damageValue;
//   final String damageStatus;

//   final String pressureValue;
//   final String pressureStatus;
//   final String pressureReason;
//   final String pressureConfidence;

//   final String summary;
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
*/