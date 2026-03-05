import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_ricette/services/gemini_service.dart';

void main() {
  // Carichiamo variabili d'ambiente finte per evitare errori all'avvio
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=fake_key');
  });

  group('GeminiService Tests', () {

    test('extractGenericName parsa correttamente la risposta JSON e fa il trim', () async {
      // SIMULO LA RISPOSTA DI GEMINI
      final mockResponse = jsonEncode({
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": "  Tomato  \n"
                }
              ],
              "role": "model"
            },
            "finishReason": "STOP",
            "index": 0,
            "safetyRatings": []
          }
        ]
      });

      // CREO IL MOCK CLIENT
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('fake_key')) {
          return http.Response(mockResponse, 200);
        }
        return http.Response('Error', 400);
      });

      final service = GeminiService(client: mockClient);
      final result = await service.extractGenericName('Pomodori');

      expect(result, 'Tomato');
    });

    test('extractGenericName lancia Exception se API fallisce (es. 400/500)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad Request', 400);
      });

      final service = GeminiService(client: mockClient);

      expect(
            () async => await service.extractGenericName('Pasta'),
        throwsA(isA<Exception>()),
      );
    });

    test('extractGenericName gestisce risposta malformata o vuota restituendo stringa vuota', () async {
      // Caso: Candidates lista vuota
      final mockResponse = jsonEncode({
        "candidates": []
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final service = GeminiService(client: mockClient);
      final result = await service.extractGenericName('Boh');

      expect(result, '');
    });

    // --- NUOVI TEST PER COPERTURA PROFONDA ---

    test('extractGenericName gestisce JSON incompleto (candidates null)', () async {
      // Caso: il campo candidates non esiste proprio nel JSON
      final mockResponse = jsonEncode({}); 

      final mockClient = MockClient((request) async => http.Response(mockResponse, 200));
      final service = GeminiService(client: mockClient);
      
      expect(await service.extractGenericName('Test'), '');
    });

    test('extractGenericName gestisce struttura interna mancante (no parts)', () async {
      // Caso: Candidate esiste, ma non ha 'content' o 'parts'
      final mockResponse = jsonEncode({
        "candidates": [
          {
            "content": {} // Manca 'parts'
          }
        ]
      });

      final mockClient = MockClient((request) async => http.Response(mockResponse, 200));
      final service = GeminiService(client: mockClient);

      expect(await service.extractGenericName('Test'), '');
    });

    test('extractGenericName gestisce parts vuoto o senza text', () async {
      // Caso: Parts esiste ma è vuoto O l'elemento dentro non ha 'text'
      final mockResponse = jsonEncode({
        "candidates": [
          {
            "content": {
              "parts": [
                {} // Oggetto vuoto, niente 'text'
              ]
            }
          }
        ]
      });

      final mockClient = MockClient((request) async => http.Response(mockResponse, 200));
      final service = GeminiService(client: mockClient);

      // Qui entra in gioco il "?? ''" finale del codice
      expect(await service.extractGenericName('Test'), '');
    });

    test('extractGenericName invia il body della richiesta correttamente', () async {
      // Verifichiamo che stiamo mandando il prompt giusto
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        final promptSent = body['contents'][0]['parts'][0]['text'];
        
        // Verifica che il prompt contenga il nome del prodotto
        if (promptSent.contains('Analizza il prodotto') && promptSent.contains('Banana')) {
          // Rispondo successo se il body è corretto
          return http.Response(jsonEncode({"candidates": []}), 200);
        }
        return http.Response('Body errato', 400);
      });

      final service = GeminiService(client: mockClient);
      await service.extractGenericName('Banana');
    });

  });
}