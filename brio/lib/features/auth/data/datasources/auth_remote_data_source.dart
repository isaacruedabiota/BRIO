import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final ApiClient _api;
  const AuthRemoteDataSource(this._api);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.post('/auth/login/', data: {
      'email':    email,
      'password': password,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
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
    final data = await _api.post('/auth/register/', data: {
      'email':                  email,
      'password':               password,
      'name':                   name,
      'goal':                   goal,
      'weight_kg':              weightKg,
      'height_cm':              heightCm,
      'birth_date':             birthDate,
      'gender':                 gender,
      'activity_level':         activityLevel,
      'training_days_per_week': trainingDaysPerWeek,
    });
    return data as Map<String, dynamic>;
  }

  Future<UserModel> getMe() async {
    final data = await _api.get('/auth/me/');
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// Updates only the fields sent (`null` ones are omitted).
  Future<UserModel> updateProfile(Map<String, dynamic> fields) async {
    final data = await _api.patch('/auth/me/', data: fields);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/auth/me/change-password/', data: {
      'current_password': currentPassword,
      'new_password':     newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _api.delete('/auth/me/');
  }
}
