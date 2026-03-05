import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_ricette/screens/auth_page.dart';
import 'package:app_ricette/screens/login_page.dart'; // Import necessario per find.byType

// --- MOCK USER ---
class FakeUser implements User {
  @override final String uid = '123';
  @override final String? email = 'test@test.com';
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- MOCK AUTH ---
class FakeFirebaseAuth implements FirebaseAuth {
  final Stream<User?> _authStateStream;

  FakeFirebaseAuth(this._authStateStream);

  @override
  Stream<User?> authStateChanges() => _authStateStream;

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthPage Logic Tests', () {

    // Controller per pilotare lo stream di autenticazione
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>();
    });

    tearDown(() {
      authController.close();
    });

    testWidgets('Utente NON Loggato: Mostra Login Page', (WidgetTester tester) async {
      final fakeAuth = FakeFirebaseAuth(authController.stream);

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('FAKE_LOGIN_PAGE'),
            homeBuilder: (_) => const Text('FAKE_HOME_PAGE'),
          ),
        ),
      );

      // Emetto "null" nello stream
      authController.add(null);
      await tester.pump();

      expect(find.text('FAKE_LOGIN_PAGE'), findsOneWidget);
      expect(find.text('FAKE_HOME_PAGE'), findsNothing);
    });

    testWidgets('Utente Loggato: Mostra Home Page', (WidgetTester tester) async {
      final fakeAuth = FakeFirebaseAuth(authController.stream);
      final fakeUser = FakeUser();

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('FAKE_LOGIN_PAGE'),
            homeBuilder: (_) => const Text('FAKE_HOME_PAGE'),
          ),
        ),
      );

      authController.add(fakeUser);
      await tester.pump();

      expect(find.text('FAKE_HOME_PAGE'), findsOneWidget);
      expect(find.text('FAKE_LOGIN_PAGE'), findsNothing);
    });

    testWidgets('Transizione Dinamica: Login -> Home -> Login', (WidgetTester tester) async {
      final fakeAuth = FakeFirebaseAuth(authController.stream);
      final fakeUser = FakeUser();

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('FAKE_LOGIN_PAGE'),
            homeBuilder: (_) => const Text('FAKE_HOME_PAGE'),
          ),
        ),
      );

      // Utente nullo
      authController.add(null);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('FAKE_LOGIN_PAGE'), findsOneWidget);

      // Utente si logga
      authController.add(fakeUser);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('FAKE_HOME_PAGE'), findsOneWidget);

      // Utente fa logout
      authController.add(null);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('FAKE_LOGIN_PAGE'), findsOneWidget);
    });

    // --- NUOVI TEST PER COPERTURA EXTRA ---

    testWidgets('Stato Iniziale (Waiting): Mostra Login Page mentre attende connessione', (WidgetTester tester) async {
      // In questo test NON emettiamo nulla nello stream (authController.add non viene chiamato).
      // Lo StreamBuilder sarà in stato "waiting".
      // La logica `if (snapshot.hasData)` sarà false, quindi deve mostrare il LoginBuilder.
      
      final fakeAuth = FakeFirebaseAuth(authController.stream);

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('FAKE_LOGIN_PAGE'),
            homeBuilder: (_) => const Text('FAKE_HOME_PAGE'),
          ),
        ),
      );

      // Verifichiamo subito dopo il pump iniziale
      expect(find.text('FAKE_LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('Safety Fallback: Se auth è null, usa FirebaseAuth.instance (branch coverage)', (WidgetTester tester) async {
      // Questo test copre la riga: "final firebaseAuth = auth ?? FirebaseAuth.instance;"
      // Non passiamo 'auth' al costruttore.
      // Poiché siamo in un test unitario senza aver configurato Firebase.initializeApp(),
      // accedere a FirebaseAuth.instance lancerà un'eccezione "[core/no-app]".
      // Intercettare questa eccezione prova che il codice è entrato nel ramo "else" del null check.

      await tester.pumpWidget(
        const CupertinoApp(
          home: AuthPage(
            // auth: null, // Lasciamo che usi il default
          ),
        ),
      );

      // Ci aspettiamo che il widget fallisca nel build a causa dell'istanza mancante
      expect(tester.takeException(), isNotNull);
    });

  });

  group('AuthPage - Coverage Expansion', () {
    // Controller per pilotare lo stream di autenticazione
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>();
    });

    tearDown(() {
      authController.close();
    });

    testWidgets('Stream Error: Se lo stream ha errore, mostra Login Page (fail-safe)', (WidgetTester tester) async {
      // Se lo stream emette errore, snapshot.hasData è false. Deve mostrare Login.
      final fakeAuth = FakeFirebaseAuth(authController.stream);

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('FAKE_LOGIN_PAGE'),
            homeBuilder: (_) => const Text('FAKE_HOME_PAGE'),
          ),
        ),
      );

      // Emetto errore
      authController.addError('Errore Generico');
      await tester.pump();

      expect(find.text('FAKE_LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('Default Builders: Se homeBuilder è null, usa HomePage (branch check)', (WidgetTester tester) async {
      // Verifica che venga usato il ramo `?? const HomePage()`.
      // Ci aspettiamo un'eccezione perché HomePage reale prova ad accedere a Firestore reale nel suo initState.
      
      final fakeAuth = FakeFirebaseAuth(authController.stream);
      final fakeUser = FakeUser();

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            loginBuilder: (_) => const Text('LOGIN'),
            // homeBuilder: null (default)
          ),
        ),
      );

      authController.add(fakeUser);
      await tester.pump();

      // Se catturiamo l'eccezione, significa che ha provato a costruire HomePage e inizializzare i servizi
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('Default Builders: Se loginBuilder è null, usa LoginPage (branch check)', (WidgetTester tester) async {
      // Verifica che venga usato il ramo `?? const LoginPage()`.
      // A differenza della HomePage, la LoginPage NON accede ai servizi in build/initState,
      // quindi non crasha subito. Verifichiamo che il widget venga renderizzato.
      
      final fakeAuth = FakeFirebaseAuth(authController.stream);

      await tester.pumpWidget(
        CupertinoApp(
          home: AuthPage(
            auth: fakeAuth,
            // loginBuilder: null (default)
            homeBuilder: (_) => const Text('HOME'),
          ),
        ),
      );

      authController.add(null);
      await tester.pump();

      // Qui non ci aspettiamo eccezioni, ma che venga trovato il widget LoginPage
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}