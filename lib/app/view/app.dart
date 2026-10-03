import 'package:dart_code_3d/l10n/l10n.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:material_ui/material_ui.dart';

class App extends StatelessWidget {
  const new({super.key, this.home = const ViewerPage()});

  /// The first screen. Injectable so widget tests can avoid the GPU.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}
