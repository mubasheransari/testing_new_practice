import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/models/two_wheeler_tyre_upload_response.dart';

class TwoWheelerReportResultScreen extends StatefulWidget {
  final String title;

  // upload args
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  // images
  final String frontPath;
  final String backPath;

  // ✅ REQUIRED tyre IDs
  final String frontTyreId;
  final String backTyreId;

  const TwoWheelerReportResultScreen({
    super.key,
    this.title = "Bike Report",
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    this.vehicleType = "bike",
    required this.frontPath,
    required this.backPath,
    required this.frontTyreId,
    required this.backTyreId,
  });

  @override
  State<TwoWheelerReportResultScreen> createState() =>
      _TwoWheelerReportResultScreenState();
}

class _TwoWheelerReportResultScreenState extends State<TwoWheelerReportResultScreen> {
  bool _dispatched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  void _upload() {
    if (_dispatched) return;
    _dispatched = true;

    context.read<AuthBloc>().add(
          UploadTwoWheelerRequested(
            userId: widget.userId,
            vehicleId: widget.vehicleId,
            token: widget.token,
            vin: widget.vin,
            vehicleType: widget.vehicleType,
            frontPath: widget.frontPath,
            backPath: widget.backPath,

            // ✅ add these in event
            frontTyreId: widget.frontTyreId,
            backTyreId: widget.backTyreId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (p, c) => p.twoWheelerStatus != c.twoWheelerStatus,
        listener: (context, state) {
          if (state.twoWheelerStatus == TwoWheelerStatus.failure &&
              state.twoWheelerError.trim().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.twoWheelerError)),
            );
          }
        },
        builder: (context, state) {
          final loading = state.twoWheelerStatus == TwoWheelerStatus.uploading;
          final TwoWheelerTyreUploadResponse? resp = state.twoWheelerResponse;

          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (resp == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _dispatched = false);
                  _upload();
                },
                child: const Text("Retry"),
              ),
            );
          }

          // ✅ You can replace this UI with your existing report widgets/cards
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(resp.toString()),
            ),
          );
        },
      ),
    );
  }
}
