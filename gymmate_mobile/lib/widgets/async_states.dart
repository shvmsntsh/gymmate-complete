import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:gymmate_mobile/api/api_client.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';

/// Shimmering placeholder shown while a page's data loads, replacing the bare
/// CircularProgressIndicator. Variants approximate the shape of the content
/// that's coming so the transition is calm rather than a jarring pop-in.
class SkeletonLoader extends StatelessWidget {
  final List<Widget> _blocks;

  const SkeletonLoader._(this._blocks, {super.key});

  /// A vertical stack of card-like rows — for list pages (plans, clients).
  factory SkeletonLoader.list({int rows = 4, Key? key}) {
    return SkeletonLoader._(
      List.generate(
        rows,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: _SkeletonBlock(height: 88, radius: 22),
        ),
      ),
      key: key,
    );
  }

  /// A single tall hero card plus a couple of supporting lines — for detail
  /// pages (membership, receipt).
  factory SkeletonLoader.detail({Key? key}) {
    return SkeletonLoader._(
      const [
        _SkeletonBlock(height: 180, radius: 28),
        SizedBox(height: 16),
        _SkeletonBlock(height: 20, radius: 8, widthFactor: 0.5),
        SizedBox(height: 12),
        _SkeletonBlock(height: 64, radius: 18),
        SizedBox(height: 12),
        _SkeletonBlock(height: 64, radius: 18),
      ],
      key: key,
    );
  }

  /// A heading band plus a wide card — for dashboards.
  factory SkeletonLoader.card({Key? key}) {
    return SkeletonLoader._(
      const [
        _SkeletonBlock(height: 24, radius: 8, widthFactor: 0.4),
        SizedBox(height: 16),
        _SkeletonBlock(height: 140, radius: 26),
        SizedBox(height: 14),
        _SkeletonBlock(height: 90, radius: 22),
      ],
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHigh.withValues(
        alpha: isDark ? 0.5 : 0.85,
      ),
      highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.28 : 0.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks,
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;
  final double widthFactor;

  const _SkeletonBlock({
    required this.height,
    required this.radius,
    this.widthFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

/// Unified error panel with a Retry affordance. Consolidates the per-page
/// inline error builders. When [error] is a network [ApiException] it swaps in
/// connection-specific copy automatically.
class ErrorStateView extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final Object? error;

  const ErrorStateView({
    super.key,
    this.title = 'Something went wrong.',
    this.message,
    this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = error is ApiException && (error as ApiException).isNetwork;
    final resolvedTitle = isNetwork ? 'You appear to be offline.' : title;
    final resolvedMessage =
        message ??
        (error is ApiException
            ? (error as ApiException).message
            : 'Please try again in a moment.');

    return EditorialSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSectionHeading(
            eyebrow: isNetwork ? 'Connection' : 'Error',
            title: resolvedTitle,
            subtitle: resolvedMessage,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            EditorialPrimaryButton(
              label: 'Retry',
              onPressed: onRetry,
              trailing: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Unified empty-state panel for when a request succeeds but returns nothing.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorialSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
