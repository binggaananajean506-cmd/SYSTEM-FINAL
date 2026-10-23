import 'package:cloud_functions/cloud_functions.dart';
import 'package:esugid/features/bayanihan_messages/services/bayanihan_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.error);
  final FirebaseFunctionsException error;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => _Callable(error);
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.error);
  final FirebaseFunctionsException error;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async => throw error;
}

void main() {
  test('callable internal errors never become domain messages', () async {
    final service = BayanihanMessagingService(functions: _Functions(
      FirebaseFunctionsException(code: 'internal', message: 'private server path'),
    ));
    await expectLater(service.acceptOffer('conversation'), throwsA(isA<BayanihanMessagingException>().having(
      (error) => error.message, 'message', 'The Bayanihan request could not be updated. Try again.',
    )));
  });
  test('known offer validation remains actionable', () async {
    final service = BayanihanMessagingService(functions: _Functions(
      FirebaseFunctionsException(code: 'failed-precondition', message: 'This offer has already been reviewed.'),
    ));
    await expectLater(service.acceptOffer('conversation'), throwsA(isA<BayanihanMessagingException>().having(
      (error) => error.message, 'message', 'This offer has already been reviewed.',
    )));
  });
  test('known required-field validation remains actionable', () async {
    final service = BayanihanMessagingService(functions: _Functions(
      FirebaseFunctionsException(code: 'invalid-argument', message: 'Initial message is required.'),
    ));
    await expectLater(service.acceptOffer('conversation'), throwsA(isA<BayanihanMessagingException>().having(
      (error) => error.message, 'message', 'Initial message is required.',
    )));
  });
}
