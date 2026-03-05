import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart';
import '../utils/is_tablet.dart';

class LoginPage extends StatefulWidget {
  final FirebaseAuth? auth;
  final GoogleSignIn? googleSignIn;

  const LoginPage({
    super.key, 
    this.auth, 
    this.googleSignIn
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _passwordError;
  bool _isLogin = true;
  bool _isLoading = false;

  // Dependency Injection Helpers
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => widget.googleSignIn ?? GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    // Real-time validation only for registration
    if (!_isLogin) {
      setState(() {
        _passwordError = _validatePassword(_passwordController.text);
      });
    } else if (_passwordError != null) {
      setState(() => _passwordError = null);
    }
  }

  String? _validatePassword(String password) {
    final pattern = r'''^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$%\^&\*\(\)\-\_=\+\[\]\{\}\|\\;:'",<>\./\?`~])[A-Za-z\d!@#\$%\^&\*\(\)\-\_=\+\[\]\{\}\|\\;:'",<>\./\?`~]{8,}$''';
    final regex = RegExp(pattern);
    if (password.isEmpty) return 'Password is required';
    if (!regex.hasMatch(password)) {
      return 'Password must be ≥8 chars, include uppercase, lowercase, number and special character';
    }
    return null;
  }

  // Email validation using regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }


  Future<void> _authenticate() async {
    // Validate email format
    if (!_isValidEmail(_emailController.text.trim())) {
      _showError('Insert a valid email address');
      return;
    }

    // Validate password for registration
    if (!_isLogin) {
      final passwordError = _validatePassword(_passwordController.text);
      if (passwordError != null) {
        _showError(passwordError);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Use the injected instance
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) { // Removed stacktrace to keep it simple
      debugPrint('Google sign-in error: $e');
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();

    try {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            children: [
              const SizedBox(height: 8),
              const Text('Enter your email address to receive a password reset link'),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: emailController,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (result == true) {
        final email = emailController.text.trim();

        if (!_isValidEmail(email)) {
          _showError('Insert a valid email address');
          return;
        }

        try {
          await _auth.sendPasswordResetEmail(email: email);

          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Email Sent'),
                content: const Text('Check your inbox for the password reset link'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    } finally {
      emailController.dispose();
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final primary = theme.primaryColor;

    Widget _buildPasswordField() {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          CupertinoTextField(
          key: const Key('passwordField'), // Merged: Added your Key here
          controller: _passwordController,
          placeholder: 'Password',
          obscureText: true,
          padding: const EdgeInsets.all(12),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(CupertinoIcons.lock_fill, size: 20),
          ),
        ),
        if (_passwordError != null && !_isLogin)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _passwordError!,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Welcome to'),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 208,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Lottie.asset('assets/lottie/magic.json', height: 160),
                        Text(
                          'FridgeWizard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Magic in tracking. Mastery in planning ✨',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),

                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ScreenSize.isTablet(context) ? 400 : double.infinity,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey,
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              _isLogin ? 'Enter your kingdom' : 'Create your account',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            key: const Key('emailField'),
                            controller: _emailController,
                            placeholder: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            padding: const EdgeInsets.all(12),
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(CupertinoIcons.mail_solid, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Merged: Using the helper function that now contains your Key
                          _buildPasswordField(),
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                onPressed: _isLoading ? null : _resetPassword,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              key: const Key('authButton'),
                              onPressed: _isLoading ? null : _authenticate,
                              child: _isLoading
                                  ? const CupertinoActivityIndicator()
                                  : Text(_isLogin ? 'Step in' : 'Claim your kingdom'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: CupertinoColors.systemGrey4,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: CupertinoColors.systemGrey4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(CupertinoIcons.person_crop_circle_badge_checkmark),
                                  SizedBox(width: 8),
                                  Text('Enter with Google'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                    const SizedBox(height: 16),

                    CupertinoButton(
                      key: const Key('toggleAuthMode'),
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? 'Create your account'
                            : 'Already have a kingdom? Enter!',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}