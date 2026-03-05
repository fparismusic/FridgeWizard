import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/screens/product_page.dart';
import 'package:app_ricette/models/ingredient.dart';
import 'package:app_ricette/services/gemini_service.dart';

// --- MOCK GEMINI SERVICE ---
class FakeGeminiService implements GeminiService {
  bool extractCalled = false;
  bool shouldFail = false;

  @override
  Future<String> extractGenericName(String productName) async {
    extractCalled = true;
    if (shouldFail) throw Exception('Gemini API Error');
    await Future.delayed(const Duration(milliseconds: 50));
    return "Generic $productName";
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  // Dati Mock condivisi
  final testProduct = Ingredient(
      id: '1',
      nome: 'Latte Intero',
      genericName: 'Latte',
      quantity: '1',
      unit: 'L',
      scadenza: '20/12/2030',
      note: 'Fresco'
  );

  group('ProductPage Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      setUp(() {
        // iPhone 13 -> 390px width
      });

      testWidgets('Visualizzazione (Mobile): Mostra dati corretti', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        expect(find.text('Latte Intero'), findsWidgets);
        expect(find.text('Fresco'), findsOneWidget);
        expect(find.byType(CupertinoTextField), findsNothing);
      });

      testWidgets('Flusso Edit & Save (Mobile): Modifica senza Gemini', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeGemini = FakeGeminiService();
        bool saved = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (ing) { saved = true; },
              onDelete: () {},
              geminiService: fakeGemini,
            ),
          ),
        );

        // Edit Mode
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Modifico Quantità (index 1)
        await tester.enterText(find.byType(CupertinoTextField).at(1), '5');

        // Salvo
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));
        await tester.pump();

        expect(saved, isTrue);
        expect(fakeGemini.extractCalled, isFalse);
      });

      testWidgets('Delete Flow (Mobile): Richiede Scroll e Conferma', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool deleted = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () { deleted = true; },
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Su mobile il tasto potrebbe essere fuori schermo -> Scroll
        await tester.scrollUntilVisible(find.text('Remove Product'), 500);
        await tester.tap(find.text('Remove Product'));
        await tester.pumpAndSettle(); // Action Sheet

        expect(find.text('Are you sure you want to delete this item?'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
      });

      testWidgets('Edit Mode: Unit Picker funziona', (WidgetTester tester) async {
        // Setup Mobile size
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: Ingredient(
                  id: testProduct.id, nome: testProduct.nome, quantity: testProduct.quantity,
                  unit: 'L',
                  scadenza: testProduct.scadenza, note: testProduct.note, genericName: testProduct.genericName
              ),
              onSave: (_) {}, onDelete: () {}, geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Edit -> Tap L -> Scroll -> Done -> Verify
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();
        await tester.tap(find.text('L'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -50));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Verifica che sia cambiato (es. in ml)
        expect(find.text('ml'), findsOneWidget);
      });

      testWidgets('Edit Mode: Date Picker funziona', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Entro in Edit Mode
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Clicco sulla data attuale per aprire il picker
        // (Nel setup il testProduct ha scadenza 20/12/2030)
        await tester.tap(find.text('20/12/2030'));
        await tester.pumpAndSettle();

        // Trascino il DatePicker per cambiare data
        await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 50));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Verifico che la data sia cambiata
        expect(find.text('20/12/2030'), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro 12.9 -> 1024px width
      });

      testWidgets('Layout (Tablet): Campi Edit ben distribuiti', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Verifico che i campi Quantity e Unit siano visibili e cliccabili
        expect(find.byType(CupertinoTextField), findsAtLeastNWidgets(2));
        expect(find.text('L'), findsOneWidget); // Unit selector
      });

      testWidgets('Flusso Save con Gemini (Tablet): Dialogo caricamento visibile', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeGemini = FakeGeminiService();
        bool saved = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (ing) {
                saved = true;
                expect(ing.genericName, 'Generic Latte Parzialmente');
              },
              onDelete: () {},
              geminiService: fakeGemini,
            ),
          ),
        );

        // Edit -> Cambia nome -> Salva
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        await tester.enterText(find.byType(CupertinoTextField).first, 'Latte Parzialmente');
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));

        // Verifico Dialogo Caricamento
        await tester.pump(const Duration(milliseconds: 10));
        expect(find.text('Translating...'), findsOneWidget);

        // Fine caricamento
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(fakeGemini.extractCalled, isTrue);
        expect(saved, isTrue);
      });

      testWidgets('Delete Flow (Tablet): ActionSheet visibile senza scroll', (WidgetTester tester) async {
        // Su tablet lo schermo è alto, il tasto Remove dovrebbe essere subito visibile
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool deleted = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () { deleted = true; },
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Non usiamo scrollUntilVisible per verificare che sia già lì
        expect(find.text('Remove Product'), findsOneWidget);

        await tester.tap(find.text('Remove Product'));
        await tester.pumpAndSettle();

        expect(find.text('Are you sure you want to delete this item?'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
      });

      testWidgets('Edit Mode (Tablet): Unit Picker funziona', (WidgetTester tester) async {
        // Configurazione iPad Pro 12.9"
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: Ingredient(
                  id: testProduct.id,
                  nome: testProduct.nome,
                  quantity: testProduct.quantity,
                  unit: 'L',
                  scadenza: testProduct.scadenza,
                  note: testProduct.note,
                  genericName: testProduct.genericName
              ),
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Entro in Edit Mode
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Apro il Picker cliccando su 'L'
        await tester.tap(find.text('L'));
        await tester.pumpAndSettle();

        // Scrollo per selezionare 'ml' (verso l'alto)
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -50));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Verifico che sia cambiato in ml
        expect(find.text('ml'), findsOneWidget);
      });

      testWidgets('Edit Mode (Tablet): Date Picker funziona', (WidgetTester tester) async {
        // Configurazione iPad Pro 12.9"
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct, // Ha data 20/12/2030
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Entro in Edit Mode
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Clicco sulla data attuale per aprire il picker
        await tester.tap(find.text('20/12/2030'));
        await tester.pumpAndSettle();

        // Trascino il DatePicker
        await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 50));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Verifico che la data sia cambiata
        expect(find.text('20/12/2030'), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('ProductPage - Coverage Expansion', () {

      testWidgets('Validation Error: Salvare con nome vuoto mostra alert', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Edit
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Svuoto il nome
        await tester.enterText(find.byType(CupertinoTextField).at(0), '');

        // Salva
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));
        await tester.pumpAndSettle();

        // Verifica Dialogo di Errore
        expect(find.text('Missing Info'), findsOneWidget);
        expect(find.text('Name, Quantity and Date are required.'), findsOneWidget);
      });

      testWidgets('Gemini Failure: Save prosegue anche se traduzione fallisce', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeGemini = FakeGeminiService();
        fakeGemini.shouldFail = true; // Simulo errore API

        bool saved = false;
        String? savedGenericName;

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct, // Nome: Latte Intero
              onSave: (ing) {
                saved = true;
                savedGenericName = ing.genericName;
              },
              onDelete: () {},
              geminiService: fakeGemini,
            ),
          ),
        );

        // Edit -> Cambio nome per triggerare traduzione
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();
        await tester.enterText(find.byType(CupertinoTextField).at(0), 'Latte Scremato');

        // Salva
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));
        
        // Aspetto che finiscano i dialoghi di loading e le chiamate async
        await tester.pumpAndSettle();

        // Verifica: Salvataggio avvenuto comunque
        expect(saved, isTrue);
        // Verifica: Generic Name è fallback al nome inserito ('Latte Scremato') invece che null o vecchio
        expect(savedGenericName, 'Latte Scremato');
      });

      testWidgets('Save Callback Error: Mostra dialogo se onSave fallisce', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: testProduct,
              onSave: (_) { throw Exception("DB Error"); }, // Simulo errore DB
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // Edit -> Save
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));
        await tester.pumpAndSettle();

        // Deve apparire dialog errore generico
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Failed to save. Try again.'), findsOneWidget);
      });

      testWidgets('Date Parsing Resilience: Gestisce date malformate nel prodotto iniziale', (WidgetTester tester) async {
        // Test per il blocco try-catch in _parseData
        final brokenProduct = Ingredient(
            id: '2',
            nome: 'Broken Date Item',
            genericName: 'Item',
            quantity: '1',
            unit: 'pcs',
            scadenza: 'invalid-date-string', // DATA ROTTA
            note: ''
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: ProductPage(
              product: brokenProduct,
              onSave: (_) {},
              onDelete: () {},
              geminiService: FakeGeminiService(),
            ),
          ),
        );

        // 1. Verifica che non sia crashato e mostri la stringa originale in read-only
        // FIX: Usiamo findsWidgets perché il testo appare sia nella AppBar che nel Body
        expect(find.text('Broken Date Item'), findsWidgets);
        expect(find.text('invalid-date-string'), findsOneWidget);

        // 2. Entra in Edit Mode -> Il DatePicker deve aver fatto fallback a DateTime.now()
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Verifico che il campo data ora mostri una data valida (Oggi)
        final now = DateTime.now();
        final expectedDateStr = '${now.day}/${now.month}/${now.year}';
        
        expect(find.text(expectedDateStr), findsOneWidget);
      });

    });

  });
}