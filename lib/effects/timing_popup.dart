import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Popup visual flutuante para feedback imediato de timing do toque.
class TimingPopupItem {
  final String text;
  final Offset position;
  final Color color;
  final double maxLife;
  double life;
  double offsetY = 0.0;

  TimingPopupItem({
    required this.text,
    required this.position,
    required this.color,
    this.maxLife = 0.65,
  }) : life = maxLife;
}

/// Gerenciador de textos flutuantes com estética retrô arcade.
class TimingPopupManager {
  final List<TimingPopupItem> _items = [];

  void add({
    required String text,
    required Offset position,
    required Color color,
    double maxLife = 0.65,
  }) {
    _items.add(TimingPopupItem(
      text: text,
      position: position,
      color: color,
      maxLife: maxLife,
    ));
    if (_items.length > 10) {
      _items.removeAt(0);
    }
  }

  void update(double dt) {
    for (final it in _items) {
      it.life -= dt;
      // Sobe com interpolação suave desacelerada
      it.offsetY -= 48.0 * dt;
    }
    _items.removeWhere((it) => it.life <= 0);
  }

  void clear() {
    _items.clear();
  }

  void render(Canvas canvas) {
    for (final it in _items) {
      final progress = (it.life / it.maxLife).clamp(0.0, 1.0);
      final alpha = (progress * 2.0).clamp(0.0, 1.0);
      final scale = 1.0 + 0.25 * math.sin((1.0 - progress) * math.pi);

      final textColor = it.color.withValues(alpha: alpha);
      final outlineColor = Colors.black.withValues(alpha: alpha * 0.9);

      try {
        final tp = TextPainter(
          text: TextSpan(
            text: it.text,
            style: TextStyle(
              color: textColor,
              fontSize: 16.0 * scale,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(offset: const Offset(2, 2), color: outlineColor),
                Shadow(offset: const Offset(-2, 2), color: outlineColor),
                Shadow(offset: const Offset(2, -2), color: outlineColor),
                Shadow(offset: const Offset(-2, -2), color: outlineColor),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final drawPos = Offset(
          it.position.dx - tp.width / 2,
          it.position.dy + it.offsetY - tp.height / 2,
        );

        tp.paint(canvas, drawPos);
      } catch (_) {}
    }
  }
}
