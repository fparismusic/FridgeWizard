import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/models/recipe.dart';

void main() {
  // --- IngredientData ---
  group('IngredientData Model Tests', () {
    test('fromJson parses correct data', () {
      final json = {
        'name': 'Farina',
        'amount': 250.5,
        'unit': 'g',
        'original': '250g di Farina 00'
      };

      final ingredient = IngredientData.fromJson(json);

      expect(ingredient.name, 'Farina');
      expect(ingredient.amount, 250.5);
      expect(ingredient.unit, 'g');
      expect(ingredient.original, '250g di Farina 00');
    });

    test('Safety: Gestisce conversione Int -> Double senza crashare', () {
      // Le API spesso mandano "100" invece di "100.0".
      // Verifico che il codice lo gestisca.
      final json = {
        'name': 'Zucchero',
        'amount': 100, // <--- INTERO!
        'unit': 'g'
      };

      final ingredient = IngredientData.fromJson(json);

      expect(ingredient.amount, 100.0); // Deve essere diventato double
      expect(ingredient.amount, isA<double>());
    });

    test('Safety: Gestisce campi nulli con default', () {
      final json = <String, dynamic>{}; // Mappa vuota

      final ingredient = IngredientData.fromJson(json);

      expect(ingredient.name, '');
      expect(ingredient.amount, 0.0);
      expect(ingredient.original, null);
    });

    // --- NUOVO TEST: Serializzazione IngredientData ---
    test('toJson serializza correttamente (inclusi campi opzionali)', () {
      final ingredient = IngredientData(
        name: 'Olio', 
        amount: 2.0, 
        unit: 'tbsp', 
        original: '2 tbsp Olive Oil'
      );

      final json = ingredient.toJson();

      expect(json['name'], 'Olio');
      expect(json['amount'], 2.0);
      expect(json['original'], '2 tbsp Olive Oil');
    });
  });

  // --- GRUPPO 2: Recipe ---
  group('Recipe Model Tests', () {

    // JSON simulato completo
    final fullJson = {
      'id': 999,
      'title': 'Pasta alla Carbonara',
      'image': 'carbonara.jpg',
      'usedIngredientCount': 1,
      'missedIngredientCount': 2,
      'usedIngredients': [
        {'name': 'Pasta', 'amount': 500, 'unit': 'g'}
      ],
      'missedIngredients': [
        {'name': 'Uova', 'amount': 4, 'unit': 'pcs'},
        {'name': 'Guanciale', 'amount': 200, 'unit': 'g'}
      ]
    };

    test('fromJsonByIngredients parsa correttamente liste annidate', () {
      final recipe = Recipe.fromJsonByIngredients(fullJson);

      expect(recipe.id, 999);
      expect(recipe.title, 'Pasta alla Carbonara');

      // Verifica Liste
      expect(recipe.usedIngredients.length, 1);
      expect(recipe.missedIngredients.length, 2);

      // Verifica oggetto annidato
      expect(recipe.missedIngredients[0].name, 'Uova');
      expect(recipe.missedIngredients[0].amount, 4.0);
    });

    test('Safety: Gestisce liste nulle o malformate', () {
      final badJson = {
        'id': 1,
        'title': 'Test',
        'image': '',
        // 'usedIngredients' è ASSENTE
        'missedIngredients': null // è NULL
      };

      final recipe = Recipe.fromJsonByIngredients(badJson);

      // Non deve crashare, ma restituire liste vuote grazie al "?? []"
      expect(recipe.usedIngredients, isEmpty);
      expect(recipe.missedIngredients, isEmpty);
      expect(recipe.usedIngredients, isA<List<IngredientData>>());
    });

    test('fromJsonByName crea ricetta base ignorando ingredienti', () {
      // Questo costruttore è diverso, verifichiamo che faccia il suo dovere parziale
      final recipe = Recipe.fromJsonByName(fullJson);

      expect(recipe.id, 999);
      expect(recipe.title, 'Pasta alla Carbonara');
    });

    // --- NUOVO TEST: Safety fromJsonByName ---
    test('Safety: fromJsonByName gestisce JSON vuoto o incompleto', () {
      // Questo test copre i rami "?? 0" e "?? ''" dentro fromJsonByName
      final emptyJson = <String, dynamic>{}; 

      final recipe = Recipe.fromJsonByName(emptyJson);

      expect(recipe.id, 0); // Default value
      expect(recipe.title, ''); // Default value
      expect(recipe.image, ''); // Default value
    });

    test('toJson serializza correttamente tutta la struttura', () {
      // Creiamo l'oggetto manualmente
      final ingredient = IngredientData(name: 'Sale', amount: 1, unit: 'pizzico');
      final recipe = Recipe(
        id: 5,
        title: 'Acqua Salata',
        image: 'water.png',
        usedIngredients: [ingredient],
      );

      // Convertiamo in JSON
      final json = recipe.toJson();

      // Verifiche
      expect(json['id'], 5);
      expect(json['usedIngredients'], isA<List>());
      expect((json['usedIngredients'] as List).first['name'], 'Sale');
    });

    // --- NUOVO TEST: toJson con liste vuote ---
    test('toJson produce liste vuote se non ci sono ingredienti', () {
      // Ricetta senza ingredienti (usiamo i default del costruttore)
      final recipe = Recipe(
        id: 10,
        title: 'Empty Recipe',
        image: 'none',
      );

      final json = recipe.toJson();

      expect(json['usedIngredients'], isEmpty);
      expect(json['missedIngredients'], isEmpty);
    });
  });
}