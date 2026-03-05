import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app_ricette/screens/login_page.dart';

// --- MOCKS ---

class FakeUser implements User {
  @override final String uid = '123';
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthCredential implements AuthCredential {
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override User? get user => FakeUser();
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements FirebaseAuth {
  bool signInCalled = false;
  bool signUpCalled = false;
  bool resetPasswordCalled = false;
  bool googleSignInCalled = false;

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'fail@test.com') throw FirebaseAuthException(code: 'user-not-found', message: 'User not found');
    signInCalled = true;
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    if (email == 'exists@test.com') throw FirebaseAuthException(code: 'email-already-in-use', message: 'Email exists');
    signUpCalled = true;
    return FakeUserCredential();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {
    if (email == 'fail@reset.com') throw FirebaseAuthException(code: 'invalid-email');
    resetPasswordCalled = true;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    googleSignInCalled = true;
    return FakeUserCredential();
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoogleAuth implements GoogleSignInAuthentication {
  @override String get accessToken => 'fake_token';
  @override String get idToken => 'fake_id_token';
  @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class MockGoogleAccount implements GoogleSignInAccount {
  @override
  Future<GoogleSignInAuthentication> get authentication async => MockGoogleAuth();
  @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeGoogleSignIn implements GoogleSignIn {
  bool shouldSucceed = false;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (shouldSucceed) {
      return MockGoogleAccount();
    }
    return null;
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LoginPage Tests', () {

    late FakeAuth fakeAuth;
    late FakeGoogleSignIn fakeGoogleSignIn;

    setUp(() {
      fakeAuth = FakeAuth();
      fakeGoogleSignIn = FakeGoogleSignIn();
    });

    // HELPER: Use this instead of pumpAndSettle to avoid Lottie Timeouts
    Future<void> pumpSafe(WidgetTester tester) async {
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 500)); 
    }

    group('Mobile View Tests', () {

      testWidgets('Rendering Iniziale (Mobile): Mostra Logo e Campi Login', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        expect(find.text('FridgeWizard'), findsOneWidget);
        expect(find.text('Enter your kingdom'), findsOneWidget);
      });

      testWidgets('Switch Mode (Mobile): Passa da Login a Registrazione', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.tap(find.text('Create your account'));
        await pumpSafe(tester);

        expect(find.text('Create your account'), findsWidgets);
        expect(find.text('Claim your kingdom'), findsOneWidget);
      });

      testWidgets('Validazione (Mobile): Errore Email non valida', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        // FIX: Find by Placeholder ('Email'), not the value
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'bad-email');
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Password'), 'Password123!');
        
        await tester.tap(find.text('Step in'));
        await pumpSafe(tester);

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Insert a valid email address'), findsOneWidget);
      });

      testWidgets('Validazione Password (Mobile): Controllo requisiti in Registrazione', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.tap(find.text('Create your account'));
        await pumpSafe(tester);

        // FIX: Find by Placeholder ('Email'), not the value
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'test@test.com');
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Password'), 'WeakPass');
        
        await tester.tap(find.text('Claim your kingdom'));
        await pumpSafe(tester);

        expect(find.text('Error'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(CupertinoAlertDialog),
                matching: find.textContaining('Password must')
            ),
            findsOneWidget
        );
      });

      testWidgets('Login Flow (Mobile): Chiama signInWithEmailAndPassword', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'valid@test.com');
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Password'), 'ValidPass1!');
        
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await tester.tap(find.text('Step in'));
        await pumpSafe(tester);

        expect(fakeAuth.signInCalled, isTrue);
      });

      testWidgets('Register Flow (Mobile): Chiama createUserWithEmailAndPassword', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.tap(find.text('Create your account'));
        await pumpSafe(tester);

        // FIX: Find by Placeholder ('Email'), not the value
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Email'), 'new@test.com');
        await tester.enterText(find.widgetWithText(CupertinoTextField, 'Password'), 'StrongP@ss1');
        
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await tester.tap(find.text('Claim your kingdom'));
        await pumpSafe(tester);

        expect(fakeAuth.signUpCalled, isTrue);
      });

      testWidgets('Forgot Password (Mobile): Apre Dialogo e invia email', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.tap(find.text('Forgot Password?'));
        await pumpSafe(tester);

        expect(find.text('Reset Password'), findsOneWidget);

        final dialogInput = find.descendant(
            of: find.byType(CupertinoAlertDialog),
            matching: find.byType(CupertinoTextField)
        );
        await tester.enterText(dialogInput, 'reset@test.com');

        await tester.tap(find.text('Send'));
        await pumpSafe(tester);

        expect(fakeAuth.resetPasswordCalled, isTrue);
        expect(find.text('Email Sent'), findsOneWidget);
      });

      testWidgets('Google Sign In (Mobile): Success flow calls auth.signInWithCredential', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        fakeGoogleSignIn.shouldSucceed = true;

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        await tester.tap(find.text('Enter with Google'));

        await pumpSafe(tester);

        expect(fakeAuth.googleSignInCalled, isTrue);
      });
    });

    group('Tablet View Tests', () {
      testWidgets('Layout (Tablet): Card centrata e leggibile', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(home: LoginPage(auth: fakeAuth, googleSignIn: fakeGoogleSignIn)),
        );
        await pumpSafe(tester);

        expect(find.text('Enter your kingdom'), findsOneWidget);
        expect(find.byType(CupertinoTextField), findsWidgets);
      });
    });
  });
}