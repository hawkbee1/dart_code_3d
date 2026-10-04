import 'package:bloc/bloc.dart';
import 'package:dart_code_3d/app/bloc_observer.dart';
import 'package:flutter_test/flutter_test.dart';

class _Secret {
  @override
  String toString() => 'THE-CONTENT-OF-A-USERS-FILE';
}

class _Counter extends Cubit<Object> {
  new() : super(0);

  void put(Object value) => emit(value);

  void fail(Object error) => addError(error, StackTrace.current);
}

void main() {
  group(AppBlocObserver, () {
    late List<String> messages;
    late List<Object?> errors;
    late _Counter bloc;

    setUp(() {
      messages = [];
      errors = [];
      Bloc.observer = AppBlocObserver(
        logger: (message, {error, stackTrace}) {
          messages.add(message);
          errors.add(error);
        },
      );
      // After the observer: a bloc keeps the one in place when it is made.
      bloc = _Counter();
    });

    tearDown(() {
      Bloc.observer = const AppBlocObserver();
      return bloc.close();
    });

    test('logs the types of a change, never the state', () {
      bloc.put(_Secret());

      expect(messages, ['_Counter: int → _Secret']);
      expect(messages.single, isNot(contains('CONTENT')));
    });

    test('logs the type of an error, not its message', () {
      bloc.fail(StateError('THE-CONTENT-OF-A-USERS-FILE'));

      expect(messages, ['_Counter failed']);
      expect(errors, [StateError]);
    });

    test('logs to the developer log by default', () {
      Bloc.observer = const AppBlocObserver();

      expect(() => bloc.put(1), returnsNormally);
    });
  });
}
