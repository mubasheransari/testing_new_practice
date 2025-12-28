class FourWheelerUploadRequest {
  final String userId;
  final String vehicleId;
  final String token;
  final String vin;
  final String vehicleType;

  final String frontLeftTyreId;
  final String frontRightTyreId;
  final String backLeftTyreId;
  final String backRightTyreId;

  final String frontLeftPath;
  final String frontRightPath;
  final String backLeftPath;
  final String backRightPath;

  FourWheelerUploadRequest({
    required this.userId,
    required this.vehicleId,
    required this.token,
    required this.vin,
    required this.vehicleType,
    required this.frontLeftTyreId,
    required this.frontRightTyreId,
    required this.backLeftTyreId,
    required this.backRightTyreId,
    required this.frontLeftPath,
    required this.frontRightPath,
    required this.backLeftPath,
    required this.backRightPath,
  });
}
