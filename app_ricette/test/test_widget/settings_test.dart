import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:app_ricette/screens/settings_page.dart';
import 'package:app_ricette/services/notification_service.dart';
import 'package:app_ricette/services/meal_planner_service.dart';
import 'package:app_ricette/models/planned_meal.dart';

// --- MOCKS ---

class FakeUser implements User {
  @override final String uid = 'test_uid_123';
  @override final String? email = 'mario.rossi@test.com';
  @override final String? photoURL = null;

  bool deleteCalled = false;
  bool shouldThrowOnDelete = false; // Control flag for error testing

  @override
  Future<void> delete() async {
    if (shouldThrowOnDelete) {
      throw FirebaseAuthException(code: 'requires-recent-login', message: 'Re-login required');
    }
    deleteCalled = true;
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements FirebaseAuth {
  final FakeUser _fakeUser = FakeUser();
  bool signOutCalled = false;

  @override User? get currentUser => _fakeUser;

  // Getter per accedere allo stato del fakeUser nei test
  FakeUser get testUser => _fakeUser;

  @override Future<void> signOut() async { signOutCalled = true; }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationService implements NotificationService {
  bool checkCalled = false;
  bool cancelCalled = false;

  @override Future<void> checkAndScheduleExpiringProducts() async { checkCalled = true; }
  @override Future<void> cancelAllNotifications() async { cancelCalled = true; }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock MealPlannerService to handle loadMeals calls in SettingsPage
class FakeMealPlannerService implements MealPlannerService {
  List<PlannedMeal> _mockMeals = [];

  void setMeals(List<PlannedMeal> meals) {
    _mockMeals = meals;
  }

  @override
  Future<void> loadMeals() async {}
  
  @override
  List<PlannedMeal> getMeals() => _mockMeals;

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  late FakeFirebaseFirestore fakeFirestore;
  late FakeAuth fakeAuth;
  late FakeNotificationService fakeNotificationService;
  late FakeMealPlannerService fakeMealPlannerService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled_test_uid_123': true,
      'reminder_index_test_uid_123': 2, // Default 3 days
    });

    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeAuth();
    fakeNotificationService = FakeNotificationService();
    fakeMealPlannerService = FakeMealPlannerService();
  });

  group('SettingsPage Tests', () {

    // ---------------------------------------------------------------------------
    // EXISTING MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      setUp(() {
        // iPhone 13 width
      });

      testWidgets('Statistiche (Mobile): Carica e mostra i dati corretti dal DB', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Setup "Saved Recipes" -> Aggiungiamo 2 ricette
        await fakeFirestore.collection('users').doc('test_uid_123').collection('saved_recipes').add({'title': 'Recipe 1'});
        await fakeFirestore.collection('users').doc('test_uid_123').collection('saved_recipes').add({'title': 'Recipe 2'});

        // Setup "Est. Savings" -> Aggiungiamo prodotti usati per calcolare il risparmio
        await fakeFirestore.collection('users').doc('test_uid_123').collection('used_products').add({
          'nome': 'Latte',
          'estimatedValue': 1.50, // 1.50€
        });
        await fakeFirestore.collection('users').doc('test_uid_123').collection('used_products').add({
          'nome': 'Uova',
          'estimatedValue': 2.50, // 2.50€
        });
        // Totale atteso: 1.50 + 2.50 = 4.00

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verifiche
        expect(find.text('2'), findsOneWidget);

        expect(find.text('€4.00'), findsOneWidget);
      });

      testWidgets('Reminder Picker (Mobile): Cambio opzione promemoria', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 days before'), findsOneWidget);

        await tester.tap(find.text('3 days before'));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoPicker), findsOneWidget);

        await tester.drag(find.byType(CupertinoPicker), const Offset(0, 50));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(find.text('3 days before'), findsNothing);
      });

      testWidgets('Delete Account (Mobile): Flusso completo cancellazione', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
              authPageBuilder: (_) => Container(key: const Key('auth_page')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deleteBtn = find.text('Delete Account');
        // FIX: Scroll more aggressively to ensure visibility on small screens
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000)); 
        await tester.pumpAndSettle();
        
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

        await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete Account'));
        await tester.pumpAndSettle();

        expect(fakeAuth.testUser.deleteCalled, isTrue);
        expect(find.byKey(const Key('auth_page')), findsOneWidget);
        expect(find.text('Account Deleted'), findsOneWidget);
      });

      testWidgets('Avatar Selection (Mobile): Apre modal, seleziona avatar e salva preferenza', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editIcon = find.byIcon(CupertinoIcons.pencil);
        await tester.tap(editIcon);
        await tester.pumpAndSettle();

        expect(find.text('Choose an Avatar'), findsOneWidget);

        final avatarItems = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(GestureDetector),
        );
        expect(avatarItems, findsAtLeastNWidgets(6));

        await tester.tap(avatarItems.last);
        await tester.pumpAndSettle();

        expect(find.text('Choose an Avatar'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('selected_avatar_index_test_uid_123'), 5);
      });

      testWidgets('Notifications (Mobile): Toggle switch ON/OFF chiama il servizio corretto', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        fakeNotificationService.cancelCalled = false;
        fakeNotificationService.checkCalled = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byType(CupertinoSwitch);
        expect((tester.widget(switchFinder) as CupertinoSwitch).value, isTrue);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect((tester.widget(switchFinder) as CupertinoSwitch).value, isFalse);
        expect(fakeNotificationService.cancelCalled, isTrue);
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications_enabled_test_uid_123'), isFalse);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect((tester.widget(switchFinder) as CupertinoSwitch).value, isTrue);
        expect(fakeNotificationService.checkCalled, isTrue);
      });

      testWidgets('Logout (Mobile): Esegue SignOut e naviga alla AuthPage', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
              authPageBuilder: (_) => Container(key: const Key('auth_page_dummy')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtn = find.text('Step Out');
        // FIX: Scroll more aggressively
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(fakeAuth.signOutCalled, isTrue);
        expect(find.byKey(const Key('auth_page_dummy')), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
      });

    });

    // ---------------------------------------------------------------------------
    // EXISTING TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {

      setUp(() {
        // iPad Pro
      });

      testWidgets('Reminder Picker (Tablet): Funziona su schermo grande', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('3 days before'));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoPicker), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      });

      testWidgets('Delete Account (Tablet): Dialog non sformato', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets('Statistiche (Tablet): Layout e dati corretti su schermo largo', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Ricette Salvate (2 items)
        await fakeFirestore.collection('users').doc('test_uid_123').collection('saved_recipes').add({'title': 'R1'});
        await fakeFirestore.collection('users').doc('test_uid_123').collection('saved_recipes').add({'title': 'R2'});

        // Risparmi Stimati (Simuliamo 5.00€ di valore usato)
        await fakeFirestore.collection('users').doc('test_uid_123').collection('used_products').add({
          'nome': 'Bistecca',
          'estimatedValue': 5.00,
        });

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verifiche
        expect(find.text('2'), findsOneWidget);

        expect(find.text('€5.00'), findsOneWidget);

        // Verifichiamo che le icone delle statistiche siano presenti
        expect(find.byIcon(CupertinoIcons.book_fill), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.money_euro_circle_fill), findsOneWidget);

        expect(find.text('Your FridgeWizard Stats'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
      });

      testWidgets('Avatar Selection (Tablet): Modal Grid funziona e salva su schermo largo', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editIcon = find.byIcon(CupertinoIcons.pencil);
        await tester.tap(editIcon);
        await tester.pumpAndSettle();

        expect(find.text('Choose an Avatar'), findsOneWidget);

        final avatarItems = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(GestureDetector),
        );

        expect(avatarItems, findsAtLeastNWidgets(6));

        await tester.tap(avatarItems.at(2));
        await tester.pumpAndSettle(); 

        expect(find.text('Choose an Avatar'), findsNothing);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('selected_avatar_index_test_uid_123'), 2);
      });

      testWidgets('Notifications (Tablet): Switch accessibile e funzionante', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        fakeNotificationService.cancelCalled = false;

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byType(CupertinoSwitch);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(fakeNotificationService.cancelCalled, isTrue);
        expect((tester.widget(switchFinder) as CupertinoSwitch).value, isFalse);
      });

      testWidgets('Logout (Tablet): Bottone visibile e funzionante', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
              authPageBuilder: (_) => Container(key: const Key('auth_page_dummy')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final logoutBtn = find.text('Step Out');
        expect(logoutBtn, findsOneWidget);

        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(fakeAuth.signOutCalled, isTrue);
        expect(find.byKey(const Key('auth_page_dummy')), findsOneWidget);
      });

    });

    // ---------------------------------------------------------------------------
    // NEW: COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('SettingsPage - Coverage Expansion', () {

      testWidgets('Time Picker: Interazione e salvataggio preferenze', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default Time is 9:00
        expect(find.text('09:00'), findsOneWidget);

        // Tap on Time row
        await tester.tap(find.text('09:00'));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoDatePicker), findsOneWidget);

        // Change time (drag picker)
        // Note: interacting with CupertinoDatePicker in tests can be tricky.
        // We verify mostly that it opens and Done closes it and saves something.
        
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Verify Preferences updated (even if time didn't change, keys should be set)
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('notification_hour_test_uid_123'), isNotNull);
        expect(prefs.getInt('notification_minute_test_uid_123'), isNotNull);
      });

      testWidgets('Delete Account: Cancellazione annullata', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FIX: Scroll aggressively to reach bottom buttons
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify account NOT deleted
        expect(fakeAuth.testUser.deleteCalled, isFalse);
        expect(find.text('Account Deleted'), findsNothing);
      });

      testWidgets('Delete Account Error: Gestione errore (es. re-login richiesto)', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Configure User Mock to throw error
        fakeAuth.testUser.shouldThrowOnDelete = true;

        await tester.pumpWidget(
          CupertinoApp(
            home: SettingsPage(
              auth: fakeAuth,
              notificationService: fakeNotificationService,
              firestore: fakeFirestore,
              mealPlannerService: fakeMealPlannerService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FIX: Scroll aggressively to reach bottom buttons
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
        await tester.pumpAndSettle();

        // Trigger Delete Flow
        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete Account'));
        await tester.pumpAndSettle();

        // Expect Error Dialog
        expect(find.text('Error'), findsOneWidget);
        expect(find.textContaining('For security reasons, please log out'), findsOneWidget);
        
        // Close Error Dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });

    });

  });
}