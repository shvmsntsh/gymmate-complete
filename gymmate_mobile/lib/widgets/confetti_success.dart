import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class ConfettiSuccess extends StatefulWidget {
  final bool show;
  final Duration duration;
  const ConfettiSuccess({Key? key, required this.show, this.duration = const Duration(seconds: 3)}) : super(key: key);

  @override
  State<ConfettiSuccess> createState() => _ConfettiSuccessState();
}

class _ConfettiSuccessState extends State<ConfettiSuccess> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: widget.duration);
    if (widget.show) {
      _confettiController.play();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiSuccess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          particleDrag: 0.05,
          emissionFrequency: 0.05,
          numberOfParticles: 50,
          gravity: 0.05,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple
          ],
        ),
      ),
    );
  }
} 