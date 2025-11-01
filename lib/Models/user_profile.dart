import 'dart:convert';

class UserProfile {
  final String firstName;
  final String lastName;
  final String? phone;
  final String? profileImage;
  final String purpose;
  final String userId;
  final String email;
  final int loginCount;
  final int isSurveyShown;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profileImage,
    required this.purpose,
    required this.userId,
    required this.email,
    required this.loginCount,
    required this.isSurveyShown,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        firstName: j['firstName']?.toString() ?? '',
        lastName: j['lastName']?.toString() ?? '',
        phone: j['phone'] as String?,
        profileImage: j['profileImage'] as String?,
        purpose: j['purpose']?.toString() ?? '',
        userId: j['userId']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        loginCount: (j['loginCount'] is int)
            ? j['loginCount'] as int
            : int.tryParse(j['loginCount']?.toString() ?? '0') ?? 0,
        isSurveyShown: (j['isSurveyShown'] is int)
            ? j['isSurveyShown'] as int
            : int.tryParse(j['isSurveyShown']?.toString() ?? '0') ?? 0,
      );

  @override
  String toString() => jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'profileImage': profileImage,
        'purpose': purpose,
        'userId': userId,
        'email': email,
        'loginCount': loginCount,
        'isSurveyShown': isSurveyShown,
      });
}
