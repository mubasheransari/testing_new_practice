import 'package:equatable/equatable.dart';

class TyreRecord extends Equatable {
  final String userId;
  final int recordId;
  final String vehicleType; // "car" | "bike"
  final String vehicleId;

  final String frontLeftStatus;
  final String frontRightStatus;
  final String backLeftStatus;
  final String backRightStatus;

  final DateTime uploadedAt;

  final String frontLeftWheelFile;
  final String frontRightWheelFile;
  final String backLeftWheelFile;
  final String backRightWheelFile;

  final String vin;

  const TyreRecord({
    required this.userId,
    required this.recordId,
    required this.vehicleType,
    required this.vehicleId,
    required this.frontLeftStatus,
    required this.frontRightStatus,
    required this.backLeftStatus,
    required this.backRightStatus,
    required this.uploadedAt,
    required this.frontLeftWheelFile,
    required this.frontRightWheelFile,
    required this.backLeftWheelFile,
    required this.backRightWheelFile,
    required this.vin,
  });

  /// Your API uses keys with spaces & mixed case. We map safely.
  factory TyreRecord.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString();

    DateTime parseDate(dynamic v) {
      final raw = s(v);
      // API example: "2025-12-31T15:16:23"
      final dt = DateTime.tryParse(raw);
      return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return TyreRecord(
      userId: s(json['User ID']),
      recordId: int.tryParse(s(json['Record ID'])) ?? 0,
      vehicleType: s(json['Vehicle type']).toLowerCase().trim(),
      vehicleId: s(json['Vehicle ID']),
      frontLeftStatus: s(json['Front Left Tyre status']),
      frontRightStatus: s(json['Front Right Tyre status']),
      backLeftStatus: s(json['Back Left Tyre status']),
      backRightStatus: s(json['Back Right Tyre status']),
      uploadedAt: parseDate(json['Uploaded Datetime']),
      frontLeftWheelFile: s(json['Front Left Wheel']),
      frontRightWheelFile: s(json['Front Right Wheel']),
      backLeftWheelFile: s(json['Back Left Wheel']),
      backRightWheelFile: s(json['Back Right Wheel']),
      vin: s(json['Vin']),
    );
  }

  @override
  List<Object?> get props => [
        userId,
        recordId,
        vehicleType,
        vehicleId,
        frontLeftStatus,
        frontRightStatus,
        backLeftStatus,
        backRightStatus,
        uploadedAt,
        frontLeftWheelFile,
        frontRightWheelFile,
        backLeftWheelFile,
        backRightWheelFile,
        vin,
      ];
}
