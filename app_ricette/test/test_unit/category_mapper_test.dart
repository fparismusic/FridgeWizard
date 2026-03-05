import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/models/category_mapper.dart'; 

void main() {
  group('CategoryMapper Logic', () {

    // Helper function: Costruisce un'app minima per mostrare l'icona
    Future<void> pumpIcon(WidgetTester tester, String productName) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CategoryMapper.getIconForProduct(productName),
          ),
        ),
      );
    }

    testWidgets('Basic: Riconosce categorie semplici', (WidgetTester tester) async {
      await pumpIcon(tester, 'Acqua Naturale');
      expect(find.text('💧'), findsOneWidget);
    });

    testWidgets('BUG HUNT: "Latte" non deve essere scambiato per "Tè"', (WidgetTester tester) async {
      await pumpIcon(tester, 'Latte Intero');
      expect(find.text('🥛'), findsOneWidget);
    });

    testWidgets('Match Parziale: "Patate" deve essere riconosciuto (Plurali)', (WidgetTester tester) async {
      await pumpIcon(tester, 'Sacco di Patate');
      expect(find.text('🥔'), findsOneWidget);
    });

    // --- NUOVI TEST PER AUMENTARE LA COVERAGE ---

    testWidgets('Default: Restituisce icona cubo se nessun match trovato', (WidgetTester tester) async {
      // Caso: Prodotto sconosciuto o stringa nonsense
      await pumpIcon(tester, 'Oggetto Misterioso XYZ');
      
      // Deve trovare l'Icona (non il testo emoji)
      expect(find.byIcon(CupertinoIcons.cube_box), findsOneWidget);
    });

    testWidgets('Normalizzazione: Gestisce spazi e maiuscole', (WidgetTester tester) async {
      // Caso: Input sporco "  LAttE  " deve diventare "latte" e trovare l'emoji
      await pumpIcon(tester, '   LAttE   '); 
      
      expect(find.text('🥛'), findsOneWidget);
    });

    testWidgets('Match Esatto: Copre il fallback di uguaglianza stringa', (WidgetTester tester) async {
      // Questo test serve a coprire l'ultima riga di _containsAny: 
      // "if (keywords.contains(input)) return true;"
      // Anche se la logica di split spesso cattura le parole, questo assicura 
      // che se la keyword è esattamente uguale all'input, ritorni true.
      await pumpIcon(tester, 'Acqua');
      
      expect(find.text('💧'), findsOneWidget);
    });

  });
}