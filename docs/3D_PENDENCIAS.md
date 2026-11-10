# Pendências da versão 3D e ponto de retomada

Atualizado em 2026-11-10, ao parar por **limite de uso** no meio do Marco 4.

## Onde parou

- **Feito e commitado (branch `feat/3d-render`):** T0 a T9.
- **Próxima tarefa: T10.** Depois T11, T12 e, se sobrar cota, T13 e T14.

## O que falta

### T10 — sobreposições 2D que dependem da posição na tela (NÃO FEITA)
- `scripts/tutorial/tip_spotlight.gd`, função `_target_rect`: usa `node.global_position` (posição 2D do jogo) como se fosse posição de tela. Na visão 3D o recorte iluminado da dica fica **deslocado** do alvo (pouco no centro, mais nas bordas e no topo). Trocar por `renderer.project_rect(pos, raio)` quando houver `Renderer3D` (o `game.gd` pode passar um `Callable` ao `TipSpotlight`).
- `scripts/core/game.gd`, `_tip_highlight_rect("player")`: mesmo problema, mesma solução.
- Números de dano, barra de vida de elite e segmentos de saúde da nave **não precisam** de mudança: são desenhados na camada 2D do plano de jogo e já acompanham a perspectiva.

### T11 — prova de equivalência (PARCIAL)
- Já medido à mão: `p1_s1` com `--deterministic` dá a mesma linha com 3D, com `--render2d` e na referência D do `docs/3D_BASELINE.md`.
- Falta rodar os capítulos 1 e 5 inteiros e comparar com a tabela D:
  `$G --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- --chapter N --level 1 --seed 1 --deterministic`

### T12 — documentação e build (NÃO FEITA)
- Atualizar `docs/ESTADO_ATUAL.md` (caminho do repo, pacote `com.example.nucleonsquad3d`, APK `builds/nucleon-squad-3d.apk`, seção da visão 3D, teste novo `tests/render3d_regressions_run.gd`) e o `README.md`.
- Criar `docs/3D_TESTE.md` (roteiro no S24; resumo na seção 8 do plano).
- Exportar: `timeout 300 $G --headless --path . --export-debug "Android" builds/nucleon-squad-3d.apk` e instalar só se `adb devices` listar o aparelho. **Nenhum APK 3D foi gerado ainda.**

### T13 e T14 — cenário e partículas (NÃO FEITAS)

## Limitações conhecidas do que já está pronto

- **Nada foi testado no S24.** O visual foi conferido só por fotos no PC (`scripts/tools/shot_3d.gd`), em janela de 540 px de largura.
- **FPS no aparelho não medido.** Custos novos: uma textura do tamanho da tela por quadro (`ground_fx_resolution`) e a atualização por script de cada projétil. No PC ficou em 58 a 60 FPS.
- **Controle:** o arraste do dedo continua em px do jogo; com a perspectiva, a nave anda um pouco menos que o dedo no fundo da tela.
- **Efeitos ainda planos** (deitados no plano de jogo, sem volume): explosões, faíscas, raio, Tesla, órbita, especiais, avisos, escudos e auras. É o previsto para antes da T14.
- **Seguimento da câmera** em 60 px, não 120 (ver D3 em `docs/3D_DECISOES.md`).
