import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/shop_vendor.dart';
import 'package:ios_tiretest_ai/models/four_wheeler_uploads_request.dart';
import 'package:ios_tiretest_ai/models/notification_models.dart';
import 'package:ios_tiretest_ai/models/reset_password_request.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/Repository/repository.dart';
import 'package:ios_tiretest_ai/models/update_user_details_model.dart' show UpdateUserDetailsRequest;
import 'package:ios_tiretest_ai/models/user_profile.dart';
import 'package:ios_tiretest_ai/models/verify_email_models.dart';
import 'package:ios_tiretest_ai/models/verify_otp_model.dart';
import '../models/auth_models.dart';
import 'package:bloc/bloc.dart';
import 'dart:async';



class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repo) : super(const AuthState()) {
    // ✅ OTP
    on<OtpIssuedNow>(_onOtpIssuedNow);
    on<VerifyOtpRequested>(_onVerifyOtp);

    // ✅ Forgot Password
    on<ForgotPasswordVerifyEmailRequested>(_onForgotVerifyEmail);
    on<ForgotPasswordResetRequested>(_onForgotResetPassword);
    on<ForgotPasswordClearRequested>(_onClearForgot);

    // ✅ Notifications
    on<NotificationFetchRequested>(_onNotificationFetch);
    on<NotificationStartListening>(_onNotificationStart);
    on<NotificationStopListening>(_onNotificationStop);
    on<NotificationMarkAllRead>(_onNotificationMarkAllRead);
    on<NotificationMarkSeenByIds>(_onNotificationMarkSeenByIds);

    // ✅ App/Auth
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<ClearAuthError>((e, emit) => emit(state.copyWith(error: null)));

    // ✅ Uploads
    on<UploadTwoWheelerRequested>(_onTwoWheelerUpload);
    on<UploadFourWheelerRequested>(_onFourWheelerUpload);

    // ✅ Profile
    on<FetchProfileRequested>(_onFetchProfile);
    on<FetchTyreHistoryRequested>(_onFetchTyreHistory);
    on<FetchNearbyShopsRequested>(_onFetchNearbyShops);

    // ✅ Vehicle Pref
    on<AddVehiclePreferenccesEvent>(addVehiclePreferences);

    // ✅ Update profile
    on<UpdateUserDetailsRequested>(_onUpdateUserDetails);
    on<ClearUpdateProfileError>(
      (e, emit) => emit(state.copyWith(updateProfileError: null)),
    );

    // ✅ Change password (existing flow using resetPassword)
    on<ChangePasswordRequested>(_onChangePassword);
    on<ClearChangePasswordError>(
      (e, emit) => emit(state.copyWith(changePasswordError: null)),
    );
  }

  final AuthRepository repo;

  // =========================
  // Notifications local store
  // =========================
  static const _kNotifReadIds = "notif_read_ids"; // List<String>

  Timer? _notifTimer;

  Set<String> _readIds() {
    final box = GetStorage();
    final raw = box.read(_kNotifReadIds);
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    return <String>{};
  }

  Future<void> _writeReadIds(Set<String> ids) async {
    final box = GetStorage();
    await box.write(_kNotifReadIds, ids.toList());
  }

  int _computeUnread(List<NotificationItem> list, Set<String> readIds) {
    return list.where((n) => !readIds.contains(n.id)).length;
  }

  // ============================================================
  // ✅ Forgot Password - Step 1: Verify Email -> returns userId
  // ============================================================
  Future<void> _onForgotVerifyEmail(
    ForgotPasswordVerifyEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();

    if (email.isEmpty) {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.failure,
        forgotEmailError: "Email is required",
        verifyEmailResponse: null,
      ));
      return;
    }

    emit(state.copyWith(
      forgotEmailStatus: ForgotEmailStatus.loading,
      forgotEmailError: null,
      verifyEmailResponse: null,
    ));

    // ✅ Your repository signature: verifyEmail({required email})
    final result = await repo.verifyEmail(email: email);

    if (result.isSuccess) {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.success,
        verifyEmailResponse: result.data,
        forgotEmailError: null,
      ));
    } else {
      emit(state.copyWith(
        forgotEmailStatus: ForgotEmailStatus.failure,
        forgotEmailError: result.failure?.message ?? "Email verification failed",
        verifyEmailResponse: null,
      ));
    }
  }

  // ============================================================
  // ✅ Forgot Password - Step 2: Reset Password with userId
  // ============================================================
  Future<void> _onForgotResetPassword(
    ForgotPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    final userId = event.userId.trim();
    final p1 = event.newPassword.trim();
    final p2 = event.confirmPassword.trim();

    if (userId.isEmpty) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "UserId missing. Please verify email again.",
        forgotResetResponse: null,
      ));
      return;
    }

    if (p1.isEmpty || p2.isEmpty) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "Password fields are required",
        forgotResetResponse: null,
      ));
      return;
    }

    if (p1 != p2) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: "Passwords do not match",
        forgotResetResponse: null,
      ));
      return;
    }

    emit(state.copyWith(
      forgotResetStatus: ForgotResetStatus.loading,
      forgotResetError: null,
      forgotResetResponse: null,
    ));

    final result = await repo.resetPassword(
      request: ResetPasswordRequest(
        userId: userId,
        newPassword: p1,
        confirmNewPassword: p2,
      ),
    );

    if (result.isSuccess) {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.success,
        forgotResetResponse: result.data,
        forgotResetError: null,
      ));
    } else {
      emit(state.copyWith(
        forgotResetStatus: ForgotResetStatus.failure,
        forgotResetError: result.failure?.message ?? "Reset password failed",
        forgotResetResponse: null,
      ));
    }
  }

  Future<void> _onClearForgot(
    ForgotPasswordClearRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      forgotEmailStatus: ForgotEmailStatus.initial,
      verifyEmailResponse: null,
      forgotEmailError: null,
      forgotResetStatus: ForgotResetStatus.initial,
      forgotResetResponse: null,
      forgotResetError: null,
    ));
  }

  // ============================================================
  // ✅ OTP Flow
  // ============================================================
  Future<void> _onOtpIssuedNow(OtpIssuedNow e, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      otpIssuedAt: DateTime.now(),
      verifyOtpStatus: VerifyOtpStatus.initial,
      verifyOtpError: null,
      verifyOtpResponse: null,
      otpExpirySeconds: 600,
    ));
  }

  Future<void> _onVerifyOtp(VerifyOtpRequested e, Emitter<AuthState> emit) async {
    if (state.verifyOtpStatus == VerifyOtpStatus.verifying) return;

    final issued = state.otpIssuedAt;
    if (issued != null) {
      final elapsed = DateTime.now().difference(issued).inSeconds;
      if (elapsed > state.otpExpirySeconds) {
        emit(state.copyWith(
          verifyOtpStatus: VerifyOtpStatus.failure,
          verifyOtpError: "OTP expired. Please resend OTP.",
        ));
        return;
      }
    }

    if (e.email.trim().isEmpty) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: "Email is required",
      ));
      return;
    }

    if (e.otp <= 0) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: "Invalid OTP",
      ));
      return;
    }

    emit(state.copyWith(
      verifyOtpStatus: VerifyOtpStatus.verifying,
      verifyOtpError: null,
      verifyOtpResponse: null,
    ));

    final r = await repo.verifyOtp(
      request: VerifyOtpRequest(email: e.email.trim(), otp: e.otp),
      token: e.token,
    );

    if (r.isSuccess) {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.success,
        verifyOtpResponse: r.data,
        verifyOtpError: null,
      ));

      add(const FetchProfileRequested());
    } else {
      emit(state.copyWith(
        verifyOtpStatus: VerifyOtpStatus.failure,
        verifyOtpError: r.failure?.message ?? "OTP verification failed",
      ));
    }
  }

  // ============================================================
  // ✅ App Started
  // ============================================================
  Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
    final tok = await repo.getSavedToken();

    if (tok != null && tok.isNotEmpty) {
      add(const FetchProfileRequested());

      add(const FetchNearbyShopsRequested(
        latitude: 24.91767709433974,
        longitude: 67.1005464655281,
      ));

      add(const NotificationStartListening(intervalSeconds: 15));
    }
  }

  // ============================================================
  // ✅ Notifications
  // ============================================================
  Future<void> _onNotificationFetch(
    NotificationFetchRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (!e.silent) {
      emit(state.copyWith(notificationError: null));
    }

    final r = await repo.fetchNotifications(page: e.page, limit: e.limit);

    if (!r.isSuccess) {
      if (!e.silent) {
        emit(state.copyWith(
          notificationError:
              r.failure?.message ?? "Failed to load notifications",
        ));
      }
      return;
    }

    final list = r.data ?? const <NotificationItem>[];
    final readIds = _readIds();
    final unread = _computeUnread(list, readIds);

    emit(state.copyWith(
      notifications: list,
      notificationUnreadCount: unread,
      notificationError: null,
    ));
  }

  Future<void> _onNotificationStart(
    NotificationStartListening e,
    Emitter<AuthState> emit,
  ) async {
    _notifTimer?.cancel();

    emit(state.copyWith(notificationListening: true));

    add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));

    _notifTimer = Timer.periodic(Duration(seconds: e.intervalSeconds), (_) {
      add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));
    });
  }

  Future<void> _onNotificationStop(
    NotificationStopListening e,
    Emitter<AuthState> emit,
  ) async {
    _notifTimer?.cancel();
    _notifTimer = null;
    emit(state.copyWith(notificationListening: false));
  }

  Future<void> _onNotificationMarkAllRead(
    NotificationMarkAllRead e,
    Emitter<AuthState> emit,
  ) async {
    final current = state.notifications;
    if (current.isEmpty) {
      emit(state.copyWith(notificationUnreadCount: 0));
      return;
    }

    final ids = current.map((n) => n.id).where((id) => id.isNotEmpty).toSet();
    final readIds = _readIds()..addAll(ids);
    await _writeReadIds(readIds);

    emit(state.copyWith(notificationUnreadCount: 0));
  }

  Future<void> _onNotificationMarkSeenByIds(
    NotificationMarkSeenByIds e,
    Emitter<AuthState> emit,
  ) async {
    if (e.ids.isEmpty) return;

    final readIds = _readIds()..addAll(e.ids.where((x) => x.trim().isNotEmpty));
    await _writeReadIds(readIds);

    final unread = _computeUnread(state.notifications, readIds);
    emit(state.copyWith(notificationUnreadCount: unread));
  }

  // ============================================================
  // ✅ Shops
  // ============================================================
  Future<void> _onFetchNearbyShops(
    FetchNearbyShopsRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      shopsStatus: ShopsStatus.loading,
      shopsError: null,
    ));

    final r = await repo.fetchNearbyShops(
      latitude: e.latitude,
      longitude: e.longitude,
    );

    if (r.isSuccess) {
      emit(state.copyWith(
        shopsStatus: ShopsStatus.success,
        shops: r.data ?? <ShopVendorModel>[],
        shopsError: null,
      ));
    } else {
      emit(state.copyWith(
        shopsStatus: ShopsStatus.failure,
        shopsError: r.failure?.message ?? 'Failed to load shops',
      ));
    }
  }

  // ============================================================
  // ✅ Login/Signup
  // ============================================================
  Future<void> _onLogin(LoginRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(loginStatus: AuthStatus.loading, error: null));
    final r =
        await repo.login(LoginRequest(email: e.email, password: e.password));

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

  // ============================================================
  // ✅ Upload Two Wheeler
  // ============================================================
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

    if (state.profile?.userId == null) {
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: 'User profile not loaded. Please login again.',
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
      final msg = r.failure?.message ??
          'Upload failed${sc != null ? ' ($sc)' : ''}';
      emit(state.copyWith(
        twoWheelerStatus: TwoWheelerStatus.failure,
        error: msg,
      ));
    }
  }

  // ============================================================
  // ✅ Upload Four Wheeler
  // ============================================================
  Future<void> _onFourWheelerUpload(
    UploadFourWheelerRequested e,
    Emitter<AuthState> emit,
  ) async {
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (state.fourWheelerStatus == FourWheelerStatus.uploading) return;

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

    if (!File(e.frontLeftPath).existsSync() ||
        !File(e.frontRightPath).existsSync() ||
        !File(e.backLeftPath).existsSync() ||
        !File(e.backRightPath).existsSync()) {
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: 'One or more images not found.',
      ));
      return;
    }

    emit(state.copyWith(
      fourWheelerStatus: FourWheelerStatus.uploading,
      fourWheelerError: null,
      fourWheelerResponse: null,
    ));

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
      final msg =
          r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
      emit(state.copyWith(
        fourWheelerStatus: FourWheelerStatus.failure,
        fourWheelerError: msg,
      ));
    }
  }

  // ============================================================
  // ✅ Profile Fetch
  // ============================================================
  Future<void> _onFetchProfile(
    FetchProfileRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(profileStatus: ProfileStatus.loading, error: null));

    final r = await repo.fetchProfile(token: e.token);

    if (r.isSuccess) {
      final profile = r.data;

      emit(state.copyWith(
        profileStatus: ProfileStatus.success,
        profile: profile,
        error: null,
      ));

      if (state.tyreHistoryStatus == TyreHistoryStatus.initial &&
          profile?.userId != null) {
        add(
          FetchTyreHistoryRequested(
            userId: profile!.userId.toString(),
            vehicleId: "ALL",
          ),
        );
      }
    } else {
      emit(state.copyWith(
        profileStatus: ProfileStatus.failure,
        error: r.failure?.message ?? 'Failed to fetch profile',
      ));
    }
  }

  // ============================================================
  // ✅ Add Vehicle Preferences
  // ============================================================
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

  // ============================================================
  // ✅ Tyre History (car + bike)
  // ============================================================
  Future<void> _onFetchTyreHistory(
    FetchTyreHistoryRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      tyreHistoryStatus: TyreHistoryStatus.loading,
      tyreHistoryError: null,
    ));

    try {
      final results = await Future.wait([
        repo.fetchUserRecords(
          userId: e.userId,
          vehicleType: "car",
          vehicleId: e.vehicleId,
        ),
        repo.fetchUserRecords(
          userId: e.userId,
          vehicleType: "bike",
          vehicleId: e.vehicleId,
        ),
      ]);

      final carRes = results[0];
      final bikeRes = results[1];

      if (!carRes.isSuccess && !bikeRes.isSuccess) {
        emit(state.copyWith(
          tyreHistoryStatus: TyreHistoryStatus.failure,
          tyreHistoryError: carRes.failure?.message ??
              bikeRes.failure?.message ??
              "Failed to load history",
        ));
        return;
      }

      final updated = Map<String, List<TyreRecord>>.from(state.tyreRecordsByType);

      if (carRes.isSuccess) updated['car'] = carRes.data ?? const <TyreRecord>[];
      if (bikeRes.isSuccess) updated['bike'] = bikeRes.data ?? const <TyreRecord>[];

      emit(state.copyWith(
        tyreHistoryStatus: TyreHistoryStatus.success,
        tyreHistoryError: null,
        tyreRecordsByType: updated,
      ));
    } catch (ex) {
      emit(state.copyWith(
        tyreHistoryStatus: TyreHistoryStatus.failure,
        tyreHistoryError: ex.toString(),
      ));
    }
  }

  // ============================================================
  // ✅ Update Profile
  // ============================================================
  Future<void> _onUpdateUserDetails(
    UpdateUserDetailsRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (state.updateProfileStatus == UpdateProfileStatus.loading) return;

    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    if (token.isEmpty) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: 'Missing auth token. Please login again.',
      ));
      return;
    }

    if (e.firstName.trim().isEmpty || e.lastName.trim().isEmpty) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: 'First name and last name are required.',
      ));
      return;
    }

    emit(state.copyWith(
      updateProfileStatus: UpdateProfileStatus.loading,
      updateProfileError: null,
      updateProfileResponse: null,
    ));

    try {
      final r = await repo.updateUserDetails(
        token: token,
        request: UpdateUserDetailsRequest(
          firstName: e.firstName.trim(),
          lastName: e.lastName.trim(),
          profileImage: e.profileImage.trim(),
          phone: e.phone.trim(),
        ),
      );

      final p = state.profile;
      UserProfile? updatedProfile = p;
      if (p != null) {
        updatedProfile = p.copyWith(
          firstName: e.firstName.trim(),
          lastName: e.lastName.trim(),
          phone: e.phone.trim(),
          profileImage: e.profileImage.trim(),
        );
      }

      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.success,
        updateProfileResponse: r,
        updateProfileError: null,
        profile: updatedProfile ?? state.profile,
      ));

      add(const FetchProfileRequested());
    } catch (ex) {
      emit(state.copyWith(
        updateProfileStatus: UpdateProfileStatus.failure,
        updateProfileError: ex.toString(),
      ));
    }
  }

  // ============================================================
  // ✅ Change Password (existing user profile flow)
  // ============================================================
  Future<void> _onChangePassword(
    ChangePasswordRequested e,
    Emitter<AuthState> emit,
  ) async {
    if (state.changePasswordStatus == ChangePasswordStatus.loading) return;

    final userId = state.profile?.userId?.toString() ?? '';
    if (userId.trim().isEmpty) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'User profile not loaded. Please login again.',
      ));
      return;
    }

    if (e.newPassword.trim().isEmpty || e.confirmNewPassword.trim().isEmpty) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'Password fields are required.',
      ));
      return;
    }

    if (e.newPassword.trim() != e.confirmNewPassword.trim()) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: 'New passwords do not match.',
      ));
      return;
    }

    emit(state.copyWith(
      changePasswordStatus: ChangePasswordStatus.loading,
      changePasswordError: null,
      changePasswordResponse: null,
    ));

    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();

    final r = await repo.resetPassword(
      request: ResetPasswordRequest(
        userId: userId.trim(),
        newPassword: e.newPassword.trim(),
        confirmNewPassword: e.confirmNewPassword.trim(),
      ),
      token: token.isEmpty ? null : token,
    );

    if (r.isSuccess) {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.success,
        changePasswordResponse: r.data,
        changePasswordError: null,
      ));
    } else {
      emit(state.copyWith(
        changePasswordStatus: ChangePasswordStatus.failure,
        changePasswordError: r.failure?.message ?? 'Failed to change password',
      ));
    }
  }

  // ============================================================
  // ✅ Close
  // ============================================================
  @override
  Future<void> close() {
    _notifTimer?.cancel();
    _notifTimer = null;
    return super.close();
  }
}


// Timer? _notificationTimer;
// class AuthBloc extends Bloc<AuthEvent, AuthState> {
//   final AuthRepository repo;
//   Timer? _notifTimer;

// static const _kNotifReadIds = "notif_read_ids"; // List<String>
// static const _kNotifSeenIds = "notif_seen_ids"; // optional: "opened"
// Set<String> _readIds() {
//   final box = GetStorage();
//   final raw = box.read(_kNotifReadIds);
//   if (raw is List) {
//     return raw.map((e) => e.toString()).toSet();
//   }
//   return <String>{};
// }

// Future<void> _writeReadIds(Set<String> ids) async {
//   final box = GetStorage();
//   await box.write(_kNotifReadIds, ids.toList());
// }

// int _computeUnread(List<NotificationItem> list, Set<String> readIds) {
//   return list.where((n) => !readIds.contains(n.id)).length;
// }

//   AuthBloc(this.repo) : super(const AuthState()) {
// on<VerifyOtpRequested>(_onVerifyOtp);
// on<OtpIssuedNow>(_onOtpIssuedNow);
//    on<ForgotPasswordVerifyEmailRequested>(_onVerifyEmail);
//     on<ForgotPasswordResetRequested>(_onResetPassword);
//     on<ForgotPasswordClearRequested>(_onClearForgot);

//     on<NotificationFetchRequested>(_onNotificationFetch);
//     on<NotificationStartListening>(_onNotificationStart);
//     on<NotificationStopListening>(_onNotificationStop);
//     on<NotificationMarkAllRead>(_onNotificationMarkAllRead);
//     on<NotificationMarkSeenByIds>(_onNotificationMarkSeenByIds);
//     on<AppStarted>(_onAppStarted);
//     on<LoginRequested>(_onLogin);
//     on<SignupRequested>(_onSignup);
//     on<UploadTwoWheelerRequested>(_onTwoWheelerUpload);
//     on<UploadFourWheelerRequested>(_onFourWheelerUpload);
//     on<FetchProfileRequested>(_onFetchProfile);
//     on<ClearAuthError>((e, emit) => emit(state.copyWith(error: null)));
//     on<AddVehiclePreferenccesEvent>(addVehiclePreferences);
//     on<FetchTyreHistoryRequested>(_onFetchTyreHistory);
//     on<FetchNearbyShopsRequested>(_onFetchNearbyShops);
//     on<UpdateUserDetailsRequested>(_onUpdateUserDetails);
//     on<ClearUpdateProfileError>(
//       (e, emit) => emit(state.copyWith(updateProfileError: null)),
//     );
//     on<ChangePasswordRequested>(_onChangePassword);
//     on<ClearChangePasswordError>((e, emit) => emit(state.copyWith(changePasswordError: null)));
//   }


  


//   Future<void> _onForgotVerifyEmail(
//     ForgotPasswordVerifyEmailRequested event,
//     Emitter<AuthState> emit,
//   ) async {
//     final email = event.email.trim();

//     if (email.isEmpty) {
//       emit(state.copyWith(
//         forgotEmailStatus: ForgotEmailStatus.failure,
//         forgotEmailError: "Email is required",
//         verifyEmailResponse: null,
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       forgotEmailStatus: ForgotEmailStatus.loading,
//       forgotEmailError: null,
//       verifyEmailResponse: null,
//     ));

//     final result = await repo.verifyEmail(
//       request: VerifyEmailRequest(email: email),
//     );

//     if (result.isSuccess) {
//       emit(state.copyWith(
//         forgotEmailStatus: ForgotEmailStatus.success,
//         verifyEmailResponse: result.data,
//         forgotEmailError: null,
//       ));
//     } else {
//       emit(state.copyWith(
//         forgotEmailStatus: ForgotEmailStatus.failure,
//         forgotEmailError: result.failure?.message ?? "Email verification failed",
//         verifyEmailResponse: null,
//       ));
//     }
//   }

//   // ============================================================
//   // ✅ Forgot Password - Step 2: Reset Password with userId
//   // ============================================================
//   Future<void> _onForgotResetPassword(
//     ForgotPasswordResetRequested event,
//     Emitter<AuthState> emit,
//   ) async {
//     final userId = event.userId.trim();
//     final p1 = event.newPassword.trim();
//     final p2 = event.confirmPassword.trim();

//     if (userId.isEmpty) {
//       emit(state.copyWith(
//         forgotResetStatus: ForgotResetStatus.failure,
//         forgotResetError: "UserId missing. Please verify email again.",
//         forgotResetResponse: null,
//       ));
//       return;
//     }

//     if (p1.isEmpty || p2.isEmpty) {
//       emit(state.copyWith(
//         forgotResetStatus: ForgotResetStatus.failure,
//         forgotResetError: "Password fields are required",
//         forgotResetResponse: null,
//       ));
//       return;
//     }

//     if (p1 != p2) {
//       emit(state.copyWith(
//         forgotResetStatus: ForgotResetStatus.failure,
//         forgotResetError: "Passwords do not match",
//         forgotResetResponse: null,
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       forgotResetStatus: ForgotResetStatus.loading,
//       forgotResetError: null,
//       forgotResetResponse: null,
//     ));

//     final result = await _repo.resetPassword(
//       request: ResetPasswordRequest(
//         userId: userId,
//         newPassword: p1,
//         confirmNewPassword: p2,
//       ),
//     );

//     if (result.isSuccess) {
//       emit(state.copyWith(
//         forgotResetStatus: ForgotResetStatus.success,
//         forgotResetResponse: result.data,
//         forgotResetError: null,
//       ));
//     } else {
//       emit(state.copyWith(
//         forgotResetStatus: ForgotResetStatus.failure,
//         forgotResetError: result.failure?.message ?? "Reset password failed",
//         forgotResetResponse: null,
//       ));
//     }
//   }

//   Future<void> _onOtpIssuedNow(OtpIssuedNow e, Emitter<AuthState> emit) async {
//   emit(state.copyWith(
//     otpIssuedAt: DateTime.now(),
//     verifyOtpStatus: VerifyOtpStatus.initial,
//     verifyOtpError: null,
//     verifyOtpResponse: null,
//     otpExpirySeconds: 600, // 10 min
//   ));
// }

// Future<void> _onVerifyOtp(VerifyOtpRequested e, Emitter<AuthState> emit) async {
//   if (state.verifyOtpStatus == VerifyOtpStatus.verifying) return;

//   // ✅ 10 minutes expiry check
//   final issued = state.otpIssuedAt;
//   if (issued != null) {
//     final elapsed = DateTime.now().difference(issued).inSeconds;
//     if (elapsed > (state.otpExpirySeconds)) {
//       emit(state.copyWith(
//         verifyOtpStatus: VerifyOtpStatus.failure,
//         verifyOtpError: "OTP expired. Please resend OTP.",
//       ));
//       return;
//     }
//   }

//   if (e.email.trim().isEmpty) {
//     emit(state.copyWith(
//       verifyOtpStatus: VerifyOtpStatus.failure,
//       verifyOtpError: "Email is required",
//     ));
//     return;
//   }

//   if (e.otp <= 0) {
//     emit(state.copyWith(
//       verifyOtpStatus: VerifyOtpStatus.failure,
//       verifyOtpError: "Invalid OTP",
//     ));
//     return;
//   }

//   emit(state.copyWith(
//     verifyOtpStatus: VerifyOtpStatus.verifying,
//     verifyOtpError: null,
//     verifyOtpResponse: null,
//   ));

//   final r = await repo.verifyOtp(
//     request: VerifyOtpRequest(email: e.email.trim(), otp: e.otp),
//     token: e.token, // optional
//   );

//   if (r.isSuccess) {
//     emit(state.copyWith(
//       verifyOtpStatus: VerifyOtpStatus.success,
//       verifyOtpResponse: r.data,
//       verifyOtpError: null,
//     ));

//     // ✅ after verify success, load profile (optional)
//     add(const FetchProfileRequested());
//   } else {
//     emit(state.copyWith(
//       verifyOtpStatus: VerifyOtpStatus.failure,
//       verifyOtpError: r.failure?.message ?? "OTP verification failed",
//     ));
//   }
// }


//     Future<void> _onAppStarted(AppStarted e, Emitter<AuthState> emit) async {
//     final tok = await repo.getSavedToken();

//     if (tok != null && tok.isNotEmpty) {
//       add(const FetchProfileRequested());

//       add(const FetchNearbyShopsRequested(
//         latitude: 24.91767709433974,
//         longitude: 67.1005464655281,
//       ));

//       add(const NotificationStartListening(intervalSeconds: 15));
//     }
//   }


// Future<void> _onNotificationFetch(
//   NotificationFetchRequested e,
//   Emitter<AuthState> emit,
// ) async {
//   if (!e.silent) {
//     emit(state.copyWith(notificationError: null));
//   }

//   final r = await repo.fetchNotifications(page: e.page, limit: e.limit);

//   if (!r.isSuccess) {
//     if (!e.silent) {
//       emit(state.copyWith(
//         notificationError: r.failure?.message ?? "Failed to load notifications",
//       ));
//     }
//     return;
//   }

//   final list = r.data ?? const <NotificationItem>[];

//   final readIds = _readIds();
//   final unread = _computeUnread(list, readIds);

//   emit(state.copyWith(
//     notifications: list,
//     notificationUnreadCount: unread,
//     notificationError: null,
//   ));
// }

// Future<void> _onNotificationStart(
//   NotificationStartListening e,
//   Emitter<AuthState> emit,
// ) async {
//   _notifTimer?.cancel();

//   emit(state.copyWith(notificationListening: true));

//   add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));

//   _notifTimer = Timer.periodic(Duration(seconds: e.intervalSeconds), (_) {
//     add(const NotificationFetchRequested(page: 1, limit: 50, silent: true));
//   });
// }

// Future<void> _onNotificationStop(
//   NotificationStopListening e,
//   Emitter<AuthState> emit,
// ) async {
//   _notifTimer?.cancel();
//   _notifTimer = null;
//   emit(state.copyWith(notificationListening: false));
// }

// Future<void> _onNotificationMarkAllRead(
//   NotificationMarkAllRead e,
//   Emitter<AuthState> emit,
// ) async {
//   final current = state.notifications;
//   if (current.isEmpty) {
//     emit(state.copyWith(notificationUnreadCount: 0));
//     return;
//   }

//   final ids = current.map((n) => n.id).where((id) => id.isNotEmpty).toSet();
//   final readIds = _readIds()..addAll(ids);
//   await _writeReadIds(readIds);

//   emit(state.copyWith(notificationUnreadCount: 0));
// }

// Future<void> _onNotificationMarkSeenByIds(
//   NotificationMarkSeenByIds e,
//   Emitter<AuthState> emit,
// ) async {
//   if (e.ids.isEmpty) return;

//   final readIds = _readIds()..addAll(e.ids.where((x) => x.trim().isNotEmpty));
//   await _writeReadIds(readIds);

//   final unread = _computeUnread(state.notifications, readIds);

//   emit(state.copyWith(notificationUnreadCount: unread));
// }


//   @override
//   Future<void> close() {
//     _notificationTimer?.cancel();
//     return super.close();
//   }


//   Future<void> _onFetchNearbyShops(
//     FetchNearbyShopsRequested e,
//     Emitter<AuthState> emit,
//   ) async {
//     emit(state.copyWith(
//       shopsStatus: ShopsStatus.loading,
//       shopsError: null,
//     ));

//     final r = await repo.fetchNearbyShops(
//       latitude: e.latitude,
//       longitude: e.longitude,
//     );

//     if (r.isSuccess) {
//       emit(state.copyWith(
//         shopsStatus: ShopsStatus.success,
//         shops: r.data ??  <ShopVendorModel>[],
//         shopsError: null,
//       ));
//     } else {
//       emit(state.copyWith(
//         shopsStatus: ShopsStatus.failure,
//         shopsError: r.failure?.message ?? 'Failed to load shops',
//       ));
//     }
//   }

//   Future<void> _onLogin(LoginRequested e, Emitter<AuthState> emit) async {
//     emit(state.copyWith(loginStatus: AuthStatus.loading, error: null));
//     final r =
//         await repo.login(LoginRequest(email: e.email, password: e.password));

//     if (r.isSuccess) {
//       emit(state.copyWith(
//         loginStatus: AuthStatus.success,
//         loginResponse: r.data,
//         error: null,
//       ));
//       add(const FetchProfileRequested());
//     } else {
//       emit(state.copyWith(
//         loginStatus: AuthStatus.failure,
//         error: r.failure?.message ?? 'Login failed',
//       ));
//     }
//   }

//   Future<void> _onSignup(SignupRequested e, Emitter<AuthState> emit) async {
//     emit(state.copyWith(signupStatus: AuthStatus.loading, error: null));
//     final r = await repo.signup(SignupRequest(
//       firstName: e.firstName,
//       lastName: e.lastName,
//       email: e.email,
//       password: e.password,
//     ));
  

//     if (r.isSuccess) {

//       emit(state.copyWith(
//         signupStatus: AuthStatus.success,
//         signupResponse: r.data,
//         error: null,
//       ));
   
//     } else {
//       emit(state.copyWith(
//         signupStatus: AuthStatus.failure,
//         error: r.failure?.message ?? 'Signup failed',
//       ));
//     }
//   }

//   Future<void> _onTwoWheelerUpload(
//     UploadTwoWheelerRequested e,
//     Emitter<AuthState> emit,
//   ) async {
//     final box = GetStorage();
//     final token = (box.read<String>('auth_token') ?? '').trim();

//     if (state.twoWheelerStatus == TwoWheelerStatus.uploading) return;

//     if (token.isEmpty) {
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.failure,
//         error: 'Missing auth token. Please log in again.',
//       ));
//       return;
//     }

//     if (e.vehicleId.trim().isEmpty) {
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.failure,
//         error: 'Missing vehicle_id.',
//       ));
//       return;
//     }
//     if (!File(e.frontPath).existsSync()) {
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.failure,
//         error: 'Front image not found: ${e.frontPath}',
//       ));
//       return;
//     }
//     if (!File(e.backPath).existsSync()) {
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.failure,
//         error: 'Back image not found: ${e.backPath}',
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       twoWheelerStatus: TwoWheelerStatus.uploading,
//       error: null,
//     ));

//     final req = TyreUploadRequest(
//       userId: state.profile!.userId.toString(),
//       vehicleType: 'bike',
//       vehicleId: e.vehicleId,
//       frontPath: e.frontPath,
//       backPath: e.backPath,
//       token: token,
//       vin: e.vin,
//     );

//     final r = await repo.uploadTwoWheeler(req);

//     if (r.isSuccess) {
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.success,
//         twoWheelerResponse: r.data,
//         error: null,
//       ));
//     } else {
//       final sc = r.failure?.statusCode;
//       final msg = r.failure?.message ??
//           'Upload failed${sc != null ? ' ($sc)' : ''}';
//       emit(state.copyWith(
//         twoWheelerStatus: TwoWheelerStatus.failure,
//         error: msg,
//       ));
//     }
//   }

//  Future<void> _onFourWheelerUpload(
//   UploadFourWheelerRequested e,
//   Emitter<AuthState> emit,
// ) async {
//   final box = GetStorage();
//   final token = (box.read<String>('auth_token') ?? '').trim();

//   if (state.fourWheelerStatus == FourWheelerStatus.uploading) return;

//   if (token.isEmpty) {
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.failure,
//       fourWheelerError: 'Missing auth token. Please log in again.',
//     ));
//     return;
//   }

//   if (state.profile?.userId == null) {
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.failure,
//       fourWheelerError: 'User profile not loaded. Please login again.',
//     ));
//     return;
//   }

//   if (e.vehicleId.trim().isEmpty) {
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.failure,
//       fourWheelerError: 'Missing vehicle_id.',
//     ));
//     return;
//   }

//   if (!File(e.frontLeftPath).existsSync() ||
//       !File(e.frontRightPath).existsSync() ||
//       !File(e.backLeftPath).existsSync() ||
//       !File(e.backRightPath).existsSync()) {
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.failure,
//       fourWheelerError: 'One or more images not found.',
//     ));
//     return;
//   }

//   emit(state.copyWith(
//     fourWheelerStatus: FourWheelerStatus.uploading,
//     fourWheelerError: null,
//     fourWheelerResponse: null,
//   ));

//   final req = FourWheelerUploadRequest(
//     userId: state.profile!.userId.toString(),
//     token: token,
//     vehicleId: e.vehicleId,
//     vehicleType: e.vehicleType,
//     vin: e.vin,
//     frontLeftTyreId: e.frontLeftTyreId,
//     frontRightTyreId: e.frontRightTyreId,
//     backLeftTyreId: e.backLeftTyreId,
//     backRightTyreId: e.backRightTyreId,
//     frontLeftPath: e.frontLeftPath,
//     frontRightPath: e.frontRightPath,
//     backLeftPath: e.backLeftPath,
//     backRightPath: e.backRightPath,
//   );

//   final r = await repo.uploadFourWheeler(req);

//   if (r.isSuccess) {
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.success,
//       fourWheelerResponse: r.data,
//       fourWheelerError: null,
//     ));
//   } else {
//     final sc = r.failure?.statusCode;
//     final msg = r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
//     emit(state.copyWith(
//       fourWheelerStatus: FourWheelerStatus.failure,
//       fourWheelerError: msg,
//     ));
//   }
// }


//   Future<void> _onFetchProfile(
//     FetchProfileRequested e,
//     Emitter<AuthState> emit,
//   ) async {
//     emit(state.copyWith(profileStatus: ProfileStatus.loading, error: null));

//     final r = await repo.fetchProfile(token: e.token);

//     if (r.isSuccess) {
//       final profile = r.data;

//       emit(state.copyWith(
//         profileStatus: ProfileStatus.success,
//         profile: profile,
//         error: null,
//       ));

//       if (state.tyreHistoryStatus == TyreHistoryStatus.initial &&
//           profile?.userId != null) {
//         add(
//           FetchTyreHistoryRequested(
//             userId: profile!.userId.toString(),
//             vehicleId: "ALL",
//           ),
//         );
//       }
//     } else {
//       emit(state.copyWith(
//         profileStatus: ProfileStatus.failure,
//         error: r.failure?.message ?? 'Failed to fetch profile',
//       ));
//     }
//   }

//   Future<void> addVehiclePreferences(
//     AddVehiclePreferenccesEvent event,
//     Emitter<AuthState> emit,
//   ) async {
//     emit(state.copyWith(
//       addVehiclePreferencesStatus: AddVehiclePreferencesStatus.loading,
//       errorMessageVehiclePreferences: null,
//     ));

//     final result = await repo.addVehiclePreferences(
//       vehiclePreference: event.vehiclePreference,
//       brandName: event.brandName,
//       modelName: event.modelName,
//       licensePlate: event.licensePlate,
//       isOwn: event.isOwn,
//       tireBrand: event.tireBrand,
//       tireDimension: event.tireDimension,
//     );

//     if (!result.isSuccess) {
//       emit(state.copyWith(
//         addVehiclePreferencesStatus: AddVehiclePreferencesStatus.failure,
//         errorMessageVehiclePreferences:
//             result.failure?.message ?? 'Failed to save vehicle',
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       addVehiclePreferencesStatus: AddVehiclePreferencesStatus.success,
//       vehiclePreferencesModel: result.data,
//     ));
//   }

//   Future<void> _onFetchTyreHistory(
//     FetchTyreHistoryRequested e,
//     Emitter<AuthState> emit,
//   ) async {
//     emit(state.copyWith(
//       tyreHistoryStatus: TyreHistoryStatus.loading,
//       tyreHistoryError: null,
//     ));

//     try {
//       final results = await Future.wait([
//         repo.fetchUserRecords(
//             userId: e.userId, vehicleType: "car", vehicleId: e.vehicleId),
//         repo.fetchUserRecords(
//             userId: e.userId, vehicleType: "bike", vehicleId: e.vehicleId),
//       ]);

//       final carRes = results[0];
//       final bikeRes = results[1];

//       if (!carRes.isSuccess && !bikeRes.isSuccess) {
//         emit(state.copyWith(
//           tyreHistoryStatus: TyreHistoryStatus.failure,
//           tyreHistoryError: carRes.failure?.message ??
//               bikeRes.failure?.message ??
//               "Failed to load history",
//         ));
//         return;
//       }

//       final updated = Map<String, List<TyreRecord>>.from(state.tyreRecordsByType);

//       if (carRes.isSuccess) updated['car'] = carRes.data ?? const <TyreRecord>[];
//       if (bikeRes.isSuccess)
//         updated['bike'] = bikeRes.data ?? const <TyreRecord>[];

//       emit(state.copyWith(
//         tyreHistoryStatus: TyreHistoryStatus.success,
//         tyreHistoryError: null,
//         tyreRecordsByType: updated,
//       ));
//     } catch (ex) {
//       emit(state.copyWith(
//         tyreHistoryStatus: TyreHistoryStatus.failure,
//         tyreHistoryError: ex.toString(),
//       ));
//     }
//   }

//   /// ✅ NEW HANDLER: Update user details (Edit Profile)
//   Future<void> _onUpdateUserDetails(
//     UpdateUserDetailsRequested e,
//     Emitter<AuthState> emit,
//   ) async {
//     // prevent double tap
//     if (state.updateProfileStatus == UpdateProfileStatus.loading) return;

//     final box = GetStorage();
//     final token = (box.read<String>('auth_token') ?? '').trim();

//     if (token.isEmpty) {
//       emit(state.copyWith(
//         updateProfileStatus: UpdateProfileStatus.failure,
//         updateProfileError: 'Missing auth token. Please login again.',
//       ));
//       return;
//     }

//     // basic validations (optional)
//     if (e.firstName.trim().isEmpty || e.lastName.trim().isEmpty) {
//       emit(state.copyWith(
//         updateProfileStatus: UpdateProfileStatus.failure,
//         updateProfileError: 'First name and last name are required.',
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       updateProfileStatus: UpdateProfileStatus.loading,
//       updateProfileError: null,
//       updateProfileResponse: null,
//     ));

//     try {
//       final r = await repo.updateUserDetails(
//         token: token,
//         request: UpdateUserDetailsRequest(
//           firstName: e.firstName.trim(),
//           lastName: e.lastName.trim(),
//           profileImage: e.profileImage.trim(),
//           phone: e.phone.trim(),
//         ),
//       );

//       // optimistic update: update local profile object if you want
//       final p = state.profile;
//       UserProfile? updatedProfile = p;
//       if (p != null) {
//         updatedProfile = p.copyWith(
//           firstName: e.firstName.trim(),
//           lastName: e.lastName.trim(),
//           phone: e.phone.trim(),
//           profileImage: e.profileImage.trim(),
//         );
//       }

//       emit(state.copyWith(
//         updateProfileStatus: UpdateProfileStatus.success,
//         updateProfileResponse: r,
//         updateProfileError: null,
//         profile: updatedProfile ?? state.profile,
//       ));

//       // ✅ refresh profile from backend (recommended)
//       add(const FetchProfileRequested());
//     } catch (ex) {
//       emit(state.copyWith(
//         updateProfileStatus: UpdateProfileStatus.failure,
//         updateProfileError: ex.toString(),
//       ));
//     }
//   }
// Future<void> _onChangePassword(ChangePasswordRequested e, Emitter<AuthState> emit) async {
//     if (state.changePasswordStatus == ChangePasswordStatus.loading) return;

//     final userId = state.profile?.userId?.toString() ?? '';
//     if (userId.trim().isEmpty) {
//       emit(state.copyWith(
//         changePasswordStatus: ChangePasswordStatus.failure,
//         changePasswordError: 'User profile not loaded. Please login again.',
//       ));
//       return;
//     }

//     if (e.newPassword.trim().isEmpty || e.confirmNewPassword.trim().isEmpty) {
//       emit(state.copyWith(
//         changePasswordStatus: ChangePasswordStatus.failure,
//         changePasswordError: 'Password fields are required.',
//       ));
//       return;
//     }

//     if (e.newPassword.trim() != e.confirmNewPassword.trim()) {
//       emit(state.copyWith(
//         changePasswordStatus: ChangePasswordStatus.failure,
//         changePasswordError: 'New passwords do not match.',
//       ));
//       return;
//     }

//     emit(state.copyWith(
//       changePasswordStatus: ChangePasswordStatus.loading,
//       changePasswordError: null,
//       changePasswordResponse: null,
//     ));

//     final box = GetStorage();
//     final token = (box.read<String>('auth_token') ?? '').trim(); // optional

//     final r = await repo.resetPassword(
//       request: ResetPasswordRequest(
//         userId: userId.trim(),
//         newPassword: e.newPassword.trim(),
//         confirmNewPassword: e.confirmNewPassword.trim(),
//       ),
//       token: token.isEmpty ? null : token,
//     );

//     if (r.isSuccess) {
//       emit(state.copyWith(
//         changePasswordStatus: ChangePasswordStatus.success,
//         changePasswordResponse: r.data,
//         changePasswordError: null,
//       ));
//     } else {
//       emit(state.copyWith(
//         changePasswordStatus: ChangePasswordStatus.failure,
//         changePasswordError: r.failure?.message ?? 'Failed to change password',
//       ));
//     }
//   }
// }

