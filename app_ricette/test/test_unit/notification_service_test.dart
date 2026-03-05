import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:app_ricette/services/notification_service.dart';

class FakeFlutterLocalNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  int cancelAllCalls = 0;
  int initializeCalls = 0;
  List<int> cancelCalls = [];
  List<Map<String, dynamic>> showCalls = [];
  List<Map<String, dynamic>> scheduleCalls = [];

  @override
  Future<bool?> initialize(
      InitializationSettings initializationSettings, {
        DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
        DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
      }) async {
    initializeCalls++;
    return true;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelCalls.add(id);
  }

  @override
  Future<void> show(
      int id,
      String? title,
      String? body,
      NotificationDetails? notificationDetails, {
        String? payload,
      }) async {
    showCalls.add({
      'id': id,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> zonedSchedule(
      int id,
      String? title,
      String? body,
      tz.TZDateTime scheduledDate,
      NotificationDetails notificationDetails, {
        required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
        required AndroidScheduleMode androidScheduleMode,
        String? payload,
        DateTimeComponents? matchDateTimeComponents,
      }) async {
    scheduleCalls.add({
      'id': id,
      'title': title,
      'body': body, // Aggiunto per verifica del testo
      'date': scheduledDate,
      'hour': scheduledDate.hour,
      'minute': scheduledDate.minute,
      'matchComponents': matchDateTimeComponents,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #resolvePlatformSpecificImplementation) {
      return null;
    }
    return Future.value(null);
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  group('NotificationService Tests', () {
    late FakeFlutterLocalNotificationsPlugin fakePlugin;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    Future<NotificationService> makeService({Map<String, Object>? prefs, bool autoInit = true, bool signedIn = true}) async {
      SharedPreferences.setMockInitialValues(prefs ?? {});

      fakePlugin = FakeFlutterLocalNotificationsPlugin();
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser(uid: 'test_uid', email: 'test@notif.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: signedIn);

      final service = NotificationService.test(
        plugin: fakePlugin,
        auth: mockAuth,
        firestore: fakeFirestore,
      );

      if (autoInit) {
        await service.initialize();
      }
      return service;
    }

    String formatDate(DateTime date) {
      return '${date.day}/${date.month}/${date.year}';
    }

    test('initialize viene eseguito una sola volta (Singleton pattern logic)', () async {
      final service = await makeService(autoInit: false);
      await service.initialize();
      expect(fakePlugin.initializeCalls, 1);

      await service.initialize();
      expect(fakePlugin.initializeCalls, 1, reason: "Initialize chiamato due volte");
    });

    test('cancelNotification chiama il metodo cancel del plugin con ID corretto', () async {
      final service = await makeService();
      await service.cancelNotification(123);
      expect(fakePlugin.cancelCalls, contains(123));
    });

    test('requestPermissions non crasha', () async {
      final service = await makeService();
      final result = await service.requestPermissions();
      expect(result, true);
    });

    // --- NUOVO TEST: Utente non loggato ---
    test('checkAndSchedule non fa nulla se nessun utente è loggato', () async {
      final service = await makeService(signedIn: false); // Simuliamo logout
      
      await service.checkAndScheduleExpiringProducts();

      // Non deve chiamare Firestore né il plugin
      expect(fakePlugin.cancelAllCalls, 0);
      expect(fakePlugin.scheduleCalls, isEmpty);
    });
    // --------------------------------------

    test('Logica Scaduti: Schedula notifica se ci sono prodotti scaduti', () async {
      final service = await makeService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = formatDate(yesterday);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Latte Scaduto',
        'displayName': 'Latte Scaduto',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'L', 'note': '', 'genericName': 'milk'
      });

      await service.checkAndScheduleExpiringProducts();

      expect(fakePlugin.cancelAllCalls, 1);
      final scheduledNotif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1, orElse: () => {});
      expect(scheduledNotif, isNotEmpty);
      expect(scheduledNotif['title'], contains('1 Product Expired'));
    });

    test('Logica In Scadenza: Schedula notifica se prodotti scadono entro reminder days', () async {
      final prefs = <String, Object>{
        'notifications_enabled_test_uid': true,
        'reminder_index_test_uid': 2,
      };
      final service = await makeService(prefs: prefs);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateStr = formatDate(tomorrow);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Yogurt',
        'displayName': 'Yogurt',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'yogurt'
      });

      await service.checkAndScheduleExpiringProducts();

      final scheduledNotif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1, orElse: () => {});
      expect(scheduledNotif, isNotEmpty);
      expect(scheduledNotif['title'], contains('1 Product Expiring Soon'));
    });

    test('Logica Futuro: NON schedula notifica per prodotti freschi', () async {
      final service = await makeService();
      final future = DateTime.now().add(const Duration(days: 30));
      final dateStr = formatDate(future);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Pasta Fresca',
        'displayName': 'Pasta',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'kg', 'note': '', 'genericName': 'pasta'
      });

      await service.checkAndScheduleExpiringProducts();
      expect(fakePlugin.scheduleCalls, isEmpty);
    });

    test('Se notifiche disabilitate, non fa nulla', () async {
      final prefs = <String, Object>{'notifications_enabled_test_uid': false};
      final service = await makeService(prefs: prefs);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = formatDate(yesterday);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Scaduto',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'L', 'note': '', 'genericName': 'milk',
        'displayName': 'Scaduto'
      });

      await service.checkAndScheduleExpiringProducts();
      expect(fakePlugin.scheduleCalls, isEmpty);
    });

    test('Notifica schedulata con orario personalizzato', () async {
      final prefs = <String, Object>{
        'notifications_enabled_test_uid': true,
        'notification_hour_test_uid': 14,
        'notification_minute_test_uid': 30,
      };
      final service = await makeService(prefs: prefs);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = formatDate(yesterday);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Latte',
        'displayName': 'Latte',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'L', 'note': '', 'genericName': 'milk'
      });

      await service.checkAndScheduleExpiringProducts();

      final scheduledNotif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1);
      expect(scheduledNotif['hour'], 14);
      expect(scheduledNotif['minute'], 30);
    });

    test('Notifica schedulata usa orario default se non impostato', () async {
      final service = await makeService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = formatDate(yesterday);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Latte',
        'displayName': 'Latte',
        'scadenza': dateStr,
        'quantity': '1', 'unit': 'L', 'note': '', 'genericName': 'milk'
      });

      await service.checkAndScheduleExpiringProducts();

      final scheduledNotif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1);
      expect(scheduledNotif['hour'], 9); // Default
      expect(scheduledNotif['minute'], 0);
    });

    test('Gestisce date malformate nel Firestore senza crashare', () async {
      final service = await makeService();
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Prodotto Data Sbagliata',
        'scadenza': 'data/non/valida',
        'displayName': 'Prodotto Data Sbagliata',
        'quantity': '1', 'unit': 'kg', 'note': '', 'genericName': 'test'
      });

      await expectLater(service.checkAndScheduleExpiringProducts(), completes);
      expect(fakePlugin.scheduleCalls, isEmpty);
    });

    test('Multipli prodotti scaduti vengono raggruppati in una notifica', () async {
      final service = await makeService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = formatDate(yesterday);

      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Latte', 'displayName': 'Latte', 'scadenza': dateStr, 'quantity': '1', 'unit': 'L', 'note': '', 'genericName': 'milk'
      });
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Pane', 'displayName': 'Pane', 'scadenza': dateStr, 'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'bread'
      });
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Formaggio', 'displayName': 'Formaggio', 'scadenza': dateStr, 'quantity': '200', 'unit': 'g', 'note': '', 'genericName': 'cheese'
      });

      await service.checkAndScheduleExpiringProducts();

      final expiredNotif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1);
      expect(expiredNotif['title'], contains('3 Products Expired'));
    });

    // --- NUOVO TEST: Combinazione Scaduti + In Scadenza ---
    test('Combinazione: Mostra FridgeWizard Alert se ci sono sia scaduti che in scadenza', () async {
      final service = await makeService();
      
      // 1 Scaduto
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Scaduto', 'displayName': 'Scaduto', 'scadenza': formatDate(yesterday),
        'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'bad'
      });

      // 1 In Scadenza (Domani)
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Fresco', 'displayName': 'Fresco', 'scadenza': formatDate(tomorrow),
        'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'good'
      });

      await service.checkAndScheduleExpiringProducts();

      final notif = fakePlugin.scheduleCalls.firstWhere((c) => c['id'] == 1);
      
      // Titolo generico di alert
      expect(notif['title'], contains('FridgeWizard Alert'));
      // Body contiene dettagli
      expect(notif['body'], contains('1 expired and 1 expiring'));
    });
    // ------------------------------------------------------

    // --- NUOVO TEST: Switch Default (Reminder Index sconosciuto) ---
    test('Default Reminder Index: Se index è sconosciuto, usa default (3 giorni)', () async {
      // Index 99 non esiste nello switch case -> default
      final prefs = <String, Object>{
        'notifications_enabled_test_uid': true,
        'reminder_index_test_uid': 99, 
      };
      final service = await makeService(prefs: prefs);

      // Prodotto scade tra 3 giorni (il default)
      final threeDays = DateTime.now().add(const Duration(days: 3));
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Limite', 'displayName': 'Limite', 'scadenza': formatDate(threeDays),
        'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'test'
      });

      await service.checkAndScheduleExpiringProducts();

      // Deve trovarlo perché 3 giorni rientra nel default
      expect(fakePlugin.scheduleCalls, isNotEmpty);
    });
    // ---------------------------------------------------------------

    test('Helper showTestNotification chiama il plugin', () async {
      final service = await makeService();
      await service.showTestNotification();
      expect(fakePlugin.showCalls.first['title'], contains('Test Notification'));
    });

    test('Diversi reminder days vengono rispettati', () async {
      final prefs = <String, Object>{
        'notifications_enabled_test_uid': true,
        'reminder_index_test_uid': 0, // 1 giorno
      };
      final service = await makeService(prefs: prefs);

      final twoDaysAway = DateTime.now().add(const Duration(days: 2));
      await fakeFirestore.collection('users').doc(mockUser.uid).collection('fridge').add({
        'nome': 'Prodotto Lontano', 'displayName': 'Prodotto Lontano', 'scadenza': formatDate(twoDaysAway),
        'quantity': '1', 'unit': 'pcs', 'note': '', 'genericName': 'test'
      });

      await service.checkAndScheduleExpiringProducts();
      expect(fakePlugin.scheduleCalls, isEmpty);
    });

  });
}