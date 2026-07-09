import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

// State.

class AuthState {
  final User? user;
  final bool isAuthenticated;

  const AuthState({this.user, this.isAuthenticated = false});

  AuthState copyWith({User? user, bool? isAuthenticated}) => AuthState(
        user:            user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

// Providers.

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(AuthRemoteDataSource(api), api);
});

// Notifier.

class AuthNotifier extends AsyncNotifier<AuthState> {

  @override
  Future<AuthState> build() async {
    final repo      = ref.read(authRepositoryProvider);
    final loggedIn  = await repo.isLoggedIn();
    if (!loggedIn) return const AuthState();

    try {
      final user = await repo.getMe();
      return AuthState(user: user, isAuthenticated: true);
    } catch (_) {
      return const AuthState();
    }
  }

  // Actions.

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final result = await repo.login(email: email, password: password);
      return AuthState(user: result.user, isAuthenticated: true);
    });
  }

  Future<void> register({
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
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final result = await repo.register(
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
      return AuthState(user: result.user, isAuthenticated: true);
    });
  }

  /// Updates the profile and refreshes state with the returned user (macros
  /// already recalculated). Throws on failure.
  Future<void> updateProfile({
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
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.updateProfile(
      name:                name,
      goal:                goal,
      weightKg:            weightKg,
      heightCm:            heightCm,
      birthDate:           birthDate,
      gender:              gender,
      activityLevel:       activityLevel,
      trainingDaysPerWeek: trainingDaysPerWeek,
      isPublic:            isPublic,
    );
    state = AsyncData(AuthState(user: user, isAuthenticated: true));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.changePassword(
      currentPassword: currentPassword,
      newPassword:     newPassword,
    );
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.deleteAccount();
    await repo.logout();
    state = const AsyncData(AuthState());
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(AuthState());
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
