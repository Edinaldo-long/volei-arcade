<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vôlei Arcade 2 x 2</title>
<style>
  :root {
    --bg: #fbfaf5;
    --surface: #ffffff;
    --text: #1b1b2f;
    --muted: #5b5f73;
    --accent: #e0a400;
    --accent-ink: #1b1b2f;
    --line: #d9d8cf;
    --code-bg: #14122b;
    --code-text: #f3f1e6;
    color-scheme: light;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0b1038;
      --surface: #121a52;
      --text: #f3f1e6;
      --muted: #aab0d4;
      --accent: #ffd600;
      --accent-ink: #14122b;
      --line: #2a3380;
      --code-bg: #07070c;
      --code-text: #f3f1e6;
      color-scheme: dark;
    }
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
    line-height: 1.6;
  }
  main { max-width: 860px; margin: 0 auto; padding: 32px 20px 64px; }
  header { text-align: center; padding: 24px 0 8px; }
  h1 {
    font-family: "Courier New", Courier, monospace;
    font-size: clamp(2rem, 6vw, 3rem);
    letter-spacing: 2px;
    margin: 0 0 8px;
    color: var(--accent);
    text-shadow: 3px 3px 0 var(--code-bg);
  }
  .tagline { color: var(--muted); margin: 0 0 18px; }
  .badges { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
  .badge {
    border: 2px solid var(--line);
    background: var(--surface);
    padding: 2px 10px;
    font-size: .85rem;
    font-family: "Courier New", Courier, monospace;
    font-weight: 700;
  }
  h2 {
    font-family: "Courier New", Courier, monospace;
    border-bottom: 4px solid var(--accent);
    display: inline-block;
    padding-bottom: 2px;
    margin: 40px 0 14px;
  }
  h3 { margin: 22px 0 6px; }
  section p, section li { max-width: 70ch; }
  .card {
    background: var(--surface);
    border: 3px solid var(--line);
    box-shadow: 5px 5px 0 var(--code-bg);
    padding: 14px 18px;
    margin: 12px 0;
  }
  .grid { display: grid; gap: 14px; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
  .grid .card { margin: 0; }
  .grid h3 { margin-top: 0; }
  .table-wrap { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; background: var(--surface); }
  th, td { border: 2px solid var(--line); padding: 8px 12px; text-align: left; vertical-align: top; }
  th { background: var(--accent); color: var(--accent-ink); }
  kbd {
    font-family: "Courier New", Courier, monospace;
    background: var(--code-bg);
    color: var(--code-text);
    padding: 1px 7px;
    border-radius: 3px;
    font-size: .9em;
    white-space: nowrap;
  }
  code {
    font-family: "Courier New", Courier, monospace;
    background: var(--surface);
    border: 1px solid var(--line);
    padding: 0 5px;
    font-size: .92em;
  }
  pre {
    background: var(--code-bg);
    color: var(--code-text);
    padding: 14px 16px;
    overflow-x: auto;
    border-left: 6px solid var(--accent);
    margin: 10px 0;
  }
  pre code { background: none; border: 0; padding: 0; color: inherit; }
  .dot { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 6px; border: 2px solid var(--code-bg); vertical-align: -1px; }
  .orange { background: #ffa000; }
  .blue { background: #1e88e5; }
  .yellow { background: #ffeb3b; }
  .white { background: #fff; }
  footer { margin-top: 48px; color: var(--muted); font-size: .9rem; text-align: center; }
  nav { display: flex; flex-wrap: wrap; gap: 6px 16px; justify-content: center; margin: 20px 0 0; font-size: .95rem; }
  nav a { color: var(--text); font-weight: 700; }
</style>
</head>
<body>
<main>

<header>
  <h1>VÔLEI ARCADE</h1>
  <p class="tagline">Vôlei 2 contra 2 em pixel art, com visão em perspectiva, inspirado nos clássicos de 8 bits. Feito com Flutter e Flame.</p>
  <div class="badges">
    <span class="badge">Flutter</span>
    <span class="badge">Flame</span>
    <span class="badge">Android</span>
    <span class="badge">Sem imagens nem sons</span>
  </div>
  <nav>
    <a href="#jogo">O jogo</a>
    <a href="#modos">Modos</a>
    <a href="#controles">Controles</a>
    <a href="#regras">Regras</a>
    <a href="#dicas">Dicas</a>
    <a href="#rodar">Como rodar</a>
    <a href="#apk">Gerar APK</a>
  </nav>
</header>

<section id="jogo">
  <h2>O jogo</h2>
  <p>
    Dois jogadores de cada lado da rede, uma bola e até 15 pontos. A quadra é desenhada
    em perspectiva, com torcida, árbitro na cadeira, juízes de linha e placar de LED.
    Tudo é desenhado por código, então o projeto não usa nenhum arquivo de imagem ou som.
  </p>
  <p>
    Foi pensado para celular deitado, com um joystick virtual de toque. No computador, também
    funciona com o teclado.
  </p>
</section>

<section id="modos">
  <h2>Modos de jogo</h2>
  <div class="grid">
    <div class="card">
      <h3>Torneio</h3>
      <p>Quatro partidas seguidas contra seleções cada vez mais fortes: Argentina, Japão, Itália e EUA. Perdeu, recomeça a partida.</p>
    </div>
    <div class="card">
      <h3>Amistoso vs CPU</h3>
      <p>Uma partida contra o computador, com três dificuldades: Fácil, Normal e Difícil.</p>
    </div>
    <div class="card">
      <h3>2 jogadores</h3>
      <p>Dois jogadores no mesmo teclado, cada um com seu time.</p>
    </div>
  </div>
</section>

<section id="controles">
  <h2>Controles</h2>

  <h3>Celular</h3>
  <ul>
    <li><strong>Joystick à esquerda:</strong> mexe o jogador em qualquer direção. Dá para mudar de lado sem soltar o dedo, e quanto mais você puxa, mais rápido ele anda.</li>
    <li><span class="dot orange"></span><strong>Botão laranja:</strong> bater na bola (e sacar).</li>
    <li><span class="dot blue"></span><strong>Botão azul:</strong> pular. Use para bloquear na rede.</li>
  </ul>
  <p>Você pode mexer o joystick com um polegar e apertar os botões com o outro ao mesmo tempo.</p>

  <h3>Teclado</h3>
  <div class="table-wrap">
    <table>
      <thead>
        <tr><th>Ação</th><th>1 jogador</th><th>2 jogadores: P1</th><th>2 jogadores: P2</th></tr>
      </thead>
      <tbody>
        <tr><td>Mover</td><td><kbd>W A S D</kbd> ou setas</td><td><kbd>W A S D</kbd></td><td>Setas</td></tr>
        <tr><td>Bater / sacar</td><td><kbd>Espaço</kbd> ou <kbd>Z</kbd></td><td><kbd>Espaço</kbd></td><td><kbd>Enter</kbd></td></tr>
        <tr><td>Pular</td><td><kbd>X</kbd></td><td><kbd>Q</kbd></td><td><kbd>Shift</kbd> direito</td></tr>
        <tr><td>Pausar</td><td colspan="3"><kbd>P</kbd> ou <kbd>Esc</kbd></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section id="regras">
  <h2>Regras</h2>
  <ul>
    <li>Cada time pode dar <strong>no máximo 3 toques</strong> antes de mandar a bola para o outro lado.</li>
    <li>O <strong>mesmo jogador não toca duas vezes seguidas</strong>. O colega faz o toque seguinte.</li>
    <li>Normalmente os três toques são <strong>recepção</strong>, <strong>levantamento</strong> e <strong>ataque</strong>.</li>
    <li>Quem faz o ponto fica com o saque.</li>
    <li>Se a bola cai dentro da quadra, o ponto é de quem a mandou. Se cai fora, o ponto é do time contrário ao último que tocou nela.</li>
    <li>A partida vai até <strong>15 pontos</strong>, com diferença de 2. O limite é 21.</li>
    <li>Tocar na rede abaixo da fita faz a bola voltar.</li>
  </ul>
</section>

<section id="dicas">
  <h2>Dicas de jogo</h2>
  <div class="card">
    <p><strong>Você controla um jogador por vez.</strong> Uma seta colorida marca quem é. O controle passa sozinho para o jogador do seu time mais perto da bola.</p>
    <p><strong>Siga o anel, não a bola.</strong> Quando é sua vez de tocar, um anel <span class="dot yellow"></span>amarelo pulsa no chão onde a bola vai chegar. Leve o jogador até ele e aperte o botão laranja quando a bola estiver perto.</p>
    <p><strong>Mire com o joystick.</strong> A direção que você segura na hora de bater decide para onde a bola vai: para o lado do adversário ela vai longe, para trás fica curta, e cima e baixo escolhem o lado da quadra.</p>
    <p><strong>Cortada.</strong> No 2º ou 3º toque, perto da rede, bata com a bola alta e com o jogador no ar. A bola sai rápida e é difícil de defender.</p>
    <p><strong>Bloqueio.</strong> Pule perto da rede quando o adversário for atacar.</p>
    <p><strong>Pulo automático.</strong> Se você apertar bater com a bola alta e perto, o jogador pula sozinho.</p>
  </div>
</section>

<section id="rodar">
  <h2>Como rodar</h2>
  <p>Você precisa do <a href="https://docs.flutter.dev/get-started/install">Flutter</a> instalado.</p>
<pre><code>git clone https://github.com/Edinaldo-long/volei-arcade.git
cd volei-arcade
flutter pub get
flutter run</code></pre>
  <p>
    A única dependência é o <code>flame</code>. Se o <code>pubspec.yaml</code> ainda não
    tiver, rode <code>flutter pub add flame</code>.
  </p>
</section>

<section id="apk">
  <h2>Gerar o APK para Android</h2>
<pre><code>flutter build apk --release</code></pre>
  <p>O arquivo fica em:</p>
<pre><code>build/app/outputs/flutter-apk/app-release.apk</code></pre>
  <p>
    Copie para o celular e abra para instalar. Se o Android bloquear, ative a opção
    de instalar apps de fontes desconhecidas para o aplicativo que você usou para abrir o arquivo.
    Para atualizar o jogo, instale o novo APK por cima do antigo.
  </p>
  <p>Com o celular conectado por USB e a depuração ativada, <code>flutter install</code> instala direto.</p>
</section>

<section id="estrutura">
  <h2>Estrutura do projeto</h2>
  <p>Todo o jogo está em um único arquivo, <code>lib/main.dart</code>, dividido em blocos:</p>
  <ul>
    <li><strong>Constantes e projeção:</strong> tamanho da quadra e a conversão da posição no jogo para a tela em perspectiva.</li>
    <li><strong>Jogo (<code>VolleyGame</code>):</strong> fases da partida, regras, placar, bola, física e partículas.</li>
    <li><strong>IA:</strong> papéis de recepção, levantamento, ataque e bloqueio, com níveis de dificuldade.</li>
    <li><strong>Desenho:</strong> cenário, quadra, rede, personagens em pixel art e HUD.</li>
    <li><strong>Telas e controles:</strong> menu, resultado, joystick, botões de toque.</li>
  </ul>
</section>

<footer>
  Feito por Edinaldo-long
</footer>

</main>
</body>
</html>
