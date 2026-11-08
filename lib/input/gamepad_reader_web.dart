import 'dart:js_interop';

@JS('GamepadButton')
extension type JSGamepadButton(JSObject _) implements JSObject {
  external bool get pressed;
  external double get value;
}

@JS('Gamepad')
extension type JSGamepad(JSObject _) implements JSObject {
  external int get index;
  external String? get id;
  external bool get connected;
  external JSArray<JSNumber> get axes;
  external JSArray<JSGamepadButton> get buttons;
}

@JS('navigator')
external JSObject? get _navigator;

extension type JSNavigator(JSObject _) implements JSObject {
  external JSArray<JSGamepad?>? getGamepads();
}

/// Leitor da Gamepad API padrão do navegador (Chrome, Edge, Firefox, Safari).
class GamepadReader {
  static final List<bool> _prevHit = [false, false, false, false];
  static final List<bool> _prevStart = [false, false, false, false];

  static void poll({
    required Function(
      int playerIndex,
      double ax,
      double ay,
      bool left,
      bool right,
      bool up,
      bool down,
      bool jump,
      bool hit,
      bool start,
    ) onGamepadState,
  }) {
    try {
      final nav = _navigator;
      if (nav == null) return;
      final pads = JSNavigator(nav).getGamepads();
      if (pads == null) return;

      final count = pads.length;
      var activeIndex = 0;

      for (var i = 0; i < count && activeIndex < 2; i++) {
        final gp = pads[i];
        if (gp == null || !gp.connected) continue;

        // Eixos do Analógico Esquerdo
        double ax = 0.0;
        double ay = 0.0;
        if (gp.axes.length >= 2) {
          final rawX = gp.axes[0].toDartDouble;
          final rawY = gp.axes[1].toDartDouble;
          // Deadzone de 16% para prevenir drift em controles analógicos
          if (rawX.abs() > 0.16) ax = rawX.clamp(-1.0, 1.0);
          if (rawY.abs() > 0.16) ay = rawY.clamp(-1.0, 1.0);
        }

        // Leitura de botões (padrão standard Gamepad W3C)
        bool btn(int idx) {
          if (idx >= gp.buttons.length) return false;
          final b = gp.buttons[idx];
          return b.pressed || b.value > 0.5;
        }

        // D-Pad: 12=Up, 13=Down, 14=Left, 15=Right
        final dUp = btn(12);
        final dDown = btn(13);
        final dLeft = btn(14);
        final dRight = btn(15);

        // Se o analógico não está sendo usado, d-pad pode fornecer ax e ay
        if (ax == 0.0) {
          if (dLeft) ax = -1.0;
          if (dRight) ax = 1.0;
        }
        if (ay == 0.0) {
          if (dUp) ay = -1.0;
          if (dDown) ay = 1.0;
        }

        // Ações:
        // Botão de Bater / Atacar / Saque: A (0), X (2), RB (5), RT (7)
        final rawHit = btn(0) || btn(2) || btn(5) || btn(7);
        // Botão de Pular / Bloqueio: B (1), Y (3), LB (4), LT (6)
        final jump = btn(1) || btn(3) || btn(4) || btn(6);

        // Disparo de Bater (apenas na borda de subida para não repetir indefinidamente)
        final hitTriggered = rawHit && !_prevHit[activeIndex];
        _prevHit[activeIndex] = rawHit;

        // Start / Pause: 9 (Start), 8 (Select)
        final rawStart = btn(9) || btn(8);
        final startTriggered = rawStart && !_prevStart[activeIndex];
        _prevStart[activeIndex] = rawStart;

        onGamepadState(
          activeIndex,
          ax,
          ay,
          dLeft || ax < -0.35,
          dRight || ax > 0.35,
          dUp || ay < -0.35,
          dDown || ay > 0.35,
          jump,
          hitTriggered,
          startTriggered,
        );

        activeIndex++;
      }
    } catch (_) {
      // Ignora falhas de plataforma silenciosamente
    }
  }
}
