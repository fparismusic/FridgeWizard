class Recipe {
  final int id;
  final String title;
  final String image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  
  final List<IngredientData> usedIngredients;
  final List<IngredientData> missedIngredients;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
    this.usedIngredientCount = 0,
    this.missedIngredientCount = 0,
    this.usedIngredients = const [],
    this.missedIngredients = const [],
  });

  factory Recipe.fromJsonByIngredients(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      usedIngredientCount: json['usedIngredientCount'] ?? 0,
      missedIngredientCount: json['missedIngredientCount'] ?? 0,
      usedIngredients: (json['usedIngredients'] as List?)
          ?.map((e) => IngredientData.fromJson(e))
          .toList() ?? [],
      missedIngredients: (json['missedIngredients'] as List?)
          ?.map((e) => IngredientData.fromJson(e))
          .toList() ?? [],
    );
  }

  factory Recipe.fromJsonByName(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'usedIngredientCount': usedIngredientCount,
      'missedIngredientCount': missedIngredientCount,
      'usedIngredients': usedIngredients.map((e) => e.toJson()).toList(),
      'missedIngredients': missedIngredients.map((e) => e.toJson()).toList(),
    };
  }
}

class IngredientData {
  final String name;
  final double amount;
  final String unit;
  final String? original;

  IngredientData({
    required this.name,
    required this.amount,
    required this.unit,
    this.original,
  });

  factory IngredientData.fromJson(Map<String, dynamic> json) {
    return IngredientData(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      original: json['original'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'original': original,
    };
  }
}