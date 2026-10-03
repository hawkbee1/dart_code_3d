import 'package:bloc_test/bloc_test.dart';
import 'package:dart_code_3d/settings/settings.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings_repository/settings_repository.dart';

import 'settings.dart';

/// A viewer bloc test double.
class MockViewerBloc extends MockBloc<ViewerEvent, ViewerState>
    implements ViewerBloc;

/// A viewer bloc test double whose state is [state].
MockViewerBloc viewerBlocWith(ViewerState state) {
  final bloc = MockViewerBloc();
  when(() => bloc.state).thenReturn(state);
  return bloc;
}

/// [ViewerView] over [bloc], with a blank 3D area (no GPU in widget tests)
/// and the [touchControls] setting.
Widget viewerViewWith(
  ViewerBloc bloc, {
  TouchControlsMode touchControls = TouchControlsMode.never,
  CodeWorldSceneBuilder sceneBuilder = blankScene,
}) => MultiBlocProvider(
  providers: [
    BlocProvider<ViewerBloc>.value(value: bloc),
    BlocProvider<SettingsBloc>.value(
      value: settingsBlocWith(
        SettingsState(
          status: SettingsStatus.ready,
          touchControls: touchControls,
        ),
      ),
    ),
  ],
  child: ViewerView(initialize: () async {}, sceneBuilder: sceneBuilder),
);

/// A blank 3D area that names what it would draw.
Widget blankScene(
  BuildContext context,
  CodeWorld world,
  FlyNavigator navigator,
) => SizedBox.expand(key: ValueKey('scene ${world.instanceCount}'));
