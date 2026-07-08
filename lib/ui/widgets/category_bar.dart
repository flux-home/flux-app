import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matter_home/models/home_category.dart';

/// Apple-Home-style row of category buttons shown under the app title and above
/// the device tiles. Each button is a black pill with a pastel outline + text
/// in the category's accent colour; tapping opens that category's screen.
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < HomeCategory.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _CategoryButton(category: HomeCategory.values[i])),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  category.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
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
