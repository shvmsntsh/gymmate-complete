import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ConfettiSuccess extends StatelessWidget {
  final bool show;
  const ConfettiSuccess({Key? key, required this.show}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Lottie.asset(
          'assets/lottie/confetti.json',
          repeat: false,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
} 