import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/screens/plan_page.dart';
import 'package:app_ricette/screens/missing_ingredient_page.dart';
import 'package:app_ricette/models/ingredient.dart';
import 'package:app_ricette/models/planned_meal.dart';
import 'package:app_ricette/models/recipe.dart';
import 'package:app_ricette/services/meal_planner_service.dart';

// --- MOCK PLANNER SERVICE ---
class MockMealPlannerService extends ChangeNotifier implements MealPlannerService {
  List<PlannedMeal> _meals = [];
  bool removeCalled = false;

  void setMeals(List<PlannedMeal> meals) {
    _meals = meals;
    notifyListeners();
  }

  @override
  Future<void> loadMeals() async {
    await Future.delayed(const Duration(milliseconds: 50));
    notifyListeners();
  }

  @override
  List<PlannedMeal> getMeals() => _meals;

  @override
  Future<void> removeMeal(String id) async {
    _meals.removeWhere((m) => m.id == id);
    removeCalled = true;
    notifyListeners();
  }

  @override
  Future<void> removeMissingIngredient(String name) async {
    // Dummy implementation
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Dati Mock condivisi
  final fridgeData = [
    Ingredient(nome: 'Pasta', genericName: 'Pasta', quantity: '500', unit: 'g', scadenza: '2030', note: ''),
  ];

  final plannedMeal = PlannedMeal(
    id: 'meal_1',
    date: DateTime.now(),
    cachedDetails: {},
    recipe: Recipe(
        id: 1,
        title: 'Pasta al Pesto',
        image: 'url',
        usedIngredientCount: 1,
        missedIngredientCount: 1,
        missedIngredients: [
          IngredientData(name: 'Basilico', amount: 10, unit: 'g')
        ],
        usedIngredients: []
    ),
  );

  group('PlanPage Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      setUp(() {
        // iPhone 13 Dimensions: 1170x2532 (Ratio 3.0) -> 390x844 Logical
      });

      testWidgets('Stato Vuoto (Mobile): Mostra messaggio al centro', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('No meals planned yet'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.calendar_today), findsOneWidget);
      });

      testWidgets('Lista Pasti (Mobile): Renderizza correttamente in verticale', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );

        mockService.setMeals([plannedMeal]);
        await tester.pumpAndSettle();

        // Verifico Meal List
        expect(find.text('Pasta al Pesto'), findsOneWidget);

        // Verifico Missing Ingredients
        expect(find.text('Missing Ingredients'), findsOneWidget);
        expect(find.text('Basilico'), findsOneWidget);
        expect(find.text('x 1'), findsOneWidget);
      });

      testWidgets('Interazione (Mobile): Swipe cancella elemento', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();
        mockService.setMeals([plannedMeal]);

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final mealFinder = find.text('Pasta al Pesto');

        // Esegui Swipe da Destra a Sinistra
        // Su mobile, -500 è sufficiente per triggerare il dismiss
        await tester.drag(mealFinder, const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(mockService.removeCalled, isTrue);
        expect(find.text('Pasta al Pesto'), findsNothing);
      });

      testWidgets('Layout (Mobile): Non mostra i titoli della versione tablet', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        mockService.setMeals([plannedMeal]);

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verifiche
        // Deve esserci il titolo Mobile
        expect(find.text('Missing Ingredients'), findsOneWidget);
        // NON deve esserci il titolo Tablet
        expect(find.text('Scheduled Meals'), findsNothing);
      });
    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro 12.9 Dimensions: 2048x2732 (Ratio 2.0) -> 1024x1366 Logical
      });

      testWidgets('Layout (Tablet): Mostra i titoli delle due colonne', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();
        mockService.setMeals([plannedMeal]);

        await tester.pumpWidget(
            CupertinoApp(home: PlanPage(fridgeItems: fridgeData, plannerService: mockService))
        );
        await tester.pumpAndSettle();

        // Verifico del layout a due colonne
        expect(find.text('Scheduled Meals'), findsOneWidget);
        expect(find.text('Shopping List'), findsOneWidget);

        // Verifico che NON ci sia il titolo della versione mobile
        expect(find.text('Missing Ingredients'), findsNothing);
      });

      testWidgets('Layout (Tablet): Contenuto si estende senza overflow', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );

        mockService.setMeals([plannedMeal]);
        await tester.pumpAndSettle();

        // Verifico che gli elementi ci siano
        expect(find.text('Pasta al Pesto'), findsOneWidget);
        expect(find.text('Basilico'), findsOneWidget);
      });

      testWidgets('Interazione (Tablet): Swipe funziona anche su schermo largo', (WidgetTester tester) async {
        // Questo test è importante perché su schermi larghi, a volte la soglia di dismiss
        // relativa alla larghezza (es. 40%) richiede uno swipe più lungo.
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();
        mockService.setMeals([plannedMeal]);

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mealFinder = find.text('Pasta al Pesto');

        // Su Tablet proviamo uno swipe più deciso (-800) per essere sicuri
        await tester.drag(mealFinder, const Offset(-800, 0));
        await tester.pumpAndSettle();

        expect(mockService.removeCalled, isTrue, reason: "Swipe su tablet deve cancellare elemento");
        expect(find.text('No meals planned yet'), findsOneWidget);
      });
    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('PlanPage - Coverage Expansion', () {

      testWidgets('Logic (Aggregation): Quantità ingredienti vengono sommate', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        // Creiamo due pasti identici, entrambi richiedono 'Basilico'
        // Il risultato atteso è che nella lista della spesa appaia "x 2"
        final meals = [plannedMeal, plannedMeal]; // Due volte lo stesso pasto (o simile)

        mockService.setMeals(meals);

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData,
              plannerService: mockService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica che ci sia scritto "x 2" sotto Basilico
        expect(find.text('x 2'), findsOneWidget);
      });

      testWidgets('Logic (Filter): Ingredienti già in frigo NON appaiono nella lista spesa', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();

        // Simuliamo che il Basilico sia già in frigo
        final extendedFridge = [
          ...fridgeData,
          Ingredient(nome: 'Basilico', genericName: 'basil', quantity: '1', unit: 'bunch', scadenza: '', note: '')
        ];

        mockService.setMeals([plannedMeal]); // Richiede Basilico

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: extendedFridge, // Passo frigo con Basilico
              plannerService: mockService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica che Basilico NON sia nella lista Missing Ingredients
        // Nota: "Basilico" potrebbe apparire in altri contesti se non filtrato,
        // ma qui verifichiamo che la lista spesa sia vuota o non contenga l'elemento.
        // Se il filtro funziona, _generateShoppingList ritorna mappa vuota.
        expect(find.text('No missing ingredients needed'), findsOneWidget);
        expect(find.text('Basilico'), findsNothing);
      });

      testWidgets('Navigation: Tap su ingrediente apre MissingIngredientPage', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockService = MockMealPlannerService();
        mockService.setMeals([plannedMeal]); // Richiede Basilico (mancante)

        await tester.pumpWidget(
          CupertinoApp(
            home: PlanPage(
              fridgeItems: fridgeData, // Basilico manca
              plannerService: mockService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap sulla riga dell'ingrediente
        await tester.tap(find.text('Basilico'));
        await tester.pumpAndSettle();

        // Verifica apertura pagina dettagli
        expect(find.byType(MissingIngredientPage), findsOneWidget);
        // Verifica contenuto pagina dettagli
        expect(find.text('Basilico'), findsOneWidget);
      });

    });

  });
}