import 'package:bloc_test/bloc_test.dart';
import 'package:dart_code_3d/viewer/viewer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

/// A viewer bloc test double.
class MockViewerBloc extends MockBloc<ViewerEvent, ViewerState>
    implements ViewerBloc;

/// A viewer bloc test double whose state is [state].
MockViewerBloc viewerBlocWith(ViewerState state) {
  final bloc = MockViewerBloc();
  when(() => bloc.state).thenReturn(state);
  return bloc;
}

/// [ViewerView] over [bloc], with a blank 3D area (no GPU in widget tests).
Widget viewerViewWith(ViewerBloc bloc) => BlocProvider.value(
  value: bloc,
  child: ViewerView(initialize: () async {}, sceneBuilder: blankScene),
);

/// A blank 3D area that names what it would draw.
Widget blankScene(
  BuildContext context,
  CodeWorld world,
  PerspectiveCamera camera,
) => SizedBox.expand(key: ValueKey('scene ${world.instanceCount}'));
