import '../utils/categories.dart';

/// Enum che associa categorie di prodotti ai loro prezzi medi stimati (€/unità media)
enum CategoryPrice {
  // Bevande
  water(emoji: '💧', pricePerUnit: 0.50),
  coffee(emoji: '☕', pricePerUnit: 4.00),
  tea(emoji: '🍵', pricePerUnit: 3.00),
  wine(emoji: '🍷', pricePerUnit: 8.00),
  beer(emoji: '🍺', pricePerUnit: 2.00),
  milk(emoji: '🥛', pricePerUnit: 1.50),
  juice(emoji: '🧃', pricePerUnit: 2.00),

  // Carboidrati
  pasta(emoji: '🍝', pricePerUnit: 1.50),
  rice(emoji: '🍚', pricePerUnit: 2.00),
  pizza(emoji: '🍕', pricePerUnit: 5.00),
  bread(emoji: '🥖', pricePerUnit: 2.00),
  cookie(emoji: '🍪', pricePerUnit: 2.50),
  croissant(emoji: '🥐', pricePerUnit: 1.50),
  cake(emoji: '🍰', pricePerUnit: 4.00),
  chocolate(emoji: '🍫', pricePerUnit: 2.50),
  iceCream(emoji: '🍦', pricePerUnit: 4.00),
  cereal(emoji: '🥣', pricePerUnit: 3.50),
  bagel(emoji: '🥯', pricePerUnit: 1.50),

  // Proteine & Freschi
  cheese(emoji: '🧀', pricePerUnit: 4.00),
  egg(emoji: '🥚', pricePerUnit: 3.00),
  chicken(emoji: '🍗', pricePerUnit: 6.00),
  bacon(emoji: '🥓', pricePerUnit: 4.00),
  meat(emoji: '🥩', pricePerUnit: 10.00),
  fish(emoji: '🐟', pricePerUnit: 12.00),
  shrimp(emoji: '🦐', pricePerUnit: 15.00),

  // Ortofrutta
  salad(emoji: '🥗', pricePerUnit: 2.00),
  tomato(emoji: '🍅', pricePerUnit: 2.50),
  potato(emoji: '🥔', pricePerUnit: 1.50),
  broccoli(emoji: '🥦', pricePerUnit: 2.00),
  mushroom(emoji: '🍄', pricePerUnit: 3.00),
  corn(emoji: '🌽', pricePerUnit: 1.50),

  // Frutta
  apple(emoji: '🍎', pricePerUnit: 2.00),
  pear(emoji: '🍐', pricePerUnit: 2.50),
  banana(emoji: '🍌', pricePerUnit: 1.50),
  lemon(emoji: '🍋', pricePerUnit: 2.00),
  grape(emoji: '🍇', pricePerUnit: 3.00),
  strawberry(emoji: '🍓', pricePerUnit: 4.00),
  peach(emoji: '🍑', pricePerUnit: 3.00),
  watermelon(emoji: '🍉', pricePerUnit: 5.00),
  avocado(emoji: '🥑', pricePerUnit: 2.00),
  pineapple(emoji: '🍍', pricePerUnit: 3.00),

  // Dispensa
  oil(emoji: '🫒', pricePerUnit: 6.00),
  herb(emoji: '🌿', pricePerUnit: 1.50),
  salt(emoji: '🧂', pricePerUnit: 1.00),
  sauce(emoji: '🥫', pricePerUnit: 2.50),
  honey(emoji: '🍯', pricePerUnit: 5.00),

  // Nuts
  nut(emoji: '🥜', pricePerUnit: 5.00),
  chestnut(emoji: '🌰', pricePerUnit: 4.00),

  // Snack
  chips(emoji: '🍟', pricePerUnit: 2.50),
  popcorn(emoji: '🍿', pricePerUnit: 3.00),
  pretzel(emoji: '🥨', pricePerUnit: 2.00),

  // Asian Food
  sushi(emoji: '🍣', pricePerUnit: 12.00),
  bento(emoji: '🍱', pricePerUnit: 10.00),
  dumpling(emoji: '🥟', pricePerUnit: 6.00),
  ramen(emoji: '🍜', pricePerUnit: 4.00),
  taco(emoji: '🌮', pricePerUnit: 3.00),

  // Spicy
  chili(emoji: '🌶️', pricePerUnit: 1.50),

  // Frozen
  frozen(emoji: '🧊', pricePerUnit: 4.00),

  // Default
  other(emoji: '📦', pricePerUnit: 3.00);

  final String emoji;
  final double pricePerUnit;

  const CategoryPrice({
    required this.emoji,
    required this.pricePerUnit,
  });

  /// Trova la categoria corrispondente ad un prodotto basandosi sul nome
  static CategoryPrice getCategoryForProduct(String productName) {
    final name = productName.toLowerCase().trim();

    // Cerchiamo nel categoryMapData per trovare l'emoji corrispondente
    for (var entry in categoryMapData.entries) {
      final emoji = entry.key;
      final keywords = entry.value;

      if (_containsAny(name, keywords)) {
        // Trova il CategoryPrice con questa emoji
        final category = CategoryPrice.values.firstWhere(
          (c) => c.emoji == emoji,
          orElse: () => CategoryPrice.other,
        );
        return category;
      }
    }

    return CategoryPrice.other;
  }

  /// Calcola il valore stimato di un prodotto basandosi sulla categoria e quantità
  static double getEstimatedValue(String productName, {double quantity = 1.0}) {
    final category = getCategoryForProduct(productName);
    return category.pricePerUnit * quantity;
  }

  /// Helper per verificare se il nome contiene una delle keywords
  static bool _containsAny(String input, List<String> keywords) {
    final inputWords = input.split(' ');

    for (var keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();

      // Match esatto della parola intera
      if (inputWords.any((w) => w == lowerKeyword)) {
        return true;
      }
      // Match parziale come fallback
      if (input.contains(lowerKeyword)) {
        return true;
      }
    }
    return false;
  }
}
