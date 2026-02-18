import 'dart:convert';

/// ✅ Parse from raw JSON string
ResponseFourWheeler responseFourWheelerFromJson(String str) =>
    ResponseFourWheeler.fromJson(json.decode(str) as Map<String, dynamic>);

/// ✅ Convert to raw JSON string
String responseFourWheelerToJson(ResponseFourWheeler data) =>
    json.encode(data.toJson());

class ResponseFourWheeler {
  final FourWheelerData data;
  final String message;

  const ResponseFourWheeler({
    required this.data,
    required this.message,
  });

  factory ResponseFourWheeler.fromJson(Map<String, dynamic> json) {
    return ResponseFourWheeler(
      data: FourWheelerData.fromJson(
        (json['data'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
      message: (json['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
        'message': message,
      };
}

class TirePressure {
  final String status;
  final String reason;
  final String confidence;

  const TirePressure({
    required this.status,
    required this.reason,
    required this.confidence,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory TirePressure.fromJson(Map<String, dynamic> json) => TirePressure(
        status: _s(json['status']),
        reason: _s(json['reason']),
        confidence: _s(json['confidence']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'reason': reason,
        'confidence': confidence,
      };
}

class FourWheelerData {
  final String userId;
  final String vehicleType;
  final int recordId;
  final String vehicleId;
  final String vin;

  final String frontLeftWheel;
  final String frontRightWheel;
  final String backLeftWheel;
  final String backRightWheel;

  final String frontLeftTyreStatus;
  final String frontRightTyreStatus;
  final String backLeftTyreStatus;
  final String backRightTyreStatus;

  final String frontLeftTreadDepth;
  final String frontRightTreadDepth;
  final String backLeftTreadDepth;
  final String backRightTreadDepth;

  final String frontLeftWearPatterns;
  final String frontRightWearPatterns;
  final String backLeftWearPatterns;
  final String backRightWearPatterns;

  final String frontLeftTypeImage;
  final String frontRightTypeImage;
  final String backLeftTypeImage;
  final String backRightTypeImage;

  // ✅ NEW: summaries (your API provides these)
  final String frontLeftSummary;
  final String frontRightSummary;
  final String backLeftSummary;
  final String backRightSummary;

  // ✅ NEW: tire pressure objects (your API provides these)
  final TirePressure? frontLeftTirePressure;
  final TirePressure? frontRightTirePressure;
  final TirePressure? backLeftTirePressure;
  final TirePressure? backRightTirePressure;

  const FourWheelerData({
    required this.userId,
    required this.vehicleType,
    required this.recordId,
    required this.vehicleId,
    required this.vin,
    required this.frontLeftWheel,
    required this.frontRightWheel,
    required this.backLeftWheel,
    required this.backRightWheel,
    required this.frontLeftTyreStatus,
    required this.frontRightTyreStatus,
    required this.backLeftTyreStatus,
    required this.backRightTyreStatus,
    required this.frontLeftTreadDepth,
    required this.frontRightTreadDepth,
    required this.backLeftTreadDepth,
    required this.backRightTreadDepth,
    required this.frontLeftWearPatterns,
    required this.frontRightWearPatterns,
    required this.backLeftWearPatterns,
    required this.backRightWearPatterns,
    required this.frontLeftTypeImage,
    required this.frontRightTypeImage,
    required this.backLeftTypeImage,
    required this.backRightTypeImage,
    required this.frontLeftSummary,
    required this.frontRightSummary,
    required this.backLeftSummary,
    required this.backRightSummary,
    required this.frontLeftTirePressure,
    required this.frontRightTirePressure,
    required this.backLeftTirePressure,
    required this.backRightTirePressure,
  });

  /// ✅ helpers
  static String _s(dynamic v) => v == null ? '' : v.toString();
  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static TirePressure? _tp(dynamic v) {
    if (v is Map<String, dynamic>) return TirePressure.fromJson(v);
    if (v is Map) return TirePressure.fromJson(Map<String, dynamic>.from(v));
    return null;
  }

  factory FourWheelerData.fromJson(Map<String, dynamic> json) => FourWheelerData(
        userId: _s(json['User ID']),
        vehicleType: _s(json['Vehicle type']),
        recordId: _i(json['Record ID']),
        vehicleId: _s(json['Vehicle ID']),
        vin: _s(json['Vin']),

        frontLeftWheel: _s(json['Front Left Wheel']),
        frontRightWheel: _s(json['Front Right Wheel']),
        backLeftWheel: _s(json['Back Left Wheel']),
        backRightWheel: _s(json['Back Right Wheel']),

        frontLeftTyreStatus: _s(json['Front Left Tyre status']),
        frontRightTyreStatus: _s(json['Front Right Tyre status']),
        backLeftTyreStatus: _s(json['Back Left Tyre status']),
        backRightTyreStatus: _s(json['Back Right Tyre status']),

        frontLeftTreadDepth: _s(json['Front Left Tread depth']),
        frontRightTreadDepth: _s(json['Front Right Tread depth']),
        backLeftTreadDepth: _s(json['Back Left Tread depth']),
        backRightTreadDepth: _s(json['Back Right Tread depth']),

        frontLeftWearPatterns: _s(json['Front Left Wear patterns']),
        frontRightWearPatterns: _s(json['Front Right Wear patterns']),
        backLeftWearPatterns: _s(json['Back Left Wear patterns']),
        backRightWearPatterns: _s(json['Back Right Wear patterns']),

        frontLeftTypeImage: _s(json['Front Left Type image']),
        frontRightTypeImage: _s(json['Front Right Type image']),
        backLeftTypeImage: _s(json['Back Left Type image']),
        backRightTypeImage: _s(json['Back Right Type image']),

        // ✅ NEW summaries
        frontLeftSummary: _s(json['Front Left Summary']),
        frontRightSummary: _s(json['Front Right Summary']),
        backLeftSummary: _s(json['Back Left Summary']),
        backRightSummary: _s(json['Back Right Summary']),

        // ✅ NEW pressure objects
        frontLeftTirePressure: _tp(json['Front Left Tire pressure']),
        frontRightTirePressure: _tp(json['Front Right Tire pressure']),
        backLeftTirePressure: _tp(json['Back Left Tire pressure']),
        backRightTirePressure: _tp(json['Back Right Tire pressure']),
      );

  Map<String, dynamic> toJson() => {
        'User ID': userId,
        'Vehicle type': vehicleType,
        'Record ID': recordId,
        'Vehicle ID': vehicleId,
        'Vin': vin,

        'Front Left Wheel': frontLeftWheel,
        'Front Right Wheel': frontRightWheel,
        'Back Left Wheel': backLeftWheel,
        'Back Right Wheel': backRightWheel,

        'Front Left Tyre status': frontLeftTyreStatus,
        'Front Right Tyre status': frontRightTyreStatus,
        'Back Left Tyre status': backLeftTyreStatus,
        'Back Right Tyre status': backRightTyreStatus,

        'Front Left Tread depth': frontLeftTreadDepth,
        'Front Right Tread depth': frontRightTreadDepth,
        'Back Left Tread depth': backLeftTreadDepth,
        'Back Right Tread depth': backRightTreadDepth,

        'Front Left Wear patterns': frontLeftWearPatterns,
        'Front Right Wear patterns': frontRightWearPatterns,
        'Back Left Wear patterns': backLeftWearPatterns,
        'Back Right Wear patterns': backRightWearPatterns,

        'Front Left Type image': frontLeftTypeImage,
        'Front Right Type image': frontRightTypeImage,
        'Back Left Type image': backLeftTypeImage,
        'Back Right Type image': backRightTypeImage,

        // ✅ NEW summaries
        'Front Left Summary': frontLeftSummary,
        'Front Right Summary': frontRightSummary,
        'Back Left Summary': backLeftSummary,
        'Back Right Summary': backRightSummary,

        // ✅ NEW pressure objects
        'Front Left Tire pressure': frontLeftTirePressure?.toJson(),
        'Front Right Tire pressure': frontRightTirePressure?.toJson(),
        'Back Left Tire pressure': backLeftTirePressure?.toJson(),
        'Back Right Tire pressure': backRightTirePressure?.toJson(),
      };
}
