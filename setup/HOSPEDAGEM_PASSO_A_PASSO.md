# Hospedagem Web — Guia Passo a Passo

Este guia complementa os scripts PowerShell da Fase 0.3 com as **etapas manuais** que não podem ser automatizadas (precisam do seu CPF, cartão e decisões pessoais no painel do Registro.br).

---

## Visão geral do que vamos fazer

```
[Você escreve o livro localmente]
       ↓ git push
[GitHub recebe o código]
       ↓ GitHub Action roda
[Quarto renderiza HTML]
       ↓ Deploy automático
[GitHub Pages serve o livro]
       ↓
[Domínio doeusinagem.com.br aponta para o GitHub]
       ↓
[Leitor acessa https://doeusinagem.com.br]
```

Os scripts PowerShell automatizam tudo exceto **o registro do domínio no Registro.br** (precisa seu CPF e cartão) e **a configuração dos DNS no painel do Registro.br** (precisa você logar com seu CPF).

---

## Ordem de execução

| Etapa | Como | Duração | Custo |
|-------|------|---------|-------|
| 1. Push inicial para GitHub | Script `setup-github-pages.ps1` | 5 min | R$ 0 |
| 2. Aguardar primeiro deploy | Automático | 3-5 min | R$ 0 |
| 3. Validar GitHub Pages funcionando | Script `validar-deploy.ps1` | 1 min | R$ 0 |
| 4. **Registrar domínio Registro.br** | Manual (este documento) | 10 min | **R$ 40/ano** |
| 5. **Configurar DNS no Registro.br** | Manual (este documento) | 5 min | R$ 0 |
| 6. Configurar domínio no GitHub | Manual (este documento) | 2 min | R$ 0 |
| 7. Aguardar propagação DNS | Automático | 1-24h | R$ 0 |
| 8. Aguardar emissão SSL | Automático GitHub | 5-15 min | R$ 0 |
| 9. Validar tudo funcionando | Script `validar-deploy.ps1` | 1 min | R$ 0 |

---

## Etapa 1-3: GitHub (automatizado)

Já está coberto pelos scripts:

```powershell
# Na raiz do projeto LIVRO_DOE_USINAGEM
.\setup\setup-github-pages.ps1
# Aguarde 3-5 minutos para o build inicial
.\setup\validar-deploy.ps1
```

Quando o livro estiver acessível em `https://mariocezar1971.github.io/livro-doe-usinagem/`, prossiga.

---

## Etapa 4: Registrar o domínio no Registro.br

### 4.1. Pré-requisitos

- CPF (já tem)
- Cartão de crédito ou boleto
- E-mail ativo (para validação)

### 4.2. Verificação de disponibilidade

Acesse [https://registro.br](https://registro.br) e use o campo de busca no topo da página.

Digite: **doeusinagem.com.br**

Resultados possíveis:

- **"Domínio disponível"** → prossiga
- **"Domínio já registrado"** → tente alternativas:
  - `livrodoe.com.br`
  - `usinabilidade.com.br`
  - `engexperimentos.com.br`

### 4.3. Registro do domínio

1. Clique em **"Registrar"** ao lado do domínio disponível
2. Faça login com **CPF e senha do gov.br** (mesma do imposto de renda) — *se ainda não tem conta no Registro.br, será criada na hora*
3. Confirme dados de contato:
   - Titular: `Mário Cezar dos Santos Jr.`
   - E-mail de contato: `mariocezarsj@gmail.com`
   - Telefone, endereço
4. Escolha período: **1 ano (R$ 40)** é suficiente para começar — renove antes do vencimento
5. Pagamento: **Pix** (mais rápido), boleto, ou cartão de crédito
6. **Aguarde confirmação** — chega em até 2h por e-mail

### 4.4. Após confirmação

Receberá e-mail confirmando o registro. O domínio já está seu, mas precisa configurar DNS (próxima etapa) para apontar para algum servidor — caso contrário não vai abrir nada.

---

## Etapa 5: Configurar DNS no Registro.br

Esta é a etapa que **faz o domínio apontar para o GitHub Pages**.

### 5.1. Acessar painel DNS

1. Acesse [https://registro.br](https://registro.br) e faça login
2. No menu superior, clique em **"Painel"**
3. Em **"Meus Domínios"**, clique em **doeusinagem.com.br**
4. Procure a aba ou link **"DNS"** ou **"Editar Zona"**

### 5.2. Configurar os 4 registros A (apex domain)

O GitHub Pages publica em 4 endereços IP fixos. Você precisa criar **4 registros A** com os IPs abaixo:

| Tipo | Nome | Valor (IP) | TTL |
|------|------|-----------|-----|
| A | (vazio) ou @ | `185.199.108.153` | 3600 |
| A | (vazio) ou @ | `185.199.109.153` | 3600 |
| A | (vazio) ou @ | `185.199.110.153` | 3600 |
| A | (vazio) ou @ | `185.199.111.153` | 3600 |

**Como cadastrar no painel do Registro.br:**

1. Clique em **"Adicionar registro"**
2. Tipo: **A**
3. Nome/Subdomínio: deixe **em branco** (significa o domínio raiz, "apex")
4. Dados/Valor: `185.199.108.153`
5. TTL: 3600 (1 hora)
6. Salve
7. **Repita os passos 1-6** para os outros 3 IPs

### 5.3. Configurar subdomínio www (opcional, recomendado)

Para que `www.doeusinagem.com.br` também funcione (redirecionando para `doeusinagem.com.br`):

| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| CNAME | www | `mariocezar1971.github.io.` | 3600 |

**Atenção ao ponto final** em `mariocezar1971.github.io.` — alguns painéis exigem, outros não. Se der erro, tente sem o ponto.

### 5.4. Verificar a configuração

No próprio painel, deve aparecer os 5 registros (4 A + 1 CNAME). Pode levar **1-24 horas** para propagar globalmente.

Para testar a propagação:

```powershell
# No PowerShell
Resolve-DnsName doeusinagem.com.br

# Deve retornar 4 IPs do GitHub: 185.199.108.153, .109.153, .110.153, .111.153
```

Ou via web: [https://dnschecker.org/](https://dnschecker.org/) → digite o domínio → veja se resolve para os IPs do GitHub em vários países.

---

## Etapa 6: Configurar domínio no GitHub

### 6.1. Adicionar custom domain no GitHub Pages

1. Acesse `https://github.com/mariocezar1971/livro-doe-usinagem/settings/pages`
2. Em **"Custom domain"**, digite: `doeusinagem.com.br`
3. Clique em **"Save"**

O GitHub fará uma **verificação DNS** automática:

- ✅ Se os DNS já propagaram, aparece um check verde com "DNS check successful"
- ⏳ Se ainda não propagaram, aparece "DNS check unsuccessful — Domain does not resolve to the GitHub Pages server"

No segundo caso, é só aguardar (até 24h) e o GitHub re-verificará automaticamente.

### 6.2. Forçar HTTPS

Depois que o GitHub validar o DNS, na mesma página:

1. Marque **"Enforce HTTPS"**
2. Salve

Isso garante que `http://doeusinagem.com.br` redirecione automaticamente para `https://doeusinagem.com.br`.

---

## Etapa 7-8: Propagação e SSL (automático, aguardar)

### O que acontece nos bastidores

1. **DNS propaga globalmente** — operadoras de internet atualizam suas tabelas. Tempo: 1-24h, tipicamente 2-4h
2. **GitHub detecta DNS válido** — verifica a cada 30 minutos
3. **GitHub solicita certificado SSL** — usando Let's Encrypt, gratuito
4. **Let's Encrypt emite certificado** — leva 5-15 minutos após GitHub solicitar
5. **GitHub instala certificado** — automático

### Sintomas durante a transição

Durante a propagação, você pode ver mensagens estranhas no navegador:

- "Sua conexão não é privada" → certificado ainda não emitido
- "ERR_TOO_MANY_REDIRECTS" → DNS configurado mas Pages ainda não → aguarde
- "404 Not Found no domain customizado" → DNS propagado mas GitHub ainda processando → aguarde

**Todos esses sintomas se resolvem sozinhos em algumas horas.** Não mexa em nada.

---

## Etapa 9: Validação final

Quando você acreditar que tudo está pronto, rode:

```powershell
.\setup\validar-deploy.ps1
```

Resultado esperado:

```
[OK] Repositorio existe
[OK] Ultimo workflow executou com sucesso
[OK] Pages habilitado
[OK] URL responde HTTP 200
[OK] DNS configurado corretamente para GitHub Pages
[OK] Dominio customizado responde HTTP 200 via HTTPS
[OK] Certificado SSL valido (Lets Encrypt via GitHub)
```

Se tudo passar, **a Fase 0.3 está oficialmente concluída** e o livro tem URL pública profissional.

---

## Troubleshooting

### "DNS check unsuccessful" mesmo após várias horas

1. Verifique os 4 IPs (digitar errado é o erro mais comum)
2. Verifique se cadastrou como tipo **A** e não AAAA, CNAME, etc.
3. No painel do Registro.br, verifique se o "Nome" está vazio ou com "@" — não pode ter "www" ou nada
4. Use [https://www.whatsmydns.net/](https://www.whatsmydns.net/) para ver propagação por região

### "Certificate not yet issued"

- Comum nos primeiros 30 minutos após DNS resolver
- GitHub e Let's Encrypt podem levar até 24h em casos raros
- Não tente "Renew certificate" no painel do GitHub se já marcou "Enforce HTTPS" — pode causar loop

### Site abre, mas sem estilos (HTML "feio")

- Verifique o arquivo `_quarto.yml`: a chave `site-url` deve estar como `https://doeusinagem.com.br` (sem trailing slash)
- Se tiver `repo-url` apontando para subdiretório, links podem quebrar
- Rode `quarto render` localmente e veja se reproduz o problema

### Workflow falhando no GitHub Actions

```powershell
# Ver últimos runs
gh run list --repo mariocezar1971/livro-doe-usinagem --limit 5

# Ver log do último run
gh run view --repo mariocezar1971/livro-doe-usinagem --log
```

Erros comuns:
- Falta pacote R → ajustar `setup-r-env.R` e fazer push
- Falta pacote Python → ajustar `requirements.txt` e fazer push
- `.qmd` com sintaxe inválida → rodar `quarto render` localmente para reproduzir

### Quero pausar/retomar o site

GitHub Pages é grátis e sem limite de tráfego. Não há razão para pausar. Para "tirar do ar":

1. Settings → Pages → Source: "None"
2. Mas o livro continua acessível pelo `mariocezar1971.github.io/livro-doe-usinagem`

Para tirar tudo do ar, precisa arquivar o repositório.

---

## Custos consolidados

| Item | Recorrência | Valor |
|------|-------------|-------|
| Domínio `.com.br` (Registro.br) | Anual | R$ 40 |
| Hospedagem (GitHub Pages) | — | R$ 0 |
| Certificado SSL (Let's Encrypt) | — | R$ 0 |
| CDN global (GitHub) | — | R$ 0 |
| **Total** | | **R$ 40/ano** |

**Limite de tráfego do GitHub Pages:** 100 GB/mês (mais do que suficiente para um livro técnico nichado com ~10.000 visitas/mês).

---

## Checklist final

Quando todos estes estiverem marcados, a Fase 0.3 está concluída:

- [ ] Repositório `mariocezar1971/livro-doe-usinagem` criado
- [ ] Primeiro `git push` enviado
- [ ] GitHub Action passou (workflow verde)
- [ ] URL `https://mariocezar1971.github.io/livro-doe-usinagem/` acessível
- [ ] Domínio `doeusinagem.com.br` registrado no Registro.br
- [ ] 4 registros A configurados no Registro.br
- [ ] CNAME `www` configurado (opcional)
- [ ] Custom domain configurado no GitHub Pages
- [ ] "Enforce HTTPS" marcado
- [ ] DNS propagado globalmente (verificável em dnschecker.org)
- [ ] `https://doeusinagem.com.br` abre o livro
- [ ] Certificado SSL válido (cadeado no navegador)
- [ ] Script `validar-deploy.ps1` retorna todos OKs

Quando este checklist estiver completo, **você tem um livro online profissional acessível por URL própria, com infraestrutura praticamente gratuita e que vai escalar para milhares de visitantes sem custo adicional**.
