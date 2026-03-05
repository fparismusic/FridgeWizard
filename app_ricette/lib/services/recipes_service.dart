//this class will handle all the API calls to spoonacular for recipes
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import 'package:flutter/foundation.dart';

final String apiKey = dotenv.env['SPOONACULAR_API_KEY'] ?? '';

class RecipesService {
  final http.Client client;
  RecipesService({http.Client? client}) : client = client ?? http.Client();
  // Fetch recipes by ingredients
  Future<List<Recipe>> fetchRecipesByIngredients(List<String> ingredients) async {
    if (ingredients.isEmpty) return [];
    
    final String ingredientsQuery = ingredients.join(',');
    final String url =
        'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$ingredientsQuery&number=20&ranking=1&ignorePantry=true&apiKey=$apiKey';

    try {
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJsonByIngredients(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching recipes by ingredients: $e');
      rethrow;
    }
  }

  // Fetch recipes by name
  Future<List<Recipe>> searchRecipesByName(String query) async {
    if (query.isEmpty) return [];
    
    final String url =
        'https://api.spoonacular.com/recipes/complexSearch?query=$query&number=20&addRecipeInformation=true&apiKey=$apiKey';

    try {
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return results.map((json) => Recipe.fromJsonByName(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching recipes by name: $e');
      rethrow;
    }
  }

  // Get recipe details
  Future<Map<String, dynamic>?> getRecipeDetails(int recipeId) async {
    final String url =
        'https://api.spoonacular.com/recipes/$recipeId/information?apiKey=$apiKey';

    try {
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching recipe details: $e');
      return null;
    }
  }

}