import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_ricette/screens/missing_ingredient_page.dart';
import 'package:app_ricette/screens/add_product_manual_page.dart';
import 'package:app_ricette/models/ingredient.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
GEMINI_API_KEY=fake_key
GEMINI_MODEL=fake_model
''');
  });
  group('MissingIngredientPage Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      setUp(() {
        // iPhone 13 Pro Max dimensions approx
        // Width: 1284 / 3 = 428 logical
      });

      testWidgets('UI Base (Mobile): Formattazione nome e singolare', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1284, 2778);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'basilico',
              count: 1,
              onProductBought: (_) {},
              onRemoveFromList: () {},
            ),
          ),
        );

        // Verifico Capitalizzazione
        expect(find.text('Basilico'), findsOneWidget);

        // Verifico Singolare
        expect(find.textContaining('1 planned meal'), findsOneWidget);
        expect(find.textContaining('meals'), findsNothing);

        // Verifico layout pulsanti
        expect(find.text('Remove from list'), findsOneWidget);
        expect(find.text('Mark as Bought'), findsOneWidget);
      });

      testWidgets('Remove Flow (Mobile): Dialogo di conferma e interazione', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1284, 2778);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool removeCalled = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Pasta',
              count: 1,
              onProductBought: (_) {},
              onRemoveFromList: () { removeCalled = true; },
            ),
          ),
        );

        // Clicco "Remove from list"
        await tester.tap(find.text('Remove from list'));
        await tester.pumpAndSettle();

        // Verifico Dialog
        expect(find.text('Remove Item?'), findsOneWidget);

        // Clicco Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(removeCalled, isFalse);

        // Riapro e Clicco Remove
        await tester.tap(find.text('Remove from list'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Remove'));
        await tester.pumpAndSettle();

        expect(removeCalled, isTrue);
      });

      testWidgets('Buy Flow (Mobile): Naviga, riceve risultato e chiama callback', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1284, 2778);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        Ingredient? boughtResult;

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Latte',
              count: 1,
              onProductBought: (ing) { boughtResult = ing; },
              onRemoveFromList: () {},
            ),
          ),
        );

        // Clicco su "Mark as Bought"
        await tester.tap(find.text('Mark as Bought'));
        await tester.pumpAndSettle(); // Aspetto la transizione

        // Verifico che si sia aperta la pagina AddProductManualPage
        expect(find.byType(AddProductManualPage), findsOneWidget);

        // SIMULO IL SUCCESSO:
        final fakeIngredient = Ingredient(
            nome: 'Latte Fresco',
            quantity: '1',
            unit: 'L',
            scadenza: '01/01/2025',
            note: '',
            genericName: 'milk'
        );

        Navigator.of(tester.element(find.byType(AddProductManualPage))).pop(fakeIngredient);
        await tester.pumpAndSettle();

        expect(boughtResult, isNotNull);
        expect(boughtResult!.nome, 'Latte Fresco');
        expect(find.byType(MissingIngredientPage), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro 12.9 dimensions
      });

      testWidgets('UI Base (Tablet): Plurale corretto e Layout Centrato', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Pasta',
              count: 3,
              onProductBought: (_) {},
              onRemoveFromList: () {},
            ),
          ),
        );

        expect(find.textContaining('3 planned meals'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.cart_fill), findsOneWidget);
        expect(find.text('Pasta'), findsOneWidget);
        expect(find.text('Mark as Bought'), findsOneWidget);
      });

      testWidgets('Dialog (Tablet): Il popup appare correttamente al centro', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Olio',
              count: 1,
              onProductBought: (_) {},
              onRemoveFromList: () {},
            ),
          ),
        );

        await tester.tap(find.text('Remove from list'));
        await tester.pumpAndSettle();

        expect(find.text('Remove Item?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Remove Item?'), findsNothing);
      });

      testWidgets('Buy Flow (Tablet): Naviga, riceve risultato e chiude la pagina', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        Ingredient? boughtResult;

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Farina',
              count: 2,
              onProductBought: (ing) { boughtResult = ing; },
              onRemoveFromList: () {},
            ),
          ),
        );

        await tester.tap(find.text('Mark as Bought'));
        await tester.pumpAndSettle();

        expect(find.byType(AddProductManualPage), findsOneWidget);

        final fakeIngredient = Ingredient(
            nome: 'Farina 00',
            quantity: '1',
            unit: 'kg',
            scadenza: '10/10/2026',
            note: '',
            genericName: 'flour'
        );

        Navigator.of(tester.element(find.byType(AddProductManualPage))).pop(fakeIngredient);
        await tester.pumpAndSettle();

        expect(boughtResult, isNotNull);
        expect(boughtResult!.nome, 'Farina 00');
        expect(find.byType(MissingIngredientPage), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('MissingIngredientPage - Coverage Expansion', () {

      testWidgets('Empty Name Handling: Gestisce stringa vuota senza crash', (WidgetTester tester) async {
        // Verifica il ramo ternario: final displayName = name.isNotEmpty ? ... : name;
        
        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: '', // Empty name
              count: 1,
              onProductBought: (_) {},
              onRemoveFromList: () {},
            ),
          ),
        );

        // Dovrebbe renderizzare una stringa vuota senza eccezioni di range
        expect(find.byType(MissingIngredientPage), findsOneWidget);
      });

      testWidgets('Buy Flow (Null Result): Se utente annulla aggiunta, non fa nulla', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1284, 2778);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool boughtCallbackCalled = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: MissingIngredientPage(
              name: 'Zucchero',
              count: 1,
              onProductBought: (_) { boughtCallbackCalled = true; },
              onRemoveFromList: () {},
            ),
          ),
        );

        await tester.tap(find.text('Mark as Bought'));
        await tester.pumpAndSettle();

        // Utente torna indietro SENZA salvare (restituisce null)
        Navigator.of(tester.element(find.byType(AddProductManualPage))).pop(null);
        await tester.pumpAndSettle();

        // Verifica che la callback NON sia stata chiamata
        expect(boughtCallbackCalled, isFalse);
        
        // Verifica che siamo tornati alla pagina MissingIngredientPage (NON deve essersi chiusa)
        expect(find.byType(MissingIngredientPage), findsOneWidget);
      });
    });

  });
}