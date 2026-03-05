import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import 'show_recipe.dart';

class SavedRecipesPage extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const SavedRecipesPage({
    super.key,
    this.firestore,
    this.auth,
  });

  @override
  State<SavedRecipesPage> createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  List<Map<String, dynamic>> _savedRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;
    _loadSavedRecipes();
  }

  Future<void> _loadSavedRecipes() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .orderBy('savedAt', descending: true)
          .get();

      setState(() {
        _savedRecipes = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading saved recipes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecipe(String recipeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .doc(recipeId)
          .delete();

      setState(() {
        _savedRecipes.removeWhere((r) => r['id'].toString() == recipeId);
      });
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
    }
  }

  void _showDeleteConfirmation(String recipeId, String title) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remove Recipe'),
        content: Text('Are you sure you want to remove "$title" from your saved recipes?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteRecipe(recipeId);
            },
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Saved Recipes'),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        border: null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _savedRecipes.isEmpty
                ? _buildEmptyState()
                : _buildRecipesList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.heart_slash,
            size: 64,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Recipes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recipes you save will appear here',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesList() {
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _loadSavedRecipes,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final recipe = _savedRecipes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRecipeCard(recipe),
                );
              },
              childCount: _savedRecipes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipeData) {
    final String title = recipeData['title'] ?? 'Unknown Recipe';
    final String image = recipeData['image'] ?? '';
    final int id = recipeData['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        final recipe = Recipe(
          id: id,
          title: title,
          image: image,
          missedIngredients: [],
          usedIngredients: [],
        );

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ShowRecipe(
              recipe: recipe,
              firestore: _firestore,
              auth: _auth,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: CupertinoColors.systemGrey5,
                          child: const Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.systemGrey,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: CupertinoColors.systemGrey5,
                      child: const Icon(
                        CupertinoIcons.photo,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
            ),

            // Recipe Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.heart_fill,
                          size: 14,
                          color: CupertinoColors.systemRed.resolveFrom(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Saved',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete Button
            CupertinoButton(
              padding: const EdgeInsets.all(12),
              onPressed: () => _showDeleteConfirmation(id.toString(), title),
              child: Icon(
                CupertinoIcons.trash,
                color: CupertinoColors.destructiveRed.resolveFrom(context),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
