import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_ricette/main.dart' as app;

import 'package:app_ricette/screens/home_page.dart';
import 'package:app_ricette/screens/recipes_page.dart';
import 'package:app_ricette/screens/show_recipe.dart';
import 'package:app_ricette/screens/plan_page.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Recipe Flow: Search, Schedule, Buy, Remove, Delete, Reschedule, Verify', (WidgetTester tester) async {

    app.main();
    await tester.pump(const Duration(seconds: 3));
    
    final helper = TestHelper();

    await helper.ensureLoggedIn(tester);
    expect(find.byType(HomePage), findsOneWidget);

    print('Navigating to Recipes Tab');
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    expect(find.byType(RecipesPage), findsOneWidget);

    await helper.searchForRecipe(tester, 'Pizza');

    await helper.openFirstRecipe(tester);

    await helper.scheduleRecipe(tester);

    await helper.goBack(tester);
    
    await helper.navigateToPlan(tester);

    expect(find.byKey(const Key('plannedMeal_0')), findsOneWidget);

    final ingredientName = await helper.markFirstIngredientAsBought(tester, qty: '1');

    await helper.removeFirstIngredientFromList(tester);

    await helper.verifyProductInPantry(tester, ingredientName);

    await helper.navigateToPlan(tester);

    await helper.deleteFirstPlannedMeal(tester);

    await helper.verifyNoPlannedMeals(tester);

    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    
    if (find.byType(Image).evaluate().isNotEmpty) {
       await helper.openFirstRecipe(tester);
    } else {
       await helper.searchForRecipe(tester, 'Pizza');
       await helper.openFirstRecipe(tester);
    }

    await helper.scheduleRecipeNextDay(tester);

    await helper.goBack(tester);
    
    await helper.navigateToPlan(tester);

    await helper.verifyIngredientNotMissing(tester, ingredientName);

    print('Extended Recipe Flow Test Completed Successfully!');
  });
}