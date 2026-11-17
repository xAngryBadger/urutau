import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/widgets/primitives.dart';
import 'golden_test_utils.dart';

void main() {
  group('UrutauButton Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_button_primary',
      builder: (config) => UrutauButton.primary(
        onPressed: () {},
        label: 'Primary Button',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_secondary',
      builder: (config) => UrutauButton.secondary(
        onPressed: () {},
        label: 'Secondary Button',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_outline',
      builder: (config) => UrutauButton.outline(
        onPressed: () {},
        label: 'Outline Button',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_text',
      builder: (config) => UrutauButton.text(
        onPressed: () {},
        label: 'Text Button',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_destructive',
      builder: (config) => UrutauButton.destructive(
        onPressed: () {},
        label: 'Delete',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_success',
      builder: (config) => UrutauButton.success(
        onPressed: () {},
        label: 'Save',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_warning',
      builder: (config) => UrutauButton.warning(
        onPressed: () {},
        label: 'Warning',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_info',
      builder: (config) => UrutauButton.info(
        onPressed: () {},
        label: 'Info',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_with_icon',
      builder: (config) => UrutauButton.primary(
        onPressed: () {},
        label: 'With Icon',
        icon: const Icon(Icons.add),
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_loading',
      builder: (config) => UrutauButton.primary(
        onPressed: null,
        label: 'Loading',
        isLoading: true,
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_full_width',
      builder: (config) => UrutauButton.primary(
        onPressed: () {},
        label: 'Full Width',
        isFullWidth: true,
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_disabled',
      builder: (config) => UrutauButton.primary(
        onPressed: null,
        label: 'Disabled',
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_small',
      builder: (config) => UrutauButton.primary(
        onPressed: () {},
        label: 'Small',
        size: UrutauButtonSize.small,
      ),
    );

    runGoldenTests(
      testName: 'urutau_button_large',
      builder: (config) => UrutauButton.primary(
        onPressed: () {},
        label: 'Large',
        size: UrutauButtonSize.large,
      ),
    );
  });

  group('UrutauField Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_field_default',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Email',
          hint: 'Digite seu email',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_with_helper',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Senha',
          hint: 'Digite sua senha',
          helperText: 'Mínimo 8 caracteres',
          obscureText: true,
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_with_error',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Email',
          hint: 'Digite seu email',
          errorText: 'Email inválido',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_with_prefix_icon',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Buscar',
          hint: 'Buscar...',
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_multiline',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Observações',
          hint: 'Digite suas observações',
          maxLines: 4,
          minLines: 2,
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_disabled',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Campo desabilitado',
          hint: 'Não editável',
          enabled: false,
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_field_readonly',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauField(
          label: 'Somente leitura',
          initialValue: 'Valor fixo',
          readOnly: true,
        ),
      ),
    );
  });

  group('UrutauCard Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_card_elevated',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Título do Card', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Conteúdo do card elevado com sombra'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_filled',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard(
          variant: UrutauCardVariant.filled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Preenchido', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Card com fundo preenchido sem elevação'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_outlined',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard(
          variant: UrutauCardVariant.outlined,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card com Borda', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Card com borda visível'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_tappable',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard.tappable(
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Tocável', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Toque para interagir'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_selectable_selected',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard.selectable(
          selected: true,
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Selecionado', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Estado selecionado com borda primária'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_selectable_unselected',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard.selectable(
          selected: false,
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Não Selecionado', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Estado normal'),
            ],
          ),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_header',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard.header(
          child: Text('Cabeçalho da Seção', style: config.theme.textTheme.titleLarge),
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_card_section',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauCard.section(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seção 1', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Conteúdo da seção'),
              const SizedBox(height: 16),
              Text('Seção 2', style: config.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Mais conteúdo'),
            ],
          ),
        ),
      ),
    );
  });

  group('UrutauStatusBanner Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_status_banner_success',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.success(
          message: 'Operação realizada com sucesso!',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_warning',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.warning(
          message: 'Atenção: espaço em disco baixo',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_danger',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.danger(
          message: 'Erro ao salvar os dados',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_info',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.info(
          message: 'Sincronização agendada para amanhã',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_neutral',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.neutral(
          message: 'Nenhuma atualização disponível',
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_sync',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.sync(
          message: 'Sincronizando dados...',
          syncState: SyncState.syncing,
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_with_action',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.success(
          message: 'Backup concluído',
          actionLabel: 'Ver detalhes',
          onActionPressed: () {},
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_dismissible',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.info(
          message: 'Nova versão disponível',
          dismissible: true,
          onDismissed: () {},
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_compact',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.warning(
          message: 'Aviso compacto',
          compact: true,
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_status_banner_with_title',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauStatusBanner.success(
          title: 'Sucesso!',
          message: 'Todos os dados foram salvos corretamente.',
        ),
      ),
    );
  });

  group('UrutauEmptyState Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_empty_state_search',
      builder: (config) => UrutauEmptyState.search(
        title: 'Nenhum resultado',
        message: 'Tente buscar com outros termos.',
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_no_data',
      builder: (config) => UrutauEmptyState.noData(
        title: 'Sem dados',
        message: 'Ainda não há informações.',
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_offline',
      builder: (config) => UrutauEmptyState.offline(
        title: 'Offline',
        message: 'Verifique sua conexão.',
        actionLabel: 'Tentar novamente',
        onActionPressed: () {},
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_error',
      builder: (config) => UrutauEmptyState.error(
        title: 'Erro',
        message: 'Não foi possível carregar.',
        actionLabel: 'Recarregar',
        onActionPressed: () {},
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_no_permission',
      builder: (config) => UrutauEmptyState.noPermission(
        title: 'Acesso negado',
        message: 'Você não tem permissão.',
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_loading',
      builder: (config) => UrutauEmptyState.loading(
        title: 'Carregando',
        message: 'Aguarde...',
      ),
    );

    runGoldenTests(
      testName: 'urutau_empty_state_sliver',
      builder: (config) => CustomScrollView(
        slivers: [
          UrutauSliverEmptyState.search(
            title: 'Sem resultados',
            message: 'Tente outra busca.',
          ),
        ],
      ),
    );
  });

  group('UrutauFilterChip Golden Tests', () {
    runGoldenTests(
      testName: 'urutau_filter_chip_default',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: [
            UrutauFilterChip.defaultChip(
              label: 'Filtro 1',
              selected: false,
              onSelected: (_) {},
            ),
            UrutauFilterChip.defaultChip(
              label: 'Filtro 2',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.defaultChip(
              label: 'Filtro 3',
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_filter_chip_variants',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: [
            UrutauFilterChip.primary(
              label: 'Primário',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.success(
              label: 'Sucesso',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.warning(
              label: 'Aviso',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.danger(
              label: 'Perigo',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.info(
              label: 'Info',
              selected: true,
              onSelected: (_) {},
            ),
            UrutauFilterChip.neutral(
              label: 'Neutro',
              selected: true,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_filter_chip_with_icons',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: [
            UrutauFilterChip.primary(
              label: 'Com ícone',
              selected: true,
              onSelected: (_) {},
              icon: const Icon(Icons.star, size: 16),
            ),
            UrutauFilterChip.success(
              label: 'Verificado',
              selected: true,
              onSelected: (_) {},
              icon: const Icon(Icons.check, size: 16),
            ),
          ],
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_filter_chip_group_single',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauFilterChipGroup(
          chips: [
            UrutauFilterChipData(value: '1', label: 'Opção 1'),
            UrutauFilterChipData(value: '2', label: 'Opção 2'),
            UrutauFilterChipData(value: '3', label: 'Opção 3'),
          ],
          selectionMode: UrutauFilterChipSelectionMode.single,
          initialSelection: {'1'},
        ),
      ),
    );

    runGoldenTests(
      testName: 'urutau_filter_chip_group_multiple',
      builder: (config) => Padding(
        padding: const EdgeInsets.all(16),
        child: UrutauFilterChipGroup(
          chips: [
            UrutauFilterChipData(value: 'a', label: 'Filtro A', variant: UrutauFilterChipVariant.primary),
            UrutauFilterChipData(value: 'b', label: 'Filtro B', variant: UrutauFilterChipVariant.success),
            UrutauFilterChipData(value: 'c', label: 'Filtro C', variant: UrutauFilterChipVariant.warning),
          ],
          selectionMode: UrutauFilterChipSelectionMode.multiple,
          initialSelection: {'a', 'c'},
        ),
      ),
    );
  });
}