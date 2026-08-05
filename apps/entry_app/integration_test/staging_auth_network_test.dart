import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staging supabase auth reaches network', (tester) async {
    const config = SupabaseConfig.fromEnvironment;
    config.validate();

    await bootstrapSupabase(config: config);

    const email = String.fromEnvironment('STAGING_TEST_EMAIL');
    const password = String.fromEnvironment('STAGING_TEST_PASSWORD');
    if (email.isEmpty || password.isEmpty) {
      fail('STAGING_TEST_EMAIL and STAGING_TEST_PASSWORD dart-defines are required');
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final auth = container.read(authRepositoryProvider);
    await auth.signInWithEmail(email: email, password: password);

    expect(auth.currentSession, isNotNull);
    expect(auth.currentUser?.email, email);
  });
}
