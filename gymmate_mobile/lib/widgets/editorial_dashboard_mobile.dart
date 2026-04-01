import 'package:flutter/material.dart';

import 'editorial_mobile.dart';

class DashboardHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String metaLeft;
  final String metaRight;
  final String? buttonLabel;
  final VoidCallback? onTap;
  final Widget? illustration;
  final Color? actionColor;

  const DashboardHeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.metaLeft,
    required this.metaRight,
    this.buttonLabel,
    this.onTap,
    this.illustration,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = actionColor ?? theme.colorScheme.primary;

    return EditorialSurface(
      padding: const EdgeInsets.all(18),
      radius: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final heroHeight = compact ? 228.0 : 240.0;
          final illustrationWidth = compact ? 108.0 : 140.0;
          final illustrationBottom = compact ? 6.0 : 0.0;
          final textRight = compact ? 122.0 : 150.0;
          final titleStyle = compact
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineMedium;
          final subtitleStyle = compact
              ? theme.textTheme.bodySmall
              : theme.textTheme.bodyMedium;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialBlurImage(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surfaceContainerHighest,
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          eyebrow.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tone,
                          ),
                        ),
                      ),
                    ),
                    if (illustration != null)
                      Positioned(
                        right: compact ? 8 : 10,
                        bottom: illustrationBottom,
                        child: IgnorePointer(
                          child: SizedBox(
                            width: illustrationWidth,
                            height: heroHeight - 48,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              child: illustration!,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 20,
                      right: textRight,
                      top: compact ? 78 : 84,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            title,
                            style: titleStyle,
                            maxLines: compact ? 3 : 5,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            style: subtitleStyle,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _HeroMetaItem(
                                icon: Icons.access_time_rounded,
                                label: metaLeft,
                                tone: tone,
                              ),
                              _HeroMetaItem(
                                icon: Icons.local_fire_department_outlined,
                                label: metaRight,
                                tone: tone,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (buttonLabel != null && onTap != null)
                      Positioned(
                        right: 16,
                        bottom: 18,
                        child: Material(
                          color: tone,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onTap,
                            child: SizedBox(
                              width: compact ? 50 : 54,
                              height: compact ? 50 : 54,
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const _HeroMetaItem({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class DashboardStatPanel extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color? accent;
  final double? minHeight;

  const DashboardStatPanel({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    required this.icon,
    this.accent,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = accent ?? theme.colorScheme.primary;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 124),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const Spacer(),
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class DashboardSectionCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const DashboardSectionCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSectionHeading(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class DashboardListTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingTop;
  final String? trailingBottom;
  final Widget? leading;
  final VoidCallback? onTap;

  const DashboardListTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingTop,
    this.trailingBottom,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailingTop,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (trailingBottom != null) ...[
                const SizedBox(height: 4),
                Text(trailingBottom!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: tile,
    );
  }
}
