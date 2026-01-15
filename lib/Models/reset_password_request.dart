class ResetPasswordRequest {
  final String userId;
  final String newPassword;
  final String confirmNewPassword;

  const ResetPasswordRequest({
    required this.userId,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  Map<String, dynamic> toJson() => {
        "userId": userId.trim(),
        "newPassword": newPassword,
        "confirmNewPassword": confirmNewPassword.trim(),
      };
}
