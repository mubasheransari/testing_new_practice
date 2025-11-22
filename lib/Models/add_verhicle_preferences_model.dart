// To parse this JSON data, do
//
//     final vehiclePreferencesModel = vehiclePreferencesModelFromJson(jsonString);

import 'dart:convert';

VehiclePreferencesModel vehiclePreferencesModelFromJson(String str) => VehiclePreferencesModel.fromJson(json.decode(str));

String vehiclePreferencesModelToJson(VehiclePreferencesModel data) => json.encode(data.toJson());

class VehiclePreferencesModel {
    String message;
    String vehicleIds;
    List<StoredDatum> storedData;

    VehiclePreferencesModel({
        required this.message,
        required this.vehicleIds,
        required this.storedData,
    });

    factory VehiclePreferencesModel.fromJson(Map<String, dynamic> json) => VehiclePreferencesModel(
        message: json["message"],
        vehicleIds: json["vehicleIds"],
        storedData: List<StoredDatum>.from(json["storedData"].map((x) => StoredDatum.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "vehicleIds": vehicleIds,
        "storedData": List<dynamic>.from(storedData.map((x) => x.toJson())),
    };
}

class StoredDatum {
    String vehiclePreference;
    String brandName;
    String modelName;
    String licensePlate;
    dynamic isOwn;
    String tireBrand;
    String tireDimension;
    String userId;
    String id;
    dynamic frontTyreId;
    dynamic backTyreId;
    String frontLeftTyreId;
    String frontRightTyreId;
    String backLeftTyreId;
    String backRightTyreId;

    StoredDatum({
        required this.vehiclePreference,
        required this.brandName,
        required this.modelName,
        required this.licensePlate,
        required this.isOwn,
        required this.tireBrand,
        required this.tireDimension,
        required this.userId,
        required this.id,
        required this.frontTyreId,
        required this.backTyreId,
        required this.frontLeftTyreId,
        required this.frontRightTyreId,
        required this.backLeftTyreId,
        required this.backRightTyreId,
    });

    factory StoredDatum.fromJson(Map<String, dynamic> json) => StoredDatum(
        vehiclePreference: json["vehiclePreference"],
        brandName: json["brandName"],
        modelName: json["modelName"],
        licensePlate: json["licensePlate"],
        isOwn: json["isOwn"],
        tireBrand: json["tireBrand"],
        tireDimension: json["tireDimension"],
        userId: json["userId"],
        id: json["id"],
        frontTyreId: json["frontTyreId"],
        backTyreId: json["backTyreId"],
        frontLeftTyreId: json["frontLeftTyreId"],
        frontRightTyreId: json["frontRightTyreId"],
        backLeftTyreId: json["backLeftTyreId"],
        backRightTyreId: json["backRightTyreId"],
    );

    Map<String, dynamic> toJson() => {
        "vehiclePreference": vehiclePreference,
        "brandName": brandName,
        "modelName": modelName,
        "licensePlate": licensePlate,
        "isOwn": isOwn,
        "tireBrand": tireBrand,
        "tireDimension": tireDimension,
        "userId": userId,
        "id": id,
        "frontTyreId": frontTyreId,
        "backTyreId": backTyreId,
        "frontLeftTyreId": frontLeftTyreId,
        "frontRightTyreId": frontRightTyreId,
        "backLeftTyreId": backLeftTyreId,
        "backRightTyreId": backRightTyreId,
    };
}



// // To parse this JSON data, do 
// //
// //     final vehiclePreferencesModel = vehiclePreferencesModelFromJson(jsonString);

// import 'dart:convert';

// VehiclePreferencesModel vehiclePreferencesModelFromJson(String str) => VehiclePreferencesModel.fromJson(json.decode(str));

// String vehiclePreferencesModelToJson(VehiclePreferencesModel data) => json.encode(data.toJson());

// class VehiclePreferencesModel {
//     String message;
//     String vehicleIds;
//     List<StoredDatum> storedData;

//     VehiclePreferencesModel({
//         required this.message,
//         required this.vehicleIds,
//         required this.storedData,
//     });

//     factory VehiclePreferencesModel.fromJson(Map<String, dynamic> json) => VehiclePreferencesModel(
//         message: json["message"],
//         vehicleIds: json["vehicleIds"],
//         storedData: List<StoredDatum>.from(json["storedData"].map((x) => StoredDatum.fromJson(x))),
//     );

//     Map<String, dynamic> toJson() => {
//         "message": message,
//         "vehicleIds": vehicleIds,
//         "storedData": List<dynamic>.from(storedData.map((x) => x.toJson())),
//     };
// }

// class StoredDatum {
//     String vehiclePreference;
//     String brandName;
//     String modelName;
//     String licensePlate;
//     dynamic isOwn;
//     String tireBrand;
//     String tireDimension;
//     String userId;
//     String id;
//     dynamic frontTyreId;
//     dynamic backTyreId;
//     String frontLeftTyreId;
//     String frontRightTyreId;
//     String backLeftTyreId;
//     String backRightTyreId;

//     StoredDatum({
//         required this.vehiclePreference,
//         required this.brandName,
//         required this.modelName,
//         required this.licensePlate,
//         required this.isOwn,
//         required this.tireBrand,
//         required this.tireDimension,
//         required this.userId,
//         required this.id,
//         required this.frontTyreId,
//         required this.backTyreId,
//         required this.frontLeftTyreId,
//         required this.frontRightTyreId,
//         required this.backLeftTyreId,
//         required this.backRightTyreId,
//     });

//     factory StoredDatum.fromJson(Map<String, dynamic> json) => StoredDatum(
//         vehiclePreference: json["vehiclePreference"],
//         brandName: json["brandName"],
//         modelName: json["modelName"],
//         licensePlate: json["licensePlate"],
//         isOwn: json["isOwn"],
//         tireBrand: json["tireBrand"],
//         tireDimension: json["tireDimension"],
//         userId: json["userId"],
//         id: json["id"],
//         frontTyreId: json["frontTyreId"],
//         backTyreId: json["backTyreId"],
//         frontLeftTyreId: json["frontLeftTyreId"],
//         frontRightTyreId: json["frontRightTyreId"],
//         backLeftTyreId: json["backLeftTyreId"],
//         backRightTyreId: json["backRightTyreId"],
//     );

//     Map<String, dynamic> toJson() => {
//         "vehiclePreference": vehiclePreference,
//         "brandName": brandName,
//         "modelName": modelName,
//         "licensePlate": licensePlate,
//         "isOwn": isOwn,
//         "tireBrand": tireBrand,
//         "tireDimension": tireDimension,
//         "userId": userId,
//         "id": id,
//         "frontTyreId": frontTyreId,
//         "backTyreId": backTyreId,
//         "frontLeftTyreId": frontLeftTyreId,
//         "frontRightTyreId": frontRightTyreId,
//         "backLeftTyreId": backLeftTyreId,
//         "backRightTyreId": backRightTyreId,
//     };
// }
