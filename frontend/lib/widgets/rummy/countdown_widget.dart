import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/rummy_colors.dart';

/// Seconds-remaining label for the between-deal auto-start countdown.
class CountdownWidget extends StatefulWidget {
  final int initialSeconds;
  final String Function(int secondsLeft) labelBuilder;
  final VoidCallback? onFinished;

  const CountdownWidget({
    super.key,
    required this.initialSeconds,
    this.labelBuilder = _defaultLabel,
    this.onFinished,
  });

  static String _defaultLabel(int secondsLeft) =>
      'Next deal starts automatically in $secondsLeft seconds';

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.initialSeconds;
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  @override
  void didUpdateWidget(CountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeconds != widget.initialSeconds) {
      _timer?.cancel();
      _secondsLeft = widget.initialSeconds;
      if (_secondsLeft > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      }
    }
  }

  void _tick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    if (_secondsLeft <= 1) {
      timer.cancel();
      setState(() => _secondsLeft = 0);
      widget.onFinished?.call();
      return;
    }
    setState(() => _secondsLeft--);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialSeconds <= 0) return const SizedBox.shrink();
    return Text(
      widget.labelBuilder(_secondsLeft),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.55),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Shared panel chrome for deal/match result overlays (board stays visible).
class ResultOverlayShell extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ResultOverlayShell({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: RummyColors.panelBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RummyColors.gold.withOpacity(0.45), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
