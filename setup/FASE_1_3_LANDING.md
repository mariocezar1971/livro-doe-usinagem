# Fase 1.3 - Landing Page de Captura

**Gerado por executar-fase-1-3.ps1**
Ultima atualizacao: 2026-08-14 08:26:58

**Progresso:** 4/6 verificacoes OK

**URL publica:** https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html

---

## 1. em-breve.qmd [x]

**Status:** OK

**Detalhes:** 4078 bytes (substancial)

**Verificada em:** 2026-08-14 08:26:34

---

## 2. em-breve.css [x]

**Status:** OK

**Detalhes:** .\styles\em-breve.css (4019 bytes)

**Verificada em:** 2026-08-14 08:26:35

---

## 3. Registro _quarto.yml [x]

**Status:** OK

**Detalhes:** em-breve.qmd presente

**Verificada em:** 2026-08-14 08:26:35

---

## 4. Formulario Brevo [X]

**Status:** ERRO

**Detalhes:** Nao integrado

**Acao:** Copiar embed do Brevo para em-breve.qmd

**Verificada em:** 2026-08-14 08:26:57

---

## 5. Promessa capitulo gratuito [!]

**Status:** AVISO

**Detalhes:** 1/3 palavras-chave

**Acao:** Reforcar promessa no texto

**Verificada em:** 2026-08-14 08:26:57

---

## 6. URL publica [x]

**Status:** OK

**Detalhes:** HTTP 200 - titulo, brevo

**Verificada em:** 2026-08-14 08:26:58

---

## Comandos uteis

```powershell
# Deploy: renderiza + push (Actions renderiza no servidor)
git add em-breve.qmd em-breve.css _quarto.yml
git commit -m "Fase 1.3: atualizacao landing page"
git push

# Ver deploy rodando
Start-Sleep -Seconds 15
gh run list --repo mariocezar1971/livro-doe-usinagem --limit 1

# Abrir landing publica
Start-Process 'https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html'
```
