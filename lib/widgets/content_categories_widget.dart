import 'package:flutter/material.dart';

import '../models/models.dart';

class ContentCategoriesWidget extends StatelessWidget {
  final List<ContentCategory> categories;
  final Function(ContentCategory) onCategorySelected;

  const ContentCategoriesWidget({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryItem(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, ContentCategory category) {
    return GestureDetector(
      onTap: () => onCategorySelected(category),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: category.isSelected
              ? const Color(0xFF6C5CE7)
              : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(25),
          border: category.isSelected
              ? Border.all(color: const Color(0xFF6C5CE7), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category.icon.isNotEmpty) ...[
              _getIconForCategory(category.icon, category.isSelected),
              const SizedBox(width: 6),
            ],
            Text(
              category.name,
              style: TextStyle(
                color: category.isSelected
                    ? Colors.white
                    : Colors.grey.shade300,
                fontSize: 14,
                fontWeight: category.isSelected
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getIconForCategory(String iconName, bool isSelected) {
    IconData icon;
    switch (iconName) {
      case 'fire':
        icon = Icons.local_fire_department;
        break;
      case 'location':
        icon = Icons.location_on;
        break;
      case 'games':
        icon = Icons.sports_esports;
        break;
      case 'shop':
        icon = Icons.shopping_bag;
        break;
      case 'music':
        icon = Icons.music_note;
        break;
      case 'art':
        icon = Icons.palette;
        break;
      case 'sport':
        icon = Icons.sports_soccer;
        break;
      case 'food':
        icon = Icons.restaurant;
        break;
      case 'tech':
        icon = Icons.computer;
        break;
      default:
        icon = Icons.category;
    }

    return Icon(
      icon,
      size: 16,
      color: isSelected ? Colors.white : Colors.grey.shade400,
    );
  }
}
