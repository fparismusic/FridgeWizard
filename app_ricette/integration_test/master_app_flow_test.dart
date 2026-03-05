import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_ricette/main.dart' as app;

import 'package:app_ricette/screens/home_page.dart';
import 'package:app_ricette/screens/recipes_page.dart';
import 'package:app_ricette/screens/plan_page.dart';
import 'package:app_ricette/screens/settings_page.dart';
import 'package:app_ricette/screens/product_page.dart';
import 'package:app_ricette/screens/add_product_manual_page.dart';
import 'package:app_ricette/screens/show_recipe.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flow: Register -> Shop -> Plan -> Logout -> Login -> Verify Data Persistence', (WidgetTester tester) async {
    // 1. Start App
    app.main();
    await tester.pump(const Duration(seconds: 3));
    
    final helper = TestHelper();
    // 1. Clean State (Logout if needed)
    await helper.ensureLoggedOut(tester);
    
    final testEmail = TestHelper.generateRandomEmail();
    const testPassword = 'Password123!'; 

    // 2. Register
    print('--- PART 1: Registration ---');
    await helper.performRegistration(tester, testEmail, testPassword);
    expect(find.byKey(const Key('addProductButton')), findsOneWidget);

    // 3. Verify Screen Navigation
    print('Step: Verifying NavBar navigation');
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    expect(find.byType(RecipesPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Plan')));
    expect(find.byType(PlanPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Profile')));
    expect(find.byType(SettingsPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Home')));
    expect(find.byType(HomePage), findsOneWidget);

    // 4. Add Product Manually (Eggs)
    print('Step: Adding product manually (Eggs)');
    await helper.tapAndWait(tester, find.byKey(const Key('addProductButton')), seconds: 1);
    await helper.tapAndWait(tester, find.byKey(const Key('addManuallyAction')), seconds: 2);

    await tester.enterText(find.byKey(const Key('manualNameField')), 'Eggs');
    await tester.enterText(find.byKey(const Key('manualQtyField')), '6');
    
    await helper.tapAndWait(tester, find.byKey(const Key('manualUnitPicker')));
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, 50)); 
    await tester.pump(const Duration(milliseconds: 500));
    await helper.tapAndWait(tester, find.byKey(const Key('manualUnitDone')));

    await helper.tapAndWait(tester, find.byKey(const Key('manualDatePicker')));
    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 500));
    await helper.tapAndWait(tester, find.byKey(const Key('manualDateDone')));

    await helper.tapAndWait(tester, find.byKey(const Key('manualAddButton')), seconds: 2);
    await helper.waitForAbsence(tester, find.byType(AddProductManualPage));
    
    await helper.waitFor(tester, find.text('Eggs'), timeout: const Duration(seconds: 10));
    expect(find.text('Eggs'), findsOneWidget);

    // 5. Modify Product
    print('Step: Modifying product');
    await helper.tapAndWait(tester, find.text('Eggs'));
    expect(find.byType(ProductPage), findsOneWidget);

    await helper.tapAndWait(tester, find.byKey(const Key('productEditSaveButton')));
    await tester.enterText(find.byKey(const Key('editNotesField')), 'test note');
    await tester.pump(const Duration(milliseconds: 200));
    
    await helper.tapAndWait(tester, find.byKey(const Key('productEditSaveButton')), seconds: 2);
    expect(find.text('test note'), findsOneWidget);

    // 6. Exit to Home
    await helper.tapAndWait(tester, find.byType(CupertinoNavigationBarBackButton));
    expect(find.byType(HomePage), findsOneWidget);


    print('--- PART 2: Recipe Search & Planning ---');

    // 1. Navigate to Recipes
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    expect(find.byType(RecipesPage), findsOneWidget);

    // 2. Search for "Pizza"
    await helper.searchForRecipe(tester, 'Pizza');

    // 3. Open First Result
    await helper.openFirstRecipe(tester);

    // 4. Schedule the Recipe
    await helper.scheduleRecipe(tester);

    // 5. Go Back from ShowRecipe
    await helper.goBack(tester);
    
    // 6. Go to Plan Page
    await helper.navigateToPlan(tester);

    // 7. Verify Meal is in list
    expect(find.byKey(const Key('plannedMeal_0')), findsOneWidget);

    // 8. Mark 1st Ingredient as Bought
    final ingredientName = await helper.markFirstIngredientAsBought(tester, qty: '1');

    // 9. Remove the new 1st Ingredient from list (cleanup)
    await helper.removeFirstIngredientFromList(tester);

    // 10. Verify Ingredient in Pantry
    await helper.verifyProductInPantry(tester, ingredientName);

    print('--- PART 3: Smart Pantry Logic ---');

    // 1. Go back to Plan Page
    await helper.navigateToPlan(tester);

    // 2. Delete the planned meal
    await helper.deleteFirstPlannedMeal(tester);
    await helper.verifyNoPlannedMeals(tester);

    // 3. Go back to Search (Recipes)
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    
    // 4. Open recipe again (should still be listed)
    if (find.byType(ShowRecipe).evaluate().isEmpty) {
       await helper.openFirstRecipe(tester);
    }

    // 5. Schedule again for NEXT DAY
    await helper.scheduleRecipeNextDay(tester);

    // 6. Go back
    await helper.goBack(tester);
    
    // 7. Go to Plan Page
    await helper.navigateToPlan(tester);

    // 8. Verify Smart Pantry Logic:
    // The ingredient we bought in Part 2 should NOT be missing now.
    await helper.verifyIngredientNotMissing(tester, ingredientName);

    print('--- PART 4: Ingredient Search ---');

    // 1. Go to Home to add more items
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Home')));

    // 2. Add Ingredients
    await helper.addPantryItem(tester, name: 'Beef', qty: '500');
    await helper.addPantryItem(tester, name: 'Egg', qty: '6');
    await helper.addPantryItem(tester, name: 'Milk', qty: '1');

    // 3. Navigate to Recipes
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));

    // 4. Switch to Ingredient Search Mode
    // (This helper now smartly handles the "Back" button if it exists)
    await helper.switchToIngredientSearch(tester);

    // 5. Select Ingredients
    await helper.selectIngredient(tester, 'Egg');
    await helper.selectIngredient(tester, 'Milk');

    // 6. Search
    await helper.tapFindRecipes(tester);

    // 7. Open First Result
    await helper.openFirstRecipe(tester);

    // 8. Schedule
    await helper.scheduleRecipe(tester);

    // 9. Verify in Plan
    await helper.goBack(tester);
    await helper.navigateToPlan(tester);
    
    // We expect 2 meals now (the one from Part 3 and this new one)
    // So 'plannedMeal_0' should definitely exist.
    expect(find.byKey(const Key('plannedMeal_0')), findsOneWidget);

    print('--- PART 5: Logout & Relogin ---');

    // 1. Logout
    // This goes to Settings -> Scrolls to bottom -> Taps Logout
    await helper.logoutFromSettings(tester);

    // 2. Login again with same credentials
    print('Logging back in');
    await helper.performLogin(tester, testEmail, testPassword);

    // 3. Verify Home (Pantry Data)
    print('Verifying Pantry Data after Login');
    // 'Eggs' (Part 1), 'Milk' (Part 4), 'Beef' (Part 2/4)
    await helper.verifyProductInPantry(tester, 'Eggs');
    await helper.verifyProductInPantry(tester, 'Milk');
    await helper.verifyProductInPantry(tester, 'Beef');

    // 4. Verify Plan (Meal Data)
    print('Verifying Planned Meals after Login');
    await helper.navigateToPlan(tester);
    expect(find.byKey(const Key('plannedMeal_0')), findsOneWidget);

    print('MASTER FLOW TEST COMPLETED SUCCESSFULLY! ');
  });
}