import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/bootstrap.dart';

/// A local `.dc3d` to open at startup, for performance work:
/// `--dart-define=DC3D_OPEN=<path>` (native platforms only).
const _openAtStartup = String.fromEnvironment('DC3D_OPEN');

Future<void> main() async {
  await bootstrap(
    () => buildApp(
      AppFlavor.development,
      initialLocation: _openAtStartup.isEmpty
          ? '/'
          : const ViewerRoute(file: _openAtStartup).location,
    ),
  );
}
