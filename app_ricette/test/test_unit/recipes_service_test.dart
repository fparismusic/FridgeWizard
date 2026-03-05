import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:app_ricette/services/recipes_service.dart';
import 'package:app_ricette/models/recipe.dart';

void main() {

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'SPOONACULAR_API_KEY=fake_key');
  });

  group('RecipesService Tests', () {

    test('fetchRecipesByIngredients restituisce una lista di ricette se la chiamata è 200 OK', () async {
      final mockResponse = jsonEncode([
        {
          "id": 1,
          "title": "Pasta al Pomodoro",
          "image": "https://img.com/pasta.jpg",
          "usedIngredientCount": 1,
          "missedIngredientCount": 0,
          "likes": 100
        },
        {
          "id": 2,
          "title": "Pizza",
          "image": "https://img.com/pizza.jpg",
          "usedIngredientCount": 2,
          "missedIngredientCount": 1,
        }
      ]);

      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final service = RecipesService(client: mockClient);
      final results = await service.fetchRecipesByIngredients(['tomato', 'flour']);

      expect(results, isA<List<Recipe>>());
      expect(results.length, 2);
      expect(results[0].title, 'Pasta al Pomodoro');
      expect(results[1].title, 'Pizza');
    });

    test('fetchRecipesByIngredients lancia Exception se API fallisce (404/500)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = RecipesService(client: mockClient);

      // Verifico non solo che lanci eccezione, ma che sia quella specifica del codice
      expect(
        () async => await service.fetchRecipesByIngredients(['tomato']),
        throwsA(predicate((e) => e is Exception && e.toString().contains('Failed to load recipes: 404')))
      );
    });

    test('searchRecipesByName restituisce ricette correttamente parsando "results"', () async {
      final mockResponse = jsonEncode({
        "results": [
          {
            "id": 10,
            "title": "Carbonara",
            "image": "carbonara.jpg"
          }
        ],
        "offset": 0,
        "number": 1,
        "totalResults": 1
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final service = RecipesService(client: mockClient);
      final results = await service.searchRecipesByName('Carbonara');

      expect(results.length, 1);
      expect(results.first.title, 'Carbonara');
    });

    test('searchRecipesByName lancia Exception se API fallisce', () async {
      final mockClient = MockClient((request) async => http.Response('Server Error', 500));
      final service = RecipesService(client: mockClient);

      expect(
        () async => await service.searchRecipesByName('Pasta'),
        throwsA(predicate((e) => e is Exception && e.toString().contains('Failed to search recipes: 500')))
      );
    });

    test('getRecipeDetails restituisce i dati (Map) se la chiamata è 200 OK', () async {
      final mockResponse = jsonEncode({
        "id": 99,
        "title": "Super Torta",
        "readyInMinutes": 45,
        "servings": 4
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('/99/information'));
        return http.Response(mockResponse, 200);
      });

      final service = RecipesService(client: mockClient);
      final result = await service.getRecipeDetails(99);

      expect(result, isNotNull);
      expect(result!['title'], 'Super Torta');
      expect(result['readyInMinutes'], 45);
    });

    test('getRecipeDetails restituisce NULL se status != 200 o eccezione di rete', () async {
      // Caso A: Server Error (copre l'else)
      final client500 = MockClient((request) async => http.Response('Error', 500));
      final serviceA = RecipesService(client: client500);
      expect(await serviceA.getRecipeDetails(1), isNull);

      // Caso B: Eccezione di rete (copre il catch)
      final clientEx = MockClient((request) async => throw Exception('Network fail'));
      final serviceB = RecipesService(client: clientEx);
      expect(await serviceB.getRecipeDetails(1), isNull);
    });

    test('I metodi restituiscono lista vuota se input vuoto (Senza chiamare API)', () async {
      final failClient = MockClient((request) async {
        throw Exception("Non avresti dovuto chiamarmi!");
      });

      final service = RecipesService(client: failClient);

      final results = await service.fetchRecipesByIngredients([]);
      expect(results, isEmpty);

      final searchResults = await service.searchRecipesByName('');
      expect(searchResults, isEmpty);
    });

  });
}