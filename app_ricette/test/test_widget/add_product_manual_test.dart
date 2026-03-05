import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_ricette/screens/add_product_manual_page.dart';
import 'package:app_ricette/models/ingredient.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
GEMINI_API_KEY=fake_key
GEMINI_MODEL=fake_model
''');
  });

  // ---------------------------------------------------------------------------
  // TEST MOBILE (Schermo stretto: iPhone/Android standard)
  // ---------------------------------------------------------------------------
  group('AddProductManualPage - MOBILE View Tests', () {

    setUp(() {
      // Configurazione schermo MOBILE (es. iPhone 13)
      // Larghezza Logica = 1170 / 3.0 = 390px
      // Altezza Logica = 2532 / 3.0 = 844px
    });

    testWidgets('Validazione (Mobile): Mostra errore se provo a salvare vuoto', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const CupertinoApp(
          home: AddProductManualPage(),
        ),
      );

      // Provo a cliccare "Add to Fridge" senza scrivere nulla
      await tester.tap(find.text('Add to Fridge'));
      await tester.pumpAndSettle();

      // Deve apparire il dialog di errore
      expect(find.text('Missing Info'), findsOneWidget);
      expect(find.text('Please ensure Name and Expiration Date are set.'), findsOneWidget);

      // Chiudo il dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('Happy Path (Mobile): Compilazione Form e Salvataggio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      Ingredient? resultIngredient;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              return CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    child: const Text('Open Form'),
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const AddProductManualPage()),
                      );
                      resultIngredient = result as Ingredient?;
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Inserisco Dati
      final nameField = find.byType(CupertinoTextField).at(0);
      await tester.enterText(nameField, 'Pasta Mobile');

      final qtyField = find.byType(CupertinoTextField).at(1);
      await tester.enterText(qtyField, '500');

      // Seleziono Data
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -70.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Salvataggio
      await tester.tap(find.text('Add to Fridge'));

      await tester.pumpAndSettle();

      expect(find.byType(AddProductManualPage), findsNothing);
      expect(resultIngredient, isNotNull);
      expect(resultIngredient!.nome, 'Pasta Mobile');
    });

    testWidgets('Interazione Unit Picker: Cambio unità da g a kg', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const CupertinoApp(
          home: AddProductManualPage(),
        ),
      );

      // Verifico stato iniziale (Default è 'g')
      expect(find.text('g'), findsOneWidget);

      // Apro il Picker cliccando sull'unità attuale
      await tester.tap(find.text('g'));
      await tester.pumpAndSettle(); // Aspetto l'animazione del popup

      // Verifico che il CupertinoPicker sia apparso
      expect(find.byType(CupertinoPicker), findsOneWidget);

      // Seleziono un'altra unità (es. 'kg')
      // La lista è: ['pcs', 'g', 'kg', 'L', ...]
      // 'g' è l'elemento corrente. 'kg' è quello subito sotto.
      // Per selezionare l'elemento SOTTO, devo trascinare la ruota verso l'ALTO (Offset Y negativo).
      // L'itemExtent è 40, quindi trasciniamo di -40 o un po' di più.
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -50));
      await tester.pumpAndSettle();

      // Chiudo il picker cliccando su Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle(); // Aspetto che il popup scenda

      // Verifico che l'UI ora mostri 'kg' invece di 'g'
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('g'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // TEST TABLET (Schermo largo: iPad Pro)
  // ---------------------------------------------------------------------------
  group('AddProductManualPage - TABLET View Tests', () {

    setUp(() {
      // Configurazione schermo TABLET (es. iPad Pro 12.9")
      // Larghezza Logica = 2048 / 2.0 = 1024px (Molto spazio orizzontale)
    });

    testWidgets('Validazione (Tablet): Dialog errore appare correttamente centrato', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const CupertinoApp(
          home: AddProductManualPage(),
        ),
      );

      await tester.tap(find.text('Add to Fridge'));
      await tester.pumpAndSettle();

      // Verifica che il dialog appaia anche su schermo grande
      expect(find.text('Missing Info'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('Happy Path (Tablet): Form utilizzabile su schermo largo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      Ingredient? resultIngredient;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              return CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    child: const Text('Open Form'),
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const AddProductManualPage()),
                      );
                      resultIngredient = result as Ingredient?;
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Verifica che i campi di testo siano trovabili e cliccabili anche su tablet
      final nameField = find.byType(CupertinoTextField).at(0);
      await tester.enterText(nameField, 'Pasta Tablet');

      final qtyField = find.byType(CupertinoTextField).at(1);
      await tester.enterText(qtyField, '1000');

      // Date Picker su Tablet
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -70.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Fridge'));
      await tester.pumpAndSettle();

      expect(find.byType(AddProductManualPage), findsNothing);
      expect(resultIngredient!.nome, 'Pasta Tablet');
    });

    testWidgets('Interazione Unit Picker (Tablet): Cambio unità da g a kg su schermo largo', (WidgetTester tester) async {
      // Configurazione schermo TABLET (iPad Pro 12.9")
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const CupertinoApp(
          home: AddProductManualPage(),
        ),
      );

      // Verifico stato iniziale 'g'
      expect(find.text('g'), findsOneWidget);

      // Apro il Picker (Tap su 'g')
      await tester.tap(find.text('g'));
      await tester.pumpAndSettle();

      // Verifico che il CupertinoPicker sia apparso (anche su tablet deve essere un modale in basso)
      expect(find.byType(CupertinoPicker), findsOneWidget);

      // Seleziono 'kg' trascinando
      // Nota: Su tablet lo scorrimento è identico
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -50));
      await tester.pumpAndSettle();

      // Chiudo con Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verifico cambiamento in 'kg'
      expect(find.text('kg'), findsOneWidget);
    });
  });
}