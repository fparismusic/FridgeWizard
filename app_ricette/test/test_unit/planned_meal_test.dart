import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/models/planned_meal.dart';
import 'package:app_ricette/models/recipe.dart';


void main() {
  group('PlannedMeal Model Tests', () {
    // Helper per creare una ricetta al volo
    final dummyRecipe = Recipe(
      id: 1,
      title: 'Pasta al Sugo',
      image: 'pasta.jpg',
    );

    final now = DateTime.now();

    test('Serializzazione Completa (Round Trip)', () {
      final meal = PlannedMeal(
        id: 'meal_123',
        recipe: dummyRecipe,
        date: now,
        cachedDetails: {'calories': 500, 'servings': 2},
      );

      // (ToJson -> FromJson)
      final json = meal.toJson();

      // Verifica intermedia: cachedDetails deve essere una STRINGA
      expect(json['cachedDetails'], isA<String>());

      final reconstructedMeal = PlannedMeal.fromJson(json);

      expect(reconstructedMeal.id, 'meal_123');
      expect(reconstructedMeal.recipe.title, 'Pasta al Sugo');

      expect(reconstructedMeal.date.difference(now).inSeconds, 0);

      // Verifico che cachedDetails sia tornato Mappa corretta
      expect(reconstructedMeal.cachedDetails['calories'], 500);
      expect(reconstructedMeal.cachedDetails['servings'], 2);
    });

    // --- NUOVI TEST ---

    test('Gestione Strutture complesse in cachedDetails (Liste, Nested Maps)', () {
      // Spoonacular spesso restituisce JSON annidati complessi
      final complexDetails = {
        'extendedIngredients': [
          {'name': 'Sale', 'amount': 100},
          {'name': 'Pepe', 'amount': 5}
        ],
        'nutrition': {
          'nutrients': [
            {'name': 'Fat', 'amount': 10},
            {'name': 'Carbs', 'amount': 50}
          ]
        },
        'instructions': "Step 1: Cook.\nStep 2: Eat." // Caratteri speciali
      };

      final meal = PlannedMeal(
        id: 'complex_meal',
        recipe: dummyRecipe,
        date: now,
        cachedDetails: complexDetails,
      );

      final json = meal.toJson();
      final reconstructed = PlannedMeal.fromJson(json);

      final details = reconstructed.cachedDetails;
      
      // Verifica liste annidate
      expect((details['extendedIngredients'] as List).length, 2);
      expect(details['extendedIngredients'][0]['name'], 'Sale');
      
      // Verifica mappe annidate
      expect(details['nutrition']['nutrients'][0]['name'], 'Fat');
      
      // Verifica stringhe con newline
      expect(details['instructions'], contains('\n'));
    });

    test('Resilienza fromJson: Gestisce JSON validi costruiti manualmente', () {
      // Simulo un JSON che potrebbe arrivare dal disco/DB
      // Nota: 'cachedDetails' qui è una stringa JSON valida
      final validJson = {
        'id': 'manual_id',
        'date': '2025-12-25T12:00:00.000',
        'recipe': {
          'id': 99,
          'title': 'Manual Recipe',
          'image': 'img.png'
        },
        'cachedDetails': '{"simple": "value", "number": 123}' // JSON String manuale
      };

      final meal = PlannedMeal.fromJson(validJson);

      expect(meal.id, 'manual_id');
      expect(meal.date.year, 2025);
      expect(meal.cachedDetails['simple'], 'value');
      expect(meal.cachedDetails['number'], 123);
    });

  });
}