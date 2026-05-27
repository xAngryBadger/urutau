import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Serviço de hashing de senhas usando SHA-256 com salt aleatório.
/// Formato armazenado: "salt:hash" (ambos em hex).
class PasswordService {
  static const _saltLength = 32;
  static const _separator = ':';

  /// Gera um salt aleatório criptograficamente seguro.
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hasheia uma senha plaintext. Retorna "salt:hash".
  static String hashPassword(String plaintext) {
    final salt = _generateSalt();
    final hash = _computeHash(plaintext, salt);
    return '$salt$_separator$hash';
  }

  /// Verifica se a senha plaintext corresponde ao hash armazenado.
  static bool verifyPassword(String plaintext, String storedHash) {
    if (!storedHash.contains(_separator)) return false;
    final parts = storedHash.split(_separator);
    if (parts.length != 2) return false;
    final salt = parts[0];
    final expectedHash = parts[1];
    final actualHash = _computeHash(plaintext, salt);
    return actualHash == expectedHash;
  }

  /// Verifica se uma string armazenada é um hash (formato "salt:hash")
  /// ou plaintext legado.
  static bool isHashed(String storedValue) {
    if (!storedValue.contains(_separator)) return false;
    final parts = storedValue.split(_separator);
    if (parts.length != 2) return false;
    // Salt deve ter exatamente _saltLength * 2 caracteres hex
    if (parts[0].length != _saltLength * 2) return false;
    // Hash SHA-256 tem 64 caracteres hex
    if (parts[1].length != 64) return false;
    return true;
  }

  /// Computa SHA-256 de (salt + plaintext).
  static String _computeHash(String plaintext, String salt) {
    final bytes = utf8.encode('$salt$plaintext');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
