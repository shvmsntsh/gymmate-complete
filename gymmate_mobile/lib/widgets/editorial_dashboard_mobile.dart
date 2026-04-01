import 'package:flutter/material.dart';

import 'editorial_mobile.dart';

class DashboardBarPoint {
  final String label;
  final int value;

  const DashboardBarPoint({required this.label, required this.value});
}

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
    final hasAction = buttonLabel != null && onTap != null;

    return EditorialSurface(
      padding: const EdgeInsets.all(18),
      radius: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final showBottomAction = hasAction;
          final heroHeight = compact ? 320.0 : 240.0;
          final illustrationWidth = compact ? 108.0 : 140.0;
          final illustrationBottom = compact ? 6.0 : 0.0;
          final textRight = compact ? 118.0 : 150.0;
          final titleStyle = compact
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineMedium;
          final subtitleStyle = compact
              ? theme.textTheme.bodySmall
              : theme.textTheme.bodyMedium;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorialBlurImage(
                  height: heroHeight,
                  child: Container(
                    width: double.infinity,
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
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
                          const SizedBox(height: 18),
                          Text(title, style: titleStyle),
                          const SizedBox(height: 12),
                          Text(
                            subtitle,
                            style: subtitleStyle?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 14),
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
                          const Spacer(),
                          if (illustration != null)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: SizedBox(
                                width: illustrationWidth + 16,
                                height: 92,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomRight,
                                  child: illustration!,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasAction) ...[
                  const SizedBox(height: 14),
                  EditorialPrimaryButton(
                    label: buttonLabel!,
                    onPressed: onTap!,
                    affordance: EditorialPrimaryAffordance.arrow,
                  ),
                ],
              ],
            );
          }

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
                  ],
                ),
              ),
              if (hasAction && showBottomAction) ...[
                const SizedBox(height: 14),
                EditorialPrimaryButton(
                  label: buttonLabel!,
                  onPressed: onTap!,
                  affordance: EditorialPrimaryAffordance.arrow,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class DashboardBarChartCard extends StatefulWidget {
  final List<DashboardBarPoint> points;
  final String emptyTitle;
  final String emptySubtitle;
  final String? summaryLeft;
  final String? summaryRight;
  final String Function(String label, int value)? detailBuilder;

  const DashboardBarChartCard({
    super.key,
    required this.points,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.summaryLeft,
    this.summaryRight,
    this.detailBuilder,
  });

  @override
  State<DashboardBarChartCard> createState() => _DashboardBarChartCardState();
}

class _DashboardBarChartCardState extends State<DashboardBarChartCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.points;
    final values = points.map((point) => point.value).toList();
    final highestValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);
    final highestIndex = highestValue > 0
        ? values.indexOf(highestValue)
        : -1;
    final maxValue = highestValue > 0 ? highestValue : 1;
    final hasData = values.any((value) => value > 0);
    final selectedIndex = _selectedIndex ?? (highestIndex >= 0 ? highestIndex : 0);
    final selectedValue = points.isNotEmpty ? points[selectedIndex].value : 0;
    final selectedLabel = points.isNotEmpty ? points[selectedIndex].label : '';

    final panelColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final gridColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final inactiveBar = theme.brightness == Brightness.dark
        ? const Color(0xFF736656)
        : const Color(0xFFBEAF9A);
    final activeBar = theme.colorScheme.primary;

    if (!hasData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.emptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.emptySubtitle, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (widget.summaryLeft != null)
                _ChartSummaryPill(label: widget.summaryLeft!),
              if (widget.summaryRight != null)
                _ChartSummaryPill(label: widget.summaryRight!),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 188,
            child: Stack(
              children: [
                Column(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: gridColor, width: 1),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(points.length, (index) {
                    final point = points[index];
                    final value = point.value;
                    final fraction = value / maxValue;
                    final isActive = index == selectedIndex;
                    final isPeak = index == highestIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 32,
                                child: isActive
                                    ? Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: theme.colorScheme.outline.withValues(alpha: 0.14),
                                            ),
                                          ),
                                          child: Text(
                                            '$selectedValue',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: isActive ? 24 : 20,
                                    height: 24 + (fraction * 98),
                                    decoration: BoxDecoration(
                                      color: isPeak || isActive ? activeBar : inactiveBar,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: activeBar.withValues(alpha: 0.22),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                point.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isActive
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.56),
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (selectedLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.detailBuilder?.call(selectedLabel, selectedValue) ??
                  '$selectedLabel recorded $selectedValue.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartSummaryPill extends StatelessWidget {
  final String label;

  const _ChartSummaryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.84),
        ),
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
