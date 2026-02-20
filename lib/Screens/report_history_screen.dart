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
// lib/screens/report_history_screen.dart
//
// ✅ Works with YOUR existing AuthState/AuthBloc:
// - uses state.tyreHistoryStatus / state.tyreHistoryError
// - uses getters: state.carRecords / state.bikeRecords / state.allTyreRecords
// - dispatches FetchTyreHistoryRequested(userId, vehicleId)
//
// ✅ Generates PDF that includes ALL response fields for BOTH Car + Bike
// ✅ Download + Share
//
// NOTE:
// - This file expects your TyreRecord model to expose the fields used below.
// - If any field name differs in your TyreRecord, just map it in the model (recommended).








// lib/screens/report_history_screen.dart
//
// ✅ Fixed + cleaned version of your file
// - Removes duplicate/old commented implementation
// - Fixes missing imports (Uint8List)
// - Makes download state robust by using String keys (recordId can be int OR string)
// - Prevents repeated setState after dispose (mounted checks)
// - Keeps SAME UI + SAME functionality (filters, tabs, download dialog, PDF, share, open)
//
// NOTE:
// - This expects your TyreRecord model to have the fields used below.
// - If any field name differs, map it in TyreRecord.


// lib/screens/report_history_screen.dart
// lib/screens/report_history_screen.dart
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

  // ---------------- PDF (FIXED) ----------------

  static const PdfColor _pdfBg = PdfColor.fromInt(0xFFF6F7FA);
  static const PdfColor _g1 = PdfColor.fromInt(0xFF00C6FF);
  static const PdfColor _g2 = PdfColor.fromInt(0xFF7F53FD);

  PdfColor _statusColorPdf(String v) {
    final t = v.toLowerCase();
    if (t.contains('danger')) return PdfColors.red;
    if (t.contains('warning')) return PdfColors.orange;
    if (t.contains('safe')) return PdfColors.green;
    return PdfColors.teal;
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
      final s = <String>[
        r.bikeFrontStatus,
        r.bikeBackStatus,
      ].map((e) => e.toLowerCase()).toList();

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

  String _dashIfEmpty(String v) => v.trim().isEmpty ? '—' : v.trim();

  pw.Widget _pill(String text, PdfColor bg) {
    final t = text.trim().isEmpty ? '—' : text.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _sectionTitle(String t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          fontSize: 13.5,
          color: PdfColor.fromInt(0xFF111827),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _card({required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE7EAF0)),
      ),
      child: child,
    );
  }

  pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 10.2,
                color: PdfColor.fromInt(0xFF6A6F7B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 10.5,
                color: PdfColor.fromInt(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _kvLong(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 10.2,
                color: PdfColor.fromInt(0xFF6A6F7B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 9.3,
                color: PdfColor.fromInt(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.ImageProvider?> _tryNetworkImage(String url) async {
    final u = url.trim();
    if (u.isEmpty || !u.startsWith('http')) return null;
    try {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode != 200) return null;
      final Uint8List bytes = res.bodyBytes;
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _imgTile(String label, pw.ImageProvider? img) {
    return pw.Container(
      width: 240,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE7EAF0)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF111827),
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
                ? pw.Center(child: pw.Text('No image'))
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

  String _fmtPressureStatus(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final s = (pressure.status ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  String _fmtPressureReason(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final s = (pressure.reason ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  String _fmtPressureConfidence(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final s = (pressure.confidence ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  List<pw.Widget> _wheelCards({
    required String title,
    required String status,
    required String tread,
    required String wear,
    required dynamic pressure,
    required String summary,
    required String imageUrl,
  }) {
    final safeStatus = status.trim().isEmpty ? '—' : status.trim();

    return [
      _card(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF111827),
                    ),
                  ),
                ),
                _pill(safeStatus, _statusColorPdf(safeStatus)),
              ],
            ),
            pw.SizedBox(height: 10),
            _kv('Tread', _dashIfEmpty(tread)),
            _kv('Wear patterns', _dashIfEmpty(wear)),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      _card(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Tyre Pressure',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF111827),
              ),
            ),
            pw.SizedBox(height: 10),
            _kv('Status', _fmtPressureStatus(pressure)),
            _kv('Reason', _fmtPressureReason(pressure)),
            _kv('Confidence', _fmtPressureConfidence(pressure)),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      _card(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Summary & Link',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF111827),
              ),
            ),
            pw.SizedBox(height: 10),
            _kvLong('Summary', _dashIfEmpty(summary)),
            _kvLong('Wheel image URL', _dashIfEmpty(imageUrl)),
          ],
        ),
      ),
    ];
  }

  pw.Widget _pdfHeader({required pw.ImageProvider? logo, required TyreRecord r}) {
    final summary = _summaryStatus(r);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(22, 22, 22, 16),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_g1, _g2],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(16)),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: 78,
            height: 78,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: logo == null
                ? pw.Center(child: pw.Text('Logo'))
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Tyre Inspection Report',
            style: pw.TextStyle(
              fontSize: 18.5,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated from your scan history',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _pill(r.vehicleType.toUpperCase(), PdfColor.fromInt(0x33000000)),
              pw.SizedBox(width: 10),
              _pill(summary, _statusColorPdf(summary)),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<int>> _buildPdfBytes(TyreRecord r) async {
    pw.ImageProvider? logo;
    try {
      final bytes =
          (await rootBundle.load('assets/tiretest_logo.png')).buffer.asUint8List();
      logo = pw.MemoryImage(bytes);
    } catch (_) {
      logo = null;
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);
    final isCar = r.vehicleType.toLowerCase().trim() == 'car';
    final isBike = r.vehicleType.toLowerCase().trim() == 'bike';

    final fl = await _tryNetworkImage(r.frontLeftWheel);
    final fr = await _tryNetworkImage(r.frontRightWheel);
    final bl = await _tryNetworkImage(r.backLeftWheel);
    final br = await _tryNetworkImage(r.backRightWheel);

    final bf = await _tryNetworkImage(r.bikeFrontWheel);
    final bb = await _tryNetworkImage(r.bikeBackWheel);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        maxPages: 999,

        // ✅ FIX HERE: put pageFormat + margin INSIDE pageTheme
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(18, 18, 18, 24),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _pdfBg),
          ),
        ),

        build: (context) => [
          _pdfHeader(logo: logo, r: r),
          pw.SizedBox(height: 14),

          _sectionTitle('Inspection Details'),
          _card(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Vehicle Type', r.vehicleType.toUpperCase()),
                _kv('Vehicle ID', _dashIfEmpty(r.vehicleId)),
                _kv('VIN', _dashIfEmpty(r.vin)),
                _kv('Record ID', r.recordId.toString()),
                _kv('User ID', _dashIfEmpty(r.userId)),
                _kv('Uploaded datetime', dateStr),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          _sectionTitle('Wheel Images'),
          _card(
            child: pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isCar) ...[
                  _imgTile('Front Left', fl),
                  _imgTile('Front Right', fr),
                  _imgTile('Back Left', bl),
                  _imgTile('Back Right', br),
                ],
                if (isBike) ...[
                  _imgTile('Front', bf),
                  _imgTile('Back', bb),
                ],
                if (!isCar && !isBike)
                  pw.Text('Unknown vehicle type: ${r.vehicleType}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          if (isCar) ...[
            _sectionTitle('Front Left Wheel'),
            ..._wheelCards(
              title: 'Front Left',
              status: r.frontLeftStatus,
              tread: r.frontLeftTread,
              wear: r.frontLeftWearPatterns,
              pressure: r.frontLeftPressure,
              summary: r.frontLeftSummary,
              imageUrl: r.frontLeftWheel,
            ),
            pw.SizedBox(height: 12),

            _sectionTitle('Front Right Wheel'),
            ..._wheelCards(
              title: 'Front Right',
              status: r.frontRightStatus,
              tread: r.frontRightTread,
              wear: r.frontRightWearPatterns,
              pressure: r.frontRightPressure,
              summary: r.frontRightSummary,
              imageUrl: r.frontRightWheel,
            ),
            pw.SizedBox(height: 12),

            _sectionTitle('Back Left Wheel'),
            ..._wheelCards(
              title: 'Back Left',
              status: r.backLeftStatus,
              tread: r.backLeftTread,
              wear: r.backLeftWearPatterns,
              pressure: r.backLeftPressure,
              summary: r.backLeftSummary,
              imageUrl: r.backLeftWheel,
            ),
            pw.SizedBox(height: 12),

            _sectionTitle('Back Right Wheel'),
            ..._wheelCards(
              title: 'Back Right',
              status: r.backRightStatus,
              tread: r.backRightTread,
              wear: r.backRightWearPatterns,
              pressure: r.backRightPressure,
              summary: r.backRightSummary,
              imageUrl: r.backRightWheel,
            ),
          ],

          if (isBike) ...[
            _sectionTitle('Front Tyre'),
            ..._wheelCards(
              title: 'Front Tyre',
              status: r.bikeFrontStatus,
              tread: r.bikeFrontTread,
              wear: r.bikeFrontWearPatterns,
              pressure: r.bikeFrontPressure,
              summary: r.bikeFrontSummary,
              imageUrl: r.bikeFrontWheel,
            ),
            pw.SizedBox(height: 12),

            _sectionTitle('Back Tyre'),
            ..._wheelCards(
              title: 'Back Tyre',
              status: r.bikeBackStatus,
              tread: r.bikeBackTread,
              wear: r.bikeBackWearPatterns,
              pressure: r.bikeBackPressure,
              summary: r.bikeBackSummary,
              imageUrl: r.bikeBackWheel,
            ),
          ],

          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text(
              'Generated by TireTest AI • Powered by your scan data',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromInt(0xFF9AA1AE),
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- UI ----------------

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

/*

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

    // ✅ same pattern: history loads after profile
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
    final vt = (r.vehicleType).trim().isEmpty ? 'vehicle' : r.vehicleType.trim();
    return 'tyre_report_${vt}_${r.recordId}_$dt.pdf';
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

  // ---------------- PDF ----------------

  static const PdfColor _pdfBg = PdfColor.fromInt(0xFFF6F7FA);
  static const PdfColor _g1 = PdfColor.fromInt(0xFF00C6FF);
  static const PdfColor _g2 = PdfColor.fromInt(0xFF7F53FD);

  PdfColor _statusColorPdf(String v) {
    final t = (v).toLowerCase();
    if (t.contains('danger')) return PdfColors.red;
    if (t.contains('warning')) return PdfColors.orange;
    if (t.contains('safe')) return PdfColors.green;
    return PdfColors.teal;
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

    // ✅ bike: front/back status
    if (vt == 'bike') {
      final s = <String>[
        r.bikeFrontStatus,
        r.bikeBackStatus,
      ].map((e) => e.toLowerCase()).toList();

      if (s.any((x) => x.contains('danger'))) return 'Danger';
      if (s.any((x) => x.contains('warning'))) return 'Warning';
      if (s.any((x) => x.contains('safe'))) return 'Safe';
      return 'Completed';
    }

    // ✅ car: all 4 wheel status
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

  pw.Widget _pill(String text, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _card({required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE7EAF0)),
      ),
      child: child,
    );
  }

  pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 10.5,
                color: PdfColor.fromInt(0xFF6A6F7B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 10.8,
                color: PdfColor.fromInt(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

Future<pw.ImageProvider?> _tryNetworkImage(String url) async {
  final u = url.trim();
  if (u.isEmpty || !u.startsWith('http')) return null;

  try {
    final res = await http.get(Uri.parse(u));
    if (res.statusCode != 200) return null;

    final Uint8List bytes = res.bodyBytes;
    if (bytes.isEmpty) return null;

    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

  pw.Widget _imgTile(String label, pw.ImageProvider? img) {
    return pw.Container(
      width: 240,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE7EAF0)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF111827),
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
                ? pw.Center(child: pw.Text('No image'))
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

  String _fmtPressureStatus(dynamic pressure) {
    // ✅ If your model uses a class: TyrePressureInfo { status, reason, confidence }
    // ✅ If backend returns null, show —
    try {
      if (pressure == null) return '—';
      final s = (pressure.status ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  String _fmtPressureReason(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final s = (pressure.reason ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  String _fmtPressureConfidence(dynamic pressure) {
    try {
      if (pressure == null) return '—';
      final s = (pressure.confidence ?? '').toString().trim();
      return s.isEmpty ? '—' : s;
    } catch (_) {
      return '—';
    }
  }

  pw.Widget _wheelBlock({
    required String title,
    required String status,
    required String tread,
    required String wear,
    required dynamic pressure,
    required String summary,
    required String imageUrl,
  }) {
    return _card(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF111827),
                  ),
                ),
              ),
              _pill(status.isEmpty ? '—' : status, _statusColorPdf(status)),
            ],
          ),
          pw.SizedBox(height: 10),
          _kv('Tread', tread.trim().isEmpty ? '—' : tread.trim()),
          _kv('Wear patterns', wear.trim().isEmpty ? '—' : wear.trim()),
          _kv('Tyre pressure status', _fmtPressureStatus(pressure)),
          _kv('Tyre pressure reason', _fmtPressureReason(pressure)),
          _kv('Tyre pressure confidence', _fmtPressureConfidence(pressure)),
          _kv('Summary', summary.trim().isEmpty ? '—' : summary.trim()),
          _kv('Wheel image URL', imageUrl.trim().isEmpty ? '—' : imageUrl.trim()),
        ],
      ),
    );
  }

  Future<List<int>> _buildPdfBytes(TyreRecord r) async {
    // ✅ logo is optional (won't crash if missing)
    pw.ImageProvider? logo;
    try {
      final bytes = (await rootBundle.load('assets/tiretest_logo.png'))
          .buffer
          .asUint8List();
      logo = pw.MemoryImage(bytes);
    } catch (_) {
      logo = null;
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(r.uploadedAt);

    // preload images
    final fl = await _tryNetworkImage(r.frontLeftWheel);
    final fr = await _tryNetworkImage(r.frontRightWheel);
    final bl = await _tryNetworkImage(r.backLeftWheel);
    final br = await _tryNetworkImage(r.backRightWheel);

    final bf = await _tryNetworkImage(r.bikeFrontWheel);
    final bb = await _tryNetworkImage(r.bikeBackWheel);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          pw.Container(
            color: _pdfBg,
            child: pw.Column(
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(22, 28, 22, 18),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [_g1, _g2],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 84,
                        height: 84,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(18),
                        ),
                        padding: const pw.EdgeInsets.all(10),
                        child: logo == null
                            ? pw.Center(child: pw.Text('Logo'))
                            : pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Tyre Inspection Report',
                        style: pw.TextStyle(
                          fontSize: 20,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Generated from your scan history',
                        style: pw.TextStyle(fontSize: 11.5, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _pill(r.vehicleType.toUpperCase(), PdfColor.fromInt(0x33000000)),
                          pw.SizedBox(width: 10),
                          _pill(_summaryStatus(r), _statusColorPdf(_summaryStatus(r))),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: pw.Column(
                    children: [
                      // Inspection details
                      _card(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Inspection Details',
                              style: pw.TextStyle(
                                fontSize: 13.5,
                                color: PdfColor.fromInt(0xFF111827),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 10),

                            // ✅ ALL response fields (common)
                            _kv('Vehicle Type', r.vehicleType.toUpperCase()),
                            _kv('Vehicle ID', r.vehicleId.trim().isEmpty ? '—' : r.vehicleId),
                            _kv('VIN', r.vin.trim().isEmpty ? '—' : r.vin),
                            _kv('Record ID', r.recordId.toString()),
                            _kv('User ID', r.userId.trim().isEmpty ? '—' : r.userId),
                            _kv('Uploaded datetime', dateStr),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 14),

                      // Wheel images
                      _card(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Wheel Images',
                              style: pw.TextStyle(
                                fontSize: 13.5,
                                color: PdfColor.fromInt(0xFF111827),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (r.vehicleType.toLowerCase() == 'car') ...[
                                  _imgTile('Front Left', fl),
                                  _imgTile('Front Right', fr),
                                  _imgTile('Back Left', bl),
                                  _imgTile('Back Right', br),
                                ] else ...[
                                  _imgTile('Front', bf),
                                  _imgTile('Back', bb),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 14),

                      // ✅ Car blocks (all response fields)
                      if (r.vehicleType.toLowerCase() == 'car') ...[
                        _wheelBlock(
                          title: 'Front Left',
                          status: r.frontLeftStatus,
                          tread: r.frontLeftTread,
                          wear: r.frontLeftWearPatterns,
                          pressure: r.frontLeftPressure,
                          summary: r.frontLeftSummary,
                          imageUrl: r.frontLeftWheel,
                        ),
                        pw.SizedBox(height: 12),
                        _wheelBlock(
                          title: 'Front Right',
                          status: r.frontRightStatus,
                          tread: r.frontRightTread,
                          wear: r.frontRightWearPatterns,
                          pressure: r.frontRightPressure,
                          summary: r.frontRightSummary,
                          imageUrl: r.frontRightWheel,
                        ),
                        pw.SizedBox(height: 12),
                        _wheelBlock(
                          title: 'Back Left',
                          status: r.backLeftStatus,
                          tread: r.backLeftTread,
                          wear: r.backLeftWearPatterns,
                          pressure: r.backLeftPressure,
                          summary: r.backLeftSummary,
                          imageUrl: r.backLeftWheel,
                        ),
                        pw.SizedBox(height: 12),
                        _wheelBlock(
                          title: 'Back Right',
                          status: r.backRightStatus,
                          tread: r.backRightTread,
                          wear: r.backRightWearPatterns,
                          pressure: r.backRightPressure,
                          summary: r.backRightSummary,
                          imageUrl: r.backRightWheel,
                        ),
                      ],

                      // ✅ Bike blocks (all response fields from your screenshot)
                      if (r.vehicleType.toLowerCase() == 'bike') ...[
                        _wheelBlock(
                          title: 'Front Tyre',
                          status: r.bikeFrontStatus,
                          tread: r.bikeFrontTread,
                          wear: r.bikeFrontWearPatterns,
                          pressure: r.bikeFrontPressure,
                          summary: r.bikeFrontSummary,
                          imageUrl: r.bikeFrontWheel,
                        ),
                        pw.SizedBox(height: 12),
                        _wheelBlock(
                          title: 'Back Tyre',
                          status: r.bikeBackStatus,
                          tread: r.bikeBackTread,
                          wear: r.bikeBackWearPatterns,
                          pressure: r.bikeBackPressure,
                          summary: r.bikeBackSummary,
                          imageUrl: r.bikeBackWheel,
                        ),
                      ],

                      pw.SizedBox(height: 18),
                      pw.Text(
                        'Generated by TireTest AI',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF9AA1AE),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // ✅ choose list from your state getters
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
                  color:
                      isActive ? Colors.white : const Color(0xFF111827),
                ),
                SizedBox(width: 6 * s),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w900,
                    color: isActive
                        ? Colors.white
                        : const Color(0xFF111827),
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
                          'Vehicle: ${vehicleType.toUpperCase()} • ${vehicleId.isEmpty ? "—" : vehicleId}',
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

*/