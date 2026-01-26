// providers/interests_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final interestsProvider = StateNotifierProvider<InterestsNotifier, List<String>>((ref) {
  return InterestsNotifier();
});

class InterestsNotifier extends StateNotifier<List<String>> {
  InterestsNotifier() : super([]) { _loadInitial(); }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('userInterests') ?? [];
  }

  Future<void> save(List<String> newInterests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('userInterests', newInterests);
    state = newInterests; // UI Rebuilds here
  }
}