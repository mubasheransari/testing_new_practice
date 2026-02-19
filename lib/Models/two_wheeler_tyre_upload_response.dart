import 'dart:convert';
import 'dart:typed_data';

TwoWheelerTyreUploadResponse twoWheelerTyreUploadResponseFromJson(String str) =>
    TwoWheelerTyreUploadResponse.fromJson(
      json.decode(str) as Map<String, dynamic>,
    );

String twoWheelerTyreUploadResponseToJson(TwoWheelerTyreUploadResponse data) =>
    json.encode(data.toJson());

class TwoWheelerTyreUploadResponse {
  final TwoWheelerData? data;
  final String message;

  const TwoWheelerTyreUploadResponse({
    required this.data,
    required this.message,
  });

  static String _s(dynamic v) => (v == null) ? '' : v.toString();

  factory TwoWheelerTyreUploadResponse.fromJson(Map<String, dynamic> json) {
    final d = json['data'];
    return TwoWheelerTyreUploadResponse(
      data: (d is Map<String, dynamic>) ? TwoWheelerData.fromJson(d) : null,
      message: _s(json['message']),
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data?.toJson(),
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
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory TwoWheelerData.fromJson(Map<String, dynamic> json) {
    final frontJson = json['front'];
    final backJson = json['back'];

    return TwoWheelerData(
      recordId: _i(json['record_id']),
      front: (frontJson is Map<String, dynamic>)
          ? TwoWheelerTyre.fromJson(frontJson)
          : const TwoWheelerTyre.empty(),
      back: (backJson is Map<String, dynamic>)
          ? TwoWheelerTyre.fromJson(backJson)
          : const TwoWheelerTyre.empty(),
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
  final PressureAdvisory? pressureAdvisory;
  final String summary;
  final String imageUrl;

  const TwoWheelerTyre({
    required this.condition,
    required this.treadDepth,
    required this.wearPatterns,
    required this.pressureAdvisory,
    required this.summary,
    required this.imageUrl,
  });

  const TwoWheelerTyre.empty()
      : condition = '',
        treadDepth = 0.0,
        wearPatterns = '',
        pressureAdvisory = null,
        summary = '',
        imageUrl = '';

  static String _s(dynamic v) => (v == null) ? '' : v.toString();

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory TwoWheelerTyre.fromJson(Map<String, dynamic> json) {
    final pa = json['pressure_advisory'];

    return TwoWheelerTyre(
      condition: _s(json['condition']),
      treadDepth: _d(json['tread_depth']),
      wearPatterns: _s(json['wear_patterns']),
      pressureAdvisory:
          (pa is Map<String, dynamic>) ? PressureAdvisory.fromJson(pa) : null,
      summary: _s(json['summary']),
      imageUrl: _s(json['image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition,
        'tread_depth': treadDepth,
        'wear_patterns': wearPatterns,
        'pressure_advisory': pressureAdvisory?.toJson(),
        'summary': summary,
        'image_url': imageUrl,
      };

  /// ✅ Helper: convert "data:image/png;base64,...." to bytes (for Image.memory)
  Uint8List? get imageBytes {
    final s = imageUrl.trim();
    if (s.isEmpty) return null;

    // supports: data:image/png;base64,xxxx OR plain base64
    final idx = s.indexOf('base64,');
    final b64 = (idx >= 0) ? s.substring(idx + 7) : s;

    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// ✅ Helper: tells you if it’s a data url
  bool get isDataUrl => imageUrl.trim().startsWith('data:image/');
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

  static String _s(dynamic v) => (v == null) ? '' : v.toString();

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

/*

TwoWheelerTyreUploadResponse twoWheelerTyreUploadResponseFromJson(String str) =>
    TwoWheelerTyreUploadResponse.fromJson(
      json.decode(str) as Map<String, dynamic>,
    );

String twoWheelerTyreUploadResponseToJson(TwoWheelerTyreUploadResponse data) =>
    json.encode(data.toJson());

class TwoWheelerTyreUploadResponse {
  final TwoWheelerData? data;
  final String message;

  const TwoWheelerTyreUploadResponse({
    required this.data,
    required this.message,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory TwoWheelerTyreUploadResponse.fromJson(Map<String, dynamic> json) {
    final d = json['data'];
    return TwoWheelerTyreUploadResponse(
      data: (d is Map<String, dynamic>) ? TwoWheelerData.fromJson(d) : null,
      message: _s(json['message']),
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data?.toJson(),
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
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory TwoWheelerData.fromJson(Map<String, dynamic> json) {
    final frontJson = json['front'];
    final backJson = json['back'];

    return TwoWheelerData(
      recordId: _i(json['record_id']),
      front: (frontJson is Map<String, dynamic>)
          ? TwoWheelerTyre.fromJson(frontJson)
          : const TwoWheelerTyre.empty(),
      back: (backJson is Map<String, dynamic>)
          ? TwoWheelerTyre.fromJson(backJson)
          : const TwoWheelerTyre.empty(),
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
  final PressureAdvisory? pressureAdvisory; // ✅ can be null safely
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

  const TwoWheelerTyre.empty()
      : condition = '',
        treadDepth = 0.0,
        wearPatterns = '',
        pressureAdvisory = null,
        summary = '',
        imageUrl = '';

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory TwoWheelerTyre.fromJson(Map<String, dynamic> json) {
    final pa = json['pressure_advisory'];

    return TwoWheelerTyre(
      condition: _s(json['condition']),
      treadDepth: _d(json['tread_depth']),
      wearPatterns: _s(json['wear_patterns']),
      pressureAdvisory: (pa is Map<String, dynamic>)
          ? PressureAdvisory.fromJson(pa)
          : null,
      summary: _s(json['summary']),
      imageUrl: _s(json['image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition,
        'tread_depth': treadDepth,
        'wear_patterns': wearPatterns,
        'pressure_advisory': pressureAdvisory?.toJson(),
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
*/