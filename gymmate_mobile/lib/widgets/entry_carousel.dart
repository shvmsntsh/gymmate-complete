import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EntryCarousel extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onJoin;
  final VoidCallback onQuickJoin;

  const EntryCarousel({
    Key? key,
    required this.onLogin,
    required this.onJoin,
    required this.onQuickJoin,
  }) : super(key: key);

  @override
  _EntryCarouselState createState() => _EntryCarouselState();
}

class _EntryCarouselState extends State<EntryCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'title': 'Login',
        'description': 'Login with email & password if you have already registered',
        'icon': Icons.lock_open_outlined,
        'illustration': 'assets/illustration.png',
        'action': widget.onLogin,
      },
      {
        'title': 'Join Now',
        'description': 'Create a new account with your invitation code',
        'icon': Icons.person_add_alt_1_outlined,
        'illustration': 'assets/images/member_illustration.png',
        'action': widget.onJoin,
      },
      {
        'title': 'Quick Join',
        'description': 'Join instantly with your phone if you have been invited',
        'icon': Icons.rocket_launch_outlined,
        'illustration': 'assets/images/owner_illustration.png',
        'action': widget.onQuickJoin,
      },
    ];

    return SizedBox(
      height: 340,
      child: PageView.builder(
        controller: _pageController,
        itemCount: options.length,
        itemBuilder: (context, index) {
          final isSelected = _currentPage == index;
          return AnimatedScale(
            scale: isSelected ? 1.0 : 0.92,
            duration: 300.ms,
            child: _CarouselCard(
              title: options[index]['title'] as String,
              description: options[index]['description'] as String,
              icon: options[index]['icon'] as IconData,
              illustration: options[index]['illustration'] as String?,
              onTap: options[index]['action'] as VoidCallback,
              isActive: isSelected,
            ),
          );
        },
      ),
    );
  }
}

class _CarouselCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? illustration;
  final VoidCallback onTap;
  final bool isActive;

  const _CarouselCard({
    required this.title,
    required this.description,
    required this.icon,
    this.illustration,
    required this.onTap,
    required this.isActive,
  });

  @override
  State<_CarouselCard> createState() => _CarouselCardState();
}

class _CarouselCardState extends State<_CarouselCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final glow = widget.isActive
        ? <BoxShadow>[
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.35),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
          ]
        : <BoxShadow>[];

    return Card(
      elevation: widget.isActive ? 12.0 : 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.5), width: 1),
      ),
      color: colorScheme.surface.withOpacity(0.7),
      shadowColor: colorScheme.primary.withOpacity(0.18),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: AnimatedContainer(
          duration: 200.ms,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: glow,
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.illustration != null && widget.illustration!.isNotEmpty)
                Image.asset(
                  widget.illustration!,
                  height: 70,
                  fit: BoxFit.contain,
                )
              else
                Icon(widget.icon, size: 60, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              AnimatedScale(
                scale: _pressed ? 1.08 : 1.0,
                duration: 120.ms,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: widget.onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text('Continue'),
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