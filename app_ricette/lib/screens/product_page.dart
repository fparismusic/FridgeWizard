import 'package:app_ricette/services/gemini_service.dart';
import 'package:flutter/cupertino.dart';
import '../models/ingredient.dart';

class ProductPage extends StatefulWidget {
  final Ingredient product;
  final Function(Ingredient) onSave;
  final VoidCallback onDelete;
  final GeminiService? geminiService;

  const ProductPage({
    super.key,
    required this.product,
    required this.onSave,
    required this.onDelete,
    this.geminiService,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _notesController;
  DateTime? _selectedDate;
  String _selectedUnit = 'pcs';

  final List<String> _units = ['pcs', 'g', 'kg', 'L', 'ml', 'oz', 'lb'];

  late String _displayName;
  late String _displayQty;
  late String _displayDate;
  late String _displayNotes;

  String _originalName = ''; // Nome originale per confronto

  GeminiService get _geminiService => widget.geminiService ?? GeminiService();

  @override
  void initState() {
    super.initState();
    _parseData();
    _nameController = TextEditingController(text: _displayName);
    _quantityController = TextEditingController(text: _displayQty);
    _notesController = TextEditingController(text: _displayNotes);
    _selectedUnit = widget.product.unit;

    // Salva il nome originale
    _originalName = widget.product.nome;
  }

  void _parseData() {
    _displayName = widget.product.nome;
    _displayQty = widget.product.quantity;
    _displayDate = widget.product.scadenza;
    _displayNotes = widget.product.note;

    try {
      if (_displayDate.isNotEmpty) {
        List<String> parts = _displayDate.split('/');
        _selectedDate = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Edit Product' : _displayName),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          key: const Key('productEditSaveButton'),
          padding: EdgeInsets.zero,
          onPressed: _toggleEditMode,
          child: Icon(
            _isEditing ? CupertinoIcons.floppy_disk : CupertinoIcons.wand_stars,
            size: 26,
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildLabel('Product Name'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _buildTextField(_nameController, 'Ex: Milk', key: const Key('editNameField'))
                      : _buildReadOnlyField(_displayName),

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
                            const SizedBox(height: 8),
                            _isEditing
                                ? _buildTextField(_quantityController, 'Ex: 500', isNumber: true, key: const Key('editQtyField'))
                                : _buildReadOnlyField(_displayQty),
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
                            _isEditing
                                ? GestureDetector(
                                    onTap: () => _showUnitPicker(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBackground,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: CupertinoTheme.of(context).primaryColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _selectedUnit,
                                            style: const TextStyle(fontSize: 17, color: CupertinoColors.label),
                                          ),
                                          const Icon(CupertinoIcons.chevron_down, size: 16, color: CupertinoColors.systemGrey),
                                        ],
                                      ),
                                    ),
                                  )
                                : _buildReadOnlyField(_selectedUnit),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildLabel('Expiration Date'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _buildDatePickerField()
                      : _buildReadOnlyField(_displayDate),

                  const SizedBox(height: 20),

                  _buildLabel('Notes'),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _buildTextField(_notesController, 'Add notes...', isMultiline: true, key: const Key('editNotesField'))
                      : _buildReadOnlyField(
                          _displayNotes.isEmpty ? 'No notes' : _displayNotes,
                          isMultiline: true),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  key: const Key('deleteProductButton'),
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  child: const Text(
                    'Remove Product',
                    style: TextStyle(
                      color: CupertinoColors.systemRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _showDeleteConfirmation(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _handleSave();
    } else {
      setState(() {
        _isEditing = true;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final qty = _quantityController.text.trim();

    if (name.isEmpty || qty.isEmpty || _selectedDate == null) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Missing Info'),
          content: const Text('Name, Quantity and Date are required.'),
          actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],
        ),
      );
      return;
    }

    // Mostra loading solo se dobbiamo tradurre
    final bool needsTranslation = name != _originalName;

    if (needsTranslation) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 10),
              Text('Translating...'),
            ],
          ),
        ),
      );
    }

    String dateString = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    String genericName = widget.product.genericName;

    // Traduci solo se il nome è cambiato
    if (needsTranslation) {
      try {
        //GeminiService geminiService = GeminiService();
        genericName = await _geminiService.extractGenericName(name);
      } catch (e) {
        debugPrint('Error translating product name: $e');
        // In caso di errore, mantieni il genericName esistente o usa il nuovo nome
        genericName = name;
      }

      if (!mounted) return;
      Navigator.pop(context); // Chiudi loading dialog
    }

    try {
      final updated = Ingredient(
        id: widget.product.id,
        nome: name,
        scadenza: dateString,
        note: _notesController.text.trim(),
        quantity: qty,
        unit: _selectedUnit,
        genericName: genericName,
      );

      widget.onSave(updated);

      setState(() {
        _displayName = name;
        _displayQty = qty;
        _displayDate = dateString;
        _displayNotes = _notesController.text.trim();
        _isEditing = false;
        _originalName = name; // Aggiorna il nome originale
      });

    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to save. Try again.'),
          actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],
        ),
      );
    }
  }


  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Remove Product'),
        message: const Text('Are you sure you want to delete this item?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx); // Chiude solo l'ActionSheet
              widget.onDelete(); // Questo già fa pop della ProductPage
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.secondaryLabel));
  }

  Widget _buildReadOnlyField(String text, {bool isMultiline = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      constraints: isMultiline ? const BoxConstraints(minHeight: 100) : null,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CupertinoColors.systemGrey4, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          color: (text == 'No notes' || text == '-')
              ? CupertinoColors.placeholderText
              : CupertinoColors.label,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String placeholder,
      {bool isNumber = false, bool isMultiline = false, Key? key}) {
    return CupertinoTextField(
      key: key,
      controller: controller,
      placeholder: placeholder,
      padding: const EdgeInsets.all(12),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isMultiline ? TextInputType.multiline : TextInputType.text),
      maxLines: isMultiline ? 5 : 1,
      minLines: isMultiline ? 3 : 1,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CupertinoTheme.of(context).primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      key: const Key('editDateField'),
      onTap: () => _showDatePickerPopup(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CupertinoTheme.of(context).primaryColor, width: 1.5),
        ),
        child: Text(
          _selectedDate == null
              ? 'Select Date'
              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          style: const TextStyle(fontSize: 17, color: CupertinoColors.label),
        ),
      ),
    );
  }

  void _showDatePickerPopup(BuildContext context) {
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
                  key: const Key('editDateDone'),
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate ?? DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 365)),
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
}