import 'package:dart_code_3d/analysis/analysis.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/home/home.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MockGoRouterState extends Mock implements GoRouterState;

void main() {
  group('routes', () {
    late GoRouter router;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      router = GoRouter(routes: $appRoutes);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        App(
          settingsRepository: SettingsRepository(
            preferences: SharedPreferencesAsync(),
          ),
          router: router,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final (location, page) in [
      ('/', HomePage),
      ('/settings', SettingsPage),
      ('/new-analysis', NewAnalysisPage),
    ]) {
      testWidgets('$location shows $page', (tester) async {
        await pump(tester);

        router.go(location);
        await tester.pump();
        await tester.pump();

        expect(find.byType(page), findsOneWidget);
      });
    }

    testWidgets('sub-routes get a back button to the home screen', (
      tester,
    ) async {
      await pump(tester);
      router.go(const SettingsRoute().location);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(const HomeRoute().location, '/');
      expect(const NewAnalysisRoute().location, '/new-analysis');
      expect(const ViewerRoute().location, '/viewer');
    });

    testWidgets('/viewer builds the $ViewerPage', (tester) async {
      await pump(tester);
      final context = tester.element(find.byType(HomePage));

      expect(
        const ViewerRoute().build(context, _MockGoRouterState()),
        isA<ViewerPage>(),
      );
    });
  });
}
