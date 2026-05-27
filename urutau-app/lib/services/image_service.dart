import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ImageService {
  static const _uuid = Uuid();

  /// Comprime uma imagem para reduzir tamanho no upload.
  /// Foto original ~5MB → comprimida ~500KB-1MB.
  static Future<File?> compressImage(File file, {int quality = 70}) async {
    if (kIsWeb) return null; // Web não suporta compressão local
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

  /// Salva uma foto no diretório do app e retorna o caminho local.
  /// No web retorna o path original (blob URL).
  static Future<String> savePhotoLocally(String photoPath) async {
    if (kIsWeb) return photoPath; // Web: blob URL direto
    try {
      final photo = File(photoPath);
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'fotos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName = '${_uuid.v4()}.jpg';
      final savedFile = await photo.copy(p.join(photosDir.path, fileName));
      return savedFile.path;
    } catch (e) {
      debugPrint('Erro ao salvar foto localmente: $e');
      return photoPath;
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
