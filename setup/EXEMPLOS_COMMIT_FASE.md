# Exemplos de uso do commit-fase.ps1

## Carregar a funcao (dot-source)

Antes de usar, "importar" a funcao na sessao atual:

```powershell
. .\commit-fase.ps1
```

## Exemplo 1: Commit de Fase 1.4 (SEO)

```powershell
Commit-Fase -Titulo "Fase 1.4: SEO completo (schema.org, OG/Twitter, sitemap)" -Arquivos @(
    "_quarto.yml",
    ".gitignore",
    "styles/schema-book.html",
    "styles/seo-meta.html",
    "styles/analytics-*.html",
    "googleec59d4807eff3619.html",
    "setup/SEO_SETUP_GUIA.md",
    "executar-fase-1-4.ps1"
) -AutoPush
```

## Exemplo 2: Commit de novo capitulo escrito

```powershell
Commit-Fase -Titulo "Cap 1: Por que DOE em manufatura (primeira versao)" -Arquivos @(
    "parte-1/cap-01-por-que-doe.qmd",
    "figuras/cap-01/*.png"
) -AutoPush
```

## Exemplo 3: Sem AutoPush (revisar antes de pushar)

```powershell
Commit-Fase -Titulo "WIP: rascunho do Cap 2" -Arquivos @(
    "parte-1/cap-02-metalurgia.qmd"
)
# Push manual depois: git push
```

## Exemplo 4: Multiplos arquivos e mindmaps

```powershell
Commit-Fase -Titulo "Fase 2.1: outline do Cap 1 + mindmap" -Arquivos @(
    "parte-1/cap-01-por-que-doe.qmd",
    "setup/mindmaps/cap-01-outline.mm"
) -AutoPush
```

## Comportamento

- Se algum arquivo nao existe: mostra aviso mas continua com os outros
- Aceita wildcards: `styles/analytics-*.html` pega todos
- Pede confirmacao antes de commitar (S/N)
- Se AutoPush: pusha automaticamente + mostra status do deploy
- Se sem AutoPush: so faz commit local
