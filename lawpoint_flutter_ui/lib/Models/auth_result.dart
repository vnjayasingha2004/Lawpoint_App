import 'user.dart';

class AuthRegistrationResult {
  final bool otpRequired;
  final String? devOtp;
  final String? message;
  final User? user;

  const AuthRegistrationResult({
    required this.otpRequired,
    this.devOtp,
    this.message,
    this.user,
  });

  factory AuthRegistrationResult.fromJson(Map<String, dynamic> json) {
    final dynamic userJson = json['user'] ?? json['item'];
    return AuthRegistrationResult(
      otpRequired: json['otpRequired'] == true ||
          json['otp_required'] == true ||
          json['otpRequired']?.toString().toLowerCase() == 'true' ||
          json['otp_required']?.toString().toLowerCase() == 'true',
      devOtp: (json['devOtp'] ?? json['dev_otp'])?.toString(),
      message: (json['message'] ?? json['status'])?.toString(),
      user: userJson is Map<String, dynamic> ? User.fromJson(userJson) : null,
    );
  }
}
