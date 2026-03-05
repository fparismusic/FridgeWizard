import 'package:flutter/cupertino.dart';
import '../utils/categories.dart';

class CategoryMapper {

  static Widget getIconForProduct(String inputName) {
    final name = inputName.toLowerCase().trim();

    // Cerchiamo se una delle keywords è contenuta nel nome del prodotto
    for (var entry in categoryMapData.entries) {
      final icon = entry.key;
      final keywords = entry.value;

      if (_containsAny(name, keywords)) {
        return Text(icon, style: const TextStyle(fontSize: 28));
      }
    }

    // 3. Default
    return const Icon(
        CupertinoIcons.cube_box,
        color: CupertinoColors.systemGrey,
        size: 28
    );
  }

  // Helper ottimizzato
  static bool _containsAny(String input, List<String> keywords) {
    final inputWords = input.split(' ');

    for (var keyword in keywords) {
      if (inputWords.contains(keyword)) return true;

      for (var word in inputWords) {
        if (word.startsWith(keyword) && (word.length - keyword.length <= 2)) {
          return true;
        }
      }
    }

    if (keywords.contains(input)) return true;

    return false;
  }
}