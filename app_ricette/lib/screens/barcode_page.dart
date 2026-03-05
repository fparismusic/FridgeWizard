import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/barcode_service.dart';
import '../services/gemini_service.dart';
import '../models/ingredient.dart';

class BarcodePage extends StatefulWidget {
  final BarcodeService? barcodeService;
  final GeminiService? geminiService;

  const BarcodePage({
    super.key, 
    this.barcodeService, 
    this.geminiService
  });

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  // Late final allows us to initialize them in initState using the widget parameters
  late final BarcodeService _barcodeService;
  late final GeminiService _geminiService;

  late final MobileScannerController _scanController;

  bool _scanEnabled = true;
  bool _isLoading = false;
  bool _hasError = false;
  String _loadingMessage = 'Scanning barcode...';

  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const Duration _scanDebounceTime = Duration(seconds: 2);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedUnit = 'g';
  String _genericName = '';

  final List<String> _units = ['pcs', 'g', 'kg', 'L', 'ml', 'oz', 'lb'];

  @override
  void initState() {
    super.initState();
    // dependency injection logic
    _barcodeService = widget.barcodeService ?? BarcodeService();
    _geminiService = widget.geminiService ?? GeminiService();

    _scanController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  // ... (The rest of the file remains EXACTLY the same as your original)
  @override
  void dispose() {
    _scanController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeCapture(BarcodeCapture capture) async {
    if (!_scanEnabled || _isLoading) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedCode == raw &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanDebounceTime) {
      return;
    }
    _lastScannedCode = raw;
    _lastScanTime = now;

    setState(() {
      _scanEnabled = false;
      _isLoading = true;
      _hasError = false;
      _loadingMessage = 'Fetching product info...';
    });

    try {
      final productData = await _barcodeService.getProductInfo(raw);

      if (!mounted) return;

      final name = productData?['name'];
      final isValidName = name != null && name.trim().isNotEmpty && name != 'Unknown Product';

      if (!isValidName) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      setState(() {
        _loadingMessage = 'Translating product name...';
      });

      final translatedName = await _geminiService.extractGenericName(name);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = false;

        _nameController.text = name;
        _quantityController.text = (productData?['quantity'] ?? '').toString();
        _noteController.text = (productData?['notes'] ?? '').toString();
        _selectedUnit = (productData?['unit'] ?? 'g').toString();
        _genericName = translatedName;
      });
    } catch (e) {
      debugPrint('Barcode scan flow error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onAddProduct() {
    if (_nameController.text.isEmpty || _selectedDate == null) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Missing Info'),
          content: const Text('Please ensure Name and Expiration Date are set.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            )
          ],
        ),
      );
      return;
    }

    final dateString = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    final Ingredient newItem = Ingredient(
      nome: _nameController.text,
      scadenza: dateString,
      note: _noteController.text,
      quantity: _quantityController.text,
      unit: _selectedUnit,
      genericName: _genericName,
    );

    Navigator.of(context).pop(newItem);
  }

  void _resetScan() {
    setState(() {
      _lastScannedCode = null;
      _lastScanTime = null;

      _isLoading = false;
      _hasError = false;
      _scanEnabled = true;

      _nameController.clear();
      _quantityController.clear();
      _noteController.clear();
      _selectedDate = null;
      _selectedUnit = 'g';
      _genericName = '';
      _loadingMessage = 'Scanning barcode...';
    });
  }

  @override
  Widget build(BuildContext context) {
    final showResultOverlay = !_scanEnabled && !_isLoading;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Scan Product'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            RepaintBoundary(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scanController,
                        onDetect: _onBarcodeCapture,
                      ),

                      if (showResultOverlay)
                        Container(
                          color: CupertinoColors.white,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasError
                                      ? CupertinoIcons.xmark_circle_fill
                                      : CupertinoIcons.checkmark_circle_fill,
                                  color: _hasError ? CupertinoColors.systemRed : CupertinoColors.activeGreen,
                                  size: 80,
                                ),
                                const SizedBox(height: 10),
                                if (_hasError)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 40),
                                    child: Text(
                                      'Product not found',
                                      style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                CupertinoButton(
                                  onPressed: _resetScan,
                                  child: const Text('Scan Again'),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_isLoading)
                        Container(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          color: CupertinoColors.black.withValues(alpha: 0.7),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CupertinoActivityIndicator(radius: 20, color: CupertinoColors.white),
                              const SizedBox(height: 16),
                              Text(
                                _loadingMessage,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Product Name', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                  const SizedBox(height: 5),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Scan a barcode...',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                            const SizedBox(height: 5),
                            CupertinoTextField(
                              controller: _quantityController,
                              placeholder: 'e.g. 500',
                              padding: const EdgeInsets.all(12),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: BoxDecoration(
                                color: CupertinoColors.tertiarySystemBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () => _showUnitPicker(context),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.tertiarySystemBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_selectedUnit, style: const TextStyle(fontSize: 17, color: CupertinoColors.label)),
                                    const Icon(CupertinoIcons.chevron_down, size: 16, color: CupertinoColors.systemGrey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text('Expiration Date', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => _showDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedDate == null
                            ? CupertinoColors.tertiarySystemBackground
                            : CupertinoColors.activeBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedDate == null ? CupertinoColors.systemGrey4 : CupertinoColors.activeBlue,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: TextStyle(
                              fontSize: 17,
                              color: _selectedDate == null ? CupertinoColors.placeholderText : CupertinoColors.activeBlue,
                              fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          const Icon(CupertinoIcons.calendar, color: CupertinoColors.systemGrey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text('Notes', style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                  const SizedBox(height: 5),
                  CupertinoTextField(
                    controller: _noteController,
                    placeholder: 'Brand, store, etc...',
                    padding: const EdgeInsets.all(12),
                    maxLines: 2,
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(25),
                      onPressed: _onAddProduct,
                      child: const Text('Add to Fridge', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (DatePicker and UnitPicker helper methods remain the same)
  void _showDatePicker(BuildContext context) {
    final now = DateTime.now();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: DateTime.now(),
                minimumDate: DateTime(now.year, now.month, now.day),
                maximumDate: DateTime.now().add(const Duration(days: 365 * 5)),
                onDateTimeChanged: (val) {
                  setState(() => _selectedDate = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(
                  initialItem: _units.indexOf(_selectedUnit),
                ),
                onSelectedItemChanged: (index) {
                  setState(() => _selectedUnit = _units[index]);
                },
                children: _units.map((unit) => Center(child: Text(unit))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}