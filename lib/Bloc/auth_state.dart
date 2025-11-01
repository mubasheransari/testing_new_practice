import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/Models/auth_models.dart';

// auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_response.dart';

import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/Models/user_profile.dart';


enum AuthStatus { initial, loading, success, failure }
enum TwoWheelerStatus { initial, uploading, success, failure }

// NEW
enum ProfileStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  // login/signup
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;
  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;
  final String? error;

  // two-wheeler
  final TwoWheelerStatus twoWheelerStatus;
  final TyreUploadResponse? twoWheelerResponse;

  // NEW: profile
  final ProfileStatus profileStatus;
  final UserProfile? profile;

  const AuthState({
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.error,
    this.twoWheelerStatus = TwoWheelerStatus.initial,
    this.twoWheelerResponse,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
  });

  AuthState copyWith({
    AuthStatus? loginStatus,
    AuthStatus? signupStatus,
    LoginResponse? loginResponse,
    SignupResponse? signupResponse,
    String? error, // set null to clear
    TwoWheelerStatus? twoWheelerStatus,
    TyreUploadResponse? twoWheelerResponse,
    ProfileStatus? profileStatus,
    UserProfile? profile,
  }) {
    return AuthState(
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error,
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
    );
  }

  @override
  List<Object?> get props => [
        loginStatus,
        signupStatus,
        loginResponse,
        signupResponse,
        error,
        twoWheelerStatus,
        twoWheelerResponse,
        profileStatus,
        profile,
      ];
}

/*
/// Reused for login/signup flows
enum AuthStatus { initial, loading, success, failure }

/// Separate enum just for the two-wheeler upload flow
enum TwoWheelerStatus { initial, uploading, success, failure }

class AuthState extends Equatable {
  // ---------- Existing auth (login/signup) ----------
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;
  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;

  /// Generic error surface (set to null to clear)
  final String? error;

  // ---------- New: two-wheeler upload ----------
  final TwoWheelerStatus twoWheelerStatus;
  final TyreUploadResponse? twoWheelerResponse;

  const AuthState({
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.error,
    this.twoWheelerStatus = TwoWheelerStatus.initial,
    this.twoWheelerResponse,
  });

  /// Pass `null` for any field you want to clear (e.g., `error: null`).
  AuthState copyWith({
    AuthStatus? loginStatus,
    AuthStatus? signupStatus,
    LoginResponse? loginResponse,
    SignupResponse? signupResponse,
    String? error,
    TwoWheelerStatus? twoWheelerStatus,
    TyreUploadResponse? twoWheelerResponse,
  }) {
    return AuthState(
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error,
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
    );
  }

  @override
  List<Object?> get props => [
        loginStatus,
        signupStatus,
        loginResponse,
        signupResponse,
        error,
        twoWheelerStatus,
        twoWheelerResponse,
      ];
}
*/

// enum AuthStatus { initial, loading, success, failure }

// class AuthState extends Equatable {
//   final AuthStatus loginStatus;
//   final AuthStatus signupStatus;
//   final LoginResponse? loginResponse;
//   final SignupResponse? signupResponse;
//   final String? error;

//   const AuthState({
//     this.loginStatus = AuthStatus.initial,
//     this.signupStatus = AuthStatus.initial,
//     this.loginResponse,
//     this.signupResponse,
//     this.error,
//   });

//   AuthState copyWith({
//     AuthStatus? loginStatus,
//     AuthStatus? signupStatus,
//     LoginResponse? loginResponse,
//     SignupResponse? signupResponse,
//     String? error, // pass null to clear
//   }) {
//     return AuthState(
//       loginStatus: loginStatus ?? this.loginStatus,
//       signupStatus: signupStatus ?? this.signupStatus,
//       loginResponse: loginResponse ?? this.loginResponse,
//       signupResponse: signupResponse ?? this.signupResponse,
//       error: error,
//     );
//   }

//   @override
//   List<Object?> get props =>
//       [loginStatus, signupStatus, loginResponse, signupResponse, error];
// }

