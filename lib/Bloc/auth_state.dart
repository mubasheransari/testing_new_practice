import 'package:equatable/equatable.dart';
import 'package:ios_tiretest_ai/models/add_verhicle_preferences_model.dart';
import 'package:ios_tiretest_ai/models/auth_models.dart';
import 'package:ios_tiretest_ai/models/shop_vendor.dart';
import 'package:ios_tiretest_ai/models/tyre_record.dart';
import 'package:ios_tiretest_ai/models/tyre_upload_response.dart';
import 'package:ios_tiretest_ai/models/update_user_details_model.dart';
import 'package:ios_tiretest_ai/models/user_profile.dart';

import 'package:equatable/equatable.dart';

// ✅ Add your existing imports
// import '...';

enum AuthStatus { initial, loading, success, failure }
enum TwoWheelerStatus { initial, uploading, success, failure }
enum FourWheelerStatus { initial, uploading, success, failure }
enum ProfileStatus { initial, loading, success, failure }
enum AddVehiclePreferencesStatus { initial, loading, success, failure }
enum TyreHistoryStatus { initial, loading, success, failure }
enum ShopsStatus { initial, loading, success, failure }

/// ✅ NEW: Update profile status
enum UpdateProfileStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  // ---------------- SHOPS ----------------
  final ShopsStatus shopsStatus;
  final List<ShopVendor> shops;
  final String? shopsError;

  // ---------------- HISTORY ----------------
  final TyreHistoryStatus tyreHistoryStatus;
  final String? tyreHistoryError;
  final Map<String, List<TyreRecord>> tyreRecordsByType;

  // ---------------- AUTH ----------------
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;
  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;

  final String? error;

  // ---------------- VEHICLE PREF ----------------
  final AddVehiclePreferencesStatus addVehiclePreferencesStatus;
  final VehiclePreferencesModel? vehiclePreferencesModel;
  final String? errorMessageVehiclePreferences;

  // ---------------- UPLOADS ----------------
  final TwoWheelerStatus twoWheelerStatus;
  final TyreUploadResponse? twoWheelerResponse;

  final FourWheelerStatus fourWheelerStatus;
  final TyreUploadResponse? fourWheelerResponse;
  final String? fourWheelerError;

  // ---------------- PROFILE ----------------
  final ProfileStatus profileStatus;
  final UserProfile? profile;

  /// ✅ NEW: UPDATE PROFILE
  final UpdateProfileStatus updateProfileStatus;
  final UpdateUserDetailsResponse? updateProfileResponse;
  final String? updateProfileError;

  // (legacy list you still keep)
  final List<TyreRecord> records;
  final String? recordsError;
  final String recordsVehicleType;

  const AuthState({
    // shops
    this.shopsStatus = ShopsStatus.initial,
    this.shops = const <ShopVendor>[],
    this.shopsError,

    // history
    this.tyreHistoryStatus = TyreHistoryStatus.initial,
    this.tyreHistoryError,
    this.tyreRecordsByType = const {},

    // auth
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.error,

    // vehicle pref
    this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
    this.vehiclePreferencesModel,
    this.errorMessageVehiclePreferences,

    // uploads
    this.twoWheelerStatus = TwoWheelerStatus.initial,
    this.twoWheelerResponse,

    this.fourWheelerStatus = FourWheelerStatus.initial,
    this.fourWheelerResponse,
    this.fourWheelerError,

    // profile
    this.profileStatus = ProfileStatus.initial,
    this.profile,

    // ✅ update profile
    this.updateProfileStatus = UpdateProfileStatus.initial,
    this.updateProfileResponse,
    this.updateProfileError,

    // legacy
    this.records = const [],
    this.recordsError,
    this.recordsVehicleType = 'car',
  });

  // helpers
  List<TyreRecord> get carRecords =>
      tyreRecordsByType['car'] ?? const <TyreRecord>[];
  List<TyreRecord> get bikeRecords =>
      tyreRecordsByType['bike'] ?? const <TyreRecord>[];

  List<TyreRecord> get allTyreRecords {
    final combined = <TyreRecord>[...carRecords, ...bikeRecords];
    combined.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return combined;
  }

  AuthState copyWith({
    ShopsStatus? shopsStatus,
    List<ShopVendor>? shops,
    String? shopsError,

    TyreHistoryStatus? tyreHistoryStatus,
    String? tyreHistoryError,
    Map<String, List<TyreRecord>>? tyreRecordsByType,

    AuthStatus? loginStatus,
    AuthStatus? signupStatus,
    LoginResponse? loginResponse,
    SignupResponse? signupResponse,
    String? error,

    AddVehiclePreferencesStatus? addVehiclePreferencesStatus,
    VehiclePreferencesModel? vehiclePreferencesModel,
    String? errorMessageVehiclePreferences,

    TwoWheelerStatus? twoWheelerStatus,
    TyreUploadResponse? twoWheelerResponse,

    FourWheelerStatus? fourWheelerStatus,
    TyreUploadResponse? fourWheelerResponse,
    String? fourWheelerError,

    ProfileStatus? profileStatus,
    UserProfile? profile,

    // ✅ update profile
    UpdateProfileStatus? updateProfileStatus,
    UpdateUserDetailsResponse? updateProfileResponse,
    String? updateProfileError,

    List<TyreRecord>? records,
    String? recordsError,
    String? recordsVehicleType,
  }) {
    return AuthState(
      // SHOPS
      shopsStatus: shopsStatus ?? this.shopsStatus,
      shops: shops ?? this.shops,
      shopsError: shopsError ?? this.shopsError,

      // HISTORY
      tyreHistoryStatus: tyreHistoryStatus ?? this.tyreHistoryStatus,
      tyreHistoryError: tyreHistoryError ?? this.tyreHistoryError,
      tyreRecordsByType: tyreRecordsByType ?? this.tyreRecordsByType,

      // AUTH
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error ?? this.error,

      // VEHICLE PREF
      addVehiclePreferencesStatus:
          addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
      vehiclePreferencesModel:
          vehiclePreferencesModel ?? this.vehiclePreferencesModel,
      errorMessageVehiclePreferences:
          errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,

      // UPLOADS
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,

      fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
      fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
      fourWheelerError: fourWheelerError ?? this.fourWheelerError,

      // PROFILE
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,

      // ✅ UPDATE PROFILE
      updateProfileStatus: updateProfileStatus ?? this.updateProfileStatus,
      updateProfileResponse: updateProfileResponse ?? this.updateProfileResponse,
      updateProfileError: updateProfileError ?? this.updateProfileError,

      // legacy
      records: records ?? this.records,
      recordsError: recordsError ?? this.recordsError,
      recordsVehicleType: recordsVehicleType ?? this.recordsVehicleType,
    );
  }

  @override
  List<Object?> get props => [
        shopsStatus,
        shops,
        shopsError,
        tyreHistoryStatus,
        tyreHistoryError,
        tyreRecordsByType,
        loginStatus,
        signupStatus,
        loginResponse,
        signupResponse,
        error,
        addVehiclePreferencesStatus,
        vehiclePreferencesModel,
        errorMessageVehiclePreferences,
        twoWheelerStatus,
        twoWheelerResponse,
        fourWheelerStatus,
        fourWheelerResponse,
        fourWheelerError,
        profileStatus,
        profile,

        // ✅ update profile
        updateProfileStatus,
        updateProfileResponse,
        updateProfileError,

        records,
        recordsError,
        recordsVehicleType,
      ];
}




// enum AuthStatus { initial, loading, success, failure }
// enum TwoWheelerStatus { initial, uploading, success, failure }
// enum FourWheelerStatus { initial, uploading, success, failure }
// enum ProfileStatus { initial, loading, success, failure }
// enum AddVehiclePreferencesStatus { initial, loading, success, failure }
// enum TyreHistoryStatus { initial, loading, success, failure }
// enum ShopsStatus { initial, loading, success, failure }

// class AuthState extends Equatable {
//   // ---------------- SHOPS ----------------
//   final ShopsStatus shopsStatus;
//   final List<ShopVendor> shops;
//   final String? shopsError;

//   // ---------------- HISTORY ----------------
//   final TyreHistoryStatus tyreHistoryStatus;
//   final String? tyreHistoryError;
//   final Map<String, List<TyreRecord>> tyreRecordsByType;

//   // ---------------- AUTH ----------------
//   final AuthStatus loginStatus;
//   final AuthStatus signupStatus;
//   final LoginResponse? loginResponse;
//   final SignupResponse? signupResponse;

//   final String? error;

//   // ---------------- VEHICLE PREF ----------------
//   final AddVehiclePreferencesStatus addVehiclePreferencesStatus;
//   final VehiclePreferencesModel? vehiclePreferencesModel;
//   final String? errorMessageVehiclePreferences;

//   // ---------------- UPLOADS ----------------
//   final TwoWheelerStatus twoWheelerStatus;
//   final TyreUploadResponse? twoWheelerResponse;

//   final FourWheelerStatus fourWheelerStatus;
//   final TyreUploadResponse? fourWheelerResponse;
//   final String? fourWheelerError;

//   // ---------------- PROFILE ----------------
//   final ProfileStatus profileStatus;
//   final UserProfile? profile;

//   // (legacy list you still keep)
//   final List<TyreRecord> records;
//   final String? recordsError;
//   final String recordsVehicleType;

//   const AuthState({
//     // shops
//     this.shopsStatus = ShopsStatus.initial,
//     this.shops = const <ShopVendor>[],
//     this.shopsError,

//     // history
//     this.tyreHistoryStatus = TyreHistoryStatus.initial,
//     this.tyreHistoryError,
//     this.tyreRecordsByType = const {},

//     // auth
//     this.loginStatus = AuthStatus.initial,
//     this.signupStatus = AuthStatus.initial,
//     this.loginResponse,
//     this.signupResponse,
//     this.error,

//     // vehicle pref
//     this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
//     this.vehiclePreferencesModel,
//     this.errorMessageVehiclePreferences,

//     // uploads
//     this.twoWheelerStatus = TwoWheelerStatus.initial,
//     this.twoWheelerResponse,

//     this.fourWheelerStatus = FourWheelerStatus.initial,
//     this.fourWheelerResponse,
//     this.fourWheelerError,

//     // profile
//     this.profileStatus = ProfileStatus.initial,
//     this.profile,

//     // legacy
//     this.records = const [],
//     this.recordsError,
//     this.recordsVehicleType = 'car',
//   });

//   // helpers
//   List<TyreRecord> get carRecords => tyreRecordsByType['car'] ?? const <TyreRecord>[];
//   List<TyreRecord> get bikeRecords => tyreRecordsByType['bike'] ?? const <TyreRecord>[];

//   List<TyreRecord> get allTyreRecords {
//     final combined = <TyreRecord>[...carRecords, ...bikeRecords];
//     combined.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
//     return combined;
//   }

//   // ✅ FIXED COPYWITH (THIS WAS YOUR MAIN BUG)
//   AuthState copyWith({
//     ShopsStatus? shopsStatus,
//     List<ShopVendor>? shops,
//     String? shopsError,

//     TyreHistoryStatus? tyreHistoryStatus,
//     String? tyreHistoryError,
//     Map<String, List<TyreRecord>>? tyreRecordsByType,

//     AuthStatus? loginStatus,
//     AuthStatus? signupStatus,
//     LoginResponse? loginResponse,
//     SignupResponse? signupResponse,
//     String? error,

//     AddVehiclePreferencesStatus? addVehiclePreferencesStatus,
//     VehiclePreferencesModel? vehiclePreferencesModel,
//     String? errorMessageVehiclePreferences,

//     TwoWheelerStatus? twoWheelerStatus,
//     TyreUploadResponse? twoWheelerResponse,

//     FourWheelerStatus? fourWheelerStatus,
//     TyreUploadResponse? fourWheelerResponse,
//     String? fourWheelerError,

//     ProfileStatus? profileStatus,
//     UserProfile? profile,

//     List<TyreRecord>? records,
//     String? recordsError,
//     String? recordsVehicleType,
//   }) {
//     return AuthState(
//       // ✅ SHOPS
//       shopsStatus: shopsStatus ?? this.shopsStatus,
//       shops: shops ?? this.shops,
//       shopsError: shopsError ?? this.shopsError,

//       // ✅ HISTORY
//       tyreHistoryStatus: tyreHistoryStatus ?? this.tyreHistoryStatus,
//       tyreHistoryError: tyreHistoryError ?? this.tyreHistoryError,
//       tyreRecordsByType: tyreRecordsByType ?? this.tyreRecordsByType,

//       // ✅ AUTH
//       loginStatus: loginStatus ?? this.loginStatus,
//       signupStatus: signupStatus ?? this.signupStatus,
//       loginResponse: loginResponse ?? this.loginResponse,
//       signupResponse: signupResponse ?? this.signupResponse,
//       error: error ?? this.error,

//       // ✅ VEHICLE PREF
//       addVehiclePreferencesStatus:
//           addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
//       vehiclePreferencesModel: vehiclePreferencesModel ?? this.vehiclePreferencesModel,
//       errorMessageVehiclePreferences:
//           errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,

//       // ✅ UPLOADS
//       twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
//       twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,

//       fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
//       fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
//       fourWheelerError: fourWheelerError ?? this.fourWheelerError,

//       // ✅ PROFILE
//       profileStatus: profileStatus ?? this.profileStatus,
//       profile: profile ?? this.profile,

//       // legacy
//       records: records ?? this.records,
//       recordsError: recordsError ?? this.recordsError,
//       recordsVehicleType: recordsVehicleType ?? this.recordsVehicleType,
//     );
//   }

//   @override
//   List<Object?> get props => [
//         shopsStatus,
//         shops,
//         shopsError,
//         tyreHistoryStatus,
//         tyreHistoryError,
//         tyreRecordsByType,
//         loginStatus,
//         signupStatus,
//         loginResponse,
//         signupResponse,
//         error,
//         addVehiclePreferencesStatus,
//         vehiclePreferencesModel,
//         errorMessageVehiclePreferences,
//         twoWheelerStatus,
//         twoWheelerResponse,
//         fourWheelerStatus,
//         fourWheelerResponse,
//         fourWheelerError,
//         profileStatus,
//         profile,
//         records,
//         recordsError,
//         recordsVehicleType,
//       ];
// }


/*enum AuthStatus { initial, loading, success, failure }
enum TwoWheelerStatus { initial, uploading, success, failure }
enum FourWheelerStatus { initial, uploading, success, failure }
enum ProfileStatus { initial, loading, success, failure }
enum AddVehiclePreferencesStatus { initial, loading, success, failure }
enum TyreHistoryStatus { initial, loading, success, failure }
enum ShopsStatus { initial, loading, success, failure }


class AuthState extends Equatable {
    final ShopsStatus shopsStatus;
  final List<ShopVendor> shops;
  final String? shopsError;
  final TyreHistoryStatus tyreHistoryStatus;
final String? tyreHistoryError;

/// store BOTH car + bike together
final Map<String, List<TyreRecord>> tyreRecordsByType;
  final AuthStatus loginStatus;
  final AuthStatus signupStatus;

  final LoginResponse? loginResponse;
  final SignupResponse? signupResponse;

  final VehiclePreferencesModel? vehiclePreferencesModel;

  final String? error;
  final String? errorMessageVehiclePreferences;

  final TwoWheelerStatus twoWheelerStatus;
  final TyreUploadResponse? twoWheelerResponse;

  final FourWheelerStatus fourWheelerStatus;
  final TyreUploadResponse? fourWheelerResponse;
  final String? fourWheelerError;

  final ProfileStatus profileStatus;
  final UserProfile? profile;

  final AddVehiclePreferencesStatus addVehiclePreferencesStatus;

  /// ✅ NEW: history

  final List<TyreRecord> records;
  final String? recordsError;
  final String recordsVehicleType; // car/bike

  const AuthState({
      this.shopsStatus = ShopsStatus.initial,
    this.shops = const <ShopVendor>[],
    this.shopsError,
     this.tyreHistoryStatus = TyreHistoryStatus.initial,
   this.tyreHistoryError,
  this.tyreRecordsByType = const {},
    this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
    this.loginStatus = AuthStatus.initial,
    this.signupStatus = AuthStatus.initial,
    this.loginResponse,
    this.signupResponse,
    this.vehiclePreferencesModel,
    this.error,
    this.twoWheelerStatus = TwoWheelerStatus.initial,
    this.twoWheelerResponse,
    this.fourWheelerStatus = FourWheelerStatus.initial,
    this.fourWheelerResponse,
    this.fourWheelerError,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
    this.errorMessageVehiclePreferences,

 
    this.records = const [],
    this.recordsError,
    this.recordsVehicleType = 'car',
  });
    List<TyreRecord> get carRecords =>
      tyreRecordsByType['car'] ?? const <TyreRecord>[];

  List<TyreRecord> get bikeRecords =>
      tyreRecordsByType['bike'] ?? const <TyreRecord>[];

  /// ✅ BOTH bike + car combined (latest first)
  List<TyreRecord> get allTyreRecords {
    final combined = <TyreRecord>[...carRecords, ...bikeRecords];
    combined.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return combined;
  }

  AuthState copyWith({
      ShopsStatus? shopsStatus,
    List<ShopVendor>? shops,
    String? shopsError,
    
    TyreHistoryStatus? tyreHistoryStatus,
String? tyreHistoryError,
Map<String, List<TyreRecord>>? tyreRecordsByType,
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
    FourWheelerStatus? fourWheelerStatus,
    TyreUploadResponse? fourWheelerResponse,
    String? fourWheelerError,
    List<TyreRecord>? records,
    String? recordsError,
    String? recordsVehicleType,
  }) {
    return AuthState(
        tyreHistoryStatus: tyreHistoryStatus ?? this.tyreHistoryStatus,
  tyreHistoryError: tyreHistoryError,
  tyreRecordsByType: tyreRecordsByType ?? this.tyreRecordsByType,
      addVehiclePreferencesStatus: addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
      loginStatus: loginStatus ?? this.loginStatus,
      signupStatus: signupStatus ?? this.signupStatus,
      loginResponse: loginResponse ?? this.loginResponse,
      signupResponse: signupResponse ?? this.signupResponse,
      error: error,
      twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
      twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
      vehiclePreferencesModel: vehiclePreferencesModel ?? this.vehiclePreferencesModel,
      errorMessageVehiclePreferences: errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,
      fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
      fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
      fourWheelerError: fourWheelerError,


      records: records ?? this.records,
      recordsError: recordsError,
      recordsVehicleType: recordsVehicleType ?? this.recordsVehicleType,
    );
  }

  @override
  List<Object?> get props => [
       shopsStatus,
        shops,
        shopsError,
      tyreHistoryStatus,
  tyreHistoryError,
  tyreRecordsByType,
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
        fourWheelerStatus,
        fourWheelerResponse,
        fourWheelerError,
        records,
        recordsError,
        recordsVehicleType,
      ];
}*/

// enum AuthStatus { initial, loading, success, failure }
// enum TwoWheelerStatus { initial, uploading, success, failure }

// /// ✅ NEW status
// enum FourWheelerStatus { initial, uploading, success, failure }

// enum ProfileStatus { initial, loading, success, failure }
// enum AddVehiclePreferencesStatus { initial, loading, success, failure }

// class AuthState extends Equatable {
//   final AuthStatus loginStatus;
//   final AuthStatus signupStatus;

//   final LoginResponse? loginResponse;
//   final SignupResponse? signupResponse;

//   final VehiclePreferencesModel? vehiclePreferencesModel;

//   final String? error;

//   final String? errorMessageVehiclePreferences;

//   final TwoWheelerStatus twoWheelerStatus;
//   final TyreUploadResponse? twoWheelerResponse;

//   /// ✅ NEW: 4-wheeler
//   final FourWheelerStatus fourWheelerStatus;
//   final TyreUploadResponse? fourWheelerResponse;
//   final String? fourWheelerError;

//   final ProfileStatus profileStatus;
//   final UserProfile? profile;

//   final AddVehiclePreferencesStatus addVehiclePreferencesStatus;

//   const AuthState({
//     this.addVehiclePreferencesStatus = AddVehiclePreferencesStatus.initial,
//     this.loginStatus = AuthStatus.initial,
//     this.signupStatus = AuthStatus.initial,
//     this.loginResponse,
//     this.signupResponse,
//     this.vehiclePreferencesModel,
//     this.error,
//     this.twoWheelerStatus = TwoWheelerStatus.initial,
//     this.twoWheelerResponse,

//     /// ✅ NEW defaults
//     this.fourWheelerStatus = FourWheelerStatus.initial,
//     this.fourWheelerResponse,
//     this.fourWheelerError,

//     this.profileStatus = ProfileStatus.initial,
//     this.profile,
//     this.errorMessageVehiclePreferences,
//   });

//   AuthState copyWith({
//     AddVehiclePreferencesStatus? addVehiclePreferencesStatus,
//     AuthStatus? loginStatus,
//     AuthStatus? signupStatus,
//     LoginResponse? loginResponse,
//     SignupResponse? signupResponse,
//     String? error,
//     TwoWheelerStatus? twoWheelerStatus,
//     TyreUploadResponse? twoWheelerResponse,
//     ProfileStatus? profileStatus,
//     UserProfile? profile,
//     VehiclePreferencesModel? vehiclePreferencesModel,
//     String? errorMessageVehiclePreferences,

//     /// ✅ NEW
//     FourWheelerStatus? fourWheelerStatus,
//     TyreUploadResponse? fourWheelerResponse,
//     String? fourWheelerError,
//   }) {
//     return AuthState(
//       addVehiclePreferencesStatus:
//           addVehiclePreferencesStatus ?? this.addVehiclePreferencesStatus,
//       loginStatus: loginStatus ?? this.loginStatus,
//       signupStatus: signupStatus ?? this.signupStatus,
//       loginResponse: loginResponse ?? this.loginResponse,
//       signupResponse: signupResponse ?? this.signupResponse,
//       error: error,
//       twoWheelerStatus: twoWheelerStatus ?? this.twoWheelerStatus,
//       twoWheelerResponse: twoWheelerResponse ?? this.twoWheelerResponse,
//       profileStatus: profileStatus ?? this.profileStatus,
//       profile: profile ?? this.profile,
//       vehiclePreferencesModel:
//           vehiclePreferencesModel ?? this.vehiclePreferencesModel,
//       errorMessageVehiclePreferences:
//           errorMessageVehiclePreferences ?? this.errorMessageVehiclePreferences,

//       /// ✅ NEW
//       fourWheelerStatus: fourWheelerStatus ?? this.fourWheelerStatus,
//       fourWheelerResponse: fourWheelerResponse ?? this.fourWheelerResponse,
//       fourWheelerError: fourWheelerError,
//     );
//   }

//   @override
//   List<Object?> get props => [
//         addVehiclePreferencesStatus,
//         loginStatus,
//         signupStatus,
//         loginResponse,
//         signupResponse,
//         error,
//         twoWheelerStatus,
//         twoWheelerResponse,
//         profileStatus,
//         profile,
//         vehiclePreferencesModel,
//         errorMessageVehiclePreferences,

//         /// ✅ NEW
//         fourWheelerStatus,
//         fourWheelerResponse,
//         fourWheelerError,
//       ];
// }
