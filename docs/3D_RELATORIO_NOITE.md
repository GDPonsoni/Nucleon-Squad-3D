# Relatório da execução do PLANO_3D (2026-11-10)

**O plano inteiro foi concluído: T0 a T14**, com push na branch `feat/3d-render`. A execução foi interrompida uma vez por limite de uso (depois da T9) e retomada. Nenhuma tarefa foi revertida. Limitações e o que depende do teste no aparelho: `docs/3D_PENDENCIAS.md`.

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
| T12 Documentação e APK | feita; **APK não instalado** (sem aparelho no adb) | `b770834` |
| T13 Cenário de fundo | feita | `e2f24f0` |
| T14 Partículas | feita (refeita uma vez, ver abaixo) | `bebf885` |

O APK em `builds/nucleon-squad-3d.apk` foi exportado de novo depois da T14 (inclui cenário e partículas).

## O que você vai ver

- Câmera a 70°, atrás da nave, com perspectiva leve. A área de jogo cabe inteira acima da barra de troca; a câmera desliza até 60 px acompanhando a nave.
- Chão em grade com estrelas fracas rolando, na cor do planeta.
- Naves, inimigos, rochas, chefes, tiros, power-ups, kits, baús e orbes de XP em modelos low poly facetados, gerados dos dados do jogo.
- Avisos, feixes, escudos, auras, explosões e números de dano deitados no plano de jogo, alinhados com a colisão.
- Rochas e planetoides escuros passando por baixo do plano de jogo.
- Estilhaços nas explosões, fagulhas nos acertos, rastro do propulsor e brilho ao coletar item.
- HUD, pausa, menus, esquadrão e inspeção de nave iguais ao 2D.

## O que mudou em relação ao plano

Tudo em `docs/3D_DECISOES.md`. As principais:

- **D1:** os efeitos de chão não foram refeitos um a um. A camada 2D inteira do jogo é mostrada como textura no plano de jogo, então o aviso fica exatamente onde a colisão acontece. Era a tarefa de maior risco (T9) e deixou de ser.
- **D4:** a simulação 2D original **não é determinística** (o áudio usa o relógio real e consome o sorteio global). O simulador ganhou `--deterministic` para a prova valer.
- **D3:** seguimento da câmera com máximo de 60 px em vez de 120 (com 120 o jogo ficaria 18% menor na tela).
- **D2:** a guarda do desenho 2D é `Renderer3D.active`, não `Params.render_3d`, para a tela de inspeção de nave continuar funcionando.
- **D8:** sem cockpit separado; o núcleo (hitbox) é o domo claro da nave.
- **D12:** as partículas não usam `GPUParticles3D`. São próprias, num `MultiMesh`.

## O que deu errado no caminho

- **Partículas (T14):** a primeira versão, com `GPUParticles3D` como o plano sugeria, passou em toda a suíte mas **mudou a simulação** (capítulo 1 diferente do 2D). A prova de equivalência pegou. Causa, confirmada num teste isolado: criar um `GPUParticles3D` ou `CPUParticles3D` consome o sorteio global do motor. Foi refeita com partículas próprias e a equivalência voltou.
- **Cor dos efeitos no plano (T13):** efeitos translúcidos saíam escuros (conversão de cor sobre alfa pré-multiplicado). Visto nas fotos, corrigido no shader.
- **Teto de partículas:** um teste pegou o teto sendo estourado em 7 partículas com parâmetros exagerados. Corrigido (o teto agora é rígido).
- **Um teste meu estava errado:** dar 100000 de vida à nave fazia a barra de troca desenhar 100000 marcas por quadro. O teste foi corrigido; o jogo não tinha defeito.

## Testes

- Suíte completa verde no commit da T14: `validate_project` (0 erros), `run_tests` (3773 verificações, eram 865), `ui_smoke`, `match_regressions`, `boss_regressions`, `run_regressions` e o novo `render3d_regressions`, todos com 0 falhas.
- `pager_regressions`: as mesmas 4 falhas que já existiam na versão 2D (registradas em `docs/3D_BASELINE.md`).
- Equivalência: capítulos 1 e 5 com `--deterministic` idênticos ao 2D original, linha por linha. Rodada depois da T10 e de novo depois da T14.
- FPS no PC (Radeon integrada, janela de 540 px, sem vsync): chefe 5-9 a 191 quadros/s; fase 5-8 a 143 em 3D contra 174 em 2D.
- Orçamento de triângulos conferido por teste: até 60 por nave e inimigo, 300 por chefe, 24 por projétil.
- **Não testado:** nada no S24. FPS, legibilidade e controle só o aparelho responde.

## O que testar no S24

Roteiro completo em `docs/3D_TESTE.md`. O essencial:

1. Instale: `~/Android/Sdk/platform-tools/adb install -r builds/nucleon-squad-3d.apk` (app "Nucleon Squad 3D", ao lado do 2D, com save próprio).
2. Jogue a 1-1: dá para ler os tiros e achar o núcleo? A câmera incomoda?
3. Jogue um chefe (1-5 ou 1-9): os avisos aparecem a tempo e no lugar certo?
4. Jogue a 5-8 com as estatísticas ligadas: o FPS segura? Se não, `ground_fx_resolution = 0.5` em `params.gd`.
5. O cenário de fundo atrapalha a leitura dos tiros? As partículas aparecem?

## Dados sensíveis

Conferido antes de cada commit: nenhum APK, keystore, senha ou token foi para o repositório (`builds/` e keystores seguem no `.gitignore`).
