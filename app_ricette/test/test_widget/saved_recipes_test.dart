import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_ricette/screens/saved_recipes_page.dart';
import 'package:app_ricette/screens/show_recipe.dart';


// --- MOCKS ---

class FakeUser implements User {
  @override final String uid = 'test_uid';
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements FirebaseAuth {
  final FakeUser _fakeUser = FakeUser();
  @override User? get currentUser => _fakeUser;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// FIX: Intercept network calls to prevent crashes when ShowRecipe loads real services
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeAuth fakeAuth;

  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeAuth();
  });

  group('SavedRecipesPage Tests', () {
    
    // Helper function to pump the widget
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: SavedRecipesPage(
            firestore: fakeFirestore,
            auth: fakeAuth,
          ),
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // MOBILE VIEW TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {
      
      setUp(() {
        // iPhone 13 Dimensions
      });

      testWidgets('Empty State: Mostra messaggio quando non ci sono ricette', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await pumpPage(tester);
        await tester.pumpAndSettle(); // Wait for async loading

        expect(find.text('No Saved Recipes'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.heart_slash), findsOneWidget);
        expect(find.text('Recipes you save will appear here'), findsOneWidget);
      });

      testWidgets('Populated State: Mostra lista delle ricette salvate', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Add mock data
        await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').add({
          'id': 101,
          'title': 'Pasta Carbonara',
          'image': 'img_url_1',
          'savedAt': DateTime.now(),
        });
        await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').add({
          'id': 102,
          'title': 'Tiramisu',
          'image': 'img_url_2',
          'savedAt': DateTime.now().subtract(const Duration(days: 1)),
        });

        await pumpPage(tester);
        await tester.pumpAndSettle();

        expect(find.text('Pasta Carbonara'), findsOneWidget);
        expect(find.text('Tiramisu'), findsOneWidget);
        // "Saved" text appears in every card
        expect(find.text('Saved'), findsNWidgets(2)); 
      });

      testWidgets('Delete Flow: Cancellazione ricetta dalla lista e dal DB', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Setup: Add one recipe
        // Ensure Firestore Doc ID matches the 'id' field value for consistent deletion logic
        await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').doc('101').set({
          'id': 101,
          'title': 'Recipe to Delete',
          'image': '',
          'savedAt': DateTime.now(),
        });

        await pumpPage(tester);
        await tester.pumpAndSettle();

        expect(find.text('Recipe to Delete'), findsOneWidget);

        // 1. Tap Delete Icon
        await tester.tap(find.byIcon(CupertinoIcons.trash));
        await tester.pumpAndSettle();

        // 2. Verify Dialog
        expect(find.text('Remove Recipe'), findsOneWidget);
        
        // FIX: Match the exact full text of the dialog content.
        // Previously find.textContaining matched both this dialog AND the list item in the background.
        expect(
          find.text('Are you sure you want to remove "Recipe to Delete" from your saved recipes?'), 
          findsOneWidget
        );

        // 3. Confirm Delete
        await tester.tap(find.text('Remove'));
        
        // Wait for dialog close and async deletion
        await tester.pumpAndSettle(); 
        await tester.pump(const Duration(milliseconds: 100)); 

        // 4. Verify Removal from UI
        expect(find.text('Recipe to Delete'), findsNothing);
        expect(find.text('No Saved Recipes'), findsOneWidget); // Should be empty now

        // 5. Verify Removal from Firestore
        final snapshot = await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').get();
        expect(snapshot.docs.isEmpty, isTrue);
      });

      testWidgets('Navigation: Tap apre ShowRecipe', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').add({
          'id': 999,
          'title': 'Nav Recipe',
          'image': '',
          'savedAt': DateTime.now(),
        });

        await pumpPage(tester);
        await tester.pumpAndSettle();

        // Tap on the recipe card
        await tester.tap(find.text('Nav Recipe'));
        
        // Wait for navigation animation
        // Use pump instead of pumpAndSettle because ShowRecipe has an infinite shimmer animation
        await tester.pump(); 
        await tester.pump(const Duration(milliseconds: 500)); 

        // Verify ShowRecipe page is pushed
        expect(find.byType(ShowRecipe), findsOneWidget);
        
        // Verify title is passed correctly
        expect(find.text('Nav Recipe'), findsWidgets); 
      });
    });

    // ---------------------------------------------------------------------------
    // TABLET VIEW TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {
      
      testWidgets('Layout Grid (Tablet): Verifica rendering su schermo largo', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Add multiple items
        for (int i = 0; i < 3; i++) {
          await fakeFirestore.collection('users').doc('test_uid').collection('saved_recipes').add({
            'id': i,
            'title': 'Recipe $i',
            'image': '',
            'savedAt': DateTime.now(),
          });
        }

        await pumpPage(tester);
        await tester.pumpAndSettle();

        expect(find.text('Recipe 0'), findsOneWidget);
        expect(find.text('Recipe 1'), findsOneWidget);
        expect(find.text('Recipe 2'), findsOneWidget);
        
        // Verifica che la lista scrollabile sia presente
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

  });
}