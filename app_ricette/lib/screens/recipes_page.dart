import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../services/recipes_service.dart';
import 'show_recipe.dart';
import '../models/category_mapper.dart';

class RecipesPage extends StatefulWidget {
  final RecipesService? recipesService;
  final List<Ingredient> fridgeItems;
  final int warningDays;

  const RecipesPage({
    super.key,
    this.fridgeItems = const [],
    this.warningDays = 3,
    this.recipesService,
  });

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> with SingleTickerProviderStateMixin {
  late final RecipesService _recipesService;
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0; 
  List<Recipe> _recipes = [];
  final List<Ingredient> _selectedIngredients = [];
  bool _isLoading = false;
  bool _hasSearched = false; // Nuovo stato
  String _errorMessage = '';
  String _lastSearchQuery = ''; // Per mostrare cosa è stato cercato

  // Animation controller per lo shimmer effect
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _recipesService = widget.recipesService ?? RecipesService();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _searchByName() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recipes = [];
      _hasSearched = true;
      _lastSearchQuery = query;
    });

    try {
      final results = await _recipesService.searchRecipesByName(query);
      setState(() {
        _recipes = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search recipes. Try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByIngredients() async {
    if (_selectedIngredients.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one ingredient';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recipes = [];
      _hasSearched = true;
      _lastSearchQuery = '${_selectedIngredients.length} ingredients';
    });

    try {

      late final List<String> ingredientNames;

      if (_selectedIngredients.map((e) => e.genName).toList().contains('')) {
        ingredientNames = _selectedIngredients
            .map((e) => e.nome)
            .toList();
      } else {
        ingredientNames = _selectedIngredients
            .map((e) => e.genName)
            .toList();
      }

      // Debug print
      if(kDebugMode){
        print (_selectedIngredients.map((e) => e.genName).toList().contains(''));
        print('Ingredient names for search: $ingredientNames');
      }

      final results = await _recipesService.fetchRecipesByIngredients(ingredientNames);
      setState(() {
        _recipes = results;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch recipes. Try again.';
        _isLoading = false;
      });
    }
  }

  void _resetSearch() {
    setState(() {
      _hasSearched = false;
      _recipes = [];
      _errorMessage = '';
      _searchController.clear();
      _selectedIngredients.clear();
      _lastSearchQuery = '';
    });
  }

  void _toggleIngredientSelection(Ingredient ingredient) {
    setState(() {
      if (_selectedIngredients.contains(ingredient)) {
        _selectedIngredients.remove(ingredient);
      } else {
        _selectedIngredients.add(ingredient);
      }
    });
  }

  List<Ingredient> get _sortedFridgeItems {
    final items = List<Ingredient>.from(widget.fridgeItems);
    items.sort((a, b) {
      try {
        final partsA = a.scadenza.split('/');
        final partsB = b.scadenza.split('/');
        final dateA = DateTime(int.parse(partsA[2]), int.parse(partsA[1]), int.parse(partsA[0]));
        final dateB = DateTime(int.parse(partsB[2]), int.parse(partsB[1]), int.parse(partsB[0]));
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });
    return items;
  }

  //build UI
  @override
  Widget build(BuildContext context) {
    final bool isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final Color backgroundColor = isDark ? CupertinoColors.black : CupertinoColors.white;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Recipes'),
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Tab Selector e Search con scroll
            if (!_hasSearched)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: _selectedTab,
                          children: {
                            0: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Text(
                                'By Name',
                                style: TextStyle(color: textColor, fontSize: 14),
                              ),
                            ),
                            1: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Text(
                                'By Ingredients',
                                style: TextStyle(color: textColor, fontSize: 14),
                              ),
                            ),
                          },
                          backgroundColor: CupertinoColors.systemGrey2,
                          thumbColor: backgroundColor,
                          onValueChanged: (value) {
                            setState(() {
                              _selectedTab = value!;
                              _recipes = [];
                              _errorMessage = '';
                              _searchController.clear();
                              _selectedIngredients.clear();
                            });
                          },
                        ),
                      ),
                      if (_selectedTab == 0) _buildSearchByName() else _buildSearchByIngredients(context),
                    ],
                  ),
                ),
              ),

            // Barra con tasto back (mostra solo dopo una ricerca)
            if (_hasSearched) _buildSearchResultsBar(),

            // Results
            Expanded(
              child: _buildResults(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _resetSearch, minimumSize: Size(0, 0),
            child: const Row(
              children: [
                Icon(CupertinoIcons.back, size: 20),
                SizedBox(width: 4),
                Text('Back', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTab == 0 ? 'Searching for:' : 'Using:',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                Text(
                  _lastSearchQuery,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${_recipes.length} ${_recipes.length == 1 ? 'recipe' : 'recipes'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchByName() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              key: const Key('recipeSearchField'),
              controller: _searchController,
              placeholder: 'Search recipes...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(CupertinoIcons.search, color: CupertinoColors.systemGrey2),
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              onSubmitted: (_) => _searchByName(),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            key: const Key('recipeSearchButton'),
            padding: const EdgeInsets.all(12),
            color: CupertinoTheme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(30),
            onPressed: _searchByName,
            child: const Icon(CupertinoIcons.arrow_right, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchByIngredients(BuildContext context) {
    final bool isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    if (widget.fridgeItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.systemYellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CupertinoColors.systemYellow),
          ),
          child: const Row(
            children: [
              Icon(CupertinoIcons.info_circle, color: CupertinoColors.systemYellow),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your fridge is empty. Add ingredients to search recipes!',
                  style: TextStyle(color: CupertinoColors.label),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Select ingredients (${_selectedIngredients.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoButton(
                key: const Key('findRecipesButton'), // ADDED KEY
                padding: EdgeInsets.zero,
                onPressed: _selectedIngredients.isEmpty ? null : _searchByIngredients, minimumSize: Size(0, 0),
                child: Text(
                  'Find Recipes',
                  style: TextStyle(
                    fontSize: 15,
                    color: _selectedIngredients.isEmpty
                        ? CupertinoColors.systemGrey
                        : CupertinoTheme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _sortedFridgeItems.length,
            itemBuilder: (context, index) {
              final ingredient = _sortedFridgeItems[index];
              final isSelected = _selectedIngredients.contains(ingredient);
              final String searchString = '${ingredient.genName} ${ingredient.nome}';

              return GestureDetector(
                key: Key('ingredient_item_${ingredient.nome}'), // ADDED KEY
                onTap: () => _toggleIngredientSelection(ingredient),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                      ? CupertinoTheme.of(context).primaryColor
                        : CupertinoColors.secondarySystemGroupedBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                    color: isSelected
                      ? CupertinoTheme.of(context).primaryColor
                        : CupertinoColors.separator,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isSelected
                        ? const Icon(CupertinoIcons.checkmark_circle_fill, color: CupertinoColors.white, size: 28)
                          : SizedBox(
                            height: 30,
                            child: Center(
                              child: CategoryMapper.getIconForProduct(searchString),
                            ),
                          ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          ingredient.nome,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? CupertinoColors.white : CupertinoColors.label,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ingredient.scadenza,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected
                            ? CupertinoColors.white.withValues(alpha: 0.9)
                              : _getDateColor(ingredient.scadenza, widget.warningDays),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Color _getDateColor(String dateStr, int warningDays) {
    try {
      final parts = dateStr.split('/');
      final expiryDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);
      final difference = expiryDate.difference(today).inDays;

      if (difference < 0) return CupertinoColors.systemRed; // Scaduto
      if (difference <= warningDays) return CupertinoColors.systemOrange; // In scadenza
      return CupertinoColors.secondaryLabel;
    } catch (e) {
      return CupertinoColors.secondaryLabel;
    }
  }

  Widget _buildResults(BuildContext context) {
    final bool isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    //final Color backgroundColor = isDark ? CupertinoColors.black : CupertinoColors.white;

    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 50,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ),
      );
    }

    // Nessuna ricetta trovata DOPO una ricerca
    if (_hasSearched && _recipes.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.search,
                size: 80,
                color: CupertinoColors.systemGrey3,
              ),
              const SizedBox(height: 24),
              Text(
                'No recipes found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTab == 0
                    ? 'Search with a different keyword'
                    : 'Select different ingredients or add more to your fridge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _resetSearch,
                borderRadius: BorderRadius.circular(30),
                child: const Text('Try Another Search'),
              ),
            ],
          ),
        ),
      );
    }

    // Stato iniziale (nessuna ricerca effettuata)
    if (!_hasSearched && _recipes.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 80, bottom: 32),
          child: Column(
            children: [
              Icon(
                _selectedTab == 0 ? CupertinoIcons.search : CupertinoIcons.cube_box,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedTab == 0
                    ? 'Search for delicious recipes'
                    : 'Select ingredients to find recipes',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Lista ricette
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: 4,
          itemBuilder: (context, index) {
            return _buildRecipeCardSkeleton();
          },
        );
      },
    );
  }

  Widget _buildRecipeCardSkeleton() {
    final shimmerGradient = LinearGradient(
      colors: [
        CupertinoColors.systemGrey5.resolveFrom(context),
        CupertinoColors.systemGrey6.resolveFrom(context),
        CupertinoColors.systemGrey5.resolveFrom(context),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(-1.0 - _shimmerController.value * 2, 0.0),
      end: Alignment(1.0 - _shimmerController.value * 2, 0.0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(gradient: shimmerGradient),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  height: 20,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: shimmerGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  width: MediaQuery.of(context).size.width * 0.6,
                  decoration: BoxDecoration(
                    gradient: shimmerGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                if (_selectedTab == 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Chip skeleton 1
                      Container(
                        height: 28,
                        width: 80,
                        decoration: BoxDecoration(
                          gradient: shimmerGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chip skeleton 2
                      Container(
                        height: 28,
                        width: 90,
                        decoration: BoxDecoration(
                          gradient: shimmerGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => ShowRecipe(recipe: recipe),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                recipe.image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    color: CupertinoColors.systemGrey5,
                    child: const Center(
                      child: Icon(CupertinoIcons.photo, size: 50, color: CupertinoColors.systemGrey),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),

                  if (_selectedTab == 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildIngredientChip(
                          '${recipe.usedIngredientCount} match',
                          CupertinoColors.activeGreen,
                        ),
                        const SizedBox(width: 8),
                        _buildIngredientChip(
                          '${recipe.missedIngredientCount} missing',
                          CupertinoColors.systemOrange,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}