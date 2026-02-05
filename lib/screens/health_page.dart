import 'package:flutter/material.dart';

class HealthTab extends StatelessWidget {
  const HealthTab({
    super.key,
    this.ingredients = const [],
    this.healthFacts = const [],
    this.onAddIngredient,
    this.onRemoveIngredient,
    this.onRefreshFacts,
    this.onRefreshRecipes,
    this.recipeCards = const [],
    this.onRecipeTap,
  });

  // Data
  final List<String> ingredients;
  final List<String> healthFacts;
  final List<RecipeCardUi> recipeCards;

  // Actions
  final VoidCallback? onAddIngredient;
  final void Function(String ingredient)? onRemoveIngredient;
  final VoidCallback? onRefreshFacts;
  final VoidCallback? onRefreshRecipes;
  final void Function(RecipeCardUi recipe)? onRecipeTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionFrame(
          title: 'INGREDIENTS',
          rightAction: IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: 'Add ingredient',
            onPressed: onAddIngredient,
          ),
          child: ingredients.isEmpty
              ? const _EmptyHint(text: 'Tap + to add ingredients.')
              : _IngredientChips(
                  items: ingredients,
                  onRemove: onRemoveIngredient,
                ),
        ),
        const SizedBox(height: 14),

        _SectionFrame(
          title: 'HEALTH FACTS',
          rightAction: IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh facts',
            onPressed: onRefreshFacts,
          ),
          child: healthFacts.isEmpty
              ? const _EmptyHint(text: 'Add ingredients to generate health facts.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final fact in healthFacts)
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
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh recipes',
            onPressed: onRefreshRecipes,
          ),
          child: recipeCards.isEmpty
              ? const _EmptyHint(text: 'Add ingredients to get recipes.')
              : SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipeCards.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _RecipeCard(
                      recipe: recipeCards[i],
                      onTap: onRecipeTap,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/* -------------------------- INGREDIENTS UI -------------------------- */

class _IngredientChips extends StatelessWidget {
  final List<String> items;
  final void Function(String ingredient)? onRemove;

  const _IngredientChips({
    required this.items,
    this.onRemove,
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
            onDelete: onRemove == null ? null : () => onRemove!(name),
          ),
      ],
    );
  }
}

class _NeonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDelete;

  const _NeonChip({
    required this.label,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
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
              onTap: onDelete,
              child: Icon(Icons.close, size: 18, color: neon),
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

  const _RecipeCard({
    required this.recipe,
    this.onTap,
  });

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
        onTap: onTap == null ? null : () => onTap!(recipe),
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
    );
  }
}

/* -------------------------- SHARED SECTION FRAME -------------------------- */

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
    return Opacity(opacity: 0.8, child: Text(text));
  }
}
