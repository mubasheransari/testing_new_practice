import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Models/tyre_upload_request.dart';
import 'package:ios_tiretest_ai/Models/vehiclePreferencesRequest.dart';
import 'package:ios_tiretest_ai/Repository/repository.dart';
import '../Models/auth_models.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {//Testing@123
  final AuthRepository repo;

  AuthBloc(this.repo) : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLogin);
    on<SignupRequested>(_onSignup);
    on<UploadTwoWheelerRequested>(_onTwoWheelerUpload);
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

     final box   = GetStorage();  
      final token = (box.read<String>('auth_token') ?? '').trim();
  // Prevent double-taps while an upload is in-flight
  if (state.twoWheelerStatus == TwoWheelerStatus.uploading) return;

  // Basic validations
 // final token = e.token.trim();
  if (token.isEmpty) {
    emit(state.copyWith(
      twoWheelerStatus: TwoWheelerStatus.failure,
      error: 'Missing auth token. Please log in again.',
    ));
    return;
  }
  // if (e.userId.trim().isEmpty) {
  //   emit(state.copyWith(
  //     twoWheelerStatus: TwoWheelerStatus.failure,
  //     error: 'Missing user_id.',
  //   ));
  //   return;
  // }
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
    error: null, // clear any previous error
  ));

  

  final req = TyreUploadRequest(
    userId: state.profile!.userId.toString(),
    vehicleType: 'bike', 
    vehicleId: '993163bd-01a1-4c3b-9f18-4df2370ed954',
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
  final sc  = r.failure?.statusCode;
  final msg = r.failure?.message ?? 'Upload failed${sc != null ? ' ($sc)' : ''}';
  emit(state.copyWith(
    twoWheelerStatus: TwoWheelerStatus.failure,
    error: msg, 
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

   addVehiclePreferences(
    AddVehiclePreferenccesEvent event,
    Emitter<AuthState> emit,
  ) async{
  emit(state.copyWith(addVehiclePreferencesStatus: AddVehiclePreferencesStatus.loading));

  final req = VehiclePreferencesRequest(
    vehiclePreference: event.vehiclePreference,
    brandName: event.brandName,
    modelName: event.modelName,
    licensePlate: event.licensePlate,
    isOwn: event.isOwn,
    tireBrand: event.tireBrand,
    tireDimension: event.tireDimension,
  );

  final result = await repo.addVehiclePreferences(req);

  if (!result.isSuccess) {
    emit(state.copyWith(
    addVehiclePreferencesStatus: AddVehiclePreferencesStatus.failure,//  status: AuthStatus.failure,
      errorMessageVehiclePreferences: result.failure?.message ?? 'Failed to save vehicle',
    ));
    return;
  }

  emit(state.copyWith(
 addVehiclePreferencesStatus: AddVehiclePreferencesStatus.failure,
    vehiclePreferencesModel: result.data, // if you store it in state
  ));
}



}

