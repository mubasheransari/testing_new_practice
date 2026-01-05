import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ios_tiretest_ai/Data/token_store.dart';
import 'package:ios_tiretest_ai/models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/models/auth_models.dart';
import 'package:http_parser/http_parser.dart';
import 'package:ios_tiretest_ai/models/four_wheeler_uploads_request.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:mime/mime.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_response.dart';
import 'package:ios_tiretest_ai/models/user_profile.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';


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

  Future<Result<TyreUploadResponse>> uploadFourWheeler(FourWheelerUploadRequest req);

   Future<Result<List<TyreRecord>>> fetchUserRecords({
    required String userId,
    required String vehicleType, // "car" | "bike"
    String vehicleId = "ALL",
  });
}

class AuthRepositoryHttp implements AuthRepository {
  AuthRepositoryHttp({
    this.timeout = const Duration(seconds: 200),
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

  // ============================================================
  // ✅ NEW: SAFE compression helper (fix jpg/jpeg assertion)
  // ============================================================
  Future<File> _compressSafe(String inputPath) async {
    final inFile = File(inputPath);
    if (!await inFile.exists()) return inFile;

    final ext = p.extension(inputPath).toLowerCase();

    // ✅ choose output format based on input extension
    final bool isPng = ext == '.png';
    final CompressFormat format = isPng ? CompressFormat.png : CompressFormat.jpeg;
    final String outExt = isPng ? '.png' : '.jpg'; // ✅ VERY IMPORTANT

    final dir = inFile.parent.path;
    final base = p.basenameWithoutExtension(inputPath);
    final outPath = p.join(
      dir,
      'cmp_${DateTime.now().millisecondsSinceEpoch}_$base$outExt',
    );

    try {
      final XFile? outX = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        outPath,
        quality: 75,
        minWidth: 1080,
        keepExif: false,
        format: format,
      );

      if (outX != null && outX.path.isNotEmpty) {
        return File(outX.path);
      }
    } catch (_) {
      // If compression fails for any reason, fallback to original
    }

    return inFile;
  }

  // ============================================================
  // ✅ UPDATED: uploadFourWheeler uses _compressSafe for all files
  // ============================================================
  @override
  Future<Result<TyreUploadResponse>> uploadFourWheeler(
    FourWheelerUploadRequest req,
  ) async {
    final url = ApiConfig.fourWheelerUrl;
    final masked = req.token.length > 9
        ? '${req.token.substring(0, 4)}…${req.token.substring(req.token.length - 4)}'
        : '***';

    // ✅ sanitize fields
    final vinValue = req.vin.trim().isEmpty ? "UNKNOWN" : req.vin.trim();
    final vehicleTypeValue =
        req.vehicleType.trim().isEmpty ? "car" : req.vehicleType.trim();

    // ✅ check file exists + log sizes (raw)
    try {
      final paths = [
        req.frontLeftPath,
        req.frontRightPath,
        req.backLeftPath,
        req.backRightPath,
      ];

      int total = 0;
      for (final path in paths) {
        final f = File(path);
        if (!await f.exists()) {
          return Result.fail(Failure(
            code: 'file',
            message: 'File not found: $path',
          ));
        }
        final bytes = await f.length();
        total += bytes;
        // ignore: avoid_print
        print('FILE ${p.basename(path)}: ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      // ignore: avoid_print
      print('TOTAL UPLOAD (RAW): ${(total / 1024 / 1024).toStringAsFixed(2)} MB');
    } catch (_) {}

    const bool enableCompression = true;

    try {
      // ✅ compress safely (fixes jpg/jpeg assertion)
      final fl = enableCompression ? await _compressSafe(req.frontLeftPath) : File(req.frontLeftPath);
      final fr = enableCompression ? await _compressSafe(req.frontRightPath) : File(req.frontRightPath);
      final bl = enableCompression ? await _compressSafe(req.backLeftPath) : File(req.backLeftPath);
      final br = enableCompression ? await _compressSafe(req.backRightPath) : File(req.backRightPath);

      // ✅ log sizes after compression
      try {
        final files = [fl, fr, bl, br];
        int total = 0;
        for (final f in files) {
          final bytes = await f.length();
          total += bytes;
          // ignore: avoid_print
          print('CMP FILE ${p.basename(f.path)}: ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB');
        }
        // ignore: avoid_print
        print('TOTAL UPLOAD (COMPRESSED): ${(total / 1024 / 1024).toStringAsFixed(2)} MB');
      } catch (_) {}

      final dio = Dio(
        BaseOptions(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${req.token}',
            HttpHeaders.acceptHeader: 'application/json',
          },
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 200),
          receiveTimeout: const Duration(seconds: 200),
        ),
      );

      // ✅ IMPORTANT: always send filenames with correct extension
      final form = FormData.fromMap({
        'user_id': req.userId.trim(),
        'vehicle_id': req.vehicleId.trim(),
        'vehicle_type': vehicleTypeValue,
        'vin': vinValue,

        'front_left_tyre_id': req.frontLeftTyreId.trim(),
        'front_right_tyre_id': req.frontRightTyreId.trim(),
        'back_left_tyre_id': req.backLeftTyreId.trim(),
        'back_right_tyre_id': req.backRightTyreId.trim(),

        'front_left': await MultipartFile.fromFile(
          fl.path,
          filename: p.basename(fl.path),
        ),
        'front_right': await MultipartFile.fromFile(
          fr.path,
          filename: p.basename(fr.path),
        ),
        'back_left': await MultipartFile.fromFile(
          bl.path,
          filename: p.basename(bl.path),
        ),
        'back_right': await MultipartFile.fromFile(
          br.path,
          filename: p.basename(br.path),
        ),
      });

      // ignore: avoid_print
      print('==[UPLOAD-4W]=> POST $url');
      // ignore: avoid_print
      print('Headers: {Authorization: Bearer $masked, Accept: application/json}');
      // ignore: avoid_print
      print('Fields: {user_id:${req.userId}, vehicle_id:${req.vehicleId}, vehicle_type:$vehicleTypeValue, vin:$vinValue, '
          'front_left_tyre_id:${req.frontLeftTyreId}, front_right_tyre_id:${req.frontRightTyreId}, '
          'back_left_tyre_id:${req.backLeftTyreId}, back_right_tyre_id:${req.backRightTyreId}}');
      // ignore: avoid_print
      print('Files: FL=${fl.path} | FR=${fr.path} | BL=${bl.path} | BR=${br.path}');
      // ignore: avoid_print
      print('⏳ Sending... sendTimeout=200s receiveTimeout=200s');

      final res = await dio.post(
        url,
        data: form,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          final pct = (sent / total) * 100;
          // ignore: avoid_print
          print('⬆️ Upload: ${pct.toStringAsFixed(1)}% ($sent/$total bytes)');
        },
      );

      // ignore: avoid_print
      print('<= [UPLOAD-4W] ${res.statusCode}');
      // ignore: avoid_print
      print('<= Body: ${res.data}');

      final status = res.statusCode ?? 0;

      if (status == 200 || status == 201) {
        final data = res.data;

        Map<String, dynamic> parsed;
        if (data is Map<String, dynamic>) {
          parsed = data;
        } else if (data is String) {
          parsed = jsonDecode(data) as Map<String, dynamic>;
        } else {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }

        final resp = TyreUploadResponse.fromJson(parsed);
        return Result.ok(resp);
      }

      String msg = 'Server error ($status)';
      try {
        final data = res.data;
        if (data is Map) {
          if (data['message'] != null) msg = data['message'].toString();
          else if (data['error'] != null) msg = data['error'].toString();
          else if (data['detail'] != null) msg = data['detail'].toString();
        } else if (data is String && data.trim().isNotEmpty) {
          msg = data.length > 200 ? data.substring(0, 200) : data;
        }
      } catch (_) {}

      return Result.fail(Failure(code: 'server', message: msg, statusCode: status));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        // ignore: avoid_print
        print('⏱️ [UPLOAD-4W] TIMEOUT: ${e.type}  message=${e.message}');
        return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
      }

      if (e.type == DioExceptionType.connectionError) {
        return Result.fail(const Failure(code: 'network', message: 'Network error / server unreachable'));
      }

      final status = e.response?.statusCode;
      final data = e.response?.data;

      String msg = 'Request failed';
      try {
        if (data is Map) {
          if (data['message'] != null) msg = data['message'].toString();
          else if (data['error'] != null) msg = data['error'].toString();
          else if (data['detail'] != null) msg = data['detail'].toString();
          else msg = data.toString();
        } else if (data is String && data.trim().isNotEmpty) {
          msg = data.length > 200 ? data.substring(0, 200) : data;
        } else if (e.message != null) {
          msg = e.message!;
        }
      } catch (_) {
        msg = e.message ?? msg;
      }

      // ignore: avoid_print
      print('❌ [UPLOAD-4W] DioException status=$status data=$data message=${e.message}');
      return Result.fail(Failure(code: 'server', message: msg, statusCode: status));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  // ============================================================
  // rest of your code remains SAME below
  // ============================================================

  @override
  Future<Result<LoginResponse>> login(LoginRequest req) async {
    final uri = Uri.parse(ApiConfig.login);

    try {
      final res = await http
          .post(uri, headers: _jsonHeaders(), body: jsonEncode(req.toJson()))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final resp = LoginResponse.fromJson(parsed);

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

  @override
  Future<Result<UserProfile>> fetchProfile({String? token}) async {
    final tok = token ?? await getSavedToken();
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

  @override
  Future<Result<TyreUploadResponse>> uploadTwoWheeler(TyreUploadRequest req) async {
    final uri = Uri.parse(_twoWheelerUrl);
    final request = http.MultipartRequest('POST', uri);

    final masked = req.token.length > 9
        ? '${req.token.substring(0, 4)}…${req.token.substring(req.token.length - 4)}'
        : '***';

    request.headers.addAll({
      HttpHeaders.authorizationHeader: 'Bearer ${req.token}',
      HttpHeaders.acceptHeader: 'application/json',
    });

    request.fields.addAll({
      'user_id': req.userId,
      'vehicle_type': req.vehicleType,
      'vehicle_id': req.vehicleId,
      if (req.vin != null && req.vin!.trim().isNotEmpty) 'vin': req.vin!.trim(),
    });

    Future<http.MultipartFile> _file(String field, String path) async {
      final mime = lookupMimeType(path) ?? 'image/jpeg';
      final media = MediaType.parse(mime);
      return http.MultipartFile.fromPath(field, path, contentType: media);
    }

    request.files.addAll([
      await _file('front', req.frontPath),
      await _file('back', req.backPath),
    ]);

    try {
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

      return Result.fail(_serverFail(res));
    } on SocketException {
      return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
    } on TimeoutException {
      return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
    } catch (e) {
      return Result.fail(Failure(code: 'unknown', message: e.toString()));
    }
  }

  @override
Future<Result<List<TyreRecord>>> fetchUserRecords({
  required String userId,
  required String vehicleType,
  String vehicleId = "ALL",
}) async {
  try {
    final uri = Uri.parse(ApiConfig.fetchUserRecord).replace(queryParameters: {
      "vehicle_type": vehicleType.trim(),
      "user_id": userId.trim(),
      "vehicle_id": vehicleId.trim().isEmpty ? "ALL" : vehicleId.trim(),
    });

    final res = await http.get(uri).timeout(timeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final parsed = jsonDecode(res.body);
      if (parsed is! Map<String, dynamic>) {
        return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
      }

      final data = parsed['data'];
      if (data is! List) {
        return Result.fail(const Failure(code: 'parse', message: 'Missing data list'));
      }

      final list = data
          .whereType<Map>()
          .map((e) => TyreRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // sort latest first
      list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return Result.ok(list);
    }

    return Result.fail(Failure(
      code: 'server',
      message: 'Server error (${res.statusCode})',
      statusCode: res.statusCode,
    ));
  } on SocketException {
    return Result.fail(const Failure(code: 'network', message: 'No internet connection'));
  } on TimeoutException {
    return Result.fail(const Failure(code: 'timeout', message: 'Request timed out'));
  } catch (e) {
    return Result.fail(Failure(code: 'unknown', message: e.toString()));
  }
}

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

    if (tok == null || tok.isEmpty) {
      return Result.fail(const Failure(
        code: 'validation',
        message: 'No token available. Please login again.',
      ));
    }

    final uri = Uri.parse(ApiConfig.vehiclePreferences);

    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $tok',
    };

    final bodyArray = [
      {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "isOwn": isOwn,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
      }
    ];

    final bodyJson = jsonEncode(bodyArray);

    try {
      final res = await http
          .post(uri, headers: headers, body: bodyJson)
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return Result.fail(const Failure(code: 'parse', message: 'Invalid response format'));
        }
        final model = VehiclePreferencesModel.fromJson(parsed);
        return Result.ok(model);
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
}

class ApiConfig {
  static const login = 'http://54.162.208.215/backend/api/login';
  static const signup = 'http://54.162.208.215/backend/api/signup';
  static const String vehiclePreferences =
      'http://54.162.208.215/backend/api/addVehiclePreference';
  static const String fourWheelerUrl =
      'http://54.162.208.215/app/tyre/four_wheeler_upload/';
        static const String fetchUserRecord =
      'http://54.162.208.215/app/tyre/fetch_user_record/';
}

