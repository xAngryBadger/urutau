import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstração para armazenamento seguro de credenciais.
/// Usa FlutterSecureStorage em plataformas nativas (Android/iOS/desktop)
/// e SharedPreferences com aviso em web (onde não há keystore nativo).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const keyCurrentPassword = 'current_user_password';
  static const keyAuthToken = 'auth_token';
  static const keyIsAdmin = 'current_user_is_admin';

  /// Armazena um valor de forma segura.
  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      // ⚠️ SECURITY: Web não tem keystore seguro — SharedPreferences é visível
      // no localStorage do navegador. NÃO armazene dados altamente sensíveis na web.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Lê um valor armazenado de forma segura.
  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage.read(key: key);
    }
  }

  /// Remove um valor armazenado.
  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  /// Remove todas as credenciais armazenadas.
  static Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyCurrentPassword);
      await prefs.remove(keyAuthToken);
      await prefs.remove(keyIsAdmin);
    } else {
      await _storage.deleteAll();
    }
  }

  /// Migra dados sensíveis de SharedPreferences para SecureStorage.
  /// Chamado uma vez na inicialização para migrar dados legados.
  static Future<void> migrateFromSharedPreferences() async {
    if (kIsWeb) return; // Web continua usando SharedPreferences

    final prefs = await SharedPreferences.getInstance();
    
    // Migra senha
    final password = prefs.getString('current_user_password');
    if (password != null && password.isNotEmpty) {
      await _storage.write(key: keyCurrentPassword, value: password);
      await prefs.remove('current_user_password');
    }

    // Migra auth token
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: keyAuthToken, value: token);
      await prefs.remove('auth_token');
    }

    // Migra isAdmin flag
    final isAdmin = prefs.getBool('current_user_is_admin');
    if (isAdmin != null) {
      await _storage.write(key: keyIsAdmin, value: isAdmin.toString());
      await prefs.remove('current_user_is_admin');
    }
  }
}
