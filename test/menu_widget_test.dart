import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volei/main.dart';
import 'package:volei/rendering/tournament_celebration.dart';

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

  testWidgets('Menu has only Torneio and Amistoso modes, without 2P, training or coach', (tester) async {
    final game = VolleyGame();
    await tester.pumpWidget(VolleyApp(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verifica que modo treino, treinador e modo 2P local no celular foram removidos
    expect(find.text('MODO TREINO COM TREINADOR 📋'), findsNothing);
    expect(find.text('PROF. SILVA (TREINADOR)'), findsNothing);
    expect(find.text('2 JOGADORES (VERSUS LOCAL)'), findsNothing);

    // Modos principais disponíveis
    expect(find.text('JOGAR TORNEIO (4 FASES)'), findsOneWidget);
    expect(find.text('JOGAR AMISTOSO'), findsOneWidget);

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

  testWidgets('Tournament victory displays animated celebration with flag and winning players', (tester) async {
    bool playAgainCalled = false;
    bool menuCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TournamentCelebrationWidget(
            championCountry: 'BRASIL',
            shirtColor: const Color(0xFFFFD600),
            trimColor: const Color(0xFF1B8E3E),
            rivalCountry: 'ARGENTINA',
            championScore: 15,
            rivalScore: 12,
            isGrandChampion: true,
            hasNextRound: false,
            onNextRound: () {},
            onPlayAgain: () => playAgainCalled = true,
            onMenu: () => menuCalled = true,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifica elementos essenciais da celebração
    expect(find.text('🏆 CAMPEÃO DO TORNEIO! 🏆'), findsOneWidget);
    expect(find.text('BRASIL CONQUISTOU O TÍTULO MÁXIMO!'), findsOneWidget);
    expect(find.text('BRASIL 15  ×  12 ARGENTINA'), findsOneWidget);
    expect(find.text('JOGAR TORNEIO NOVAMENTE'), findsOneWidget);
    expect(find.text('MENU PRINCIPAL'), findsOneWidget);

    // Anima mais alguns frames para testar o canvas com os jogadores e confetes
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Testa os botões de ação
    await tester.tap(find.text('JOGAR TORNEIO NOVAMENTE'));
    expect(playAgainCalled, isTrue);

    await tester.tap(find.text('MENU PRINCIPAL'));
    expect(menuCalled, isTrue);
  });
}
