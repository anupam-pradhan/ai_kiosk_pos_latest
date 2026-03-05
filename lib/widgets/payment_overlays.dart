import 'dart:async';

import 'package:flutter/material.dart';

class KioskDotLoader extends StatefulWidget {
  const KioskDotLoader({super.key, required this.color});

  final Color color;

  @override
  State<KioskDotLoader> createState() => _KioskDotLoaderState();
}

class _KioskDotLoaderState extends State<KioskDotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final start = index * 0.2;
        final end = start + 0.6;
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeInOut),
        );
        return FadeTransition(
          opacity: animation,
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class PaymentSuccessOverlay extends StatefulWidget {
  const PaymentSuccessOverlay({
    super.key,
    required this.amountStr,
    required this.cardStr,
    required this.onDone,
  });

  final String amountStr;
  final String cardStr;
  final VoidCallback onDone;

  @override
  State<PaymentSuccessOverlay> createState() => _PaymentSuccessOverlayState();
}

class _PaymentSuccessOverlayState extends State<PaymentSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _strokeProgress;
  late final Animation<double> _contentSlide;
  late final Animation<double> _contentOpacity;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _strokeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.4,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _checkController.forward();
    _pulseController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _contentController.forward();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const successGreen = Color(0xFF22C55E);
    const darkGreen = Color(0xFF16A34A);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: successGreen.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: successGreen, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) => Transform.scale(
                        scale: _checkScale.value,
                        child: Opacity(
                          opacity: _checkOpacity.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [successGreen, darkGreen],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x4022C55E),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: _CheckmarkPainter(
                                progress: _strokeProgress.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _contentSlide.value),
                  child: Opacity(
                    opacity: _contentOpacity.value,
                    child: Column(
                      children: [
                        const Text(
                          'Payment Successful',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D1D1F),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.amountStr.isNotEmpty)
                          Text(
                            widget.amountStr,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: darkGreen,
                              letterSpacing: -0.5,
                            ),
                          ),
                        if (widget.cardStr.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.credit_card,
                                  size: 14,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.cardStr,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Your order will be prepared shortly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
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

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final startX = cx - 14;
    final startY = cy + 2;
    final midX = cx - 4;
    final midY = cy + 12;
    final endX = cx + 16;
    final endY = cy - 10;

    path.moveTo(startX, startY);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      path.lineTo(startX + (midX - startX) * t, startY + (midY - startY) * t);
    } else {
      path.lineTo(midX, midY);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(midX + (endX - midX) * t, midY + (endY - midY) * t);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

class TapToPayInstructionOverlay extends StatefulWidget {
  const TapToPayInstructionOverlay({
    super.key,
    required this.amountStr,
    required this.onDone,
    this.deviceModel = 'SUNMI Flex 3',
    this.nfcHint = 'Hold Here',
  });

  final String amountStr;
  final VoidCallback onDone;
  final String deviceModel;
  final String nfcHint;

  @override
  State<TapToPayInstructionOverlay> createState() =>
      _TapToPayInstructionOverlayState();
}

class _TapToPayInstructionOverlayState extends State<TapToPayInstructionOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _countdownController;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismissOverlay();
      }
    });
    _enterController.forward();
    _countdownController.forward();
  }

  void _dismissOverlay() {
    if (_dismissed) return;
    _dismissed = true;
    if (_countdownController.isAnimating) {
      _countdownController.stop();
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ringGreen = Color(0xFF22C55E);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - 32).clamp(320.0, 380.0).toDouble();
    final ringSize = (cardWidth * 0.70).clamp(220.0, 260.0).toDouble();
    final innerCircleSize = (ringSize * 0.78).clamp(176.0, 204.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _countdownController]),
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_enterController.value);
          final countdown = 1.0 - _countdownController.value;
          return Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.94 + (0.06 * t),
                child: Center(
                  child: Container(
                    width: cardWidth,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: countdown,
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: ringGreen.withValues(
                                    alpha: 0.16,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        ringGreen,
                                      ),
                                ),
                              ),
                              Container(
                                width: innerCircleSize,
                                height: innerCircleSize,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF0FDF4),
                                  border: Border.all(
                                    color: ringGreen.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.contactless_rounded,
                                        size: 38,
                                        color: Color(0xFF15803D),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap card right here on next page',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF166534),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.amountStr.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.amountStr,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _dismissOverlay,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
