import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';
import '../../../app/app_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user != null) {
    // Use ref.read inside async body — ref.watch would create unintended subscriptions
    final userRepo = ref.read(userRepositoryProvider);
    var appUser = await userRepo.getUser(user.uid);

    // Auto-repair missing Firestore document if Auth exists
    if (appUser == null) {
      final appType = ref.read(appConfigProvider).appType;
      final role = appType == AppType.captain ? 'captain' : 'user';

      appUser = AppUser(
        uid: user.uid,
        email: user.email ?? 'No Email',
        name: user.displayName ?? 'New $role',
        role: role,
        createdAt: DateTime.now(),
      );
      await userRepo.createUser(appUser);
    }

    return appUser;
  }
  return null;
});

final mySupportTicketsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).streamMyTickets(user.uid);
});
