import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/main.dart'
    show kConvidadoEmail, semearConvidadoSeNecessario;

/// Perfis de demonstração offline: primeiro arranque sem conta nenhuma deve
/// semear um utilizador convidado local, sem precisar de servidor nem de rede.
///
/// Regra de salvaguarda coberta aqui: se já existe conta, NÃO semeia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // O semeado grava a sessão em SharedPreferences; em teste unitário o plugin
  // de plataforma não existe, por isso injeta um store em memória.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('semear convidado: banco vazio ganha exatamente 1 convidado local',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final antes = await db.getAllUsuarios();
      expect(antes, isEmpty, reason: 'banco novo deve começar sem usuários');

      await semearConvidadoSeNecessario(db);

      final depois = await db.getAllUsuarios();
      expect(depois, hasLength(1));
      expect(depois.first.email, kConvidadoEmail);
      expect(depois.first.nome, 'Convidado');
      expect(depois.first.isAdmin, isFalse,
          reason: 'convidado não deve ter acesso admin/MRV');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_user_uuid'), depois.first.uuid,
          reason: 'sessão gravada: o splash cai em /home sem login');
    } finally {
      await db.close();
    }
  });

  test('semear convidado: banco com conta real NÃO é tocado', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await db.insertUsuario(UsuariosCompanion.insert(
        uuid: 'uuid-real-1',
        nome: 'Lucas Rigamonte',
        email: 'lucas@campo.local',
        senha: 'hash-qualquer',
        isAdmin: const Value(false),
      ));

      await semearConvidadoSeNecessario(db);

      final users = await db.getAllUsuarios();
      expect(users, hasLength(1));
      expect(users.first.email, 'lucas@campo.local');
      expect(users.any((u) => u.email == kConvidadoEmail), isFalse);
    } finally {
      await db.close();
    }
  });
}
