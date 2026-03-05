import 'package:flutter/cupertino.dart';
import '../models/ingredient.dart';
import 'add_product_manual_page.dart';

class MissingIngredientPage extends StatelessWidget {
  final String name;
  final int count; 
  
  final Function(Ingredient) onProductBought;
  
  final VoidCallback onRemoveFromList;

  const MissingIngredientPage({
    super.key,
    required this.name,
    required this.count,
    required this.onProductBought,
    required this.onRemoveFromList, 
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty 
        ? '${name[0].toUpperCase()}${name.substring(1)}' 
        : name;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Ingredient Details'),
        backgroundColor: CupertinoColors.systemGroupedBackground,
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                             BoxShadow(
                              color: CupertinoColors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.cart_fill, size: 60, color: CupertinoColors.systemOrange),
                      ),
                      const SizedBox(height: 32),
                      
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Required for $count planned ${count == 1 ? 'meal' : 'meals'}",
                        style: const TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "This item is missing from your pantry.\nTap 'Mark as Bought' to add it to your fridge.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CupertinoColors.secondaryLabel, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(top: BorderSide(color: CupertinoColors.separator.withOpacity(0.5))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    key: const Key('removeIngredientButton'), // --- KEY ADDED HERE ---
                    onPressed: () {
                      _showRemoveConfirmation(context);
                    },
                    child: const Text(
                      "Remove from list",
                      style: TextStyle(
                        color: CupertinoColors.systemRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      key: const Key('markAsBoughtButton'), // --- KEY ADDED HERE ---
                      borderRadius: BorderRadius.circular(25),
                      onPressed: () => _navigateToBuy(context),
                      child: const Text("Mark as Bought", style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showRemoveConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Remove Item?"),
        content: const Text("This will remove the item from your shopping list without adding it to the fridge."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            key: const Key('confirmRemoveButton'), // --- KEY ADDED HERE ---
            isDestructiveAction: true,
            child: const Text("Remove"),
            onPressed: () {
              Navigator.pop(ctx); 
              onRemoveFromList(); 
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToBuy(BuildContext context) async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddProductManualPage(
          initialName: name,
        ),
      ),
    );

    if (result != null && result is Ingredient) {
      onProductBought(result);
      if (context.mounted) {
        Navigator.of(context).pop(); 
      }
    }
  }
}