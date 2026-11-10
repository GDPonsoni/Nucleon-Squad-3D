# Relatório da execução do PLANO_3D (2026-11-10)

**Parou por limite de uso, depois da T9.** O repositório está consistente e com push feito. Ponto de retomada e lista do que falta: `docs/3D_PENDENCIAS.md`.

## Resultado

| Tarefa | Estado |
|---|---|
| T0 Preparação e linha de base | feita |
| T1 Esqueleto (câmera, luz, chão, camada 2D no plano) | feita |
| T2 Mapeamento e câmera, com testes | feita |
| T3 Malhas low poly, com testes | feita |
| T4 Jogador, auxiliar, troca e quebra de corpo | feita |
| T5 Inimigos, rochas e elites | feita |
| T6 Projéteis em MultiMesh | feita |
| T7 Chefes | feita |
| T8 Power-ups, kits, baús e orbes | feita |
| T9 Efeitos de chão que afetam a jogabilidade | feita (pela camada 2D no plano, D1) |
| T10 Sobreposições 2D (destaque do tutorial) | **não feita** |
| T11 Prova de equivalência | **parcial** (só a fase 1-1) |
| T12 Documentação e APK | **não feita: não há APK 3D** |
| T13 Cenário, T14 Partículas | não feitas |

Nenhuma tarefa falhou nem foi revertida.

## O que mudou em relação ao plano

Tudo em `docs/3D_DECISOES.md`. As principais:

- **D1:** os efeitos de chão não foram refeitos um a um. A camada 2D inteira do jogo é mostrada como textura no plano de jogo, então o aviso fica exatamente onde a colisão acontece.
- **D4:** a simulação 2D original não é determinística (o áudio usa o relógio real). O simulador ganhou `--deterministic` para a prova valer.
- **D3:** seguimento da câmera com máximo de 60 px em vez de 120.

## Testes

Última suíte completa verde: commit da T9 (validate, `run_tests` com 3652 verificações, `ui_smoke`, `match`, `boss` e `run_regressions` e o teste novo `render3d_regressions`, todos com 0 falhas). `pager_regressions` segue com as 4 falhas antigas.

## Para o Gabriel

Ainda **não dá para testar no S24**: falta exportar o APK (T12). Para ver no PC:

```bash
G=../Godot_v4.7.2-stable_linux.x86_64
$G --path . --resolution 540x1170
```

Para continuar, cole de novo o prompt da seção 9 do `docs/PLANO_3D.md`: a sessão nova deve ler `docs/3D_PENDENCIAS.md` e seguir da T10.
