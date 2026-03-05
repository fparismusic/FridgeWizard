import 'dart:convert';
import 'recipe.dart';

class PlannedMeal {
  final String id;
  final Recipe recipe;
  final DateTime date; 
  final Map<String, dynamic> cachedDetails;

  PlannedMeal({
    required this.id,
    required this.recipe,
    required this.date,
    required this.cachedDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipe': recipe.toJson(),
      'date': date.toIso8601String(),
      'cachedDetails': jsonEncode(cachedDetails),
    };
  }

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    return PlannedMeal(
      id: json['id'],
      recipe: Recipe.fromJsonByIngredients(json['recipe']),
      date: DateTime.parse(json['date']),
      cachedDetails: jsonDecode(json['cachedDetails']),
    );
  }
}