import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/utils/is_tablet.dart';

void main() {
  group('ScreenSize Utility Tests', () {

    testWidgets('screenHeight: Restituisce l\'altezza logica corretta', (WidgetTester tester) async {
      // Imposta una dimensione fissa conosciuta
      // Altezza Fisica 2400 / Pixel Ratio 3.0 = Altezza Logica 800
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      double? result;

      // Costruisco un widget per ottenere un Context valido
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              // Chiamo il metodo incriminato
              result = ScreenSize.screenHeight(context);
              return Container();
            },
          ),
        ),
      );

      // Verifico il risultato (2400 / 3 = 800)
      expect(result, 800.0);
    });

    testWidgets('screenWidth: Restituisce la larghezza logica corretta', (WidgetTester tester) async {
      // Larghezza Fisica 1080 / Pixel Ratio 3.0 = Larghezza Logica 360
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      double? result;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              result = ScreenSize.screenWidth(context);
              return Container();
            },
          ),
        ),
      );

      expect(result, 360.0);
    });

    testWidgets('isTablet: Rileva correttamente tablet vs telefono', (WidgetTester tester) async {
      // Telefono (lato corto < 600)
      // 1080 / 3 = 360 (lato corto) -> Non è tablet
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isTablet;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              isTablet = ScreenSize.isTablet(context);
              return Container();
            },
          ),
        ),
      );

      expect(isTablet, isFalse);
    });

    testWidgets('isTablet: Rileva Tablet (lato corto >= 600)', (WidgetTester tester) async {
      // Tablet (iPad Pro 12.9" approx)
      // 2048 / 2 = 1024 (lato corto) -> È tablet
      tester.view.physicalSize = const Size(2048, 2732);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isTablet;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              isTablet = ScreenSize.isTablet(context);
              return Container();
            },
          ),
        ),
      );

      expect(isTablet, isTrue);
    });

  });
}