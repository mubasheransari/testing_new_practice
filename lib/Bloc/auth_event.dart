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

class ClearAuthError extends AuthEvent {
  const ClearAuthError();
}

// NEW: fetch user profile (optional override token)
class FetchProfileRequested extends AuthEvent {
  final String? token;
  const FetchProfileRequested({this.token});
  @override
  List<Object?> get props => [token];
}


// abstract class AuthEvent extends Equatable {
//   const AuthEvent();
//   @override
//   List<Object?> get props => [];
// }

// class UploadTwoWheelerRequested extends AuthEvent {
//   final String userId;
//   final String vehicleId;
//   final String token;       // Bearer <token>
//   final String frontPath;   // local file path (jpeg/png)
//   final String backPath;    // local file path (jpeg/png)
//   final String vehicleType; // "bike"
//   final String? vin;        // optional

//   const UploadTwoWheelerRequested({
//     required this.userId,
//     required this.vehicleId,
//     required this.token,
//     required this.frontPath,
//     required this.backPath,
//     this.vehicleType = 'bike',
//     this.vin,
//   });

//   @override
//   List<Object?> get props =>
//       [userId, vehicleId, token, frontPath, backPath, vehicleType, vin];
// }

// class LoginRequested extends AuthEvent {
//   final String email;
//   final String password;
//   const LoginRequested({required this.email, required this.password});
//   @override
//   List<Object?> get props => [email, password];
// }

// class SignupRequested extends AuthEvent {
//   final String firstName;
//   final String lastName;
//   final String email;
//   final String password;
//   const SignupRequested({
//     required this.firstName,
//     required this.lastName,
//     required this.email,
//     required this.password,
//   });
//   @override
//   List<Object?> get props => [firstName, lastName, email, password];
// }

// class ClearAuthError extends AuthEvent {
//   const ClearAuthError();
// }