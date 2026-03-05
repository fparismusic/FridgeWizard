import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_ricette/screens/barcode_page.dart';
import 'package:app_ricette/models/ingredient.dart';
import 'package:app_ricette/services/barcode_service.dart';
import 'package:app_ricette/services/gemini_service.dart';

// --- 1. MOCK SERVICES ---

class MockBarcodeService implements BarcodeService {
  bool shouldFail = false;
  Map<String, String>? mockResult;
  int callCount = 0; // Per verificare il debounce

  @override
  Future<Map<String, String>?> getProductInfo(String barcode) async {
    callCount++;
    if (shouldFail) return null;

    // Simulate Network Delay
    await Future.delayed(const Duration(milliseconds: 50));

    // Return the mock result if set, otherwise default logic
    if (mockResult != null) return mockResult;

    if (barcode == '123456') {
      return {
        'name': 'Nutella Biscuits',
        'notes': 'Ferrero',
        'quantity': '304',
        'unit': 'g',
      };
    }
    return null; // Not found
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGeminiService implements GeminiService {
  String mockGenericName = 'Cookie';
  bool shouldFail = false;

  @override
  Future<String> extractGenericName(String productName) async {
    if (shouldFail) throw Exception('Gemini Error');
    await Future.delayed(const Duration(milliseconds: 50));
    return mockGenericName;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=fake');
  });

  // Necessary to prevent MobileScanner from crashing the test runner
  const MethodChannel channel = MethodChannel('dev.steenbakker.mobile_scanner/method');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
          (MethodCall methodCall) async {
        return null; // Mock success for start/stop calls
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('BarcodePage Tests', () {

    // ---------------------------------------------------------------------------
    // MOBILE TESTS
    // ---------------------------------------------------------------------------
    group('Mobile View Tests', () {

      // --- 1. VALIDATION TEST ---
      testWidgets('Validation (Mobile): Shows error if trying to save empty form', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: MockBarcodeService(),
              geminiService: MockGeminiService(),
            ),
          ),
        );

        // Try to save immediately (Fields empty)
        await tester.tap(find.text('Add to Fridge'));
        await tester.pumpAndSettle();

        // Expect Alert Dialog
        expect(find.text('Missing Info'), findsOneWidget);
        expect(find.text('Please ensure Name and Expiration Date are set.'), findsOneWidget);

        // Close Dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });

      // --- 2. HAPPY PATH / MANUAL ENTRY ---
      testWidgets('Manual Entry (Mobile): User fills form and returns Ingredient', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        Ingredient? resultIngredient;

        // Use Builder pattern to catch the Navigator.pop result
        await tester.pumpWidget(
          CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => BarcodePage(
                        barcodeService: MockBarcodeService(),
                        geminiService: MockGeminiService(),
                      ),
                    ),
                  );
                  resultIngredient = result as Ingredient?;
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        );

        // Open the page
        await tester.tap(find.text('Open Scanner'));
        await tester.pumpAndSettle();

        // 1. Enter Name
        final nameField = find.widgetWithText(CupertinoTextField, 'Scan a barcode...');
        await tester.enterText(nameField, 'Manual Milk');

        // 2. Enter Quantity
        final qtyField = find.widgetWithText(CupertinoTextField, 'e.g. 500');
        await tester.enterText(qtyField, '1');

        // 3. Select Date
        await tester.tap(find.text('Select Date'));
        await tester.pumpAndSettle();
        
        // FIX: We must scroll the picker to trigger onDateTimeChanged!
        // We drag the picker down slightly to change the date
        await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 70));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done')); 
        await tester.pumpAndSettle();

        // 4. Submit
        await tester.tap(find.text('Add to Fridge'));
        await tester.pumpAndSettle();

        // CHECK RESULT
        expect(find.byType(BarcodePage), findsNothing); // Page closed
        expect(resultIngredient, isNotNull);
        expect(resultIngredient!.nome, 'Manual Milk');
        expect(resultIngredient!.quantity, '1');
      });

      // --- 3. UNIT PICKER TEST ---
      testWidgets('Unit Picker (Mobile): Can change unit from g to kg', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: MockBarcodeService(),
              geminiService: MockGeminiService(),
            ),
          ),
        );

        // Initial state 'g'
        expect(find.widgetWithText(Container, 'g'), findsOneWidget);

        // Open Picker
        await tester.tap(find.text('g'));
        await tester.pumpAndSettle();

        // Scroll to 'kg' (offset depends on list order, usually scrolling up means negative Y offset)
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -50));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Check if changed
        expect(find.widgetWithText(Container, 'kg'), findsOneWidget);
      });

      // --- 4. SCANNING LOGIC ---
      testWidgets('Scanning Logic (Mobile): Mock Service auto-fills form', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockBarcode = MockBarcodeService();
        final mockGemini = MockGeminiService();

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: mockBarcode,
              geminiService: mockGemini,
            ),
          ),
        );

        // Find Scanner and Simulate Detection
        final scannerFinder = find.byType(MobileScanner);
        final MobileScanner scannerWidget = tester.widget(scannerFinder);
        
        // ! Added here to unwrap the nullable callback
        scannerWidget.onDetect!(BarcodeCapture(
          barcodes: [Barcode(rawValue: '123456', format: BarcodeFormat.ean13)],
        ));

        await tester.pump(); // Start async
        expect(find.text('Fetching product info...'), findsOneWidget);

        await tester.pumpAndSettle(); // Finish async

        // Verify Auto-Fill
        expect(find.widgetWithText(CupertinoTextField, 'Nutella Biscuits'), findsOneWidget);
        expect(find.widgetWithText(CupertinoTextField, '304'), findsOneWidget);
      });

      // --- 5. SCAN FAIL LOGIC ---
      testWidgets('Scan Fail (Mobile): Shows "Product not found"', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockBarcode = MockBarcodeService();
        mockBarcode.shouldFail = true;

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(barcodeService: mockBarcode, geminiService: MockGeminiService()),
          ),
        );

        final scannerWidget = tester.widget<MobileScanner>(find.byType(MobileScanner));
        
        // ! Added here to unwrap the nullable callback
        scannerWidget.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: '999999')]));

        await tester.pumpAndSettle();

        expect(find.text('Product not found'), findsOneWidget);
      });

    });

    // ---------------------------------------------------------------------------
    // TABLET TESTS
    // ---------------------------------------------------------------------------
    group('Tablet View Tests', () {
      
      testWidgets('Validazione (Tablet): Dialog corretto', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: MockBarcodeService(),
              geminiService: MockGeminiService(),
            ),
          ),
        );

        await tester.tap(find.text('Add to Fridge'));
        await tester.pumpAndSettle();

        expect(find.text('Missing Info'), findsOneWidget);
      });

      testWidgets('Layout (Tablet): Form is readable and usable', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2048, 2732);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: MockBarcodeService(),
              geminiService: MockGeminiService(),
            ),
          ),
        );

        expect(find.byType(MobileScanner), findsOneWidget);
        expect(find.text('Product Name'), findsOneWidget);
      });

    });

    // ---------------------------------------------------------------------------
    // COVERAGE EXPANSION
    // ---------------------------------------------------------------------------
    group('Coverage Expansion', () {

      testWidgets('Scan Debounce: Ignora scan ripetuti ravvicinati', (WidgetTester tester) async {
        final mockBarcode = MockBarcodeService();
        final mockGemini = MockGeminiService();

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: mockBarcode,
              geminiService: mockGemini,
            ),
          ),
        );

        final scannerWidget = tester.widget<MobileScanner>(find.byType(MobileScanner));
        final capture = BarcodeCapture(barcodes: [Barcode(rawValue: '123456')]);

        // Simula DUE scan consecutivi rapidi
        scannerWidget.onDetect!(capture);
        scannerWidget.onDetect!(capture);

        await tester.pump();
        
        // Verifico che il servizio sia stato chiamato UNA sola volta
        expect(mockBarcode.callCount, 1);

        // FIX: Importante! Dobbiamo aspettare che il Future.delayed(50ms) del servizio termini
        // altrimenti il test finisce lasciando un timer pendente, causando errore.
        await tester.pumpAndSettle();
      });

      testWidgets('Invalid Name Logic: "Unknown Product" scatena errore', (WidgetTester tester) async {
        final mockBarcode = MockBarcodeService();
        // Configuro il mock per restituire un prodotto con nome "Unknown Product"
        mockBarcode.mockResult = {
          'name': 'Unknown Product',
          'quantity': '1',
          'unit': 'kg'
        };

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: mockBarcode,
              geminiService: MockGeminiService(),
            ),
          ),
        );

        final scannerWidget = tester.widget<MobileScanner>(find.byType(MobileScanner));
        scannerWidget.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: 'INVALID_NAME')]));

        await tester.pumpAndSettle();

        // Deve mostrare l'overlay di errore perché il nome non è valido
        expect(find.text('Product not found'), findsOneWidget);
        // E non deve aver compilato i campi
        expect(find.text('Unknown Product'), findsNothing);
      });

      testWidgets('Gemini Error: Gestisce eccezione durante traduzione', (WidgetTester tester) async {
        final mockBarcode = MockBarcodeService();
        final mockGemini = MockGeminiService();
        
        // Barcode OK, ma Gemini fallisce
        mockGemini.shouldFail = true;

        await tester.pumpWidget(
          CupertinoApp(
            home: BarcodePage(
              barcodeService: mockBarcode,
              geminiService: mockGemini,
            ),
          ),
        );

        final scannerWidget = tester.widget<MobileScanner>(find.byType(MobileScanner));
        scannerWidget.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: '123456')]));

        // Aspetto che arrivi alla fase di caricamento/errore
        await tester.pumpAndSettle();

        // Se Gemini lancia eccezione, il codice la cattura e setta _hasError = true
        expect(find.text('Product not found'), findsOneWidget);
      });
    });

  });
}