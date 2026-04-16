import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'editorial_mobile.dart';

class OnboardingStepLayout extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget footer;
  final Widget? headerTrailing;

  const OnboardingStepLayout({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footer,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 420;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: compact
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (headerTrailing != null) ...[
              const SizedBox(width: 12),
              headerTrailing!,
            ],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: body,
          ),
        ),
        const SizedBox(height: 14),
        footer,
      ],
    );
  }
}

class OnboardingOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const OnboardingOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.surface.withValues(alpha: 0.98)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.34),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingChipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const OnboardingChipOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.28)
                : theme.colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(
                    alpha: onTap == null ? 0.5 : 1,
                  ),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class OnboardingValueTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const OnboardingValueTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialMetricTile(label: label, value: value, icon: icon);
  }
}
