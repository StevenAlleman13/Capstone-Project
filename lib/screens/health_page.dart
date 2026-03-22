import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key, this.onRecipeTap});

  final void Function(RecipeCardUi recipe)? onRecipeTap;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _supabase = Supabase.instance.client;

  static const List<String> _apiKeys = [
    'd9928e2e194e429bb0f8ff330651ad89',
    '160eeec24f1f43d5b642881f1be44243',
  ];

  List<IngredientRow> _ingredients = const [];
  bool _loadingIngredients = true;

  List<String> _healthFacts = const [];
  bool _loadingFacts = false;

  List<RecipeCardUi> _recipeCards = const [];
  bool _loadingRecipes = false;

  Set<int> _favoriteRecipeIds = <int>{};
  bool _loadingFavorites = false;
  List<String> _cachedTrivia = const [];
  String? _lastRecipeIngredientKey;
  bool _ingredientsExpanded = false;
  bool _healthFactsExpanded = false;
  bool _recipesExpanded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFavorites();
    await _loadIngredients();
  }

  Future<http.Response?> _spoonGet(Uri uri) async {
    for (final key in _apiKeys) {
      final keyedUri = uri.replace(
        queryParameters: {...uri.queryParameters, 'apiKey': key},
      );
      try {
        final resp = await http.get(keyedUri);
        if (resp.statusCode == 200) return resp;
        if (resp.statusCode == 402) continue;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /* -------------------------- INGREDIENTS -------------------------- */

  Future<void> _loadIngredients() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _ingredients = const [];
        _loadingIngredients = false;
        _recipeCards = const [];
        _healthFacts = const [];
      });
      return;
    }

    try {
      if (mounted) setState(() => _loadingIngredients = true);

      final rows = await _supabase
          .from('ingredients')
          .select(
            'name, spoonacular_id, image_url, calories, carbs_g, protein_g, fat_g, fiber_g, sugar_g, sodium_mg, last_nutrition_sync',
          )
          .eq('user_id', user.id)
          .order('created_at');

      final list = (rows as List)
          .map((r) => IngredientRow.fromMap(r as Map<String, dynamic>))
          .where((x) => x.name.trim().isNotEmpty)
          .toList();

      if (!mounted) return;

      final changed = !_sameIngredientNames(_ingredients, list);

      setState(() {
        _ingredients = list;
        _loadingIngredients = false;
      });

      if (changed) {
        _buildAndSetHealthFacts(list);
        final newKey = list.map((e) => e.name).join(',');
        if (newKey != _lastRecipeIngredientKey) {
          await _loadRecipes();
        }
      } else {
        if (_healthFacts.isEmpty) _buildAndSetHealthFacts(list);
        if (_recipeCards.isEmpty) await _loadRecipes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingIngredients = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading ingredients: $e')));
    }
  }

  bool _sameIngredientNames(List<IngredientRow> a, List<IngredientRow> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  Future<void> _addIngredientDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Add Ingredient'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g., bananas',
              hintStyle: TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Enter an ingredient';
              if (s.length > 40) return 'Keep it short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null) return;

    await _supabase.from('ingredients').insert({
      'user_id': user.id,
      'name': name,
    });

    await _loadIngredients();
    await _syncIngredientNutritionByName(name);
    await _loadIngredients();
  }  Future<void> _removeIngredient(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('ingredients')
        .delete()
        .eq('user_id', user.id)
        .eq('name', name);

    await _loadIngredients();
  }

  Future<void> _openBarcodeScanner() async {
    if (!mounted) return;
    
    final scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const _BarcodeScannerPage(),
      ),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty) return;

    // Use the barcode as the ingredient search query
    await _syncIngredientNutritionByName(scannedBarcode);
    await _loadIngredients();
  }

  Future<void> _syncIngredientNutritionByName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final found = await _spoonSearchIngredient(name);
      if (found == null) return;

      final info = await _spoonIngredientInformation(found.id);
      if (info == null) return;

      await _supabase
          .from('ingredients')
          .update({
            'spoonacular_id': info.id,
            'image_url': info.imageUrl,
            'calories': info.calories,
            'carbs_g': info.carbsG,
            'protein_g': info.proteinG,
            'fat_g': info.fatG,
            'fiber_g': info.fiberG,
            'sugar_g': info.sugarG,
            'sodium_mg': info.sodiumMg,
            'last_nutrition_sync': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('name', name);
    } catch (_) {}
  }

  /* -------------------------- HEALTH FACTS -------------------------- */

  void _buildAndSetHealthFacts(List<IngredientRow> items) {
    if (!mounted) return;
    final facts = _buildFactsFromIngredients(items);
    final merged = [
      ...facts,
      ..._cachedTrivia,
    ].where((s) => s.trim().isNotEmpty).toList();
    setState(() => _healthFacts = merged);
  }

  Future<void> _loadHealthFacts() async {
    if (_ingredients.isEmpty) {
      if (!mounted) return;
      setState(() => _healthFacts = const []);
      return;
    }

    try {
      if (mounted) setState(() => _loadingFacts = true);

      final ingredientFacts = _buildFactsFromIngredients(_ingredients);

      if (_cachedTrivia.isEmpty) {
        _cachedTrivia = await _spoonRandomTrivia(count: 2);
      }

      final merged = <String>[
        ...ingredientFacts,
        ..._cachedTrivia,
      ].where((s) => s.trim().isNotEmpty).toList();

      if (!mounted) return;
      setState(() => _healthFacts = merged);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading health facts: $e')));
    } finally {
      if (mounted) setState(() => _loadingFacts = false);
    }
  }

  List<String> _buildFactsFromIngredients(List<IngredientRow> items) {
    final facts = <String>[];

    for (final ing in items) {
      final parts = <String>[];

      if (ing.calories != null) parts.add('${_fmt0(ing.calories)} cal');
      if (ing.carbsG != null) parts.add('${_fmt1(ing.carbsG)}g carbs');
      if (ing.proteinG != null) parts.add('${_fmt1(ing.proteinG)}g protein');
      if (ing.fatG != null) parts.add('${_fmt1(ing.fatG)}g fat');
      if (ing.fiberG != null) parts.add('${_fmt1(ing.fiberG)}g fiber');
      if (ing.sugarG != null) parts.add('${_fmt1(ing.sugarG)}g sugar');
      if (ing.sodiumMg != null) parts.add('${_fmt0(ing.sodiumMg)}mg sodium');

      if (parts.isEmpty) {
        facts.add(
          'Add details for ${ing.name} by refreshing ingredients (nutrition not synced yet).',
        );
      } else {
        facts.add(
          '${_title(ing.name)} (typical serving): ${parts.join(' • ')}.',
        );
      }
    }

    if (facts.length > 12) return facts.take(12).toList();
    return facts;
  }

  String _fmt0(num? v) => v == null ? '' : v.toStringAsFixed(0);
  String _fmt1(num? v) => v == null ? '' : v.toStringAsFixed(1);

  String _title(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  /* -------------------------- RECIPES -------------------------- */

  Future<void> _loadRecipes() async {
    if (_ingredients.isEmpty) {
      if (!mounted) return;
      setState(() => _recipeCards = const []);
      return;
    }

    final newKey = _ingredients.map((e) => e.name).take(5).join(',');

    if (newKey == _lastRecipeIngredientKey && _recipeCards.isNotEmpty) return;

    try {
      if (mounted) setState(() => _loadingRecipes = true);

      final joined = Uri.encodeQueryComponent(
        _ingredients.map((e) => e.name).take(5).join(','),
      );

      final uri = Uri.parse(
        'https://api.spoonacular.com/recipes/findByIngredients'
        '?ingredients=$joined&number=5&ranking=1&ignorePantry=true',
      );

      final resp = await _spoonGet(uri);
      if (resp == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not load recipes — API limit reached on all keys.',
              ),
            ),
          );
        }
        return;
      }

      final list = jsonDecode(resp.body) as List<dynamic>;

      final cards = list.map((e) {
        final m = e as Map<String, dynamic>;
        final id = (m['id'] ?? 0) as int;
        final title = (m['title'] ?? 'Recipe').toString();
        final image = (m['image'] ?? '').toString();

        final used = (m['usedIngredients'] as List?) ?? const [];
        final missed = (m['missedIngredients'] as List?) ?? const [];

        final missingNames = missed
            .map((x) => (x as Map)['name']?.toString() ?? '')
            .where((s) => s.trim().isNotEmpty)
            .toList();

        return RecipeCardUi(
          recipeId: id,
          title: title,
          imageUrl: image,
          subtitle: 'Used: ${used.length} • Missing: ${missed.length}',
          missingIngredients: missingNames,
          isFavorite: _favoriteRecipeIds.contains(id),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _recipeCards = cards;
        _lastRecipeIngredientKey = newKey;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading recipes: $e')));
    } finally {
      if (mounted) setState(() => _loadingRecipes = false);
    }
  }

  /* -------------------------- FAVORITES -------------------------- */

  Future<void> _loadFavorites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (mounted) setState(() => _loadingFavorites = true);

      final rows = await _supabase
          .from('favorite_recipes')
          .select('recipe_id')
          .eq('user_id', user.id);

      final ids = <int>{};
      for (final r in (rows as List)) {
        final v = r['recipe_id'];
        if (v is int) ids.add(v);
        if (v is num) ids.add(v.toInt());
      }

      if (!mounted) return;
      setState(() => _favoriteRecipeIds = ids);
    } finally {
      if (mounted) setState(() => _loadingFavorites = false);
    }
  }

  Future<void> _toggleFavorite(RecipeCardUi recipe) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final id = recipe.recipeId;
    final isFav = _favoriteRecipeIds.contains(id);

    try {
      if (isFav) {
        await _supabase
            .from('favorite_recipes')
            .delete()
            .eq('user_id', user.id)
            .eq('recipe_id', id);
        _favoriteRecipeIds.remove(id);
      } else {
        await _supabase.from('favorite_recipes').insert({
          'user_id': user.id,
          'recipe_id': id,
          'title': recipe.title,
          'image_url': recipe.imageUrl,
        });
        _favoriteRecipeIds.add(id);
      }

      if (!mounted) return;
      setState(() {
        _recipeCards = _recipeCards
            .map(
              (r) => r.recipeId == id
                  ? r.copyWith(isFavorite: _favoriteRecipeIds.contains(id))
                  : r,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Favorite error: $e')));
    }
  }

  /* -------------------------- ADD RECIPE (SEARCH) -------------------------- */

  Future<void> _addRecipeDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Add Recipe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search recipes (e.g., chicken bowl)',
              hintStyle: TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Enter a search';
              if (s.length > 50) return 'Keep it short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (query == null) return;

    try {
      final results = await _spoonRecipeSearch(query);
      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No recipes found.')));
        return;
      }

      final picked = await showModalBottomSheet<RecipeCardUi>(
        context: context,
        backgroundColor: Colors.black,
        showDragHandle: true,
        builder: (context) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = results[i];
              return ListTile(
                title: Text(
                  r.title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Tap to favorite',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () => Navigator.pop(context, r),
              );
            },
          );
        },
      );

      if (picked == null) return;
      await _toggleFavorite(picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add recipe error: $e')));
    }
  }

  /* -------------------------- UI -------------------------- */
  @override
  Widget build(BuildContext context) {
    final ingredients = _ingredients;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _CollapsibleSection(
            title: 'Ingredients',
            icon: Icons.restaurant,
            expanded: _ingredientsExpanded,
            onToggle: () =>
                setState(() => _ingredientsExpanded = !_ingredientsExpanded),
            rightAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  tooltip: 'Scan barcode',
                  onPressed: _openBarcodeScanner,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: 'Add ingredient',
                  onPressed: _addIngredientDialog,
                ),
              ],
            ),
            child: _loadingIngredients
                ? const _EmptyHint(text: 'Loading ingredients...')
                : ingredients.isEmpty
                ? const _EmptyHint(text: 'Tap + to add ingredients.')
                : _IngredientCards(
                    items: ingredients,
                    onRemove: (name) => _removeIngredient(name),
                  ),
          ),
          const SizedBox(height: 14),

          _CollapsibleSection(
            title: 'Health Facts',
            icon: Icons.health_and_safety,
            expanded: _healthFactsExpanded,
            onToggle: () =>
                setState(() => _healthFactsExpanded = !_healthFactsExpanded),
            rightAction: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh facts',
              onPressed: _loadHealthFacts,
            ),
            child: ingredients.isEmpty
                ? const _EmptyHint(
                    text: 'Add ingredients to generate health facts.',
                  )
                : _loadingFacts
                ? const _EmptyHint(text: 'Loading facts...')
                : _healthFacts.isEmpty
                ? const _EmptyHint(text: 'No facts yet. Tap refresh.')
                : SizedBox(
                    height: 120,
                    child: PageView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _healthFacts.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _NeonBullet(text: _healthFacts[i]),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),

          _CollapsibleSection(
            title: 'Recipes',
            icon: Icons.menu_book,
            expanded: _recipesExpanded,
            onToggle: () =>
                setState(() => _recipesExpanded = !_recipesExpanded),
            rightAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, size: 22),
                  tooltip: 'Add recipe',
                  onPressed: _addRecipeDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh recipes',
                  onPressed: () {
                    _lastRecipeIngredientKey = null;
                    _loadRecipes();
                  },
                ),
              ],
            ),
            child: ingredients.isEmpty
                ? const _EmptyHint(text: 'Add ingredients to get recipes.')
                : _loadingRecipes || _loadingFavorites
                ? const _EmptyHint(text: 'Loading recipes...')
                : _recipeCards.isEmpty
                ? const _EmptyHint(text: 'No recipes found.')
                : SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _recipeCards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _RecipeCard(
                        recipe: _recipeCards[i],
                        onTap: widget.onRecipeTap,
                        onFavorite: _toggleFavorite,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /* -------------------------- SPOONACULAR HELPERS -------------------------- */

  Future<_SpoonIngredientSearchResult?> _spoonSearchIngredient(
    String query,
  ) async {
    final uri = Uri.parse(
      'https://api.spoonacular.com/food/ingredients/search'
      '?query=${Uri.encodeQueryComponent(query)}&number=1',
    );

    final resp = await _spoonGet(uri);
    if (resp == null) return null;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];
    if (results.isEmpty) return null;

    final r = results.first as Map<String, dynamic>;
    final id = (r['id'] ?? 0) as int;
    final name = (r['name'] ?? query).toString();
    final image = (r['image'] ?? '').toString();

    return _SpoonIngredientSearchResult(id: id, name: name, image: image);
  }

  Future<_SpoonIngredientInfo?> _spoonIngredientInformation(int id) async {
    final uri = Uri.parse(
      'https://api.spoonacular.com/food/ingredients/$id/information?amount=1&includeNutrition=true',
    );

    final resp = await _spoonGet(uri);
    if (resp == null) return null;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    final image = (data['image'] ?? '').toString();
    final nutrients = ((data['nutrition']?['nutrients'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    num? pick(String name) {
      for (final n in nutrients) {
        if ((n['name'] ?? '').toString().toLowerCase() == name.toLowerCase()) {
          final amt = n['amount'];
          if (amt is num) return amt;
          if (amt is String) return num.tryParse(amt);
        }
      }
      return null;
    }

    return _SpoonIngredientInfo(
      id: id,
      imageUrl: image.isEmpty
          ? ''
          : 'https://spoonacular.com/cdn/ingredients_250x250/$image',
      calories: pick('Calories'),
      carbsG: pick('Carbohydrates'),
      proteinG: pick('Protein'),
      fatG: pick('Fat'),
      fiberG: pick('Fiber'),
      sugarG: pick('Sugar'),
      sodiumMg: pick('Sodium'),
    );
  }

  Future<List<String>> _spoonRandomTrivia({int count = 2}) async {
    final facts = <String>[];

    for (int i = 0; i < count; i++) {
      final uri = Uri.parse('https://api.spoonacular.com/food/trivia/random');
      final resp = await _spoonGet(uri);
      if (resp == null) continue;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = (data['text'] ?? '').toString().trim();
      if (text.isNotEmpty) facts.add(text);
    }

    return facts;
  }

  Future<List<RecipeCardUi>> _spoonRecipeSearch(String query) async {
    final uri = Uri.parse(
      'https://api.spoonacular.com/recipes/complexSearch'
      '?query=${Uri.encodeQueryComponent(query)}&number=5',
    );

    final resp = await _spoonGet(uri);
    if (resp == null) return const [];

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];
    return results.map((e) {
      final m = e as Map<String, dynamic>;
      final id = (m['id'] ?? 0) as int;
      final title = (m['title'] ?? 'Recipe').toString();
      final image = (m['image'] ?? '').toString();
      return RecipeCardUi(
        recipeId: id,
        title: title,
        imageUrl: image,
        subtitle: 'Search result',
        missingIngredients: const [],
        isFavorite: _favoriteRecipeIds.contains(id),
      );
    }).toList();
  }
}

/* -------------------------- MODELS -------------------------- */

class IngredientRow {
  final String name;
  final int? spoonacularId;
  final String imageUrl;

  final num? calories;
  final num? carbsG;
  final num? proteinG;
  final num? fatG;
  final num? fiberG;
  final num? sugarG;
  final num? sodiumMg;

  const IngredientRow({
    required this.name,
    this.spoonacularId,
    this.imageUrl = '',
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  factory IngredientRow.fromMap(Map<String, dynamic> m) {
    num? n(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);

    return IngredientRow(
      name: (m['name'] ?? '').toString(),
      spoonacularId: m['spoonacular_id'] is int
          ? m['spoonacular_id'] as int
          : (m['spoonacular_id'] is num
                ? (m['spoonacular_id'] as num).toInt()
                : null),
      imageUrl: (m['image_url'] ?? '').toString(),
      calories: n(m['calories']),
      carbsG: n(m['carbs_g']),
      proteinG: n(m['protein_g']),
      fatG: n(m['fat_g']),
      fiberG: n(m['fiber_g']),
      sugarG: n(m['sugar_g']),
      sodiumMg: n(m['sodium_mg']),
    );
  }
}

class RecipeCardUi {
  final int recipeId;
  final String title;
  final String imageUrl;
  final String subtitle;
  final List<String> missingIngredients;
  final bool isFavorite;

  const RecipeCardUi({
    required this.recipeId,
    required this.title,
    this.imageUrl = '',
    this.subtitle = '',
    this.missingIngredients = const [],
    this.isFavorite = false,
  });

  RecipeCardUi copyWith({bool? isFavorite}) {
    return RecipeCardUi(
      recipeId: recipeId,
      title: title,
      imageUrl: imageUrl,
      subtitle: subtitle,
      missingIngredients: missingIngredients,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class _SpoonIngredientSearchResult {
  final int id;
  final String name;
  final String image;
  const _SpoonIngredientSearchResult({
    required this.id,
    required this.name,
    required this.image,
  });
}

class _SpoonIngredientInfo {
  final int id;
  final String imageUrl;

  final num? calories;
  final num? carbsG;
  final num? proteinG;
  final num? fatG;
  final num? fiberG;
  final num? sugarG;
  final num? sodiumMg;

  const _SpoonIngredientInfo({
    required this.id,
    required this.imageUrl,
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });
}

/* -------------------------- INGREDIENTS UI -------------------------- */

class _IngredientCards extends StatelessWidget {
  final List<IngredientRow> items;
  final void Function(String ingredient)? onRemove;

  const _IngredientCards({required this.items, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final ing in items) ...[
          _IngredientCard(
            ing: ing,
            onRemove: onRemove == null ? null : () => onRemove!(ing.name),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final IngredientRow ing;
  final VoidCallback? onRemove;

  const _IngredientCard({required this.ing, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    String macroLine() {
      final parts = <String>[];
      if (ing.calories != null)
        parts.add('${ing.calories!.toStringAsFixed(0)} cal');
      if (ing.carbsG != null) parts.add('${ing.carbsG!.toStringAsFixed(1)}c');
      if (ing.proteinG != null)
        parts.add('${ing.proteinG!.toStringAsFixed(1)}p');
      if (ing.fatG != null) parts.add('${ing.fatG!.toStringAsFixed(1)}f');
      return parts.isEmpty ? 'Nutrition not synced yet' : parts.join(' • ');
    }

    return Container(
      padding: const EdgeInsets.all(12),      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neon, width: 1.5),
        boxShadow: [
          BoxShadow(color: neon.withOpacity(0.4), blurRadius: 6),
        ],
        color: Colors.black,
      ),
      child: Row(
        children: [
          if (ing.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ing.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 44, height: 44, color: Colors.black),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neon.withOpacity(0.4)),
              ),
              child: const Icon(Icons.restaurant, size: 20),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ing.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  macroLine(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: neon.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: neon),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------- HEALTH FACTS UI -------------------------- */

class _NeonBullet extends StatelessWidget {
  final String text;
  const _NeonBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon, width: 1.5),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.4), blurRadius: 6)],
        color: Colors.black,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 10,
            height: 10,            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: neon, width: 1),
              boxShadow: [
                BoxShadow(color: neon.withOpacity(0.4), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/* -------------------------- RECIPES UI -------------------------- */

class _RecipeCard extends StatelessWidget {
  final RecipeCardUi recipe;
  final void Function(RecipeCardUi recipe)? onTap;
  final void Function(RecipeCardUi recipe)? onFavorite;

  const _RecipeCard({required this.recipe, this.onTap, this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap == null ? null : () => onTap!(recipe),
        child: Container(
          width: 240,          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: neon, width: 1.5),
            boxShadow: [
              BoxShadow(color: neon.withOpacity(0.4), blurRadius: 6),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (recipe.imageUrl.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        recipe.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black),
                      ),
                    )
                  else
                    Container(height: 110, color: Colors.black),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onFavorite == null
                            ? null
                            : () => onFavorite!(recipe),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            recipe.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color: neon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (recipe.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 8,
                  ),
                  child: Text(
                    recipe.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: neon.withOpacity(0.85),
                    ),
                  ),
                ),
              if (recipe.missingIngredients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  child: Text(
                    'Need: ${recipe.missingIngredients.take(4).join(', ')}'
                    '${recipe.missingIngredients.length > 4 ? '…' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.80),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? rightAction;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.expanded,
    required this.onToggle,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon, width: 2),
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: expanded ? Radius.zero : const Radius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: neon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: neon,
                      ),
                    ),
                  ),
                  if (expanded && rightAction != null) rightAction!,
                  Icon(
                    expanded ? Icons.remove : Icons.add,
                    color: neon,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.85,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }
}

/* -------------------------- BARCODE SCANNER -------------------------- */

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_scanned) return;
          final Barcode? barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
          final String? code = barcode?.rawValue;
          if (code != null && code.isNotEmpty) {
            _scanned = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
