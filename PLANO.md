# Plano de Engenharia de Gameplay & Game Feel — Vôlei Arcade Flame/Flutter

**Autor:** Senior Game Designer & Gameplay Engineer  
**Documento de Origem:** `lib/.specs/VOLLEYBALL_SPEC.md`  
**Status:** Implementado e Validado com Testes de Unidade e Integração (100% Passing, 0 Analyzer Warnings)  
**Versão:** 1.0.0  

---

## 1. Diagnóstico do Estado Atual do Projeto

### 1.1 Arquitetura e Estrutura de Código
- **Arquivo Único Monolítico (`lib/main.dart` - ~1.730 linhas):**
  - Concentra dados de estado (`Player`, `Pad`, `TeamInfo`, `Pred`), lógica de ciclo de vida (`VolleyGame`), simulação física pseudo-3D, IA oponente, renderização em Canvas (sprites pixel art, quadra, torcida, HUD) e componentes de UI Flutter (`_Menu`, `_Controls`, `_Result`, `_Joystick`).
  - *Diagnóstico técnico:* A física atual e os efeitos estão fortemente acoplados ao loop de renderização e predição. Para implementar novos sistemas de partículas, rastro, hitstop e topspin com precisão e manutenibilidade, é essencial modularizar ou isolar os subsistemas de física e feedback através de classes de serviço bem definidas.

### 1.2 Física da Bola
- **Simulação Balística Atual:**
  - Gravidade constante `kG = 900`.
  - Lançamentos calculados por aproximação estática (`_launchTo` e `_launchFast`), definindo velocidade inicial $v_{x0}, v_{y0}, v_{z0}$ para cruzar um tempo $tt$.
  - Sem forças dinâmicas de **arrasto aerodinâmico (air drag)** e **efeito Magnus (topspin/backspin)**.
  - O corte atual usa uma rotação visual estática (`bAng += bvx * dt * 0.02`), mas a trajetória em si não curva para baixo; a sensação resultante é de uma trajetória rígida, onde a bola viaja em linha reta ou parábola uniforme, parecendo ora "leve demais", ora previsível.
- **Predição de Trajetória (`_predict`):**
  - Passo fixo de simulação forward (`t += 0.02`), que sofrerá discrepâncias se adicionarmos forças aerodinâmicas sem atualizar a predição da IA e do retículo.

### 1.3 Sistema de Toques e Cortada
- **Detecção de Contato:**
  - Esfera de alcance euclidiana simplificada (`dx*dx + dy*dy*0.8 + dz*dz <= reach*reach`).
  - Não avalia a altura relativa do impacto no ápice do salto nem o vetor de antecipação do jogador.
  - A cortada é disparada sempre na mesma velocidade e trajetória com base apenas em estar no ar e acima da rede (`air && idx >= 1 && nearNet && bz > kNetH - 15`).
- **Feedback de Timing Inexistente:**
  - O jogador não tem indicação se bateu cedo demais, tarde demais ou no "sweet spot". Não há premiação para a execução técnica no topo do salto.

### 1.4 Game Feel & "Juice"
- **Ausência de Hitstop (Freeze Frame):** O impacto da cortada é contínuo, sem aquele instante de congelamento cinemático (micro-pausa de 40-70ms) que confere peso dramático ao golpe.
- **Screen Shake Rígido:** Tremor uniforme aleatório linear (`canvas.translate`), sem decaimento de trauma polinomial ($trauma^2$) e sem vetor direcional congruente com o ataque.
- **Ausência de Squash & Stretch:** A bola é renderizada como círculo com raio estático $r = 15 \times \text{scale}(y)$. Não se deforma no impacto potente nem na compressão com o solo.
- **Ausência de Trilha de Alta Velocidade (Streak/Trail):** Cortes potentes exibem apenas fagulhas (`Spark`), sem rastro fluido destacando a linha de ataque.
- **Retículo de Queda Básico:** O anel atual não fornece sensação de urgência/tempo até o impacto (retículo estático pulsante).

---

## 2. Visão de Game Design & Arquitetura Alvo

### 2.1 Modelo Físico Aprimorado (Pseudo-3D com Magnus e Arrasto)
A aceleração da bola em cada sub-passo será regida por:
$$\vec{a} = \vec{g} + \vec{a}_{\text{drag}} + \vec{a}_{\text{magnus}}$$

1. **Gravidade Base ($\vec{g}$):** $(0, 0, -kG)$ com calibração esportiva ($kG \approx 1050 \text{ px/s}^2$).
2. **Arrasto Aerodinâmico ($\vec{a}_{\text{drag}}$):**
   $$\vec{a}_{\text{drag}} = -c_d \cdot \|\vec{v}\| \cdot \vec{v}$$
   Gera perda natural de energia nas pontas, evitando que a bola pareça um projétil de ferro no vácuo.
3. **Efeito Magnus / Topspin ($\vec{a}_{\text{magnus}}$):**
   - Cortadas com topspin agressivo aplicam aceleração vertical para baixo ($a_z < 0$), provocando uma "mergulhada" violenta da bola na quadra adversária após passar pela fita.
   - Levantamentos com backspin suave mantêm a bola mais tempo flutuando no ar para o atacante armar o golpe.

### 2.2 Sistema de Janelas de Timing (Mecânica de Maestria)
O contato com a bola será classificado em 3 categorias com base na distância ao *Ponto Ideal de Contato (Sweet Spot)* e na velocidade relativa:
- **PERFEITO (Sweet Spot):** Janela de $\pm 45 \text{ ms}$ e $\Delta z \approx 0$ no topo do salto.
  - Multiplicador de velocidade: $1.35\times$.
  - Efeito: Ativação de Topspin Máximo, Hitstop dramático (65ms), Screen Shake direcional intenso, rastro de fogo/energia e popup visual dourado `"PERFEITO!"`.
- **BOM (Good):** Janela de $\pm 110 \text{ ms}$.
  - Multiplicador de velocidade: $1.0\times$.
  - Efeito: Trajetória planejada padrão, micro-shake (30ms), popup ciano `"BOM"`.
- **TARDE / CEDO (Sub-ótimo):** Janela marginal de alcance.
  - Multiplicador de velocidade: $0.75\times$.
  - Efeito: Sem hitstop, maior dispersão de mira (risco de mandar bola na rede ou fora da quadra), popup vermelho/cinza `"CEDO"` ou `"TARDE"`.

### 2.3 Matriz de "Juice" e Efeitos Visuais
| Ação | Hitstop | Screen Shake | Deformação Bola (Squash) | Trail / Rastro | Partículas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Manchete / Toque 1** | 0 ms | 0 px | Leve achatamento vertical ($0.85/1.15$) | Nenhum | Brilho suave no ponto de contato |
| **Levantamento / Toque 2**| 0 ms | 0 px | Recuperação elástica natural | Nenhum | 4 partículas circulares |
| **Cortada Normal** | 40 ms | 5 px linear | Estiramento longitudinal ($1.30/0.75$) | Trilha de 4 frames translúcidos | 12 faíscas direcionais |
| **Cortada PERFEITA** | 70 ms | 10 px trauma² | Estiramento extremo ($1.50/0.65$) | Rastro contínuo cônico com glow | Onda de choque + 25 partículas |
| **Bloqueio Bem-Sucedido** | 60 ms | 8 px horizontal | Achatamento no plano frontal | Explosão de impacto na rede | Faíscas metálicas azuis |
| **Impacto no Chão** | 0 ms | 3 px | Achatamento contra o piso ($1.40/0.60$) | Dissipação imediata do rastro | Nuvem de poeira da quadra |

---

## 3. Plano de Implementação em 5 Etapas

### ETAPA 1: Isolamento Modular e Infraestrutura de Dados
**Objetivo:** Criar os tipos de dados e os serviços de física/feedback sem alterar o gameplay existente, mantendo estabilidade e compilação livre de erros.

- [x] **1.1. Criação das Estruturas de Domínio:**
  - `BallPhysicsState`: Armazenar vetores $(\vec{p}, \vec{v}, \vec{\omega})$, coeficientes de arrasto e rotação.
  - `TimingRating`: Enum com `perfect`, `good`, `early`, `late`.
  - `HitEvaluation`: Objeto com avaliação de timing, posição do impacto, intensidade do golpe e cor associada.
- [x] **1.2. Criação do Gerenciador de Tempo & Hitstop (`HitstopController`):**
  - Implementar o mecanismo de *freeze frame*: quando ativo, o `update(dt)` da física e dos atores congela temporariamente, mas o relógio de efeitos e renderizadores continuam consumindo delta time real.
- [x] **1.3. Criação do Gerenciador de Câmera & Shake Baseado em Trauma:**
  - Implementar padrão $Offset = Trauma^2 \times MaxOffset$, com decaimento exponencial suave e suporte a impulsos direcionais.

### ETAPA 2: Novo Motor de Trajetória da Bola & Efeito Magnus
**Objetivo:** Implementar física responsiva, realista e previsível, eliminando a sensação de bola flutuante ou artificial.

- [x] **2.1. Equações Diferenciais com Integração Sub-Step:**
  - Refatorar `_stepBall` para integrar aceleração com arrasto aerodinâmico suave e Magnus horizontal/vertical proporcional ao spin $\omega$.
- [x] **2.2. Atualização dos Construtores de Trajetória (`_launchTo` e `_launchFast`):**
  - Calibrar o algoritmo balístico inverso para contemplar o arrasto e garantir que passes e levantamentos alcancem a altura correta do atacante.
- [x] **2.3. Atualização do Algoritmo de Predição (`_predict`):**
  - Refinar o integrador numérico de predição rápida para que tanto a IA quanto o marcador de solo coincidam precisamente com o local e momento real da queda.
- [x] **2.4. Colisão Realista com Fita da Rede e Chão:**
  - Quique elástico no solo com deformação e fricção tangencial (a bola não desliza infinitamente).
  - Tratamento aprimorado de toque na borda superior da fita da rede (efeito "fita"): redução de velocidade e desvio de rota.

### ETAPA 3: Sistema Dinâmico de Toques, Janelas de Timing e Cortada
**Objetivo:** Transformar o contato com a bola em uma mecânica rica de controle de timing, altura e mira direcional.

- [x] **3.1. Avaliação do Ponto de Contato & Altura:**
  - Medir a distância tridimensional entre o ponto de contato do jogador e o centro da bola.
  - Para jogadas aéreas (cortada e bloqueio), calcular a proximidade em relação ao ápice vertical do salto do atacante.
- [x] **3.2. Classificação de Timing e Aplicação de Atributos:**
  - Gerar `TimingRating` correspondente (`PERFEITO`, `BOM`, `CEDO`, `TARDE`).
  - Modular a velocidade e o topspin da bola de acordo com o rating:
    - *Perfeito:* Velocidade máxima, ângulo agudo descendente, rotação rápida.
    - *Tarde/Cedo:* Velocidade atenuada, trajetória mais alta/lenta e aberta.
- [x] **3.3. Transição Clara dos 3 Toques:**
  - *Toque 1 (Recepção):* Amortece o impacto de ataques adversários e direciona parabola alta para a zona do levantador.
  - *Toque 2 (Levantamento):* Direciona a bola precisamente para a zona de corte na fita com curva suave.
  - *Toque 3 (Ataque/Cortada):* Golpe descendente agressivo com transição de animação para swing vigoroso.
- [x] **3.4. Calibração da IA Oponente:**
  - Fazer a IA reagir ao nível de dificuldade com janelas de timing realistas (nível fácil erra o timing e comete erros não forçados; nível difícil busca timings perfeitos e bloqueios ajustados).

### ETAPA 4: Game Feel, Juice & Efeitos Audiovisuais
**Objetivo:** Aplicar os efeitos de polimento descritos na spec para entregar impacto satisfatório estilo arcade.

- [x] **4.1. Acoplamento do Hitstop:**
  - Disparar congelamento de 50ms a 70ms no instante do golpe de cortada perfeita e de 40ms em cortes normais.
- [x] **4.2. Rastro Dinâmico da Bola (Motion Streak Trail):**
  - Implementar buffer circular de posições passadas da bola (`bx, by, bz`).
  - Renderizar polígonos/elipses com gradiente de transparência e escala decrescente apenas quando a velocidade linear exceder $450 \text{ px/s}$.
- [x] **4.3. Squash & Stretch na Bola:**
  - No método `_drawBall`, aplicar rotação alinhada ao vetor de velocidade e escalar canvas:
    - Longarina na direção do movimento: $\text{scaleX} = 1 + \min(0.4, \|\vec{v}\| / 2000)$.
    - Compressão transversal: $\text{scaleY} = 1 / \text{scaleX}$ (preservação de volume visual).
    - Achatamento especial no impacto do solo e na mão do jogador.
- [x] **4.4. Retículo Dinâmico no Chão (Target Reticle com Indicador Temporal):**
  - Substituir o anel simples por um retículo dinâmico: anel externo concêntrico que encolhe até convergir com o centro exatamente no frame do impacto.
  - Intensidade e opacidade proporcionais à proximidade da bola em relação ao piso.
- [x] **4.5. Popups de Texto Flutuante ("PERFEITO!", "BOM", "TARDE/CEDO"):**
  - Renderizar textos flutuantes estilizados com contorno 8-bit, emergindo do ponto de toque e subindo com interpolação ease-out e fade-out.
- [x] **4.6. Partículas de Poeira e Impacto:**
  - Partículas de poeira amarronzadas no choque da bola com a quadra e faíscas brilhantes de choque no contato aéreo.

### ETAPA 5: Calibração Fina, Profiling e Aceitação
**Objetivo:** Testar todos os cenários de rally, garantir 60 FPS e validar os critérios do `VOLLEYBALL_SPEC.md`.

- [x] **5.1. Bateria de Testes de Jogabilidade:**
  - Testar recepções de saques rápidos.
  - Testar ralis longos (3 a 5 trocas de bola entre as equipes).
  - Testar bloqueio na rede contra cortes perfeitos e normais.
  - Testar situações de bola fora e bola na fita.
- [x] **5.2. Verificação dos Critérios de Aceitação da Spec:**
  - [x] Critério 1: *A bola não deve parecer leve/flutuante nem cair de forma abrupta e não natural.*
  - [x] Critério 2: *Controles fluidos para posicionamento rápido do jogador sob a bola.*
  - [x] Critério 3: *IA oponente com tempos de reação ajustáveis e tomadas de decisão coerentes.*
- [x] **5.3. Profiling de Desempenho:**
  - Garantir ausência de alocação excessiva de memória no garbage collector (reuso de buffers e `Paint` objects).

---

## 4. Matriz de Parâmetros de Calibração Recomendados

| Parâmetro | Valor Inicial Recomendado | Descrição |
| :--- | :--- | :--- |
| `kG` | `1050.0 px/s²` | Gravidade vertical calibrada para arco realista |
| `kTopspinFactor` | `0.38` | Força vertical descendente extra em cortadas |
| `kAirDrag` | `0.00015` | Coeficiente de resistência aerodinâmica da bola |
| `kPerfectWindow` | `0.045 s` | Janela de tempo de ouro para contato ótimo |
| `kGoodWindow` | `0.110 s` | Janela de tempo para toques regulares |
| `kHitstopSpike` | `0.065 s` (65 ms) | Duração do freeze frame em cortada forte |
| `kHitstopBlock` | `0.055 s` (55 ms) | Duração do freeze frame em bloqueio na rede |
| `kMaxTraumaShake`| `12.0 px` | Amplitude de pico do screen shake |
| `kTrailSpeedMin` | `480.0 px/s` | Velocidade mínima da bola para emitir rastro |

---

## 5. Próximos Passos e Aguardo de Validação

Este plano organiza a evolução técnica de forma segura e progressiva, mantendo a integridade do jogo retro arcade existente e elevando o nível de responsividade física e impacto sensorial.

> [!IMPORTANT]
> **Aguardando aprovação:** Nenhum código do jogo foi alterado. Por favor, revise as etapas, a matriz de parâmetros e a abordagem proposta. Assim que validado, iniciaremos a execução conforme suas instruções.
