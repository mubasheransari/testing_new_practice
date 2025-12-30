import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/four_wheeler_uploads_request.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/Repository/repository.dart';
import '../Models/auth_models.dart';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:get_storage/get_storage.dart';

import 'auth_event.dart';
import 'auth_state.dart';

// keep your imports/models:
// AuthRepository, LoginRequest, SignupRequest, TyreUploadRequest, TyreUploadResponse, etc.

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repo;

  AuthBloc(this.repo) : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<UploadTwoWheelerRequested>(_onTwoWheelerUpload);

    /// ✅ NEW
    on<UploadFourWheelerRequested>(_onFourWheelerUpload);

    on<FetchProfileRequested>(_onFetchProfile);
    on<ClearAuthError>((e, emit) => emit(state.copyWith(error: null)));
    on<AddVehiclePreferenccesEvent>(addVehiclePreferences);
  }

  Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
    final tok = await repo.getSavedToken();
    if (tok != null && tok.isNotEmpty) {
      add(const FetchProfileRequested());
    }
  }

  Future<void> _onLogin(LoginRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(loginStatus: AuthStatus.loading, error: null));
    final r = await repo.login(LoginRequest(email: e.email, password: e.password));

    if (r.isSuccess) {
      emit(state.copyWith(
        loginStatus: AuthStatus.success,
        loginResponse: r.data,
        error: null,
      ));
      add(const FetchProfileRequested());
    } else {
      emit(state.copyWith(
        loginStatus: AuthStatus.failure,
        error: r.failure?.message ?? 'Login failed',
      ));
    }
  }

  Future<void> _onSignup(SignupRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(signupStatus: AuthStatus.loading, error: null));
    final r = await repo.signup(SignupRequest(
      firstName: e.firstName,
      lastName: e.lastName,
      email: e.email,
      password: e.password,
    ));

    if (r.isSuccess) {
      emit(state.copyWith(
        signupStatus: AuthStatus.success,
        signupResponse: r.data,
        error: null,
      ));
    } else {
      emit(state.copyWith(
        signupStatus: AuthStatus.failure,
        error: r.failure?.message ?? 'Signup failed',
      ));
    }
  }

  Future<void> _onTwoWheelerUpload(
    UploadTwoWheelerRequested e,
    Emitter<AuthState> emit,
  ) async {
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (state.twoWheelerStatus == TwoWheelerStatus.uploading) return;

    if (token.isEmpty) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: 'Missing auth token. Please log in again.',
      ));
      return;
    }

    if (e.vehicleId.trim().isEmpty) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: 'Missing vehicle_id.',
      ));
      return;
    }
    if (!File(e.frontPath).existsSync()) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: 'Front image not found: ${e.frontPath}',
      ));
      return;
    }
    if (!File(e.backPath).existsSync()) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: 'Back image not found: ${e.backPath}',
      ));
      return;
    }

    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.uploading,
      error: null,
    ));

    final req = TyreUploadRequest(
      userId: state.profile!.userId.toString(),
      vehicleType: 'bike',
      vehicleId: e.vehicleId,
      frontPath: e.frontPath,
      backPath: e.backPath,
      token: token,
      vin: e.vin,
    );

    final r = await repo.uploadTwoWheeler(req);

    if (r.isSuccess) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.success,
        twoWheelerResponse: r.data,
        error: null,
      ));
    } else {
      final sc = r.failure?.statusCode;
      final msg = r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: msg,
      ));
    }
  }

  /// ✅ NEW: Four-wheeler upload handler
  Future<void> _onFourWheelerUpload(
    UploadFourWheelerRequested e,
    Emitter<AuthState> emit,
  ) async {
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    // prevent double taps
    if (state.fourWheelerStatus == FourWheelerStatus.uploading) return;

    // validations
    if (token.isEmpty) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Missing auth token. Please log in again.',
      ));
      return;
    }

    if (state.profile?.userId == null) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'User profile not loaded. Please login again.',
      ));
      return;
    }

    if (e.vehicleId.trim().isEmpty) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Missing vehicle_id.',
      ));
      return;
    }

    // image files
    if (!File(e.frontLeftPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Front-left image not found: ${e.frontLeftPath}',
      ));
      return;
    }
    if (!File(e.frontRightPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Front-right image not found: ${e.frontRightPath}',
      ));
      return;
    }
    if (!File(e.backLeftPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Back-left image not found: ${e.backLeftPath}',
      ));
      return;
    }
    if (!File(e.backRightPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'Back-right image not found: ${e.backRightPath}',
      ));
      return;
    }

    emit(state.copyWith(
      fourWheelerStatus: FourWheelerStatus.uploading,
      fourWheelerError: null,
    ));

    // Build request (create your model or pass params directly)
    final req = FourWheelerUploadRequest(
      userId: state.profile!.userId.toString(),
      token: token,
      vehicleId: e.vehicleId,
      vehicleType: e.vehicleType,
      vin: e.vin,

      frontLeftTyreId: e.frontLeftTyreId,
      frontRightTyreId: e.frontRightTyreId,
      backLeftTyreId: e.backLeftTyreId,
      backRightTyreId: e.backRightTyreId,

      frontLeftPath: e.frontLeftPath,
      frontRightPath: e.frontRightPath,
      backLeftPath: e.backLeftPath,
      backRightPath: e.backRightPath,
    );

    final r = await repo.uploadFourWheeler(req);

    if (r.isSuccess) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.success,
        fourWheelerResponse: r.data,
        fourWheelerError: null,
      ));
    } else {
      final sc = r.failure?.statusCode;
      final msg = r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: msg,
      ));
    }
  }

  Future<void> _onFetchProfile(
    FetchProfileRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(profileStatus: ProfileStatus.loading, error: null));

    final r = await repo.fetchProfile(token: e.token);

    if (r.isSuccess) {
      emit(state.copyWith(
        profileStatus: ProfileStatus.success,
        profile: r.data,
        error: null,
      ));
    } else {
      emit(state.copyWith(
        profileStatus: ProfileStatus.failure,
        error: r.failure?.message ?? 'Failed to fetch profile',
      ));
    }
  }

  Future<void> addVehiclePreferences(
    AddVehiclePreferenccesEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      addVehiclePreferencesStatus: AddVehiclePreferencesStatus.loading,
      errorMessageVehiclePreferences: null,
    ));

    final result = await repo.addVehiclePreferences(
      vehiclePreference: event.vehiclePreference,
      brandName: event.brandName,
      modelName: event.modelName,
      licensePlate: event.licensePlate,
      isOwn: event.isOwn,
      tireBrand: event.tireBrand,
      tireDimension: event.tireDimension,
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        addVehiclePreferencesStatus: AddVehiclePreferencesStatus.failure,
        errorMessageVehiclePreferences:
            result.failure?.message ?? 'Failed to save vehicle',
      ));
      return;
    }

    emit(state.copyWith(
      addVehiclePreferencesStatus: AddVehiclePreferencesStatus.success,
      vehiclePreferencesModel: result.data,
    ));
  }
}
