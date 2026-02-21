import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../models/tyre_record.dart';
import 'package:http/http.dart' as http;

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

//   final Map<int, bool> _downloaded = {};

//   final Map<int, bool> _downloading = {};

//   @override
//   void initState() {
//     super.initState();

//     final bloc = context.read<AuthBloc>();
//     final state = bloc.state;

//     final userId = state.profile?.userId?.toString() ?? '';
//     if (userId.isNotEmpty && state.tyreHistoryStatus == TyreHistoryStatus.initial) {
//       bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
//     }
//   }

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
//             .where((e) => e.uploadedAt.year == now.year && e.uploadedAt.month == now.month)
//             .toList();
//     }
//   }

//   String _prettyDate(DateTime d) {
//     const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
//     final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final mm = d.minute.toString().padLeft(2, '0');
//     final am = d.hour >= 12 ? 'PM' : 'AM';
//     return '${d.day} ${months[d.month - 1]}, ${d.year}  —  $hh:$mm $am';
//   }

//   String _safeFileName(TyreRecord r) {
//     final dt = DateFormat('yyyyMMdd_HHmmss').format(r.uploadedAt);
//     return 'tyre_report_${r.vehicleType}_${r.recordId}_$dt.pdf';
//   }


//   Future<Directory> _downloadDirectory() async {
//     if (Platform.isAndroid) {
//       final dir = await getExternalStorageDirectory();
//       if (dir != null) return dir;
//       return await getApplicationDocumentsDirectory();
//     }
//     return await getApplicationDocumentsDirectory();
//   }

//   /// ✅ create Reports folder
//   Future<Directory> _reportsDir() async {
//     final base = await _downloadDirectory();
//     final dir = Directory(p.join(base.path, 'Reports'));
//     if (!await dir.exists()) {
//       await dir.create(recursive: true);
//     }
//     return dir;
//   }

//   Future<bool> _ensureStoragePermissionIfNeeded() async {
//     return true;
//   }


//   static const PdfColor _pdfBg = PdfColor.fromInt(0xFFF6F7FA);
//   static const PdfColor _g1 = PdfColor.fromInt(0xFF00C6FF);
//   static const PdfColor _g2 = PdfColor.fromInt(0xFF7F53FD);

//   PdfColor _statusColorPdf(String v) {
//     final t = v.toLowerCase();
//     if (t.contains('danger')) return PdfColors.red;
//     if (t.contains('warning')) return PdfColors.orange;
//     if (t.contains('safe')) return PdfColors.green;
//     return PdfColors.teal;
//   }

//   pw.Widget _pill(String text, PdfColor bg) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: pw.BoxDecoration(
//         color: bg,
//         borderRadius: pw.BorderRadius.circular(999),
//       ),
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           color: PdfColors.white,
//           fontSize: 10.5,
//           fontWeight: pw.FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   pw.Widget _card({required pw.Widget child}) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(14),
//       decoration: pw.BoxDecoration(
//         color: PdfColors.white,
//         borderRadius: pw.BorderRadius.circular(14),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE7EAF0)),
//       ),
//       child: child,
//     );
//   }

//   pw.Widget _kv(String k, String v) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.only(bottom: 6),
//       child: pw.Row(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.SizedBox(
//             width: 110,
//             child: pw.Text(
//               k,
//               style: pw.TextStyle(
//                 fontSize: 10.5,
//                 color: PdfColor.fromInt(0xFF6A6F7B),
//                 fontWeight: pw.FontWeight.bold,
//               ),
//             ),
//           ),
//           pw.Expanded(
//             child: pw.Text(
//               v,
//               style: pw.TextStyle(
//                 fontSize: 10.8,
//                 color: PdfColor.fromInt(0xFF111827),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _summaryStatus(TyreRecord r) {
//     final statuses = [
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

//   pw.TableRow _statusRow(String wheel, String status) {
//     final c = _statusColorPdf(status);
//     return pw.TableRow(
//       decoration: const pw.BoxDecoration(color: PdfColors.white),
//       children: [
//         pw.Padding(
//           padding: const pw.EdgeInsets.all(10),
//           child: pw.Text(
//             wheel,
//             style: pw.TextStyle(
//               fontSize: 11,
//               color: PdfColor.fromInt(0xFF111827),
//               fontWeight: pw.FontWeight.bold,
//             ),
//           ),
//         ),
//         pw.Padding(
//           padding: const pw.EdgeInsets.all(10),
//           child: pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Expanded(
//                 child: pw.Text(
//                   status,
//                   style: pw.TextStyle(
//                     fontSize: 11,
//                     color: PdfColor.fromInt(0xFF374151),
//                   ),
//                 ),
//               ),
//               pw.SizedBox(width: 10),
//               _pill(status, c),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Future<List<int>> _buildPdfBytes(TyreRecord r) async {
//     final logoBytes = (await rootBundle.load('assets/tiretest_logo.png')).buffer.asUint8List();
//     final logo = pw.MemoryImage(logoBytes);

//     final doc = pw.Document();
//     final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);
//     final summary = _summaryStatus(r);

//     doc.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: pw.EdgeInsets.zero,
//         build: (context) => [
//           pw.Container(
//             color: _pdfBg,
//             child: pw.Column(
//               children: [
//                 pw.Container(
//                   width: double.infinity,
//                   padding: const pw.EdgeInsets.fromLTRB(22, 28, 22, 18),
//                   decoration: const pw.BoxDecoration(
//                     gradient: pw.LinearGradient(
//                       colors: [_g1, _g2],
//                       begin: pw.Alignment.centerLeft,
//                       end: pw.Alignment.centerRight,
//                     ),
//                   ),
//                   child: pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.center,
//                     children: [
//                       pw.Container(
//                         width: 84,
//                         height: 84,
//                         decoration: pw.BoxDecoration(
//                           color: PdfColors.white,
//                           borderRadius: pw.BorderRadius.circular(18),
//                         ),
//                         padding: const pw.EdgeInsets.all(10),
//                         child: pw.Image(logo, fit: pw.BoxFit.contain),
//                       ),
//                       pw.SizedBox(height: 12),
//                       pw.Text(
//                         'Tyre Inspection Report',
//                         style: pw.TextStyle(
//                           fontSize: 20,
//                           color: PdfColors.white,
//                           fontWeight: pw.FontWeight.bold,
                          
//                         ),
//                       ),
//                       pw.SizedBox(height: 6),
//                       pw.Text(
//                         'Generated from your latest scan data',
//                         style: pw.TextStyle(
//                           fontSize: 11.5,
//                           color: PdfColors.white,
//                         ),
//                       ),
//                       pw.SizedBox(height: 12),
//                     /*  pw.Row(
//                         mainAxisAlignment: pw.MainAxisAlignment.center,
//                         children: [
//                           _pill(
//                             '${r.vehicleType.toUpperCase()} • ${r.vehicleId}',
//                             PdfColor.fromInt(0x33000000),
//                           ),
//                           pw.SizedBox(width: 10),
//                          // _pill(summary, _statusColorPdf(summary)),
//                         ],
//                       ),*/
//                     ],
//                   ),
//                 ),

//                 pw.Padding(
//                   padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 24),
//                   child: pw.Column(
//                     children: [
//                       _card(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Text(
//                               'Inspection Details',
//                               style: pw.TextStyle(
//                                 fontSize: 13.5,
//                                 color: PdfColor.fromInt(0xFF111827),
//                                 fontWeight: pw.FontWeight.bold,
//                               ),
//                             ),
//                             pw.SizedBox(height: 10),
//                             _kv('Vehicle Type', r.vehicleType.toUpperCase()),
//                             _kv('Date', dateStr),
//                           ],
//                         ),
//                       ),
//                       pw.SizedBox(height: 14),
//                       _card(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Text(
//                               'Wheel Status',
//                               style: pw.TextStyle(
//                                 fontSize: 13.5,
//                                 color: PdfColor.fromInt(0xFF111827),
//                                 fontWeight: pw.FontWeight.bold,
//                               ),
//                             ),
//                             pw.SizedBox(height: 10),
//                             pw.Table(
//                               border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE7EAF0)),
//                               columnWidths: const {
//                                 0: pw.FlexColumnWidth(2),
//                                 1: pw.FlexColumnWidth(4),
//                               },
//                               children: [
//                                 pw.TableRow(
//                                   decoration: pw.BoxDecoration(
//                                     color: PdfColor.fromInt(0xFFF2F4F8),
//                                   ),
//                                   children: [
//                                     pw.Padding(
//                                       padding: const pw.EdgeInsets.all(10),
//                                       child: pw.Text(
//                                         'Wheel',
//                                         style: pw.TextStyle(
//                                           fontWeight: pw.FontWeight.bold,
//                                           fontSize: 11,
//                                           color: PdfColor.fromInt(0xFF111827),
//                                         ),
//                                       ),
//                                     ),
//                                     pw.Padding(
//                                       padding: const pw.EdgeInsets.all(10),
//                                       child: pw.Text(
//                                         'Status',
//                                         style: pw.TextStyle(
//                                           fontWeight: pw.FontWeight.bold,
//                                           fontSize: 11,
//                                           color: PdfColor.fromInt(0xFF111827),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 _statusRow('Front Left', r.frontLeftStatus),
//                                 _statusRow('Front Right', r.frontRightStatus),
//                                 _statusRow('Back Left', r.backLeftStatus),
//                                 _statusRow('Back Right', r.backRightStatus),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                       pw.SizedBox(height: 14),
//                       _card(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Text(
//                               'Notes',
//                               style: pw.TextStyle(
//                                 fontSize: 13.5,
//                                 fontWeight: pw.FontWeight.bold,
//                                 color: PdfColor.fromInt(0xFF111827),
//                               ),
//                             ),
//                             pw.SizedBox(height: 8),
//                             pw.Text(
//                               'This PDF is generated inside the app using your inspection result.',
//                               style: pw.TextStyle(
//                                 fontSize: 10.8,
//                                 color: PdfColor.fromInt(0xFF6A6F7B),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       pw.SizedBox(height: 18),
//                       pw.Text(
//                         'TireTest AI • Powered by your scan data',
//                         style: pw.TextStyle(
//                           fontSize: 10,
//                           color: PdfColor.fromInt(0xFF9AA1AE),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );

//     return doc.save();
//   }

//   Future<File> _savePdfToDisk(TyreRecord record) async {
//     await _ensureStoragePermissionIfNeeded();

//     final dir = await _reportsDir(); 
//     final path = p.join(dir.path, _safeFileName(record));

//     final bytes = await _buildPdfBytes(record);
//     final file = File(path);
//     await file.writeAsBytes(bytes, flush: true);
//     return file;
//   }

//   Future<void> _downloadPdf(TyreRecord record) async {
//     final id = record.recordId;
//     if (_downloading[id] == true) return;

//     setState(() => _downloading[id] = true);

//     try {
//       final file = await _savePdfToDisk(record);

//       setState(() {
//         _downloaded[id] = true;
//         _downloading[id] = false;
//       });

//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Saved: ${p.basename(file.path)}'),
//           action: SnackBarAction(
//             label: 'Open',
//             onPressed: () => OpenFilex.open(file.path),
//           ),
//         ),
//       );
//     } catch (e) {
//       setState(() => _downloading[id] = false);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Download failed: $e')),
//       );
//     }
//   }

//   Future<void> _sharePdf(TyreRecord record) async {
//     final id = record.recordId;

//     try {
//       final file = await _savePdfToDisk(record);
//       setState(() => _downloaded[id] = true);

//       await Share.shareXFiles(
//         [XFile(file.path)],
//         text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
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
//             onShare: () async {
//               Navigator.of(context).pop();
//               await _sharePdf(record);
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
//             position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
//             child: child,
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       body: SafeArea(
//         child: BlocBuilder<AuthBloc, AuthState>(
//           builder: (context, state) {
//             // ✅ pick records based on vehicle tab
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
//                         BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
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
//                             final userId = state.profile?.userId?.toString() ?? '';
//                             if (userId.isEmpty) return;
//                             context.read<AuthBloc>().add(
//                               FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"),
//                             );
//                           },
//                           child: const Text('Retry'),
//                         ),
//                       ],
//                     ),
//                   ),

//                 if (state.tyreHistoryStatus == TyreHistoryStatus.success && filtered.isEmpty)
//                   Container(
//                     padding: EdgeInsets.all(14 * s),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12 * s),
//                       boxShadow: const [
//                         BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))
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

//                   return Padding(
//                     padding: EdgeInsets.only(bottom: 12 * s),
//                     child: _ReportCard(
//                       s: s,
//                       dateText: _prettyDate(it.uploadedAt),
//                       vehicleText: '${it.vehicleType.toUpperCase()} • ${it.vehicleId}',
//                       completed: true,
//                       downloaded: downloaded,
//                       downloading: downloading,
//                       onDownload: () => _openDownloadSheet(it),
//                       statusSummary: _summaryStatus(it),
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

// /* ---------------- Vehicle Tabs ---------------- */

// class _VehicleTabs extends StatelessWidget {
//   const _VehicleTabs({
//     required this.s,
//     required this.active,
//     required this.onChanged,
//   });

//   final double s;
//   final _VehicleTab active;
//   final ValueChanged<_VehicleTab> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     Widget tab(_VehicleTab t, String label, IconData icon) {
//       final isActive = t == active;
//       return Expanded(
//         child: GestureDetector(
//           onTap: () => onChanged(t),
//           child: Container(
//             padding: EdgeInsets.symmetric(vertical: 10 * s),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12 * s),
//               gradient: isActive
//                   ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
//                   : null,
//               color: isActive ? null : const Color(0xFFEFF2F8),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(icon, size: 18 * s, color: isActive ? Colors.white : const Color(0xFF111827)),
//                 SizedBox(width: 6 * s),
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w900,
//                     color: isActive ? Colors.white : const Color(0xFF111827),
//                     fontSize: 13 * s,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: EdgeInsets.all(8 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12 * s),
//         boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
//       ),
//       child: Row(
//         children: [
//           tab(_VehicleTab.all, 'All', Icons.dashboard_rounded),
//           SizedBox(width: 8 * s),
//           tab(_VehicleTab.car, 'Car', Icons.directions_car_filled_rounded),
//           SizedBox(width: 8 * s),
//           tab(_VehicleTab.bike, 'Bike', Icons.two_wheeler_rounded),
//         ],
//       ),
//     );
//   }
// }


// class _FiltersBar extends StatelessWidget {
//   const _FiltersBar({required this.s, required this.active, required this.onChanged});
//   final double s;
//   final _Filter active;
//   final ValueChanged<_Filter> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     Widget chip(_Filter f, String label) {
//       final isActive = f == active;
//       return GestureDetector(
//         onTap: () => onChanged(f),
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(999),
//             gradient: isActive
//                 ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
//                 : null,
//             color: isActive ? null : const Color(0xFFEFF2F8),
//           ),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//               color: isActive ? Colors.white : const Color(0xFF111827),
//               fontSize: 13 * s,
//             ),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: EdgeInsets.all(8 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12 * s),
//         boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           chip(_Filter.all, 'All'),
//           chip(_Filter.today, 'Today'),
//           chip(_Filter.last7, 'Last 7 Days'),
//           chip(_Filter.thisMonth, 'This Month'),
//         ],
//       ),
//     );
//   }
// }


// class _ReportCard extends StatelessWidget {
//   const _ReportCard({
//     required this.s,
//     required this.dateText,
//     required this.vehicleText,
//     required this.completed,
//     required this.downloaded,
//     required this.downloading,
//     required this.onDownload,
//     required this.statusSummary,
//   });

//   final double s;
//   final String dateText;
//   final String vehicleText;
//   final bool completed;
//   final bool downloaded;
//   final bool downloading;
//   final VoidCallback onDownload;
//   final String statusSummary;

//   Color _statusColor(String v) {
//     final t = v.toLowerCase();
//     if (t.contains('danger')) return const Color(0xFFEF4444);
//     if (t.contains('warning')) return const Color(0xFFF59E0B);
//     if (t.contains('safe')) return const Color(0xFF22C55E);
//     return const Color(0xFF10B981);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final statusColor = _statusColor(statusSummary);
// final displayVehicleText = (vehicleText ?? '')
//     .split('•')
//     .first
//     .trim();

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12 * s),
//         boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 9 * s,
//             height: 131 * s,
//             decoration: const BoxDecoration(
//               borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
//               gradient: LinearGradient(
//                 colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 10 * s),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Report Generated',
//                           style: TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             fontWeight: FontWeight.w900,
//                             color: const Color(0xFF0F172A),
//                             fontSize: 16 * s,
//                           ),
//                         ),
//                       ),
//                       _DownloadPill(
//                         s: s,
//                         enabled: completed,
//                         downloaded: downloaded,
//                         downloading: downloading,
//                         onTap: onDownload,
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 6 * s),
//                   Row(
//                     children: [
//                       Icon(Icons.event_note_rounded, size: 16 * s, color: const Color(0xFF6B7280)),
//                       SizedBox(width: 6 * s),
//                       Text(dateText, style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s)),
//                     ],
//                   ),
//                   SizedBox(height: 4 * s),
//                   Row(
//   children: [
//     InkWell(
//       onTap: () {
//         print("PRINT ::: $vehicleText");
//       },
//       child: Icon(
//         Icons.directions_car_filled_rounded,
//         size: 16 * s,
//         color: const Color(0xFF6B7280),
//       ),
//     ),
//     SizedBox(width: 6 * s),
//     Flexible(
//       child: Text(
//         'Vehicle: ${displayVehicleText}',
//         style: TextStyle(
//           color: const Color(0xFF6B7280),
//           fontSize: 12.5 * s,
//         ),
//         overflow: TextOverflow.ellipsis,
//       ),
//     ),
//   ],
// ),

//                   // Row(
//                   //   children: [
//                   //     InkWell(
//                   //       onTap: (){
//                   //         print("PRINT ::: $vehicleText");
//                   //       },
//                   //       child: Icon(Icons.directions_car_filled_rounded, size: 16 * s, color: const Color(0xFF6B7280))),
//                   //     SizedBox(width: 6 * s),
//                   //     Flexible(
//                   //       child: Text(
//                   //         'Vehicle: ${vehicleText}',
//                   //         style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12.5 * s),
//                   //         overflow: TextOverflow.ellipsis,
//                   //       ),
//                   //     ),
//                   //   ],
//                   // ),
//                   SizedBox(height: 4 * s),
//                   Row(
//                     children: [
//                       Icon(Icons.circle, size: 10 * s, color: statusColor),
//                       SizedBox(width: 6 * s),
//                       Text(
//                         'Status: $statusSummary',
//                         style: TextStyle(color: statusColor, fontSize: 12.5 * s, fontWeight: FontWeight.w800),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _DownloadPill extends StatelessWidget {
//   const _DownloadPill({
//     required this.s,
//     required this.enabled,
//     required this.downloaded,
//     required this.downloading,
//     required this.onTap,
//   });

//   final double s;
//   final bool enabled;
//   final bool downloaded;
//   final bool downloading;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final label = downloading ? 'Downloading...' : (downloaded ? 'Downloaded' : 'Download\nFull Report');

//     final pill = Container(
//       padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12 * s),
//         color: enabled ? null : const Color(0xFFF1F5F9),
//         gradient: enabled ? const LinearGradient(colors: [Color(0xFFEEF6FF), Color(0xFFEFF1FF)]) : null,
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 4)),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 30 * s,
//             height: 30 * s,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: enabled ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]) : null,
//               color: enabled ? null : const Color(0xFFE2E8F0),
//             ),
//             child: downloading
//                 ? Padding(
//                     padding: EdgeInsets.all(6 * s),
//                     child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                   )
//                 : Icon(Icons.picture_as_pdf_rounded, size: 19 * s, color: enabled ? Colors.white : const Color(0xFF6B7280)),
//           ),
//           SizedBox(width: 8 * s),
//           Text(
//             label,
//             textAlign: TextAlign.right,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//               color: const Color(0xFF111827),
//               fontSize: 11.5 * s,
//               height: 1.0,
//             ),
//           ),
//         ],
//       ),
//     );

//     return Opacity(
//       opacity: enabled ? 1 : .5,
//       child: GestureDetector(
//         onTap: enabled && !downloading ? onTap : null,
//         behavior: HitTestBehavior.opaque,
//         child: pill,
//       ),
//     );
//   }
// }


// class _DownloadDialog extends StatelessWidget {
//   const _DownloadDialog({required this.s, required this.onDownload, required this.onShare});
//   final double s;
//   final VoidCallback onDownload, onShare;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Container(
//             width: 300 * s,
//             padding: EdgeInsets.fromLTRB(16 * s, 40 * s, 16 * s, 16 * s),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(18 * s),
//               boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 10))],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Ready to Download?',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w900,
//                     fontSize: 18 * s,
//                     color: const Color(0xFF111827),
//                   ),
//                 ),
//                 SizedBox(height: 8 * s),
//                 Text(
//                   'Get a detailed PDF of your wheel inspection. You can also share it directly.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: const Color(0xFF6B7280), fontSize: 13.5 * s, height: 1.35,fontFamily: 'ClashGrotesk',fontWeight: FontWeight.w800),
//                 ),
//                 SizedBox(height: 16 * s),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton.icon(
//                     onPressed: onDownload,
//                     icon: const Icon(Icons.download_rounded,size: 25,),
//                     label: Text(
//                       'Download PDF',
//                       style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800, fontSize: 15 * s),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 14 * s),
//                       foregroundColor: Colors.white,
//                       backgroundColor: const Color(0xFF4F7BFF),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s)),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 8 * s),
//                     SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton.icon(
//                  onPressed: onShare,
//                     icon: const Icon(Icons.ios_share_rounded,size: 23,),
//                     label: Text(
//                       'Share Report',
//                       style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800, fontSize: 15 * s),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 14 * s),
//                       foregroundColor: Colors.white,
//                       backgroundColor: const Color(0xFF4F7BFF),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s)),
//                     ),
//                   ),
//                 ),
//                 // TextButton.icon(
//                 //   onPressed: onShare,
//                 //   icon: const Icon(Icons.ios_share_rounded),
//                 //   label: Text(
//                 //     'Share Report',
//                 //     style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800, color: const Color(0xFF4F7BFF)),
//                 //   ),
//                 // ),
//               ],
//             ),
//           ),
//           Positioned(
//             top: -26 * s,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Container(
//                 width: 64 * s,
//                 height: 64 * s,
//                 decoration: const BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]),
//                 ),
//                 child: const Center(
//                   child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// ReportHistoryScreen.dart
// ReportHistoryScreen.dart
// ✅ Only update this screen (UI + PDF generation) — no other app changes needed.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../Bloc/auth_bloc.dart';
import '../../Bloc/auth_event.dart';
import '../../Bloc/auth_state.dart';
import '../../models/tyre_record.dart';

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

  @override
  void initState() {
    super.initState();

    final bloc = context.read<AuthBloc>();
    final st = bloc.state;

    final userId = (st.profile?.userId?.toString() ?? '').trim();
    if (userId.isNotEmpty && st.tyreHistoryStatus == TyreHistoryStatus.initial) {
      bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
    }
  }

  // ---------------- Filters ----------------

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

  // ---------------- File / Download ----------------

  String _safeFileName(TyreRecord r) {
    final dt = DateFormat('yyyyMMdd_HHmmss').format(r.uploadedAt);
    final vt = r.vehicleType.trim().isEmpty ? 'vehicle' : r.vehicleType.trim();
    final rid = r.recordId;
    return 'tyre_report_${vt}_${rid}_$dt.pdf';
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
      return await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> _reportsDir() async {
    final base = await _downloadDirectory();
    final dir = Directory(p.join(base.path, 'Reports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _savePdfToDisk(TyreRecord record) async {
    final dir = await _reportsDir();
    final path = p.join(dir.path, _safeFileName(record));

    final bytes = await _ModernPdfReport.build(record);
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

      if (!mounted) return;
      setState(() {
        _downloading[id] = false;
        _downloaded[id] = true;
      });

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
      if (!mounted) return;
      setState(() => _downloading[id] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _sharePdf(TyreRecord record) async {
    try {
      final file = await _savePdfToDisk(record);
      if (!mounted) return;

      setState(() => _downloaded[record.recordId] = true);

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
            position:
                Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ---------------- UI ----------------

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

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
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

/* ========================================================================== */
/* =========================  MODERN PDF BUILDER  =========================== */
/* ========================================================================== */

class _ModernPdfReport {
  // Gradient (same vibe as your UI)
  static const PdfColor _g1 = PdfColor.fromInt(0xFF00C6FF);
  static const PdfColor _g2 = PdfColor.fromInt(0xFF7F53FD);

  static const PdfColor _bg = PdfColor.fromInt(0xFFF6F7FA);
  static const PdfColor _card = PdfColors.white;
  static const PdfColor _text = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE7EAF0);

  static String _dash(String v) => v.trim().isEmpty ? '—' : v.trim();

  static PdfColor _statusColorPdf(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return PdfColors.red;
    if (t.contains('warning')) return PdfColors.orange;
    if (t.contains('safe')) return PdfColors.green;
    return PdfColors.teal;
  }

  static String _summaryStatus(TyreRecord r) {
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

  static String _fmtAny(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  // ✅ DO NOT print objects directly (this is what caused the raw JSON line)
  static String _pressureStatus(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final x = pressure.status;
      return _fmtAny(x);
    } catch (_) {
      return '—';
    }
  }

  static String _pressureReason(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final x = pressure.reason;
      return _fmtAny(x);
    } catch (_) {
      return '—';
    }
  }

  static String _pressureConfidence(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final x = pressure.confidence;
      return _fmtAny(x);
    } catch (_) {
      return '—';
    }
  }

  static Future<pw.ImageProvider?> _tryNetworkImage(String url) async {
    final u = url.trim();
    if (u.isEmpty || !u.startsWith('http')) return null;

    try {
      final res = await http
          .get(Uri.parse(u))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final Uint8List bytes = res.bodyBytes;
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _pill(String text, {PdfColor? bg, bool filled = true}) {
    final t = _dash(text);
    final color = bg ?? PdfColor.fromInt(0xFF111827);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: filled ? color : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(999),
        border: filled ? null : pw.Border.all(color: color, width: 1),
      ),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: filled ? PdfColors.white : color,
        ),
      ),
    );
  }

  static pw.Widget _cardBlock({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: _border, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 112,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 9.6,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 10.2,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _kvList(List<List<String>> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final r in rows) _kv(r[0], r[1]),
      ],
    );
  }

  static pw.Widget _header({required pw.ImageProvider? logo, required TyreRecord r}) {
    final summary = _summaryStatus(r);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_g1, _g2],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 56,
            height: 56,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: logo == null
                ? pw.Center(
                    child: pw.Text(
                      'TT',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF111827),
                      ),
                    ),
                  )
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Tyre Inspection Report',
                  style: pw.TextStyle(
                    fontSize: 16.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Professional scan summary with tyre health & pressure details',
                  style: pw.TextStyle(fontSize: 9.8, color: PdfColors.white),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    _pill(r.vehicleType.toUpperCase(),
                        bg: PdfColor.fromInt(0x33000000), filled: true),
                    pw.SizedBox(width: 8),
                    _pill(summary, bg: _statusColorPdf(summary), filled: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _row2({required pw.Widget left, required pw.Widget right}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: left),
        pw.SizedBox(width: 10),
        pw.Expanded(child: right),
      ],
    );
  }

  static String _shortUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '—';
    if (u.length <= 56) return u;
    return '${u.substring(0, 34)}…${u.substring(u.length - 18)}';
  }

  static pw.Widget _imageTile(String title, pw.ImageProvider? img) {
    return pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.8,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 120,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF2F4F8),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: img == null
                ? pw.Center(
                    child: pw.Text(
                      'No image',
                      style: pw.TextStyle(fontSize: 10, color: _muted),
                    ),
                  )
                : pw.ClipRRect(
                    horizontalRadius: 10,
                    verticalRadius: 10,
                    child: pw.Image(img, fit: pw.BoxFit.cover),
                  ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _wheelDetailCard(_WheelData w) {
    final status = _dash(w.status);
    final statusColor = _statusColorPdf(status);

    return _cardBlock(
      title: w.title,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // image
              pw.Container(
                width: 110,
                height: 110,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF2F4F8),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: _border),
                ),
                child: w.image == null
                    ? pw.Center(
                        child: pw.Text('No image',
                            style: pw.TextStyle(fontSize: 9.5, color: _muted)),
                      )
                    : pw.ClipRRect(
                        horizontalRadius: 12,
                        verticalRadius: 12,
                        child: pw.Image(w.image!, fit: pw.BoxFit.cover),
                      ),
              ),
              pw.SizedBox(width: 12),

              // details
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'Status',
                          style: pw.TextStyle(
                            fontSize: 9.6,
                            fontWeight: pw.FontWeight.bold,
                            color: _muted,
                          ),
                        ),
                        pw.Spacer(),
                        _pill(status, bg: statusColor, filled: true),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    _kv('Tread', _dash(w.tread)),
                    _kv('Wear patterns', _dash(w.wear)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 8),

          // Pressure
          pw.Text(
            'Tyre Pressure',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Status', _pressureStatus(w.pressure)),
          _kv('Reason', _pressureReason(w.pressure)),
          _kv('Confidence', _pressureConfidence(w.pressure)),

          pw.SizedBox(height: 10),
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 8),

          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _dash(w.summary),
            style: pw.TextStyle(fontSize: 10.2, color: _text, height: 1.35),
          ),

          pw.SizedBox(height: 10),

          pw.Text(
            'Wheel Image Link',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 4),
          (w.imageUrl.trim().isEmpty || !w.imageUrl.trim().startsWith('http'))
              ? pw.Text('—', style: pw.TextStyle(fontSize: 10.1, color: _text))
              : pw.UrlLink(
                  destination: w.imageUrl.trim(),
                  child: pw.Text(
                    _shortUrl(w.imageUrl),
                    style: pw.TextStyle(
                      fontSize: 10.1,
                      color: PdfColor.fromInt(0xFF2563EB),
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// ✅ Main entry
  /// NOTE: We pre-build ALL async parts BEFORE putting widgets into `build: [...]`
  static Future<List<int>> build(TyreRecord r) async {
    // Logo (optional)
    pw.ImageProvider? logo;
    try {
      final bytes =
          (await rootBundle.load('assets/tiretest_logo.png')).buffer.asUint8List();
      logo = pw.MemoryImage(bytes);
    } catch (_) {
      logo = null;
    }

    final isCar = r.vehicleType.toLowerCase().trim() == 'car';
    final isBike = r.vehicleType.toLowerCase().trim() == 'bike';

    // Build wheel list (data)
    final wheels = <_WheelData>[];
    if (isCar) {
      wheels.addAll([
        _WheelData(
          title: 'Front Left',
          status: r.frontLeftStatus,
          tread: r.frontLeftTread,
          wear: r.frontLeftWearPatterns,
          pressure: r.frontLeftPressure,
          summary: r.frontLeftSummary,
          imageUrl: r.frontLeftWheel,
        ),
        _WheelData(
          title: 'Front Right',
          status: r.frontRightStatus,
          tread: r.frontRightTread,
          wear: r.frontRightWearPatterns,
          pressure: r.frontRightPressure,
          summary: r.frontRightSummary,
          imageUrl: r.frontRightWheel,
        ),
        _WheelData(
          title: 'Back Left',
          status: r.backLeftStatus,
          tread: r.backLeftTread,
          wear: r.backLeftWearPatterns,
          pressure: r.backLeftPressure,
          summary: r.backLeftSummary,
          imageUrl: r.backLeftWheel,
        ),
        _WheelData(
          title: 'Back Right',
          status: r.backRightStatus,
          tread: r.backRightTread,
          wear: r.backRightWearPatterns,
          pressure: r.backRightPressure,
          summary: r.backRightSummary,
          imageUrl: r.backRightWheel,
        ),
      ]);
    } else if (isBike) {
      wheels.addAll([
        _WheelData(
          title: 'Front Tyre',
          status: r.bikeFrontStatus,
          tread: r.bikeFrontTread,
          wear: r.bikeFrontWearPatterns,
          pressure: r.bikeFrontPressure,
          summary: r.bikeFrontSummary,
          imageUrl: r.bikeFrontWheel,
        ),
        _WheelData(
          title: 'Back Tyre',
          status: r.bikeBackStatus,
          tread: r.bikeBackTread,
          wear: r.bikeBackWearPatterns,
          pressure: r.bikeBackPressure,
          summary: r.bikeBackSummary,
          imageUrl: r.bikeBackWheel,
        ),
      ]);
    }

    // ✅ Pre-fetch wheel images (async)
    for (final w in wheels) {
      w.image = await _tryNetworkImage(w.imageUrl);
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);

    final doc = pw.Document();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(18, 18, 18, 22),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      // ✅ Simple background only (NO giant shapes / NO green overlays)
      buildBackground: (_) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(color: _bg),
      ),
    );

    // ✅ Pre-build sections list (NO await inside MultiPage build list)
    final wheelSections = <pw.Widget>[
      for (final w in wheels) ...[
        _wheelDetailCard(w),
        pw.SizedBox(height: 12),
      ]
    ];

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (ctx) => [
          _header(logo: logo, r: r),
          pw.SizedBox(height: 12),

          _row2(
            left: _cardBlock(
              title: 'Inspection Details',
              child: _kvList([
                ['Vehicle Type', _dash(r.vehicleType.toUpperCase())],
                ['Vehicle ID', _dash(r.vehicleId)],
                ['VIN', _dash(r.vin)],
                ['Record ID', '${r.recordId}'],
                ['User ID', _dash(r.userId)],
                ['Uploaded', dateStr],
              ]),
            ),
            right: _cardBlock(
              title: 'Report Summary',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Overall Status',
                    style: pw.TextStyle(fontSize: 10, color: _muted),
                  ),
                  pw.SizedBox(height: 8),
                  _pill(
                    _summaryStatus(r),
                    bg: _statusColorPdf(_summaryStatus(r)),
                    filled: true,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'This report includes tyre health, wear patterns and tyre pressure signals from your scan.',
                    style: pw.TextStyle(fontSize: 10.4, color: _text, height: 1.35),
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 12),

          _cardBlock(
            title: 'Wheel Images',
            child: wheels.isEmpty
                ? pw.Text(
                    'Unknown vehicle type: ${_dash(r.vehicleType)}',
                    style: pw.TextStyle(fontSize: 10.2, color: _text),
                  )
                : pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: wheels.map((w) => _imageTile(w.title, w.image)).toList(),
                  ),
          ),

          pw.SizedBox(height: 12),

          ...wheelSections,

          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Generated by TireTest AI • Powered by your scan data',
              style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromInt(0xFF9AA1AE)),
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

  final String title;
  final String status;
  final String tread;
  final String wear;
  final dynamic pressure;
  final String summary;
  final String imageUrl;

  pw.ImageProvider? image; // fetched async
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

/* ---------------- Filters ---------------- */

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

/* ---------------- Report Card ---------------- */

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

/* ---------------- Download Pill ---------------- */

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

/* ---------------- Download Dialog ---------------- */

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({
    required this.s,
    required this.onDownload,
    required this.onShare,
  });

  final double s;
  final VoidCallback onDownload;
  final VoidCallback onShare;

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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onShare,
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

//   static const _uiBg = Color(0xFFF6F7FA);
//   static const _g1 = Color(0xFF00C6FF);
//   static const _g2 = Color(0xFF7F53FD);
//   static const _text = Color(0xFF0F172A);
//   static const _muted = Color(0xFF6B7280);

//   @override
//   void initState() {
//     super.initState();

//     final bloc = context.read<AuthBloc>();
//     final st = bloc.state;

//     final userId = (st.profile?.userId?.toString() ?? '').trim();
//     if (userId.isNotEmpty && st.tyreHistoryStatus == TyreHistoryStatus.initial) {
//       bloc.add(FetchTyreHistoryRequested(userId: userId, vehicleId: "ALL"));
//     }
//   }

//   // ---------------- Filters ----------------

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
//     // keeps your existing style but safer
//     final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final mm = d.minute.toString().padLeft(2, '0');
//     final am = d.hour >= 12 ? 'PM' : 'AM';
//     return '${DateFormat('dd MMM, yyyy').format(d)}  —  $hh:$mm $am';
//   }

//   // ---------------- File / Download ----------------

//   String _safeFileName(TyreRecord r) {
//     // ✅ FIX: never use $rid_ (Dart thinks rid_ is a variable)
//     final uploaded = r.uploadedAt;
//     final dt = DateFormat('yyyyMMdd_HHmmss').format(uploaded);
//     final vt = r.vehicleType.trim().isEmpty ? 'vehicle' : r.vehicleType.trim().toLowerCase();
//     final rid = r.recordId;
//     return 'tyre_report_${vt}_${rid}_$dt.pdf';
//   }

//   Future<Directory> _downloadDirectory() async {
//     if (Platform.isAndroid) {
//       final dir = await getExternalStorageDirectory();
//       if (dir != null) return dir;
//       return await getApplicationDocumentsDirectory();
//     }
//     return await getApplicationDocumentsDirectory();
//   }

//   Future<Directory> _reportsDir() async {
//     final base = await _downloadDirectory();
//     final dir = Directory(p.join(base.path, 'Reports'));
//     if (!await dir.exists()) {
//       await dir.create(recursive: true);
//     }
//     return dir;
//   }

//   Future<File> _savePdfToDisk(TyreRecord record) async {
//     final dir = await _reportsDir();
//     final path = p.join(dir.path, _safeFileName(record));

//     final bytes = await TyrePdfBuilder.build(record);
//     final file = File(path);
//     await file.writeAsBytes(bytes, flush: true);
//     return file;
//   }

//   Future<void> _downloadPdf(TyreRecord record) async {
//     final id = record.recordId;
//     if (_downloading[id] == true) return;

//     setState(() => _downloading[id] = true);

//     try {
//       final file = await _savePdfToDisk(record);

//       if (!mounted) return;
//       setState(() {
//         _downloading[id] = false;
//         _downloaded[id] = true;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Saved: ${p.basename(file.path)}'),
//           action: SnackBarAction(
//             label: 'Open',
//             onPressed: () => OpenFilex.open(file.path),
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

//   Future<void> _sharePdf(TyreRecord record) async {
//     try {
//       final file = await _savePdfToDisk(record);
//       if (!mounted) return;

//       setState(() => _downloaded[record.recordId] = true);

//       await Share.shareXFiles(
//         [XFile(file.path)],
//         text: 'Tyre Inspection Report (${record.vehicleType.toUpperCase()})',
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Share failed: $e')),
//       );
//     }
//   }

//   void _openActionsSheet(TyreRecord record) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: false,
//       builder: (_) {
//         return _ActionsBottomSheet(
//           s: s,
//           onDownload: () async {
//             Navigator.of(context).pop();
//             await _downloadPdf(record);
//           },
//           onShare: () async {
//             Navigator.of(context).pop();
//             await _sharePdf(record);
//           },
//         );
//       },
//     );
//   }

//   // ---------------- Status (UI) ----------------

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
//       final s = <String>[
//         r.bikeFrontStatus,
//         r.bikeBackStatus,
//       ].map((e) => (e).toLowerCase()).toList();

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
//     ].map((e) => (e).toLowerCase()).toList();

//     if (statuses.any((s) => s.contains('danger'))) return 'Danger';
//     if (statuses.any((s) => s.contains('warning'))) return 'Warning';
//     if (statuses.any((s) => s.contains('safe'))) return 'Safe';
//     return 'Completed';
//   }

//   // ---------------- UI ----------------

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context).width / 390.0;

//     return Scaffold(
//       backgroundColor: _uiBg,
//       body: SafeArea(
//         child: BlocBuilder<AuthBloc, AuthState>(
//           builder: (context, state) {
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

//             return CustomScrollView(
//               slivers: [
//                 SliverToBoxAdapter(
//                   child: Padding(
//                     padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 12 * s),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _TopBar(s: s),
//                         SizedBox(height: 12 * s),

//                         _VehicleTabs(
//                           s: s,
//                           active: _vehicleTab,
//                           onChanged: (v) => setState(() => _vehicleTab = v),
//                         ),
//                         SizedBox(height: 12 * s),

//                         _FiltersBar(
//                           s: s,
//                           active: _filter,
//                           onChanged: (f) => setState(() => _filter = f),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Loading state
//                 if (state.tyreHistoryStatus == TyreHistoryStatus.loading)
//                   const SliverFillRemaining(
//                     hasScrollBody: false,
//                     child: Center(child: CircularProgressIndicator()),
//                   ),

//                 // Failure state
//                 if (state.tyreHistoryStatus == TyreHistoryStatus.failure)
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: EdgeInsets.fromLTRB(16 * s, 6 * s, 16 * s, 16 * s),
//                       child: _ErrorCard(
//                         s: s,
//                         message: state.tyreHistoryError ?? 'Failed to load history',
//                         onRetry: () {
//                           final userId =
//                               (state.profile?.userId?.toString() ?? '').trim();
//                           if (userId.isEmpty) return;
//                           context.read<AuthBloc>().add(
//                                 FetchTyreHistoryRequested(
//                                   userId: userId,
//                                   vehicleId: "ALL",
//                                 ),
//                               );
//                         },
//                       ),
//                     ),
//                   ),

//                 // Empty state
//                 if (state.tyreHistoryStatus == TyreHistoryStatus.success &&
//                     filtered.isEmpty)
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: EdgeInsets.fromLTRB(16 * s, 6 * s, 16 * s, 16 * s),
//                       child: _EmptyCard(s: s),
//                     ),
//                   ),

//                 // List
//                 if (state.tyreHistoryStatus == TyreHistoryStatus.success &&
//                     filtered.isNotEmpty)
//                   SliverPadding(
//                     padding: EdgeInsets.fromLTRB(16 * s, 6 * s, 16 * s, 24 * s),
//                     sliver: SliverList.separated(
//                       itemCount: filtered.length,
//                       separatorBuilder: (_, __) => SizedBox(height: 12 * s),
//                       itemBuilder: (_, i) {
//                         final it = filtered[i];
//                         final downloading = _downloading[it.recordId] == true;
//                         final downloaded = _downloaded[it.recordId] == true;

//                         final statusSummary = _summaryStatus(it);

//                         return _ReportCard(
//                           s: s,
//                           dateText: _prettyDate(it.uploadedAt),
//                           vehicleType: it.vehicleType,
//                           vehicleId: it.vehicleId,
//                           downloaded: downloaded,
//                           downloading: downloading,
//                           onDownload: () => _openActionsSheet(it),
//                           statusSummary: statusSummary,
//                           statusColor: _statusColorUi(statusSummary),
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// /* ---------------- Top Bar ---------------- */

// class _TopBar extends StatelessWidget {
//   const _TopBar({required this.s});
//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         // back
//         InkWell(
//           onTap: () => Navigator.maybePop(context),
//           borderRadius: BorderRadius.circular(12),
//           child: Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(14),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Color(0x14000000),
//                   blurRadius: 12,
//                   offset: Offset(0, 6),
//                 )
//               ],
//             ),
//             child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Text(
//             'Report History',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20 * s,
//               fontWeight: FontWeight.w900,
//               color: const Color(0xFF0F172A),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// /* ---------------- Vehicle Tabs ---------------- */

// class _VehicleTabs extends StatelessWidget {
//   const _VehicleTabs({
//     required this.s,
//     required this.active,
//     required this.onChanged,
//   });

//   final double s;
//   final _VehicleTab active;
//   final ValueChanged<_VehicleTab> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     Widget tab(_VehicleTab t, String label, IconData icon) {
//       final isActive = t == active;
//       return Expanded(
//         child: InkWell(
//           onTap: () => onChanged(t),
//           borderRadius: BorderRadius.circular(14 * s),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 180),
//             padding: EdgeInsets.symmetric(vertical: 10 * s),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(14 * s),
//               gradient: isActive
//                   ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
//                   : null,
//               color: isActive ? null : const Color(0xFFEFF2F8),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   icon,
//                   size: 18 * s,
//                   color: isActive ? Colors.white : const Color(0xFF111827),
//                 ),
//                 SizedBox(width: 6 * s),
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w900,
//                     color: isActive ? Colors.white : const Color(0xFF111827),
//                     fontSize: 13 * s,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: EdgeInsets.all(8 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 12,
//             offset: Offset(0, 6),
//           )
//         ],
//       ),
//       child: Row(
//         children: [
//           tab(_VehicleTab.all, 'All', Icons.dashboard_rounded),
//           SizedBox(width: 8 * s),
//           tab(_VehicleTab.car, 'Car', Icons.directions_car_filled_rounded),
//           SizedBox(width: 8 * s),
//           tab(_VehicleTab.bike, 'Bike', Icons.two_wheeler_rounded),
//         ],
//       ),
//     );
//   }
// }

// /* ---------------- Filters ---------------- */

// class _FiltersBar extends StatelessWidget {
//   const _FiltersBar({
//     required this.s,
//     required this.active,
//     required this.onChanged,
//   });

//   final double s;
//   final _Filter active;
//   final ValueChanged<_Filter> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     Widget chip(_Filter f, String label) {
//       final isActive = f == active;
//       return InkWell(
//         onTap: () => onChanged(f),
//         borderRadius: BorderRadius.circular(999),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 160),
//           padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(999),
//             gradient: isActive
//                 ? const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)])
//                 : null,
//             color: isActive ? null : const Color(0xFFEFF2F8),
//           ),
//           child: Text(
//             label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//               color: isActive ? Colors.white : const Color(0xFF111827),
//               fontSize: 13 * s,
//             ),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: EdgeInsets.all(8 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 12,
//             offset: Offset(0, 6),
//           )
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           chip(_Filter.all, 'All'),
//           chip(_Filter.today, 'Today'),
//           chip(_Filter.last7, 'Last 7 Days'),
//           chip(_Filter.thisMonth, 'This Month'),
//         ],
//       ),
//     );
//   }
// }

// /* ---------------- Report Card ---------------- */

// class _ReportCard extends StatelessWidget {
//   const _ReportCard({
//     required this.s,
//     required this.dateText,
//     required this.vehicleType,
//     required this.vehicleId,
//     required this.downloaded,
//     required this.downloading,
//     required this.onDownload,
//     required this.statusSummary,
//     required this.statusColor,
//   });

//   final double s;
//   final String dateText;
//   final String vehicleType;
//   final String vehicleId;
//   final bool downloaded;
//   final bool downloading;
//   final VoidCallback onDownload;
//   final String statusSummary;
//   final Color statusColor;

//   @override
//   Widget build(BuildContext context) {
//     final isBike = vehicleType.toLowerCase().trim() == 'bike';

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x12000000),
//             blurRadius: 12,
//             offset: Offset(0, 8),
//           )
//         ],
//         border: Border.all(color: const Color(0xFFE9EDF5)),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Accent bar
//           Container(
//             width: 8,
//             height: 136 * s,
//             decoration: const BoxDecoration(
//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(16),
//                 bottomLeft: Radius.circular(16),
//               ),
//               gradient: LinearGradient(
//                 colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),

//           Expanded(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(12 * s, 12 * s, 12 * s, 12 * s),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // title + action
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Report Generated',
//                           style: TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             fontWeight: FontWeight.w900,
//                             color: const Color(0xFF0F172A),
//                             fontSize: 16 * s,
//                           ),
//                         ),
//                       ),
//                       _DownloadPill(
//                         s: s,
//                         downloaded: downloaded,
//                         downloading: downloading,
//                         onTap: onDownload,
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 8 * s),

//                   _MetaRow(
//                     s: s,
//                     icon: Icons.event_note_rounded,
//                     text: dateText,
//                   ),
//                   SizedBox(height: 6 * s),

//                   _MetaRow(
//                     s: s,
//                     icon: isBike
//                         ? Icons.two_wheeler_rounded
//                         : Icons.directions_car_filled_rounded,
//                     text:
//                         'Vehicle: ${vehicleType.toUpperCase()} • ${vehicleId.trim().isEmpty ? "—" : vehicleId.trim()}',
//                   ),
//                   SizedBox(height: 6 * s),

//                   Row(
//                     children: [
//                       Icon(Icons.circle, size: 10 * s, color: statusColor),
//                       SizedBox(width: 6 * s),
//                       Text(
//                         'Status: $statusSummary',
//                         style: TextStyle(
//                           color: statusColor,
//                           fontSize: 12.5 * s,
//                           fontWeight: FontWeight.w900,
//                           fontFamily: 'ClashGrotesk',
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _MetaRow extends StatelessWidget {
//   const _MetaRow({required this.s, required this.icon, required this.text});
//   final double s;
//   final IconData icon;
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 16 * s, color: const Color(0xFF6B7280)),
//         SizedBox(width: 6 * s),
//         Expanded(
//           child: Text(
//             text,
//             style: TextStyle(
//               color: const Color(0xFF6B7280),
//               fontSize: 12.5 * s,
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w700,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }
// }

// /* ---------------- Download Pill ---------------- */

// class _DownloadPill extends StatelessWidget {
//   const _DownloadPill({
//     required this.s,
//     required this.downloaded,
//     required this.downloading,
//     required this.onTap,
//   });

//   final double s;
//   final bool downloaded;
//   final bool downloading;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final label = downloading
//         ? 'Downloading...'
//         : (downloaded ? 'Downloaded' : 'Download\nFull Report');

//     return InkWell(
//       onTap: downloading ? null : onTap,
//       borderRadius: BorderRadius.circular(14 * s),
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(14 * s),
//           gradient: const LinearGradient(
//             colors: [Color(0xFFEEF6FF), Color(0xFFEFF1FF)],
//           ),
//           border: Border.all(color: const Color(0xFFE6EBF5)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(.05),
//               blurRadius: 10,
//               offset: const Offset(0, 6),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 30 * s,
//               height: 30 * s,
//               decoration: const BoxDecoration(
//                 shape: BoxShape.circle,
//                 gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]),
//               ),
//               child: downloading
//                   ? Padding(
//                       padding: EdgeInsets.all(6 * s),
//                       child: const CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : Icon(
//                       Icons.picture_as_pdf_rounded,
//                       size: 19 * s,
//                       color: Colors.white,
//                     ),
//             ),
//             SizedBox(width: 8 * s),
//             Text(
//               label,
//               textAlign: TextAlign.right,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontWeight: FontWeight.w900,
//                 color: const Color(0xFF111827),
//                 fontSize: 11.5 * s,
//                 height: 1.0,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /* ---------------- Bottom Sheet Actions ---------------- */

// class _ActionsBottomSheet extends StatelessWidget {
//   const _ActionsBottomSheet({
//     required this.s,
//     required this.onDownload,
//     required this.onShare,
//   });

//   final double s;
//   final VoidCallback onDownload;
//   final VoidCallback onShare;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 16 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(22 * s)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x33000000),
//             blurRadius: 20,
//             offset: Offset(0, -6),
//           )
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 42,
//             height: 5,
//             margin: EdgeInsets.only(bottom: 14 * s),
//             decoration: BoxDecoration(
//               color: const Color(0xFFE5E7EB),
//               borderRadius: BorderRadius.circular(999),
//             ),
//           ),
//           Row(
//             children: [
//               Container(
//                 width: 52,
//                 height: 52,
//                 decoration: const BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)]),
//                 ),
//                 child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
//               ),
//               SizedBox(width: 12 * s),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Report Options',
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w900,
//                         fontSize: 16 * s,
//                         color: const Color(0xFF111827),
//                       ),
//                     ),
//                     SizedBox(height: 4 * s),
//                     Text(
//                       'Download or share your PDF report.',
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w700,
//                         fontSize: 12.5 * s,
//                         color: const Color(0xFF6B7280),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 14 * s),

//           _ActionBtn(
//             s: s,
//             label: 'Download PDF',
//             icon: Icons.download_rounded,
//             onTap: onDownload,
//           ),
//           SizedBox(height: 10 * s),
//           _ActionBtn(
//             s: s,
//             label: 'Share Report',
//             icon: Icons.ios_share_rounded,
//             onTap: onShare,
//           ),

//           SizedBox(height: 6 * s),
//         ],
//       ),
//     );
//   }
// }

// class _ActionBtn extends StatelessWidget {
//   const _ActionBtn({
//     required this.s,
//     required this.label,
//     required this.icon,
//     required this.onTap,
//   });

//   final double s;
//   final String label;
//   final IconData icon;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         onPressed: onTap,
//         icon: Icon(icon, size: 20 * s),
//         label: Text(
//           label,
//           style: TextStyle(
//             fontFamily: 'ClashGrotesk',
//             fontWeight: FontWeight.w900,
//             fontSize: 14.5 * s,
//           ),
//         ),
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(vertical: 14 * s),
//           foregroundColor: Colors.white,
//           backgroundColor: const Color(0xFF4F7BFF),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14 * s),
//           ),
//         ),
//       ),
//     );
//   }
// }

// /* ---------------- Error/Empty Cards ---------------- */

// class _ErrorCard extends StatelessWidget {
//   const _ErrorCard({required this.s, required this.message, required this.onRetry});
//   final double s;
//   final String message;
//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 12,
//             offset: Offset(0, 6),
//           )
//         ],
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.error_outline, color: Colors.redAccent),
//           SizedBox(width: 10 * s),
//           Expanded(
//             child: Text(
//               message,
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 color: const Color(0xFF111827),
//                 fontSize: 13 * s,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//           TextButton(
//             onPressed: onRetry,
//             child: const Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _EmptyCard extends StatelessWidget {
//   const _EmptyCard({required this.s});
//   final double s;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(14 * s),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16 * s),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x14000000),
//             blurRadius: 12,
//             offset: Offset(0, 6),
//           )
//         ],
//       ),
//       child: Text(
//         'No reports found.',
//         style: TextStyle(
//           fontFamily: 'ClashGrotesk',
//           color: const Color(0xFF111827),
//           fontSize: 13.5 * s,
//           fontWeight: FontWeight.w800,
//         ),
//       ),
//     );
//   }
// }

// /* =======================================================================
//    ✅ MODERN PDF BUILDER (FIXED)
//    - No "pageTheme + others" assertion
//    - No raw JSON printed
//    - Safe network images
//    - Better design: header card + info + images + wheel sections
//    ======================================================================= */

// class TyrePdfBuilder {
//   // PDF theme colors
//   static const PdfColor _bg = PdfColor.fromInt(0xFFF6F7FA);
//   static const PdfColor _card = PdfColor.fromInt(0xFFFFFFFF);
//   static const PdfColor _text = PdfColor.fromInt(0xFF111827);
//   static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

//   static const PdfColor _blue = PdfColor.fromInt(0xFF00C6FF);
//   static const PdfColor _purple = PdfColor.fromInt(0xFF7F53FD);

//   static const PdfColor _safe = PdfColor.fromInt(0xFF22C55E);
//   static const PdfColor _danger = PdfColor.fromInt(0xFFEF4444);
//   static const PdfColor _warn = PdfColor.fromInt(0xFFF59E0B);

//  static Future<List<int>> build(TyreRecord r) async {
//   // Logo (optional)
//   pw.ImageProvider? logo;
//   try {
//     final bytes =
//         (await rootBundle.load('assets/tiretest_logo.png')).buffer.asUint8List();
//     logo = pw.MemoryImage(bytes);
//   } catch (_) {
//     logo = null;
//   }

//   final doc = pw.Document();

//   final pageTheme = pw.PageTheme(
//     pageFormat: PdfPageFormat.a4,
//     margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
//     theme: pw.ThemeData.withFont(
//       base: pw.Font.helvetica(),
//       bold: pw.Font.helveticaBold(),
//     ),
//     buildBackground: (_) => pw.FullPage(
//       ignoreMargins: true,
//       child: pw.Container(color: _bg),
//     ),
//   );

//   final isCar = r.vehicleType.toLowerCase().trim() == 'car';
//   final isBike = r.vehicleType.toLowerCase().trim() == 'bike';

//   // build wheels list
//   final wheels = <_WheelData>[];
//   if (isCar) {
//     wheels.addAll([
//       _WheelData(
//         title: 'Front Left',
//         status: r.frontLeftStatus,
//         tread: r.frontLeftTread,
//         wear: r.frontLeftWearPatterns,
//         pressure: r.frontLeftPressure,
//         summary: r.frontLeftSummary,
//         imageUrl: r.frontLeftWheel,
//       ),
//       _WheelData(
//         title: 'Front Right',
//         status: r.frontRightStatus,
//         tread: r.frontRightTread,
//         wear: r.frontRightWearPatterns,
//         pressure: r.frontRightPressure,
//         summary: r.frontRightSummary,
//         imageUrl: r.frontRightWheel,
//       ),
//       _WheelData(
//         title: 'Back Left',
//         status: r.backLeftStatus,
//         tread: r.backLeftTread,
//         wear: r.backLeftWearPatterns,
//         pressure: r.backLeftPressure,
//         summary: r.backLeftSummary,
//         imageUrl: r.backLeftWheel,
//       ),
//       _WheelData(
//         title: 'Back Right',
//         status: r.backRightStatus,
//         tread: r.backRightTread,
//         wear: r.backRightWearPatterns,
//         pressure: r.backRightPressure,
//         summary: r.backRightSummary,
//         imageUrl: r.backRightWheel,
//       ),
//     ]);
//   } else if (isBike) {
//     wheels.addAll([
//       _WheelData(
//         title: 'Front Tyre',
//         status: r.bikeFrontStatus,
//         tread: r.bikeFrontTread,
//         wear: r.bikeFrontWearPatterns,
//         pressure: r.bikeFrontPressure,
//         summary: r.bikeFrontSummary,
//         imageUrl: r.bikeFrontWheel,
//       ),
//       _WheelData(
//         title: 'Back Tyre',
//         status: r.bikeBackStatus,
//         tread: r.bikeBackTread,
//         wear: r.bikeBackWearPatterns,
//         pressure: r.bikeBackPressure,
//         summary: r.bikeBackSummary,
//         imageUrl: r.bikeBackWheel,
//       ),
//     ]);
//   }

//   final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);

//   // ✅ IMPORTANT: build async widgets BEFORE addPage
//   final wheelSectionWidgets = await _wheelSections(wheels);

//   doc.addPage(
//     pw.MultiPage(
//       pageTheme: pageTheme,
//       build: (ctx) => [
//         _header(logo: logo, r: r),
//         pw.SizedBox(height: 14),

//         _row2(
//           left: _cardBlock(
//             title: 'Inspection Details',
//             child: _kvList([
//               ['Vehicle Type', _dash(r.vehicleType.toUpperCase())],
//               ['Vehicle ID', _dash(r.vehicleId)],
//               ['VIN', _dash(r.vin)],
//               ['Record ID', '${r.recordId}'],
//               ['User ID', _dash(r.userId)],
//               ['Uploaded', dateStr],
//             ]),
//           ),
//           right: _cardBlock(
//             title: 'Report Summary',
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text('Overall Status',
//                     style: pw.TextStyle(fontSize: 10, color: _muted)),
//                 pw.SizedBox(height: 8),
//                 _statusPill(_summaryStatus(r), filled: true),
//                 pw.SizedBox(height: 10),
//                 pw.Text(
//                   'This report is generated from your scan history and includes tyre pressure and wear analysis.',
//                   style: pw.TextStyle(
//                     fontSize: 10.5,
//                     color: _text,
//                     height: 1.35,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),

//         pw.SizedBox(height: 14),

//         _cardBlock(
//           title: 'Wheel Images',
//           child: pw.Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children:
//                 wheels.map((w) => _imageTile(w.title, w.imageUrl)).toList(),
//           ),
//         ),

//         pw.SizedBox(height: 14),

//         // ✅ use prebuilt widgets (no await here)
//         ...wheelSectionWidgets,

//         pw.SizedBox(height: 14),
//         pw.Center(
//           child: pw.Text(
//             'Generated by TireTest AI • Powered by your scan data',
//             style: pw.TextStyle(
//               fontSize: 9.5,
//               color: PdfColor.fromInt(0xFF9AA1AE),
//             ),
//           ),
//         ),
//       ],
//     ),
//   );

//   return doc.save();
// }

//   static pw.Widget _header({required pw.ImageProvider? logo, required TyreRecord r}) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: _card,
//         borderRadius: pw.BorderRadius.circular(16),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//         boxShadow: [
//           pw.BoxShadow(
//             color: PdfColor.fromInt(0x11000000),
//             blurRadius: 12,
//             offset: const PdfPoint(0, 6),
//           ),
//         ],
//       ),
//       child: pw.Row(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Container(
//             width: 56,
//             height: 56,
//             padding: const pw.EdgeInsets.all(10),
//             decoration: pw.BoxDecoration(
//               gradient: const pw.LinearGradient(
//                 colors: [_blue, _purple],
//                 begin: pw.Alignment.centerLeft,
//                 end: pw.Alignment.centerRight,
//               ),
//               borderRadius: pw.BorderRadius.circular(14),
//             ),
//             child: logo == null
//                 ? pw.Center(
//                     child: pw.Text(
//                       'AI',
//                       style: pw.TextStyle(
//                         color: PdfColors.white,
//                         fontWeight: pw.FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   )
//                 : pw.Image(logo, fit: pw.BoxFit.contain),
//           ),
//           pw.SizedBox(width: 12),
//           pw.Expanded(
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text(
//                   'Tyre Inspection Report',
//                   style: pw.TextStyle(
//                     fontSize: 18,
//                     color: _text,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.Text(
//                   'Generated from your scan history',
//                   style: pw.TextStyle(fontSize: 10.5, color: _muted),
//                 ),
//                 pw.SizedBox(height: 10),
//                 pw.Row(
//                   children: [
//                     _chip('Vehicle', r.vehicleType.toUpperCase()),
//                     pw.SizedBox(width: 8),
//                     _chip('Record', '${r.recordId}'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           _statusPill(_summaryStatus(r), filled: false),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _chip(String label, String value) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: pw.BoxDecoration(
//         color: PdfColor.fromInt(0xFFF3F4F6),
//         borderRadius: pw.BorderRadius.circular(999),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//       ),
//       child: pw.Row(
//         mainAxisSize: pw.MainAxisSize.min,
//         children: [
//           pw.Text('$label: ', style: pw.TextStyle(fontSize: 9.5, color: _muted)),
//           pw.Text(value, style: pw.TextStyle(fontSize: 9.5, color: _text, fontWeight: pw.FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   static pw.Widget _row2({required pw.Widget left, required pw.Widget right}) {
//     return pw.Row(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Expanded(child: left),
//         pw.SizedBox(width: 12),
//         pw.Expanded(child: right),
//       ],
//     );
//   }

//   static pw.Widget _cardBlock({required String title, required pw.Widget child}) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: _card,
//         borderRadius: pw.BorderRadius.circular(16),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//         boxShadow: [
//           pw.BoxShadow(
//             color: PdfColor.fromInt(0x11000000),
//             blurRadius: 12,
//             offset: const PdfPoint(0, 6),
//           ),
//         ],
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Row(
//             children: [
//               pw.Container(
//                 width: 6,
//                 height: 18,
//                 decoration: pw.BoxDecoration(
//                   color: _blue,
//                   borderRadius: pw.BorderRadius.circular(999),
//                 ),
//               ),
//               pw.SizedBox(width: 8),
//               pw.Text(
//                 title,
//                 style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _text),
//               ),
//               pw.Spacer(),
//               pw.Container(
//                 width: 28,
//                 height: 6,
//                 decoration: pw.BoxDecoration(
//                   color: _purple,
//                   borderRadius: pw.BorderRadius.circular(999),
//                 ),
//               ),
//             ],
//           ),
//           pw.SizedBox(height: 12),
//           child,
//         ],
//       ),
//     );
//   }

//   static pw.Widget _kvList(List<List<String>> rows) {
//     return pw.Column(
//       children: rows.map((r) {
//         return pw.Container(
//           padding: const pw.EdgeInsets.symmetric(vertical: 6),
//           decoration: pw.BoxDecoration(
//             border: pw.Border(
//               bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.8),
//             ),
//           ),
//           child: pw.Row(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.SizedBox(
//                 width: 88,
//                 child: pw.Text(r[0], style: pw.TextStyle(fontSize: 10, color: _muted)),
//               ),
//               pw.Expanded(
//                 child: pw.Text(
//                   r[1],
//                   style: pw.TextStyle(fontSize: 10.5, color: _text, fontWeight: pw.FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }

//   static pw.Widget _statusPill(String status, {required bool filled}) {
//     final s = (status.trim().isEmpty) ? 'Unknown' : status.trim();
//     final c = _statusColor(s);
//     final bg = filled ? _softBg(c) : PdfColors.white;

//     return pw.Container(
//       padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: pw.BoxDecoration(
//         color: bg,
//         borderRadius: pw.BorderRadius.circular(999),
//         border: pw.Border.all(color: c, width: 1),
//       ),
//       child: pw.Text(
//         s,
//         style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: c),
//       ),
//     );
//   }

//   static PdfColor _statusColor(String v) {
//     final t = v.toLowerCase();
//     if (t.contains('danger')) return _danger;
//     if (t.contains('warning')) return _warn;
//     if (t.contains('safe')) return _safe;
//     return PdfColor.fromInt(0xFF10B981);
//   }

//   static PdfColor _softBg(PdfColor c) {
//     // simple soft background
//     if (c == _danger) return PdfColor.fromInt(0xFFFDECEC);
//     if (c == _warn) return PdfColor.fromInt(0xFFFFF7ED);
//     if (c == _safe) return PdfColor.fromInt(0xFFE9F9EE);
//     return PdfColor.fromInt(0xFFE8FBF6);
//   }

//   static String _dash(String v) {
//     final s = v.trim();
//     if (s.isEmpty) return '—';
//     if (s.toLowerCase() == 'null') return '—';
//     return s;
//   }

//   static String _summaryStatus(TyreRecord r) {
//     final vt = r.vehicleType.toLowerCase().trim();
//     if (vt == 'bike') {
//       final s = <String>[r.bikeFrontStatus, r.bikeBackStatus].map((e) => e.toLowerCase()).toList();
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

//   static pw.Widget _imageTile(String title, String url) {
//     // No image embedding here (fast). Link+title tiles.
//     final u = url.trim();
//     final has = u.isNotEmpty && u.startsWith('http');

//     return pw.Container(
//       width: 240,
//       padding: const pw.EdgeInsets.all(12),
//       decoration: pw.BoxDecoration(
//         color: PdfColor.fromInt(0xFFF9FAFB),
//         borderRadius: pw.BorderRadius.circular(14),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _text)),
//           pw.SizedBox(height: 6),
//           pw.Text(
//             has ? u : 'No image',
//             style: pw.TextStyle(fontSize: 9.2, color: has ? PdfColor.fromInt(0xFF2563EB) : _muted),
//           ),
//         ],
//       ),
//     );
//   }

//   static Future<List<pw.Widget>> _wheelSections(List<_WheelData> wheels) async {
//     final out = <pw.Widget>[];

//     for (final w in wheels) {
//       final imgBytes = await _loadImageBytes(w.imageUrl);

//       out.add(
//         pw.Container(
//           margin: const pw.EdgeInsets.only(bottom: 12),
//           child: _cardBlock(
//             title: w.title,
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 // image preview
//                 if (imgBytes != null)
//                   pw.ClipRRect(
//                     horizontalRadius: 12,
//                     verticalRadius: 12,
//                     child: pw.Container(
//                       height: 180,
//                       width: double.infinity,
//                       child: pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.cover),
//                     ),
//                   )
//                 else
//                   pw.Container(
//                     height: 180,
//                     decoration: pw.BoxDecoration(
//                       color: PdfColor.fromInt(0xFFF3F4F6),
//                       borderRadius: pw.BorderRadius.circular(12),
//                       border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//                     ),
//                     child: pw.Center(
//                       child: pw.Text('No image', style: pw.TextStyle(fontSize: 10.5, color: _muted)),
//                     ),
//                   ),

//                 pw.SizedBox(height: 12),

//                 // status + metrics
//                 pw.Row(
//                   children: [
//                     pw.Expanded(
//                       child: pw.Text(
//                         'Status: ${_dash(w.status)}',
//                         style: pw.TextStyle(
//                           fontSize: 11,
//                           fontWeight: pw.FontWeight.bold,
//                           color: _statusColor(_dash(w.status)),
//                         ),
//                       ),
//                     ),
//                     _statusPill(_dash(w.status), filled: false),
//                   ],
//                 ),

//                 pw.SizedBox(height: 10),

//                 pw.Row(
//                   children: [
//                     pw.Expanded(child: _metric('Tread', _dash(w.tread))),
//                     pw.SizedBox(width: 10),
//                     pw.Expanded(child: _metric('Wear patterns', _dash(w.wear))),
//                   ],
//                 ),

//                 pw.SizedBox(height: 12),
//                 pw.Text('Tyre Pressure', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _text)),
//                 pw.SizedBox(height: 6),

//                 _kvList([
//                   ['Status', _dash(_pStatus(w.pressure))],
//                   ['Reason', _dash(_pReason(w.pressure))],
//                   ['Confidence', _dash(_pConfidence(w.pressure))],
//                 ]),

//                 pw.SizedBox(height: 12),
//                 pw.Text('Summary', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _text)),
//                 pw.SizedBox(height: 6),
//                 pw.Text(_dash(w.summary), style: pw.TextStyle(fontSize: 10.5, color: _text, height: 1.35)),

//                 if (w.imageUrl.trim().isNotEmpty) ...[
//                   pw.SizedBox(height: 10),
//                   pw.Text('Wheel Image URL', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _text)),
//                   pw.SizedBox(height: 6),
//                   pw.Text(
//                     w.imageUrl,
//                     style: pw.TextStyle(fontSize: 9.3, color: PdfColor.fromInt(0xFF2563EB)),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return out;
//   }

//   static pw.Widget _metric(String label, String value) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(12),
//       decoration: pw.BoxDecoration(
//         color: PdfColor.fromInt(0xFFF9FAFB),
//         borderRadius: pw.BorderRadius.circular(12),
//         border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(label, style: pw.TextStyle(fontSize: 9.5, color: _muted)),
//           pw.SizedBox(height: 6),
//           pw.Text(value, style: pw.TextStyle(fontSize: 12, color: _text, fontWeight: pw.FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   static Future<Uint8List?> _loadImageBytes(String url) async {
//     final u = url.trim();
//     if (u.isEmpty || !u.startsWith('http')) return null;

//     try {
//       final res = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 12));
//       if (res.statusCode >= 200 && res.statusCode < 300 && res.bodyBytes.isNotEmpty) {
//         return res.bodyBytes;
//       }
//       return null;
//     } catch (_) {
//       return null;
//     }
//   }

//   // pressure safe getters (dynamic)
//   static String _pStatus(dynamic p) {
//     try {
//       final s = (p?.status ?? '').toString().trim();
//       return s.isEmpty ? '—' : s;
//     } catch (_) {
//       return '—';
//     }
//   }

//   static String _pReason(dynamic p) {
//     try {
//       final s = (p?.reason ?? '').toString().trim();
//       return s.isEmpty ? '—' : s;
//     } catch (_) {
//       return '—';
//     }
//   }

//   static String _pConfidence(dynamic p) {
//     try {
//       final s = (p?.confidence ?? '').toString().trim();
//       return s.isEmpty ? '—' : s;
//     } catch (_) {
//       return '—';
//     }
//   }
// }

// class _WheelData {
//   final String title;
//   final String status;
//   final String tread;
//   final String wear;
//   final dynamic pressure;
//   final String summary;
//   final String imageUrl;

//   _WheelData({
//     required this.title,
//     required this.status,
//     required this.tread,
//     required this.wear,
//     required this.pressure,
//     required this.summary,
//     required this.imageUrl,
//   });
// }