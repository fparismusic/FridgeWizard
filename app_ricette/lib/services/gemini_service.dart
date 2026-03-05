// dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  final String model;
  final http.Client client;

  GeminiService({
    String? apiKey,
    String? model,
    http.Client? client,
  })  : apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
        model = model ?? dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash-latest',
        client = client ?? http.Client();


  Future<String> extractGenericName(String productName) async {
    const String validCategories = '''
    - Beverages: water, coffee, tea, wine, beer, milk, juice
    - Carbs: pasta, rice, pizza, bread, cookie, croissant, cake, chocolate, ice cream, cereal, bagel
    - Proteins: cheese, egg, chicken, bacon, meat, fish, shrimp
    - Vegetables: salad, tomato, potato, broccoli, mushroom, corn
    - Fruits: apple, pear, banana, lemon, grape, strawberry, peach, watermelon, avocado, pineapple
    - Pantry: oil, salt, sugar, herb, sauce, honey
    - Nuts: nut, chestnut
    - Snack: chips, popcorn, pretzel
    - Asian Food: sushi, bento, dumpling, ramen, taco
    - Spicy: chili
    - Frozen: ice
    ''';

    final prompt = '''
Analizza il prodotto (nome prodotto): "$productName".

Il tuo compito è CLASSIFICARLO scegliendo ESATTAMENTE una sola parola chiave dalla seguente lista valida.
Se il prodotto non rientra perfettamente, scegli la categoria più vicina o più logica.
Se è un prodotto non commestibile o sconosciuto, rispondi "Other".

REGOLE FONDAMENTALI:
1. Rispondi SOLO con la parola chiave scelta (in inglese).
2. Se il prodotto è plurale, CONVERTILO AL SINGOLARE presente nella lista (es. "Mele" -> "apple", "Pomodori" -> "tomato").

LISTA CATEGORIE VALIDE:
$validCategories

Esempi:
- "Latte Granarolo Intero 1L" → "Milk"
- "Pasta Barilla Penne 500g" → "Pasta"
- "Pomodori San Marzano Bio" → "Tomato"

Rispondi SOLO con la parola chiave scelta (in inglese). Niente altro.
Nome generico:''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 50,
      }
    };

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body);

    // Estraggo la lista candidates in modo sicuro
    final candidates = json['candidates'] as List?;

    // Controllo che non sia null E che abbia almeno un elemento
    if (candidates != null && candidates.isNotEmpty) {

      final parts = candidates[0]['content']?['parts'] as List?;

      if (parts != null && parts.isNotEmpty) {
        final text = parts[0]['text'] ?? '';
        return text.toString().trim();
      }
    }
    return '';
  }
}
