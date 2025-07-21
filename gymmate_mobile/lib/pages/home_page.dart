import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gold = colorScheme.primary;
    final accentYellow = colorScheme.secondary;
    final cardBg = colorScheme.surface;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated Welcome Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: gold,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: accentYellow,
                      child: Icon(Icons.fitness_center, size: 36, color: cardBg),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: theme.textTheme.titleMedium?.copyWith(color: cardBg),
                          ),
                          Text(
                            'User', // Replace with your user name variable
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: cardBg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.verified_user, color: accentYellow, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'USER', // Replace with your user role variable
                                style: theme.textTheme.bodyMedium?.copyWith(color: cardBg),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 500.ms),
          ),
          // Animated Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _StatCard(label: 'Gym', value: '-', icon: Icons.home_work, color: gold, cardBg: cardBg, index: 0),
                const SizedBox(width: 12),
                _StatCard(label: 'Role', value: '-', icon: Icons.verified_user, color: accentYellow, cardBg: cardBg, index: 1),
                const SizedBox(width: 12),
                _StatCard(label: 'Logins', value: '0', icon: Icons.login, color: gold, cardBg: cardBg, index: 2),
              ],
            ),
          ),
          // Add more dashboard content here if needed
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final int index;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.cardBg, required this.index});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: (index * 120).ms).slideY(begin: 0.1, end: 0, duration: 400.ms, delay: (index * 120).ms, curve: Curves.easeOut),
    );
  }
}