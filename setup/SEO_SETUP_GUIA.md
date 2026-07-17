# SEO — Guia de Configuração Completa

Guia passo a passo para configurar SEO, indexação no Google e analytics do livro.

**Estimativa total:** 60-90 minutos ativos + 24-72h aguardando propagação/indexação.

---

## Parte 1 — Google Search Console (indexação)

### Passo 1.1 — Criar conta e adicionar propriedade (15 min)

1. Acesse [search.google.com/search-console](https://search.google.com/search-console)
2. Fazer login com sua conta Google
3. Clicar em **"+ Adicionar propriedade"**
4. Escolher **"Prefixo do URL"** (não "Domínio", que exige DNS)
5. Preencher: `https://mariocezar1971.github.io/livro-doe-usinagem/`
6. Clicar em **"Continuar"**

### Passo 1.2 — Verificar propriedade via meta tag (5 min)

O Search Console vai oferecer vários métodos. Escolha **"Tag HTML"**.

1. Copiar a meta tag mostrada. Vai ser algo como:
   ```html
   <meta name="google-site-verification" content="ABC123xyz..." />
   ```

2. Salvar em arquivo `.\google-verification.html` na raiz do projeto:
   ```
   C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM\google-verification.html
   ```

3. Rodar o script orquestrador da Fase 1.4 novamente — ele detecta o arquivo e insere a tag automaticamente no `_quarto.yml`.

4. Aguardar deploy (~3 min).

5. No Search Console, clicar em **"Verificar"**.

Se der ✓ verde, propriedade confirmada.

### Passo 1.3 — Submeter sitemap (2 min)

1. Menu lateral esquerdo do Search Console: **"Sitemaps"**
2. Em "Adicionar um sitemap", digitar:
   ```
   sitemap.xml
   ```
3. Clicar em **"Enviar"**

O Google vai começar a rastrear as páginas em 24-72h.

### Passo 1.4 — Monitorar indexação (semanal)

Toda semana, verificar:

- **Cobertura**: quantas páginas foram indexadas
- **Desempenho**: quais consultas trazem visitantes
- **Melhorias**: erros de dados estruturados

Meta realista: 15-25 páginas indexadas em 30 dias após submissão.

---

## Parte 2 — Analytics

Escolha UMA das 3 opções abaixo. O script orquestrador pergunta qual você prefere e configura automaticamente.

### Opção A — Google Analytics 4 (Gratuito, mais popular)

**Prós:** gratuito, muitos recursos, integra com Search Console.
**Contras:** cookies, banner de consentimento LGPD obrigatório, mais lento (~45 KB).

#### Setup (15 min)

1. Acesse [analytics.google.com](https://analytics.google.com)
2. Clicar em **"Começar a medir"** (ou "Admin" → "Criar propriedade" se já tiver conta)
3. Nome da conta: `Livro DOE Usinagem`
4. Nome da propriedade: `Livro DOE Usinagem - Site`
5. Fuso horário: **Brasil - São Paulo**
6. Moeda: **Real brasileiro (BRL)**
7. Setor: **Educação**
8. Tamanho da empresa: **Menos de 10 funcionários**
9. Objetivos: **Gerar leads** e **Examinar o comportamento do usuário**
10. Aceitar termos

Configurar **Fluxo de dados**:
1. Escolher **Web**
2. URL: `https://mariocezar1971.github.io/livro-doe-usinagem/`
3. Nome: `Site principal`
4. Copiar o **ID de medição** (formato `G-XXXXXXXXXX`)

#### Inserir no site

Salvar o ID em arquivo `.\ga4-id.txt` na raiz do projeto:
```
G-XXXXXXXXXX
```

Rodar o script orquestrador — ele detecta o arquivo e configura automaticamente.

**IMPORTANTE — LGPD:** você precisa adicionar um **banner de consentimento** de cookies. Sugestão: [Cookie Consent by Osano](https://www.osano.com/cookieconsent) (gratuito).

### Opção B — Plausible (~$9/mês, privacy-friendly) ⭐ RECOMENDADO

**Prós:** sem cookies (sem banner LGPD), LGPD-nativo, leve (~1 KB), dashboard pode ser público.
**Contras:** pago (~R$45/mês).

#### Setup (10 min)

1. Acesse [plausible.io](https://plausible.io)
2. Criar conta (trial gratuito de 30 dias)
3. Adicionar site: `mariocezar1971.github.io/livro-doe-usinagem`
4. Copiar o script de integração (é uma tag `<script>` de 1 linha)

Salvar em `.\plausible-domain.txt`:
```
mariocezar1971.github.io/livro-doe-usinagem
```

Rodar o script orquestrador.

**Bonus:** compartilhe o dashboard público para mostrar transparência de métricas do livro. Muitos autores fazem isso para gerar confiança.

### Opção C — Umami self-hosted (gratuito, avançado)

**Prós:** completamente gratuito, sem cookies, LGPD-nativo, você controla os dados.
**Contras:** requer deploy próprio (Fly.io, Railway, Vercel Postgres).

#### Setup (30 min - requer familiaridade com deploy)

1. Fork do [Umami no GitHub](https://github.com/umami-software/umami)
2. Deploy em Fly.io ou Railway (grátis)
3. Configurar banco Postgres (grátis nos providers)
4. Adicionar site no dashboard Umami
5. Copiar `data-website-id` e URL do script

Salvar em `.\umami-config.txt`:
```
url=https://SEU-UMAMI.fly.dev/script.js
id=abcd1234-efgh-5678-ijkl-9012mnop3456
```

Rodar o script orquestrador.

### Opção D — Nenhum analytics (mais simples)

Se você não quer analytics agora, é OK. Você pode adicionar depois. O script orquestrador aceita "nenhum" e apenas configura SEO/Search Console.

**Análise de tráfego alternativa:** o GitHub Pages não expõe métricas próprias, mas você pode consultar **`gh api /repos/mariocezar1971/livro-doe-usinagem/traffic/views`** via GitHub CLI para ver views nos últimos 14 dias (limitado).

---

## Parte 3 — Sitemap.xml

O Quarto **gera sitemap automaticamente** quando `site-url:` está configurado no `_quarto.yml`. Mas para o GitHub Pages atual, precisamos que a URL do `site-url:` bate com onde está publicado.

### Verificação

Após deploy, acesse:
```
https://mariocezar1971.github.io/livro-doe-usinagem/sitemap.xml
```

Deve mostrar XML válido com URLs de todas as páginas do livro. Se retornar 404, o `site-url` não foi configurado corretamente (o script corrige isso).

### O que o sitemap contém

- Todas as páginas HTML do livro (index, capítulos, apêndices, referências, em-breve)
- URL, data de última modificação, prioridade e frequência de atualização

### Submissão manual (backup)

Você pode ping direto o Google para forçar re-crawl:

```
https://www.google.com/ping?sitemap=https://mariocezar1971.github.io/livro-doe-usinagem/sitemap.xml
```

Copiar/colar essa URL no navegador uma vez a cada 30 dias força reprocessamento.

---

## Parte 4 — Otimizações extras

### Robots.txt (opcional)

Se quiser controlar quais páginas o Google rastreia:

Criar `.\robots.txt` na raiz do projeto:

```
User-agent: *
Allow: /
Sitemap: https://mariocezar1971.github.io/livro-doe-usinagem/sitemap.xml

# Não indexar arquivos de desenvolvimento
Disallow: /styles/
Disallow: /setup/
```

Adicionar `robots.txt` como `resources:` no `_quarto.yml`.

### Meta description por capítulo

Cada `.qmd` pode ter descrição própria no frontmatter:

```yaml
---
title: "Capítulo 1: Por que DOE em manufatura?"
description: "Introdução ao Planejamento de Experimentos e sua aplicação em processos de usinagem, com casos comparativos entre OFAT e DOE."
keywords: [DOE, manufatura, usinagem, experimentos]
---
```

Isso é feito capítulo a capítulo durante a escrita. Fase 3.

### Rich Snippets

Google mostra "rich snippets" (preview enriquecido) baseado no schema.org que já configuramos. Depois de indexado (7-30 dias), teste em:

```
https://search.google.com/test/rich-results
```

Cole a URL do seu livro e veja como o Google vê os dados estruturados.

---

## Parte 5 — Monitoramento (semanal)

### KPIs para acompanhar

**Search Console:**
- **Impressões**: quantas vezes seu site apareceu em buscas
- **Cliques**: quantos vieram do Google
- **CTR (Click-Through Rate)**: cliques ÷ impressões
- **Posição média**: onde você aparece nos resultados
- **Consultas top**: quais palavras trazem tráfego

**Analytics (GA4 ou Plausible):**
- **Visitantes únicos**
- **Páginas mais vistas**
- **Fonte de tráfego** (direto, Google, LinkedIn, etc.)
- **Duração média de sessão**
- **Bounce rate** (visitantes que só veem 1 página)
- **Conversões** (cliques no formulário Brevo, downloads)

### Meta realista de tráfego

| Marco | Visitantes/mês | Fonte principal |
|-------|----------------|-----------------|
| 1º mês | 30-80 | Direto (você compartilhou o link) |
| 3º mês | 100-250 | Google começa a mandar tráfego |
| 6º mês | 300-600 | Google + LinkedIn + referências |
| 1 ano | 800-1500 | Diversificado |
| Lançamento (18 meses) | 2000-4000 | Efeito lançamento |

Livros técnicos em nicho têm **cauda longa** — o tráfego se acumula lentamente mas fica estável por anos.

---

## Solução de problemas

### "Meu site não aparece no Google mesmo após submeter"

- **Aguarde 7-14 dias**: crawl inicial demora
- **Verifique**: no Search Console → Cobertura → Erros. Se aparecer "excluído por noindex", verifique que não tem `<meta name="robots" content="noindex">` no HTML
- **Force crawl**: no Search Console, use "Inspecionar URL" e clique em "Solicitar indexação"

### "Analytics não está rastreando visitas"

- Verifique se o script foi inserido no `<head>` do HTML gerado (view-source no navegador)
- Verifique se o ID (G-XXXXXXXXXX ou domain) está correto
- Adblockers bloqueiam GA4 mas não Plausible
- Aguarde 24h para dados aparecerem

### "Preview no LinkedIn/WhatsApp está errado"

- LinkedIn cacheia agressivamente. Use [Post Inspector](https://www.linkedin.com/post-inspector/) e clique em "Inspect" para forçar refresh
- WhatsApp cacheia por 30 dias. Use [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) → cola URL → "Scrape Again"

### "og:image não aparece"

- Confirme que `figuras/capa.png` existe e é acessível publicamente
- Tamanho ideal: 1200×630 px, formato PNG ou JPG, menos de 8 MB
- Se a capa é placeholder, gere uma temporária mesmo (fundo azul, título grande) só para o preview funcionar

---

## Checklist final da Fase 1.4

- [ ] Meta tags OG/Twitter no `_quarto.yml` (automatizado)
- [ ] Schema.org Book JSON-LD (automatizado)
- [ ] `site-url:` correto no `_quarto.yml` (github.io por enquanto)
- [ ] sitemap.xml gerado (Quarto automático)
- [ ] Google Search Console: propriedade criada e verificada
- [ ] Google Search Console: sitemap submetido
- [ ] Analytics configurado (GA4, Plausible, Umami ou nenhum)
- [ ] Capa `figuras/capa.png` existe (mesmo que placeholder)
- [ ] robots.txt criado (opcional)
- [ ] Rich Results testado (após indexação, ~15 dias)

Ao completar, você tem visibilidade orgânica maximizada para o livro.
