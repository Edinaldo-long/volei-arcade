import 'package:flutter_test/flutter_test.dart';
import 'package:volei/main.dart';

void main() {
  test('VolleyGame instantiation smoke test', () {
    final game = VolleyGame();
    expect(game.phase, Phase.menu);
    expect(game.players.length, 4);
  });
}

