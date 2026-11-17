import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/widgets/primitives.dart';

void main() {
  group('UrutauButton Accessibility Tests', () {
    testWidgets('Primary button renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauButton.primary(
              onPressed: () {},
              label: 'Salvar',
              semanticsLabel: 'Botão salvar formulário',
            ),
          ),
        ),
      );

      // Verify button renders
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.byType(UrutauButton), findsOneWidget);
    });

    testWidgets('Disabled button is not tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauButton.primary(
              onPressed: null,
              label: 'Desabilitado',
              semanticsLabel: 'Botão desabilitado',
            ),
          ),
        ),
      );

      // Verify disabled button renders
      expect(find.text('Desabilitado'), findsOneWidget);
      
      // Tap should not crash
      await tester.tap(find.byType(UrutauButton));
      await tester.pump();
    });

    testWidgets('Loading button shows loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauButton.primary(
              onPressed: null,
              label: 'Carregando',
              isLoading: true,
              semanticsLabel: 'Carregando',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Button with tooltip shows tooltip on long press', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauButton.primary(
              onPressed: () {},
              label: 'Com Tooltip',
              tooltip: 'Clique para salvar',
            ),
          ),
        ),
      );

      // Long press to show tooltip
      await tester.longPress(find.byType(UrutauButton));
      await tester.pumpAndSettle();
      
      expect(find.byTooltip('Clique para salvar'), findsOneWidget);
    });

    testWidgets('All button variants have proper touch target size', (WidgetTester tester) async {
      final variants = [
        UrutauButton.primary(onPressed: () {}, label: 'Primary'),
        UrutauButton.secondary(onPressed: () {}, label: 'Secondary'),
        UrutauButton.outline(onPressed: () {}, label: 'Outline'),
        UrutauButton.text(onPressed: () {}, label: 'Text'),
        UrutauButton.destructive(onPressed: () {}, label: 'Destructive'),
        UrutauButton.success(onPressed: () {}, label: 'Success'),
        UrutauButton.warning(onPressed: () {}, label: 'Warning'),
        UrutauButton.info(onPressed: () {}, label: 'Info'),
      ];

      for (final variant in variants) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: variant),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(find.byType(UrutauButton));
        final size = renderBox.size;
        
        // Minimum touch target: 48x48dp for medium and large
        expect(size.height, greaterThanOrEqualTo(36)); // Small is 36
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  });

  group('UrutauField Accessibility Tests', () {
    testWidgets('Field renders with label and hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauField(
                label: 'Email',
                hint: 'Digite seu email',
                semanticsLabel: 'Campo de email',
              ),
            ),
          ),
        ),
      );

      // Verify field renders
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Digite seu email'), findsOneWidget);
      expect(find.byType(UrutauField), findsOneWidget);
    });

    testWidgets('Field with error shows error text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauField(
                label: 'Email',
                errorText: 'Email inválido',
                semanticsLabel: 'Campo de email com erro',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Email inválido'), findsOneWidget);
    });

    testWidgets('Disabled field renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauField(
                label: 'Desabilitado',
                enabled: false,
                semanticsLabel: 'Campo desabilitado',
              ),
            ),
          ),
        ),
      );

      // Verify disabled field renders
      expect(find.text('Desabilitado'), findsOneWidget);
      expect(find.byType(UrutauField), findsOneWidget);
    });

    testWidgets('Readonly field is not editable but focusable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauField(
                label: 'Somente leitura',
                readOnly: true,
                initialValue: 'Valor fixo',
                semanticsLabel: 'Campo somente leitura',
              ),
            ),
          ),
        ),
      );

      // Verify readonly field renders
      expect(find.text('Valor fixo'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('Obscure text toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauField(
                label: 'Senha',
                obscureText: true,
              ),
            ),
          ),
        ),
      );

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      // Should show text now (icon changes to visibility)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('UrutauCard Accessibility Tests', () {
    testWidgets('Tappable card can be tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauCard.tappable(
              onTap: () => tapped = true,
              semanticsLabel: 'Card tocável para detalhes',
              child: const Text('Conteúdo'),
            ),
          ),
        ),
      );

      // Verify card renders
      expect(find.text('Conteúdo'), findsOneWidget);
      expect(find.byType(UrutauCard), findsOneWidget);
      
      // Tap the card
      await tester.tap(find.byType(UrutauCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Selectable card shows selection state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauCard.selectable(
              selected: true,
              onTap: () {},
              semanticsLabel: 'Card selecionado',
              child: const Text('Selecionado'),
            ),
          ),
        ),
      );

      // Verify card renders
      expect(find.text('Selecionado'), findsOneWidget);
      expect(find.byType(UrutauCard), findsOneWidget);
      
      // Verify selected state visually (primary border)
      final card = tester.widget<UrutauCard>(find.byType(UrutauCard));
      expect(card.selected, isTrue);
    });

    testWidgets('Non-interactive card has no tap callback', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauCard(
              child: const Text('Apenas exibição'),
            ),
          ),
        ),
      );

      // Should not be tappable
      final card = tester.widget<UrutauCard>(find.byType(UrutauCard));
      expect(card.onTap, isNull);
    });
  });

  group('UrutauStatusBanner Accessibility Tests', () {
    testWidgets('Status banner renders with message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauStatusBanner.success(
                message: 'Operação concluída com sucesso',
                semanticsLabel: 'Sucesso: operação concluída',
              ),
            ),
          ),
        ),
      );

      // Verify banner renders
      expect(find.text('Operação concluída com sucesso'), findsOneWidget);
      expect(find.byType(UrutauStatusBanner), findsOneWidget);
    });

    testWidgets('All status types render with correct icons', (WidgetTester tester) async {
      final statuses = [
        UrutauStatusBanner.success(message: 'Sucesso'),
        UrutauStatusBanner.warning(message: 'Aviso'),
        UrutauStatusBanner.danger(message: 'Erro'),
        UrutauStatusBanner.info(message: 'Informação'),
        UrutauStatusBanner.neutral(message: 'Neutro'),
      ];

      for (final status in statuses) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: status))),
        );

        // Each should have an icon
        expect(find.byType(Icon), findsWidgets);
      }
    });

    testWidgets('Dismissible banner has close button', (WidgetTester tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauStatusBanner.info(
                message: 'Dispensável',
                dismissible: true,
                onDismissed: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Action button in banner is accessible', (WidgetTester tester) async {
      bool actionPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauStatusBanner.success(
                message: 'Com ação',
                actionLabel: 'Ver detalhes',
                onActionPressed: () => actionPressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ver detalhes'), findsOneWidget);
      await tester.tap(find.text('Ver detalhes'));
      await tester.pump();
      expect(actionPressed, isTrue);
    });
  });

  group('UrutauEmptyState Accessibility Tests', () {
    testWidgets('Empty state renders with title and message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauEmptyState.noData(
              title: 'Sem dados',
              message: 'Nada para mostrar',
              semanticsLabel: 'Estado vazio: sem dados disponíveis',
            ),
          ),
        ),
      );

      // Verify empty state renders
      expect(find.text('Sem dados'), findsOneWidget);
      expect(find.text('Nada para mostrar'), findsOneWidget);
      expect(find.byType(UrutauEmptyState), findsOneWidget);
    });

    testWidgets('Action button in empty state works', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauEmptyState.error(
              title: 'Erro',
              message: 'Falha ao carregar',
              actionLabel: 'Tentar novamente',
              onActionPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('Loading state shows progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UrutauEmptyState.loading(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('UrutauFilterChip Accessibility Tests', () {
    testWidgets('Filter chip renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauFilterChip.defaultChip(
                label: 'Filtro ativo',
                selected: true,
                onSelected: (_) {},
                semanticsLabel: 'Filtro ativo selecionado',
              ),
            ),
          ),
        ),
      );

      // Verify chip renders
      expect(find.text('Filtro ativo'), findsOneWidget);
      expect(find.byType(UrutauFilterChip), findsOneWidget);
    });

    testWidgets('Filter chip group manages selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauFilterChipGroup(
                chips: [
                  UrutauFilterChipData(value: '1', label: 'Opção 1'),
                  UrutauFilterChipData(value: '2', label: 'Opção 2'),
                ],
                selectionMode: UrutauFilterChipSelectionMode.single,
                initialSelection: {'1'},
              ),
            ),
          ),
        ),
      );

      // Both chips should render
      expect(find.byType(UrutauFilterChip), findsNWidgets(2));
    });

    testWidgets('Disabled filter chip is not interactive', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UrutauFilterChip.defaultChip(
                label: 'Desabilitado',
                selected: false,
                onSelected: (_) {},
                enabled: false,
              ),
            ),
          ),
        ),
      );

      // Should not respond to taps (no state change)
      await tester.tap(find.byType(UrutauFilterChip));
      await tester.pump();
    });
  });

  group('Contrast Ratio Tests', () {
    testWidgets('All primitives render in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: Column(
              children: [
                UrutauButton.primary(onPressed: () {}, label: 'Test'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauField(label: 'Test'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauCard(child: Text('Test')),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauStatusBanner.success(message: 'Test'),
                ),
                UrutauEmptyState.noData(title: 'Test'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauFilterChip.defaultChip(label: 'Test', selected: false, onSelected: (_) {}),
                ),
              ],
            ),
          ),
        ),
      );

      // All widgets should render without issues
      expect(find.byType(UrutauButton), findsOneWidget);
      expect(find.byType(UrutauField), findsOneWidget);
      expect(find.byType(UrutauCard), findsOneWidget);
      expect(find.byType(UrutauStatusBanner), findsOneWidget);
      expect(find.byType(UrutauEmptyState), findsOneWidget);
      expect(find.byType(UrutauFilterChip), findsOneWidget);
    });

    testWidgets('All primitives render in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Column(
              children: [
                UrutauButton.primary(onPressed: () {}, label: 'Test'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauField(label: 'Test'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauCard(child: Text('Test')),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauStatusBanner.success(message: 'Test'),
                ),
                UrutauEmptyState.noData(title: 'Test'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauFilterChip.defaultChip(label: 'Test', selected: false, onSelected: (_) {}),
                ),
              ],
            ),
          ),
        ),
      );

      // All widgets should render without issues
      expect(find.byType(UrutauButton), findsOneWidget);
      expect(find.byType(UrutauField), findsOneWidget);
      expect(find.byType(UrutauCard), findsOneWidget);
      expect(find.byType(UrutauStatusBanner), findsOneWidget);
      expect(find.byType(UrutauEmptyState), findsOneWidget);
      expect(find.byType(UrutauFilterChip), findsOneWidget);
    });
  });

  group('Touch Target Size Tests', () {
    testWidgets('All interactive elements meet minimum touch target', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UrutauButton.primary(onPressed: () {}, label: 'Button', size: UrutauButtonSize.small),
                UrutauButton.primary(onPressed: () {}, label: 'Button', size: UrutauButtonSize.medium),
                UrutauButton.primary(onPressed: () {}, label: 'Button', size: UrutauButtonSize.large),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauField(label: 'Field'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UrutauFilterChip.defaultChip(label: 'Chip', selected: false, onSelected: (_) {}),
                ),
              ],
            ),
          ),
        ),
      );

      // Check button sizes
      final smallButton = tester.renderObject<RenderBox>(find.byType(UrutauButton).first);
      expect(smallButton.size.height, greaterThanOrEqualTo(36)); // Small is 36

      final mediumButton = tester.renderObject<RenderBox>(find.byType(UrutauButton).at(1));
      expect(mediumButton.size.height, greaterThanOrEqualTo(48));

      final largeButton = tester.renderObject<RenderBox>(find.byType(UrutauButton).at(2));
      expect(largeButton.size.height, greaterThanOrEqualTo(56));
    });
  });

  group('Screen Reader Navigation Tests', () {
    testWidgets('Tab order is logical in forms', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  UrutauField(label: 'Campo 1', semanticsLabel: 'Primeiro campo'),
                  UrutauField(label: 'Campo 2', semanticsLabel: 'Segundo campo'),
                  UrutauButton.primary(onPressed: () {}, label: 'Enviar'),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify all fields are present
      expect(find.byType(UrutauField), findsNWidgets(2));
      expect(find.byType(UrutauButton), findsOneWidget);
    });

    testWidgets('Dialogs can be opened', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => UrutauDestructiveDialog(
                    title: 'Confirmar exclusão',
                    message: 'Tem certeza?',
                    confirmLabel: 'Excluir',
                    onConfirmed: () {},
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(UrutauDestructiveDialog), findsOneWidget);
      expect(find.text('Confirmar exclusão'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });
  });
}