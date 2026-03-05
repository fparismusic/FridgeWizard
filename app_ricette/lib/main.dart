import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui'; // PlatformDispatcher
import 'screens/auth_page.dart';
import 'utils/my_theme_data.dart';
import 'services/notification_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  runApp(const MyApp());
}

// Add a global key for accessing settings page for statistics updates
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// MyApp is a StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// We listen to system changes
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  late Brightness _brightness;

  @override
  void initState() {
    super.initState();
    // We register as observers
    WidgetsBinding.instance.addObserver(this);
    // We instantiate brightness at start
    _brightness = PlatformDispatcher.instance.platformBrightness;
  }

  @override
  void dispose() {
    // memory leak awareness
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When I change theme on the phone this method is called by Flutter
  @override
  void didChangePlatformBrightness() {
    setState(() {
      // Update the variable
      _brightness = PlatformDispatcher.instance.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _brightness == Brightness.dark
        ? MyThemeData.darkTheme
        : MyThemeData.lightTheme;

    return CupertinoApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FridgeWizard',
      theme: currentTheme,
      home: const AuthPage()
    );
  }
}