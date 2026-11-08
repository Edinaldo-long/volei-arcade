# Spec: Melhoria de Gameplay & Game Feel — Vôlei Flutter/Flame

## 1. Visão Geral
Transformar a dinâmica de toque, salto, cortada e recepção para entregar impacto, física responsiva da bola e ritmo esportivo empolgante.

## 2. Pilares de Mecânica e Física
- **Física da Bola:**
  - Trajetória parabólica ajustada com gravidade realista e efeito de rotação (topspin).
  - Variação de velocidade e ângulo conforme o timing e o ponto de contato do jogador.
- **Mecânica de Toques & Posição:**
  - Sistema de 3 toques por time (Recepção/Manchete -> Levantamento -> Cortada/Ataque).
  - Indicador visual no chão do ponto de queda previsto da bola (*shadow/target reticle*).
  - Salto sincronizado para bloqueio na rede e cortadas aéreas.

## 3. Game Feel & Efeitos (Juice)
- **Impacto & Hitstop:**
  - Micro-pausa (freeze frame de 40ms a 70ms) no instante exato de uma cortada potente (*spike*).
  - Leve Screen Shake proporcional à força do ataque.
- **Efeitos Visuais:**
  - Rastro dinâmico na bola ao ser golpeada em velocidade máxima (streak/trail).
  - Partículas de poeira/impacto no piso da quadra e deformação sutil da bola no impacto (squash & stretch).
- **Feedback de Timing:**
  - Feedback visual e sonoro de qualidade do toque: "PERFEITO", "BOM", "TARDE/CEDO".

## 4. Critérios de Aceitação
1. A bola não deve parecer leve/flutuante nem cair de forma abrupta e não natural.
2. Controles fluidos para posicionamento rápido do jogador sob a bola.
3. IA oponente com tempos de reação ajustáveis e tomadas de decisão coerentes.