import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  final _supabase = Supabase.instance.client;

  // Replace with your Spoonacular API key
  static const String _spoonacularApiKey = 'd9928e2e194e429bb0f8ff330651ad89';

  // Optional: replace this with your own “Health Facts” API endpoint
  // For now, this function returns generated facts based on ingredients (local fallback)
  // You can wire it to a real API later.
  Future<List<String>> _fetchHealthFacts(List<String> ingredients) async {
    // ----- OPTION A: Call your own API (recommended) -----
    // Example:
    // final resp = await http.post(
    //   Uri.parse('https://your-api.com/health-facts'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({'ingredients': ingredients}),
    // ).timeout(const Duration(seconds: 20));
    // if (resp.statusCode != 200) throw Exception(resp.body);
    // final data = jsonDecode(resp.body) as Map<String, dynamic>;
    // return (data['facts'] as List).map((e) => e.toString()).toList();

    // ----- OPTION B: Local fallback facts (so UI works now) -----
    if (ingredients.isEmpty) return const [];
    // Very lightweight “facts” just to prove the refresh mechanism.
    return ingredients.take(6).map((i) {
      return "Health note: $i can contribute useful nutrients depending on portion size and preparation.";
    }).toList();
  }

  Future<List<_RecipeCardModel>> _fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) return const [];

    final joined = ingredients.take(10).join(',');
    final uri = Uri.parse(
      'https://api.spoonacular.com/recipes/findByIngredients'
      '?ingredients=$joined&number=12&ranking=1&ignorePantry=true&apiKey=$_spoonacularApiKey',
    );

    final resp = await http.get(uri).timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Spoonacular error: ${resp.statusCode} ${resp.body}');
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return _RecipeCardModel(
        id: (m['id'] ?? 0) as int,
        title: (m['title'] ?? 'Recipe') as String,
        image: (m['image'] ?? '') as String,
        usedIngredientCount: (m['usedIngredientCount'] ?? 0) as int,
        missedIngredientCount: (m['missedIngredientCount'] ?? 0) as int,
      );
    }).toList();
  }

  Stream<List<String>> _ingredientsStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // If not logged in, just yield empty.
      return Stream.value(const []);
    }

    // Realtime-ish stream (polling via stream primary key changes)
    // Works well for simple refresh. If you want true realtime,
    // we can add Supabase channel subscriptions.
    return _supabase
        .from('ingredients')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at')
        .map((rows) => rows.map((r) => (r['name'] ?? '').toString()).where((s) => s.trim().isNotEmpty).toList());
  }

  Future<void> _addIngredientDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
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
              hintText: 'e.g., strawberry',
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

    if (result == null) return;

    await _supabase.from('ingredients').insert({
      'user_id': user.id,
      'name': result,
    });
  }

  Future<void> _removeIngredient(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Remove by name for simplicity. If you want strict removals,
    // store and delete by ID.
    await _supabase
        .from('ingredients')
        .delete()
        .eq('user_id', user.id)
        .eq('name', name);
  }

  @override
  Widget build(BuildContext context) {
    // Overall vertical scroll (like your mock)
    return StreamBuilder<List<String>>(
      stream: _ingredientsStream(),
      builder: (context, snap) {
        final ingredients = snap.data ?? const <String>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionFrame(
              title: 'INGREDIENTS',
              rightAction: IconButton(
                icon: const Icon(Icons.add, size: 22),
                tooltip: 'Add ingredient',
                onPressed: _addIngredientDialog,
              ),
              child: ingredients.isEmpty
                  ? const _EmptyHint(text: 'Tap + to add ingredients.')
                  : _IngredientChips(
                      items: ingredients,
                      onRemove: (name) => _removeIngredient(name),
                    ),
            ),
            const SizedBox(height: 14),

            _HealthFactsSection(
              ingredients: ingredients,
              fetchFacts: _fetchHealthFacts,
            ),
            const SizedBox(height: 14),

            _RecipesSection(
              ingredients: ingredients,
              fetchRecipes: _fetchRecipes,
            ),
          ],
        );
      },
    );
  }
}

/* -------------------------- INGREDIENTS UI -------------------------- */

class _IngredientChips extends StatelessWidget {
  final List<String> items;
  final void Function(String name) onRemove;

  const _IngredientChips({
    required this.items,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in items)
          _NeonChip(
            label: name,
            onDelete: () => onRemove(name),
          ),
      ],
    );
  }
}

class _NeonChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _NeonChip({
    required this.label,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: neon.withOpacity(0.75), width: 1.2),
        boxShadow: [
          BoxShadow(color: neon.withOpacity(0.15), blurRadius: 10),
        ],
        color: Colors.black,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 10),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 18, color: neon),
          ),
        ],
      ),
    );
  }
}

/* -------------------------- HEALTH FACTS -------------------------- */

class _HealthFactsSection extends StatefulWidget {
  final List<String> ingredients;
  final Future<List<String>> Function(List<String>) fetchFacts;

  const _HealthFactsSection({
    required this.ingredients,
    required this.fetchFacts,
  });

  @override
  State<_HealthFactsSection> createState() => _HealthFactsSectionState();
}

class _HealthFactsSectionState extends State<_HealthFactsSection> {
  Timer? _debounce;
  Future<List<String>>? _future;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  @override
  void didUpdateWidget(covariant _HealthFactsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh when ingredient list changes
    if (!_sameList(oldWidget.ingredients, widget.ingredients)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _kickoff);
    }
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _kickoff() {
    setState(() {
      _future = widget.fetchFacts(widget.ingredients);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      title: 'HEALTH FACTS',
      rightAction: IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Refresh facts',
        onPressed: _kickoff,
      ),
      child: widget.ingredients.isEmpty
          ? const _EmptyHint(text: 'Add ingredients to generate health facts.')
          : FutureBuilder<List<String>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingHint(text: 'Generating facts...');
                }
                if (snap.hasError) {
                  return _ErrorHint(text: 'Could not load facts: ${snap.error}');
                }
                final facts = snap.data ?? const [];
                if (facts.isEmpty) {
                  return const _EmptyHint(text: 'No facts returned.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in facts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NeonBullet(text: f),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _NeonBullet extends StatelessWidget {
  final String text;

  const _NeonBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: neon.withOpacity(0.8), width: 1),
            boxShadow: [BoxShadow(color: neon.withOpacity(0.18), blurRadius: 10)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/* -------------------------- RECIPES -------------------------- */

class _RecipesSection extends StatefulWidget {
  final List<String> ingredients;
  final Future<List<_RecipeCardModel>> Function(List<String>) fetchRecipes;

  const _RecipesSection({
    required this.ingredients,
    required this.fetchRecipes,
  });

  @override
  State<_RecipesSection> createState() => _RecipesSectionState();
}

class _RecipesSectionState extends State<_RecipesSection> {
  Timer? _debounce;
  Future<List<_RecipeCardModel>>? _future;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  @override
  void didUpdateWidget(covariant _RecipesSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameList(oldWidget.ingredients, widget.ingredients)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _kickoff);
    }
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _kickoff() {
    setState(() {
      _future = widget.fetchRecipes(widget.ingredients);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      title: 'RECIPES',
      rightAction: IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Refresh recipes',
        onPressed: _kickoff,
      ),
      child: widget.ingredients.isEmpty
          ? const _EmptyHint(text: 'Add ingredients to get recipes.')
          : FutureBuilder<List<_RecipeCardModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingHint(text: 'Finding recipes...');
                }
                if (snap.hasError) {
                  return _ErrorHint(text: 'Could not load recipes: ${snap.error}');
                }
                final recipes = snap.data ?? const [];
                if (recipes.isEmpty) {
                  return const _EmptyHint(text: 'No recipes returned.');
                }

                // Horizontal scrolling list like your mock
                return SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _RecipeCard(recipe: recipes[i]),
                  ),
                );
              },
            ),
    );
  }
}

class _RecipeCardModel {
  final int id;
  final String title;
  final String image;
  final int usedIngredientCount;
  final int missedIngredientCount;

  _RecipeCardModel({
    required this.id,
    required this.title,
    required this.image,
    required this.usedIngredientCount,
    required this.missedIngredientCount,
  });
}

class _RecipeCard extends StatelessWidget {
  final _RecipeCardModel recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border.all(color: neon.withOpacity(0.7), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.12), blurRadius: 14)],
        color: Colors.black,
      ),
      child: InkWell(
        onTap: () {
          // Later: open details page, or open Spoonacular recipe info
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  recipe.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              )
            else
              Container(height: 110, color: Colors.black),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              child: Text(
                "Used: ${recipe.usedIngredientCount} • Missing: ${recipe.missedIngredientCount}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: neon.withOpacity(0.85),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------- SHARED SECTION STYLING -------------------------- */

class _SectionFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? rightAction;

  const _SectionFrame({
    required this.title,
    required this.child,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: neon.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(color: neon.withOpacity(0.12), blurRadius: 16),
        ],
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: neon,
                    ),
              ),
              const Spacer(),
              if (rightAction != null) rightAction!,
            ],
          ),
          const SizedBox(height: 10),
          child,
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
      opacity: 0.8,
      child: Text(text),
    );
  }
}

class _LoadingHint extends StatelessWidget {
  final String text;
  const _LoadingHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ErrorHint extends StatelessWidget {
  final String text;
  const _ErrorHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.redAccent));
  }
}
