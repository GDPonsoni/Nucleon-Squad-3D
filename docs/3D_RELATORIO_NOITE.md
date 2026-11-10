# Relatório da execução do PLANO_3D (2026-11-10)

**T0 a T12 concluídas**, com push na branch `feat/3d-render`. A execução foi interrompida uma vez por limite de uso (depois da T9) e retomada. Nenhuma tarefa falhou nem foi revertida. O que falta e as limitações: `docs/3D_PENDENCIAS.md`.

## Resultado

| Tarefa | Estado | Commit |
|---|---|---|
| T0 Preparação e linha de base | feita | `99f9277` |
| T1 Esqueleto (câmera, luz, chão, camada 2D no plano) | feita | `6f01a62` |
| T2 Mapeamento e câmera, com testes | feita | `16dc495` |
| T3 Malhas low poly, com testes | feita | `c57c42d` |
| T4 Jogador, auxiliar, troca e quebra de corpo | feita | `cc8fb1f` |
| T5 Inimigos, rochas e elites | feita | `feb890c` |
| T6 Projéteis em MultiMesh | feita | `5fb36af` |
| T7 Chefes | feita | `a2543a5` |
| T8 Power-ups, kits, baús e orbes | feita | `2198ebc` |
| T9 Efeitos de chão que afetam a jogabilidade | feita (pela camada 2D no plano, D1) | `b5aad28` |
| T10 Destaque do tutorial pela projeção | feita | `2c4ecd2` |
| T11 Prova de equivalência | feita: **18 fases idênticas ao 2D** | `f6e71b5` |
| T12 Documentação e APK | feita; **APK não instalado** (sem aparelho no adb) | este commit |
| T13 Cenário, T14 Partículas | ver `docs/3D_PENDENCIAS.md` | |

## O que você vai ver

- Câmera a 70°, atrás da nave, com perspectiva leve. A área de jogo cabe inteira acima da barra de troca; a câmera desliza até 60 px acompanhando a nave.
- Chão em grade com estrelas fracas rolando, na cor do planeta.
- Naves, inimigos, rochas, chefes, tiros, power-ups, kits, baús e orbes de XP em modelos low poly facetados, gerados dos dados do jogo.
- Avisos, feixes, escudos, auras, explosões e números de dano deitados no plano de jogo, alinhados com a colisão.
- HUD, pausa, menus, esquadrão e inspeção de nave iguais ao 2D.

## O que mudou em relação ao plano

Tudo em `docs/3D_DECISOES.md`. As principais:

- **D1:** os efeitos de chão não foram refeitos um a um. A camada 2D inteira do jogo é mostrada como textura no plano de jogo, então o aviso fica exatamente onde a colisão acontece. Era a tarefa de maior risco (T9) e deixou de ser.
- **D4:** a simulação 2D original **não é determinística** (o áudio usa o relógio real e consome o sorteio global). O simulador ganhou `--deterministic` para a prova valer.
- **D3:** seguimento da câmera com máximo de 60 px em vez de 120 (com 120 o jogo ficaria 18% menor na tela).
- **D2:** a guarda do desenho 2D é `Renderer3D.active`, não `Params.render_3d`, para a tela de inspeção de nave continuar funcionando.
- **D8:** sem cockpit separado; o núcleo (hitbox) é o domo claro da nave.

## Testes

- Suíte completa verde no commit da T10: `validate_project` (0 erros), `run_tests` (3652 verificações, eram 865), `ui_smoke`, `match_regressions`, `boss_regressions`, `run_regressions` e o novo `render3d_regressions`, todos com 0 falhas.
- `pager_regressions`: as mesmas 4 falhas que já existiam na versão 2D (registradas em `docs/3D_BASELINE.md`).
- Equivalência: capítulos 1 e 5 com `--deterministic` idênticos ao 2D original, linha por linha.
- Orçamento de triângulos conferido por teste: até 60 por nave e inimigo, 300 por chefe, 24 por projétil.
- **Não testado:** nada no S24. FPS, legibilidade e controle só o aparelho responde.

## O que testar no S24

Roteiro completo em `docs/3D_TESTE.md`. O essencial:

1. Instale: `~/Android/Sdk/platform-tools/adb install -r builds/nucleon-squad-3d.apk` (app "Nucleon Squad 3D", ao lado do 2D, com save próprio).
2. Jogue a 1-1: dá para ler os tiros e achar o núcleo? A câmera incomoda?
3. Jogue um chefe (1-5 ou 1-9): os avisos aparecem a tempo e no lugar certo?
4. Jogue a 5-8 com as estatísticas ligadas: o FPS segura? Se não, `ground_fx_resolution = 0.5` em `params.gd`.

## Dados sensíveis

Conferido antes de cada commit: nenhum APK, keystore, senha ou token foi para o repositório (`builds/` e keystores seguem no `.gitignore`).
