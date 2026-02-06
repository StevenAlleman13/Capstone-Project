import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({
    super.key,
    this.healthFacts = const [],
    this.recipeCards = const [],
    this.onRefreshFacts,
    this.onRefreshRecipes,
    this.onRecipeTap,
    this.onAddRecipe,
  });

  final List<String> healthFacts;
  final List<RecipeCardUi> recipeCards;

  final VoidCallback? onRefreshFacts;
  final VoidCallback? onRefreshRecipes;
  final void Function(RecipeCardUi recipe)? onRecipeTap;
  final VoidCallback? onAddRecipe;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _supabase = Supabase.instance.client;

  List<String> _ingredients = const [];
  bool _loadingIngredients = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();                                    // initial load
  }

  Future<void> _loadIngredients() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _ingredients = const [];
        _loadingIngredients = false;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() => _loadingIngredients = true);
      }

      final rows = await _supabase
          .from('ingredients')
          .select('name')
          .eq('user_id', user.id)
          .order('created_at');

      final list = (rows as List)
          .map((r) => (r['name'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _ingredients = list;
        _loadingIngredients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingIngredients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ingredients: $e')),
      );
    }
  }

  Future<void> _addIngredientDialog() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
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

    await _loadIngredients();                                  // refresh immediately after add
  }

  Future<void> _removeIngredient(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('ingredients')
        .delete()
        .eq('user_id', user.id)
        .eq('name', name);

    await _loadIngredients();                                  // refresh immediately after delete
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _ingredients;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _SectionFrame(
            title: 'INGREDIENTS',
            rightAction: IconButton(
              icon: const Icon(Icons.add, size: 22),
              tooltip: 'Add ingredient',
              onPressed: _addIngredientDialog,
            ),
            child: _loadingIngredients
                ? const _EmptyHint(text: 'Loading ingredients...')
                : ingredients.isEmpty
                    ? const _EmptyHint(text: 'Tap + to add ingredients.')
                    : _IngredientChips(
                        items: ingredients,
                        onRemove: (name) => _removeIngredient(name),
                      ),
          ),
          const SizedBox(height: 14),

          _SectionFrame(
            title: 'HEALTH FACTS',
            rightAction: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh facts',
              onPressed: widget.onRefreshFacts,
            ),
            child: widget.healthFacts.isEmpty
                ? const _EmptyHint(text: 'Add ingredients to generate health facts.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final fact in widget.healthFacts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NeonBullet(text: fact),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          _SectionFrame(
            title: 'RECIPES',
            rightAction: IconButton(
              icon: const Icon(Icons.add, size: 22),
              tooltip: 'Add recipe',
              onPressed: widget.onAddRecipe,
            ),
            child: widget.recipeCards.isEmpty
                ? const _EmptyHint(text: 'Add ingredients to get recipes.')
                : SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.recipeCards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _RecipeCard(
                        recipe: widget.recipeCards[i],
                        onTap: widget.onRecipeTap,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------- INGREDIENTS UI -------------------------- */

class _IngredientChips extends StatelessWidget {
  final List<String> items;
  final void Function(String ingredient)? onRemove;

  const _IngredientChips({required this.items, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in items)
          _NeonChip(
            label: name,
            onDelete: onRemove == null ? null : () => onRemove!(name),
          ),
      ],
    );
  }
}

class _NeonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDelete;

  const _NeonChip({required this.label, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon.withOpacity(0.75), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.15), blurRadius: 10)],
        color: Colors.black,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          if (onDelete != null) ...[
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 18, color: neon),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neon.withOpacity(0.55), width: 1),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.10), blurRadius: 10)],
        color: Colors.black,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: neon.withOpacity(0.85), width: 1),
              boxShadow: [BoxShadow(color: neon.withOpacity(0.18), blurRadius: 10)],
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

class RecipeCardUi {
  final String title;
  final String imageUrl;
  final String subtitle;

  const RecipeCardUi({
    required this.title,
    this.imageUrl = '',
    this.subtitle = '',
  });
}

class _RecipeCard extends StatelessWidget {
  final RecipeCardUi recipe;
  final void Function(RecipeCardUi recipe)? onTap;

  const _RecipeCard({required this.recipe, this.onTap});

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
          width: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: neon.withOpacity(0.7), width: 1.2),
            boxShadow: [BoxShadow(color: neon.withOpacity(0.12), blurRadius: 14)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    recipe.imageUrl,
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
              if (recipe.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                  child: Text(
                    recipe.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: neon.withOpacity(0.85),
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

class _SectionFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? rightAction;

  const _SectionFrame({required this.title, required this.child, this.rightAction});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neon.withOpacity(0.8), width: 1.2),
        boxShadow: [BoxShadow(color: neon.withOpacity(0.12), blurRadius: 16)],
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
      opacity: 0.85,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
      ),
    );
  }
}
