# VÔLEI ARCADE

Vôlei 2 contra 2 em pixel art, com visão em perspectiva, inspirado nos clássicos de 8 bits. Feito com **Flutter** e **Flame**.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)

## O jogo

Dois jogadores de cada lado da rede, uma bola e até 15 pontos. A quadra é desenhada em perspectiva, com torcida, árbitro na cadeira, juízes de linha e placar de LED. Tudo é desenhado por código, então o projeto não usa nenhum arquivo de imagem ou som.

Foi pensado para celular deitado, com um joystick virtual de toque. No computador, também funciona com o teclado.

## Modos de jogo

| Modo | Descrição |
|---|---|
| **Torneio** | Quatro partidas seguidas contra Argentina, Japão, Itália e EUA, cada uma mais forte que a anterior. |
| **Amistoso vs CPU** | Uma partida contra o computador, com dificuldade Fácil, Normal ou Difícil. |
| **2 jogadores** | Dois jogadores no mesmo teclado, cada um com seu time. |

## Controles

### Celular

- **Joystick à esquerda:** move o jogador em qualquer direção. Dá para mudar de lado sem soltar o dedo, e quanto mais você puxa, mais rápido ele anda.
- **Botão laranja:** bater na bola e sacar.
- **Botão azul:** pular. Use para bloquear na rede.

Dá para mexer o joystick com um polegar e apertar os botões com o outro ao mesmo tempo.

### Teclado

| Ação | 1 jogador | 2 jogadores: P1 | 2 jogadores: P2 |
|---|---|---|---|
| Mover | `W` `A` `S` `D` ou setas | `W` `A` `S` `D` | Setas |
| Bater / sacar | `Espaço` ou `Z` | `Espaço` | `Enter` |
| Pular | `X` | `Q` | `Shift` direito |
| Pausar | `P` ou `Esc` | `P` ou `Esc` | `P` ou `Esc` |

## Regras

- Cada time pode dar **no máximo 3 toques** antes de mandar a bola para o outro lado.
- O **mesmo jogador não toca duas vezes seguidas**. O colega faz o toque seguinte.
- Normalmente os três toques são **recepção**, **levantamento** e **ataque**.
- Quem faz o ponto fica com o saque.
- Se a bola cai dentro da quadra, o ponto é de quem a mandou. Se cai fora, o ponto é do time contrário ao último que tocou nela.
- A partida vai até **15 pontos**, com diferença de 2. O limite é 21.
- Tocar na rede abaixo da fita faz a bola voltar.

## Dicas de jogo

- **Você controla um jogador por vez.** Uma seta colorida marca quem é. O controle passa sozinho para o jogador do seu time mais perto da bola.
- **Siga o anel, não a bola.** Quando é sua vez de tocar, um anel amarelo pulsa no chão onde a bola vai chegar. Leve o jogador até ele e aperte o botão laranja quando a bola estiver perto.
- **Mire com o joystick.** A direção que você segura na hora de bater decide para onde a bola vai: para o lado do adversário ela vai longe, para trás fica curta, e cima e baixo escolhem o lado da quadra.
- **Cortada.** No 2º ou 3º toque, perto da rede, bata com a bola alta e com o jogador no ar. A bola sai rápida e é difícil de defender.
- **Bloqueio.** Pule perto da rede quando o adversário for atacar.
- **Pulo automático.** Se você apertar bater com a bola alta e perto, o jogador pula sozinho.

## Como rodar

Você precisa do [Flutter](https://docs.flutter.dev/get-started/install) instalado.

```bash
git clone https://github.com/Edinaldo-long/volei-arcade.git
cd volei-arcade
flutter pub get
flutter run
```

A única dependência é o `flame`. Se o `pubspec.yaml` ainda não tiver, rode `flutter pub add flame`.

## Gerar o APK para Android

```bash
flutter build apk --release
```

O arquivo fica em `build/app/outputs/flutter-apk/app-release.apk`.

Copie para o celular e abra para instalar. Se o Android bloquear, ative a opção de instalar apps de fontes desconhecidas para o aplicativo que você usou para abrir o arquivo. Para atualizar o jogo, instale o novo APK por cima do antigo.

Com o celular conectado por USB e a depuração ativada, `flutter install` instala direto.

## Estrutura do projeto

Todo o jogo está em um único arquivo, `lib/main.dart`, dividido em blocos:

- **Constantes e projeção:** tamanho da quadra e a conversão da posição no jogo para a tela em perspectiva.
- **Jogo (`VolleyGame`):** fases da partida, regras, placar, bola, física e partículas.
- **IA:** papéis de recepção, levantamento, ataque e bloqueio, com níveis de dificuldade.
- **Desenho:** cenário, quadra, rede, personagens em pixel art e HUD.
- **Telas e controles:** menu, resultado, joystick e botões de toque.

---


