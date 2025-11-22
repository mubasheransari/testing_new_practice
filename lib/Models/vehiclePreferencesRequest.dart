class VehiclePreferencesRequest {
  final String vehiclePreference; // "Car" / "Bike"
  final String brandName;
  final String modelName;
  final String licensePlate;
  final bool? isOwn; // we can keep it but not required by API
  final String tireBrand;
  final String tireDimension;

  VehiclePreferencesRequest({
    required this.vehiclePreference,
    required this.brandName,
    required this.modelName,
    required this.licensePlate,
    required this.isOwn,
    required this.tireBrand,
    required this.tireDimension,
  });

  /// If later you still need JSON, keep this:
  Map<String, dynamic> toJson() => {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
        if (isOwn != null) "isOwn": isOwn,
      };

  /// 🔥 Form-encoded body (string values) EXACTLY like Postman (x-www-form-urlencoded)
  Map<String, String> toForm() => {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
        if (isOwn != null) "isOwn": isOwn.toString(), // "true"/"false"
      };
}
