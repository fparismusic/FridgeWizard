import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_ricette/main.dart' as app;

import 'package:app_ricette/screens/home_page.dart';
import 'package:app_ricette/screens/recipes_page.dart';
import 'package:app_ricette/screens/plan_page.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ingredient Search Flow: Add Pantry Items, Search by Ingredients, Schedule Meal', (WidgetTester tester) async {

    app.main();
    await tester.pump(const Duration(seconds: 3));
    
    final helper = TestHelper();

    await helper.ensureLoggedIn(tester);
    expect(find.byType(HomePage), findsOneWidget);

    print('Step 3: Populating Pantry');
    await helper.addPantryItem(tester, name: 'Beef', qty: '500');
    await helper.addPantryItem(tester, name: 'Egg', qty: '6');
    await helper.addPantryItem(tester, name: 'Milk', qty: '1');

    print('Step 4: Navigating to Recipes Tab');
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    expect(find.byType(RecipesPage), findsOneWidget);

    print('Step 5: Switching to Ingredient Search');
    await helper.switchToIngredientSearch(tester);

    print('Step 6: Selecting Ingredients');
    await helper.selectIngredient(tester, 'Egg');
    await helper.selectIngredient(tester, 'Milk');

    print('Step 7: Tapping Find Recipes');
    await helper.tapFindRecipes(tester);

    print('Step 8: Opening first recipe result');
    await helper.openFirstRecipe(tester);

    print('Step 9: Scheduling the recipe');
    await helper.scheduleRecipe(tester);

    print('Step 10: Verifying in Plan Page');
    
    await helper.goBack(tester);
    
    await helper.navigateToPlan(tester);

    expect(find.byKey(const Key('plannedMeal_0')), findsOneWidget);

    print('Ingredient Search Test Completed Successfully!');
  });
}