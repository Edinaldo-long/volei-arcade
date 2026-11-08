/// Stub para plataformas não-web (VM, testes).
class GamepadReader {
  static void poll({
    required Function(int playerIndex, double ax, double ay, bool left, bool right, bool up, bool down, bool jump, bool hit, bool start) onGamepadState,
  }) {
    // No-op em ambientes não-web sem Gamepad API W3C
  }
}
