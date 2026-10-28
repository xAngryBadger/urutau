import 'dart:io' if (dart.library.html) 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

// >>> t14 S3: inicio
import 'package:crypto/crypto.dart';
import 'dart:convert';
// <<< t14 S3: fim

class ImageService {
  static const _uuid = Uuid();

  /// (S3 / RC-04) SHA-256 hex lowercase de um arquivo.
  ///
  /// NA ORIGEM: calculado no aparelho, antes de qualquer upload. Com a D-1
  /// aplicada (picker sem re-encodar), o arquivo guardado É o original —
  /// hash aqui é hash do bruto.
  ///
  /// Retorna null se o arquivo não existe — NÃO lança: o chamador decide.
  static Future<String?> sha256De(String path) async {
    if (kIsWeb) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('Erro ao calcular SHA-256 de $path: $e');
      return null;
    }
  }

  /// (S3) bytes + mime + hash do arquivo — o que o catálogo precisa gravar.
  static Future<({String? hash, int? bytes, String? mime})> metadadosDe(
      String path) async {
    if (kIsWeb) return (hash: null, bytes: null, mime: null);
    try {
      final file = File(path);
      if (!await file.exists()) return (hash: null, bytes: null, mime: null);
      final bytes = await file.readAsBytes();
      return (
        hash: sha256.convert(bytes).toString(),
        bytes: bytes.length,
        mime: 'image/jpeg',
      );
    } catch (e) {
      debugPrint('Erro ao ler metadados de $path: $e');
      return (hash: null, bytes: null, mime: null);
    }
  }
  // <<< t14 S3: fim

  /// Comprime uma imagem para reduzir tamanho no upload.
  /// Foto original ~5MB → comprimida ~500KB-1MB.
  static Future<File?> compressImage(File file, {int quality = 70}) async {
    if (kIsWeb) return null; // Web não suporta compressão local
    
    // Verifica espaço em disco antes de comprimir
    final freeGB = await StorageService.getFreeSpaceGB();
    if (StorageService.isCritical(freeGB)) {
      throw Exception(
          'Espaço em disco extremamente baixo (${freeGB.toStringAsFixed(2)} GB). '
          'Libere espaço antes de capturar fotos.');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final compressedDir = Directory(p.join(dir.path, 'compressed'));
      if (!compressedDir.existsSync()) {
        compressedDir.createSync(recursive: true);
      }

      final targetPath = p.join(
        compressedDir.path,
        '${_uuid.v4()}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1920,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao comprimir imagem: $e');
      return null;
    }
  }

  /// (S3) Comprime E devolve os metadados do resultado. Não substitui
  /// compressImage — os 2 chamadores de sync_service.dart continuam iguais.
  static Future<({String caminho, String? sha256, int? bytes})?>
      comprimirComMetadados(File file, {int quality = 70}) async {
    final result = await compressImage(file, quality: quality);
    if (result == null) return null;
    final meta = await metadadosDe(result.path);
    return (caminho: result.path, sha256: meta.hash, bytes: meta.bytes);
  }

  /// (S3 + D-1) Salva o ORIGINAL e devolve metadados dele — com a decisão do
  /// Badger o app não re-encoda mais; o original é a evidência.
  static Future<({String caminho, String? sha256, int? bytes})>
      salvarOriginalComMetadados(String photoPath) async {
    final salvo = await savePhotoLocally(photoPath);
    final meta = await metadadosDe(salvo.caminho);
    return (caminho: salvo.caminho, sha256: meta.hash, bytes: meta.bytes);
  }

  /// (S3) Salva a foto no diretório do app e devolve (caminho, sha256).
  /// ANTES devolvia só String — 3 chamadores: parcela_form_screen.dart:1100
  /// e :1109 (fallback) e planta_form_screen.dart (primário).
  static Future<({String caminho, String? sha256})> savePhotoLocally(
      String photoPath) async {
    if (kIsWeb) return (caminho: photoPath, sha256: null);
    try {
      final photo = File(photoPath);
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'fotos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName = '${_uuid.v4()}.jpg';
      final savedFile = await photo.copy(p.join(photosDir.path, fileName));
      return (caminho: savedFile.path, sha256: await sha256De(savedFile.path));
    } catch (e) {
      debugPrint('Erro ao salvar foto localmente: $e');
      return (caminho: photoPath, sha256: null);
    }
  }

  /// (D-1 H4) Remove uma foto SÓ com confirmação de estado.
  ///
  /// Regra dura: só apaga se o estado for `enviado_verificado` ou
  /// `comprimido_local`. Com `capturado`, RETORNA FALSE e não apaga — a UI
  /// explica a recusa; o operador pode insistir por um segundo caminho
  /// explícito, nunca por silêncio.
  ///
  /// [onLimpo] é chamado após a remoção para registrar o evento
  /// `arquivo_local_limpo` (auditoria) — não apaga sem rasto.
  static Future<bool> limparFotoConfirmada({
    required String path,
    required String arquivoEstado,
    Future<void> Function()? onLimpo,
  }) async {
    if (kIsWeb) return false;
    if (arquivoEstado != 'enviado_verificado' &&
        arquivoEstado != 'comprimido_local') {
      return false; // 'capturado' (ou desconhecido) nunca é apagado
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        await onLimpo?.call();
      }
      return true;
    } catch (e) {
      debugPrint('limparFotoConfirmada: falha ao remover $path: $e');
      return false;
    }
  }

  /// Remove um arquivo de foto local.
  static Future<void> deletePhoto(String path) async {
    if (kIsWeb) return; // Web: nada a deletar
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Erro ao deletar foto: $e');
    }
  }

  static Future<void> deletePhotos(List<String> paths) async {
    for (final path in paths) {
      await deletePhoto(path);
    }
  }

  static Future<Directory> getPhotosDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(p.join(dir.path, 'fotos'));
  }

  static Future<void> deletePhotosDir() async {
    if (kIsWeb) return;
    try {
      final photosDir = await getPhotosDir();
      if (photosDir.existsSync()) {
        await for (final entity in photosDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao limpar diretório de fotos: $e');
    }
  }

  /// Limpa fotos comprimidas após sincronização bem-sucedida.
  static Future<void> cleanCompressedPhotos() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final compressedDir = Directory(p.join(dir.path, 'compressed'));
      if (compressedDir.existsSync()) {
        await compressedDir.delete(recursive: true);
        compressedDir.createSync(recursive: true);
      }
    } catch (e) {
      debugPrint('Erro ao limpar fotos comprimidas: $e');
    }
  }

  /// Gera thumbnail 300px da foto para uso em grids/listas.
  static Future<File?> generateThumbnail(File sourceImage, {int width = 300}) async {
    if (kIsWeb) return null;
    try {
      final bytes = await sourceImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final decodedImage = frame.image;
      final thumbnailBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: width,
        minHeight: (width * decodedImage.height / decodedImage.width).round(),
        quality: 70,
      );
      
      if (thumbnailBytes == null) return null;
      
      final dir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory(p.join(dir.path, 'thumbnails'));
      if (!thumbDir.existsSync()) {
        thumbDir.createSync(recursive: true);
      }
      
      final thumbPath = p.join(thumbDir.path, 'thumb_${_uuid.v4()}.jpg');
      await File(thumbPath).writeAsBytes(thumbnailBytes);
      return File(thumbPath);
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return null;
    }
  }

  /// Widget de imagem cross-platform (File no mobile, Network no web).
  static Widget buildImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    int? cacheWidth,
  }) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (ctx, err, st) => const _BrokenImagePlaceholder(),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('Foto ausente: $path');
      return const _BrokenImagePlaceholder();
  }
    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      errorBuilder: (ctx, err, st) => const _BrokenImagePlaceholder(),
    );
  }
}

class _BrokenImagePlaceholder extends StatelessWidget {
  const _BrokenImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E0E0),
      child: const Center(
        child: Icon(IconData(0xe09a, fontFamily: 'MaterialIcons'), size: 40),
      ),
    );
  }
}
