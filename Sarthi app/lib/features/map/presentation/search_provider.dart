import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ola_maps_repository.dart';
import '../../auth/presentation/auth_providers.dart';

final olaMapsRepositoryProvider = Provider<OlaMapsRepository>((ref) {
  return OlaMapsRepository();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  // Debounce could be implemented here using a timer if needed,
  // but for simplicity we rely on the FutureProvider's cancellation or UI debouncing.

  final repo = ref.watch(olaMapsRepositoryProvider);
  return repo.autocomplete(query);
});

final recentCompletedDropsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];

  try {
    final recentSearches = user.recentSearches;
    if (recentSearches != null && recentSearches.isNotEmpty) {
      return List<Map<String, dynamic>>.from(recentSearches);
    }
    return [];
  } catch (e) {
    debugPrint('Failed to fetch recent drops: $e');
    return [];
  }
});
