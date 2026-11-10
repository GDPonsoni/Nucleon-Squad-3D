# Linha de base da versão 2D (antes do 3D)

Medida em 2026-11-10, no commit `e542b67` (igual à versão 2D `73a6305` + o plano), Godot 4.7.2, headless, tela 1080×2340. Serve para provar que a visão 3D não mudou a simulação (T11 do `docs/PLANO_3D.md`).

## Suíte

| Comando | Resultado |
|---|---|
| `--headless --path . --quit` | sem `SCRIPT ERROR` nem `Parse Error` (só os avisos de saída abaixo) |
| `scripts/tools/validate_project.gd` | `validate_project: 243 arquivos, 0 com erro` |
| `tests/run_tests.gd` | `testes: 865 verificações, 0 falhas` |
| `tests/ui_smoke_run.gd` | `ui_smoke: 24 telas, 0 falhas de carga, 0 elementos fora da tela` |
| `tests/match_regressions_run.gd` | `match_regressions: 0 falhas` |
| `tests/boss_regressions_run.gd` | `boss_regressions: 0 falhas` |
| `tests/run_regressions_run.gd` | `run_regressions: 0 falhas` |
| `tests/pager_regressions_run.gd` | `pager_regressions: 4 falhas` (**já falhava**) |

**Falhas que já existiam (registradas, não consertadas):**

- `pager_regressions`: 4 falhas ("gesto rápido recua (cap 2)", "página acompanha o dedo (offset 0)", "voltar o dedo e soltar cancela", "toque simples no botão aciona a fase"). Já constavam no `docs/ESTADO_ATUAL.md`.
- Toda execução headless termina com avisos de saída do Godot (`ObjectDB instances were leaked at exit`, `resources still in use at exit`, e no `ui_smoke` também `RID allocations ... were leaked`). Não são erros de script.

## Simulação de fases (piloto automático)

Comando: `$G --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- --chapter N --level 1 --seed 1`

### Descoberta: a simulação 2D **não é determinística**

Duas execuções seguidas do capítulo 1 com a mesma semente deram resultados diferentes (tabelas A e B abaixo). Causa: `Audio.play` decide se toca pelo relógio real (`sfx_min_gap` com `Time.get_ticks_msec()`) e, quando toca, consome o sorteio global (`randf_range` do tom). Como o tempo real de cada quadro varia, a sequência de sorteios muda e as ondas saem diferentes. **Isso já acontece na versão 2D**; não foi consertado (seria mexer em lógica).

Consequência para a T11: comparar o 3D com as tabelas A/B só vale como **faixa** (a variação natural entre A e B já é de vários hits por fase). Para uma prova exata, o simulador ganhou a opção `--deterministic` (zera os sons só na ferramenta, sem tocar no jogo): com ela, duas execuções dão resultado **idêntico**. A tabela D é a referência exata.

### A. Capítulo 1, semente 1 (execução 1)

```
stage | result | time | boss_s | hits | hits/min | kills | score | bullets avg/max | enemies max | pool_full | levels
p1_s1 | clear | 304 | -1 | 11 | 2.2 | 607 | 8185 | 6/31 | 16 | 0 | [5, 1, 1, 1]
p1_s2 | clear | 304 | -1 | 19 | 3.7 | 592 | 8790 | 7/30 | 13 | 0 | [5, 1, 1, 1]
p1_s3 | clear | 304 | -1 | 15 | 3.0 | 649 | 9945 | 6/23 | 18 | 0 | [5, 1, 1, 1]
p1_s4 | clear | 304 | -1 | 19 | 3.7 | 660 | 9435 | 6/29 | 16 | 0 | [5, 1, 1, 1]
p1_s5 | clear | 257 | 39 | 20 | 4.7 | 512 | 8285 | 10/37 | 19 | 0 | [5, 1, 1, 1]
p1_s6 | clear | 304 | -1 | 15 | 3.0 | 739 | 11545 | 6/34 | 24 | 0 | [5, 1, 1, 1]
p1_s7 | clear | 309 | -1 | 28 | 5.4 | 738 | 9494 | 6/33 | 29 | 0 | [5, 1, 1, 1]
p1_s8 | clear | 308 | -1 | 25 | 4.9 | 905 | 12629 | 8/32 | 27 | 0 | [5, 1, 1, 1]
p1_s9 | clear | 264 | 55 | 22 | 5.0 | 532 | 9000 | 19/74 | 23 | 0 | [5, 1, 1, 1]
TOTAL | 9 fases | 44.4 min | 174 hits | 3.92 hits/min
```

### B. Capítulo 1, semente 1 (execução 2, mesmo comando)

```
p1_s1 | clear | 304 | -1 | 17 | 3.4 | 606 | 8155 | 6/29 | 16 | 0 | [5, 1, 1, 1]
p1_s2 | clear | 304 | -1 | 13 | 2.6 | 592 | 8790 | 7/27 | 13 | 0 | [5, 1, 1, 1]
p1_s3 | clear | 304 | -1 | 13 | 2.6 | 648 | 9995 | 6/22 | 17 | 0 | [5, 1, 1, 1]
p1_s4 | clear | 304 | -1 | 13 | 2.6 | 669 | 9575 | 6/25 | 17 | 0 | [5, 1, 1, 1]
p1_s5 | clear | 257 | 39 | 26 | 6.0 | 516 | 8335 | 10/36 | 16 | 0 | [5, 1, 1, 1]
p1_s6 | clear | 304 | -1 | 13 | 2.6 | 742 | 11620 | 6/32 | 25 | 0 | [5, 1, 1, 1]
p1_s7 | clear | 310 | -1 | 22 | 4.3 | 696 | 9142 | 5/29 | 29 | 0 | [5, 1, 1, 1]
p1_s8 | clear | 310 | -1 | 31 | 6.0 | 902 | 12623 | 8/34 | 31 | 0 | [5, 1, 1, 1]
p1_s9 | clear | 270 | 61 | 30 | 6.6 | 551 | 9325 | 20/76 | 23 | 0 | [5, 1, 1, 1]
TOTAL | 9 fases | 44.5 min | 178 hits | 4.00 hits/min
```

### C. Capítulo 5, semente 1

```
stage | result | time | boss_s | hits | hits/min | kills | score | bullets avg/max | enemies max | pool_full | levels
p5_s1 | clear | 310 | -1 | 86 | 16.6 | 332 | 6378 | 56/147 | 56 | 0 | [5, 1, 1, 1]
p5_s2 | clear | 310 | -1 | 98 | 19.0 | 386 | 6346 | 70/164 | 55 | 0 | [5, 1, 1, 1]
p5_s3 | clear | 310 | -1 | 72 | 13.9 | 328 | 4972 | 62/141 | 64 | 0 | [5, 1, 1, 1]
p5_s4 | clear | 310 | -1 | 95 | 18.4 | 304 | 5458 | 105/217 | 60 | 0 | [5, 1, 1, 1]
p5_s5 | clear | 287 | 68 | 62 | 13.0 | 249 | 5323 | 24/102 | 52 | 0 | [5, 1, 1, 1]
p5_s6 | clear | 310 | -1 | 88 | 17.0 | 321 | 7491 | 70/153 | 64 | 0 | [5, 1, 1, 1]
p5_s7 | clear | 310 | -1 | 100 | 19.4 | 235 | 4925 | 138/264 | 64 | 0 | [5, 1, 1, 1]
p5_s8 | clear | 310 | -1 | 117 | 22.6 | 370 | 5380 | 224/452 | 64 | 0 | [5, 1, 1, 1]
p5_s9 | clear | 309 | 199 | 88 | 17.1 | 177 | 7731 | 67/173 | 63 | 0 | [5, 1, 1, 1]
TOTAL | 9 fases | 46.1 min | 806 hits | 17.48 hits/min
```

### D. Referência exata (`--deterministic`), código 2D original

Rodado numa cópia limpa do commit `e542b67` (só com a opção nova do simulador). Comando: `... simulate_stages.gd -- --chapter N --level 1 --seed 1 --deterministic`

```
stage | result | time | boss_s | hits | hits/min | kills | score | bullets avg/max | enemies max | pool_full | levels
p1_s1 | clear | 304 | -1 | 16 | 3.2 | 611 | 8230 | 6/28 | 16 | 0 | [5, 1, 1, 1]
p1_s2 | clear | 304 | -1 | 12 | 2.4 | 592 | 8730 | 7/30 | 13 | 0 | [5, 1, 1, 1]
p1_s3 | clear | 304 | -1 | 11 | 2.2 | 649 | 9990 | 5/23 | 17 | 0 | [5, 1, 1, 1]
p1_s4 | clear | 304 | -1 | 18 | 3.6 | 668 | 9575 | 7/28 | 18 | 0 | [5, 1, 1, 1]
p1_s5 | clear | 257 | 39 | 20 | 4.7 | 509 | 8240 | 10/38 | 20 | 0 | [5, 1, 1, 1]
p1_s6 | clear | 304 | -1 | 19 | 3.7 | 743 | 11630 | 5/30 | 21 | 0 | [5, 1, 1, 1]
p1_s7 | clear | 310 | -1 | 22 | 4.3 | 726 | 9213 | 6/29 | 29 | 0 | [5, 1, 1, 1]
p1_s8 | clear | 305 | -1 | 29 | 5.7 | 911 | 12797 | 8/34 | 28 | 0 | [5, 1, 1, 1]
p1_s9 | clear | 266 | 57 | 28 | 6.3 | 537 | 9070 | 20/74 | 25 | 0 | [5, 1, 1, 1]
TOTAL | 9 fases | 44.3 min | 175 hits | 3.95 hits/min
```

```
stage | result | time | boss_s | hits | hits/min | kills | score | bullets avg/max | enemies max | pool_full | levels
p5_s1 | clear | 310 | -1 | 82 | 15.9 | 360 | 6749 | 59/134 | 58 | 0 | [5, 1, 1, 1]
p5_s2 | clear | 306 | -1 | 102 | 20.0 | 403 | 6601 | 74/170 | 56 | 0 | [5, 1, 1, 1]
p5_s3 | clear | 310 | -1 | 77 | 14.9 | 336 | 4987 | 79/185 | 64 | 0 | [5, 1, 1, 1]
p5_s4 | clear | 310 | -1 | 106 | 20.5 | 327 | 5758 | 76/169 | 60 | 0 | [5, 1, 1, 1]
p5_s5 | clear | 286 | 68 | 53 | 11.1 | 257 | 5481 | 24/102 | 51 | 0 | [5, 1, 1, 1]
p5_s6 | clear | 310 | -1 | 96 | 18.6 | 362 | 8238 | 68/146 | 64 | 0 | [5, 1, 1, 1]
p5_s7 | clear | 310 | -1 | 85 | 16.4 | 220 | 4683 | 128/300 | 64 | 0 | [5, 1, 1, 1]
p5_s8 | clear | 310 | -1 | 111 | 21.5 | 378 | 5494 | 198/355 | 64 | 0 | [5, 1, 1, 1]
p5_s9 | clear | 326 | 214 | 96 | 17.6 | 197 | 8427 | 66/175 | 64 | 0 | [5, 1, 1, 1]
TOTAL | 9 fases | 46.3 min | 808 hits | 17.44 hits/min
```

Tempo de parede: capítulo 1 ≈ 92 s, capítulo 5 ≈ 268 s.
