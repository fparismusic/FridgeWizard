import 'package:flutter_test/flutter_test.dart';
import 'package:app_ricette/models/ingredient.dart';

void main() {
  group('Ingredient Model Tests', () {

    // TEST 1: Parsing Felice
    test('fromJson parsa correttamente un JSON completo', () {
      final Map<String, dynamic> json = {
        'id': '123',
        'nome': 'Pomodori',
        'scadenza': '01/01/2025',
        'note': 'Per la pizza',
        'quantity': '2',
        'unit': 'kg',
        'genericName': 'tomato'
      };

      final ingredient = Ingredient.fromJson(json);

      expect(ingredient.id, '123');
      expect(ingredient.nome, 'Pomodori');
      expect(ingredient.quantity, '2');
      expect(ingredient.unit, 'kg');
      expect(ingredient.genericName, 'tomato');
    });

    // TEST 2: Resilience (fromJson defaults)
    test('fromJson gestisce i valori NULL e applica i default specifici (es. unit -> g)', () {
      final Map<String, dynamic> badJson = {
        'id': '456',
        // 'nome' manca!
        // 'quantity' manca!
        // 'unit' manca! -> fromJson mette 'g'
        'scadenza': '01/01/2025',
      };

      final ingredient = Ingredient.fromJson(badJson);

      expect(ingredient.nome, '');
      expect(ingredient.quantity, '');
      expect(ingredient.note, '');
      expect(ingredient.genericName, '');
      
      // COPERTURA AGGIUNTIVA: 
      // fromJson ha un default diverso dal costruttore ('g' vs 'pcs')
      expect(ingredient.unit, 'g'); 
    });

    // TEST 3: Serializzazione
    test('toJson converte l oggetto in Mappa correttamente', () {
      final ingredient = Ingredient(
          id: '789',
          nome: 'Latte',
          scadenza: '10/10/2024',
          note: '',
          quantity: '1',
          unit: 'L'
      );

      final json = ingredient.toJson();

      expect(json['nome'], 'Latte');
      expect(json['quantity'], '1');
      expect(json['unit'], 'L');
    });

    // TEST 4: Getters (Helper)
    test('Getters (qty, displayName, genName) restituiscono i valori corretti', () {
      final ingredient = Ingredient(
        nome: 'Mela',
        scadenza: 'domani',
        note: '',
        quantity: '5',
        unit: 'pcs',
        genericName: 'apple',
      );

      expect(ingredient.qty, '5');
      expect(ingredient.displayName, 'Mela');
      expect(ingredient.genName, 'apple');
    });

    // --- NUOVO TEST PER IL COSTRUTTORE ---
    test('Costruttore applica i valori di default corretti (es. unit -> pcs)', () {
      // Istanzio manualmente senza passare unit e genericName
      final ingredient = Ingredient(
        nome: 'Uova',
        scadenza: '10/10',
        note: 'Bio',
        quantity: '6',
        // unit omesso -> deve diventare 'pcs'
        // genericName omesso -> deve diventare ''
      );

      expect(ingredient.unit, 'pcs'); // Diverso da fromJson!
      expect(ingredient.genericName, '');
    });

  });
}