# GDD — Nucleon Squad (nome provisório)

> Documento de requisitos e design. Tudo marcado como **[PARÂMETRO]** é valor ajustável em `scripts/core/params.gd` ou `data/balance.tres` e deve ser confirmado em teste no celular. Tudo em **[EM ABERTO]** ainda não foi decidido.
> Criado em 01/11/2026 (v1, pré-protótipo) · Revisado em 09/11/2026 (v2, alinhado ao jogo atual) · Autor: Gabriel

---

## 1. Visão geral

- **Gênero:** shoot 'em up (shmup) vertical, bullet hell, controle por toque, 2D.
- **Plataforma inicial:** Android (teste local em Galaxy S24). iOS fica para depois.
- **Orientação:** retrato (vertical) fixo, 100%.
- **Referência principal:** *Squadron – Bullet Hell Shooter* (sucessor espiritual; o original é 32 bits e não roda na maioria dos celulares atuais).
- **Público/uso:** projeto pessoal; renda passiva futura por anúncios não invasivos.
- **Offline:** 100% offline e salvamento local.
- **Idiomas:** português, inglês e espanhol.

### Pilares de design
1. **Troca de corpo sob câmera lenta:** soltar o dedo desacelera o jogo e permite escolher outro corpo do esquadrão.
2. **Núcleo fixo, corpos descartáveis:** o núcleo persiste e os corpos (formato e arma) são perdidos ao morrer.
3. **Arcade legível:** visual de meio-termo (nem pixel art puro, nem realista), com contraste forte entre naves e inimigos. Todo ataque inimigo tem aviso (telegrafia).
4. **Iteração rápida:** rodar no celular o quanto antes e evoluir em ciclos curtos.

### Fora de escopo (por enquanto)
Online (contas, ranking, nuvem), 3D, mudança visual da nave por nível de arma, compras dentro do app.

---

## 2. Tecnologia

- **Engine:** Godot 4 (2D), GDScript tipado.
- **Alvo de desempenho:** 60 FPS estáveis no S24; desejável rodar em celulares intermediários.
- **Pontos de atenção:** pooling de objetos (projéteis, inimigos, efeitos), colisão simples (círculos), sem física pesada.
- **Anúncios:** AdMob (plugin Godot) ou equivalente. Hoje são simulados (`AdService`); plano em `docs/PUBLICACAO.md`.

---

## 3. Controles

- **Movimento relativo:** a nave se move conforme o deslocamento do dedo a partir do ponto onde ele tocou, independentemente de onde a nave esteja.
- **Tiro:** automático enquanto o jogo roda.
- **Botão de especial:** fixo no canto, alcançável pelo polegar; pulsa quando está carregado.
- **Botão de pausa/configurações:** sempre visível; acessível durante a câmera lenta.
- **Soltar o dedo:** ativa a **câmera lenta** (seção 4).
- **Troca de nave:** toque curto num corpo da barra fixa na base da tela.

---

## 4. Câmera lenta e troca de corpo

1. Dedo solto → o jogo passa para **30% da velocidade** [PARÂMETRO], com moldura azul.
2. A barra de troca na base da tela fica nítida (translúcida enquanto o dedo move a nave).
3. Opções durante a câmera lenta:
   - Toque curto em **um corpo** → troca para ele (o corpo recolhe no núcleo e o novo nasce dele).
   - Tocar e arrastar em **qualquer outro lugar** → retoma o jogo com o corpo atual.
   - **Pausa/configurações** → abre o menu; ao sair, o jogo retoma.
4. **Invulnerabilidade:** 1,0 s ao trocar de corpo e 1,0 s após levar hit [PARÂMETRO].
5. **Recarga entre trocas voluntárias:** 4 s [PARÂMETRO], mostrada como setor escuro nos ícones. Trocas forçadas (corpo destruído) não esperam.
6. **Custo da câmera lenta (09/11/2026):** na câmera lenta voluntária **as armas não atiram** (ficam prontas e disparam ao voltar) e uma **energia** esvazia em tempo real: cheia dura 3 s; com o dedo na tela recarrega do zero em 6 s; abaixo de 15% soltar o dedo não ativa a câmera lenta, e vazia o jogo volta ao normal [PARÂMETRO]. Barra azul acima da barra de troca. A câmera lenta forçada (corpo destruído) e a do começo da fase não gastam. A Órbita só gira na câmera lenta (não dá dano, mas segue bloqueando tiros).

---

## 5. Núcleo, corpos e esquadrão

- **Núcleo:** comum a todos os corpos e é a hitbox. Rachar o núcleo a cada corpo perdido continua só como ideia. [EM ABERTO]
- **Corpo:** formato + arma + especial. Um corpo ativo por vez; os outros ficam em reserva.
- **Esquadrão:** de **1 a 4 corpos** escolhidos antes da partida [PARÂMETRO: `squad_size` = máximo]. Esquadrão menor tem menos vidas, mas cada vaga vazia dá **+25% no bônus de quarks** da fase [PARÂMETRO]. O código suporta N corpos.
- **Fim de partida:** perde-se quando morre o último corpo. Ao morrer um corpo, o jogador escolhe outro corpo vivo.
- **Vida do corpo:** 3 hits [PARÂMETRO], mais com o Casco da evolução. Hits aparecem na barra de troca.
- **Morte do corpo:** perde-se o corpo e os níveis de arma dele.
- **Nave auxiliar:** versão pequena de uma nave fora do esquadrão. Acompanha a principal, não leva dano e atira uma versão fraca da arma (3 níveis). Cada arma tem um papel como auxiliar (foco, flancos, caça-grandões, escudo, perfuração, área, defesa próxima, enxame). O espaço libera ao concluir o **capítulo 2**, quando já há naves sobrando para ela.

---

## 6. Armas (1 por corpo, 5 níveis cada)

Evolução de nível: **apenas efeito da arma** (e variação de cor); a nave não muda visualmente por nível. Cada arma tem cor, especial e fraquezas próprias (inimigos fracos ou resistentes a ela).

| Nave/arma | Especial | Liberada |
|---|---|---|
| Raio | raio gigante + anel que limpa tiros | início |
| Leque | rajada 360° + anel | início |
| Mísseis | chuva de mísseis em todos | início |
| Órbita | anel de energia | início |
| Lança | leque de lanças gigantes | capítulo 1 |
| Artilharia | bombardeio | capítulo 2 |
| Tesla | tempestade de raios em todos | capítulo 3 |
| Ricochete | 16 orbes que ricocheteiam | capítulo 4 |

O capítulo 5 é o último por enquanto. A próxima atualização traz novos capítulos e recompensas; até lá, o seletor mostra uma página de "novos capítulos em breve".

### Especial por arma
- Carrega por **tempo** [PARÂMETRO]; o jogador aciona pelo botão quando estiver cheio.
- **Momentos de especial:** no clímax da fase 8 e na última fase dos chefes de capítulo, os alvos ficam blindados até o jogador usar o especial.

### Bomba global
- Prevista no v1 (item que limpa a tela, até 2 por fase), mas **não implementada**: os especiais e os momentos de especial cobrem esse papel. O som `bomb_global.wav` está guardado. [EM ABERTO: implementar ou retirar do design]

---

## 7. Itens e progressão dentro da partida

Todos os drops seguem o **relógio da fase** (não o número de abates): ficam "devidos" no horário e caem no próximo inimigo destruído.

- **Power-ups de arma:** 15 por fase, ao longo de 75% da duração [PARÂMETRO]. Sobem o nível da arma do corpo ativo (máximo 5). Dá para levar 3 armas ao nível 5 com folga, mas perder um corpo no fim da fase ainda pesa.
- **Kits médicos:** 2 por fase [PARÂMETRO]; recuperam 1 hit do corpo ativo.
- **Power-up da auxiliar (raro, lilás):** 2 por fase, só enquanto ela pode subir de nível.
- **Excedente:** power-up com a arma no nível máximo e kit com o corpo sem dano viram pontos.
- A evolução do núcleo encurta esses intervalos (Arsenal e Reparo), com piso.

---

## 8. Estrutura de fases e dificuldade

- **Campanha:** 5 planetas (capítulos) × 9 fases = 45 fases, geradas por `scripts/tools/campaign_builder.gd`.
- **Fase 5:** chefe intermediário. **Fase 9:** chefe do capítulo. **Fase 7:** campo de meteoros. **Fase 8:** clímax com momento de especial.
- **Duração:** fases comuns com 5 min de ondas; fase 5 com 3,5 min antes do chefe; fase 9 com ondas mais curtas e luta longa [PARÂMETRO]. Os 5 min são uma aposta inicial, a revisar com dados de jogo.
- **Inimigos:** 9 tipos que atiram, 5 "counters" (Faísca, Enxame, Colosso, Escudeiro, Serpente) e rochas que bloqueiam tiros. Todo ataque tem aviso.
- **Ritmo:** motivos de onda em ciclo, mais uma camada de ação (ondas que não atiram) e um surto a cada minuto.
- **Curva de dificuldade:** sobe de fase em fase dentro do capítulo e recua um pouco no começo do seguinte (respiro depois do chefe).
- **Vida dos inimigos alinhada à progressão:** vida = poder esperado do jogador × resistência do capítulo (`BalanceData`). O poder esperado segue o que a renda de quarks compra até aquele capítulo; a resistência sobe devagar (1,4 → 1,8). Os testes conferem esse alinhamento, e o simulador mede a dificuldade com a evolução esperada (`--expected`).

---

## 9. Progressão fora da partida

- **Quarks:** moeda da evolução. Vêm sobretudo de **concluir fases** (bônus por capítulo, dobrado na 1ª vez), de **estrelas novas** e de vagas vazias no esquadrão; abates rendem só um extra pequeno.
- **Meta de ritmo:** 1º nível de vários nós no capítulo 1 e a árvore com limite completa por volta do fim do capítulo 4. A Sobrecarga (sem limite) fica para o fim.
- **Evolução do núcleo:** 12 nós com limite em 3 ramos (Ataque, Defesa, Suporte) + Sobrecarga sem limite.
- **Estrelas:** 1 por concluir, 2 e 3 por pontuação.
- **Desbloqueios por capítulo:** uma nave por capítulo (1 a 4) e o espaço da auxiliar no capítulo 2.

---

## 10. Anúncios e monetização

- **Revive por anúncio:** só no **game over**, **1 vez por partida**. O jogador volta com os mesmos power-ups que tinha.
- **Quarks por anúncio:** opcional, até 5 por dia, cerca de uma fase concluída de recompensa.
- **Banner:** só no menu inicial.
- **Sem anúncios** no início da partida ou entre fases.
- **Privacidade:** consentimento/LGPD para anúncios ao integrar o SDK.
- **Expectativa realista:** receita baixa no início; tratar como renda passiva futura, não custeio.

---

## 11. Interface

- **HUD:** pontuação, barra do especial, barra de troca com hits e nível de cada corpo, botão de pausa.
- **Telas:** menu principal, esquadrão (vagas, auxiliar, inspeção com demo da arma), evolução do núcleo, seletor de fases (mapa de um planeta por página + "em breve"), partida, resultado, configurações (volumes, vibração, efeitos reduzidos, estatísticas, contador de dano, idioma, rever tutorial).
- **Tutorial:** dicas contextuais que não pausam e só aparecem em momento seguro; avisos de desbloqueio ao fim da fase.
- **Idiomas:** PT-BR, EN e ES (textos em tabela de tradução).

---

## 12. Arte e áudio

- **Estilo:** meio-termo entre arcade simples e detalhado. Naves **minimalistas**, inimigos **coloridos e de alto contraste**, fundo intermediário.
- **Inclinação:** pseudo-3D por código (inclinação, achatamento, sombra).
- **Produção:** assets gerados com IA + ajustes manuais, com pipeline de consistência (paleta, tamanho, prompts-base). Hoje tudo são placeholders desenhados por código.
- **Áudio:** efeitos e músicas sintetizados como placeholder; versões definitivas pendentes.
- **Vibração:** padrões nomeados, com intensidade configurável.

---

## 13. Dados e salvamento

- Local no aparelho (`user://save.json`, versionado e com migração): fases concluídas, recordes, esquadrão, auxiliar, quarks, evolução, capítulos concluídos, dicas vistas e configurações.
- Sem contas e sem nuvem. Estrutura pensada para sincronização futura.

---

## 14. Arquitetura (diretrizes para o desenvolvimento)

- **Data-driven:** armas, níveis, corpos, inimigos, padrões de tiro, fases e evolução em recursos (`data/`), não em código.
- **Corpos desacoplados:** lógica de arma separada da nave; trocar de corpo = trocar a arma e o formato, mantendo o núcleo.
- **Estado de partida centralizado** (`MatchState`).
- **Pooling** de projéteis, inimigos e efeitos.
- **Parâmetros expostos** num só lugar (`Params` e `BalanceData`).
- **Suporte a N corpos:** o código não assume exatamente 2 nem exatamente 4.

---

## 15. Marcos

| Marco | Objetivo | Situação |
|-------|----------|----------|
| **0** | Decidir engine | Concluído (Godot) |
| **1** | Jogável mínimo | Concluído |
| **2** | Núcleo completo | Concluído (8 naves, especiais, chefes, save); a bomba global ficou de fora |
| **3** | Conteúdo, áudio e anúncio de revive | Em andamento: 5 capítulos, sons e anúncio simulado; faltam áudio definitivo e SDK real |
| **4** | Polimento e publicação | Pendente: arte final, balanceamento no aparelho, Play Store (teste fechado) |

---

## 16. Riscos

- **Câmera lenta:** custo novo (seção 4) a calibrar no aparelho; curto demais deixa a troca de nave estressante.
- **Fases de 5 min** podem ser longas para sessões no celular. Medir retenção e revisar.
- **Escopo grande para primeiro jogo:** seguir os marcos.
- **Arte por IA:** inconsistência entre sprites. Definir o pipeline antes da arte final.
- **Semelhança com o Squadron:** manter nome, silhuetas e identidade próprios para evitar remoção na loja.
- **Desempenho:** muitos projéteis na tela. Medir no aparelho com carga máxima.

---

## 17. Pendências (resumo)

1. Nome final do jogo (hoje provisório).
2. Estilo final de arte.
3. Calibrar a energia da câmera lenta no aparelho.
4. Bomba global: implementar ou retirar.
5. Revive: qual corpo volta e com quantos hits (hoje volta o último, com a vida cheia).
6. Núcleo rachando como mecânica.
7. Conteúdo da próxima atualização: novos capítulos e as recompensas do capítulo 5 em diante.
