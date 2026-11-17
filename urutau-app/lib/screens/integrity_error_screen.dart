import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database.dart';
import '../services/backup_service.dart';

class IntegrityErrorScreen extends StatelessWidget {
  const IntegrityErrorScreen({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 72, color: theme.colorScheme.tertiary),
            const SizedBox(height: 24),
            Text(
              'Problema detectado no banco de dados',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _restoreFromBackup(context),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar de backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _resetAppData(context),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Resetar dados do app'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    await BackupService.prepareRestore(filePath);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup preparado. O app será reiniciado para aplicar a restauração.'),
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    }
  }

  Future<void> _resetAppData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reset'),
        content: const Text(
          'Todos os dados (parcelas, plantas, fotos) serão apagados permanentemente. '
          'Apenas a conta de administrador será mantida. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final db = context.read<AppDatabase>();
    await db.limparTodosDadosExcetoAdmin();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados resetados. O app será reiniciado.'),
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    }
  }
}
