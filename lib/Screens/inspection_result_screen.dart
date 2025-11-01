import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart';





class InspectionResultScreen extends StatelessWidget {
  const InspectionResultScreen({
    super.key,
    required this.frontPath,
    required this.backPath,
    this.response,
  });

  final String frontPath;
  final String backPath;
  final TyreUploadResponse? response;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final blue = const Color(0xFF4F7BFF);

    final d = response?.data;

final frontImg = (d?.frontWheelUrl != null)
    ? NetworkImage(d!.frontWheelUrl!)
    : FileImage(File(frontPath)) as ImageProvider;

final backImg = (d?.backWheelUrl != null)
    ? NetworkImage(d!.backWheelUrl!)
    : FileImage(File(backPath)) as ImageProvider;

    final frontStatus = d?.frontTyreStatus ?? 'Unknown';
    final backStatus = d?.backTyreStatus ?? 'Unknown';
    final vehicleId = d?.vehicleId ?? '—';
    final vehicleType = d?.vehicleType ?? '—';
    final recordId = d?.recordId;

    final summary = response?.message ??
        'Record #${recordId ?? "-"}, $vehicleType ($vehicleId).\n'
            'Front: $frontStatus, Back: $backStatus.';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Inspection Report',
            style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
        children: [
          // 3 thumbnails like mock (front/back/extra)
          Row(
            children: [
              _thumb(frontImg),
              SizedBox(width: 10 * s),
              _thumb(backImg),
              SizedBox(width: 10 * s),
              Expanded(
                child: Container(
                  height: 90 * s,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E8F5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.tire_repair_rounded, color: Color(0xFF4F7BFF)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * s),

          // metric cards (mapped to your fields)
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  s,
                  title: 'Front Tyre',
                  value: frontStatus,
                  status: 'Vehicle: $vehicleId',
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: _metricCard(
                  s,
                  title: 'Back Tyre',
                  value: backStatus,
                  status: 'Type: $vehicleType',
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * s),
          if (recordId != null)
            _metricWide(
              s,
              title: 'Record',
              value: '#$recordId',
              status: d?.vin?.isNotEmpty == true ? 'VIN: ${d!.vin}' : '—',
            ),
          SizedBox(height: 14 * s),

          // summary
          Container(
            padding: EdgeInsets.all(14 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E8F5)),
              boxShadow: const [BoxShadow(color: Color(0x140E1631), blurRadius: 12, offset: Offset(0, 8))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.article_rounded, color: blue),
                SizedBox(width: 10 * s),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(fontFamily: 'ClashGrotesk', color: const Color(0xFF111826)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 22 * s),

          // actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: Text('Share Report',
                      style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700)),
                  onPressed: () => _toast(context, 'Share pressed'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14 * s),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Download PDF',
                      style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800)),
                  onPressed: () => _toast(context, 'Download pressed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumb(ImageProvider image) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1.2,
          child: Image(image: image, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _metricCard(double s,
      {required String title, required String value, required String status}) {
    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8F5)),
        boxShadow: const [BoxShadow(color: Color(0x140E1631), blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(title,
              style: TextStyle(
                  fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800, color: const Color(0xFF4F7BFF))),
        ),
        SizedBox(height: 8 * s),
        Text('Value: $value',
            style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
        SizedBox(height: 4 * s),
        Text(status, style: const TextStyle(color: Color(0xFF6B7280))),
      ]),
    );
  }

  Widget _metricWide(double s, {required String title, required String value, required String status}) {
    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8F5)),
        boxShadow: const [BoxShadow(color: Color(0x140E1631), blurRadius: 12, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F0FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(title,
                style: TextStyle(
                    fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800, color: const Color(0xFF4F7BFF))),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text('Value: $value   •   $status',
                style: TextStyle(fontFamily: 'ClashGrotesk', color: const Color(0xFF1F2937))),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}
