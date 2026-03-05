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

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full App Flow: Register, Verify Screens, Add & Edit Product', (WidgetTester tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 3));
    
    final helper = TestHelper();

    await helper.ensureLoggedOut(tester);
    
    final testEmail = TestHelper.generateRandomEmail();
    const testPassword = 'Password123!'; 

    print('Step 1: Registering new user $testEmail');
    await helper.performRegistration(tester, testEmail, testPassword);
    
    expect(find.byKey(const Key('addProductButton')), findsOneWidget);

    print('Step 2: Verifying NavBar navigation');
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Search')));
    expect(find.byType(RecipesPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Plan')));
    expect(find.byType(PlanPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Profile')));
    expect(find.byType(SettingsPage), findsOneWidget);
    
    await helper.tapAndWait(tester, find.byKey(const Key('nav_Home')));
    expect(find.byType(HomePage), findsOneWidget);

    print('Step 3: Adding product manually');
    
    await helper.tapAndWait(tester, find.byKey(const Key('addProductButton')), seconds: 1);
    await helper.tapAndWait(tester, find.byKey(const Key('addManuallyAction')), seconds: 2);

    expect(find.text('Add Product Manually'), findsOneWidget);

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

    print('Step 4: Confirming Add');
    await helper.tapAndWait(tester, find.byKey(const Key('manualAddButton')), seconds: 2);
    
    await helper.waitForAbsence(tester, find.byType(AddProductManualPage));
    
    await helper.waitFor(tester, find.text('Eggs'), timeout: const Duration(seconds: 10));
    expect(find.text('Eggs'), findsOneWidget);

    print('Step 5: Modifying the product');
    
    await helper.tapAndWait(tester, find.text('Eggs'));
    expect(find.byType(ProductPage), findsOneWidget);

    await helper.tapAndWait(tester, find.byKey(const Key('productEditSaveButton')));

    await tester.enterText(find.byKey(const Key('editNotesField')), 'test note');
    await tester.pump(const Duration(milliseconds: 200));

    await helper.tapAndWait(tester, find.byKey(const Key('editDateField')));
    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -50)); 
    await tester.pump(const Duration(milliseconds: 500));
    await helper.tapAndWait(tester, find.byKey(const Key('editDateDone')));

    await helper.tapAndWait(tester, find.byKey(const Key('productEditSaveButton')), seconds: 2);

    expect(find.text('test note'), findsOneWidget);

    print('Step 6: Exiting to Home');
    
    await helper.tapAndWait(tester, find.byType(CupertinoNavigationBarBackButton));
    expect(find.byType(HomePage), findsOneWidget);

    print('Test Completed Successfully!');
  });
}