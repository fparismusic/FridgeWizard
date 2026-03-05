import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  final http.Client client;
  BarcodeService({http.Client? client}) : client = client ?? http.Client();

  // Mappa unità di misura comuni
  static const Map<String, String> _unitMap = {
    'g': 'g',
    'kg': 'kg',
    'l': 'L',
    'ml': 'ml',
    'cl': 'ml', // converti cl in ml
    'dl': 'ml', // converti dl in ml
    'oz': 'oz',
    'lb': 'lb',
  };

  Future<Map<String, String>?> getProductInfo(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/$barcode.json');
      final response = await client.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 1) {
          final product = data['product'];
          
          String name = product['product_name'] ?? '';
          String quantityRaw = product['quantity'] ?? '';
          String brands = product['brands'] ?? '';

          String genericName = product['generic_name'] ?? '';
          if (name.isEmpty && genericName.isNotEmpty) {
            name = genericName;
          } else if (name.isEmpty) {
            name = 'Unknown Product';
          }

          String displayName = name;
          if (brands.isNotEmpty) {
            displayName = name;
          }

          // Separa quantità e unità di misura
          final parsed = _parseQuantity(quantityRaw);

          //if (kDebugMode) {
            //print("Product GenericName: $genericName");
            //print("generic_name_it: ${product['generic_name_it']}");
            //print("Raw Quantity: $quantityRaw");
            //print("Parsed Quantity: ${parsed['quantity']}");
            //print("Parsed Unit: ${parsed['unit']}");
            //print ("Display Name: $displayName");
            //print ("categories: ${product['categories']}");
            //print ("brands: $brands");
          //}

          return {
            'name': displayName,
            'notes': brands,
            'quantity': parsed['quantity']!,
            'unit': parsed['unit']!,
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching barcode: $e");
    }
    return null;
  }

  // Estrae numero e unità da stringhe come "130g", "1.5 L", "500 ml"
  //da fixare/testare in base alle diverse casistiche
  Map<String, String> _parseQuantity(String quantityString) {
    if (quantityString.isEmpty) {
      return {'quantity': '', 'unit': 'g'};
    }
    String cleaned = quantityString.trim().toLowerCase();

    // Pattern per catturare: numero (con decimali) + unità opzionale
    final RegExp regex = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([a-z]+)?');
    final match = regex.firstMatch(cleaned);

    if (match != null) {
      String quantity = match.group(1) ?? '';
      String unit = match.group(2) ?? '';

      // Sostituisci virgola con punto per i decimali
      quantity = quantity.replaceAll(',', '.');

      // Normalizza l'unità di misura
      if (unit.isNotEmpty && _unitMap.containsKey(unit)) {
        unit = _unitMap[unit]!;
      } else if (unit.isEmpty) {
        // Se non c'è unità, usa 'g' come default
        unit = 'g';
      }
      return {'quantity': quantity , 'unit': unit};
    }

    // Se non riesce a fare il parsing, restituisci la stringa originale come quantità
    return {'quantity': quantityString, 'unit': 'g'};
  }
}