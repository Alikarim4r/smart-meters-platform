import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

final meterSearchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(node.dispose);
  return node;
});

/// Remembers collapsed/expanded state per source group key.
final sourceGroupExpandedProvider =
    StateProvider.family<bool, String>((ref, key) => true);

final meterComparisonFavoritesProvider =
    StateProvider.family<Set<String>, String>((ref, key) => {});

final meterComparisonRecentProvider =
    StateProvider.family<List<String>, String>((ref, key) => []);
