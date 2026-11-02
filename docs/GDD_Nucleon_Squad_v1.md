# GDD — Nucleon Squad (nome provisório) — v1

> Documento de requisitos / design para iniciar o desenvolvimento. Tudo marcado como **[PARÂMETRO]** é valor inicial a ser ajustado em teste no celular. Tudo em **[EM ABERTO]** ainda não foi decidido.
> Data: 01/11/2026 · Autor: Gabriel · Status: v1 (pré-protótipo)

---

## 1. Visão geral

- **Gênero:** shoot 'em up (shmup) vertical, bullet hell, controle por toque, 2D.
- **Plataforma inicial:** Android (teste local em Galaxy S24). iOS e Play Store ficam para depois.
- **Orientação:** retrato (vertical) fixo, 100%.
- **Referência principal:** *Squadron – Bullet Hell Shooter* (sucessor espiritual; o original é 32 bits e não roda na maioria dos celulares atuais).
- **Público/uso:** projeto pessoal; renda passiva futura por anúncios não invasivos.
- **Offline:** 100% offline e salvamento local na v1.
- **Idiomas:** português e inglês (espanhol opcional depois).

### Pilares de design
1. **Troca de corpo sob câmera lenta:** soltar o dedo desacelera o jogo e permite escolher outro corpo da formação.
2. **Núcleo fixo, corpos descartáveis:** o núcleo persiste e os corpos (formato e arma) são perdidos ao morrer.
3. **Arcade legível:** visual de meio-termo (nem pixel art puro, nem realista), com contraste forte entre naves e inimigos.
4. **Iteração rápida:** o primeiro objetivo é rodar no celular o quanto antes e evoluir em ciclos curtos.

### Fora de escopo (v1)
Árvore de upgrades, online (contas, ranking, nuvem), 3D, mudança visual da nave por nível de arma, compras dentro do app, publicação na Play Store.

---

## 2. Tecnologia

- **Engine candidata:** Godot 4 (2D). Alternativa se não funcionar: Unity.
- **Flutter/Flame:** descartado para este jogo.
- **Marco 0 (decisão da engine):** 1–2 dias com tutorial 2D oficial do Godot + protótipo mínimo (nave seguindo o dedo de forma relativa + câmera lenta ao soltar). Critério: se o fluxo de trabalho e a sensação no S24 forem bons, segue com Godot; senão, reavalia Unity.
- **Alvo de desempenho:** 60 FPS estáveis no S24; desejável rodar em celulares intermediários (mid-range). Orçamento de projéteis e partículas definido no Marco 1 por medição.
- **Pontos de atenção:** pooling de objetos (projéteis, inimigos, efeitos), colisão simples (círculos), sem física pesada.
- **Anúncios:** AdMob (plugin Godot) ou equivalente; integrar só depois do Marco 2.

---

## 3. Controles

- **Movimento relativo:** a nave se move conforme o deslocamento do dedo a partir do ponto onde ele tocou, independentemente de onde a nave esteja. Não há "a nave vai para o dedo".
- **Tiro:** automático enquanto o jogo roda.
- **Botão de especial:** fixo em um canto da tela, alcançável pelo polegar. [EM ABERTO: posição exata e se aparece só quando carregado]
- **Botão de pausa/configurações:** sempre visível; acessível durante a câmera lenta.
- **Soltar o dedo:** ativa a **câmera lenta** (seção 4).

---

## 4. Câmera lenta e troca de corpo

1. Dedo solto → o jogo passa para **30% da velocidade** (time scale 0,3) [PARÂMETRO].
2. Aparecem ao lado da nave os ícones dos **outros corpos** da formação.
3. Opções durante a câmera lenta:
   - Tocar em **um ícone de corpo** → troca para aquele corpo (animação: núcleo fecha e o corpo se reconstrói) e o jogo retoma.
   - Tocar em **qualquer outro lugar da tela** → retoma o jogo com o corpo atual (já pré-selecionado).
   - Tocar em **configurações/pausa** → abre o menu; ao sair, o jogo retoma.
4. **Invulnerabilidade:** 2 s ao trocar de corpo [PARÂMETRO].
5. **Limite de uso da câmera lenta:** *sem limite na v1*, mas tratar como mecânica a equilibrar. Risco conhecido: o jogador pode soltar o dedo a qualquer sinal de perigo. Parâmetros a testar: duração máxima, energia/cooldown, custo. [EM ABERTO]

---

## 5. Núcleo, corpos e formação

- **Núcleo:** estático e comum a todos os corpos. Cada vez que um corpo morre, o núcleo racha (efeito visual e narrativo; sem efeito de gameplay na v1 [EM ABERTO: pode virar mecânica depois]).
- **Corpo:** formato + arma. Um corpo ativo por vez; os outros ficam em reserva.
- **Formação (preset):** 4 corpos escolhidos antes da partida. Estrutura de código deve suportar de 4 até N corpos desbloqueáveis.
- **Fim de partida:** perde-se quando morre o **último corpo** (4º). Ao morrer um corpo, o jogador escolhe outro corpo vivo (reconstrução do núcleo).
- **Vida do corpo:** 3 hits [PARÂMETRO]. Ataques grandes podem tirar 2 de uma vez. Hits recebidos aparecem em um indicador na tela.
- **Morte do corpo:** perde-se o corpo e os **power-ups acumulados** da arma dele.
- **Marco 1:** apenas 2 corpos jogáveis, mas toda a estrutura já preparada para 4+.

---

## 6. Armas (1 por corpo, 5 níveis cada)

Evolução de nível: **apenas efeito da arma** (e variação de cor); a nave não muda visualmente por nível. Cada arma tem uma cor própria.

| # | Arma | Nível 1 → 5 (esboço) | Especial (esboço) |
|---|------|----------------------|-------------------|
| 1 | **Raio** | 1 raio → 2 → 3 → 4 → raio grande | Raio gigante à frente que se abre e limpa em volta |
| 2 | **Leque** | tiro espalhado: mais projéteis e mais ângulo por nível | Rajada de 360° que limpa projéteis ao redor |
| 3 | **Mísseis teleguiados** (os "triângulos") | 1 míssil → mais mísseis, mais tracking | Chuva de mísseis que busca todos os inimigos na tela |
| 4 | **Órbita** | 1 orbital → 2 → 3 → 4 → anel completo | Anel de energia que expande e limpa projéteis |

Os especiais 2–4 são genéricos (efeito de limpar a tela/área) para não travar o design; refinar depois do protótipo.

Nomes e detalhes dos níveis são esboços; fechar no balanceamento.

### Especial por arma
- Carrega por **tempo** [PARÂMETRO]; o jogador aciona pelo botão lateral quando estiver cheio.
- Cada arma terá um especial próprio, com efeito de limpar/dar dano em área.

### Bomba global
- Item de drop que limpa a tela. Máximo de **2 por fase**, dropadas por volta de 30% e 60% da fase [PARÂMETRO].
- [EM ABERTO: se existe também um "especial global" que carrega por tempo, separado da bomba]

---

## 7. Power-ups e progressão dentro da partida

- Power-ups sobem o nível da **arma do corpo ativo** (nível máximo 5).
- Morreu o corpo → perde os níveis daquela arma. Cada corpo começa a partida no nível 1.
- **Princípio de balanceamento de drops:** dropar o suficiente para que seja possível levar pelo menos **2 armas** ao nível máximo na fase, mas com punição real: se o jogador morrer no fim da fase, pode ficar com corpos sem evolução.
- Balanceamento fino (dano, taxa de drop) é só por teste. [PARÂMETRO]
- Outros itens previstos: bomba global (seção 6). [EM ABERTO: itens de cura, escudo, moedas]

---

## 8. Estrutura de fases

- **Planetas** → cada um com várias **fases** → cada fase termina com um **chefe**.
- **Duração da fase:** ~3 minutos até o chefe [PARÂMETRO].
- **Quantidade de planetas e fases por planeta:** [EM ABERTO]
- **Inimigos:** muitos tipos, com padrões de tiro (bullet hell). Lista e comportamentos definidos por marco. [EM ABERTO]
- **Chefes:** um por fase, com fases de ataque. [EM ABERTO]
- **Marco 1:** 1 fase, 1 tipo de inimigo, sem chefe obrigatório.

---

## 9. Anúncios e monetização

- **Revive por anúncio:** disponível apenas no **game over** (quando os 4 corpos morreram), **1 vez por partida**. O jogador volta com os mesmos power-ups que tinha. [EM ABERTO: qual corpo volta e com quantos hits]
- **Sem anúncios** no início da partida ou entre fases na v1.
- **Futuro (fora da v1):** recompensas por anúncio opcional (bônus, desbloqueios), a avaliar.
- **Privacidade:** consentimento/LGPD para anúncios ao integrar o SDK.
- **Expectativa realista:** receita baixa no início; tratar como renda passiva futura, não custeio.

---

## 10. Interface

- **HUD:** pontuação, hits do corpo atual (indicador), barra do especial, ícones dos corpos em reserva, botão de pausa.
- **Telas:** menu principal, seleção de formação (4 corpos), seleção de planeta/fase, partida, game over (com opção de revive), configurações (idioma, áudio).
- **Idiomas:** PT-BR e EN desde o início (textos fora do código, em tabela de tradução).

---

## 11. Arte e áudio

- **Estilo:** meio-termo entre arcade simples e detalhado. Naves **minimalistas** (inspiração Squadron), inimigos **coloridos e de alto contraste**, fundo intermediário (nem realista, nem plano).
- **Efeito de inclinação:** a nave inclina ao mover lateralmente, feito em 2D (sprites por ângulo ou simulação por código). Testar no Marco 1.
- **Produção:** assets gerados com IA (imagem) + ajustes manuais. Definir pipeline de consistência (paleta, tamanho, prompts-base) no Marco 1.
- **Áudio:** música e efeitos gerados por IA (ex.: Suno); implementar áudio depois do Marco 1.
- **Estilo:** mantido como descrito acima (decisão de 01/11/2026). Refinar após o protótipo.
- **Placeholders:** no Marco 0–1, naves, inimigos e projéteis podem ser formas geométricas desenhadas por código (sem depender de arte pronta).

---

## 12. Dados e salvamento

- Local no aparelho: formação de 4 corpos, corpos desbloqueados, progresso de fases, configurações.
- Sem contas e sem nuvem na v1. Estrutura de dados pensada para sincronização futura.

---

## 13. Arquitetura (diretrizes para o desenvolvimento)

- **Data-driven:** armas, níveis, corpos, inimigos, padrões de tiro e fases definidos em dados (recursos/JSON), não em código.
- **Corpos desacoplados:** lógica de arma separada da nave; trocar de corpo = trocar a arma e o formato, mantendo o núcleo.
- **Estado de partida centralizado:** corpos vivos, hits, nível da arma por corpo, tempo/especial.
- **Pooling** de projéteis/inimigos/efeitos desde o início.
- **Parâmetros expostos** (câmera lenta, hits, i-frames, drops, duração) em um único lugar, para ajustar rápido.
- **Suporte a N corpos:** código não deve assumir exatamente 2 nem exatamente 4.

---

## 14. Marcos

| Marco | Objetivo | Critério de pronto |
|-------|----------|--------------------|
| **0** | Decidir engine | Protótipo mínimo no S24 (nave relativa + câmera lenta) |
| **1** | Jogável mínimo | 2 corpos, troca de corpo, câmera lenta, 1 inimigo, 1 fase, 3 hits, tudo rodando no S24 |
| **2** | Núcleo completo | 4 corpos, 4 armas com 5 níveis, especial e bomba, 1 chefe, salvamento local |
| **3** | Conteúdo | Vários inimigos/chefes, 1º planeta completo, áudio, anúncio de revive |
| **4** | Polimento e publicação | Estilo final de arte, balanceamento, Play Store (teste fechado exigido pela Play Console) |

---

## 15. Riscos

- **Câmera lenta sem custo** pode quebrar a dificuldade. Testar cedo.
- **Escopo grande para primeiro jogo:** seguir os marcos, nada de adicionar conteúdo antes do núcleo funcionar.
- **Arte por IA:** inconsistência entre sprites e frames de inclinação. Definir pipeline no Marco 1.
- **Semelhança com o Squadron:** manter nome, silhuetas e identidade próprios para evitar remoção na loja.
- **Desempenho:** muitos projéteis na tela. Medir desde o Marco 1.

---

## 16. Pendências (resumo)

1. Nome final do jogo (hoje provisório).
2. Estilo final de arte (referências: protótipo definido; final em aberto).
3. Limite/custo da câmera lenta.
4. Existência de "especial global" além da bomba (especiais das armas 2–4 já definidos de forma genérica).
5. Revive: qual corpo volta e com quantos hits.
6. Invulnerabilidade após levar hit (hoje só definida para troca de corpo).
7. Quantidade de planetas, fases, tipos de inimigos e chefes.
8. Posição do botão de especial.
