import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:urutau/services/sync_service.dart';

/// Regressão do retry em erros de autenticação.
///
/// PROBLEMA MEDIDO: o `SyncService._withRetry` repetia QUALQUER erro,
/// incluindo a recusa de credenciais do PocketBase. Com senha errada, o
/// login ficava 2 s + 4 s + 8 s = **14 segundos** de espera antes de
/// devolver o erro ao utilizador. A interface parecia pendurada.
///
/// O `_withRetry` é agora pelo que determinístico não é repetido:
/// `ClientException` com `statusCode` 4xx (400 credenciais inválidas, 401
/// token expirado, 403 sem permissão, 404 recurso inexistente).
///
/// Erros transitórios (sem resposta → `statusCode` 0, ou 5xx do servidor)
/// CONTINUAM a ser repetidos — é o comportamento certo para rede instável.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('_isNonRetryableError', () {
    test('400 (credenciais inválidas) NÃO é repetido', () {
      final e = ClientException(statusCode: 400, response: {
        'message': 'Failed to authenticate.',
      });
      expect(SyncService.isNonRetryableErrorForTest(e), isTrue,
          reason: 'senha errada tem de falhar de imediato, não 14 s depois');
    });

    test('401 (token expirado) NÃO é repetido', () {
      expect(
        SyncService.isNonRetryableErrorForTest(
            ClientException(statusCode: 401, response: {'message': 'unauthorized'})),
        isTrue,
      );
    });

    test('403 (sem permissão) NÃO é repetido', () {
      expect(
        SyncService.isNonRetryableErrorForTest(
            ClientException(statusCode: 403, response: {'message': 'forbidden'})),
        isTrue,
      );
    });

    test('404 (recurso inexistente) NÃO é repetido', () {
      expect(
        SyncService.isNonRetryableErrorForTest(
            ClientException(statusCode: 404, response: {'message': 'not found'})),
        isTrue,
      );
    });

    test('sem resposta (statusCode 0) É repetido — erro transitório', () {
      expect(
        SyncService.isNonRetryableErrorForTest(ClientException(statusCode: 0)),
        isFalse,
        reason: 'sem resposta HTTP é rede caída: o retry é o comportamento certo',
      );
    });

    test('500/503 (servidor) É repetido — erro transitório', () {
      expect(
        SyncService.isNonRetryableErrorForTest(
            ClientException(statusCode: 500, response: {'message': 'internal'})),
        isFalse,
      );
      expect(
        SyncService.isNonRetryableErrorForTest(
            ClientException(statusCode: 503, response: {'message': 'unavailable'})),
        isFalse,
      );
    });

    test('exceção não-ClientException (timeout/socket) É repetida', () {
      expect(
        SyncService.isNonRetryableErrorForTest(
            Exception('Requisição expirou após 30s')),
        isFalse,
      );
      expect(
        SyncService.isNonRetryableErrorForTest(
            StateError('ligação recusada')),
        isFalse,
      );
    });
  });
}
