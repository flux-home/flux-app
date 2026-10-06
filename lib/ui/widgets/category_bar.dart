import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';

/// Apple-Home-style row of category buttons shown under the app title. Each is
/// a black pill with a pastel outline and text in the category's accent colour;
/// tapping opens that category's screen.
///
/// The row scrolls rather than dividing the width evenly. Four categories
/// already squeezed the labels, and a fifth would squeeze them further — a
/// button that has to shrink to fit is a button that will eventually be
/// unreadable, so they keep their size and the row moves instead.
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Padding inside the scroll view, so the first and last buttons line up
      // with the cards below at rest and can still scroll clear of the edge.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < HomeCategory.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _CategoryButton(category: HomeCategory.values[i]),
          ],
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.category});
  final HomeCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Material(
      color: Colors.black,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: InkWell(
        onTap: () => context.push('/category/${category.name}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
