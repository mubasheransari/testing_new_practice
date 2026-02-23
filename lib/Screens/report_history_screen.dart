import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';

enum _Filter { all, today, last7, thisMonth }
enum _VehicleTab { all, car, bike }

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  _Filter _filter = _Filter.all;
  _VehicleTab _vehicleTab = _VehicleTab.all;

  final Map<int, bool> _downloaded = <int, bool>{};
  final Map<int, bool> _downloading = <int, bool>{};

  // Persist downloaded report paths: recordId -> savedPath
  final Map<int, String> _savedPaths = <int, String>{};
  final GetStorage _store = GetStorage();

  // ✅ bump to force NEW filenames (so you don't keep opening old PDFs)
  static const int _pdfDesignVersion = 7;
  static const String _storeKeyPaths = 'report_download_paths_v7';

  @override
  void initState() {
    super.initState();
    _restoreDownloadedState();

    final bloc = context.read<AuthBloc>();
    final st = bloc.state;

    final userId = (st.profile?.userId?.toString() ?? '').trim();
    if (userId.isNotEmpty && st.tyreHistoryStatus == TyreHistoryStatus.initial) {
      bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
    }
  }

  Future<void> _restoreDownloadedState() async {
    try {
      final raw = _store.read(_storeKeyPaths);

      if (raw is Map) {
        for (final entry in raw.entries) {
          final k = int.tryParse(entry.key.toString());
          final v = entry.value?.toString();
          if (k != null && v != null && v.trim().isNotEmpty) {
            _savedPaths[k] = v.trim();
          }
        }

        // Remove paths that no longer exist
        for (final e in _savedPaths.entries.toList()) {
          final exists = await File(e.value).exists();
          if (!exists) _savedPaths.remove(e.key);
        }

        if (!mounted) return;
        setState(() {
          for (final id in _savedPaths.keys) {
            _downloaded[id] = true;
          }
        });

        _persistDownloadedPaths();
      }
    } catch (_) {
      // ignore
    }
  }

  void _persistDownloadedPaths() {
    final out = <String, String>{};
    for (final e in _savedPaths.entries) {
      out[e.key.toString()] = e.value;
    }
    _store.write(_storeKeyPaths, out);
  }

  /* ============================ Filters ============================ */

  List<TyreRecord> _applyTimeFilter(List<TyreRecord> all) {
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.today:
        return all
            .where((e) =>
                e.uploadedAt.year == now.year &&
                e.uploadedAt.month == now.month &&
                e.uploadedAt.day == now.day)
            .toList();
      case _Filter.last7:
        final from = now.subtract(const Duration(days: 7));
        return all.where((e) => e.uploadedAt.isAfter(from)).toList();
      case _Filter.thisMonth:
        return all
            .where((e) =>
                e.uploadedAt.year == now.year && e.uploadedAt.month == now.month)
            .toList();
    }
  }

  String _prettyDate(DateTime d) {
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final am = d.hour >= 12 ? 'PM' : 'AM';
    return '${DateFormat('dd MMM, yyyy').format(d)}  —  $hh:$mm $am';
  }

  /* ============================ File names ============================ */

  // ✅ FIX: sanitize filename (no / \ : etc.) so iOS never fails to create file
  String _safeFileName(TyreRecord r) {
    final dt = DateFormat('yyyyMMdd_HHmmss').format(r.uploadedAt);

    String clean(String v) {
      final t = v.trim().isEmpty ? 'vehicle' : v.trim();
      // keep only safe filename characters
      return t.replaceAll(RegExp(r'[^\w\-]+'), '_');
    }

    final vt = clean(r.vehicleType);
    final rid = r.recordId;
    return 'tyre_report_v$_pdfDesignVersion${vt}_${rid}_$dt.pdf';
  }

  Future<Directory> _reportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Reports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _tempShareDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'tyre_reports_share'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _savePdfTempForShare(TyreRecord record) async {
    final dir = await _tempShareDir();
    final path = p.join(dir.path, _safeFileName(record));
    final bytes = await _ModernPdfReport.build(record);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ✅ FIX: log real error so you can see why it failed (no UI change)
  Future<String?> _savePdfToAppDocuments(TyreRecord record) async {
    try {
      final dir = await _reportsDir();
      final path = p.join(dir.path, _safeFileName(record));

      final bytes = await _ModernPdfReport.build(record);
      final file = File(path);

      await file.writeAsBytes(bytes, flush: true);

      // small sanity check
      final ok = await file.exists();
      if (!ok) return null;

      return path;
    } catch (e, st) {
      debugPrint('PDF save failed: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<void> _downloadPdf(TyreRecord record) async {
    final id = record.recordId;
    if (_downloading[id] == true) return;

    setState(() => _downloading[id] = true);

    try {
      final savedPath = await _savePdfToAppDocuments(record);

      if (!mounted) return;
      setState(() => _downloading[id] = false);

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed: Unable to save file')),
        );
        return;
      }

      _savedPaths[id] = savedPath;
      _persistDownloadedPaths();

      if (!mounted) return;
      setState(() => _downloaded[id] = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${p.basename(savedPath)}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(savedPath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading[id] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _sharePdf(TyreRecord record, {Rect? shareOrigin}) async {
    try {
      final file = await _savePdfTempForShare(record);
      if (!mounted) return;

      // iPad requires a non-zero anchor rect
      final fallback = const Rect.fromLTWH(1, 1, 1, 1);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
        sharePositionOrigin: shareOrigin ?? fallback,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  void _openDownloadSheet(TyreRecord record) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _DownloadDialog(
            s: s,
            onDownload: () async {
              Navigator.of(context).pop();
              await _downloadPdf(record);
            },
            onShare: (Rect origin) async {
              Navigator.of(context).pop();
              await _sharePdf(record, shareOrigin: origin);
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Color _statusColorUi(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return const Color(0xFFEF4444);
    if (t.contains('warning')) return const Color(0xFFF59E0B);
    if (t.contains('safe')) return const Color(0xFF22C55E);
    return const Color(0xFF10B981);
  }

  String _summaryStatus(TyreRecord r) {
    final vt = r.vehicleType.toLowerCase().trim();

    if (vt == 'bike') {
      final s = <String>[r.bikeFrontStatus, r.bikeBackStatus]
          .map((e) => e.toLowerCase())
          .toList();

      if (s.any((x) => x.contains('danger'))) return 'Danger';
      if (s.any((x) => x.contains('warning'))) return 'Warning';
      if (s.any((x) => x.contains('safe'))) return 'Safe';
      return 'Completed';
    }

    final statuses = <String>[
      r.frontLeftStatus,
      r.frontRightStatus,
      r.backLeftStatus,
      r.backRightStatus,
    ].map((e) => e.toLowerCase()).toList();

    if (statuses.any((s) => s.contains('danger'))) return 'Danger';
    if (statuses.any((s) => s.contains('warning'))) return 'Warning';
    if (statuses.any((s) => s.contains('safe'))) return 'Safe';
    return 'Completed';
  }

  /* ============================ UI (OLD UI kept) ============================ */

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // ✅ IMPORTANT: these lists MUST be same TyreRecord import everywhere
            List<TyreRecord> all;
            switch (_vehicleTab) {
              case _VehicleTab.all:
                all = state.allTyreRecords;
                break;
              case _VehicleTab.car:
                all = state.carRecords;
                break;
              case _VehicleTab.bike:
                all = state.bikeRecords;
                break;
            }

            final filtered = _applyTimeFilter(all);

            return ListView(
              padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 28 * s),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 30.0),
                      child: Text(
                        'Report History',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                SizedBox(height: 10 * s),
                _VehicleTabs(
                  s: s,
                  active: _vehicleTab,
                  onChanged: (v) => setState(() => _vehicleTab = v),
                ),
                SizedBox(height: 12 * s),
                _FiltersBar(
                  s: s,
                  active: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                SizedBox(height: 16 * s),
                if (state.tyreHistoryStatus == TyreHistoryStatus.loading)
                  Padding(
                    padding: EdgeInsets.only(top: 20 * s),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                if (state.tyreHistoryStatus == TyreHistoryStatus.failure)
                  Container(
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12 * s),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: Text(
                            state.tyreHistoryError ?? 'Failed to load history',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: const Color(0xFF111827),
                              fontSize: 13 * s,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final userId =
                                (state.profile?.userId?.toString() ?? '').trim();
                            if (userId.isEmpty) return;
                            context.read<AuthBloc>().add(
                                  FetchTyreHistoryRequested(
                                    userId: userId,
                                    vehicleId: "ALL",
                                  ),
                                );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (state.tyreHistoryStatus == TyreHistoryStatus.success &&
                    filtered.isEmpty)
                  Container(
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12 * s),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        )
                      ],
                    ),
                    child: Text(
                      'No reports found.',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        color: const Color(0xFF111827),
                        fontSize: 13.5 * s,
                      ),
                    ),
                  ),
                ...filtered.map((it) {
                  final downloading = _downloading[it.recordId] == true;
                  final downloaded = _downloaded[it.recordId] == true;
                  final statusSummary = _summaryStatus(it);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12 * s),
                    child: _ReportCard(
                      s: s,
                      dateText: _prettyDate(it.uploadedAt),
                      vehicleType: it.vehicleType,
                      vehicleId: it.vehicleId,
                      completed: true,
                      downloaded: downloaded,
                      downloading: downloading,
                      onDownload: () => _openDownloadSheet(it),
                      statusSummary: statusSummary,
                      statusColor: _statusColorUi(statusSummary),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModernPdfReport {
  // ===================== COLORS =====================
  static const PdfColor _bg = PdfColor.fromInt(0xFFF7F7F7);
  static const PdfColor _card = PdfColors.white;
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

  static const PdfColor _text = PdfColor.fromInt(0xFF111827);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

  // Gradient ONLY for heading text
  static const PdfColor _g1 = PdfColor.fromInt(0xFF4F46E5);
  static const PdfColor _g2 = PdfColor.fromInt(0xFF6366F1);

  static String _dash(String v) => v.trim().isEmpty ? '—' : v.trim();

  static Map<String, dynamic>? _asMap(dynamic v) {
  try {
    if (v == null) return null;

    if (v is Map<String, dynamic>) return v;

    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      if (s.startsWith('{') && s.endsWith('}')) {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
      }
      return null;
    }

    // try object -> map-like fields
    final d = v as dynamic;
    final m = <String, dynamic>{};
    try {
      m['condition'] = d.condition;
    } catch (_) {}
    try {
      m['pressure_advisory'] = d.pressure_advisory;
    } catch (_) {}
    try {
      m['summary'] = d.summary;
    } catch (_) {}
    return m.isEmpty ? null : m;
  } catch (_) {
    return null;
  }
}

static Map<String, dynamic>? _pressureAdv(dynamic status) {
  final m = _asMap(status);
  if (m == null) return null;

  final adv = m['pressure_advisory'];
  return _asMap(adv);
}

static String _conditionOnly(dynamic status) {
  final m = _asMap(status);
  final v = (m?['condition']?.toString() ?? '').trim();
  return v.isEmpty ? '—' : v;
}

static String _pressureReason(dynamic status) {
  final adv = _pressureAdv(status);
  final v = (adv?['reason']?.toString() ?? '').trim();
  return v.isEmpty ? '—' : v;
}

static String _pressureConfidence(dynamic status) {
  final adv = _pressureAdv(status);
  final v = (adv?['confidence']?.toString() ?? '').trim();
  return v.isEmpty ? '—' : v;
}

  // ✅ FIX: status may be String OR Map OR object. Never crash.
  static String _statusCondition(dynamic status) {
    try {
      if (status == null) return '—';

      if (status is String) {
        final t = status.trim();
        return t.isEmpty ? '—' : t;
      }

      if (status is Map) {
        final v = status['condition']?.toString() ?? '';
        final t = v.trim();
        return t.isEmpty ? '—' : t;
      }

      final v = (status as dynamic).condition?.toString() ?? '';
      final t = v.trim();
      return t.isEmpty ? '—' : t;
    } catch (_) {
      return '—';
    }
  }

  // ===================== PRESSURE SAFE READ =====================
  static dynamic _read(dynamic obj, String key) {
    try {
      if (obj == null) return null;
      if (obj is Map) return obj[key];
      final d = obj as dynamic;
      if (key == 'status') return d.status;
      if (key == 'reason') return d.reason;
      if (key == 'confidence') return d.confidence;
    } catch (_) {}
    return null;
  }

  static String _pStatus(dynamic p) => _dash('${_read(p, 'status') ?? ''}');
  static String _pReason(dynamic p) => _dash('${_read(p, 'reason') ?? ''}');
  static String _pConfidence(dynamic p) =>
      _dash('${_read(p, 'confidence') ?? ''}');

  // ===================== IMAGE =====================
  static Future<pw.ImageProvider?> _netImg(String url) async {
    try {
      if (!url.startsWith('http')) return null;
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return null;
      return pw.MemoryImage(r.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  // ===================== SMALL HELPERS =====================
  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(fontSize: 10.2, color: _text),
            ),
          ),
        ],
      ),
    );
  }
  static String _pressureStatus(dynamic status) {
  final adv = _pressureAdv(status);
  final v = (adv?['status']?.toString() ?? '').trim();
  return v.isEmpty ? '—' : v;
}


//   static String _conditionOnly(dynamic status) {
//   try {
//     if (status == null) return '—';

//     // If already a Map
//     if (status is Map) {
//       final v = status['condition']?.toString().trim() ?? '';
//       return v.isEmpty ? '—' : v;
//     }

//     // If it's a JSON string like {"condition":"Danger", ...}
//     if (status is String) {
//       final s = status.trim();
//       if (s.isEmpty) return '—';

//       // If string looks like JSON, parse it
//       if (s.startsWith('{') && s.endsWith('}')) {
//         final decoded = jsonDecode(s);
//         if (decoded is Map) {
//           final v = decoded['condition']?.toString().trim() ?? '';
//           return v.isEmpty ? '—' : v;
//         }
//       }

//       // Otherwise it's already a plain status string
//       return s;
//     }

//     // If it's an object with .condition
//     final v = (status as dynamic).condition?.toString().trim() ?? '';
//     return v.isEmpty ? '—' : v;
//   } catch (_) {
//     return '—';
//   }
// }

  // ===================== TYRE TILE =====================
  static pw.Widget _tyreTile(_WheelData w) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            w.title,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 8),

          // IMAGE
          pw.Container(
            height: 110,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: w.image == null
                ? pw.Center(
                    child: pw.Text(
                      'No image',
                      style: pw.TextStyle(fontSize: 9.5, color: _muted),
                    ),
                  )
                : pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(w.image!, fit: pw.BoxFit.cover),
                  ),
          ),

          pw.SizedBox(height: 10),

          // ✅ FIXED: show condition safely (no crash => download works)
         _kv('Status', _conditionOnly(w.status)),
          _kv('Tread', _dash(w.tread)),
          _kv('Wear', _dash(w.wear)),

          pw.Divider(color: _border),
          pw.Text(
            'Tyre Pressure',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 6),
          _kv('Status', _pressureStatus(w.status)),
_kv('Reason', _pressureReason(w.status)),
_kv('Confidence', _pressureConfidence(w.status)),
          // _kv('Status', _pStatus(w.pressure)),
          // _kv('Reason', _pReason(w.pressure)),
          // _kv('Confidence', _pConfidence(w.pressure)),

          pw.Divider(color: _border),
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _dash(w.summary),
            style: pw.TextStyle(fontSize: 10, color: _text, height: 1.35),
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================
  static Future<List<int>> build(TyreRecord r) async {
    final wheels = <_WheelData>[];

    if (r.vehicleType.toLowerCase() == 'car') {
      wheels.addAll([
        _WheelData.fromCar(
          'Front Left',
          r.frontLeftStatus,
          r.frontLeftTread,
          r.frontLeftWearPatterns,
          r.frontLeftPressure,
          r.frontLeftSummary,
          r.frontLeftWheel,
        ),
        _WheelData.fromCar(
          'Front Right',
          r.frontRightStatus,
          r.frontRightTread,
          r.frontRightWearPatterns,
          r.frontRightPressure,
          r.frontRightSummary,
          r.frontRightWheel,
        ),
        _WheelData.fromCar(
          'Back Left',
          r.backLeftStatus,
          r.backLeftTread,
          r.backLeftWearPatterns,
          r.backLeftPressure,
          r.backLeftSummary,
          r.backLeftWheel,
        ),
        _WheelData.fromCar(
          'Back Right',
          r.backRightStatus,
          r.backRightTread,
          r.backRightWearPatterns,
          r.backRightPressure,
          r.backRightSummary,
          r.backRightWheel,
        ),
      ]);
    } else {
      wheels.addAll([
        _WheelData.fromCar(
          'Front Tyre',
          r.bikeFrontStatus,
          r.bikeFrontTread,
          r.bikeFrontWearPatterns,
          r.bikeFrontPressure,
          r.bikeFrontSummary,
          r.bikeFrontWheel,
        ),
        _WheelData.fromCar(
          'Back Tyre',
          r.bikeBackStatus,
          r.bikeBackTread,
          r.bikeBackWearPatterns,
          r.bikeBackPressure,
          r.bikeBackSummary,
          r.bikeBackWheel,
        ),
      ]);
    }

    for (final w in wheels) {
      w.image = await _netImg(w.imageUrl);
    }

    final doc = pw.Document();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(color: _bg),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (_) => [
          // ===== HEADER =====
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Tyre ',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _g1,
                  ),
                ),
                pw.TextSpan(
                  text: 'Inspection Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _g2,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ===== GRID =====
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                wheels.map((w) => pw.SizedBox(width: 260, child: _tyreTile(w))).toList(),
          ),

          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Generated by TireTest AI',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}

class _WheelData {
  _WheelData({
    required this.title,
    required this.status,
    required this.tread,
    required this.wear,
    required this.pressure,
    required this.summary,
    required this.imageUrl,
  });

  factory _WheelData.fromCar(
    String t,
    dynamic s, // ✅ dynamic (String OR Map)
    String tr,
    String w,
    dynamic p,
    String sum,
    String img,
  ) =>
      _WheelData(
        title: t,
        status: s,
        tread: tr,
        wear: w,
        pressure: p,
        summary: sum,
        imageUrl: img,
      );

  final String title;
  final dynamic status;
  final String tread;
  final String wear;
  final dynamic pressure;
  final String summary;
  final String imageUrl;

  pw.ImageProvider? image;
}

/* ---------------- The rest of your UI widgets remain unchanged ---------------- */
/* _VehicleTabs, _FiltersBar, _ReportCard, _DownloadPill, _DownloadDialog */
/* Keep them exactly as you already have in your file. */


// enum _Filter { all, today, last7, thisMonth }
// enum _VehicleTab { all, car, bike }

// class ReportHistoryScreen extends StatefulWidget {
//   const ReportHistoryScreen({super.key});

//   @override
//   State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
// }

// class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
//   _Filter _filter = _Filter.all;
//   _VehicleTab _vehicleTab = _VehicleTab.all;

//   final Map<int, bool> _downloaded = <int, bool>{};
//   final Map<int, bool> _downloading = <int, bool>{};

//   // Persist downloaded report paths: recordId -> savedPath
//   final Map<int, String> _savedPaths = <int, String>{};
//   final GetStorage _store = GetStorage();

//   // ✅ bump to force NEW filenames (so you don't keep opening old PDFs)
//   static const int _pdfDesignVersion = 7;
//   static const String _storeKeyPaths = 'report_download_paths_v7';

//   @override
//   void initState() {
//     super.initState();
//     _restoreDownloadedState();

//     final bloc = context.read<AuthBloc>();
//     final st = bloc.state;

//     final userId = (st.profile?.userId?.toString() ?? '').trim();
//     if (userId.isNotEmpty && st.tyreHistoryStatus == TyreHistoryStatus.initial) {
//       bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
//     }
//   }

//   Future<void> _restoreDownloadedState() async {
//     try {
//       final raw = _store.read(_storeKeyPaths);

//       if (raw is Map) {
//         for (final entry in raw.entries) {
//           final k = int.tryParse(entry.key.toString());
//           final v = entry.value?.toString();
//           if (k != null && v != null && v.trim().isNotEmpty) {
//             _savedPaths[k] = v.trim();
//           }
//         }

//         // Remove paths that no longer exist
//         for (final e in _savedPaths.entries.toList()) {
//           final exists = await File(e.value).exists();
//           if (!exists) _savedPaths.remove(e.key);
//         }

//         if (!mounted) return;
//         setState(() {
//           for (final id in _savedPaths.keys) {
//             _downloaded[id] = true;
//           }
//         });

//         _persistDownloadedPaths();
//       }
//     } catch (_) {
//       // ignore
//     }
//   }

//   void _persistDownloadedPaths() {
//     final out = <String, String>{};
//     for (final e in _savedPaths.entries) {
//       out[e.key.toString()] = e.value;
//     }
//     _store.write(_storeKeyPaths, out);
//   }

//   /* ============================ Filters ============================ */

//   List<TyreRecord> _applyTimeFilter(List<TyreRecord> all) {
//     final now = DateTime.now();
//     switch (_filter) {
//       case _Filter.all:
//         return all;
//       case _Filter.today:
//         return all
//             .where((e) =>
//                 e.uploadedAt.year == now.year &&
//                 e.uploadedAt.month == now.month &&
//                 e.uploadedAt.day == now.day)
//             .toList();
//       case _Filter.last7:
//         final from = now.subtract(const Duration(days: 7));
//         return all.where((e) => e.uploadedAt.isAfter(from)).toList();
//       case _Filter.thisMonth:
//         return all
//             .where((e) =>
//                 e.uploadedAt.year == now.year && e.uploadedAt.month == now.month)
//             .toList();
//     }
//   }

//   String _prettyDate(DateTime d) {
//     final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final mm = d.minute.toString().padLeft(2, '0');
//     final am = d.hour >= 12 ? 'PM' : 'AM';
//     return '${DateFormat('dd MMM, yyyy').format(d)}  —  $hh:$mm $am';
//   }

//   /* ============================ File names ============================ */

//   String _safeFileName(TyreRecord r) {
//     final dt = DateFormat('yyyyMMdd_HHmmss').format(r.uploadedAt);
//     final vt = r.vehicleType.trim().isEmpty ? 'vehicle' : r.vehicleType.trim();
//     final rid = r.recordId;
//     return 'tyre_report_v$_pdfDesignVersion${vt}_${rid}_$dt.pdf';
//   }

//   Future<Directory> _reportsDir() async {
//     final docs = await getApplicationDocumentsDirectory();
//     final dir = Directory(p.join(docs.path, 'Reports'));
//     if (!await dir.exists()) await dir.create(recursive: true);
//     return dir;
//   }

//   Future<Directory> _tempShareDir() async {
//     final base = await getTemporaryDirectory();
//     final dir = Directory(p.join(base.path, 'tyre_reports_share'));
//     if (!await dir.exists()) await dir.create(recursive: true);
//     return dir;
//   }

//   Future<File> _savePdfTempForShare(TyreRecord record) async {
//     final dir = await _tempShareDir();
//     final path = p.join(dir.path, _safeFileName(record));
//     final bytes = await _ModernPdfReport.build(record);
//     final file = File(path);
//     await file.writeAsBytes(bytes, flush: true);
//     return file;
//   }

//   Future<String?> _savePdfToAppDocuments(TyreRecord record) async {
//     try {
//       final dir = await _reportsDir();
//       final path = p.join(dir.path, _safeFileName(record));
//       final bytes = await _ModernPdfReport.build(record);
//       final file = File(path);
//       await file.writeAsBytes(bytes, flush: true);
//       return path;
//     } catch (_) {
//       return null;
//     }
//   }

//   Future<void> _downloadPdf(TyreRecord record) async {
//     final id = record.recordId;
//     if (_downloading[id] == true) return;

//     setState(() => _downloading[id] = true);

//     try {
//       final savedPath = await _savePdfToAppDocuments(record);

//       if (!mounted) return;
//       setState(() => _downloading[id] = false);

//       if (savedPath == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Download failed: Unable to save file')),
//         );
//         return;
//       }

//       _savedPaths[id] = savedPath;
//       _persistDownloadedPaths();

//       if (!mounted) return;
//       setState(() => _downloaded[id] = true);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Saved: ${p.basename(savedPath)}'),
//           action: SnackBarAction(
//             label: 'Open',
//             onPressed: () => OpenFilex.open(savedPath),
//           ),
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _downloading[id] = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Download failed: $e')),
//       );
//     }
//   }

//   Future<void> _sharePdf(TyreRecord record, {Rect? shareOrigin}) async {
//     try {
//       final file = await _savePdfTempForShare(record);
//       if (!mounted) return;

//       // iPad requires a non-zero anchor rect
//       final fallback = const Rect.fromLTWH(1, 1, 1, 1);

//       await Share.shareXFiles(
//         [XFile(file.path)],
//         text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
//         sharePositionOrigin: shareOrigin ?? fallback,
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Share failed: $e')),
//       );
//     }
//   }

//   void _openDownloadSheet(TyreRecord record) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     showGeneralDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
//       barrierColor: Colors.black54,
//       transitionDuration: const Duration(milliseconds: 250),
//       pageBuilder: (context, animation, secondaryAnimation) {
//         return Center(
//           child: _DownloadDialog(
//             s: s,
//             onDownload: () async {
//               Navigator.of(context).pop();
//               await _downloadPdf(record);
//             },
//             onShare: (Rect origin) async {
//               Navigator.of(context).pop();
//               await _sharePdf(record, shareOrigin: origin);
//             },
//           ),
//         );
//       },
//       transitionBuilder: (context, animation, secondaryAnimation, child) {
//         final curved = CurvedAnimation(
//           parent: animation,
//           curve: Curves.easeOutCubic,
//           reverseCurve: Curves.easeInCubic,
//         );
//         return FadeTransition(
//           opacity: curved,
//           child: SlideTransition(
//             position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
//                 .animate(curved),
//             child: child,
//           ),
//         );
//       },
//     );
//   }


//   Color _statusColorUi(String v) {
//     final t = v.toLowerCase();
//     if (t.contains('danger')) return const Color(0xFFEF4444);
//     if (t.contains('warning')) return const Color(0xFFF59E0B);
//     if (t.contains('safe')) return const Color(0xFF22C55E);
//     return const Color(0xFF10B981);
//   }

//   String _summaryStatus(TyreRecord r) {
//     final vt = r.vehicleType.toLowerCase().trim();

//     if (vt == 'bike') {
//       final s = <String>[r.bikeFrontStatus, r.bikeBackStatus]
//           .map((e) => e.toLowerCase())
//           .toList();

//       if (s.any((x) => x.contains('danger'))) return 'Danger';
//       if (s.any((x) => x.contains('warning'))) return 'Warning';
//       if (s.any((x) => x.contains('safe'))) return 'Safe';
//       return 'Completed';
//     }

//     final statuses = <String>[
//       r.frontLeftStatus,
//       r.frontRightStatus,
//       r.backLeftStatus,
//       r.backRightStatus,
//     ].map((e) => e.toLowerCase()).toList();

//     if (statuses.any((s) => s.contains('danger'))) return 'Danger';
//     if (statuses.any((s) => s.contains('warning'))) return 'Warning';
//     if (statuses.any((s) => s.contains('safe'))) return 'Safe';
//     return 'Completed';
//   }

//   /* ============================ UI (OLD UI kept) ============================ */

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       body: SafeArea(
//         child: BlocBuilder<AuthBloc, AuthState>(
//           builder: (context, state) {
//             // ✅ IMPORTANT: these lists MUST be same TyreRecord import everywhere
//             List<TyreRecord> all;
//             switch (_vehicleTab) {
//               case _VehicleTab.all:
//                 all = state.allTyreRecords;
//                 break;
//               case _VehicleTab.car:
//                 all = state.carRecords;
//                 break;
//               case _VehicleTab.bike:
//                 all = state.bikeRecords;
//                 break;
//             }

//             final filtered = _applyTimeFilter(all);

//             return ListView(
//               padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 28 * s),
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.only(left: 30.0),
//                       child: Text(
//                         'Report History',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 20 * s,
//                           fontWeight: FontWeight.w900,
//                           color: const Color(0xFF0F172A),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 48),
//                   ],
//                 ),
//                 SizedBox(height: 10 * s),
//                 _VehicleTabs(
//                   s: s,
//                   active: _vehicleTab,
//                   onChanged: (v) => setState(() => _vehicleTab = v),
//                 ),
//                 SizedBox(height: 12 * s),
//                 _FiltersBar(
//                   s: s,
//                   active: _filter,
//                   onChanged: (f) => setState(() => _filter = f),
//                 ),
//                 SizedBox(height: 16 * s),

//                 if (state.tyreHistoryStatus == TyreHistoryStatus.loading)
//                   Padding(
//                     padding: EdgeInsets.only(top: 20 * s),
//                     child: const Center(child: CircularProgressIndicator()),
//                   ),

//                 if (state.tyreHistoryStatus == TyreHistoryStatus.failure)
//                   Container(
//                     padding: EdgeInsets.all(14 * s),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12 * s),
//                       boxShadow: const [
//                         BoxShadow(
//                           color: Color(0x14000000),
//                           blurRadius: 12,
//                           offset: Offset(0, 6),
//                         )
//                       ],
//                     ),
//                     child: Row(
//                       children: [
//                         const Icon(Icons.error_outline, color: Colors.redAccent),
//                         SizedBox(width: 10 * s),
//                         Expanded(
//                           child: Text(
//                             state.tyreHistoryError ?? 'Failed to load history',
//                             style: TextStyle(
//                               fontFamily: 'ClashGrotesk',
//                               color: const Color(0xFF111827),
//                               fontSize: 13 * s,
//                             ),
//                           ),
//                         ),
//                         TextButton(
//                           onPressed: () {
//                             final userId =
//                                 (state.profile?.userId?.toString() ?? '').trim();
//                             if (userId.isEmpty) return;
//                             context.read<AuthBloc>().add(
//                                   FetchTyreHistoryRequested(
//                                     userId: userId,
//                                     vehicleId: "ALL",
//                                   ),
//                                 );
//                           },
//                           child: const Text('Retry'),
//                         ),
//                       ],
//                     ),
//                   ),

//                 if (state.tyreHistoryStatus == TyreHistoryStatus.success &&
//                     filtered.isEmpty)
//                   Container(
//                     padding: EdgeInsets.all(14 * s),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12 * s),
//                       boxShadow: const [
//                         BoxShadow(
//                           color: Color(0x14000000),
//                           blurRadius: 12,
//                           offset: Offset(0, 6),
//                         )
//                       ],
//                     ),
//                     child: Text(
//                       'No reports found.',
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         color: const Color(0xFF111827),
//                         fontSize: 13.5 * s,
//                       ),
//                     ),
//                   ),

//                 ...filtered.map((it) {
//                   final downloading = _downloading[it.recordId] == true;
//                   final downloaded = _downloaded[it.recordId] == true;
//                   final statusSummary = _summaryStatus(it);

//                   return Padding(
//                     padding: EdgeInsets.only(bottom: 12 * s),
//                     child: _ReportCard(
//                       s: s,
//                       dateText: _prettyDate(it.uploadedAt),
//                       vehicleType: it.vehicleType,
//                       vehicleId: it.vehicleId,
//                       completed: true,
//                       downloaded: downloaded,
//                       downloading: downloading,
//                       onDownload: () => _openDownloadSheet(it),
//                       statusSummary: statusSummary,
//                       statusColor: _statusColorUi(statusSummary),
//                     ),
//                   );
//                 }),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class _ModernPdfReport {
//   // ===================== COLORS =====================
//   static const PdfColor _bg = PdfColor.fromInt(0xFFF7F7F7);
//   static const PdfColor _card = PdfColors.white;
//   static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

//   static const PdfColor _text = PdfColor.fromInt(0xFF111827);
//   static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

//   // Gradient ONLY for heading text
//   static const PdfColor _g1 = PdfColor.fromInt(0xFF4F46E5);
//   static const PdfColor _g2 = PdfColor.fromInt(0xFF6366F1);

//   static String _dash(String v) => v.trim().isEmpty ? '—' : v.trim();

//   // ===================== PRESSURE SAFE READ =====================
//   static dynamic _read(dynamic obj, String key) {
//     try {
//       if (obj == null) return null;
//       if (obj is Map) return obj[key];
//       final d = obj as dynamic;
//       if (key == 'status') return d.status;
//       if (key == 'reason') return d.reason;
//       if (key == 'confidence') return d.confidence;
//     } catch (_) {}
//     return null;
//   }

//   static String _pStatus(dynamic p) => _dash('${_read(p, 'status') ?? ''}');
//   static String _pReason(dynamic p) => _dash('${_read(p, 'reason') ?? ''}');
//   static String _pConfidence(dynamic p) => _dash('${_read(p, 'confidence') ?? ''}');

//   // ===================== IMAGE =====================
//   static Future<pw.ImageProvider?> _netImg(String url) async {
//     try {
//       if (!url.startsWith('http')) return null;
//       final r = await http.get(Uri.parse(url));
//       if (r.statusCode != 200) return null;
//       return pw.MemoryImage(r.bodyBytes);
//     } catch (_) {
//       return null;
//     }
//   }

//   // ===================== SMALL HELPERS =====================
//   static pw.Widget _kv(String k, String v) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.only(bottom: 6),
//       child: pw.Row(
//         children: [
//           pw.SizedBox(
//             width: 90,
//             child: pw.Text(
//               k,
//               style: pw.TextStyle(
//                 fontSize: 9.5,
//                 fontWeight: pw.FontWeight.bold,
//                 color: _muted,
//               ),
//             ),
//           ),
//           pw.Expanded(
//             child: pw.Text(
//               v,
//               style: pw.TextStyle(fontSize: 10.2, color: _text),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ===================== TYRE TILE =====================
//   static pw.Widget _tyreTile(_WheelData w) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(12),
//       decoration: pw.BoxDecoration(
//         color: _card,
//         borderRadius: pw.BorderRadius.circular(12),
//         border: pw.Border.all(color: _border),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             w.title,
//             style: pw.TextStyle(
//               fontSize: 11.5,
//               fontWeight: pw.FontWeight.bold,
//               color: _text,
//             ),
//           ),
//           pw.SizedBox(height: 8),

//           // IMAGE
//           pw.Container(
//             height: 110,
//             decoration: pw.BoxDecoration(
//               color: PdfColor.fromInt(0xFFF1F5F9),
//               borderRadius: pw.BorderRadius.circular(8),
//             ),
//             child: w.image == null
//                 ? pw.Center(
//                     child: pw.Text(
//                       'No image',
//                       style: pw.TextStyle(fontSize: 9.5, color: _muted),
//                     ),
//                   )
//                 : pw.ClipRRect(
//                     horizontalRadius: 8,
//                     verticalRadius: 8,
//                     child: pw.Image(w.image!, fit: pw.BoxFit.cover),
//                   ),
//           ),

//           pw.SizedBox(height: 10),

//           _kv('Status', _dash(w.status['condition'])),//w.status['condition']
//           _kv('Tread', _dash(w.tread)),
//           _kv('Wear', _dash(w.wear)),

//           pw.Divider(color: _border),
//           pw.Text(
//             'Tyre Pressure',
//             style: pw.TextStyle(
//               fontSize: 10.5,
//               fontWeight: pw.FontWeight.bold,
//               color: _text,
//             ),
//           ),
//           pw.SizedBox(height: 6),
//           _kv('Status', _pStatus(w.pressure)),
//           _kv('Reason', _pReason(w.pressure)),
//           _kv('Confidence', _pConfidence(w.pressure)),

//           pw.Divider(color: _border),
//           pw.Text(
//             'Summary',
//             style: pw.TextStyle(
//               fontSize: 10.5,
//               fontWeight: pw.FontWeight.bold,
//               color: _text,
//             ),
//           ),
//           pw.SizedBox(height: 6),
//           pw.Text(
//             _dash(w.summary),
//             style: pw.TextStyle(fontSize: 10, color: _text, height: 1.35),
//           ),
//         ],
//       ),
//     );
//   }

//   // ===================== BUILD =====================
//   static Future<List<int>> build(TyreRecord r) async {
//     final wheels = <_WheelData>[];

//     if (r.vehicleType.toLowerCase() == 'car') {
//       wheels.addAll([
//         _WheelData.fromCar('Front Left', r.frontLeftStatus, r.frontLeftTread,
//             r.frontLeftWearPatterns, r.frontLeftPressure, r.frontLeftSummary, r.frontLeftWheel),
//         _WheelData.fromCar('Front Right', r.frontRightStatus, r.frontRightTread,
//             r.frontRightWearPatterns, r.frontRightPressure, r.frontRightSummary, r.frontRightWheel),
//         _WheelData.fromCar('Back Left', r.backLeftStatus, r.backLeftTread,
//             r.backLeftWearPatterns, r.backLeftPressure, r.backLeftSummary, r.backLeftWheel),
//         _WheelData.fromCar('Back Right', r.backRightStatus, r.backRightTread,
//             r.backRightWearPatterns, r.backRightPressure, r.backRightSummary, r.backRightWheel),
//       ]);
//     } else {
//       wheels.addAll([
//         _WheelData.fromCar('Front Tyre', r.bikeFrontStatus, r.bikeFrontTread,
//             r.bikeFrontWearPatterns, r.bikeFrontPressure, r.bikeFrontSummary, r.bikeFrontWheel),
//         _WheelData.fromCar('Back Tyre', r.bikeBackStatus, r.bikeBackTread,
//             r.bikeBackWearPatterns, r.bikeBackPressure, r.bikeBackSummary, r.bikeBackWheel),
//       ]);
//     }

//     for (final w in wheels) {
//       w.image = await _netImg(w.imageUrl);
//     }

//     final doc = pw.Document();

// final pageTheme = pw.PageTheme(
//   pageFormat: PdfPageFormat.a4,
//   margin: const pw.EdgeInsets.all(20),
//   theme: pw.ThemeData.withFont(
//     base: pw.Font.helvetica(),
//     bold: pw.Font.helveticaBold(),
//   ),
//   buildBackground: (_) => pw.FullPage(
//     ignoreMargins: true,
//     child: pw.Container(color: _bg),
//   ),
// );

// doc.addPage(
//   pw.MultiPage(
//     pageTheme: pageTheme,
//     build: (_) => [
//       // ===== HEADER =====
//       pw.RichText(
//         text: pw.TextSpan(
//           children: [
//             pw.TextSpan(
//               text: 'Tyre ',
//               style: pw.TextStyle(
//                 fontSize: 18,
//                 fontWeight: pw.FontWeight.bold,
//                 color: _g1,
//               ),
//             ),
//             pw.TextSpan(
//               text: 'Inspection Report',
//               style: pw.TextStyle(
//                 fontSize: 18,
//                 fontWeight: pw.FontWeight.bold,
//                 color: _g2,
//               ),
//             ),
//           ],
//         ),
//       ),
//       pw.SizedBox(height: 14),

//       // ===== GRID =====
//       pw.Wrap(
//         spacing: 10,
//         runSpacing: 10,
//         children: wheels
//             .map((w) => pw.SizedBox(width: 260, child: _tyreTile(w)))
//             .toList(),
//       ),

//       pw.SizedBox(height: 20),
//       pw.Center(
//         child: pw.Text(
//           'Generated by TireTest AI',
//           style: pw.TextStyle(fontSize: 9, color: _muted),
//         ),
//       ),
//     ],
//   ),
// );

//     return doc.save();
//   }
// }

// class _WheelData {
//   _WheelData({
//     required this.title,
//     required this.status,
//     required this.tread,
//     required this.wear,
//     required this.pressure,
//     required this.summary,
//     required this.imageUrl,
//   });

//   factory _WheelData.fromCar(
//     String t,
//     dynamic s, // ✅ was String
//     String tr,
//     String w,
//     dynamic p,
//     String sum,
//     String img,
//   ) =>
//       _WheelData(
//         title: t,
//         status: s,
//         tread: tr,
//         wear: w,
//         pressure: p,
//         summary: sum,
//         imageUrl: img,
//       );

//   final String title;
//   final dynamic status; // ✅ was String
//   final String tread;
//   final String wear;
//   final dynamic pressure;
//   final String summary;
//   final String imageUrl;

//   pw.ImageProvider? image;
// }
// // class _WheelData {
// //   _WheelData({
// //     required this.title,
// //     required this.status,
// //     required this.tread,
// //     required this.wear,
// //     required this.pressure,
// //     required this.summary,
// //     required this.imageUrl,
// //   });

// //   factory _WheelData.fromCar(
// //     String t,
// //     String s,
// //     String tr,
// //     String w,
// //     dynamic p,
// //     String sum,
// //     String img,
// //   ) =>
// //       _WheelData(
// //         title: t,
// //         status: s,
// //         tread: tr,
// //         wear: w,
// //         pressure: p,
// //         summary: sum,
// //         imageUrl: img,
// //       );

// //   final String title;
// //   final String status;
// //   final String tread;
// //   final String wear;
// //   final dynamic pressure;
// //   final String summary;
// //   final String imageUrl;

// //   pw.ImageProvider? image;
// // }





class _VehicleTabs extends StatelessWidget {
  const _VehicleTabs({
    required this.s,
    required this.active,
    required this.onChanged,
  });

  final double s;
  final _VehicleTab active;
  final ValueChanged<_VehicleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(_VehicleTab t, String label, IconData icon) {
      final isActive = t == active;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * s),
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                    )
                  : null,
              color: isActive ? null : const Color(0xFFEFF2F8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18 * s,
                  color: isActive ? Colors.white : const Color(0xFF111827),
                ),
                SizedBox(width: 6 * s),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : const Color(0xFF111827),
                    fontSize: 13 * s,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          tab(_VehicleTab.all, 'All', Icons.dashboard_rounded),
          SizedBox(width: 8 * s),
          tab(_VehicleTab.car, 'Car', Icons.directions_car_filled_rounded),
          SizedBox(width: 8 * s),
          tab(_VehicleTab.bike, 'Bike', Icons.two_wheeler_rounded),
        ],
      ),
    );
  }
}

// /* ---------------- Filters (OLD UI) ---------------- */

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.s,
    required this.active,
    required this.onChanged,
  });

  final double s;
  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_Filter f, String label) {
      final isActive = f == active;
      return GestureDetector(
        onTap: () => onChanged(f),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                  )
                : null,
            color: isActive ? null : const Color(0xFFEFF2F8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : const Color(0xFF111827),
              fontSize: 13 * s,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          chip(_Filter.all, 'All'),
          chip(_Filter.today, 'Today'),
          chip(_Filter.last7, 'Last 7 Days'),
          chip(_Filter.thisMonth, 'This Month'),
        ],
      ),
    );
  }
}

// /* ---------------- Report Card (OLD UI) ---------------- */

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.s,
    required this.dateText,
    required this.vehicleType,
    required this.vehicleId,
    required this.completed,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.statusSummary,
    required this.statusColor,
  });

  final double s;
  final String dateText;
  final String vehicleType;
  final String vehicleId;
  final bool completed;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final String statusSummary;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final isBike = vehicleType.toLowerCase().trim() == 'bike';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9 * s,
            height: 131 * s,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 10 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Report Generated',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            fontSize: 16 * s,
                          ),
                        ),
                      ),
                      _DownloadPill(
                        s: s,
                        enabled: completed,
                        downloaded: downloaded,
                        downloading: downloading,
                        onTap: onDownload,
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded,
                          size: 16 * s, color: const Color(0xFF6B7280)),
                      SizedBox(width: 6 * s),
                      Text(
                        dateText,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: 12.5 * s,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(
                        isBike
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_filled_rounded,
                        size: 16 * s,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6 * s),
                      Flexible(
                        child: Text(
                          'Vehicle: ${vehicleType.toUpperCase()} • ${vehicleId.trim().isEmpty ? "—" : vehicleId.trim()}',
                          style: TextStyle(
                            color: const Color(0xFF6B7280),
                            fontSize: 12.5 * s,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10 * s, color: statusColor),
                      SizedBox(width: 6 * s),
                      Text(
                        'Status: $statusSummary',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12.5 * s,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// /* ---------------- Download Pill (OLD UI) ---------------- */

class _DownloadPill extends StatelessWidget {
  const _DownloadPill({
    required this.s,
    required this.enabled,
    required this.downloaded,
    required this.downloading,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = downloading
        ? 'Downloading...'
        : (downloaded ? 'Downloaded' : 'Download\nFull Report');

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * s),
        color: enabled ? null : const Color(0xFFF1F5F9),
        gradient: enabled
            ? const LinearGradient(colors: [Color(0xFFEEF6FF), Color(0xFFEFF1FF)])
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30 * s,
            height: 30 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                    )
                  : null,
              color: enabled ? null : const Color(0xFFE2E8F0),
            ),
            child: downloading
                ? Padding(
                    padding: EdgeInsets.all(6 * s),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 19 * s,
                    color: enabled ? Colors.white : const Color(0xFF6B7280),
                  ),
          ),
          SizedBox(width: 8 * s),
          Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              fontSize: 11.5 * s,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : .5,
      child: GestureDetector(
        onTap: enabled && !downloading ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: pill,
      ),
    );
  }
}

// /* ---------------- Download Dialog (OLD UI) ---------------- */

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({
    required this.s,
    required this.onDownload,
    required this.onShare,
  });

  final double s;
  final VoidCallback onDownload;
  final void Function(Rect shareOrigin) onShare;

  Rect _rectFromContext(BuildContext ctx) {
    final render = ctx.findRenderObject();
    if (render is RenderBox) {
      final origin = render.localToGlobal(Offset.zero);
      final size = render.size;
      if (size.width > 0 && size.height > 0) {
        return origin & size;
      }
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 300 * s,
            padding: EdgeInsets.fromLTRB(16 * s, 40 * s, 16 * s, 16 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18 * s),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ready to Download?',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    fontSize: 18 * s,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 8 * s),
                Text(
                  'Get a detailed PDF of your scan. You can also share it directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: 13.5 * s,
                    height: 1.35,
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 25),
                    label: Text(
                      'Download PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF4F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * s),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8 * s),
                Builder(
                  builder: (btnCtx) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final rect = _rectFromContext(btnCtx);
                          onShare(rect);
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 23),
                        label: Text(
                          'Share Report',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 15 * s,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14 * s),
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF4F7BFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14 * s),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: -26 * s,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 64 * s,
                height: 64 * s,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}