abstract interface class IPasswordChangeDataSource {
  Future<void> changePassword({required String currentPassword, required String newPassword, required String otp});
}
