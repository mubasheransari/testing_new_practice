import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/Models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/Models/auth_models.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart';
import 'package:ios_tiretest_ai/Models/user_profile.dart';

import 'package:equatable/equatable.dart';

// keep your imports/models:
/// LoginResponse, SignupResponse, VehiclePreferencesModel, TyreUploadResponse, UserProfile

enum AuthStatus { initial, loading, success, failure }
enum TwoWheelerStatus { initial, uploading, success, failure }

/// ✅ NEW status
enum FourWheelerStatus { initial, uploading, success, failure }

enum ProfileStatus { initial, loading, success, failure }
enum AddVehiclePreferencesStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;

  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;

  final VehiclePreferencesModel? vehiclePreferencesModel;

  final String? error;

  final String? errorMessageVehiclePreferences;

  final TwoWheelerStatus twoWheelerStatus;
  final TyreUploadResponse? twoWheelerResponse;

  /// ✅ NEW: 4-wheeler
  final FourWheelerStatus fourWheelerStatus;
  final TyreUploadResponse? fourWheelerResponse;
  final String? fourWheelerError;

  final ProfileStatus profileStatus;
  final UserProfile? profile;

  final AddVehiclePreferencesStatus addVehiclePreferencesStatus;

  const AuthState({
    this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.vehiclePreferencesModel,
    this.error,
    this.twoWheelerStatus = TwoWheelerStatus.initial,
    this.twoWheelerResponse,

    /// ✅ NEW defaults
    this.fourWheelerStatus = FourWheelerStatus.initial,
    this.fourWheelerResponse,
    this.fourWheelerError,

    this.profileStatus = ProfileStatus.initial,
    this.profile,
    this.errorMessageVehiclePreferences,
  });

  AuthState copyWith({
    AddVehiclePreferencesStatus? addVehiclePreferencesStatus,
    AuthStatus? loginStatus,
    AuthStatus? signupStatus,
    LoginResponse? loginResponse,
    SignupResponse? signupResponse,
    String? error,
    TwoWheelerStatus? twoWheelerStatus,
    TyreUploadResponse? twoWheelerResponse,
    ProfileStatus? profileStatus,
    UserProfile? profile,
    VehiclePreferencesModel? vehiclePreferencesModel,
    String? errorMessageVehiclePreferences,

    /// ✅ NEW
    FourWheelerStatus? fourWheelerStatus,
    TyreUploadResponse? fourWheelerResponse,
    String? fourWheelerError,
  }) {
    return AuthState(
      addVehiclePreferencesStatus:
          addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error,
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
      vehiclePreferencesModel:
          vehiclePreferencesModel ?? this.vehiclePreferencesModel,
      errorMessageVehiclePreferences:
          errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,

      /// ✅ NEW
      fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
      fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
      fourWheelerError: fourWheelerError,
    );
  }

  @override
  List<Object?> get props => [
        addVehiclePreferencesStatus,
        loginStatus,
        signupStatus,
        loginResponse,
        signupResponse,
        error,
        twoWheelerStatus,
        twoWheelerResponse,
        profileStatus,
        profile,
        vehiclePreferencesModel,
        errorMessageVehiclePreferences,

        /// ✅ NEW
        fourWheelerStatus,
        fourWheelerResponse,
        fourWheelerError,
      ];
}
