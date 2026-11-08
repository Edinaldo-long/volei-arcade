import 'package:flutter_test/flutter_test.dart';
import 'package:volei/gameplay/training_controller.dart';
import 'package:volei/main.dart';

void main() {
  testWidgets('VolleyApp full widget and overlay smoke test', (tester) async {
    final game = VolleyGame();
    await tester.pumpWidget(VolleyApp(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Check menu overlay is present
    expect(find.text('VÔLEI ARCADE'), findsOneWidget);
    expect(find.text('SEU TIME:'), findsOneWidget);

    // Start match
    game.startMatch(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Pause match
    game.togglePause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Resume match
    game.togglePause();
    await tester.pump();

    // Toggle arena
    game.toggleArena();
    await tester.pump();

    // Toggle music
    game.toggleMusic();
    await tester.pump();
  });

  testWidgets('Menu has only Torneio, Amistoso and 2P modes, without training or coach', (tester) async {
    final game = VolleyGame();
    await tester.pumpWidget(VolleyApp(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verifica que o modo treino e treinador foram completamente removidos
    expect(find.text('MODO TREINO COM TREINADOR 📋'), findsNothing);
    expect(find.text('PROF. SILVA (TREINADOR)'), findsNothing);

    // Modos principais disponíveis
    expect(find.text('JOGAR TORNEIO (4 FASES)'), findsOneWidget);
    expect(find.text('JOGAR AMISTOSO'), findsOneWidget);
    expect(find.text('2 JOGADORES (VERSUS LOCAL)'), findsOneWidget);

    // Inicia Amistoso
    game.startMatch(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Pausa e verifica que exibe o placar oficial de partida sem card de treino
    game.togglePause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CONTINUAR'), findsOneWidget);
    expect(find.text('PONTOS'), findsNothing);
    expect(find.text('ACERTOS'), findsNothing);
  });
}
