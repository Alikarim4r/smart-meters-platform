import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/alert_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/meter_catalog_repository.dart';
import '../repositories/meter_image_storage_repository.dart';
import '../repositories/meter_reading_repository.dart';
import '../repositories/meter_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/site_repository.dart';
import '../repositories/site_tank_repository.dart';
import '../repositories/site_network_repository.dart';
import '../repositories/utility_network_repository.dart';
import '../repositories/user_admin_repository.dart';
import '../repositories/policy_settings_repository.dart';
import '../repositories/reading_correction_repository.dart';
import '../repositories/zone_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(
    ref.watch(dashboardRepositoryProvider),
    ref.watch(policySettingsRepositoryProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository(ref.watch(supabaseClientProvider));
});

final siteTankRepositoryProvider = Provider<SiteTankRepository>((ref) {
  return SiteTankRepository(ref.watch(supabaseClientProvider));
});

final siteNetworkRepositoryProvider = Provider<SiteNetworkRepository>((ref) {
  return SiteNetworkRepository(ref.watch(supabaseClientProvider));
});

final utilityNetworkRepositoryProvider = Provider<UtilityNetworkRepository>((
  ref,
) {
  return UtilityNetworkRepository(ref.watch(supabaseClientProvider));
});

final zoneRepositoryProvider = Provider<ZoneRepository>((ref) {
  return ZoneRepository(ref.watch(supabaseClientProvider));
});

final meterCatalogRepositoryProvider = Provider<MeterCatalogRepository>((ref) {
  return MeterCatalogRepository(ref.watch(supabaseClientProvider));
});

final meterRepositoryProvider = Provider<MeterRepository>((ref) {
  return MeterRepository(ref.watch(supabaseClientProvider));
});

final meterReadingRepositoryProvider = Provider<MeterReadingRepository>((ref) {
  return MeterReadingRepository(ref.watch(supabaseClientProvider));
});

final meterImageStorageRepositoryProvider =
    Provider<MeterImageStorageRepository>((ref) {
      return MeterImageStorageRepository(ref.watch(supabaseClientProvider));
    });

final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  return UserAdminRepository(ref.watch(supabaseClientProvider));
});

final readingCorrectionRepositoryProvider =
    Provider<ReadingCorrectionRepository>((ref) {
      return ReadingCorrectionRepository(ref.watch(supabaseClientProvider));
    });

final policySettingsRepositoryProvider = Provider<PolicySettingsRepository>((
  ref,
) {
  return PolicySettingsRepository(ref.watch(supabaseClientProvider));
});
