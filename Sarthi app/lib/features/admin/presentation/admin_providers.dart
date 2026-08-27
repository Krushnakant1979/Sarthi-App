import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../../auth/domain/app_user.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final fareRulesProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, vehicleType) {
  return ref.watch(adminRepositoryProvider).streamFareRules(vehicleType);
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllUsers();
});

final allRidesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllRides();
});

final usersFilterProvider = StateProvider<String>((ref) => 'all');

final payoutHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamPayoutHistory();
});

final offersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamOffers();
});

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAnalyticsData();
});

final globalSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).streamGlobalSettings();
});

final supportTicketsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamSupportTickets();
});
