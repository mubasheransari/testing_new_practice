import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart' hide TyreRecord;
import 'package:ios_tiretest_ai/Screens/home_screen.dart';
import 'package:ios_tiretest_ai/Screens/location_google_maos.dart' hide BottomTab;


import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';




import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;




import '../../models/tyre_record.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// local "downloaded" state (recordId -> true)
  final Map<int, bool> _downloaded = {};

  /// local "downloading" state (recordId -> true)
  final Map<int, bool> _downloading = {};

  @override
  void initState() {
    super.initState();

    // ✅ SAFETY NET: if global load didn't happen, fetch once here
    final bloc = context.read<AuthBloc>();
    final state = bloc.state;

    final userId = state.profile?.userId?.toString() ?? '';
    if (userId.isNotEmpty &&
        state.tyreHistoryStatus == TyreHistoryStatus.initial) {
      bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
    }
  }

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
                e.uploadedAt.year == now.year &&
                e.uploadedAt.month == now.month)
            .toList();
    }
  }

  String _prettyDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final am = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]}, ${d.year}  —  $hh:$mm $am';
  }

  // ============================================================
  // ✅ LOCAL PDF (NO API)
  // ============================================================

  String _safeFileName(TyreRecord r) {
    final dt = r.uploadedAt.toIso8601String().replaceAll(':', '-');
    return 'tyre_report_${r.vehicleType}_${r.recordId}_$dt.pdf';
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      // Try public Downloads
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;

      // fallback
      return (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<bool> _ensureStoragePermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;

    // If user denies, we can still write to app folder fallback.
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final req = await Permission.storage.request();
    return req.isGranted;
  }

  pw.Widget _badge(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  PdfColor _statusColorPdf(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return PdfColors.red;
    if (t.contains('warning')) return PdfColors.orange;
    if (t.contains('safe')) return PdfColors.green;
    return PdfColors.teal;
  }

  String _summaryStatus(TyreRecord r) {
    final statuses = [
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

  Future<List<int>> _buildPdfBytes(TyreRecord r) async {
    final doc = pw.Document();

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);
    final summary = _summaryStatus(r);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Tyre Inspection Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Record ID: ${r.recordId}'),
                  pw.Text('Vehicle: ${r.vehicleType.toUpperCase()} • ${r.vehicleId}'),
                  pw.Text('Generated: $dateStr'),
                ],
              ),
              _badge(summary, _statusColorPdf(summary)),
            ],
          ),

          pw.SizedBox(height: 18),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Wheel Status',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(4),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Wheel', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    _row('Front Left', r.frontLeftStatus),
                    _row('Front Right', r.frontRightStatus),
                    _row('Back Left', r.backLeftStatus),
                    _row('Back Right', r.backRightStatus),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 18),

          pw.Text(
            'Notes',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report was generated from the inspection data already fetched in the app (no server PDF used).',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.TableRow _row(String label, String status) {
    final c = _statusColorPdf(status);
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  status,
                  maxLines: 2,
                ),
              ),
              pw.SizedBox(width: 10),
              _badge(status, c),
            ],
          ),
        ),
      ],
    );
  }

  Future<File> _savePdfToDisk(TyreRecord record) async {
    await _ensureStoragePermissionIfNeeded();

    final dir = await _downloadDirectory();
    final path = p.join(dir.path, _safeFileName(record));

    final bytes = await _buildPdfBytes(record);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _downloadPdf(TyreRecord record) async {
    final id = record.recordId;

    if (_downloading[id] == true) return;

    setState(() => _downloading[id] = true);

    try {
      final file = await _savePdfToDisk(record);

      setState(() {
        _downloaded[id] = true;
        _downloading[id] = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${p.basename(file.path)}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    } catch (e) {
      setState(() => _downloading[id] = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _sharePdf(TyreRecord record) async {
    final id = record.recordId;

    try {
      final dir = await _downloadDirectory();
      final filePath = p.join(dir.path, _safeFileName(record));
      final file = File(filePath);

      // if not exists, generate it now
      if (!await file.exists()) {
        final saved = await _savePdfToDisk(record);
        setState(() => _downloaded[id] = true);
        await Share.shareXFiles(
          [XFile(saved.path)],
          text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
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
            onShare: () async {
              Navigator.of(context).pop();
              await _sharePdf(record);
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
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // ✅ pick records based on vehicle tab
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
                              color: const Color(0xFF111827),
                              fontSize: 13 * s,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final userId = state.profile?.userId?.toString() ?? '';
                            if (userId.isEmpty) return;
                            context.read<AuthBloc>().add(
                              FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                if (state.tyreHistoryStatus == TyreHistoryStatus.success && filtered.isEmpty)
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
                        color: const Color(0xFF111827),
                        fontSize: 13.5 * s,
                      ),
                    ),
                  ),

                ...filtered.map((it) {
                  final downloading = _downloading[it.recordId] == true;
                  final downloaded = _downloaded[it.recordId] == true;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12 * s),
                    child: _ReportCard(
                      s: s,
                      dateText: _prettyDate(it.uploadedAt),
                      vehicleText: '${it.vehicleType.toUpperCase()} • ${it.vehicleId}',
                      completed: true,
                      downloaded: downloaded,
                      downloading: downloading,
                      onDownload: () => _openDownloadSheet(it),
                      statusSummary: _summaryStatus(it),
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

/* ---------------- Vehicle Tabs ---------------- */

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
                  ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
                  : null,
              color: isActive ? null : const Color(0xFFEFF2F8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18 * s, color: isActive ? Colors.white : const Color(0xFF111827)),
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
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
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

/* ---------------- Time Filters ---------------- */

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({required this.s, required this.active, required this.onChanged});
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
                ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
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
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
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

/* ---------------- Report Card ---------------- */

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.s,
    required this.dateText,
    required this.vehicleText,
    required this.completed,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.statusSummary,
  });

  final double s;
  final String dateText;
  final String vehicleText;
  final bool completed;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final String statusSummary;

  Color _statusColor(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return const Color(0xFFEF4444);
    if (t.contains('warning')) return const Color(0xFFF59E0B);
    if (t.contains('safe')) return const Color(0xFF22C55E);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(statusSummary);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))
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
                      Icon(Icons.event_note_rounded, size: 16 * s, color: const Color(0xFF6B7280)),
                      SizedBox(width: 6 * s),
                      Text(dateText, style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s)),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(Icons.directions_car_filled_rounded, size: 16 * s, color: const Color(0xFF6B7280)),
                      SizedBox(width: 6 * s),
                      Flexible(
                        child: Text(
                          'Vehicle: $vehicleText',
                          style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s),
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
                  ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
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

/* ---------------- Download dialog ---------------- */

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.s, required this.onDownload, required this.onShare});
  final double s;
  final VoidCallback onDownload, onShare;

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
                BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 10))
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
                  'Get a detailed PDF of your wheel inspection. You can also share it directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: 13.5 * s,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      'Download PDF',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16 * s,
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
                TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(
                    'Share Report',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F7BFF),
                    ),
                  ),
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
                  gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]),
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
