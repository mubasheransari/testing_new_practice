import 'package:equatable/equatable.dart';

import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {
  const AppStarted();
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class SignupRequested extends AuthEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  const SignupRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [firstName, lastName, email, password];
}

class UploadTwoWheelerRequested extends AuthEvent {
  final String userId;
  final String vehicleId;
  final String token;
  final String frontPath;
  final String backPath;
  final String vehicleType;
  final String? vin;

  const UploadTwoWheelerRequested({
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.frontPath,
    required this.backPath,
    this.vehicleType = 'bike',
    this.vin,
  });

  @override
  List<Object?> get props =>
      [userId, vehicleId, token, frontPath, backPath, vehicleType, vin];
}

/// ✅ NEW: Upload 4-wheeler (car) tyres
class UploadFourWheelerRequested extends AuthEvent {
  final String vehicleId;
  final String vehicleType; // "Car" or "car" (backend strict sometimes)
  final String vin;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  /// paths of captured images
  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  const UploadFourWheelerRequested({
    required this.vehicleId,
    this.vehicleType = 'car',
    required this.vin,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
  });

  @override
  List<Object?> get props => [
        vehicleId,
        vehicleType,
        vin,
        frontLeftTyreId,
        frontRightTyreId,
        backLeftTyreId,
        backRightTyreId,
        frontLeftPath,
        frontRightPath,
        backLeftPath,
        backRightPath,
      ];
}

class ClearAuthError extends AuthEvent {
  const ClearAuthError();
}

class FetchProfileRequested extends AuthEvent {
  final String? token;
  const FetchProfileRequested({this.token});
  @override
  List<Object?> get props => [token];
}

class AddVehiclePreferenccesEvent extends AuthEvent {
  final String vehiclePreference;
  final String brandName;
  final String modelName;
  final String licensePlate;
  final bool? isOwn;
  final String tireBrand;
  final String tireDimension;

  const AddVehiclePreferenccesEvent({
    required this.vehiclePreference,
    required this.brandName,
    required this.modelName,
    required this.licensePlate,
    required this.isOwn,
    required this.tireBrand,
    required this.tireDimension,
  });

  @override
  List<Object?> get props => [
        vehiclePreference,
        brandName,
        modelName,
        licensePlate,
        isOwn,
        tireBrand,
        tireDimension,
      ];
}

