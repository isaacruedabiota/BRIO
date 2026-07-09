import '../entities/user.dart';

abstract class AuthRepository {
  Future<({User user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  });

  Future<({User user, String accessToken, String refreshToken})> register({
    required String email,
    required String password,
    required String name,
    required String goal,
    required double weightKg,
    required int heightCm,
    required String birthDate,
    required String gender,
    required String activityLevel,
    required int trainingDaysPerWeek,
  });

  Future<User> getMe();
  Future<void> logout();
  Future<bool> isLoggedIn();

  /// Updates profile data. Only non-null fields are sent; the backend
  /// recalculates the macro targets and returns the updated user.
  Future<User> updateProfile({
    String? name,
    String? goal,
    double? weightKg,
    int? heightCm,
    String? birthDate,
    String? gender,
    String? activityLevel,
    int? trainingDaysPerWeek,
    bool? isPublic,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> deleteAccount();
}
