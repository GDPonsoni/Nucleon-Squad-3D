# Anúncios e publicação na Play Store (plano para depois)

Guardado para quando o jogo estiver pronto para sair. **Nada daqui foi feito ainda:** os anúncios são simulados (`AdService`) e o APK de `builds/` é de debug.

## 1. Anúncios reais (AdMob)

**O que muda no app:** pouco. O `AdService` (`scripts/core/ad_service.gd`) já isola tudo. Os pontos de chamada existem (revive, quarks por anúncio, banner do menu) e a integração é trocar o corpo de `is_rewarded_available()`, `show_rewarded()` e `make_banner_placeholder()` pelas chamadas do plugin.

**Passos:**
1. Criar conta no AdMob e cadastrar o app (gera o ID do app e os IDs dos blocos: recompensado e banner).
2. Instalar um plugin AdMob para Godot 4 e ligar ao `AdService`.
3. Ativar o **build Gradle** no export Android (hoje `gradle_build/use_gradle_build=false` em `export_presets.cfg`). Plugins nativos exigem isso. É o maior ajuste técnico.
4. Permissão de internet e ID do app no manifesto.
5. Usar IDs **de teste** durante o desenvolvimento (clicar em anúncio real do próprio app pode banir a conta).
6. Trocar pelos IDs reais só na versão de produção.

**Obrigações:** formulário de consentimento (UMP) para a Europa; política de privacidade que cubra a LGPD; declaração de anúncios e do ID de publicidade no Play Console.

**Receber:** o AdMob paga ao acumular US$ 100, com conta de recebimento e dados fiscais.

## 2. Publicar na Play Store

**O APK de debug não é o que vai para a loja.** Ele tem o overlay de FPS, usa a chave de debug e o pacote ainda é `com.example`. A loja exige:

| Item | O que fazer |
|---|---|
| Formato | **AAB** (Android App Bundle) em modo release |
| Assinatura | **Keystore de release** própria, com backup fora do repositório (perder = não atualizar mais o app) |
| Pacote | id definitivo (ex.: `com.seunome.nucleonsquad`), que não muda depois de publicado |
| Conta | desenvolvedor Google Play (US$ 25, uma vez). Contas pessoais novas precisam de **teste fechado com 12+ testadores por 14 dias** antes de publicar |
| Material | ícone, capturas de tela, descrição curta e longa, política de privacidade |
| Nome | "Nucleon Squad" é provisório; conferir conflito com outros apps |
| Classificação etária | questionário IARC no Play Console (violência de fantasia, anúncios); responder quando chegar a hora |
| Segurança de dados | formulário de dados coletados (anúncios coletam ID de publicidade) |

## 3. Testes com outras pessoas

O APK de debug pode ser enviado por WhatsApp ou Drive (o testador libera "fontes desconhecidas"). Tem o overlay de FPS e o save fica só no aparelho de cada um. Para testes mais sérios, gerar um release assinado, ou usar o teste fechado da própria Play Store.

## 4. Ordem sugerida

1. Pacote definitivo e keystore de release
2. Export release (AAB) sem overlay de debug
3. Anúncios de teste (AdMob) com Gradle
4. Política de privacidade, UMP e declarações
5. Teste fechado (12 testadores, 14 dias)
6. IDs reais, ficha da loja e publicação
