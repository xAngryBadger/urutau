import 'package:flutter/material.dart';
import '../models/conflict_info.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final List<ConflictInfo> conflicts;
  final Function(ConflictInfo, ConflictResolution) onResolve;

  const ConflictResolutionDialog({
    super.key,
    required this.conflicts,
    required this.onResolve,
  });

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  int _currentIndex = 0;
  ConflictResolution _resolution = ConflictResolution.keepLocal;

  ConflictInfo get _currentConflict => widget.conflicts[_currentIndex];

  @override
  Widget build(BuildContext context) {
    if (widget.conflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    final conflict = _currentConflict;
    final isLast = _currentIndex == widget.conflicts.length - 1;
    // Cores do tema (antes laranja/grey[700]/blue[50]/orange[50] fixos).
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: cs.tertiary, size: 28),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Conflito Detectado', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parcela ${conflict.differingFields.length > 0 ? "com diferenças" : ""}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Os seguintes campos diferem entre o local e o servidor:',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ...conflict.differingFields.map((field) => _buildDiffRow(field, conflict, cs)),
              const Divider(height: 24),
              const Text('Como deseja resolver?'),
              const SizedBox(height: 12),
              RadioListTile<ConflictResolution>(
                title: const Text('Manter versão local'),
                subtitle: const Text('Seus dados prevalecem; sobrescreve o servidor no próximo sync'),
                value: ConflictResolution.keepLocal,
                groupValue: _resolution,
                onChanged: (v) => setState(() => _resolution = v!),
              ),
              RadioListTile<ConflictResolution>(
                title: const Text('Usar versão do servidor'),
                subtitle: const Text('Descarta suas alterações locais; pega os dados do servidor'),
                value: ConflictResolution.useServer,
                groupValue: _resolution,
                onChanged: (v) => setState(() => _resolution = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Adiar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onResolve(conflict, _resolution);
            if (isLast) {
              Navigator.pop(context);
            } else {
              setState(() {
                _currentIndex++;
                _resolution = ConflictResolution.keepLocal;
              });
            }
          },
          child: Text(isLast ? 'Confirmar tudo' : 'Próximo'),
        ),
      ],
    );
  }

  Widget _buildDiffRow(String field, ConflictInfo conflict, ColorScheme cs) {
    final localVal = conflict.localValues[field]?.toString() ?? '(vazio)';
    final serverVal = conflict.serverValues[field]?.toString() ?? '(vazio)';
    final label = _fieldLabel(field);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text('Local: $localVal', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text('Servidor: $serverVal', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fieldLabel(String field) {
    const labels = {
      'propriedade': 'Propriedade',
      'propUt': 'UT / Talhão',
      'idParcela': 'Número da Parcela',
      'areaHa': 'Área (ha)',
      'observacoes': 'Anotações',
      'synced': 'Sincronizado',
      'prontaParaSync': 'Pronta para Sync',
      'userId': 'Usuário',
      'createdAt': 'Criada em',
      'updatedAt': 'Atualizada em',
    };
    return labels[field] ?? field;
  }
}