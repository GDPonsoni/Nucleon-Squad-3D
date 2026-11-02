# Marco 0 — Como testar

Protótipo mínimo: menu inicial, nave com controle relativo, tiro automático com pooling, câmera lenta ao soltar o dedo, pausa e overlay de FPS.

## 1. Abrir o projeto

- Godot usado: **4.7.2 stable** (`../Godot_v4.7.2-stable_linux.x86_64`, ao lado da pasta do projeto).
- Abrir o editor: `../Godot_v4.7.2-stable_linux.x86_64 --path . -e`
- Rodar no PC (sem editor): `../Godot_v4.7.2-stable_linux.x86_64 --path .`
  - Janela de 540×960 (metade de 1080×1920). O **mouse emula toque**: segurar o botão esquerdo = dedo na tela.
- Validar scripts sem abrir janela: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit`

## 2. Exportar e rodar no S24

Pré-requisitos (já configurados nesta máquina): templates de exportação 4.7.2, Android SDK em `~/Android/Sdk`, JDK 17 e keystore de debug nas configurações do editor. O S24 precisa estar com **depuração USB** ativa.

**Pelo editor (mais simples):** com o celular conectado, clicar no ícone do Android no canto superior direito ("Remote Debug / One-click deploy"). O Godot instala e abre o app.

**Pelo terminal:**

```bash
# exportar APK de debug
../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --export-debug "Android" builds/nucleon-squad.apk

# instalar e abrir
~/Android/Sdk/platform-tools/adb install -r builds/nucleon-squad.apk
~/Android/Sdk/platform-tools/adb shell monkey -p com.example.nucleonsquad 1
```

O overlay de FPS só aparece em build de **debug** (`--export-debug`).

## 3. O que observar

**Menu e pausa**
- O app abre no **menu inicial** (Jogar / Sair), em português se o celular estiver em PT-BR e em inglês nos outros idiomas.
- **Jogar** entra na partida. O botão **II** (canto superior direito) pausa e mostra **Continuar** / **Recomeçar fase** / **Voltar ao menu**.
- Tocar no **II** não deve mexer a nave nem tirar a câmera lenta antes de pausar.
- **Continuar** retoma em câmera lenta (o dedo está solto). O próximo toque volta à velocidade normal.
- **Botão Voltar do Android:** na partida abre e fecha a pausa; no menu fecha o jogo. No PC, o **Esc** faz o mesmo.
- Entrar e sair da partida várias vezes: a nave sempre recomeça embaixo e no centro, e o FPS não cai.

**Arraste relativo**
- Tocar em qualquer lugar (inclusive longe da nave) e arrastar: a nave deve se mover o mesmo tanto que o dedo, sem "pular" para o dedo.
- Levar a nave até a borda e continuar arrastando: ela para na borda. Ao voltar o dedo, ela deve responder **imediatamente** (sem zona morta).
- Sensação: atraso perceptível? A nave fica "pesada" ou "escorregadia"? Ajustar `drag_sensitivity` e `ship_speed` em `scripts/core/params.gd`.

**Câmera lenta**
- O jogo **começa em câmera lenta** (ainda não há dedo na tela). Ao tocar, volta a 1.0.
- Soltar o dedo: tiros e cadência desaceleram para 30% em ~0,1 s; tocar de novo em qualquer lugar volta ao normal.
- Observar se a transição parece suave ou brusca demais (`time_scale_smooth_seconds`) e se 0,3 é lento o bastante (`slow_time_scale`).
- Puxar a cortina de notificações com o dedo na tela: o jogo deve entrar em câmera lenta (perda de foco conta como soltar).

**Desempenho**
- FPS no canto superior esquerdo: alvo **60 estável** (o S24 pode chegar a 120 se a tela estiver em 120 Hz; anotar qual valor aparece).
- Anotar se o FPS cai ao arrastar rápido ou ao alternar a câmera lenta várias vezes.

## Parâmetros (`scripts/core/params.gd`)

| Parâmetro | Valor inicial | Efeito |
|---|---|---|
| `slow_time_scale` | 0.3 | velocidade do jogo com o dedo solto |
| `time_scale_smooth_seconds` | 0.1 | duração da transição (tempo real) |
| `ship_speed` | 3000 px/s | velocidade máxima da nave seguindo o dedo |
| `drag_sensitivity` | 1.0 | quanto a nave anda por pixel de dedo |
| `fire_rate` | 10 tiros/s | cadência do tiro automático |
| `bullet_speed` | 2200 px/s | velocidade do projétil |
| `bullet_pool_size` | 64 | projéteis pré-criados no pool |
