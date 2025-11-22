class VehiclePreferencesRequest {
  final String vehiclePreference; // "Car" | "Bike"
  final String brandName;
  final String modelName;
  final String licensePlate;
  final bool? isOwn;
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

  Map<String, dynamic> toJson() => {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "isOwn": isOwn,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
      };
}
