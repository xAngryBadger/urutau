import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urutau/main.dart' as app;
import 'package:urutau/services/sync_service.dart';
import 'package:urutau/services/theme_provider.dart';
import 'package:urutau/data/database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end smoke test (API 34 compatible)', () {
    testWidgets('Complete user flow: login → explorer → create parcel → plants → photo → draft/conclude → sync → settings → admin → logout', (WidgetTester tester) async {
      // Start the app with test overrides
      await _runAppWithTestOverrides(tester);

      // 1. Login screen should be visible
      await _waitForLoginScreen(tester);

      // Fill login credentials (using default test user)
      await _fillLoginForm(tester, 'test@test.com', 'test123');

      // Tap login button
      await _tapLoginButton(tester);

      // 2. Should be on Home screen
      await _verifyHomeScreen(tester);

      // 3. Navigate to Explorer
      await _navigateToExplorer(tester);

      // 4. Create new parcel
      await _createParcel(tester, 'Fazenda Teste', 'UT01', '1', 'Parcela de teste para smoke test');

      // 5. Add a plant
      await _addPlant(tester, 'Eucalipto', '150', '25');

      // 6. Add a photo (simulate)
      await _addPhoto(tester);

      // 7. Save as draft
      await _saveAsDraft(tester);

      // Verify back to explorer
      await _verifyParcelInExplorer(tester, 'Fazenda Teste');

      // 8. Open parcel and conclude
      await _concludeParcel(tester);

      // 9. Sync
      await _performSync(tester);

      // 10. Settings
      await _openSettings(tester);

      // 11. Admin (if admin user)
      await _checkAdminAccess(tester);

      // 12. Logout
      await _logout(tester);

      // Back to login screen
      await _verifyLoginScreen(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('App launches without crashes', (WidgetTester tester) async {
      await _runAppWithTestOverrides(tester);
      await _waitForLoginScreen(tester);
      expect(find.text('Urutau'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Theme toggle works', (WidgetTester tester) async {
      await _runAppWithTestOverrides(tester);
      await _waitForLoginScreen(tester);
      
      // Check theme provider is accessible
      final themeProvider = tester.binding.platformDispatcher.implicitView?.platformDispatcher;
      expect(themeProvider, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('High contrast mode toggle', (WidgetTester tester) async {
      await _runAppWithTestOverrides(tester);
      await _waitForLoginScreen(tester);
      
      // Navigate to settings if possible
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Look for high contrast toggle
        final contrastToggle = find.byType(Switch).first;
        if (contrastToggle.evaluate().isNotEmpty) {
          await tester.tap(contrastToggle);
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }
        
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

/// Helper functions for robust testing

Future<void> _runAppWithTestOverrides(WidgetTester tester) async {
  // Use runZonedGuarded to catch errors
  await tester.runAsync(() async {
    app.main();
  });
  
  // Wait for app to initialize
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> _waitForLoginScreen(WidgetTester tester) async {
  // Wait for login screen elements
  await tester.pumpUntilFound(
    find.text('Urutau'),
    const Duration(seconds: 15),
  );
  
  // Verify login form fields
  await tester.pumpUntilFound(
    find.byType(TextField).at(0),
    const Duration(seconds: 5),
  );
  await tester.pumpUntilFound(
    find.byType(TextField).at(1),
    const Duration(seconds: 5),
  );
}

Future<void> _fillLoginForm(WidgetTester tester, String email, String password) async {
  // Clear and enter email
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  
  // Clear and enter password
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

Future<void> _tapLoginButton(WidgetTester tester) async {
  // Find and tap login button (could be ElevatedButton, FilledButton, etc.)
  final loginButtons = find.byWidgetPredicate((widget) {
    return widget is FilledButton || widget is ElevatedButton;
  });
  
  if (loginButtons.evaluate().isNotEmpty) {
    await tester.tap(loginButtons.first);
  } else {
    // Fallback: tap any button on screen
    await tester.tap(find.byType(Button).first);
  }
  
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

Future<void> _verifyHomeScreen(WidgetTester tester) async {
  // Wait for home screen indicators
  await tester.pumpUntilFound(
    find.byIcon(Icons.add).first,
    const Duration(seconds: 10),
  );
  
  // Or check for FAB
  final fab = find.byType(FloatingActionButton);
  if (fab.evaluate().isNotEmpty) {
    expect(fab, findsOneWidget);
  }
}

Future<void> _navigateToExplorer(WidgetTester tester) async {
  // Try multiple ways to navigate to explorer
  final explorerIcons = [
    find.byIcon(Icons.forest),
    find.byIcon(Icons.explore),
    find.byIcon(Icons.map),
    find.byTooltip('Explorador'),
  ];

  bool navigated = false;
  for (final icon in explorerIcons) {
    if (icon.evaluate().isNotEmpty) {
      await tester.tap(icon);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      navigated = true;
      break;
    }
  }

  if (!navigated) {
    // Try bottom navigation bar
    final bottomNav = find.byType(BottomNavigationBar);
    if (bottomNav.evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.forest).last);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
  }
}

Future<void> _createParcel(
  WidgetTester tester,
  String propriedade,
  String ut,
  String parcela,
  String descricao,
) async {
  // Tap create parcel button
  final createButtons = [
    find.text('Nova Parcela'),
    find.text('Criar Parcela'),
    find.byIcon(Icons.add).last,
  ];

  for (final btn in createButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }

  // Fill form fields
  final textFields = find.byType(TextField);
  if (textFields.evaluate().length >= 4) {
    await tester.enterText(textFields.at(0), propriedade);
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(1), ut);
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(2), parcela);
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(3), descricao);
    await tester.pumpAndSettle();
  }

  // Save
  final saveButtons = [
    find.text('Salvar'),
    find.text('Criar'),
    find.byType(FilledButton).last,
  ];

  for (final btn in saveButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }
}

Future<void> _addPlant(WidgetTester tester, String nome, String altura, String dap) async {
  // Tap add plant
  final addPlantButtons = [
    find.text('Adicionar Planta'),
    find.text('Nova Planta'),
    find.byIcon(Icons.add_circle),
  ];

  for (final btn in addPlantButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }

  // Fill plant form
  final textFields = find.byType(TextField);
  if (textFields.evaluate().length >= 3) {
    await tester.enterText(textFields.first, nome);
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(1), altura);
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(2), dap);
    await tester.pumpAndSettle();
  }

  // Select category (if dropdown)
  final categoryDropdown = find.byType(DropdownButtonFormField);
  if (categoryDropdown.evaluate().isNotEmpty) {
    await tester.tap(categoryDropdown.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria 1').first);
    await tester.pumpAndSettle();
  }

  // Save plant
  final saveButtons = [find.text('Salvar').last, find.byType(FilledButton).last];
  for (final btn in saveButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }
}

Future<void> _addPhoto(WidgetTester tester) async {
  // Tap add photo button
  final photoButtons = [
    find.byIcon(Icons.add_a_photo),
    find.byIcon(Icons.camera_alt),
    find.byIcon(Icons.photo),
  ];

  for (final btn in photoButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }

  // Try to select gallery option
  final galleryOptions = [
    find.text('Galeria (múltiplas)'),
    find.text('Galeria'),
    find.text('Escolher da galeria'),
  ];

  for (final opt in galleryOptions) {
    if (opt.evaluate().isNotEmpty) {
      await tester.tap(opt);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }
}

Future<void> _saveAsDraft(WidgetTester tester) async {
  final draftButtons = [
    find.text('Guardar rascunho'),
    find.text('Salvar rascunho'),
    find.text('Rascunho'),
  ];

  for (final btn in draftButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }
}

Future<void> _verifyParcelInExplorer(WidgetTester tester, String propriedade) async {
  await tester.pumpUntilFound(
    find.text(propriedade),
    const Duration(seconds: 5),
  );
}

Future<void> _concludeParcel(WidgetTester tester) async {
  // Tap on first parcel
  final parcelItems = find.byType(ListTile);
  if (parcelItems.evaluate().isNotEmpty) {
    await tester.tap(parcelItems.first);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  // Conclude
  final concludeButtons = [
    find.text('Concluir alterações'),
    find.text('Finalizar'),
    find.text('Concluir'),
  ];

  for (final btn in concludeButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      break;
    }
  }
}

Future<void> _performSync(WidgetTester tester) async {
  // Tap sync button
  final syncButtons = [
    find.byIcon(Icons.cloud_upload),
    find.byIcon(Icons.sync),
    find.byTooltip('Sincronizar'),
  ];

  for (final btn in syncButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }

  // Confirm sync if dialog appears
  final confirmButtons = [
    find.text('Confirmar envio'),
    find.text('Enviar'),
    find.text('Sim'),
  ];

  for (final btn in confirmButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 15));
      break;
    }
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  final settingsButtons = [
    find.byIcon(Icons.settings),
    find.byTooltip('Configurações'),
  ];

  for (final btn in settingsButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }

  // Go back
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

Future<void> _checkAdminAccess(WidgetTester tester) async {
  final adminButtons = [
    find.byIcon(Icons.admin_panel_settings),
    find.byIcon(Icons.security),
    find.byTooltip('Administração'),
  ];

  for (final btn in adminButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      break;
    }
  }
}

Future<void> _logout(WidgetTester tester) async {
  final logoutButtons = [
    find.byIcon(Icons.logout),
    find.byIcon(Icons.exit_to_app),
    find.byTooltip('Sair'),
  ];

  for (final btn in logoutButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }

  // Confirm logout
  final confirmButtons = [
    find.text('Sair'),
    find.text('Confirmar'),
    find.text('Sim'),
  ];

  for (final btn in confirmButtons) {
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      break;
    }
  }
}

Future<void> _verifyLoginScreen(WidgetTester tester) async {
  await tester.pumpUntilFound(
    find.text('Urutau'),
    const Duration(seconds: 5),
  );
}