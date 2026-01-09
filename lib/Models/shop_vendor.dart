class ShopVendor {
  final String id;
  final String shopName;
  final String? location;
  final String? phoneNumber;
  final String? address;
  final String? services;
  final String? shopImageUrl;
  final double latitude;
  final double longitude;

  /// optional fields in your response (fallback safe)
  final double rating; // derived from weights or default
  final int? reviewCount;

  const ShopVendor({
    required this.id,
    required this.shopName,
    required this.latitude,
    required this.longitude,
    this.location,
    this.phoneNumber,
    this.address,
    this.services,
    this.shopImageUrl,
    required this.rating,
    this.reviewCount,
  });

  String get displayAddress =>
      (address?.trim().isNotEmpty == true)
          ? address!.trim()
          : (location?.trim().isNotEmpty == true)
              ? location!.trim()
              : '—';

  factory ShopVendor.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // your API returns latitude/longitude sometimes as string
    final lat = _toDouble(json['latitude']);
    final lng = _toDouble(json['longitude']);

    // rating fallback strategy:
    // - if backend has rating => use it
    // - else if numeric_weights/weights => use it
    // - else default 4.5
    double rating = 4.5;
    final r1 = json['rating'];
    final r2 = json['numeric_weights'];
    final r3 = json['weights'];
    if (r1 != null) rating = _toDouble(r1);
    else if (r2 != null) rating = _toDouble(r2);
    else if (r3 != null) rating = _toDouble(r3);

    // clamp rating 0-5
    if (rating.isNaN) rating = 4.5;
    rating = rating.clamp(0.0, 5.0);

    return ShopVendor(
      id: (json['id'] ?? '').toString(),
      shopName: (json['shopName'] ?? json['shop_name'] ?? '').toString(),
      location: json['location']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address']?.toString(),
      services: json['services']?.toString(),
      shopImageUrl: json['shopImageURL']?.toString(),
      latitude: lat,
      longitude: lng,
      rating: rating,
      reviewCount: (json['reviewCount'] is int)
          ? json['reviewCount'] as int
          : int.tryParse((json['reviewCount'] ?? '').toString()),
    );
  }
}
