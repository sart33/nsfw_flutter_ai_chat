import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/config/app_theme.dart';

class PerimeterLoaderButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final String? loadingLabel;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double borderRadius;

  const PerimeterLoaderButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.loadingLabel,
    this.width = 260,
    this.height = 48,
    this.borderRadius = 32,
  });

  @override
  State<PerimeterLoaderButton> createState() => _PerimeterLoaderButtonState();
}

class _PerimeterLoaderButtonState extends State<PerimeterLoaderButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const Color _comet = Color(0xFFD97436); // оранжевый огонёк
  static const double _cometFraction = 0.25;     // длина огонька (доля периметра)
  static const Color _loadingBg = AppTheme.overlayDark; // фон при загрузке

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200), // скорость оборота
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isLoading) {
      _controller.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PerimeterLoaderButton old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isLoading) {
      _controller.stop();
      _controller.reset();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = !widget.isDisabled && !widget.isLoading;

    final button = ElevatedButton(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (widget.isLoading) return _loadingBg;
          if (states.contains(WidgetState.disabled)) return AppTheme.cardBg;
          return AppTheme.accentVivid; // обычная заливка
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (widget.isLoading) return _comet;
          if (states.contains(WidgetState.disabled)) return Colors.white38;
          return Colors.white;
        }),
        overlayColor: WidgetStateProperty.all(
          Colors.white.withOpacity(0.08), // лёгкое затемнение при нажатии
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (widget.isLoading || states.contains(WidgetState.disabled)) {
            return 0;
          }
          return 6;
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
      onPressed: active ? widget.onPressed : null,
      child: widget.isLoading
          ? AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) => Text(
          widget.loadingLabel ?? widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _comet.withOpacity(_pulseAnim.value),
          ),
        ),
      )
          : Text(
        widget.label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: button),
          if (widget.isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _PerimeterPainter(
                      progress: _controller.value,
                      borderRadius: widget.borderRadius,
                      color: _comet,
                      cometFraction: _cometFraction,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PerimeterPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final Color color;
  final double cometFraction;
  final Color trackColor;
  final double strokeWidth;

  const _PerimeterPainter({
    required this.progress,
    required this.borderRadius,
    required this.color,
    required this.cometFraction,
    this.trackColor = const Color(0xFF393948), // AppTheme.cardBorder
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final maxR = math.min(rect.width, rect.height) / 2;
    final r = math.min(borderRadius, maxR);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));

    final metric = path.computeMetrics().first;
    final len = metric.length;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, trackPaint);

    final segLen = len * cometFraction;
    final start = (progress * len) % len;
    final end = start + segLen;

    final cometPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (end <= len) {
      canvas.drawPath(metric.extractPath(start, end), cometPaint);
    } else {
      canvas.drawPath(metric.extractPath(start, len), cometPaint);
      canvas.drawPath(metric.extractPath(0, end - len), cometPaint);
    }
  }

  @override
  bool shouldRepaint(_PerimeterPainter old) =>
      old.progress != progress ||
          old.color != color ||
          old.borderRadius != borderRadius;
}