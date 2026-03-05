import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/screens/auth_page.dart';
import 'package:app_ricette/screens/home_page.dart';
import 'package:app_ricette/screens/login_page.dart';
import 'package:app_ricette/screens/recipes_page.dart';
import 'package:app_ricette/screens/show_recipe.dart';
import 'package:app_ricette/screens/plan_page.dart';
import 'package:app_ricette/screens/missing_ingredient_page.dart';
import 'package:app_ricette/screens/add_product_manual_page.dart';
import 'package:app_ricette/screens/settings_page.dart';

class TestHelper {
  
  static String generateRandomEmail() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'test_$timestamp@example.com';
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder, {int seconds = 1}) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(); 
    await tester.pump(Duration(seconds: seconds)); 
  }

  // --- NAVIGATION HELPERS ---
  
  Future<void> goBack(WidgetTester tester) async {
    print('Going back');
    final backBtn = find.byType(CupertinoNavigationBarBackButton);
    await tapAndWait(tester, backBtn);
  }

  // --- AUTH HELPERS ---

  Future<void> ensureLoggedIn(WidgetTester tester) async {
    print('Checking initial auth state');
    await tester.pump(const Duration(milliseconds: 500));

    bool onHome = find.byType(HomePage).evaluate().isNotEmpty;
    bool onLogin = find.byType(LoginPage).evaluate().isNotEmpty;

    if (onHome) {
      print('User found on HomePage. Waiting for loading to finish');
      await waitFor(tester, find.byKey(const Key('nav_Search')), timeout: const Duration(seconds: 10));
      return;
    } else if (onLogin) {
      print('User found on LoginPage. Logging in');
      final email = generateRandomEmail();
      await performRegistration(tester, email, 'Password123!');
    } else {
      await tester.pump(const Duration(seconds: 2));
      if (find.byType(LoginPage).evaluate().isNotEmpty) {
        final email = generateRandomEmail();
        await performRegistration(tester, email, 'Password123!');
      } else if (find.byType(HomePage).evaluate().isNotEmpty) {
        await waitFor(tester, find.byKey(const Key('nav_Search')), timeout: const Duration(seconds: 10));
      }
    }
  }

  Future<void> ensureLoggedOut(WidgetTester tester) async {
    print('Checking initial auth state (expecting Logout)');
    await tester.pump(const Duration(milliseconds: 500));

    bool onHome = find.byType(HomePage).evaluate().isNotEmpty;
    bool onLogin = find.byType(LoginPage).evaluate().isNotEmpty;

    if (onHome) {
      print('User found on HomePage. Logging out');
      await performLogout(tester);
    } else if (onLogin) {
      print('User found on LoginPage. Ready to register.');
    } else {
      await tester.pump(const Duration(seconds: 2));
      if (find.byType(HomePage).evaluate().isNotEmpty) {
        await performLogout(tester);
      }
    }
  }

  Future<void> performLogout(WidgetTester tester) async {
    await waitFor(tester, find.byKey(const Key('nav_Profile')));
    await tapAndWait(tester, find.byKey(const Key('nav_Profile')));
    
    final logoutButton = find.text('Log Out');
    await tapAndWait(tester, logoutButton.first);

    final confirmLogout = find.widgetWithText(CupertinoDialogAction, 'Log Out');
    await tapAndWait(tester, confirmLogout);
    
    await waitFor(tester, find.byType(LoginPage));
  }

  // Specific for SettingsPage structure
  Future<void> logoutFromSettings(WidgetTester tester) async {
    print('Navigating to Profile');
    await tapAndWait(tester, find.byKey(const Key('nav_Profile')));
    expect(find.byType(SettingsPage), findsOneWidget);

    print('Scrolling to Logout');

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));

    await tester.pump(const Duration(seconds: 1)); 
    
    print('Tapping Step Out');

    final logoutBtn = find.byKey(const Key('settingsLogoutButton'));
    await tester.ensureVisible(logoutBtn);
    await tapAndWait(tester, logoutBtn);
    
    await waitFor(tester, find.byType(LoginPage));
  }

  Future<void> performRegistration(WidgetTester tester, String email, String password) async {
    await waitFor(tester, find.byType(LoginPage));
    
    if (find.text('Create your account').evaluate().isNotEmpty) {
       print('Switching to Register mode');
       await tapAndWait(tester, find.byKey(const Key('toggleAuthMode')), seconds: 1);
    }

    print('Entering credentials');
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await tester.pump(const Duration(milliseconds: 100)); 

    print('Tapping Register');
    await tapAndWait(tester, find.byKey(const Key('authButton')), seconds: 3);
    
    await waitFor(tester, find.byKey(const Key('addProductButton')), timeout: const Duration(seconds: 15));
  }

  Future<void> performLogin(WidgetTester tester, String email, String password) async {
    await waitFor(tester, find.byType(LoginPage));
    
    // Default assumption: We are in Login mode after logout.
    
    print('Entering login credentials');
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await tester.pump(const Duration(milliseconds: 100)); 

    print('Tapping Log In');
    await tapAndWait(tester, find.byKey(const Key('authButton')), seconds: 3);
    
    await waitFor(tester, find.byKey(const Key('addProductButton')), timeout: const Duration(seconds: 15));
  }

  // --- PANTRY HELPERS  ---

  Future<void> addPantryItem(WidgetTester tester, {required String name, required String qty}) async {
    print('Adding pantry item: $name');
    
    await waitFor(tester, find.byKey(const Key('addProductButton')), timeout: const Duration(seconds: 10));
    await tapAndWait(tester, find.byKey(const Key('addProductButton')), seconds: 1);
    
    await tapAndWait(tester, find.byKey(const Key('addManuallyAction')), seconds: 1);
    
    await tester.enterText(find.byKey(const Key('manualNameField')), name);
    await tester.enterText(find.byKey(const Key('manualQtyField')), qty);

    await tapAndWait(tester, find.byKey(const Key('manualDatePicker')));
    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 50)); 
    await tester.pump(const Duration(milliseconds: 500));
    await tapAndWait(tester, find.byKey(const Key('manualDateDone')));

    await tapAndWait(tester, find.byKey(const Key('manualAddButton')));
    
    final itemFinder = find.text(name).hitTestable();
    await waitFor(tester, itemFinder, timeout: const Duration(seconds: 10));
  }

  // --- RECIPE FLOW HELPERS ---

  Future<void> searchForRecipe(WidgetTester tester, String query) async {
    print('Searching for: $query');
    final searchField = find.byKey(const Key('recipeSearchField'));
    await tester.ensureVisible(searchField); 
    await tester.enterText(searchField, query);
    await tester.pump(const Duration(milliseconds: 500));

    final searchBtn = find.byKey(const Key('recipeSearchButton'));
    await tapAndWait(tester, searchBtn, seconds: 1);

    print('Waiting for API results');
    await tester.pump(const Duration(seconds: 5)); 
  }

  // --- NEW: INGREDIENT SEARCH HELPERS ---

  Future<void> switchToIngredientSearch(WidgetTester tester) async {
    print('Checking for stuck search state');
    
    if (find.text('Back').evaluate().isNotEmpty) {
      print('Found active search results. Resetting search');
      await tapAndWait(tester, find.text('Back'));
      print('Waiting for "By Ingredients" tab to appear');
      // FIX: Use waitFor instead of pumpAndSettle to avoid infinite animation loops
      await waitFor(tester, find.text('By Ingredients'));
    }

    print('Switching to Ingredient Search Tab');
    await tapAndWait(tester, find.text('By Ingredients'));
  }

  Future<void> selectIngredient(WidgetTester tester, String name) async {
    print('Selecting ingredient: $name');
    final itemKey = find.byKey(Key('ingredient_item_$name'));
    
    await tester.ensureVisible(itemKey);
    await tapAndWait(tester, itemKey, seconds: 0); 
  }

  Future<void> tapFindRecipes(WidgetTester tester) async {
    print('Tapping Find Recipes');
    await tapAndWait(tester, find.byKey(const Key('findRecipesButton')), seconds: 1);
    print('Waiting for API results');
    await tester.pump(const Duration(seconds: 5)); 
  }

  Future<void> openFirstRecipe(WidgetTester tester) async {
    final firstCardImage = find.byType(Image).first;
    print('Opening first result');
    await tapAndWait(tester, firstCardImage, seconds: 2);
    expect(find.byType(ShowRecipe), findsOneWidget);
  }

  Future<void> scheduleRecipe(WidgetTester tester) async {
    print('Tapping Program Recipe');
    final programBtn = find.byKey(const Key('programRecipeButton'));
    await waitFor(tester, programBtn, timeout: const Duration(seconds: 10));
    await tester.ensureVisible(programBtn); 
    await tapAndWait(tester, programBtn, seconds: 1);

    print('Saving schedule');
    final saveBtn = find.byKey(const Key('scheduleSaveButton'));
    await tapAndWait(tester, saveBtn, seconds: 1);

    print('Waiting for success dialog');
    final okBtn = find.text("OK");
    await waitFor(tester, okBtn);
    await tapAndWait(tester, okBtn, seconds: 1);
  }

  Future<void> scheduleRecipeNextDay(WidgetTester tester) async {
    print('Tapping Program Recipe');
    final programBtn = find.byKey(const Key('programRecipeButton'));
    await waitFor(tester, programBtn, timeout: const Duration(seconds: 10));
    await tester.ensureVisible(programBtn); 
    await tapAndWait(tester, programBtn, seconds: 1);

    print('Scrolling to next day');
    await tester.drag(find.byKey(const Key('scheduleDatePicker')), const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 500));

    print('Saving schedule');
    final saveBtn = find.byKey(const Key('scheduleSaveButton'));
    await tapAndWait(tester, saveBtn, seconds: 1);

    print('Waiting for success dialog');
    final okBtn = find.text("OK");
    await waitFor(tester, okBtn);
    await tapAndWait(tester, okBtn, seconds: 1);
  }

  // --- PLAN & SHOPPING LIST HELPERS ---

  Future<void> navigateToPlan(WidgetTester tester) async {
    print('Navigating to Plan Tab');
    await tapAndWait(tester, find.byKey(const Key('nav_Plan')));
    expect(find.byType(PlanPage), findsOneWidget);
  }

  Future<String> markFirstIngredientAsBought(WidgetTester tester, {required String qty}) async {
    print('Tapping first missing ingredient');
    await tapAndWait(tester, find.byKey(const Key('missingIngredient_0')));
    expect(find.byType(MissingIngredientPage), findsOneWidget);

    print('Marking as Bought');
    await tapAndWait(tester, find.byKey(const Key('markAsBoughtButton')));
    expect(find.byType(AddProductManualPage), findsOneWidget);

    final nameFieldFinder = find.byKey(const Key('manualNameField'));
    final nameField = tester.widget<CupertinoTextField>(nameFieldFinder);
    final ingredientName = nameField.controller?.text ?? "Unknown";
    print('Identified ingredient to buy: $ingredientName');

    print('Filling product details');
    await tester.enterText(find.byKey(const Key('manualQtyField')), qty);

    print('Selecting date');
    await tapAndWait(tester, find.byKey(const Key('manualDatePicker')));
    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 50)); 
    await tester.pump(const Duration(milliseconds: 500));
    await tapAndWait(tester, find.byKey(const Key('manualDateDone')));

    print('Confirming purchase');
    await tapAndWait(tester, find.byKey(const Key('manualAddButton')));

    await waitForAbsence(tester, find.byType(MissingIngredientPage));
    await waitFor(tester, find.byType(PlanPage));
    
    return ingredientName;
  }

  Future<void> removeFirstIngredientFromList(WidgetTester tester) async {
    print('Tapping  first missing ingredient');
    await tapAndWait(tester, find.byKey(const Key('missingIngredient_0')));
    expect(find.byType(MissingIngredientPage), findsOneWidget);

    print('Removing ingredient');
    await tapAndWait(tester, find.byKey(const Key('removeIngredientButton')));
    
    await tapAndWait(tester, find.byKey(const Key('confirmRemoveButton')));
    
    await waitForAbsence(tester, find.byType(MissingIngredientPage));
    await waitFor(tester, find.byType(PlanPage));
  }

  Future<void> deleteFirstPlannedMeal(WidgetTester tester) async {
    print('Deleting first planned meal');
    final mealItem = find.byKey(const Key('plannedMeal_0'));
    await tester.drag(mealItem, const Offset(-1000, 0));
    await tester.pump(); 
    await tester.pump(const Duration(milliseconds: 800)); 
    await waitFor(tester, find.text('No meals planned yet'), timeout: const Duration(seconds: 5));
  }

  Future<void> verifyNoPlannedMeals(WidgetTester tester) async {
    print('Verifying meal list is empty');
    expect(find.text('No meals planned yet'), findsOneWidget);
    expect(find.text("Missing Ingredients"), findsNothing);
  }

  Future<void> verifyIngredientNotMissing(WidgetTester tester, String name) async {
    print('Verifying $name is NOT in missing list');
    expect(find.text(name).hitTestable(), findsNothing);
  }

  Future<void> verifyProductInPantry(WidgetTester tester, String name) async {
    print('Navigating to Home/Pantry');
    await tapAndWait(tester, find.byKey(const Key('nav_Home')));
    
    print('Checking for $name');
    final itemFinder = find.text(name).hitTestable();
    await waitFor(tester, itemFinder, timeout: const Duration(seconds: 5));
    
    // FIX: Allow multiple items with the same name (e.g., 2x Beef)
    expect(itemFinder, findsAtLeastNWidgets(1));
  }

  // --- UTILS ---

  Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    print('Warning: Timed out waiting for $finder');
  }

  Future<void> waitForAbsence(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return; 
    }
    print('Warning: Widget $finder is still visible after timeout');
  }
}