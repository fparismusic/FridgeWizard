import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/models/category_price.dart';

void main() {
  group('CategoryPrice Logic Tests', () {

    test('Verifica prezzi unitari di categorie chiave', () {
      // Bevande
      expect(CategoryPrice.water.pricePerUnit, 0.50);
      expect(CategoryPrice.wine.pricePerUnit, 8.00);

      // Proteine
      expect(CategoryPrice.chicken.pricePerUnit, 6.00);
      expect(CategoryPrice.meat.pricePerUnit, 10.00);

      // Frutta/Verdura
      expect(CategoryPrice.apple.pricePerUnit, 2.00);

      // Default
      expect(CategoryPrice.other.pricePerUnit, 3.00);
    });

    test('Riconosce correttamente prodotti esatti (Exact Match)', () {
      // Assumendo che "milk" o "latte" siano mappati a CategoryPrice.milk
      expect(
          CategoryPrice.getCategoryForProduct('milk'),
          CategoryPrice.milk,
          reason: 'Dovrebbe riconoscere "milk"'
      );

      expect(
          CategoryPrice.getCategoryForProduct('pollo'),
          CategoryPrice.chicken,
          reason: 'Dovrebbe riconoscere "pollo"'
      );

      expect(
          CategoryPrice.getCategoryForProduct('pasta'),
          CategoryPrice.pasta,
          reason: 'Dovrebbe riconoscere "pasta"'
      );
    });

    test('Riconosce prodotti con Case Insensitivity e Spazi', () {
      // Test Maiuscole
      expect(CategoryPrice.getCategoryForProduct('APPLE'), CategoryPrice.apple);

      // Test Misto
      expect(CategoryPrice.getCategoryForProduct('BaNaNa'), CategoryPrice.banana);

      // Test Spazi extra (trimming)
      expect(CategoryPrice.getCategoryForProduct('  rice  '), CategoryPrice.rice);
    });

    test('Riconosce parole chiave all\'interno di frasi (Partial Match)', () {
      // "Cherry Tomato Pack" -> deve trovare "tomato"
      expect(CategoryPrice.getCategoryForProduct('Cherry Tomato Pack'), CategoryPrice.tomato);

      // "Green Salad Bowl" -> deve trovare "salad"
      expect(CategoryPrice.getCategoryForProduct('Green Salad Bowl'), CategoryPrice.salad);
    });

    test('Restituisce "other" per prodotti sconosciuti', () {
      expect(
          CategoryPrice.getCategoryForProduct('XyzKwq999'),
          CategoryPrice.other,
          reason: 'Una stringa casuale senza keyword note dovrebbe restituire Other'
      );

      expect(
          CategoryPrice.getCategoryForProduct(''),
          CategoryPrice.other,
          reason: 'Una stringa vuota dovrebbe restituire Other'
      );
    });

    test('Calcola valore corretto con quantità default (1.0)', () {
      // Water = 0.50
      expect(CategoryPrice.getEstimatedValue('water'), 0.50);

      // Meat = 10.00
      expect(CategoryPrice.getEstimatedValue('meat'), 10.00);
    });

    test('Calcola valore corretto con quantità custom', () {
      // Coffee = 4.00 * 2 = 8.00
      expect(CategoryPrice.getEstimatedValue('coffee', quantity: 2.0), 8.00);

      // Pasta = 1.50 * 10 = 15.00
      expect(CategoryPrice.getEstimatedValue('pasta', quantity: 10.0), 15.00);
    });

    test('Calcola valore corretto con quantità decimali', () {
      // Cheese = 4.00 * 0.5 = 2.00
      expect(CategoryPrice.getEstimatedValue('cheese', quantity: 0.5), 2.00);
    });

    test('Calcola valore corretto per categoria sconosciuta (fallback price)', () {
      // Other price = 3.00
      expect(
          CategoryPrice.getEstimatedValue('unknown_item', quantity: 2.0),
          6.00 // 3.00 * 2
      );
    });

    test('Priorità match: Se una stringa contiene keyword multiple', () {

      // "Chicken Salad"
      // Se "salad" viene prima nella mappa -> restituisce salad
      // Se "chicken" viene prima -> restituisce chicken

      final result = CategoryPrice.getCategoryForProduct('Chicken Salad');

      expect(
          [CategoryPrice.chicken, CategoryPrice.salad].contains(result),
          isTrue,
          reason: '"Chicken Salad" dovrebbe essere o Pollo o Insalata, non Other'
      );
    });

  });
}