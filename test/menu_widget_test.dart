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

  testWidgets('Training Mode Coach Dialogue Box and Avatar test', (tester) async {
    final game = VolleyGame();
    await tester.pumpWidget(VolleyApp(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Inicia o Modo Treino com o Treinador
    game.startTraining(drill: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verifica se a Caixa de Diálogo do Treinador apareceu com título e texto legível
    expect(find.text('PROF. SILVA (TREINADOR)'), findsOneWidget);
    expect(find.text('ORIENTAÇÃO TÁTICA'), findsOneWidget);
    expect(find.text(TrainingController.drillTip(0)), findsOneWidget);

    // Fecha a dica clicando no botão X
    await tester.tap(find.byTooltip('Fechar dica'));
    await tester.pump();
    expect(find.text('PROF. SILVA (TREINADOR)'), findsNothing);

    // Clica no botão de lâmpada para reabrir a dica
    await tester.tap(find.byTooltip('Repetir dica do Treinador'));
    await tester.pump();
    expect(find.text('PROF. SILVA (TREINADOR)'), findsOneWidget);
    expect(find.text(TrainingController.drillTip(0)), findsOneWidget);

    // Avança para o próximo exercício
    await tester.tap(find.byTooltip('Próximo exercício'));
    await tester.pump();
    expect(find.text(TrainingController.drillTip(1)), findsOneWidget);

    // Clica no botão de demonstração em vídeo
    await tester.tap(find.byTooltip('Ver demonstração em vídeo (D)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verifica que o overlay de demonstração e botões de ação estão visíveis
    expect(find.text('🔁 REPETIR DEMO'), findsOneWidget);
    expect(find.text('▶️ MINHA VEZ! PRATICAR'), findsOneWidget);
    expect(game.training.isDemo, isTrue);

    // Clica em 'MINHA VEZ! PRATICAR' para voltar ao treino
    await tester.tap(find.text('▶️ MINHA VEZ! PRATICAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.training.isDemo, isFalse);

    // Pausa o jogo em Modo Treino e verifica o card com métricas de treino (Pontos, Acertos, Rank)
    game.togglePause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('PONTOS'), findsOneWidget);
    expect(find.text('ACERTOS'), findsOneWidget);
    expect(find.text('APROVEITAMENTO'), findsOneWidget);
    expect(find.text('VER DEMONSTRAÇÃO DO LANCE 🎬'), findsOneWidget);
  });
}
