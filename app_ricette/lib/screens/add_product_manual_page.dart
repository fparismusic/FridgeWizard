import 'package:flutter/cupertino.dart';
import '../models/ingredient.dart';
import '../services/gemini_service.dart';

class AddProductManualPage extends StatefulWidget {
  final String? initialName;

  const AddProductManualPage({super.key, this.initialName});

  @override
  State<AddProductManualPage> createState() => _AddProductManualPageState();
}

class _AddProductManualPageState extends State<AddProductManualPage> {
  final GeminiService _geminiService = GeminiService();
  
  late TextEditingController _nameController;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedUnit = 'g';
  bool _isTranslating = false; 

  final List<String> _units = ['pcs', 'g', 'kg', 'L', 'ml', 'oz', 'lb'];

  String? _nameError;
  String? _quantityError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Product Manually'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: _isTranslating ? null : () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildLabel('Product Name'),
                _buildErrorMsg(_nameError),
                const SizedBox(height: 8),
                CupertinoTextField(
                  key: const Key('manualNameField'),
                  controller: _nameController,
                  placeholder: 'Ex: Milk',
                  padding: const EdgeInsets.all(12),
                  decoration: _inputDecoration(_nameError != null),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
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
                          _buildLabel('Quantity'),
                          _buildErrorMsg(_quantityError),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            key: const Key('manualQtyField'),
                            controller: _quantityController,
                            placeholder: 'Ex: 500',
                            padding: const EdgeInsets.all(12),
                            decoration: _inputDecoration(_quantityError != null),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) {
                              if (_quantityError != null) setState(() => _quantityError = null);
                            },
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
                          _buildLabel('Unit'),
                          const SizedBox(height: 8),
                          GestureDetector(
                            key: const Key('manualUnitPicker'),
                            onTap: () => _showUnitPicker(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.tertiarySystemBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedUnit,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: CupertinoColors.label,
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 16,
                                    color: CupertinoColors.systemGrey,
                                  ),
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

                _buildLabel('Expiration Date'),
                _buildErrorMsg(_dateError),
                const SizedBox(height: 8),
                GestureDetector(
                  key: const Key('manualDatePicker'),
                  onTap: () => _showDatePickerPopup(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _inputDecoration(_dateError != null),
                    child: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: TextStyle(
                        color: _selectedDate == null
                            ? CupertinoColors.placeholderText
                            : CupertinoColors.label,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _buildLabel('Notes (Optional)'),
                const SizedBox(height: 8),
                CupertinoTextField(
                  key: const Key('manualNotesField'),
                  controller: _noteController,
                  placeholder: 'Add details here...',
                  padding: const EdgeInsets.all(12),
                  decoration: _inputDecoration(false),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    key: const Key('manualAddButton'),
                    borderRadius: BorderRadius.circular(25),
                    onPressed: _isTranslating ? null : _onAddProduct,
                    child: _isTranslating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(color: CupertinoColors.white),
                              SizedBox(width: 12),
                              Text('Translating...', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text('Add to Fridge', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            if (_isTranslating)
              Container(
                color: CupertinoColors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }

  Widget _buildErrorMsg(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        error,
        style: const TextStyle(
          fontSize: 13,
          color: CupertinoColors.systemRed,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  BoxDecoration _inputDecoration(bool hasError) {
    return BoxDecoration(
      color: CupertinoColors.tertiarySystemBackground,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: hasError ? CupertinoColors.systemRed : CupertinoColors.systemGrey4,
        width: hasError ? 1.5 : 0.5,
      ),
    );
  }

  void _showDatePickerPopup(BuildContext context) {
    if (_dateError != null) setState(() => _dateError = null);

    final initialDate = _selectedDate ?? DateTime.now();
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
                  key: const Key('manualDateDone'),
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: DateTime(now.year, now.month, now.day),
                maximumDate: DateTime.now().add(const Duration(days: 365 * 5)),
                onDateTimeChanged: (val) {
                  setState(() {
                    _selectedDate = val;
                  });
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
                  key: const Key('manualUnitDone'),
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
                  setState(() {
                    _selectedUnit = _units[index];
                  });
                },
                children: _units.map((unit) => Center(child: Text(unit))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddProduct() async {
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

    setState(() {
      _isTranslating = true;
    });

    String genericName = '';
    try {
      genericName = await _geminiService.extractGenericName(_nameController.text);
      if (genericName.isEmpty || genericName.length > 50) {
        genericName = _nameController.text;
      }
    } catch (e) {
      debugPrint('Error translating product name: $e');
      genericName = _nameController.text;
    }

    if (!mounted) return;

    setState(() {
      _isTranslating = false;
    });

    String dateString = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    final Ingredient newItem = Ingredient(
      nome: _nameController.text,
      scadenza: dateString,
      note: _noteController.text,
      quantity: _quantityController.text,
      unit: _selectedUnit,
      genericName: genericName,
    );

    Navigator.of(context).pop(newItem);
  }
}