import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  const anonKey = 'publishable-test-key';

  test('missing Supabase configuration fails closed', () {
    const config = SupabaseConfig(url: '', anonKey: '');
    expect(config.validate, throwsStateError);
  });

  test('production rejects Smart Meters staging project', () {
    const config = SupabaseConfig(
      url: 'https://iqcxgtpcfhoapnklxdyl.supabase.co',
      anonKey: anonKey,
    );
    expect(
      () => config.validate(env: AppEnv.production),
      throwsStateError,
    );
  });

  test('production rejects Daily Checklists project', () {
    const config = SupabaseConfig(
      url: 'https://xhdpyiklhouqwrtdwztn.supabase.co',
      anonKey: anonKey,
    );
    expect(
      () => config.validate(env: AppEnv.production),
      throwsStateError,
    );
  });

  test('staging accepts the verified Smart Meters staging project', () {
    const config = SupabaseConfig(
      url: 'https://iqcxgtpcfhoapnklxdyl.supabase.co',
      anonKey: anonKey,
    );
    expect(() => config.validate(env: AppEnv.staging), returnsNormally);
  });

  test('production accepts a distinct configured Production project', () {
    const config = SupabaseConfig(
      url: 'https://production-project.supabase.co',
      anonKey: anonKey,
    );
    expect(() => config.validate(env: AppEnv.production), returnsNormally);
  });
}
