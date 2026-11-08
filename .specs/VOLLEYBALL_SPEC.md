# Spec: Sistema de Gameplay Avançado, Lances Especiais & Game Feel — Vôlei Arcade Flutter/Flame

**Documento:** Especificação Técnica de Gameplay (Spec-Driven Development)  
**Versão:** 2.0.0  
**Perfil:** Senior Game Designer & Gameplay Engineer (Flutter & Flame)  
**Status:** Aprovado para Planejamento Modular  

---

## 1. Visão Geral & Filosofia de Game Design

O objetivo desta especificação é consolidar o jogo de vôlei como uma experiência retro arcade de alta performance e dinamismo tático (inspirada em clássicos cultuados como *Super Spike V'Ball*, *Beach Spikers* e *Windjammers*), combinando:
1. **Controles Intuitivos de 2 Botões + Analógico:** Mapeamento inteligente onde contexto, posicionamento e timing destravam jogadas de vôlei de quadra e praia de nível olímpico.
2. **Profundidade Mecânica & Repertório Completo:** Ataques variados (potência, finta, tempo 1 e ataque do fundo), defesas acrobáticas (peixinho no chão e resgate fora da quadra) e saques estratégicos (viagem veloz com barra de precisão e flutuante imprevisível).
3. **Game Feel "Juicy" de Alto Impacto:** Micro-congelamentos de impacto (*hitstop*), desaceleração dramática (*slowdown*), tremor de tela (*screen shake* trauma-based), partículas estilizadas e feedback instantâneo de timing (*Timing Popups*).
4. **Robustez Absoluta de Código:** Tipagem estrita com prevenção contra exceções nulas (*TypeError: null is not a subtype of type String*) em toda a camada de UI, áudio e HUD.

---

## 2. Especificação dos Lances de Ataque e Finalização

### 2.1. Super Cortada Cravada (Monster Spike)
* **Conceito:** O ataque mais potente do jogo. Uma cravada fulminante disparada no ápice absoluto do salto que afunda em ângulo vertical rasante na quadra adversária.
* **Critérios de Ativação:**
  - Jogador aéreo (`!p.onGround`) próximo à rede (`|p.x - kMid| < 260px`).
  - Bola acima da fita (`bz > kNetH - 25px`).
  - Ponto de contato no sweet spot: altura relativa $60.0 \le \Delta z \le 125.0$, velocidade vertical do salto no ápice ($-160 \le v_z \le 220$), distância horizontal $\le 80\text{px}$.
  - Vetor direcional agressivo: analógico direcionado para frente/baixo (`aimX > 0.25`).
* **Física & Trajetória:**
  - Multiplicador de velocidade balística: **$1.35\times$ a $1.42\times$**.
  - Topspin agressivo: $+28.0$ a $+32.0$ (força Magnus acelerando a queda vertical da bola).
  - Tempo de voo ultra reduzido ($tt \approx 0.26\text{s}$ a $0.30\text{s}$).
* **Feedback Visual & Áudio (Juice):**
  - **Hitstop:** Freeze frame de $50\text{ms}$ a $65\text{ms}$ na bola e nos atores.
  - **Screen Shake:** Trauma de câmera $+0.70$ com vetor vertical e decaimento polinomial suave.
  - **Trail da Bola:** Rastro contínuo flamejante dourado/âmbar com partículas e distorção squash longitudinal ($1.45\times$).
  - **Áudio:** Som estalado de pancada seca, aplausos e aclamação da torcida no ginásio/praia.
  - **HUD/Popup:** Texto `"CORTADA PERFEITA!"` dourado com brilho.

### 2.2. Largadinha Tática (The Tip / Feint)
* **Conceito:** Golpe sutil e desconsertante. O jogador finge uma cortada violenta, mas dá um toque suave com a ponta dos dedos que amortece a bola, fazendo-a planar e cair rente logo atrás do bloqueio adversário.
* **Critérios de Ativação:**
  - Jogador no ar próximo à rede em situação de ataque.
  - Comando específico: toque suave no botão de bater com analógico neutro ou puxado sutilmente para trás (`aimX < 0.15`), ou botão secundário de finta.
* **Física & Trajetória:**
  - A velocidade da bola sofre desaceleração brusca imediata ($v_x \times 0.38$, $v_y \times 0.38$).
  - Velocidade vertical moderada para cima ($v_z \approx 85\text{px/s}$), produzindo uma parábola curta e graciosa que ultrapassa a rede com folga de $15\text{px}$ a $25\text{px}$ e cai rapidamente entre $40\text{px}$ e $110\text{px}$ da linha central.
  - Topspin nulo ($topspin = 0$), impedindo aceleração descendente precoce.
* **Feedback Visual & Áudio (Juice):**
  - Sem hitstop agressivo (movimento fluido e esguio).
  - Som sutil de ponta de dedo (*plink/pop* suave).
  - Texto flutuante `"LARGADINHA!"` em cor ciano/lilás.
  - Pega bloqueadores de surpresa (bloqueio oponente salta no vazio e a bola cai atrás de suas costas).

### 2.3. Ataque Rápido de Meio (Quick Attack / Tempo 1)
* **Conceito:** Jogada ensaiada veloz de 1º tempo. O atacante de rede (meio de rede) salta antes mesmo da bola chegar às mãos do levantador; o passe do levantador é tenso e horizontal, e o atacante desfere o golpe no milissegundo em que a bola passa pela fita.
* **Critérios de Ativação:**
  - Segundo toque da equipe (fase de levantamento).
  - O atacante companheiro já está no ar ou decolando próximo à fita ($|p.x - 450| < 90\text{px}$ e $p.z > 20\text{px}$).
  - O levantador dispara o passe para a frente imediata da rede em linha reta.
* **Física & Trajetória:**
  - Parábola quase retilínea com ápice baixo ($apexZ \approx 165\text{px}$, apenas ligeiramente acima da rede de $130\text{px}$).
  - Tempo de trânsito relâmpago ($tt \approx 0.20\text{s}$).
  - A defesa e os bloqueadores rivais têm tempo de reação reduzido pela metade.
* **Feedback Visual & Áudio (Juice):**
  - Efeito sonoro de chicote rápido (*whoosh-smash*).
  - Efeito visual de rastro elétrico azul claro.
  - Popup `"ATAQUE RÁPIDO!"`.

### 2.4. Ataque do Fundo (Pipe Attack / Linha dos 3 Metros)
* **Conceito:** O jogador que está posicionado no fundo da quadra corre, toma impulsão potente antes da linha dos 3 metros ($x < 300\text{px}$ ou $x > 600\text{px}$), voa horizontalmente por cima da linha e crava a bola por cima do bloqueio na fita.
* **Critérios de Ativação:**
  - Jogador de trás (slot 0) recebe levantamento longo e alto no meio da quadra.
  - Decolagem realizada antes da linha dos 3 metros (respeitando a regra oficial do voleibol).
* **Física & Trajetória:**
  - Impulsão horizontal ampliada ($v_{x\text{jump}} \approx 320\text{px/s}$ a $380\text{px/s}$ para a frente).
  - Contato com bola em altura mais elevada ($z > 70\text{px}$).
  - Trajetória com ângulo longo e veloz atingindo o terço final da quadra adversária.
* **Feedback Visual & Áudio (Juice):**
  - Nuvem de poeira e marca de sola no piso na linha dos 3 metros.
  - Popup visual `"PIPE ATTACK!"` em cor alaranjada vibrante.
  - Rastro contínuo na bola sobrevoando a rede com grande amplitude.

---

## 3. Especificação dos Lances de Defesa e Bloqueio

### 3.1. Peixinho Defensivo (Pancake / Dive Save)
* **Conceito:** O lance mais acrobático da defesa. Quando uma cortada ou largadinha adversária está a fração de segundo de tocar o chão longe do defensor, o jogador se atira de peito no piso esticando a mão espalmada para a bola quicar no dorso da mão e permanecer viva no rally.
* **Critérios de Ativação:**
  - Bola em trajetória descendente acentuada em direção à quadra do jogador ($v_z < -180$).
  - Altura crítica da bola prestes a tocar o solo ($10\text{px} \le b_z \le 35\text{px}$, tempo até o solo $< 0.16\text{s}$).
  - Distância do jogador para a bola entre $65\text{px}$ e $145\text{px}$ (fora do alcance de toque em pé, exigindo mergulho).
  - Pressionamento do botão de ação defensiva na direção da bola.
* **Física & Movimentação:**
  - O jogador transiciona para o estado `PlayerState.diving` rente ao chão ($p.z = 0$, corpo na horizontal).
  - Impulso de deslize no piso ($v_{x\text{slide}} = \text{dir} \times 440\text{px/s}$ desacelerando com fricção de atrito por $0.4\text{s}$).
  - Se a mão interceptar a bola antes de $b_z = 0$, a bola é amortecida e impulsionada verticalmente para cima ($v_z = 380\text{px/s}$, $v_x$ amortecido em direção ao levantador).
* **Feedback Visual & Áudio (Juice):**
  - **Slow-motion dinâmico:** Micro-desaceleração do tempo global ($dt \times 0.35$) por $120\text{ms}$ no instante do mergulho, restaurando a velocidade normal com curva ease-out.
  - **Partículas:** Rastro duplo de poeira/fumaça no piso simulando o atrito do corpo deslizando na quadra de madeira ou na areia da praia.
  - **Áudio:** Som seco de contato no piso e "pop" elástico na mão.
  - **Popup:** `"PEIXINHO DEFENSIVO!"` com estrelas douradas.

### 3.2. Bloqueio Toco (Monster Block / Roof)
* **Conceito:** A barreira intransponível na rede. Quando o atacante adversário desfere uma cortada potente, um ou dois bloqueadores sobem na fita com timing impecável e "engolem" a bola, devolvendo-a instantaneamente para baixo no chão rival.
* **Critérios de Ativação:**
  - Jogador(es) na rede ($|p.x - 450| < 80\text{px}$) no ar com braços acima da fita ($p.z + 86 > kNetH$).
  - Timing com a cortada adversária: a bola atinge as mãos dos bloqueadores nos primeiros instantes após o golpe rival.
  - Suporte a **bloqueio duplo sincronizado** (se o companheiro de rede também estiver no ar ao lado).
* **Física & Trajetória:**
  - Inversão imediata de direção horizontal ($v_x = \text{dirOpp} \times 540\text{px/s}$).
  - Vetor descendente violento ($v_z = -180\text{px/s}$ a $-240\text{px/s}$), cravando na quadra atacante.
* **Feedback Visual & Áudio (Juice):**
  - **Hitstop:** Freeze frame de $60\text{ms}$.
  - **Screen Shake:** Tremor horizontal de tela ($trauma = 0.65$).
  - **Flash Visual:** Brilho de choque na fita da rede com faíscas metálicas azuis e amarelas.
  - **Áudio:** Som cavernoso de abafamento e torcida vai ao delírio.
  - **Popup:** `"SUPER BLOQUEIO TOCO!"`.

### 3.3. Recuperação Fora da Quadra (Out-of-Bounds Rescue)
* **Conceito:** A bola espirra torta no bloqueio ou na manchete e viaja para fora das linhas da quadra. O atleta corre para além das linhas laterais ou de fundo, alcança a bola no ar antes do chão e devolve de costas para o companheiro salvar o ponto.
* **Critérios de Ativação:**
  - A bola cruza os limites laterais ($y < 0$ ou $y > 430$) ou de fundo ($x < 0$ ou $x > 900$) com velocidade residual.
  - Jogador elegível tem seus limites de locomoção estendidos para fora da quadra (área de escape de até $120\text{px}$).
* **Física & Movimentação:**
  - Sprint automático acelerado ($1.25\times$ da velocidade máxima) para alcançar a bola.
  - Toque reverso: mesmo correndo para fora da quadra de costas para a rede, o cálculo de lançamento inverte o vetor com parábola alta de salvação direcionada ao centro da quadra amiga ($apexZ = 260\text{px}$).
* **Feedback Visual & Áudio (Juice):**
  - Som de esforço do atleta, aplauso imediato da torcida pela recuperação difícil.
  - Popup `"RECUPERAÇÃO ESPETACULAR!"`.

---

## 4. Especificação dos Saques Dinâmicos

### 4.1. Saque Viagem Potente (Jump Serve com Mini-Barra de Timing)
* **Conceito:** O saque mais rápido e agressivo do voleibol moderno. O atleta joga a bola bem alto para a frente, parte em corrida veloz, salta antes da linha de fundo e atinge a bola no ápice com força total.
* **Mecânica da Mini-Barra de Timing:**
  - Ao lançar a bola para o saque viagem, surge sobre a cabeça do atleta uma mini-barra visual retrô estilizada com indicador móvel em tempo real.
  - **Zonas da Barra:**
    - **Zona Dourada Central (Perfeito - 20% da barra):** Saque a $1.35\times$ de velocidade com topspin máximo. Se a recepção adversária não estiver perfeitamente posicionada, resulta em **Ace** ou bola espirrada.
    - **Zona Ciano (Bom - 40% da barra):** Saque firme a $1.15\times$ de velocidade que passa fácil pela rede.
    - **Zonas Extremas (Cedo / Tarde):** Saque sem força ($0.85\times$) ou com risco de bola na fita/fora.
* **Feedback Visual & Áudio (Juice):**
  - Mini-barra com contorno pixel art neon que se apaga no momento do golpe.
  - Efeito sonoro de impacto ensurdecedor e rastro dourado na trajetória.

### 4.2. Saque Flutuante (Float Serve com Turbulência Senoidal)
* **Conceito:** Saque estratégico sem rotação. A bola é atingida no centro de massa com a palma dura; sem topspin, a bola sofre instabilidade aerodinâmica pelas correntes de ar, oscilando no voo e caindo de repente.
* **Critérios de Ativação:**
  - Saque executado no chão ou com salto leve, sem corrida extensa.
  - Toque seco no centro da bola (`topspin = 0.0`).
* **Física & Trajetória Aerodinâmica:**
  - Modelo de instabilidade pseudo-Magnus / vórtices com oscilação harmônica:
    $$y(t) = y_{\text{base}}(t) + A_y \cdot \sin(\omega_y \cdot t + \phi_y)$$
    $$z(t) = z_{\text{base}}(t) + A_z \cdot \cos(\omega_z \cdot t + \phi_z)$$
    Onde $A_y \approx 14.0\text{px}$, $A_z \approx 10.0\text{px}$ e $\omega \approx 18.0\text{ rad/s}$.
  - A bola oscila para os lados e afunda repentinamente nos últimos $0.15\text{s}$ antes do solo, dificultando a previsão do retículo de queda.
* **Feedback Visual & Áudio (Juice):**
  - A bola não gira (ângulo visual estático no ar).
  - Trilha visual de ar transparente ondulada.
  - Som oco de toque seco ("TOC").
  - Popup visual `"SAQUE FLUTUANTE!"`.

---

## 5. Correção Preventiva & Estabilidade (Zero Null Pointer Exceptions)

### 5.1. Diagnóstico da Exceção
* **Erro Alvo:** `TypeError: null: type 'Null' is not a subtype of type 'String'`
* **Origem Comum em Flutter Web / Flame:**
  - Interpolação de Strings nulas em textos de HUD e placar (`teams[t].name`, `countryName`).
  - Chamadas de Web Audio API passando strings nulas ou valores indefinidos em `trackNames[currentTrack]`, `osc.type` ou labels de áudio.
  - Textos de popups criados com strings nulas no callback de finalização de golpe.
  - Widgets de bandeira (`FlagRenderer.flagWidget`) recebendo nome nulo ou inválido em partidas versus / dois jogadores.
* **Regras Estritas de Implementação Preventiva:**
  1. Todo getter, parâmetro e interpolador de String no HUD, nos popups e no áudio deve possuir fallback seguro com operador null-coalescing:
     ```dart
     final safeName = (team.name.isNotEmpty) ? team.name : 'TIME';
     final safeLabel = (eval.label.isNotEmpty) ? eval.label : 'BOM';
     final safeTrack = ArcadeAudio.currentTrackName.isNotEmpty ? ArcadeAudio.currentTrackName : 'Trilha Padrão';
     ```
  2. Em `FlagRenderer`, o método `flagWidget(String? countryName)` deve aceitar string anulável e normalizar com `countryName ?? 'BRASIL'`.
  3. No gerenciador de áudio (`ArcadeAudio`), o array de trilhas e nomes deve usar índice com proteção circular `trackNames[idx.clamp(0, trackNames.length - 1)]`.

---

## 6. Critérios de Aceitação da Spec

1. **Ataques:** Implementação funcional e verificada via testes de Monster Spike, Largadinha, Quick Attack e Pipe Attack.
2. **Defesas:** Implementação funcional e verificada de Peixinho com micro-slowdown e partículas, Bloqueio Toco na fita e Recuperação fora da quadra.
3. **Saques:** Mini-barra visual de timing no Saque Viagem e oscilação senoidal sem rotação no Saque Flutuante.
4. **Estabilidade:** Ausência absoluta de `TypeError` ou crashes em todas as resoluções e modos de jogo.
5. **Testes:** 100% dos testes unitários e de integração passando (`flutter test`).
6. **Compilação:** `flutter build web --release` com código 0 e sem warnings no analisador.
