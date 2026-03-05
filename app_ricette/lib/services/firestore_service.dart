import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_price.dart';
import '../models/ingredient.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Push: Aggiungi prodotto
  Future<void> addIngredient(Ingredient ingredient) async {
    if (_userId == null) return;

    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('fridge')
        .add(ingredient.toJson());

    ingredient.id = docRef.id;
  }

  // Push: Aggiorna prodotto
  Future<void> updateIngredient(Ingredient ingredient) async {
    if (_userId == null || ingredient.id == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('fridge')
        .doc(ingredient.id)
        .update(ingredient.toJson());
  }

  // Push: Elimina prodotto
  Future<void> deleteIngredient(String ingredientId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('fridge')
        .doc(ingredientId)
        .delete();
  }

  // Pull: Carica tutti i prodotti
  Future<List<Ingredient>> loadFridge() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('fridge')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Ingredient.fromJson({
        ...data,
        'id': doc.id,
      });
    }).toList();
  }

  // Stream in tempo reale (opzionale)
  Stream<List<Ingredient>> streamFridge() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('fridge')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Ingredient.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    });
  }

  // ============ USED PRODUCTS (Savings Tracking) ============
  Future<void> saveUsedProduct(Ingredient ingredient, double estimatedValue) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('used_products')
        .add({
      'nome': ingredient.nome,
      'genericName': ingredient.genericName,
      'quantity': ingredient.quantity,
      'unit': ingredient.unit,
      'estimatedValue': estimatedValue,
      'usedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<double> getTotalSavings() async {
    if (_userId == null) return 0.0;

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('used_products')
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['estimatedValue'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }


  Stream<double> streamTotalSavings() {
    if (_userId == null) return Stream.value(0.0);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('used_products')
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['estimatedValue'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    });
  }

  Future<void> deleteIngredientWithTracking(Ingredient ingredient, {required bool isExpired}) async {
    if (_userId == null || ingredient.id == null) return;

    // Se non è scaduto, traccia il risparmio
    if (!isExpired) {
      // Calcola quantità numerica
      double qty = double.tryParse(ingredient.quantity) ?? 1.0;

      // Usa il genericName se disponibile, altrimenti il nome
      String productName = ingredient.genericName.isNotEmpty
          ? ingredient.genericName
          : ingredient.nome;

      double estimatedValue = CategoryPrice.getEstimatedValue(productName, quantity: qty);
      await saveUsedProduct(ingredient, estimatedValue);
    }

    // Elimina il prodotto dal frigo
    await deleteIngredient(ingredient.id!);
  }
}
