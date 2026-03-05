import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/widgets/nav_bar.dart';
import 'package:app_ricette/utils/my_theme_data.dart';

void main() {

  // Helper function per costruire il widget in un ambiente di test
  Widget createWidgetUnderTest({
    required int selectedIndex,
    required Function(int) onTabChange,
    CupertinoThemeData? theme,
  }) {
    return CupertinoApp(
      theme: theme ?? MyThemeData.lightTheme,
      home: CupertinoPageScaffold(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: CustomNavBar(
                selectedIndex: selectedIndex,
                onTabChange: onTabChange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE (Schermo stretto)
  // ---------------------------------------------------------------------------
  group('CustomNavBar - MOBILE View Tests', () {

    setUp(() {
      // Configurazione Mobile standard (iPhone 13 style)
      // Width: 1170 / 3 = 390
    });

    testWidgets('Rendering & State: Mostra item corretti e nasconde label non selezionate', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(
        selectedIndex: 0,
        onTabChange: (_) {},
      ));

      // Verifico Tab Selezionato (Home)
      expect(find.byIcon(CupertinoIcons.home), findsOneWidget);
      expect(find.text('Home'), findsOneWidget); // Label visibile

      // Verifico Tab Non Selezionato (Search)
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
      expect(find.text('Search'), findsNothing); // Label nascosta
    });

    testWidgets('Interaction: Tapping cambia index', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      int tappedIndex = -1;

      await tester.pumpWidget(createWidgetUnderTest(
        selectedIndex: 0,
        onTabChange: (index) => tappedIndex = index,
      ));

      // Clicco su Search
      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pump(); // Avvia animazione

      expect(tappedIndex, 1, reason: "Il tap sull'icona Search deve ritornare index 1");
    });

    testWidgets('Theme: Dark Mode adatta i colori', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(
        selectedIndex: 0,
        onTabChange: (_) {},
        theme: MyThemeData.darkTheme,
      ));

      // Cerco il Container principale della NavBar per verificarne la decorazione
      // Nota: Potrebbe essere necessario aggiustare il finder se la struttura del widget cambia
      final containerFinder = find.ancestor(
        of: find.byIcon(CupertinoIcons.home),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      // Verifico specifica sul colore di sfondo in dark mode
      expect(decoration.color, CupertinoColors.white,
          reason: "In Dark Mode, il container deve avere lo sfondo bianco (secondo la tua logica attuale)");
    });
  });

  // ---------------------------------------------------------------------------
  // TABLET (Schermo largo)
  // ---------------------------------------------------------------------------
  group('CustomNavBar - TABLET View Tests', () {

    setUp(() {
      // Configurazione Tablet (iPad Pro 12.9")
      // Width: 2048 / 2 = 1024 logical
    });

    testWidgets('Layout: Applica margini laterali per non allargarsi troppo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(
        selectedIndex: 0,
        onTabChange: (_) {},
      ));

      // Trovo il container più esterno della NavBar
      final navBarFinder = find.byType(Container).first;
      final container = tester.widget<Container>(navBarFinder);

      final EdgeInsets margin = container.margin as EdgeInsets;

      expect(margin.horizontal, closeTo(574.0, 1.0),
          reason: "Il margine orizzontale dovrebbe essere ristretto su tablet per estetica");
    });

    testWidgets('Interaction (Tablet): I tap funzionano anche con i margini', (WidgetTester tester) async {
      // Questo test è importante perché a volte i margini/padding bloccano i click
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      int tappedIndex = -1;

      await tester.pumpWidget(createWidgetUnderTest(
        selectedIndex: 0,
        onTabChange: (index) => tappedIndex = index,
      ));

      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pump();

      expect(tappedIndex, 1);
    });
  });
}