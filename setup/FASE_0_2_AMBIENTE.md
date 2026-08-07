# Fase 0.2 - Ambiente de Producao

**Gerado automaticamente por executar-fase-0-2.ps1**
Ultima atualizacao: 2026-08-07 10:56:42

**Diretorio do projeto:** `C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM`

Total de verificacoes: 6 de 6

---

## 1. Quarto CLI [x]

**Status:** OK

**Detalhes:** Versao 1.8.25 em C:\Program Files\Quarto\bin\quarto.exe

**Verificada em:** 2026-08-07 10:56:19

---

## 2. TinyTeX / LaTeX [x]

**Status:** OK

**Detalhes:** TinyTeX presente e funcional

**Verificada em:** 2026-08-07 10:56:40

---

## 3. Diretorio do projeto [x]

**Status:** OK

**Detalhes:** Projeto em C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM

**Verificada em:** 2026-08-07 10:56:40

---

## 4. Configuracao _quarto.yml [!]

**Status:** AVISO

**Detalhes:** html=OK, pdf=AUSENTE, epub=AUSENTE

**Verificada em:** 2026-08-07 10:56:40

---

## 5. Engines R + Python [x]

**Status:** OK

**Detalhes:** R: C:\Program Files\R\R-4.5.1\bin\Rscript.exe | Python: C:\Users\mceza\AppData\Local\Programs\Python\Python313\python.exe

**Verificada em:** 2026-08-07 10:56:42

---

## 6. Estrutura de pastas [x]

**Status:** OK

**Detalhes:** 10/10 pastas, 16/16 capitulos

**Verificada em:** 2026-08-07 10:56:42

---

## Comandos uteis

### Navegar para o projeto
```powershell
cd 'C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM'
```

### Renderizar
```powershell
quarto render --to html          # Apenas HTML (rapido)
quarto render                    # Todos os formatos
quarto render parte-1\cap-01-por-que-doe.qmd  # Um capitulo
```

### Preview (recomendado para escrever)
```powershell
quarto preview                                    # Livro inteiro
quarto preview parte-2\cap-04-fatorial.qmd       # Um capitulo
```

### Abrir HTML pronto
```powershell
start _book\index.html
```
