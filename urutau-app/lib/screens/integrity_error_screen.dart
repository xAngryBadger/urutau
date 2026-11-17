import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database.dart';
import '../services/backup_service.dart';

class IntegrityErrorScreen extends StatefulWidget {
  const IntegrityErrorScreen({super.key, required this.error});

  final String error;

  @override
  State<IntegrityErrorScreen> createState() => _IntegrityErrorScreenState();
}

class _IntegrityErrorScreenState extends State<IntegrityErrorScreen> {
  bool _isRestoring = false;
  bool _isResetting = false;
  String? _restoreError;
  String? _resetError;

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
            const Icon(Icons.warning_amber_rounded,
                size: 72, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              'Problema detectado no banco de dados',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.error,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            if (_restoreError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _restoreError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_resetError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resetError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isRestoring || _isResetting ? null : () => _restoreFromBackup(context),
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.restore),
              label: Text(_isRestoring ? 'Restaurando...' : 'Restaurar de backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isRestoring || _isResetting ? null : () => _resetAppData(context),
              icon: _isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(_isResetting ? 'Resetando...' : 'Resetar dados do app'),
            ),
            if (_restoreError != null || _resetError != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() {
                  _restoreError = null;
                  _resetError = null;
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('Limpar erro e tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    setState(() {
      _isRestoring = true;
      _restoreError = null;
    });

    try {
      final result = await FilePicker.pickFile(
        type: FileType.any,
      );
      if (result == null || result.path == null) {
        setState(() => _isRestoring = false);
        return;
      }

      final filePath = result.path!;
      await BackupService.prepareRestore(filePath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup preparado. O app será reiniciado para aplicar a restauração.'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        exit(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _restoreError = 'Erro ao restaurar: $e';
        });
      }
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

    setState(() {
      _isResetting = true;
      _resetError = null;
    });

    try {
      final db = context.read<AppDatabase>();
      await db.limparTodosDadosExcetoAdmin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados resetados. O app será reiniciado.'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        exit(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResetting = false;
          _resetError = 'Erro ao resetar: $e';
        });
      }
    }
  }
}
