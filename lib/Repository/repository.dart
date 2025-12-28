import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ios_tiretest_ai/Data/token_store.dart';
import 'package:ios_tiretest_ai/Models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/Models/auth_models.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart';
import 'package:ios_tiretest_ai/Models/user_profile.dart';



class Failure {
  final String code;       
  final String message;
  final int? statusCode;
  const Failure({required this.code, required this.message, this.statusCode});
}

class Result<T> {
  final T? data;
  final Failure? failure;
  const Result._(this.data, this.failure);
  bool get isSuccess => failure == null;

  factory Result.ok(T data) => Result._(data, null);
  factory Result.fail(Failure f) => Result._(null, f);
}

abstract class AuthRepository {
  Future<Result<LoginResponse>> login(LoginRequest req);
  Future<Result<SignupResponse>> signup(SignupRequest req);
  Future<Result<UserProfile>> fetchProfile({String? token});
  Future<void> saveToken(String token);
  Future<String?> getSavedToken();
  Future<void> clearToken();
  Future<Result<TyreUploadResponse>> uploadTwoWheeler(TyreUploadRequest req);
   Future<Result<VehiclePreferencesModel>> addVehiclePreferences({
    required String vehiclePreference,
    required String brandName,
    required String modelName,
    required String licensePlate,
    required bool? isOwn,
    required String tireBrand,
    required String tireDimension,
  });


}

class AuthRepositoryHttp implements AuthRepository {
  AuthRepositoryHttp({
    this.timeout = const Duration(seconds: 60),
    TokenStore? tokenStore,
  }) : _tokenStore = tokenStore ?? TokenStore();

  final Duration timeout;
  final TokenStore _tokenStore;

  static const String _twoWheelerUrl =
      'http://54.162.208.215/app/tyre/twowheeler/upload';

  static const String _profileUrl =
      'http://54.162.208.215/backend/api/profile';

  Map<String, String> _jsonHeaders() => const {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  Failure _serverFail(http.Response res, {String? fallback}) {
    String msg = fallback ?? 'Server error (${res.statusCode})';
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed['message'] != null) {
        msg = parsed['message'].toString();
      }
    } catch (_) {/* ignore */}
    return Failure(code: 'server', message: msg, statusCode: res.statusCode);
  }


  @override
  Future<void> saveToken(String token) => _tokenStore.save(token);

  @override
  Future<String?> getSavedToken() => _tokenStore.read();

  @override
  Future<void> clearToken() => _tokenStore.clear();

  @override
  Future<Result<LoginResponse>> login(LoginRequest req) async {
    final uri = Uri.parse(ApiConfig.login);

    try {
      final res = await http
          .post(uri, headers: _jsonHeaders(), body: jsonEncode(req.toJson()))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Parse typed response
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final resp = LoginResponse.fromJson(parsed);

        // Try to extract token directly from raw JSON (covers various backend shapes)
        final tok = _extractTokenFromRaw(parsed);
        if (tok != null && tok.isNotEmpty) {
          await saveToken(tok);
        }

        if (!resp.isValid) {
          return Result.fail(Failure(
            code: 'validation',
            message: parsed['message']?.toString() ?? 'Login failed',
            statusCode: res.statusCode,
          ));
        }
        return Result.ok(resp);
      }
      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  /// Best-effort extraction for access token; adjust keys to your real payload.
  String? _extractTokenFromRaw(Map<String, dynamic> raw) {
    if (raw['token'] is String) return raw['token'] as String;
    if (raw['access_token'] is String) return raw['access_token'] as String;
    if (raw['accessToken'] is String) return raw['accessToken'] as String;

    final result = raw['result'];
    if (result is Map<String, dynamic>) {
      if (result['token'] is String) return result['token'] as String;
      if (result['access_token'] is String) return result['access_token'] as String;
      if (result['accessToken'] is String) return result['accessToken'] as String;
    }
    return null;
  }

  // -------------------- SIGNUP --------------------
  @override
  Future<Result<SignupResponse>> signup(SignupRequest req) async {
    final uri = Uri.parse(ApiConfig.signup);
    try {
      final res = await http
          .post(uri, headers: _jsonHeaders(), body: jsonEncode(req.toJson()))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final resp = SignupResponse.fromJson(parsed);
        if (!resp.isValid) {
          return Result.fail(Failure(
            code: 'validation',
            message: resp.message ?? 'Signup failed',
            statusCode: res.statusCode,
          ));
        }
        return Result.ok(resp);
      }

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  // -------------------- PROFILE (GET with Bearer) --------------------
  @override
  Future<Result<UserProfile>> fetchProfile({String? token}) async {
    final tok = token ?? await getSavedToken();
    print("GET SAVED TOKEN FROM PROFILE $tok");
      print("GET SAVED TOKEN FROM PROFILE $tok");
    if (tok == null || tok.isEmpty) {
      return Result.fail(const Failure(code: 'validation', message: 'No token available'));
    }

    final uri = Uri.parse(_profileUrl);
    final headers = {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $tok',
    };

    try {
      final res = await http.get(uri, headers: headers).timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        late final Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid JSON'));
        }

        final data = parsed['data'];
        if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
          final profile = UserProfile.fromJson(data.first as Map<String, dynamic>);
          return Result.ok(profile);
        }
        return Result.fail(const Failure(code: 'parse', message: 'Missing data array'));
      }

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

 // AuthRepositoryHttp.dart (top of file or near other endpoints)


@override
Future<Result<TyreUploadResponse>> uploadTwoWheeler(TyreUploadRequest req) async {
  final uri = Uri.parse(_twoWheelerUrl);
  final request = http.MultipartRequest('POST', uri);

  // Headers
  final masked = req.token.length > 9
      ? '${req.token.substring(0, 4)}…${req.token.substring(req.token.length - 4)}'
      : '***';
  request.headers.addAll({
    HttpHeaders.authorizationHeader: 'Bearer ${req.token}',
    HttpHeaders.acceptHeader: 'application/json',
    // DO NOT set content-type manually for MultipartRequest
  });

  // Fields (exactly per API)
  request.fields.addAll({
    'user_id': req.userId,
    'vehicle_type': req.vehicleType, // "bike"
    'vehicle_id': req.vehicleId,
    if (req.vin != null && req.vin!.trim().isNotEmpty) 'vin': req.vin!.trim(),
  });

  // Files
  Future<http.MultipartFile> _file(String field, String path) async {
    final mime = lookupMimeType(path) ?? 'image/jpeg';
    final media = MediaType.parse(mime);
    return http.MultipartFile.fromPath(field, path, contentType: media);
  }
  request.files.addAll([
    await _file('front', req.frontPath),
    await _file('back',  req.backPath),
  ]);

  try {
    // Helpful logs
    // ignore: avoid_print
    print('==[UPLOAD-2W]=> POST $_twoWheelerUrl');
    // ignore: avoid_print
    print('Headers: {Authorization: Bearer $masked, Accept: application/json}');
    // ignore: avoid_print
    print('Fields: ${request.fields}');
    // ignore: avoid_print
    print('Files: front=${req.frontPath} | back=${req.backPath}');

    final streamed = await request.send().timeout(timeout);
    final res = await http.Response.fromStream(streamed);

    // ignore: avoid_print
    print('<= [UPLOAD-2W] ${res.statusCode}');
    // ignore: avoid_print
    print('<= Body: ${res.body}');

    if (res.statusCode == 200) {
      final Map<String, dynamic> parsed = jsonDecode(res.body);
      final resp = TyreUploadResponse.fromJson(parsed);
      return Result.ok(resp);
    }

    // 404: show the real backend message
    if (res.statusCode == 404) {
      String msg = 'Not Found (404)';
      try {
        final j = jsonDecode(res.body);
        if (j is Map) {
          if (j['message'] != null) msg = j['message'].toString();
          else if (j['error'] != null) msg = j['error'].toString();
          else if (j['detail'] != null) msg = j['detail'].toString();
        }
      } catch (_) {}
      return Result.fail(Failure(code: '404', message: msg, statusCode: 404));
    }

    // Explicit 500 handling (your spec)
    if (res.statusCode == 500) {
      String msg = 'Internal Server Error';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['message'] != null) msg = j['message'].toString();
      } catch (_) {}
      return Result.fail(Failure(code: 'server', message: msg, statusCode: 500));
    }

    // Other non-200s
    String msg = 'Server error (${res.statusCode})';
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['message'] != null) msg = j['message'].toString();
    } catch (_) {}
    return Result.fail(Failure(code: 'server', message: msg, statusCode: res.statusCode));

  } on SocketException {
    return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
  } on TimeoutException {
    return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }
}

// auth_repository_http.dart

@override
Future<Result<VehiclePreferencesModel>> addVehiclePreferences({
  required String vehiclePreference,
  required String brandName,
  required String modelName,
  required String licensePlate,
  required bool? isOwn,
  required String tireBrand,
  required String tireDimension,
}) async {
  final box = GetStorage();
  final tok = box.read<String>("token");
  print("JWT TOKEN $tok");

  if (tok == null || tok.isEmpty) {
    return Result.fail(const Failure(
      code: 'validation',
      message: 'No token available. Please login again.',
    ));
  }

  final uri = Uri.parse(ApiConfig.vehiclePreferences);

  // EXACTLY like Postman
  final headers = <String, String>{
    HttpHeaders.acceptHeader: 'application/json',
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.authorizationHeader: 'Bearer $tok',
  };

  // IMPORTANT: JSON ARRAY with ONE OBJECT
  final bodyArray = [
    {
      "vehiclePreference": vehiclePreference,
      "brandName": brandName,
      "modelName": modelName,
      "licensePlate": licensePlate,
      "isOwn": isOwn, // true/false or null
      "tireBrand": tireBrand,
      "tireDimension": tireDimension,
    }
  ];

  final bodyJson = jsonEncode(bodyArray);

  print('== [VEHICLE-PREF] POST $uri');
  print('Headers: $headers');
  print('Body JSON: $bodyJson');

  try {
    final res = await http
        .post(
          uri,
          headers: headers,
          body: bodyJson,
        )
        .timeout(timeout);

    print('<= [VEHICLE-PREF] status: ${res.statusCode}');
    print('<= body: ${res.body}');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      late final Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return Result.fail(const Failure(
          code: 'parse',
          message: 'Invalid response format',
        ));
      }

      // for debugging to prove backend data is present
      print('PARSED vehicleIds: ${parsed["vehicleIds"]}');
      print('PARSED storedData length: ${(parsed["storedData"] as List?)?.length}');

      final model = VehiclePreferencesModel.fromJson(parsed);
      return Result.ok(model);
    }

    return Result.fail(_serverFail(res));
  } on SocketException {
    return Result.fail(const Failure(
      code: 'network',
      message: 'No internet connection',
    ));
  } on TimeoutException {
    return Result.fail(const Failure(
      code: 'timeout',
      message: 'Request timed out',
    ));
  } catch (e) {
    return Result.fail(Failure(
      code: 'unknown',
      message: e.toString(),
    ));
  }
}


}

class ApiConfig {
  static const login  = 'http://54.162.208.215/backend/api/login';
  static const signup = 'http://54.162.208.215/backend/api/signup';
  static const String _twoWheelerUrl =
    'http://54.162.208.215/app/tyre/twowheeler/upload';
      static const String vehiclePreferences =
      'http://54.162.208.215/backend/api/addVehiclePreference';
}

