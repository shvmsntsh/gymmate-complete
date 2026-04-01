import 'package:flutter/material.dart';
import 'package:gymmate_mobile/pages/plan_page.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({Key? key}) : super(key: key);

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: EditorialBackdrop(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialSurface(
                padding: const EdgeInsets.all(18),
                radius: 24,
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/trainer_illustration.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Coach Hub', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Thoughtful guidance is on the way. Your plan, progress, and gym tools are already ready to use.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              EditorialSurface(
                padding: const EdgeInsets.all(18),
                radius: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialKicker('Coach Access'),
                    const SizedBox(height: 18),
                    EditorialBlurImage(
                      height: 240,
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
                                  theme.colorScheme.surfaceContainerHigh,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 0,
                            child: Image.asset(
                              'assets/images/trainer_illustration.png',
                              height: 170,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            left: 20,
                            top: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'COMING SOON',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Coach will be back soon.',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We are shaping a calmer, more personal coaching space. Until then, today\'s plan, your training record, and your profile stay fully within reach.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: EditorialPrimaryButton(
                        label: 'Open Today\'s Plan',
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF390C00),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PlanPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              EditorialSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialSectionHeading(
                      eyebrow: 'Ready Today',
                      title: 'Everything you can keep moving with right now.',
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: const [
                        EditorialMetricTile(
                          label: 'Plan',
                          value: 'Meals & workouts',
                          icon: Icons.restaurant_menu_rounded,
                        ),
                        EditorialMetricTile(
                          label: 'Progress',
                          value: 'Daily rhythm',
                          icon: Icons.show_chart_rounded,
                        ),
                        EditorialMetricTile(
                          label: 'Profile',
                          value: 'Personal settings',
                          icon: Icons.person_outline_rounded,
                        ),
                        EditorialMetricTile(
                          label: 'Gym Tools',
                          value: 'Invites & branding',
                          icon: Icons.apartment_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              EditorialSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialSectionHeading(
                      eyebrow: 'Conversation History',
                      title: 'No messages yet.',
                      subtitle:
                          'Once coaching opens up, your check-ins and guidance will land here in one calm timeline.',
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: isDark ? 0.52 : 0.72),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: Icon(
                              Icons.forum_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'When coach support returns, you\'ll see replies, prompts, and check-ins here without needing to hunt for them.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
