import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  // While connectivity is still resolving, assume online so first paint
  // fetches sites from the server instead of an empty offline cache.
  final async = ref.watch(connectivityStatusProvider);
  return async.maybeWhen(
    data: (results) =>
        results.any((result) => result != ConnectivityResult.none),
    orElse: () => true,
  );
});

bool isNetworkError(Object error) {
  if (error is SocketException) {
    return true;
  }
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    return message.contains('network') ||
        message.contains('connection') ||
        message.contains('host lookup');
  }
  return false;
}

String readablePostgrestError(PostgrestException error) {
  if (error.code == '42501' || error.message.toLowerCase().contains('policy')) {
    return 'Server rejected this reading. Check your access or contact admin.';
  }
  return error.message;
}
