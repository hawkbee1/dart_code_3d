import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:code_map_repository/code_map_repository.dart';
import 'package:dart_code_3d/analysis/cubit/source_form_cubit.dart';
import 'package:dart_code_3d/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFileDialogs extends Mock implements FileDialogs;

void main() {
  group(SourceFormCubit, () {
    late FileDialogs dialogs;

    const all = [SourceKind.git, SourceKind.folder, SourceKind.zip];

    setUp(() => dialogs = _MockFileDialogs());

    SourceFormCubit cubit({List<SourceKind> kinds = all}) =>
        SourceFormCubit(dialogs: dialogs, kinds: kinds);

    test('starts on the first kind it offers', () {
      expect(cubit().state.kind, SourceKind.git);
      expect(cubit(kinds: const [SourceKind.zip]).state.kind, SourceKind.zip);
    });

    test('needs at least one kind', () {
      expect(
        () => SourceFormCubit(dialogs: dialogs, kinds: const []),
        throwsAssertionError,
      );
    });

    group('kindChanged', () {
      blocTest<SourceFormCubit, SourceFormState>(
        'selects a kind that is offered',
        build: cubit,
        act: (cubit) => cubit.kindChanged(SourceKind.zip),
        expect: () => [
          isA<SourceFormState>().having((s) => s.kind, 'kind', SourceKind.zip),
        ],
      );

      blocTest<SourceFormCubit, SourceFormState>(
        'ignores a kind that is not offered',
        build: () => cubit(kinds: const [SourceKind.git, SourceKind.zip]),
        act: (cubit) => cubit.kindChanged(SourceKind.folder),
        expect: () => <SourceFormState>[],
      );
    });

    group('git', () {
      test('has no source and no error before anything is typed', () {
        final state = cubit().state;

        expect(state.source, isNull);
        expect(state.urlInvalid, isFalse);
      });

      test('builds a source from a valid URL', () {
        final subject = cubit()
          ..urlChanged(' https://github.com/TalaoDAO/AltMe ');

        expect(
          subject.state.source,
          const GitRepositorySource('https://github.com/TalaoDAO/AltMe'),
        );
        expect(subject.state.urlInvalid, isFalse);
      });

      test('adds the branch or tag when given', () {
        final subject = cubit()
          ..urlChanged('https://github.com/bdero/flutter_scene')
          ..refChanged(' flutter_scene-0.23.0 ');

        expect(
          subject.state.source,
          const GitRepositorySource(
            'https://github.com/bdero/flutter_scene',
            ref: 'flutter_scene-0.23.0',
          ),
        );
      });

      test('accepts a repository typed without a scheme', () {
        expect(
          (cubit()..urlChanged('github.com/o/r')).state.source,
          const GitRepositorySource('github.com/o/r'),
        );
      });

      test('flags a URL that is not a GitHub or GitLab repository', () {
        final subject = cubit()..urlChanged('https://example.com/o/r');

        expect(subject.state.urlInvalid, isTrue);
        expect(subject.state.source, isNull);
      });

      test('does not flag an invalid URL on another kind', () {
        final subject = cubit()
          ..urlChanged('nope')
          ..kindChanged(SourceKind.zip);

        expect(subject.state.urlInvalid, isFalse);
      });
    });

    group('folderPicked', () {
      blocTest<SourceFormCubit, SourceFormState>(
        'keeps the chosen folder as the source',
        setUp: () => when(dialogs.pickFolder).thenAnswer((_) async => '/a/b'),
        build: cubit,
        act: (cubit) async {
          cubit.kindChanged(SourceKind.folder);
          await cubit.folderPicked();
        },
        verify: (cubit) {
          expect(cubit.state.folderPath, '/a/b');
          expect(cubit.state.source, const LocalFolderSource('/a/b'));
        },
      );

      blocTest<SourceFormCubit, SourceFormState>(
        'keeps the previous folder when the dialog is cancelled',
        setUp: () {
          when(dialogs.pickFolder).thenAnswer((_) async => '/a/b');
        },
        build: cubit,
        act: (cubit) async {
          await cubit.folderPicked();
          when(dialogs.pickFolder).thenAnswer((_) async => null);
          await cubit.folderPicked();
        },
        verify: (cubit) => expect(cubit.state.folderPath, '/a/b'),
      );

      test('has no source before a folder is chosen', () {
        expect((cubit()..kindChanged(SourceKind.folder)).state.source, isNull);
      });
    });

    group('zipPicked', () {
      final zip = PickedFile(name: 'app.zip', bytes: Uint8List(3));

      blocTest<SourceFormCubit, SourceFormState>(
        'keeps the chosen file as the source',
        setUp: () => when(dialogs.pickZip).thenAnswer((_) async => zip),
        build: cubit,
        act: (cubit) async {
          cubit.kindChanged(SourceKind.zip);
          await cubit.zipPicked();
        },
        verify: (cubit) => expect(
          cubit.state.source,
          ZipBytesSource(fileName: 'app.zip', bytes: zip.bytes),
        ),
      );

      blocTest<SourceFormCubit, SourceFormState>(
        'keeps the previous file when the dialog is cancelled',
        setUp: () => when(dialogs.pickZip).thenAnswer((_) async => zip),
        build: cubit,
        act: (cubit) async {
          await cubit.zipPicked();
          when(dialogs.pickZip).thenAnswer((_) async => null);
          await cubit.zipPicked();
        },
        verify: (cubit) => expect(cubit.state.zip, zip),
      );

      test('has no source before a file is chosen', () {
        expect((cubit()..kindChanged(SourceKind.zip)).state.source, isNull);
      });
    });
  });
}
