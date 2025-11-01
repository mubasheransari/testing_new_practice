class TyreUploadRequest {
  final String userId;
  final String vehicleType; // "bike"
  final String vehicleId;
  final String frontPath;
  final String backPath;
  final String token;       // Bearer token
  final String? vin;

  const TyreUploadRequest({
    required this.userId,
    required this.vehicleType,
    required this.vehicleId,
    required this.frontPath,
    required this.backPath,
    required this.token,
    this.vin,
  });
}
