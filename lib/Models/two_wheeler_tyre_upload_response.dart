import 'dart:convert';

/// ✅ Parse from raw JSON string
TwoWheelerTyreUploadResponse twoWheelerTyreUploadResponseFromJson(String str) =>
    TwoWheelerTyreUploadResponse.fromJson(
      json.decode(str) as Map<String, dynamic>,
    );

/// ✅ Convert to raw JSON string
String twoWheelerTyreUploadResponseToJson(TwoWheelerTyreUploadResponse data) =>
    json.encode(data.toJson());

class TwoWheelerTyreUploadResponse {
  final TwoWheelerData data;
  final String message;

  const TwoWheelerTyreUploadResponse({
    required this.data,
    required this.message,
  });

  factory TwoWheelerTyreUploadResponse.fromJson(Map<String, dynamic> json) {
    return TwoWheelerTyreUploadResponse(
      data: TwoWheelerData.fromJson(
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

class TwoWheelerData {
  final int recordId;
  final TwoWheelerTyre front;
  final TwoWheelerTyre back;

  const TwoWheelerData({
    required this.recordId,
    required this.front,
    required this.back,
  });

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  factory TwoWheelerData.fromJson(Map<String, dynamic> json) {
    return TwoWheelerData(
      recordId: _i(json['record_id']),
      front: TwoWheelerTyre.fromJson(
        (json['front'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
      back: TwoWheelerTyre.fromJson(
        (json['back'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'record_id': recordId,
        'front': front.toJson(),
        'back': back.toJson(),
      };
}

class TwoWheelerTyre {
  final String condition;
  final double treadDepth;
  final String wearPatterns;
  final PressureAdvisory pressureAdvisory;
  final String summary;
  final String imageUrl; // can be data:image/png;base64,...

  const TwoWheelerTyre({
    required this.condition,
    required this.treadDepth,
    required this.wearPatterns,
    required this.pressureAdvisory,
    required this.summary,
    required this.imageUrl,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory TwoWheelerTyre.fromJson(Map<String, dynamic> json) {
    return TwoWheelerTyre(
      condition: _s(json['condition']),
      treadDepth: _d(json['tread_depth']),
      wearPatterns: _s(json['wear_patterns']),
      pressureAdvisory: PressureAdvisory.fromJson(
        (json['pressure_advisory'] ?? const <String, dynamic>{})
            as Map<String, dynamic>,
      ),
      summary: _s(json['summary']),
      imageUrl: _s(json['image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition,
        'tread_depth': treadDepth,
        'wear_patterns': wearPatterns,
        'pressure_advisory': pressureAdvisory.toJson(),
        'summary': summary,
        'image_url': imageUrl,
      };
}

class PressureAdvisory {
  final String status;
  final String reason;
  final String confidence;

  const PressureAdvisory({
    required this.status,
    required this.reason,
    required this.confidence,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory PressureAdvisory.fromJson(Map<String, dynamic> json) {
    return PressureAdvisory(
      status: _s(json['status']),
      reason: _s(json['reason']),
      confidence: _s(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'reason': reason,
        'confidence': confidence,
      };
}
