import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'barcode_page.dart';
import 'recipes_page.dart';
import 'plan_page.dart';
import 'settings_page.dart';
import 'add_product_manual_page.dart';
import 'product_page.dart';
import '../models/ingredient.dart';
import '../models/category_mapper.dart';
import '../widgets/nav_bar.dart';

class HomePage extends StatefulWidget {
  final FirestoreService? firestoreService;
  final Widget? recipesPageOverride;
  final Widget? planPageOverride;
  final Widget? settingsPageOverride;

  final bool isTestMode;

  const HomePage({
    super.key,
    this.firestoreService,
    this.recipesPageOverride,
    this.planPageOverride,
    this.settingsPageOverride,
    this.isTestMode = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<Ingredient> _dispensa = [];
  late final FirestoreService _firestoreService;
  bool _isLoading = true;
  int _warningDays = 3; 

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadDispensa();
    if (!widget.isTestMode) {
      _loadPreferences();
      _checkExpiringProducts();
    }

    // Schedule notification check after login
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    try {
      await NotificationService().checkAndScheduleExpiringProducts();
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  Future<void> _checkExpiringProducts() async {
    try {
      await NotificationService().checkAndScheduleExpiringProducts();
    } catch (e) {
      debugPrint('Error checking expiring products: $e');
    }
  }

  void _sortDispensa() {
    _dispensa.sort((a, b) {
      DateTime? dateA = _parseDate(a.scadenza);
      DateTime? dateB = _parseDate(b.scadenza);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadDispensa() async {
    setState(() => _isLoading = true);

    try {
      final items = await _firestoreService.loadFridge();
      setState(() {
        _dispensa = items;
        _sortDispensa(); 
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading fridge: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addProduct(Ingredient newItem) async {
    await _firestoreService.addIngredient(newItem);
    setState(() {
      _dispensa.add(newItem);
      _sortDispensa(); 
    });

  }

  Future<void> _updateProduct(int index, Ingredient updatedItem) async {
    updatedItem.id = _dispensa[index].id;
    await _firestoreService.updateIngredient(updatedItem);
    setState(() {
      _dispensa[index] = updatedItem;
      _sortDispensa(); 
    });
  }

  Future<void> _deleteProduct(int index) async {
    final item = _dispensa[index];
    if (item.id != null) {
      // Determina se il prodotto è scaduto
      bool isExpired = false;
      if (item.scadenza.isNotEmpty) {
        try {
          List<String> parts = item.scadenza.split('/');
          if (parts.length == 3) {
            int day = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int year = int.parse(parts[2]);
            DateTime expiryDate = DateTime(year, month, day);
            DateTime now = DateTime.now();
            DateTime today = DateTime(now.year, now.month, now.day);
            isExpired = expiryDate.difference(today).inDays < 0;
          }
        } catch (e) {
          debugPrint("Errore parsing data scadenza: $e");
        }
      }

      await _firestoreService.deleteIngredientWithTracking(item, isExpired: isExpired);
    }
    setState(() {
      _dispensa.removeAt(index);
    });
  }

  Future<void> _loadPreferences() async {
    if (widget.isTestMode) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'reminder_index_${user.uid}';
    final savedIndex = prefs.getInt(key) ?? 2;

    if (mounted) {
      setState(() {
        _warningDays = _getDaysFromIndex(savedIndex);
      });
    }
  }

  int _getDaysFromIndex(int index) {
    switch (index) {
      case 0: return 1;  
      case 1: return 2;  
      case 2: return 3;  
      case 3: return 4;  
      case 4: return 7;  
      case 5: return 14; 
      default: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeTab(context),

                widget.recipesPageOverride ?? RecipesPage(fridgeItems: _dispensa, warningDays: _warningDays),

                widget.planPageOverride ?? PlanPage(fridgeItems: _dispensa, onAddIngredient: _addProduct),

                widget.settingsPageOverride ?? const SettingsPage(),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: CustomNavBar(
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                if (index == 0) { 
                  _loadPreferences();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('FridgeWizard'),
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        border: null,
        transitionBetweenRoutes: true,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,

                  child: _dispensa.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _dispensa.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      color: CupertinoColors.separator,
                      margin: const EdgeInsets.only(left: 26, right: 26),
                    ),
                    itemBuilder: (context, index) {
                      final item = _dispensa[index];
                      return _buildProductRow(item, index);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('addProductButton'),
                  borderRadius: BorderRadius.circular(25),
                  color: CupertinoTheme.of(context).primaryColor,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add_circled_solid),
                      SizedBox(width: 8),
                      Text(
                        'Add Product',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  onPressed: () {
                    _showAddProductModal(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProductRow(Ingredient item, int index) {
    final String notes = item.note;
    final bool hasNotes = notes.isNotEmpty;
    final String originalDateString = item.scadenza;
    final String searchString = '${item.genericName} ${item.displayName}';

    String displayName = item.displayName;
    String displayQty = item.quantity;
    String displayUnit = item.unit;

    Color expirationColor = CupertinoColors.systemGrey;
    Color nameColor = CupertinoColors.label;
    String dateDisplayText = originalDateString;

    if (originalDateString.isNotEmpty) {
      try {
        List<String> parts = originalDateString.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);

          DateTime expiryDate = DateTime(year, month, day);
          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);

          int daysLeft = expiryDate.difference(today).inDays;

          if (daysLeft < 0) {
            // SCADUTO
            expirationColor = CupertinoColors.systemRed;
            nameColor = CupertinoColors.systemRed;
            dateDisplayText = "Expired";
          } else if (daysLeft <= _warningDays) {
            // IN SCADENZA (Basato sui settings dell'utente)
            expirationColor = CupertinoColors.systemOrange;
          }
        }
      } catch (e) {
        debugPrint("Errore: $e");
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ProductPage(
              product: item,
              onSave: (Ingredient updatedItem) async {
                await _updateProduct(index, updatedItem);
              },
              onDelete: () async {
                final navigator = Navigator.of(context);
                await _deleteProduct(index);
                navigator.pop(); // Chiudi la pagina del prodotto
              },
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 16),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 35,
                    height: 35,
                    child: Center(
                      child: CategoryMapper.getIconForProduct(searchString),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: nameColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$displayQty $displayUnit', 
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasNotes) ...[
                          const SizedBox(height: 2),
                          Text(
                            notes,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Expires on:',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateDisplayText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: expirationColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey3,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.shopping_cart,
            size: 64,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Empty pantry',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Craft Ingredient'),
        message: const Text(
          'Every creation begins with a choice—select yours.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;

                final result = await Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const BarcodePage()),
                );

                if (result != null && result is Ingredient) {
                  await _addProduct(result);
                }
              });
            },
            child: const Text('Barcode'),
          ),
          CupertinoActionSheetAction(
            key: const Key('addManuallyAction'),
            onPressed: () {
              Navigator.pop(context);

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                final result = await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const AddProductManualPage(),
                  ),
                );

                if (result != null && result is Ingredient) {
                  await _addProduct(result);
                }
              });
            },
            child: const Text('Manually'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Annulla'),
        ),
      ),
    );
  }
}