import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import '../services/meal_planner_service.dart';
import '../models/planned_meal.dart';
import '../models/category_mapper.dart'; 
import '../models/ingredient.dart'; 
import 'show_recipe.dart';
import 'missing_ingredient_page.dart';
import '../utils/app_events.dart';

class PlanPage extends StatefulWidget {
  final List<Ingredient> fridgeItems;
  final Function(Ingredient)? onAddIngredient;
  final MealPlannerService? plannerService;

  const PlanPage({
    super.key, 
    this.fridgeItems = const [],
    this.onAddIngredient,
    this.plannerService,
  });

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late final MealPlannerService _plannerService;
  List<PlannedMeal> _plannedMeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _plannerService = widget.plannerService ?? MealPlannerService();

    _plannerService.addListener(_updateFromService);
    _loadData();
  }

  @override
  void dispose() {
    _plannerService.removeListener(_updateFromService);
    super.dispose();
  }

  void _updateFromService() {
    if (mounted) {
      setState(() {
        _plannedMeals = _plannerService.getMeals();
        //_isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _plannerService.loadMeals();
    if (mounted) {
      setState(() {
        _plannedMeals = _plannerService.getMeals();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.day}/${date.month}';
  }

  String _formatTime(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, int> _generateShoppingList() {
    final Map<String, int> shoppingList = {};

    final fridgeNames = widget.fridgeItems
        .map((e) => e.nome.toLowerCase().trim())
        .toSet();

    for (var meal in _plannedMeals) {
      for (var ingredientData in meal.recipe.missedIngredients) {
        
        String ingredientName = ingredientData.name;
        
        if (fridgeNames.contains(ingredientName.toLowerCase().trim())) {
          continue; 
        }

        if (shoppingList.containsKey(ingredientName)) {
          shoppingList[ingredientName] = shoppingList[ingredientName]! + 1;
        } else {
          shoppingList[ingredientName] = 1;
        }
      }
    }
    return shoppingList;
  }

  @override
  Widget build(BuildContext context) {
    final shoppingList = _generateShoppingList();
    final Color backgroundColor = CupertinoTheme.of(context).scaffoldBackgroundColor;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Meal Plan'),
        backgroundColor: backgroundColor,
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : LayoutBuilder(
          builder: (context, constraints) {
            // SE TABLET (Larghezza > 700 pixel)
            if (constraints.maxWidth >= 700) {
              return _buildTabletLayout(shoppingList);
            }
            // SE MOBILE
            return _buildMobileLayout(shoppingList);
          },
        ),
      ),
    );
  }

  // --- LAYOUT MOBILE ---
  Widget _buildMobileLayout(Map<String, int> shoppingList) {
    final bool showIngredientsSection = _plannedMeals.isNotEmpty;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final Color textColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sezione Ricette
        Expanded(
          flex: 40,
          child: _plannedMeals.isEmpty ? _buildEmptyState() : _buildMealList(),
        ),

        // Sezione Ingredienti (solo se ci sono ricette)
        if (showIngredientsSection) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              "Missing Ingredients",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            flex: 60,
            child: shoppingList.isEmpty
                ? _buildEmptyShoppingList()
                : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 127),
              child: _buildShoppingListView(shoppingList),
            ),
          ),
        ],
      ],
    );
  }

  // --- LAYOUT TABLET ---
  Widget _buildTabletLayout(Map<String, int> shoppingList) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final Color textColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;
    final Color separatorColor = CupertinoColors.separator.resolveFrom(context);

    return Row(
      children: [
        // COLONNA SINISTRA: Planned Meals
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Scheduled Meals",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  child: _plannedMeals.isEmpty
                      ? _buildEmptyState()
                      : _buildMealList(),
                ),
              ),
            ],
          ),
        ),

        // DIVISORE VERTICALE
        Container(
          width: 1,
          color: separatorColor,
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 120),
        ),

        // COLONNA DESTRA: Shopping List
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Shopping List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ),
              Expanded(
                child: _plannedMeals.isEmpty
                    ? _buildEmptyShoppingList() // Se non ci sono pasti, niente lista
                    : (shoppingList.isEmpty
                    ? _buildEmptyShoppingList()
                    : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 130),
                  child: _buildShoppingListView(shoppingList),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(CupertinoIcons.calendar_today, size: 40, color: CupertinoColors.systemGrey),
          SizedBox(height: 12),
          Text('No meals planned yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMealList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plannedMeals.length,
      itemBuilder: (context, index) {
        final meal = _plannedMeals[index];
        final String dateStr = _formatDate(meal.date);
        final String timeStr = _formatTime(meal.date);

        return Dismissible(
          key: Key(meal.id), 
          direction: DismissDirection.endToStart, 
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(CupertinoIcons.trash, color: Colors.white),
          ),
          onDismissed: (direction) {
            _plannerService.removeMeal(meal.id);
            AppEvents.notifyDataChanged();
          },
          child: GestureDetector(
            key: Key('plannedMeal_$index'), // --- KEY ADDED HERE ---
            //funzionava anche senza, ma forse è meglio così
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => ShowRecipe(
                    recipe: meal.recipe,
                    preLoadedDetails: meal.cachedDetails,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      meal.recipe.image,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 60, height: 60,
                        color: CupertinoColors.systemGrey5,
                        child: const Icon(CupertinoIcons.photo, size: 20, color: CupertinoColors.systemGrey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.calendar, size: 14, color: CupertinoTheme.of(context).primaryColor),
                            const SizedBox(width: 4),
                            Text(dateStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.clock, size: 10, color: CupertinoColors.label),
                                  const SizedBox(width: 2),
                                  Text(timeStr, style: const TextStyle(fontSize: 10, color: CupertinoColors.label, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(meal.recipe.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.label), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyShoppingList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(CupertinoIcons.cart, size: 40, color: CupertinoColors.systemGrey3),
          SizedBox(height: 12),
          Text(
            'No missing ingredients needed',
            style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingListView(Map<String, int> shoppingList) {
    final ingredients = shoppingList.keys.toList();

    return Container(
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
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: ingredients.length,
        separatorBuilder: (context, index) => Container(
          height: 1,
          color: CupertinoColors.separator,
          margin: const EdgeInsets.only(left: 26, right: 26),
        ),
        itemBuilder: (context, index) {
          final name = ingredients[index];
          final count = shoppingList[name]!;
          // --- CHANGED: Passed index to helper ---
          return _buildShoppingItemRow(name, count, index);
        },
      ),
    );
  }

  // --- CHANGED: Added index parameter ---
  Widget _buildShoppingItemRow(String name, int count, int index) {
    String displayName = name.isNotEmpty 
        ? '${name[0].toUpperCase()}${name.substring(1)}' 
        : name;

    return GestureDetector(
      key: Key('missingIngredient_$index'), // --- KEY ADDED HERE ---
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => MissingIngredientPage(
              name: displayName,
              count: count,
              onProductBought: (Ingredient boughtItem) {
                if (widget.onAddIngredient != null) {
                  widget.onAddIngredient!(boughtItem);
                }
              },
              onRemoveFromList: () {
                _plannerService.removeMissingIngredient(name);
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
                      child: CategoryMapper.getIconForProduct(name),
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
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Missing Ingredient',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                      'Needed:',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'x $count',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.systemOrange,
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
}