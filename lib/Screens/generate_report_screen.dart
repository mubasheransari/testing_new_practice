import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'dart:io';
import 'dart:convert';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart' as m;



class InspectionResultScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;

    // ✅ 1) prefer raw api json, fallback to response?.toJson(), fallback to response?.data
    final raw = fourWheelerRaw ?? _safeToJson(response) ?? {};
    final data = _tryReadMap(raw, ['data', 'result', 'payload']) ??
        _safeToJson((response as dynamic?)?.data) ??
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

    final flImg = _imgProvider(localPath: frontLeftPath, url: flUrl);
    final frImg = _imgProvider(localPath: frontRightPath, url: frUrl);
    final blImg = _imgProvider(localPath: backLeftPath, url: blUrl);
    final brImg = _imgProvider(localPath: backRightPath, url: brUrl);

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
  // ✅ helpers
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


/*
class InspectionResultScreen extends StatelessWidget {
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
  });

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  final String vehicleId;
  final String userId;
  final String token;

  final m.TyreUploadResponse? response;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 393;
    final data = response?.data;

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

    final flImg = _imgProvider(localPath: frontLeftPath, url: flUrl);
    final frImg = _imgProvider(localPath: frontRightPath, url: frUrl);
    final blImg = _imgProvider(localPath: backLeftPath, url: blUrl);
    final brImg = _imgProvider(localPath: backRightPath, url: brUrl);

    final treadDepth = _pickStringFromData(data, ['treadDepth', 'tread_depth']) ?? '—';
    final treadStatus = _pickStringFromData(data, ['treadStatus', 'tread_status']) ?? '—';

    final tyrePressure =
        _pickStringFromData(data, ['tyrePressure', 'tirePressure', 'pressure']) ?? '—';
    final tyrePressureStatus = _pickStringFromData(
          data,
          ['tyrePressureStatus', 'tirePressureStatus', 'pressure_status'],
        ) ??
        '—';

    final damageCheck =
        _pickStringFromData(data, ['damageCheck', 'damage_check', 'damage']) ?? '—';
    final damageStatus =
        _pickStringFromData(data, ['damageStatus', 'damage_status']) ?? '—';

    final summary = response?.message ??
        _pickStringFromData(data, ['summary', 'reportSummary', 'report_summary']) ??
        'Report generated.';

    final prettyJson = _prettyResponseJson(response);

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
            title: 'Four-wheeler API Response (Debug)',
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
  }*/

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

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));


class _PhotosGrid4 extends StatelessWidget {
  const _PhotosGrid4({
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PhotoCard(
                s: s,
                image: fl,
                label: 'Front Left',
                gradient: const LinearGradient(
                  colors: [Color(0xFF30C5FF), Color(0xFF4676FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _PhotoCard(
                s: s,
                image: fr,
                label: 'Front Right',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7E6D), Color(0xFFFF57B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * s),
        Row(
          children: [
            Expanded(
              child: _PhotoCard(
                s: s,
                image: bl,
                label: 'Back Left',
                gradient: const LinearGradient(
                  colors: [Color(0xFF39D2C0), Color(0xFF7993FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: _PhotoCard(
                s: s,
                image: br,
                label: 'Back Right',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ApiResponseCard extends StatelessWidget {
  const _ApiResponseCard({
    required this.s,
    required this.title,
    required this.jsonText,
  });

  final double s;
  final String title;
  final String jsonText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFE3E7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 15 * s,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 10 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * s),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(12 * s),
              border: Border.all(color: const Color(0xFFE6EAF6)),
            ),
            child: SelectableText(
              jsonText,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 12.5 * s,
                height: 1.25,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      height: 140 * s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * s),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18 * s),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image(image: image, fit: BoxFit.cover),
            ),
            Positioned(
              left: 10 * s,
              bottom: 10 * s,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5 * s,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40 * s,
                height: 40 * s,
                decoration: BoxDecoration(
                  gradient: iconBg,
                  borderRadius: BorderRadius.circular(12 * s),
                ),
                child: Icon(icon, color: Colors.white, size: 22 * s),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14.5 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 13 * s,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
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
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13.5 * s,
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5 * s,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white.withOpacity(.9),
              fontWeight: FontWeight.w700,
              fontSize: 12.5 * s,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              fontSize: 15 * s,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            summary,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w600,
              fontSize: 13.5 * s,
              height: 1.35,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}


// class InspectionResultScreen extends StatelessWidget {
//   const InspectionResultScreen({
//     super.key,

//     // ✅ 4-wheeler local paths
//     required this.frontLeftPath,
//     required this.frontRightPath,
//     required this.backLeftPath,
//     required this.backRightPath,

//     required this.vehicleId,
//     required this.userId,
//     required this.token,

//     // ✅ API response
//     this.response,
//   });

//   final String frontLeftPath;
//   final String frontRightPath;
//   final String backLeftPath;
//   final String backRightPath;

//   final String vehicleId;
//   final String userId;
//   final String token;

//   final m.TyreUploadResponse? response;

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 393;

//     // ✅ response data
//     final data = response?.data;

//     // ✅ Try to find URL fields even if backend uses different keys
//     final flUrl = _pickStringFromData(data, [
//       'frontLeftWheelUrl',
//       'front_left_wheel_url',
//       'front_left_url',
//       'front_left',
//       'frontLeftUrl',
//       'front_left_image',
//       'front_left_image_url',
//     ]);

//     final frUrl = _pickStringFromData(data, [
//       'frontRightWheelUrl',
//       'front_right_wheel_url',
//       'front_right_url',
//       'front_right',
//       'frontRightUrl',
//       'front_right_image',
//       'front_right_image_url',
//     ]);

//     final blUrl = _pickStringFromData(data, [
//       'backLeftWheelUrl',
//       'back_left_wheel_url',
//       'back_left_url',
//       'back_left',
//       'backLeftUrl',
//       'back_left_image',
//       'back_left_image_url',
//     ]);

//     final brUrl = _pickStringFromData(data, [
//       'backRightWheelUrl',
//       'back_right_wheel_url',
//       'back_right_url',
//       'back_right',
//       'backRightUrl',
//       'back_right_image',
//       'back_right_image_url',
//     ]);

//     // ✅ build image providers (URL if available else local file)
//     final flImg = _imgProvider(localPath: frontLeftPath, url: flUrl);
//     final frImg = _imgProvider(localPath: frontRightPath, url: frUrl);
//     final blImg = _imgProvider(localPath: backLeftPath, url: blUrl);
//     final brImg = _imgProvider(localPath: backRightPath, url: brUrl);

//     // ✅ Metrics (generic/fallback). If your backend returns per-tyre metrics,
//     // you can enhance these using _pickStringFromData(...) similarly.
//     final treadDepth =
//         _pickStringFromData(data, ['treadDepth', 'tread_depth']) ?? '—';
//     final treadStatus =
//         _pickStringFromData(data, ['treadStatus', 'tread_status']) ?? '—';

//     final tyrePressure =
//         _pickStringFromData(data, [
//           'tyrePressure',
//           'tirePressure',
//           'pressure',
//         ]) ??
//         '—';
//     final tyrePressureStatus =
//         _pickStringFromData(data, [
//           'tyrePressureStatus',
//           'tirePressureStatus',
//           'pressure_status',
//         ]) ??
//         '—';

//     final damageCheck =
//         _pickStringFromData(data, ['damageCheck', 'damage_check', 'damage']) ??
//         '—';
//     final damageStatus =
//         _pickStringFromData(data, ['damageStatus', 'damage_status']) ?? '—';

//     final summary =
//         response?.message ??
//         _pickStringFromData(data, [
//           'summary',
//           'reportSummary',
//           'report_summary',
//         ]) ??
//         'Report generated.';

//     // ✅ Pretty JSON block (best way to “show API response”)
//     // Works if your TyreUploadResponse has toJson().
//     final prettyJson = _prettyResponseJson(response);

//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F2F8),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             size: 22,
//             color: Colors.black,
//           ),
//           onPressed: () => Navigator.pop(context),
//         ),
//         centerTitle: true,
//         title: Text(
//           'Inspection Report',
//           style: TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontSize: 20 * s,
//             fontWeight: FontWeight.w800,
//             color: Colors.black,
//           ),
//         ),
//       ),
//       body: ListView(
//         padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 28 * s),
//         children: [
//           // ✅ 4 images grid
//           _PhotosGrid4(s: s, fl: flImg, fr: frImg, bl: blImg, br: brImg),
//           SizedBox(height: 18 * s),

//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 flex: 11,
//                 child: _BigMetricCard(
//                   s: s,
//                   iconBg: const LinearGradient(
//                     colors: [Color(0xFF4F7BFF), Color(0xFFA6C8FF)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   icon: Icons.sync,
//                   title: 'Tread Depth',
//                   value: 'Value: $treadDepth',
//                   status: 'Status: $treadStatus',
//                 ),
//               ),
//               SizedBox(width: 14 * s),
//               Expanded(
//                 flex: 10,
//                 child: Column(
//                   children: [
//                     _SmallMetricCard(
//                       s: s,
//                       title: 'Tyre Pressure',
//                       value: 'Value: $tyrePressure',
//                       status: 'Status: $tyrePressureStatus',
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFF4F7BFF), Color(0xFF80B3FF)],
//                         begin: Alignment.centerLeft,
//                         end: Alignment.centerRight,
//                       ),
//                     ),
//                     SizedBox(height: 12 * s),
//                     _SmallMetricCard(
//                       s: s,
//                       title: 'Damage Check',
//                       value: 'Value: $damageCheck',
//                       status: 'Status: $damageStatus',
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFF69A3FF), Color(0xFF9C7FFF)],
//                         begin: Alignment.centerLeft,
//                         end: Alignment.centerRight,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 18 * s),

//           _ReportSummaryCard(s: s, title: 'Report Summary:', summary: summary),
//           SizedBox(height: 18 * s),

//           // ✅ SHOW API RESPONSE (requested)
//           _ApiResponseCard(
//             s: s,
//             title: 'Four-wheeler API Response (Debug)',
//             jsonText: prettyJson,
//           ),
//           SizedBox(height: 18 * s),

//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   style: OutlinedButton.styleFrom(
//                     side: const BorderSide(color: Color(0xFFB8C1D9)),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16 * s),
//                     ),
//                     padding: EdgeInsets.symmetric(vertical: 14 * s),
//                     backgroundColor: Colors.white,
//                   ),
//                   icon: const Icon(
//                     Icons.share_rounded,
//                     color: Color(0xFF4F7BFF),
//                   ),
//                   label: Text(
//                     'Share Report',
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontWeight: FontWeight.w700,
//                       color: const Color(0xFF4F7BFF),
//                     ),
//                   ),
//                   onPressed: () => _toast(context, 'Share pressed'),
//                 ),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF4F7BFF),
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16 * s),
//                     ),
//                     padding: EdgeInsets.symmetric(vertical: 15 * s),
//                     elevation: 4,
//                   ),
//                   icon: const Icon(Icons.download_rounded),
//                   label: Text(
//                     'Download PDF',
//                     style: TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontWeight: FontWeight.w800,
//                       fontSize: 14 * s,
//                     ),
//                   ),
//                   onPressed: () => _toast(context, 'Download pressed'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------------- Helpers ----------------

//   ImageProvider _imgProvider({required String localPath, String? url}) {
//     final u = (url ?? '').trim();
//     if (u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'))) {
//       return NetworkImage(u);
//     }
//     return FileImage(File(localPath));
//   }

//   /// ✅ Reads data fields safely even if your `data` type changes.
//   /// Works if:
//   /// - data is a Map
//   /// - OR data has toJson()
//   String? _pickStringFromData(dynamic data, List<String> keys) {
//     if (data == null) return null;

//     Map<String, dynamic>? map;

//     if (data is Map) {
//       map = Map<String, dynamic>.from(data as Map);
//     } else {
//       try {
//         final dynamic j = (data as dynamic).toJson();
//         if (j is Map) map = Map<String, dynamic>.from(j as Map);
//       } catch (_) {
//         map = null;
//       }
//     }

//     if (map == null) return null;

//     for (final k in keys) {
//       final v = map[k];
//       if (v == null) continue;
//       final s = v.toString().trim();
//       if (s.isNotEmpty && s != 'null') return s;
//     }
//     return null;
//   }

//   String _prettyResponseJson(m.TyreUploadResponse? response) {
//     if (response == null) return 'No response (null)';
//     try {
//       final dynamic j = (response as dynamic).toJson();
//       return const JsonEncoder.withIndent('  ').convert(j);
//     } catch (_) {
//       // fallback: show minimal info
//       return 'message: ${response.message}\n'
//           'data: ${response.data}\n'
//           '(Tip: add toJson() in TyreUploadResponse for full JSON)';
//     }
//   }

//   void _toast(BuildContext ctx, String msg) =>
//       ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
// }

// // ================== UI widgets (simple + reusable) ==================

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

// // ---------- Below are placeholders of your existing widgets ----------
// // If you already have these widgets in your file/project, REMOVE these duplicates.

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
//                 padding: EdgeInsets.symmetric(
//                   horizontal: 10 * s,
//                   vertical: 6 * s,
//                 ),
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

    // ✅ 4 images
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
  m.TyreUploadResponse? _apiResponse;

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

              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

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
