import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoleCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final int index;
  const RoleCard({
    Key? key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String imageAsset;
    switch (title) {
      case 'Owner':
        imageAsset = 'assets/images/owner_illustration.png';
        break;
      case 'Trainer':
        imageAsset = 'assets/images/trainer_illustration.png';
        break;
      case 'Member':
      default:
        imageAsset = 'assets/images/member_illustration.png';
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imageAsset,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (index * 100).ms).slideY(begin: 0.1, end: 0, duration: 400.ms, delay: (index * 100).ms, curve: Curves.easeOut);
  }
} 