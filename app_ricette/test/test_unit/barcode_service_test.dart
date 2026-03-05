import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:app_ricette/services/barcode_service.dart';

void main() {
  group('BarcodeService Tests', () {

    MockClient getMockClient(String body, int statusCode) {
      return MockClient((request) async {
        return http.Response(body, statusCode);
      });
    }

    test('getProductInfo restituisce dati corretti se API risponde status 1', () async {
      // JSON simulato da OpenFoodFacts
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "product_name": "Nutella",
          "brands": "Ferrero",
          "quantity": "750g",
          "generic_name": "Hazelnut spread"
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));

      final result = await service.getProductInfo('123456');

      expect(result, isNotNull);
      expect(result!['name'], 'Nutella');
      expect(result['notes'], 'Ferrero');
      expect(result['quantity'], '750');
      expect(result['unit'], 'g');
    });

    test('getProductInfo gestisce Fallback Nome (Generic Name)', () async {
      // Caso: product_name vuoto, ma generic_name presente
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "product_name": null, // o stringa vuota
          "generic_name": "Spaghetti Integrali",
          "quantity": "500g"
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('111');

      expect(result!['name'], 'Spaghetti Integrali');
    });

    test('getProductInfo gestisce Fallback Nome (Unknown)', () async {
      // Caso: Tutto vuoto
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "product_name": "",
          "generic_name": "",
          "quantity": "500g"
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('222');

      expect(result!['name'], 'Unknown Product');
    });

    test('getProductInfo restituisce NULL se il prodotto non esiste (status 0)', () async {
      final mockJson = jsonEncode({
        "status": 0, // Prodotto non trovato
        "status_verbose": "product not found"
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('000000');

      expect(result, isNull);
    });

    test('getProductInfo restituisce NULL se errore HTTP', () async {
      final service = BarcodeService(client: getMockClient('Error', 404));
      final result = await service.getProductInfo('999');

      expect(result, isNull);
    });

    test('Parsing Quantità: Gestisce i litri e normalizza unità', () async {
      final mockJson = jsonEncode({
        "status": 1,
        "product": {"quantity": "1.5 l"} // minuscolo l
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('333');

      expect(result!['quantity'], '1.5');
      expect(result['unit'], 'L'); // Deve diventare Maiuscolo
    });

    test('Parsing Quantità: Gestisce la virgola come separatore', () async {
      final mockJson = jsonEncode({
        "status": 1,
        "product": {"quantity": "1,25kg"} // Virgola
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('444');

      expect(result!['quantity'], '1.25'); // Deve diventare punto
      expect(result['unit'], 'kg');
    });

    test('Parsing Quantità: Gestisce assenza di unità (Default g)', () async {
      final mockJson = jsonEncode({
        "status": 1,
        "product": {"quantity": "500"} // Nessuna unità
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('555');

      expect(result!['quantity'], '500');
      expect(result['unit'], 'g');
    });

    test('Parsing Quantità: Gestisce stringhe sporche', () async {
      final mockJson = jsonEncode({
        "status": 1,
        "product": {"quantity": "  250   ml  "} // Spazi extra
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('666');

      expect(result!['quantity'], '250');
      expect(result['unit'], 'ml');
    });

    test('Parsing Quantità: Mappatura CL -> ML (Nota logica)', () async {
      // NOTA: Nel codice cl -> ml, ma non moltiplichi il valore.
      // Quindi "33 cl" diventa "33 ml" (che è tecnicamente un errore matematico, ma testiamo il codice così com'è).
      final mockJson = jsonEncode({
        "status": 1,
        "product": {"quantity": "33cl"}
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('777');

      expect(result!['quantity'], '33');
      expect(result['unit'], 'ml');
    });

    // --- NUOVO TEST AGGIUNTO ---
    test('Parsing Quantità: Unità sconosciuta viene mantenuta (non normalizzata)', () async {
      // Caso: L'unità viene riconosciuta dalla Regex ma non è nella mappa (es. "bottles")
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "quantity": "6 bottles"
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('unknown_unit');

      expect(result!['quantity'], '6');
      expect(result['unit'], 'bottles'); // Deve rimanere 'bottles', non diventare 'g'
    });
    // ---------------------------

    test('getProductInfo gestisce eccezioni di rete (catch block)', () async {
      // Creiamo un client che lancia un'eccezione Dart invece di ritornare una Response
      final mockClient = MockClient((request) async {
        throw Exception('Errore fatale di rete');
      });

      final service = BarcodeService(client: mockClient);

      // La funzione non deve crashare, ma entrare nel catch, stampare l'errore e ritornare null
      final result = await service.getProductInfo('exception_test');

      expect(result, isNull);
    });

    // COPERTURA STRINGA VUOTA (_parseQuantity)
    test('Parsing Quantità: Gestisce stringa vuota', () async {
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "quantity": "" // Stringa vuota
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('empty_qty');

      // Verifica che entri nel primo if di _parseQuantity
      expect(result!['quantity'], '');
      expect(result['unit'], 'g'); // Default unit
    });

    // COPERTURA REGEX FAIL (_parseQuantity fallback)
    test('Parsing Quantità: Gestisce formato non numerico (Regex mismatch)', () async {
      // La regex si aspetta che la stringa inizi con un numero (^d+).
      // Se scriviamo "circa 100g", la regex fallisce perché inizia con 'c'.
      final mockJson = jsonEncode({
        "status": 1,
        "product": {
          "quantity": "circa 100g"
        }
      });

      final service = BarcodeService(client: getMockClient(mockJson, 200));
      final result = await service.getProductInfo('regex_fail');

      // Verifica che ritorni la stringa originale come quantità
      expect(result!['quantity'], 'circa 100g');
      expect(result['unit'], 'g'); // Default unit
    });

  });
}