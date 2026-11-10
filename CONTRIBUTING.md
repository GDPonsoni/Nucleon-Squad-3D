# Contribuindo

## Commits: Conventional Commits

Todo commit segue o padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/):

```
<tipo>(<escopo opcional>): <descrição curta no imperativo, em português>

<corpo opcional: o porquê da mudança>

<rodapé opcional: BREAKING CHANGE, Refs #issue>
```

**Regras**
- Um commit por tarefa ou mecânica funcional. Não misture assuntos.
- Descrição em minúsculas, no imperativo ("adiciona", "corrige") e sem ponto final, com até ~72 caracteres.
- Mudança que quebra compatibilidade (save, formato de dados): use `!` depois do tipo e um rodapé `BREAKING CHANGE:`.

### Tipos

| Tipo | Quando usar |
|---|---|
| `feat` | nova mecânica ou funcionalidade |
| `fix` | correção de bug |
| `perf` | melhoria de desempenho (FPS, memória, pooling) |
| `refactor` | reestruturação sem mudar o comportamento |
| `tune` | só ajuste de valores em `params.gd` ou dados de balanceamento |
| `docs` | documentação (README, GDD, roteiros de teste) |
| `test` | testes ou cenas de teste |
| `build` | export presets, configuração de Android e build |
| `chore` | manutenção (gitignore, configurações do projeto) |
| `ci` | automação no GitHub Actions |
| `style` | formatação, sem mudar a lógica |

> `tune` não faz parte do padrão base, mas é aceito pela especificação. Ele separa o balanceamento das mudanças de código.

### Escopos

Os escopos seguem as pastas: `core`, `player`, `weapons`, `enemies`, `ui`, `data`, `assets`, `android`, `render3d` (visão 3D, `scripts/render3d/`), `tools` (ferramentas e simuladores).

### Exemplos

```
feat(player): implementa controle relativo por toque e mouse
fix(core): restaura time scale ao perder o foco do app
perf(weapons): reutiliza projéteis via pool em vez de instanciar
tune: reduz câmera lenta para 0.25
docs: adiciona roteiro de teste do Marco 1
build(android): ativa arquitetura arm64 no preset de exportação
feat(core)!: muda formato do save para JSON

BREAKING CHANGE: saves da versão anterior não são carregados.
```

## Fluxo de trabalho

1. **Branch por tarefa** a partir da `main`: `feat/troca-de-corpo`, `fix/clamp-nave`, `docs/readme`.
2. **Valide antes de commitar:**
   ```bash
   godot --headless --path . --quit
   ```
   A saída não pode ter `SCRIPT ERROR` nem `Parse Error`.
3. **Teste no celular** as mudanças de controle, câmera lenta ou desempenho (veja o [README](README.md#exportar-para-android)).
4. Abra um **Pull Request** para a `main` usando o template.

## Padrões de código (Godot)

- **GDScript tipado:** `var speed: float`, `func move() -> void`.
- **Nomes:** arquivos e variáveis em `snake_case`, classes (`class_name`) em `PascalCase`, código em inglês.
- **Comentários** curtos e em português.
- **Nada de números mágicos:** valores ajustáveis vão em `scripts/core/params.gd`.
- **Cenas pequenas:** monte nós por código sempre que possível. Editar `.tscn` à mão é frágil, então prefira o editor.
- **Pooling:** nunca instancie nem destrua projéteis, inimigos ou efeitos a cada frame ou tiro.
- **Textos do jogo** vão na tabela de tradução (PT-BR e EN), nunca fixos no código.
- **Arquivos `.uid`:** o Godot 4.4+ gera um `.uid` ao lado de cada script. **Versione-os** junto com o script.
- **Mover ou renomear arquivos:** faça pelo FileSystem do editor, para o Godot atualizar as referências.
