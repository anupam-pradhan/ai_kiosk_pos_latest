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
  late final AnimationController _pulseController;
  late final AnimationController _cardController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _enterController.forward();
    _pulseController.repeat();
    _cardController.repeat();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFC2410C);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _enterController,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_enterController.value);
          return Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: Opacity(opacity: t, child: child),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF7F2), Color(0xFFFFF3EC), Color(0xFFFFEADF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandOrange.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                right: -90,
                bottom: -110,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandOrange.withValues(alpha: 0.07),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sceneWidth = constraints.maxWidth > 520
                          ? 520.0
                          : constraints.maxWidth;
                      final sceneHeight = constraints.maxHeight > 820
                          ? 360.0
                          : constraints.maxHeight * 0.44;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Tap to Pay',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827),
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Hold Here',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.amountStr.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [brandOrange, Color(0xFF9A3412)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    widget.amountStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Center(
                              child: Container(
                                width: sceneWidth,
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 26,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: sceneWidth,
                                      height: sceneHeight,
                                      child: AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _pulseController,
                                          _cardController,
                                        ]),
                                        builder: (context, child) =>
                                            CustomPaint(
                                              painter:
                                                  _SunmiFlex3TapScenePainter(
                                                    pulseProgress:
                                                        _pulseController.value,
                                                    cardProgress:
                                                        _cardController.value,
                                                    brandColor: brandOrange,
                                                  ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.nfc,
                                      color: Color(0xFFC2410C),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.nfcHint,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2937),
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

class _SunmiFlex3TapScenePainter extends CustomPainter {
  _SunmiFlex3TapScenePainter({
    required this.pulseProgress,
    required this.cardProgress,
    required this.brandColor,
  });

  final double pulseProgress;
  final double cardProgress;
  final Color brandColor;

  @override
  void paint(Canvas canvas, Size size) {
    final phoneWidth = size.width * 0.34;
    final phoneHeight = size.height * 0.74;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.46, size.height * 0.56),
        width: phoneWidth,
        height: phoneHeight,
      ),
      const Radius.circular(18),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(phoneRect.shift(const Offset(0, 4)), shadowPaint);

    final phoneBodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF111827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(phoneRect.outerRect);
    canvas.drawRRect(phoneRect, phoneBodyPaint);

    final screenRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        phoneRect.left + 5,
        phoneRect.top + 8,
        phoneWidth - 10,
        phoneHeight - 16,
      ),
      const Radius.circular(14),
    );
    final screenPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF111827).withValues(alpha: 0.96),
          const Color(0xFF1F2937).withValues(alpha: 0.96),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(screenRect.outerRect);
    canvas.drawRRect(screenRect, screenPaint);

    final notchRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(phoneRect.center.dx - 12, phoneRect.top + 14, 24, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      notchRect,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final nfcCenter = Offset(
      phoneRect.center.dx,
      phoneRect.top + phoneHeight * 0.5,
    );

    final zonePaint = Paint()
      ..color = brandColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nfcCenter, phoneWidth * 0.16, zonePaint);

    final targetStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.4;
    final targetRadius = phoneWidth * 0.11;
    canvas.drawCircle(nfcCenter, targetRadius, targetStroke);
    canvas.drawLine(
      Offset(nfcCenter.dx - targetRadius, nfcCenter.dy),
      Offset(nfcCenter.dx + targetRadius, nfcCenter.dy),
      targetStroke,
    );
    canvas.drawLine(
      Offset(nfcCenter.dx, nfcCenter.dy - targetRadius),
      Offset(nfcCenter.dx, nfcCenter.dy + targetRadius),
      targetStroke,
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (var i = 0; i < 3; i++) {
      final phase = (pulseProgress + (i * 0.28)) % 1.0;
      final radius = targetRadius + 5 + phase * 30;
      ringPaint.color = brandColor.withValues(alpha: (1 - phase) * 0.55);
      canvas.drawCircle(nfcCenter, radius, ringPaint);
    }

    final guideStart = Offset(nfcCenter.dx + 104, nfcCenter.dy + 86);
    final guideEnd = Offset(nfcCenter.dx + 12, nfcCenter.dy + 12);
    final guidePaint = Paint()
      ..color = brandColor.withValues(alpha: 0.48)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, guideStart, guideEnd, guidePaint);
    final trailT = Curves.easeInOut.transform((cardProgress * 1.15) % 1.0);
    final trailDot = Offset.lerp(guideStart, guideEnd, trailT) ?? guideEnd;
    canvas.drawCircle(
      trailDot,
      3.5,
      Paint()..color = brandColor.withValues(alpha: 0.95),
    );

    final labelLeft = (nfcCenter.dx + 20)
        .clamp(10.0, size.width - 120.0)
        .toDouble();
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, nfcCenter.dy - 12, 104, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(labelRect, Paint()..color = const Color(0xFFFFF2E9));
    canvas.drawLine(
      Offset(labelRect.left, labelRect.center.dy),
      Offset(nfcCenter.dx + targetRadius + 2, nfcCenter.dy),
      Paint()
        ..color = brandColor.withValues(alpha: 0.65)
        ..strokeWidth = 1.4,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Hold Here',
        style: TextStyle(
          color: brandColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(labelRect.left + 15, labelRect.top + 7));

    _drawFrontTapBadge(canvas, phoneRect);
    _drawPaymentDevice(canvas, nfcCenter);
  }

  void _drawFrontTapBadge(Canvas canvas, RRect phoneRect) {
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(phoneRect.left - 2, phoneRect.top - 26, 82, 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFF111827).withValues(alpha: 0.84),
    );
    final badgeTextPainter = TextPainter(
      text: const TextSpan(
        text: 'HOLD HERE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeTextPainter.paint(
      canvas,
      Offset(badgeRect.left + 8, badgeRect.top + 5),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double distance = 0.0;
    while (distance < totalLength) {
      final dashStart = start + direction * distance;
      final dashEnd =
          start + direction * (distance + dashWidth).clamp(0, totalLength);
      canvas.drawLine(dashStart, dashEnd, paint);
      distance += dashWidth + dashSpace;
    }
  }

  void _drawPaymentDevice(Canvas canvas, Offset nfcCenter) {
    final t = cardProgress;
    double approach;
    if (t < 0.55) {
      approach = Curves.easeOutCubic.transform(t / 0.55);
    } else if (t < 0.85) {
      approach = 1.0; // Hold at tap point
    } else {
      approach = 1.0 - Curves.easeIn.transform((t - 0.85) / 0.15) * 0.2;
    }

    final start = Offset(nfcCenter.dx + 100, nfcCenter.dy + 88);
    final end = Offset(nfcCenter.dx + 10, nfcCenter.dy + 10);
    final current = Offset.lerp(start, end, approach) ?? end;
    final angle = -0.22 + (approach * 0.05);

    canvas.save();
    canvas.translate(current.dx, current.dy);
    canvas.rotate(angle);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -34, 40, 68),
        const Radius.circular(10),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -34, 40, 68),
        const Radius.circular(10),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(-20, -34, 40, 68)),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -28, 30, 48),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    final nfcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 2; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(4, -1), radius: 5.0 + i * 3.0),
        -1.1,
        0.85,
        false,
        nfcPaint,
      );
    }
    canvas.drawCircle(
      const Offset(2, 0),
      1.2,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunmiFlex3TapScenePainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.cardProgress != cardProgress ||
        oldDelegate.brandColor != brandColor;
  }
}
