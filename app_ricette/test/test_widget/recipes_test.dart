import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/screens/recipes_page.dart';
import 'package:app_ricette/models/ingredient.dart';
import 'package:app_ricette/models/recipe.dart';
import 'package:app_ricette/services/recipes_service.dart';

// --- MOCK RECIPES SERVICE ---
class MockRecipesService implements RecipesService {
  bool shouldFail = false;
  Duration delay = const Duration(milliseconds: 50);

  @override
  Future<List<Recipe>> searchRecipesByName(String query) async {
    if (shouldFail) throw Exception("API Error");

    await Future.delayed(delay);

    if (query == "Carbonara") {
      return [
        Recipe(
            id: 1,
            title: 'Spaghetti Carbonara',
            image: 'url_finto',
            usedIngredientCount: 0,
            missedIngredientCount: 0
        )
      ];
    }
    return [];
  }

  @override
  Future<List<Recipe>> fetchRecipesByIngredients(List<String> ingredients) async {
    if (shouldFail) throw Exception("API Error");

    if (ingredients.contains("Tomato")) {
      return [
        Recipe(
            id: 2,
            title: 'Tomato Soup',
            image: 'url_finto',
            usedIngredientCount: 1,
            missedIngredientCount: 0
        )
      ];
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getRecipeDetails(int id) async {
    return {
      'id': id,
      'title': 'Mock Details',
      'image': 'mock_url',
      'readyInMinutes': 30,
      'servings': 2,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  // Dati Mock Condivisi
  final fridgeData = [
    Ingredient(
      nome: 'Pomodori',
      genericName: 'Tomato',
      quantity: '2',
      unit: 'pcs',
      scadenza: '01/01/2030',
      note: '',
    ),
    Ingredient(
      nome: 'Latte',
      genericName: 'Milk',
      quantity: '1',
      unit: 'L',
      scadenza: '01/01/2030',
      note: '',
    ),
  ];

  group('RecipesPage Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      setUp(() {
        // iPhone 13 Pro Dimensions
      });

      testWidgets('Rendering Iniziale (Mobile): Layout compatto', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(
              recipesService: MockRecipesService(),
              fridgeItems: fridgeData,
            ),
          ),
        );

        await tester.pump(); // No pumpAndSettle per via dello shimmer

        expect(find.text('By Name'), findsOneWidget);
        expect(find.text('By Ingredients'), findsOneWidget);
        expect(find.text('Search recipes...'), findsOneWidget);
      });

      testWidgets('Ricerca per Nome (Mobile): Input e Risultati', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: mockService),
          ),
        );

        // Input testo
        await tester.enterText(find.byType(CupertinoTextField), 'Carbonara');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        // Aspetto caricamento
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Spaghetti Carbonara'), findsOneWidget);
        expect(find.text('1 recipe'), findsOneWidget);
      });

      testWidgets('Gestione Errori (Mobile): Messaggio visibile', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();
        mockService.shouldFail = true;

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: mockService),
          ),
        );

        await tester.enterText(find.byType(CupertinoTextField), 'Pizza');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Failed to search recipes. Try again.'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
      });

      testWidgets('Loading State (Mobile): Mostra Skeleton Loader', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Service LENTO (5 secondi di attesa)
        final slowService = MockRecipesService();
        slowService.delay = const Duration(seconds: 5);

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: slowService),
          ),
        );

        // Avvio ricerca
        await tester.enterText(find.byType(CupertinoTextField), 'Carbonara');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        // Avanzo solo di 100ms (l'API sta ancora caricando)
        await tester.pump(const Duration(milliseconds: 100));

        // Verifico che ci sia lo Skeleton (ClipRRect è usato per l'immagine placeholder)
        // Possiamo anche cercare un Container specifico, ma ClipRRect è un buon indicatore dello scheletro
        expect(find.byType(ClipRRect), findsWidgets);

        // Per sicurezza, verifico che NON ci sia ancora il testo del risultato
        expect(find.text('Spaghetti Carbonara'), findsNothing);

        // Ora finisco l'attesa per chiudere pulito il test
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('Empty State (Mobile): Mostra "No recipes found" se la ricerca è vuota', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(home: RecipesPage(recipesService: mockService)),
        );

        // Cerco qualcosa che il Mock NON conosce (es. "Sassi")
        // Il mock restituisce [] per tutto ciò che non è "Carbonara"
        await tester.enterText(find.byType(CupertinoTextField), 'Sassi');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        // Aspetto la fine del caricamento
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifico che appaia la UI di "Nessun risultato"
        expect(find.text('No recipes found'), findsOneWidget);
        expect(find.text('Search with a different keyword'), findsOneWidget);

        // Verifico che ci sia il bottone per riprovare
        expect(find.text('Try Another Search'), findsOneWidget);

        // Opzionale: Clicco il bottone reset e verifico che torni alla home
        await tester.tap(find.text('Try Another Search'));
        await tester.pump();
        expect(find.text('No recipes found'), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro 12.9 Dimensions
      });

      testWidgets('Ricerca per Ingredienti (Tablet): Griglia e Selezione', (WidgetTester tester) async {
        // Su Tablet la griglia a 4 colonne spalmerà gli elementi.
        // Verifichiamo che siano cliccabili e visibili.
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(
              recipesService: mockService,
              fridgeItems: fridgeData,
            ),
          ),
        );

        // Cambio Tab
        await tester.tap(find.text('By Ingredients'));

        // Animazione Tab
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifico Ingredienti nella griglia
        expect(find.text('Pomodori'), findsOneWidget);
        expect(find.text('Latte'), findsOneWidget);

        // Seleziono Pomodori (Grid Item)
        await tester.tap(find.text('Pomodori'));
        await tester.pump();

        // Premo "Find Recipes" (Che si trova in alto a destra)
        await tester.tap(find.text('Find Recipes'));

        // Aspetto risultati
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifico che la Card del risultato occupi lo spazio (o almeno sia visibile)
        expect(find.text('Tomato Soup'), findsOneWidget);
      });

      testWidgets('Ricerca per Nome (Tablet): Input field accessibile', (WidgetTester tester) async {
        // Verifico che su schermo largo la barra di ricerca non abbia problemi
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: mockService),
          ),
        );

        await tester.enterText(find.byType(CupertinoTextField), 'Carbonara');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifico che il risultato sia mostrato
        expect(find.text('Spaghetti Carbonara'), findsOneWidget);
      });

      testWidgets('Loading State (Tablet): Mostra Skeleton Loader su schermo grande', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final slowService = MockRecipesService();
        slowService.delay = const Duration(seconds: 5);

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: slowService),
          ),
        );

        await tester.enterText(find.byType(CupertinoTextField), 'Carbonara');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        // Verifico Skeleton durante il loading
        await tester.pump(const Duration(milliseconds: 100));

        // Lo skeleton usa ClipRRect per l'area immagine
        expect(find.byType(ClipRRect), findsWidgets);

        // Chiudo il test
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('Empty State (Tablet): UI centrata e leggibile', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(home: RecipesPage(recipesService: mockService)),
        );

        // Cerco qualcosa che non esiste
        await tester.enterText(find.byType(CupertinoTextField), 'Unicorno');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifico UI Empty State
        expect(find.text('No recipes found'), findsOneWidget);

        // Verifica icona grossa della lente
        expect(find.byIcon(CupertinoIcons.search), findsWidgets); // Ne trova 2 (input e icona grande)
      });

      testWidgets('Gestione Errori (Tablet): Messaggio errore visibile e centrato', (WidgetTester tester) async {
        // Configurazione iPad Pro 12.9"
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Configuro il mock per fallire
        final mockService = MockRecipesService();
        mockService.shouldFail = true;

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(recipesService: mockService),
          ),
        );

        // Provo a cercare
        await tester.enterText(find.byType(CupertinoTextField), 'Pizza');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));

        // Aspetto che la chiamata fallisca
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifica: Il messaggio deve apparire
        expect(find.text('Failed to search recipes. Try again.'), findsOneWidget);

        // Verifica visuale: L'icona di errore deve esserci
        expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
      });

    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('RecipesPage - Coverage Expansion', () {

      testWidgets('Ingredients Tab (Empty Fridge): Mostra messaggio vuoto', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(
              recipesService: MockRecipesService(),
              fridgeItems: [], // FRIGO VUOTO
            ),
          ),
        );

        await tester.tap(find.text('By Ingredients'));
        
        // FIX: Usare pump() + Duration invece di pumpAndSettle per evitare timeout da shimmer infinito
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); 

        expect(find.text('Your fridge is empty. Add ingredients to search recipes!'), findsOneWidget);
      });

      testWidgets('Ingredients Search Validation: Mostra errore se nessun ingrediente selezionato', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(
              recipesService: MockRecipesService(),
              fridgeItems: fridgeData,
            ),
          ),
        );

        await tester.tap(find.text('By Ingredients'));
        // FIX: pump instead of pumpAndSettle
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // NON seleziono nulla, provo a premere "Find Recipes" (che è disabilitato/non fa nulla o mostra errore?)
        
        final findBtnFinder = find.text('Find Recipes');
        final findBtnText = tester.widget<Text>(findBtnFinder);
        
        expect(findBtnText.style?.color, CupertinoColors.systemGrey);
        
        // Tap comunque per sicurezza (non deve succedere nulla)
        await tester.tap(findBtnFinder);
        
        // FIX: pump instead of pumpAndSettle
        await tester.pump();
        
        expect(find.byType(ListView), findsNothing); // Nessuna lista risultati
      });

      testWidgets('Reset Search Flow: Tasto Back pulisce la ricerca', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: RecipesPage(
              recipesService: mockService,
              fridgeItems: fridgeData,
            ),
          ),
        );

        // Faccio una ricerca che restituisce risultati
        await tester.enterText(find.byType(CupertinoTextField), 'Carbonara');
        await tester.tap(find.byIcon(CupertinoIcons.arrow_right));
        
        // FIX: Wait for async + no pumpAndSettle
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Verifico presenza barra risultati con tasto Back
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Spaghetti Carbonara'), findsOneWidget);

        // Premo Back
        await tester.tap(find.text('Back'));
        
        // FIX: pump instead of pumpAndSettle
        await tester.pump();

        // Verifico ritorno stato iniziale
        expect(find.text('Back'), findsNothing);
        expect(find.text('Spaghetti Carbonara'), findsNothing);
        expect(find.text('Search recipes...'), findsOneWidget);
      });

    });

  });
}