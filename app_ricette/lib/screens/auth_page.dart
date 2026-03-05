import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthPage extends StatelessWidget {
  final FirebaseAuth? auth;
  final Widget Function(BuildContext)? homeBuilder;
  final Widget Function(BuildContext)? loginBuilder;

  const AuthPage({
    super.key,
    this.auth,
    this.homeBuilder,
    this.loginBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;

    return StreamBuilder<User?>(
      stream: firebaseAuth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return homeBuilder?.call(context) ?? const HomePage();
        } else {
          return loginBuilder?.call(context) ?? const LoginPage();
        }
      },
    );
  }
}
