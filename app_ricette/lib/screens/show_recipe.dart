import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import '../models/recipe.dart';
import '../models/planned_meal.dart';
import '../services/recipes_service.dart';
import '../services/meal_planner_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_events.dart';

class ShowRecipe extends StatefulWidget {
  final Recipe recipe;
  final Map<String, dynamic>? preLoadedDetails;
  final RecipesService? recipesService;
  final MealPlannerService? mealPlannerService;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const ShowRecipe({
    super.key, 
    required this.recipe, 
    this.preLoadedDetails,
    this.recipesService,
    this.mealPlannerService,
    this.firestore,
    this.auth,
  });

  @override
  State<ShowRecipe> createState() => _ShowRecipeState();
}

class _ShowRecipeState extends State<ShowRecipe> with SingleTickerProviderStateMixin {
  late final RecipesService _recipesService;
  late final MealPlannerService _plannerService;
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  Map<String, dynamic>? _recipeDetails;
  bool _isLoading = true;
  late AnimationController _shimmerController;

  bool _isSaved = false;
  bool _isCheckingSaved = true;

  @override
  void initState() {
    super.initState();

    _recipesService = widget.recipesService ?? RecipesService();
    _plannerService = widget.mealPlannerService ?? MealPlannerService();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    if (widget.preLoadedDetails != null) {
      _recipeDetails = widget.preLoadedDetails;
      _isLoading = false;
    } else {
      _loadRecipeDetails();
    }

    _checkIfRecipeIsSaved();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      final details = await _recipesService.getRecipeDetails(widget.recipe.id);
      if (mounted) {
        setState(() {
          _recipeDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkIfRecipeIsSaved() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isCheckingSaved = false);
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .doc(widget.recipe.id.toString())
          .get();

      setState(() {
        _isSaved = doc.exists;
        _isCheckingSaved = false;
      });
    } catch (e) {
      setState(() => _isCheckingSaved = false);
    }
  }

  Future<void> _toggleSaveRecipe() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .doc(widget.recipe.id.toString());

      if (_isSaved) {
        await docRef.delete();
        setState(() => _isSaved = false);
      } else {
        await docRef.set({
          'id': widget.recipe.id,
          'title': widget.recipe.title,
          'image': widget.recipe.image,
          'savedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _isSaved = true);
      }
      AppEvents.notifyDataChanged();
    } catch (e) {
      debugPrint('Error toggling recipe save: $e');
    }
  }

  void _showScheduleSheet() {
    DateTime tempDate = DateTime.now();
    Duration tempTime = Duration(hours: DateTime.now().hour, minutes: DateTime.now().minute);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: const Text(
                        "Schedule Meal", 
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    CupertinoButton(
                      key: const Key('scheduleSaveButton'),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final finalDateTime = DateTime(
                          tempDate.year,
                          tempDate.month,
                          tempDate.day,
                          tempTime.inHours,
                          tempTime.inMinutes % 60,
                        );

                        List<IngredientData> allIngredients = [];
                        
                        if (_recipeDetails != null && _recipeDetails!['extendedIngredients'] != null) {
                          for (var item in _recipeDetails!['extendedIngredients']) {
                            allIngredients.add(IngredientData(
                              name: item['name'] ?? 'Unknown',
                              amount: (item['amount'] ?? 0).toDouble(),
                              unit: item['unit'] ?? '',
                              original: item['original'],
                            ));
                          }
                        }

                        final updatedRecipe = Recipe(
                          id: widget.recipe.id,
                          title: widget.recipe.title,
                          image: widget.recipe.image,
                          missedIngredients: allIngredients, 
                          usedIngredients: [], 
                        );

                        final newMeal = PlannedMeal(
                          id: DateTime.now().toIso8601String(),
                          recipe: updatedRecipe, 
                          date: finalDateTime,
                          cachedDetails: _recipeDetails!,
                        );
                        
                        await _plannerService.addMeal(newMeal);
                        AppEvents.notifyDataChanged();

                        if (context.mounted) {
                          Navigator.pop(context);
                          showCupertinoDialog(
                            context: context, 
                            builder: (ctx) => CupertinoAlertDialog(
                              title: const Text("Scheduled!"),
                              content: const Text("Recipe added to your Plan."),
                              actions: [
                                CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))
                              ],
                            )
                          );
                        }
                      },
                    ),
                  ],
                ),
                const Divider(height: 1),

                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Select Date", style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
                SizedBox(
                  height: 100,
                  child: CupertinoDatePicker(
                    key: const Key('scheduleDatePicker'), // --- KEY ADDED HERE ---
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: DateTime.now(),
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
                  ),
                ),

                const Divider(),

                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Select Time", style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
                SizedBox(
                  height: 100,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime.now(),
                    onDateTimeChanged: (DateTime newTime) {
                      tempTime = Duration(hours: newTime.hour, minutes: newTime.minute);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: true,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.recipe.title,
          style: const TextStyle(fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: null,
        transitionBetweenRoutes: false,
        trailing: _isCheckingSaved
          ? const CupertinoActivityIndicator()
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleSaveRecipe,
              child: Icon(
                _isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: _isSaved ? CupertinoColors.systemRed : null,
              ),
            ),
      ),
      child: Column(
        children: [
          Expanded(
            child: _isLoading ? _buildLoadingSkeleton() : _buildRecipeContent(context),
          ),
          
          if (!_isLoading && _recipeDetails != null && widget.preLoadedDetails == null)
            Container(
              padding: const EdgeInsets.only(bottom:40, top:18, left:30, right:30),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: const Border(top: BorderSide(color: CupertinoColors.separator)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('programRecipeButton'),
                  borderRadius: BorderRadius.circular(30),
                  onPressed: _showScheduleSheet,
                  child: const Text("Program Recipe"),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
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

        return ListView(
          children: [
            Container(height: 300, decoration: BoxDecoration(gradient: shimmerGradient)),
          ],
        );
      },
    );
  }

  Widget _buildRecipeContent(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final Color textColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    if (_recipeDetails == null) return Container();

    final List<dynamic> extendedIngredients = _recipeDetails!['extendedIngredients'] ?? [];
    final List<dynamic> instructions = _recipeDetails!['analyzedInstructions'] ?? [];
    final int readyInMinutes = _recipeDetails!['readyInMinutes'] ?? 0;
    final int servings = _recipeDetails!['servings'] ?? 0;
    final String? summary = _recipeDetails!['summary'];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Image.network(
          widget.recipe.image,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 300,
              color: CupertinoColors.systemGrey5,
              child: const Center(
                child: Icon(CupertinoIcons.photo, size: 50, color: CupertinoColors.systemGrey),
              ),
            );
          },
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recipe.title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInfoCard(CupertinoIcons.time, '$readyInMinutes min', 'Cook Time', textColor)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInfoCard(CupertinoIcons.person_2, '$servings', 'Servings', textColor)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInfoCard(CupertinoIcons.chart_bar, '${extendedIngredients.length}', 'Ingredients', textColor)),
                ],
              ),
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Summary', textColor),
                const SizedBox(height: 8),
                Text(_stripHtmlTags(summary), style: TextStyle(fontSize: 15, color: textColor, height: 1.5)),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle('Ingredients', textColor),
              const SizedBox(height: 12),
              ...extendedIngredients.map((ingredient) {
                final String name = ingredient['original'] ?? ingredient['name'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(margin: const EdgeInsets.only(top: 4), width: 6, height: 6, decoration: BoxDecoration(color: CupertinoTheme.of(context).primaryColor, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: TextStyle(fontSize: 16, color: textColor, height: 1.4))),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              _buildSectionTitle('Instructions', textColor),
              const SizedBox(height: 12),
              if (instructions.isEmpty)
                const Text('No instructions available', style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel))
              else
                ...instructions.expand((instruction) {
                  final List<dynamic> steps = instruction['steps'] ?? [];
                  return steps.map((step) {
                    final int number = step['number'] ?? 0;
                    final String stepText = step['step'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 32, height: 32, decoration: BoxDecoration(color: CupertinoTheme.of(context).primaryColor, shape: BoxShape.circle), child: Center(child: Text('$number', style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                          const SizedBox(width: 12),
                          Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(stepText, style: TextStyle(fontSize: 16, color: textColor, height: 1.5)))),
                        ],
                      ),
                    );
                  }).toList();
                }),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String value, String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(color: CupertinoColors.systemBackground.resolveFrom(context), borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CupertinoTheme.of(context).primaryColor, size: 22,),
          const SizedBox(height: 4),
          Flexible(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          const SizedBox(height: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor));
  }

  String _stripHtmlTags(String htmlString) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }
}