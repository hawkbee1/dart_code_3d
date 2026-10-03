import 'package:dart_code_3d/app/app.dart';
import 'package:dart_code_3d/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => buildApp(AppFlavor.production));
}
