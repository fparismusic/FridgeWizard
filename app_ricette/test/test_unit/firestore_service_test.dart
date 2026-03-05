import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:app_ricette/services/firestore_service.dart';
import 'package:app_ricette/models/ingredient.dart';

void main() {
  group('FirestoreService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late FirestoreService service;
    late MockUser mockUser;

    setUp(() async {
      // Inizializzo il database finto e l'auth finto
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(uid: 'test_user_123');

      // Simulo un login utente (fondamentale perché _userId serve)
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      await mockAuth.signInWithCustomToken('test_token'); // Logga l'utente nel mock

      // Inietto le dipendenze
      service = FirestoreService(firestore: fakeFirestore, auth: mockAuth);
    });

    test('addIngredient salva i dati nel path corretto', () async {
      final ingredient = Ingredient(
        nome: 'Pasta',
        quantity: '500',
        unit: 'g',
        scadenza: '01/01/2025',
        note: 'Barilla',
        genericName: 'pasta',
      );

      await service.addIngredient(ingredient);

      // Verifico direttamente nel "database finto"
      final snapshot = await fakeFirestore
          .collection('users')
          .doc(mockAuth.currentUser!.uid)
          .collection('fridge')
          .get();

      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['nome'], 'Pasta');

      // Verifico che l'ID sia stato assegnato all'oggetto locale
      expect(ingredient.id, isNotNull);
    });

    test('loadFridge recupera i dati correttamente', () async {
      // Preparo il DB con dei dati
      await fakeFirestore
          .collection('users')
          .doc(mockAuth.currentUser!.uid)
          .collection('fridge')
          .add({
        'nome': 'Latte',
        'quantity': '1',
        'unit': 'L',
        'scadenza': '10/10/2024',
        'note': '',
        'genericName': 'milk'
      });

      // Chiamo il metodo del service
      final items = await service.loadFridge();

      // Verifico
      expect(items.length, 1);
      expect(items.first.nome, 'Latte');
      expect(items.first.id, isNotNull);
    });

    test('updateIngredient modifica il documento esistente', () async {
      // Aggiungo dato iniziale
      final docRef = await fakeFirestore
          .collection('users')
          .doc(mockAuth.currentUser!.uid)
          .collection('fridge')
          .add({
        'nome': 'Mela',
        'quantity': '2',
        'unit': 'pcs',
        'scadenza': '',
        'note': '',
        'genericName': 'apple'
      });

      // Creo oggetto aggiornato (con lo stesso ID)
      final updatedIngredient = Ingredient(
        id: docRef.id,
        nome: 'Mela Rossa', // Nome cambiato
        quantity: '5',      // Quantità cambiata
        unit: 'pcs',
        scadenza: '',
        note: '',
        genericName: 'apple',
      );

      // Eseguo update
      await service.updateIngredient(updatedIngredient);

      // Verifico nel DB
      final docSnapshot = await docRef.get();
      expect(docSnapshot.data()!['nome'], 'Mela Rossa');
      expect(docSnapshot.data()!['quantity'], '5');
    });

    // --- NUOVO TEST: updateIngredient con ID nullo ---
    test('updateIngredient non fa nulla se ingredient.id è null', () async {
      // Creo un ingrediente senza ID
      final noIdIngredient = Ingredient(
        nome: 'Fantasma',
        quantity: '1',
        unit: 'pcs',
        scadenza: '',
        note: '',
      );

      // Provo a fare update
      await service.updateIngredient(noIdIngredient);

      // Verifico che il DB sia ancora vuoto (o invariato)
      final snapshot = await fakeFirestore
          .collection('users')
          .doc(mockUser.uid)
          .collection('fridge')
          .get();
      expect(snapshot.docs.length, 0);
    });
    // -----------------------------------------------

    test('deleteIngredient rimuove il documento', () async {
      // Aggiungo dato
      final docRef = await fakeFirestore
          .collection('users')
          .doc(mockAuth.currentUser!.uid)
          .collection('fridge')
          .add({
        'nome': 'Da Cancellare',
        'quantity': '1',
        'unit': 'kg',
        'scadenza': '',
        'note': '',
        'genericName': 'trash'
      });

      // Verifico che esista
      expect((await fakeFirestore.collection('users').doc(mockAuth.currentUser!.uid).collection('fridge').get()).docs.length, 1);

      // Eseguo delete
      await service.deleteIngredient(docRef.id);

      // Verifico che non esista più
      final snapshot = await fakeFirestore.collection('users').doc(mockAuth.currentUser!.uid).collection('fridge').get();
      expect(snapshot.docs.length, 0);
    });

    test('streamFridge emette i dati presenti nel DB', () async {
      final user = MockUser(uid: 'user_stream_id', email: 'stream@test.com');
      final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      final firestore = FakeFirebaseFirestore();
      final localService = FirestoreService(firestore: firestore, auth: auth);

      await firestore
          .collection('users')
          .doc('user_stream_id')
          .collection('fridge')
          .add({
        'nome': 'Stream Item',
        'quantity': '1',
        'unit': 'x',
        'scadenza': '',
        'note': '',
        'genericName': 'stream'
      });

      // LETTURA: Chiedo lo stream
      final stream = localService.streamFridge();

      // VERIFICo: Prendo il primo elemento emesso
      // fake_cloud_firestore emette lo stato attuale istantaneamente
      final list = await stream.first;

      expect(list, isNotEmpty, reason: "Lo stream ha restituito una lista vuota (probabile errore auth)");
      expect(list.first.nome, 'Stream Item');
    });

    test('Se utente non loggato, i metodi ritornano vuoto o non fanno nulla', () async {

      final signedOutAuth = MockFirebaseAuth(signedIn: false);
      final serviceNoAuth = FirestoreService(firestore: fakeFirestore, auth: signedOutAuth);

      // Add: non deve fare nulla
      final ing = Ingredient(nome: 'Test', quantity: '1', unit: 'g', scadenza: '', note: '');
      await serviceNoAuth.addIngredient(ing);
      // Verifico DB vuoto
      final snapshot = await fakeFirestore.collection('users').get();
      expect(snapshot.docs.isEmpty, isTrue);

      // Load: deve ritornare lista vuota
      final list = await serviceNoAuth.loadFridge();
      expect(list, isEmpty);

      // Update: non deve crashare
      ing.id = '123';
      await serviceNoAuth.updateIngredient(ing);

      // Delete: non deve crashare
      await serviceNoAuth.deleteIngredient('123');

      // Stream: deve ritornare stream vuoto
      final stream = serviceNoAuth.streamFridge();
      final streamResult = await stream.first;
      expect(streamResult, isEmpty);
    });

    // -------------------------------------------------------------------------
    // SAVINGS & TRACKING
    // -------------------------------------------------------------------------
    group('Savings & Tracking Tests', () {

      test('saveUsedProduct aggiunge il record alla collezione used_products', () async {
        final ingredient = Ingredient(
            nome: 'Latte',
            quantity: '1',
            unit: 'L',
            scadenza: '',
            note: '',
            genericName: 'milk'
        );

        await service.saveUsedProduct(ingredient, 1.50);

        final snapshot = await fakeFirestore
            .collection('users')
            .doc(mockUser.uid)
            .collection('used_products')
            .get();

        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first['nome'], 'Latte');
        expect(snapshot.docs.first['estimatedValue'], 1.50);
        // FieldValue.serverTimestamp è gestito da FakeFirestore, verifichiamo che esista
        expect(snapshot.docs.first.data().containsKey('usedAt'), isTrue);
      });

      test('getTotalSavings calcola la somma corretta', () async {
        final collection = fakeFirestore.collection('users').doc(mockUser.uid).collection('used_products');
        await collection.add({'estimatedValue': 2.50});
        await collection.add({'estimatedValue': 1.50});
        await collection.add({'estimatedValue': 6.00}); // Totale atteso: 10.00

        final total = await service.getTotalSavings();
        expect(total, 10.00);
      });

      test('streamTotalSavings emette aggiornamenti in tempo reale', () async {
        final collection = fakeFirestore.collection('users').doc(mockUser.uid).collection('used_products');

        // Inizia lo stream
        final stream = service.streamTotalSavings();

        // Aggiungi dato
        await collection.add({'estimatedValue': 5.00});

        // Verifica: FakeFirestore emette lo stato corrente
        expect(await stream.first, 5.00);
      });

      test('deleteIngredientWithTracking (FRESCO): Cancella da frigo E salva risparmio', () async {
        // Setup Frigo
        final docRef = await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
          'nome': 'Bistecca',
          'quantity': '1',
          'unit': 'pz',
          'genericName': 'meat',
          'scadenza': '',
          'note': ''
        });

        final ing = Ingredient(
            id: docRef.id,
            nome: 'Bistecca',
            quantity: '1',
            unit: 'pz',
            genericName: 'meat', // Match category 'meat' -> 10.0
            scadenza: '',
            note: ''
        );

        // Chiamata: NON SCADUTO (isExpired: false)
        await service.deleteIngredientWithTracking(ing, isExpired: false);

        // Verifica Frigo (Deve essere vuoto)
        final fridgeSnap = await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').get();
        expect(fridgeSnap.docs.length, 0, reason: "Il prodotto doveva essere rimosso dal frigo");

        // Verifica Risparmi (Deve esserci 1 record)
        final usedSnap = await fakeFirestore.collection('users').doc(mockUser.uid).collection('used_products').get();
        expect(usedSnap.docs.length, 1, reason: "Il prodotto doveva essere salvato in used_products");

        // Verifica valore (Meat price è 10.0 * 1 = 10.0)
        expect(usedSnap.docs.first['estimatedValue'], 10.00);
      });

      test('deleteIngredientWithTracking (SCADUTO): Cancella da frigo MA NON salva risparmio', () async {
        // Setup Frigo
        final docRef = await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
          'nome': 'Latte',
          'quantity': '1',
          'unit': 'L',
          'genericName': 'milk',
          'scadenza': '',
          'note': ''
        });

        final ing = Ingredient(
            id: docRef.id,
            nome: 'Latte',
            quantity: '1',
            unit: 'L',
            genericName: 'milk',
            scadenza: '',
            note: ''
        );

        // Chiamata: SCADUTO (isExpired: true)
        await service.deleteIngredientWithTracking(ing, isExpired: true);

        // Verifica Frigo (Deve essere vuoto)
        final fridgeSnap = await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').get();
        expect(fridgeSnap.docs.length, 0);

        // Verifica Risparmi (Deve essere vuoto perché è stato sprecato)
        final usedSnap = await fakeFirestore.collection('users').doc(mockUser.uid).collection('used_products').get();
        expect(usedSnap.docs.length, 0, reason: "Il prodotto scaduto NON deve finire nei risparmi");
      });
    });

  });
}