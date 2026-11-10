# CLAUDE.md — Nucleon Squad 3D (nome provisório)

Jogo mobile, shmup vertical (bullet hell), feito em **Godot 4 (GDScript)**, alvo Android (teste em Galaxy S24). Esta é a **versão 3D low poly** (repositório `Nucleon-Squad-3D`, cópia do Nucleon Squad 2D): a **simulação continua 2D** (posições em pixels, colisão por círculos) e a visão é **3D**, com câmera de perseguição inclinada e modelos gerados por código (`scripts/render3d/`). HUD e menus continuam 2D. O design do jogo está em `docs/GDD_Nucleon_Squad_v1.md` e o plano da versão 3D em `docs/PLANO_3D.md`: leia antes de qualquer tarefa e siga os documentos.

**Retomando o projeto numa conversa nova?** Leia antes `docs/ESTADO_ATUAL.md`. Ele traz o caminho do Godot e do adb, os comandos de build e instalação, o que já existe, as armadilhas conhecidas e as pendências. Mantenha esse arquivo atualizado ao final de cada entrega.

## Regras do projeto

- **Linguagem:** GDScript tipado (`var x: int`, `func f() -> void`). Não usar C#.
- **Idioma:** código e nomes de arquivos em inglês; comentários curtos em português; textos do jogo via tabela de tradução (PT-BR e EN), nunca fixos no código.
- **Parâmetros ajustáveis** (câmera lenta, hits, invulnerabilidade, drops, duração da fase etc.) ficam em **um único lugar** (`scripts/core/params.gd`, autoload). Nada de números mágicos espalhados.
- **Data-driven:** armas, níveis, corpos, inimigos, padrões de tiro e fases definidos em recursos (`.tres`) ou JSON em `data/`, não em código.
- **Pooling** para projéteis, inimigos e efeitos desde o início. Nunca instanciar/destruir projéteis a cada tiro.
- **Suportar N corpos:** não assumir exatamente 2 nem exatamente 4 corpos.
- **Colisão simples** (círculos/áreas pequenas), sem física pesada. Hitbox da nave menor que o sprite.
- **3D só desenha:** a simulação 2D é a fonte da verdade. Nada em `scripts/render3d/` muda lógica, usa o sorteio global (`randf`) ou é lido pela simulação. Efeitos planos que afetam a jogabilidade (avisos, feixes, escudos) continuam desenhados em 2D e aparecem no plano de jogo pela camada `GroundFx`. Parâmetros da visão 3D ficam em `params.gd` (sufixo `_3d` e `camera_*`).
- **Cenas simples:** prefira montar nós por código e manter `.tscn` pequenos (editar `.tscn` à mão é frágil). Não reescreva `project.godot` sem necessidade.
- **Placeholders:** formas geométricas geradas por código (2D em menus, malhas low poly facetadas na partida), sem depender de arte externa.
- **Entrada de toque:** além de toque, suportar mouse (emulação) para testar no PC.
- **Desempenho:** alvo de 60 FPS no S24. Qualquer mudança que aumente muito projéteis/partículas deve vir com medição (FPS na tela em modo debug).

## Estrutura de pastas

```
docs/        GDD e documentos
scenes/      cenas (.tscn) pequenas
scripts/
  core/      params, autoloads, estado da partida
  player/    nave, controle por toque, troca de corpo
  weapons/   armas e níveis
  enemies/   inimigos e padrões
  ui/        HUD e menus
  render3d/  visão 3D: câmera, malhas low poly, vistas das entidades, shaders
data/        dados de armas, inimigos, fases
assets/      imagens, áudio (placeholders até o Marco 2)
```

## Fluxo de trabalho

- Trabalhe em **tarefas pequenas** e faça **um commit por mecânica funcional**, no padrão **Conventional Commits** em português (ex.: `feat(player): implementa troca de corpo`). Tipos e escopos em `CONTRIBUTING.md`.
- Você **não consegue rodar o jogo no celular**: ao terminar uma tarefa, diga em 2–4 linhas **o que o Gabriel deve testar no S24** e o que observar.
- Se o executável do Godot estiver disponível (`godot` no PATH ou caminho informado), valide scripts com `godot --headless --path . --quit` e corrija erros antes de entregar.
- **Não adicione conteúdo fora do marco atual.** Se algo for ambíguo ou o GDD estiver em aberto ([EM ABERTO]), **pergunte** em vez de assumir.
  - **Exceção:** nas **execuções autônomas do `docs/PLANO_3D.md`** (ninguém disponível para responder), essa regra fica **suspensa**: decida pela leitura mais razoável e registre a decisão e a alternativa descartada em `docs/3D_DECISOES.md`. Com o Gabriel presente, a regra original volta a valer.
- Não instale dependências nem altere configurações do sistema sem avisar.

## Marcos (resumo)

0. Engine: protótipo mínimo (nave com controle relativo + câmera lenta ao soltar o dedo) rodando no S24.
1. 2 corpos, troca de corpo, câmera lenta, 1 inimigo, 1 fase, 3 hits.
2. 4 corpos, 4 armas com 5 níveis, especiais, bomba, 1 chefe, salvamento local.
3. Conteúdo, áudio e anúncio de revive.
4. Polimento e publicação.
