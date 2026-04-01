import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final int index;
  final bool compact;
  final bool fullWidth;
  const RoleCard({
    Key? key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.index,
    this.compact = false,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String imageAsset;
    IconData roleIcon;
    switch (title) {
      case 'Owner':
        imageAsset = 'assets/images/owner_illustration.png';
        roleIcon = Icons.workspace_premium_rounded;
        break;
      case 'Trainer':
        imageAsset = 'assets/images/trainer_illustration.png';
        roleIcon = Icons.bolt_rounded;
        break;
      case 'Member':
      default:
        imageAsset = 'assets/images/member_illustration.png';
        roleIcon = Icons.fitness_center_rounded;
    }
    return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: compact || fullWidth ? double.infinity : 160,
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.98 : 1,
                    )
                  : theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.82 : 0.94,
                    ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.32)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 14),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 40 : 46,
                  height: compact ? 40 : 46,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient() : null,
                    color: selected
                        ? null
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    roleIcon,
                    color: selected
                        ? AppColors.textOnAccent
                        : theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Center(
                  child: Image.asset(
                    imageAsset,
                    width: compact ? 56 : 76,
                    height: compact ? 56 : 76,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: compact ? 12 : 18),
                Text(
                  title,
                  style:
                      (compact
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(color: theme.colorScheme.onSurface),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    _descriptionFor(title),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.64,
                      ),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 8),
                Text(
                  selected ? 'Selected' : 'Tap to choose',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 100).ms)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOut,
        );
  }

  String _descriptionFor(String role) {
    switch (role) {
      case 'Owner':
        return 'Lead your gym, welcome new members, and keep the day running with confidence.';
      case 'Trainer':
        return 'Coach each session with focus, accountability, and a steady training rhythm.';
      case 'Member':
      default:
        return 'Follow your plan, track your progress, and keep your momentum week after week.';
    }
  }
}
