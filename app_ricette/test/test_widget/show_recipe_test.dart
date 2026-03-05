import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/screens/show_recipe.dart';
import 'package:app_ricette/models/recipe.dart';
import 'package:app_ricette/models/planned_meal.dart';
import 'package:app_ricette/services/recipes_service.dart';
import 'package:app_ricette/services/meal_planner_service.dart';

// Imports for Firebase Mocks
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

// --- MOCK RECIPES SERVICE ---
class MockRecipesService implements RecipesService {
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>?> getRecipeDetails(int id) async {
    if (shouldFail) throw Exception("Network Error");
    await Future.delayed(const Duration(milliseconds: 50));

    return {
      'id': id,
      'title': 'Test Pasta',
      'image': 'test_url',
      'readyInMinutes': 45,
      'servings': 4,
      'summary': 'A delicious <b>test</b> pasta.',
      'extendedIngredients': [
        {'original': '200g Pasta', 'name': 'Pasta', 'amount': 200, 'unit': 'g'},
        {'original': 'Tomato Sauce', 'name': 'Tomato', 'amount': 100, 'unit': 'g'}
      ],
      'analyzedInstructions': [
        {
          'steps': [
            {'number': 1, 'step': 'Boil water.'},
            {'number': 2, 'step': 'Cook pasta.'}
          ]
        }
      ]
    };
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- MOCK MEAL PLANNER SERVICE ---
class MockMealPlannerService implements MealPlannerService {
  bool addMealCalled = false;

  @override
  Future<void> addMeal(PlannedMeal meal) async {
    addMealCalled = true;
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  final testRecipe = Recipe(
      id: 123,
      title: 'Test Pasta',
      image: 'img_url',
      usedIngredientCount: 0,
      missedIngredientCount: 0
  );

  // Setup Firebase Mocks
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'test_uid');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  });

  group('ShowRecipe Page Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      testWidgets('Caricamento & UI (Mobile): Mostra dettagli correttamente', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockRecipes = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: ShowRecipe(
              recipe: testRecipe,
              recipesService: mockRecipes,
              mealPlannerService: MockMealPlannerService(),
              firestore: fakeFirestore, // Injected Mock
              auth: mockAuth,           // Injected Mock
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Test Pasta'), findsWidgets);
        expect(find.text('45 min'), findsOneWidget);
        expect(find.text('Program Recipe'), findsOneWidget);
      });

      testWidgets('Programmazione (Mobile): Modal non overflowa e salva', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockPlanner = MockMealPlannerService();
        final mockRecipes = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: ShowRecipe(
              recipe: testRecipe,
              recipesService: mockRecipes,
              mealPlannerService: mockPlanner,
              firestore: fakeFirestore, // Injected Mock
              auth: mockAuth,           // Injected Mock
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Clicco "Program Recipe"
        await tester.tap(find.text('Program Recipe'));

        // Aspetto apertura modal (NO pumpAndSettle per animazione shimmer background)
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifico Header Modal
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);

        // Salvo
        await tester.tap(find.text('Save'));

        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Scheduled!'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(mockPlanner.addMealCalled, isTrue);
      });
    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro 12.9
      });

      testWidgets('PreLoaded Details (Tablet): Layout spazioso e Pulsante Nascosto', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final preLoaded = {
          'id': 123,
          'title': 'Preloaded Recipe',
          'image': 'test_url',
          'extendedIngredients': [],
          'analyzedInstructions': []
        };

        final preloadRecipe = Recipe(
            id: 123, title: 'Preloaded Recipe', image: 'u', usedIngredientCount: 0, missedIngredientCount: 0
        );

        await tester.pumpWidget(
          CupertinoApp(
            home: ShowRecipe(
              recipe: preloadRecipe,
              preLoadedDetails: preLoaded,
              recipesService: null,
              mealPlannerService: null,
              firestore: fakeFirestore, // Injected Mock
              auth: mockAuth,           // Injected Mock
            ),
          ),
        );

        await tester.pump();

        // Verifico che il contenuto ci sia
        expect(find.text('Preloaded Recipe'), findsWidgets);

        // Il codice nasconde il pulsante se preLoadedDetails != null.
        expect(find.text('Program Recipe'), findsNothing);
      });

      testWidgets('Scroll & Contenuto (Tablet): Verifica elementi lunghi', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockRecipes = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: ShowRecipe(
              recipe: testRecipe,
              recipesService: mockRecipes,
              mealPlannerService: MockMealPlannerService(),
              firestore: fakeFirestore, // Injected Mock
              auth: mockAuth,           // Injected Mock
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('Boil water.'), findsOneWidget);
        expect(find.textContaining('A delicious test pasta'), findsOneWidget);

        // Qui invece, non essendoci preLoadedDetails, il pulsante DEVE esserci
        expect(find.text('Program Recipe'), findsOneWidget);
      });

      testWidgets('Programmazione (Tablet): Il modal appare e salva correttamente', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockPlanner = MockMealPlannerService();
        final mockRecipes = MockRecipesService();

        await tester.pumpWidget(
          CupertinoApp(
            home: ShowRecipe(
              recipe: testRecipe,
              recipesService: mockRecipes,
              mealPlannerService: mockPlanner,
              firestore: fakeFirestore, // Injected Mock
              auth: mockAuth,           // Injected Mock
            ),
          ),
        );

        // Aspetto caricamento
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Apro il modal
        await tester.tap(find.text('Program Recipe'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifico che il modal sia presente
        expect(find.text('Save'), findsOneWidget);

        // Provo a salvare
        await tester.tap(find.text('Save'));
        await tester.pump(const Duration(milliseconds: 500));

        // Verifico successo e chiusura
        expect(find.text('Scheduled!'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(mockPlanner.addMealCalled, isTrue);
      });
    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('ShowRecipe - Coverage Expansion', () {

      testWidgets('Favorites: Toggle Save adds/removes from Firestore', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockRecipes = MockRecipesService();
        
        await tester.pumpWidget(CupertinoApp(
          home: ShowRecipe(
            recipe: testRecipe,
            recipesService: mockRecipes,
            mealPlannerService: MockMealPlannerService(),
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ));
        
        // Wait for load and check saved status
        await tester.pump(const Duration(milliseconds: 100)); 
        await tester.pump(); 

        // Initial state: Not saved (Empty Heart)
        expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.heart_fill), findsNothing);

        // Tap Heart (Save)
        await tester.tap(find.byIcon(CupertinoIcons.heart));
        // Use pump instead of pumpAndSettle due to infinite shimmer animation in background
        await tester.pump(); 
        await tester.pump(const Duration(milliseconds: 100)); 

        // New state: Saved (Filled Heart)
        expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
        
        // Check Firestore
        final snapshot = await fakeFirestore
            .collection('users')
            .doc('test_uid')
            .collection('saved_recipes')
            .doc('${testRecipe.id}')
            .get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['title'], testRecipe.title);

        // Tap Heart Again (Unsave)
        await tester.tap(find.byIcon(CupertinoIcons.heart_fill));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); 

        // Back to empty
        expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
        final snapshotAfter = await fakeFirestore
            .collection('users')
            .doc('test_uid')
            .collection('saved_recipes')
            .doc('${testRecipe.id}')
            .get();
        expect(snapshotAfter.exists, isFalse);
      });

      testWidgets('Favorites: Loads initial saved state', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Pre-populate Firestore with this recipe
        await fakeFirestore
            .collection('users')
            .doc('test_uid')
            .collection('saved_recipes')
            .doc('${testRecipe.id}')
            .set({
              'title': testRecipe.title,
              'image': 'img'
            });

        await tester.pumpWidget(CupertinoApp(
          home: ShowRecipe(
            recipe: testRecipe,
            recipesService: MockRecipesService(),
            mealPlannerService: MockMealPlannerService(),
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ));

        await tester.pump(const Duration(milliseconds: 100)); // Load details
        await tester.pump(); // Update UI

        // Should be filled heart because it was already in Firestore
        expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
      });

      testWidgets('Load Error: Handles API failure gracefully', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockRecipes = MockRecipesService();
        mockRecipes.shouldFail = true; // Trigger failure

        await tester.pumpWidget(CupertinoApp(
          home: ShowRecipe(
            recipe: testRecipe,
            recipesService: mockRecipes,
            mealPlannerService: MockMealPlannerService(),
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ));

        // Wait for async call to fail
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Should stop loading. 
        // In the code: if (_recipeDetails == null) return Container();
        // So we expect to find a Container in the body, and NO detailed text like "45 min".
        expect(find.text('45 min'), findsNothing);
        expect(find.byType(Container), findsWidgets);
      });
    });

  });
}