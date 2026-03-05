import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_ricette/screens/home_page.dart';
import 'package:app_ricette/models/ingredient.dart';
import 'package:app_ricette/services/firestore_service.dart';
import 'package:app_ricette/screens/product_page.dart';

// --- SMART MOCK FIRESTORE ---
class SmartMockFirestore implements FirestoreService {
  List<Ingredient> _db = [];

  SmartMockFirestore() {
    // Dati iniziali
    _db = [
      Ingredient(
        id: '1',
        nome: 'Latte',
        genericName: 'milk',
        quantity: '1',
        unit: 'L',
        scadenza: '10/12/2030', // Futuro (non scaduto)
        note: '',
      ),
      Ingredient(
        id: '2',
        nome: 'Pollo',
        genericName: 'chicken',
        quantity: '500',
        unit: 'g',
        scadenza: '01/01/2020', // Passato (scaduto)
        note: 'Scaduto',
      ),
    ];
  }

  @override
  Future<List<Ingredient>> loadFridge() async {
    // Simula ritardo rete
    await Future.delayed(const Duration(milliseconds: 50));
    return List.from(_db);
  }

  @override
  Future<void> addIngredient(Ingredient i) async {
    i.id = DateTime.now().millisecondsSinceEpoch.toString(); // ID finto
    _db.add(i);
  }

  @override
  Future<void> updateIngredient(Ingredient i) async {
    final index = _db.indexWhere((element) => element.id == i.id);
    if (index != -1) {
      _db[index] = i;
    }
  }

  @override
  Future<void> deleteIngredient(String id) async {
    _db.removeWhere((element) => element.id == id);
  }

  @override
  Stream<List<Ingredient>> streamFridge() => Stream.value(_db);

  @override
  Future<void> deleteIngredientWithTracking(Ingredient i, {bool isExpired = false}) async {
    _db.removeWhere((element) => element.id == i.id);
  }

  @override
  Future<void> saveUsedProduct(Ingredient i, double amountUsed) async {
    return;
  }

  @override
  Future<double> getTotalSavings() async {
    return 0.0;
  }

  @override
  Stream<double> streamTotalSavings() {
    return Stream.value(0.0);
  }
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
GEMINI_API_KEY=fake_test_key
GEMINI_MODEL=fake_test_model
''');
  });

  group('HomePage Full Tests', () {
    late SmartMockFirestore smartMock;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Ricrea il DB pulito prima di ogni test
      smartMock = SmartMockFirestore();
    });

    // ---------------------------------------------------------------------------
    // MOBILE (iPhone 13 View)
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      void setupMobile(WidgetTester tester) {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
      }

      testWidgets('Rendering Lista (Mobile): Mostra prodotti e badge scadenza', (WidgetTester tester) async {
        setupMobile(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Latte'), findsOneWidget);
        expect(find.text('Pollo'), findsOneWidget);
        expect(find.text('Expired'), findsOneWidget);
      });

      testWidgets('Navigazione Tabs (Mobile): Cambio pagina fluido', (WidgetTester tester) async {
        setupMobile(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(key: const Key('plan_tab')), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('plan_tab')), findsNothing);
        await tester.tap(find.byIcon(CupertinoIcons.calendar_today));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('plan_tab')), findsOneWidget);
      });

      testWidgets('Menu Aggiungi (Mobile): ActionSheet apre e naviga', (WidgetTester tester) async {
        setupMobile(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(CupertinoIcons.add_circled_solid));
        await tester.pumpAndSettle();
        expect(find.text('Craft Ingredient'), findsOneWidget);
        await tester.tap(find.text('Manually'));
        await tester.pumpAndSettle();
        expect(find.text('Craft Ingredient'), findsNothing);
      });

      testWidgets('CRUD Delete (Mobile): Elimina un prodotto e aggiorna la lista', (WidgetTester tester) async {
        setupMobile(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        // Verifico presenza "Pollo"
        expect(find.text('Pollo'), findsOneWidget);

        // Apro ProductPage cliccando sull'elemento
        await tester.tap(find.text('Pollo'));
        await tester.pumpAndSettle();

        // Cerco il bottone delete (assumiamo sia un'icona cestino o testo Delete nella ProductPage)
        expect(find.byType(ProductPage), findsOneWidget);

        // CERCo IL TASTO "Remove Product" (Bottone rosso in basso)
        final removeBtn = find.text('Remove Product');

        await tester.ensureVisible(removeBtn);
        expect(removeBtn, findsOneWidget);

        // Clicco "Remove Product"
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        // Gestione eventuale Dialog di conferma (se presente in ProductPage)
        final confirmBtn = find.text('Delete'); // O 'Confirm'
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn.last);
          await tester.pumpAndSettle();
        }

        // Verifico ritorno alla Home e rimozione elemento
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.text('Pollo'), findsNothing);
        expect(find.text('Latte'), findsOneWidget);
      });

      testWidgets('CRUD Add (Mobile): Aggiunge prodotto manualmente e aggiorna lista', (WidgetTester tester) async {
        setupMobile(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        // Apro menu aggiunta
        await tester.tap(find.text('Add Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manually'));
        await tester.pumpAndSettle();

        // Compilo form (AddProductManualPage)
        await tester.enterText(find.byType(CupertinoTextField).at(0), 'Torta'); // Nome
        await tester.enterText(find.byType(CupertinoTextField).at(1), '1'); // Qta

        // Data (apri picker e conferma)
        await tester.tap(find.text('Select Date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Salvo
        await tester.tap(find.text('Add to Fridge'));
        await tester.pumpAndSettle();

        // Verifico aggiunta in Home
        expect(find.text('Torta'), findsOneWidget);
      });

      testWidgets('Empty State (Mobile): Mostra icona e testo quando il frigo è vuoto', (WidgetTester tester) async {
        setupMobile(tester);

        // Creo un Mock vuoto
        //final emptyMock = SmartMockFirestore();

        // Creo una variante locale del mock vuota
        final emptyFirestore = SmartMockFirestore();
        await emptyFirestore.deleteIngredient('1');
        await emptyFirestore.deleteIngredient('2');

        await tester.pumpWidget(
            CupertinoApp(
                home: HomePage(
                    firestoreService: emptyFirestore,
                    isTestMode: true,
                    recipesPageOverride: Container(),
                    planPageOverride: Container(),
                    settingsPageOverride: Container()
                )
            )
        );

        await tester.pumpAndSettle();

        // Verifico Empty State
        expect(find.text('Empty pantry'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.shopping_cart), findsOneWidget);
        expect(find.text('Latte'), findsNothing);
      });

      testWidgets('Color Logic (Mobile): Verifica colori per Scaduto e Fresco', (WidgetTester tester) async {
        setupMobile(tester);

        // Latte è fresco (2030) -> Grigio
        // Pollo è scaduto (2020) -> Rosso

        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        // Verifico Scaduto (Pollo)
        // "Expired" è il testo mostrato quando scaduto
        final expiredText = tester.widget<Text>(find.text('Expired'));
        expect(expiredText.style?.color, CupertinoColors.systemRed);

        // Verifico nome prodotto rosso
        final polloText = tester.widget<Text>(find.text('Pollo'));
        expect(polloText.style?.color, CupertinoColors.systemRed);

        // Verifico Fresco (Latte)
        // La data è mostrata (10/12/2030)
        final freshDateText = tester.widget<Text>(find.text('10/12/2030'));
        // Il colore di default è systemGrey
        expect(freshDateText.style?.color, CupertinoColors.systemGrey);

        final latteText = tester.widget<Text>(find.text('Latte'));
        expect(latteText.style?.color, CupertinoColors.label);
      });
    });

    // ---------------------------------------------------------------------------
    // TABLET (iPad Pro View)
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      void setupTablet(WidgetTester tester) {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
      }

      testWidgets('Layout & Interaction (Tablet): Elementi visibili e cliccabili', (WidgetTester tester) async {
        setupTablet(tester);
        await tester.pumpWidget(CupertinoApp(home: CupertinoPageScaffold(child: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container()))));
        await tester.pumpAndSettle();

        expect(find.text('Latte'), findsOneWidget);
        await tester.tap(find.text('Latte'));
        await tester.pumpAndSettle();
      });

      testWidgets('Menu Aggiungi (Tablet): ActionSheet centrato o visibile', (WidgetTester tester) async {
        setupTablet(tester);
        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(CupertinoIcons.add_circled_solid));
        await tester.pumpAndSettle();
        expect(find.text('Craft Ingredient'), findsOneWidget);
        expect(find.text('Manually'), findsOneWidget);
        await tester.tap(find.text('Manually'));
        await tester.pumpAndSettle();
        expect(find.text('Craft Ingredient'), findsNothing);
      });

      testWidgets('Logic Check: Date parsing & Warning Days', (WidgetTester tester) async {
        // Questo test verifica indirettamente _getDaysFromIndex e la logica di visualizzazione date
        setupTablet(tester);

        // Aggiungo un elemento che scade tra 2 giorni (Warning Zone per default)
        final today = DateTime.now();
        final warningDate = today.add(const Duration(days: 2));
        final warningStr = '${warningDate.day}/${warningDate.month}/${warningDate.year}';

        await smartMock.addIngredient(Ingredient(
            nome: 'Yogurt', genericName: 'yogurt', quantity: '1', unit: 'vasetto',
            scadenza: warningStr, note: ''
        ));

        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        // Verifico che l'elemento sia in lista
        expect(find.text('Yogurt'), findsOneWidget);

        // Verifico visualizzazione data
        expect(find.text(warningStr), findsOneWidget);

        // Verifico Colore Arancione (Warning)
        final dateText = tester.widget<Text>(find.text(warningStr));
        expect(dateText.style?.color, CupertinoColors.systemOrange);
      });

      testWidgets('CRUD Update Reale (Tablet): Modifica quantità e verifica', (WidgetTester tester) async {
        setupTablet(tester);

        await tester.pumpWidget(CupertinoApp(home: HomePage(firestoreService: smartMock, isTestMode: true, recipesPageOverride: Container(), planPageOverride: Container(), settingsPageOverride: Container())));
        await tester.pumpAndSettle();

        // Apro Latte
        await tester.tap(find.text('Latte'));
        await tester.pumpAndSettle();

        // Clicco Edit (Bacchetta magica in ProductPage)
        await tester.tap(find.byIcon(CupertinoIcons.wand_stars));
        await tester.pump();

        // Cambio quantità da 1 a 5
        final qtyField = find.byType(CupertinoTextField).at(1); // Il secondo campo è qty
        await tester.enterText(qtyField, '5');

        // Salvo (Floppy disk)
        await tester.tap(find.byIcon(CupertinoIcons.floppy_disk));
        await tester.pumpAndSettle();

        // Torno indietro alla Home
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Verifico che in Home ora ci sia scritto "5 L" invece di "1 L"
        expect(find.text('5 L'), findsOneWidget);
      });

    });
  });
}