import '../../../../core/network/api_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final ApiClient _api;

  const AuthRepositoryImpl(this._remote, this._api);

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final json = await _remote.login(email, password);
    return _parseAuthResponse(json);
  }

  @override
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
  }) async {
    final json = await _remote.register(
      email:                email,
      password:             password,
      name:                 name,
      goal:                 goal,
      weightKg:             weightKg,
      heightCm:             heightCm,
      birthDate:            birthDate,
      gender:               gender,
      activityLevel:        activityLevel,
      trainingDaysPerWeek:  trainingDaysPerWeek,
    );
    return _parseAuthResponse(json);
  }

  @override
  Future<User> getMe() async {
    final model = await _remote.getMe();
    return model.toDomain();
  }

  @override
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
  }) async {
    final fields = <String, dynamic>{
      if (name != null)                'name':                   name,
      if (goal != null)                'goal':                   goal,
      if (weightKg != null)            'weight_kg':              weightKg,
      if (heightCm != null)            'height_cm':              heightCm,
      if (birthDate != null)           'birth_date':             birthDate,
      if (gender != null)              'gender':                 gender,
      if (activityLevel != null)       'activity_level':         activityLevel,
      if (trainingDaysPerWeek != null) 'training_days_per_week': trainingDaysPerWeek,
      if (isPublic != null)            'is_public':              isPublic,
    };
    final model = await _remote.updateProfile(fields);
    return model.toDomain();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _remote.changePassword(
        currentPassword: currentPassword,
        newPassword:     newPassword,
      );

  @override
  Future<void> deleteAccount() => _remote.deleteAccount();

  @override
  Future<void> logout() async => _api.clearTokens();

  @override
  Future<bool> isLoggedIn() => _api.hasValidToken();

  // Helper.

  Future<({User user, String accessToken, String refreshToken})> _parseAuthResponse(
    Map<String, dynamic> json,
  ) async {
    final user         = UserModel.fromJson(json['user'] as Map<String, dynamic>).toDomain();
    final accessToken  = json['access_token']  as String;
    final refreshToken = json['refresh_token'] as String;

    await _api.saveTokens(access: accessToken, refresh: refreshToken);

    return (user: user, accessToken: accessToken, refreshToken: refreshToken);
  }
}
