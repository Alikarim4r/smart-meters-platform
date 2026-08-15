import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emission_factor.dart';
import '../models/normalization_model.dart';
import '../models/occupancy_calendar.dart';
import '../models/portfolio_forecast.dart';
import '../models/saving_persistence_result.dart';
import '../models/weather_dataset.dart';

/// Thin Phase 5 repositories (CRUD). Calculations stay in pure services.
class WeatherDatasetRepository {
  WeatherDatasetRepository(this._client);
  final SupabaseClient _client;

  Future<List<WeatherDataset>> listForOrg(String organizationId) async {
    final rows = await _client
        .from('conservation_weather_datasets')
        .select()
        .eq('organization_id', organizationId)
        .order('period_start');
    return (rows as List)
        .map((e) => WeatherDataset.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<WeatherObservation>> listObservations(String datasetId) async {
    final rows = await _client
        .from('conservation_weather_observations')
        .select()
        .eq('dataset_id', datasetId)
        .order('period_start');
    return (rows as List)
        .map(
          (e) =>
              WeatherObservation.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}

class NormalizationModelRepository {
  NormalizationModelRepository(this._client);
  final SupabaseClient _client;

  Future<List<NormalizationModel>> listForSite(String siteId) async {
    final rows = await _client
        .from('conservation_normalization_models')
        .select()
        .eq('site_id', siteId)
        .order('model_version');
    return (rows as List)
        .map(
          (e) =>
              NormalizationModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<NormalizedResult>> listResultsForSite(
    String siteId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('conservation_normalized_results')
        .select()
        .eq('site_id', siteId)
        .order('period_start', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => NormalizedResult.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}

class OperatingCalendarRepository {
  OperatingCalendarRepository(this._client);
  final SupabaseClient _client;

  Future<List<SiteOperatingCalendarEntry>> listForSite(
    String siteId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var q = _client.from('site_operating_calendar').select().eq('site_id', siteId);
    if (from != null) {
      q = q.gte('period_date', from.toIso8601String().substring(0, 10));
    }
    if (to != null) {
      q = q.lte('period_date', to.toIso8601String().substring(0, 10));
    }
    final rows = await q.order('period_date');
    return (rows as List)
        .map(
          (e) => SiteOperatingCalendarEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}

class SavingPersistenceRepository {
  SavingPersistenceRepository(this._client);
  final SupabaseClient _client;

  Future<SavingPersistenceResult> upsert(SavingPersistenceResult row) async {
    final inserted = await _client
        .from('conservation_saving_persistence')
        .upsert(row.toInsertJson())
        .select()
        .single();
    return SavingPersistenceResult.fromJson(
      Map<String, dynamic>.from(inserted),
    );
  }

  Future<List<SavingPersistenceResult>> listForMv(String mvId) async {
    final rows = await _client
        .from('conservation_saving_persistence')
        .select()
        .eq('measurement_verification_id', mvId)
        .order('follow_up_start');
    return (rows as List)
        .map(
          (e) => SavingPersistenceResult.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<SavingPersistenceResult>> listForSite(
    String siteId, {
    int limit = 30,
  }) async {
    final rows = await _client
        .from('conservation_saving_persistence')
        .select()
        .eq('site_id', siteId)
        .order('follow_up_start', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => SavingPersistenceResult.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}

class EmissionFactorRepository {
  EmissionFactorRepository(this._client);
  final SupabaseClient _client;

  Future<List<EmissionFactor>> listActive(
    String organizationId, {
    String? utilityOrFuelType,
  }) async {
    var q = _client
        .from('emission_factors')
        .select()
        .eq('organization_id', organizationId)
        .eq('status', 'active');
    if (utilityOrFuelType != null) {
      q = q.eq('utility_or_fuel_type', utilityOrFuelType);
    }
    final rows = await q.order('effective_from', ascending: false);
    return (rows as List)
        .map((e) => EmissionFactor.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class CarbonResultRepository {
  CarbonResultRepository(this._client);
  final SupabaseClient _client;

  Future<List<CarbonResult>> listForSite(String siteId, {int limit = 50}) async {
    final rows = await _client
        .from('conservation_carbon_results')
        .select()
        .eq('site_id', siteId)
        .order('calculated_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => CarbonResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class PortfolioSummaryRepository {
  PortfolioSummaryRepository(this._client);
  final SupabaseClient _client;

  Future<List<PortfolioSummary>> listForOrg(
    String organizationId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from('conservation_portfolio_summaries')
        .select()
        .eq('organization_id', organizationId)
        .order('refreshed_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => PortfolioSummary.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}

class ForecastResultRepository {
  ForecastResultRepository(this._client);
  final SupabaseClient _client;

  Future<List<ForecastResult>> listForSite(String siteId, {int limit = 20}) async {
    final rows = await _client
        .from('conservation_forecast_results')
        .select()
        .eq('site_id', siteId)
        .order('calculated_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => ForecastResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class RecommendationRepository {
  RecommendationRepository(this._client);
  final SupabaseClient _client;

  Future<List<ConservationRecommendation>> listOpenForSite(String siteId) async {
    final rows = await _client
        .from('conservation_recommendations')
        .select()
        .eq('site_id', siteId)
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => ConservationRecommendation.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}
