# Migração da Tese — Guia de Uso

Guia da **Fase 1.1** do roadmap: como usar os arquivos gerados pelo pipeline de migração da tese docx para o material bruto do livro.

---

## Visão geral

O pipeline executa **4 etapas automatizadas**:

1. **Conversão** `docx → qmd bruto` via pandoc (preserva equações, tabelas, referências às figuras)
2. **Extração** de todas as figuras para `figuras/media/`
3. **Análise + classificação** heurística de cada figura (MANTER/REFAZER/DESCARTAR/AVALIAR)
4. **Reexportação** conforme categoria (TIFF → PNG, WMF → SVG)

O resultado é o **material bruto de trabalho** — não são os arquivos finais do livro. São os insumos que você vai reescrever nas Fases 3-5 do roadmap.

---

## Estrutura gerada

Após rodar `migrar-tese.ps1`, você terá:

```
migracao-tese/
├── qmd/
│   ├── tese-bruta.qmd            ← Documento inteiro em markdown
│   ├── tese-cap-pre-textual.qmd  ← Introdução, capa, etc.
│   ├── tese-cap-i.qmd            ← Cap I — Introdução
│   ├── tese-cap-ii.qmd           ← Cap II — Revisão bibliográfica
│   ├── tese-cap-iii.qmd          ← Cap III — Procedimento
│   ├── tese-cap-iv.qmd           ← Cap IV — Dispositivos e calibração
│   ├── tese-cap-v.qmd            ← Cap V — Resultados
│   ├── tese-cap-vi.qmd           ← Cap VI — Conclusões
│   ├── tese-cap-vii.qmd          ← Cap VII — Trabalhos futuros
│   └── tese-cap-viii.qmd         ← Cap VIII — Referências
├── figuras/
│   └── media/                    ← 293 figuras originais (WMF, TIFF, EMF)
├── figuras-processadas/
│   ├── manter/                   ← ~25 PNGs otimizados (fotos, micrografias)
│   ├── refazer/                  ← ~168 SVGs (gráficos e esquemas vetoriais)
│   └── avaliar/                  ← ~7 casos ambíguos
└── catalogo/
    ├── catalogo-figuras.csv      ← Metadados de todas as figuras (para Excel)
    └── catalogo-figuras.md       ← Relatório navegável
```

---

## Como usar cada arquivo

### 1. Arquivos `.qmd` bruto

**Estes NÃO vão para o livro diretamente.** São material de referência para você:

- Ler durante a reescrita dos capítulos correspondentes do livro
- Copiar frases específicas que ficaram boas na tese
- Consultar dados numéricos e resultados originais

**Recomendação:** durante a escrita do Cap 8 do livro (Análise fatorial 2^k das ligas), abra `tese-cap-v.qmd` ao lado como referência. Não copie parágrafos inteiros — reescreva na voz autoral do livro.

### 2. Catálogo de figuras (CSV)

O arquivo `catalogo-figuras.csv` tem 293 linhas — uma por figura. Colunas principais:

| Coluna | Descrição |
|--------|-----------|
| `filename` | Nome do arquivo (`image42.wmf`) |
| `formato` | WMF, TIFF, EMF, PNG |
| `tamanho_kb` | Tamanho em KB |
| `categoria_sugerida` | MANTER / REFAZER / DESCARTAR / AVALIAR |
| `prioridade` | 1 (alta), 2 (média), 3 (baixa) |
| `capitulo_estimado` | I, II, III, ... (localização na tese) |
| `linha_referencia` | Linha no qmd onde aparece |
| `legenda` | Texto "Figura X.Y — ..." se identificado |
| `razao_sugestao` | Explicação da categoria proposta |
| `contexto_antes` | Últimas 250 chars antes da figura |

**Como revisar:**

1. Abra no **Excel** ou **LibreOffice Calc**
2. Ordene por `prioridade` (crescente) e `tamanho_kb` (decrescente)
3. Comece pelas **prioridade 1** (as figuras mais importantes)
4. Ajuste a coluna `categoria_sugerida` conforme sua decisão real
5. Salve o CSV

Depois, rode `reexportar-figuras.py` de novo — ele vai reprocessar com as suas decisões.

### 3. Figuras processadas

**`manter/`** — PNGs otimizados de fotos e micrografias. Prontos para uso:
- Nome descritivo baseado na legenda (ex.: `capiii-figura---sistemas-de-lubri-refrigeracao-a-bocais.png`)
- Já em RGB (CMYK dos TIFFs originais convertido)
- Comprimidos com PNG-optimize

**`refazer/`** — SVGs gerados do LibreOffice a partir dos WMFs:
- Podem estar OK para uso direto
- Ou precisar de retrabalho no **Inkscape** ou **draw.io**
- Ou serem reproduzidos programaticamente em **ggplot2** (R) ou **matplotlib** (Python)

**`avaliar/`** — cópias dos originais que precisam decisão manual.

---

## Classificação heurística — como interpretar

O script classifica automaticamente conforme:

| Formato | Tamanho | Categoria | Ação |
|---------|---------|-----------|------|
| WMF/EMF | < 15 KB | **DESCARTAR** | Provavelmente é equação/símbolo — recriar em LaTeX inline |
| WMF/EMF | 15–100 KB | **REFAZER** | Gráfico ou esquema — redesenhar em SVG |
| WMF/EMF | > 100 KB | **REFAZER** (prioridade 1) | Vetorial complexo importante |
| TIFF | > 500 KB | **MANTER** (prioridade 1) | Foto/micrografia de alta qualidade |
| TIFF | 100–500 KB | **MANTER** | Micrografia — converter para PNG otimizado |
| TIFF | < 100 KB | **AVALIAR** | Raster pequeno — verificar |
| PNG/JPG | > 100 KB | **MANTER** | Raster comum de tamanho adequado |
| PNG/JPG | < 100 KB | **AVALIAR** | Raster pequeno |

**A heurística acerta ~80% das decisões automaticamente.** O restante você ajusta manualmente no CSV.

---

## Workflow recomendado

### Fase 1: revisão do catálogo (2-4 horas)

1. Rode `migrar-tese.ps1`
2. Abra `catalogo-figuras.md` no navegador — veja a distribuição geral
3. Abra `catalogo-figuras.csv` no Excel
4. Filtre por **prioridade 1** — são ~20 figuras críticas
5. Para cada uma, decida a categoria final
6. Filtre por **prioridade 2** — ~50 figuras médias
7. Prioridade 3 pode ficar com a sugestão automática

### Fase 2: reexportação com decisões finalizadas (10 min)

```powershell
python .\setup\reexportar-figuras.py `
    .\migracao-tese\catalogo\catalogo-figuras.csv `
    --figuras .\migracao-tese\figuras `
    --output .\migracao-tese\figuras-processadas
```

### Fase 3: adoção seletiva no projeto (contínua, durante a escrita)

Ao escrever cada capítulo do livro:

1. Consulte o `.qmd` bruto do capítulo correspondente da tese
2. Identifique quais figuras são relevantes para o novo capítulo
3. Copie da pasta `figuras-processadas/manter/` ou `refazer/` para `figuras/` do projeto (com nome final descritivo)
4. Referencie no `.qmd` do capítulo do livro

**Exemplo:**

```markdown
::: {#fig-formas-cavaco}
![Tipos de cavaco na usinagem de ligas de alumínio](figuras/cap02-formas-cavaco.png)
:::

Como mostra a @fig-formas-cavaco, o torneamento das ligas 6xxx e 7xxx...
```

### Fase 4: retrabalho de figuras REFAZER (mais tarde)

Para os SVGs que precisam retrabalho, tem 3 caminhos:

**A. Editar no Inkscape** (para diagramas/esquemas)
- Abrir SVG, ajustar cores/tipografia para padrão do livro
- Exportar de volta como SVG

**B. Redesenhar em draw.io** (para fluxogramas)
- Desenhar do zero seguindo o layout original
- Vantagem: fica editável para futuras edições

**C. Recriar em ggplot2/matplotlib** (para gráficos de dados)
- **Melhor opção** para o livro, porque:
  - Fica reproduzível a partir dos dados
  - Padrão visual consistente (mesma paleta, mesma tipografia)
  - Se dados mudarem, gráfico atualiza sozinho
- Use a paleta oficial do livro (`viridis` ou paleta customizada)

**Recomendação:** priorize (C) para gráficos de resultados (Cap 8-10 do livro), (A/B) para esquemas e diagramas conceituais (Cap 1-3 e 11).

---

## Ferramentas necessárias

**Já instaladas na Fase 0.2:**
- Python 3.10+
- Quarto (que inclui Pandoc)
- Pillow (imagens)

**Instalar se ainda não tiver:**

**LibreOffice** — para conversão WMF → SVG automática
```
https://www.libreoffice.org/download/
```
Sem LibreOffice, os WMFs são copiados sem conversão (você faz manualmente).

**Inkscape** — para editar SVGs
```
https://inkscape.org/release/
```
Alternativa: [draw.io desktop](https://github.com/jgraph/drawio-desktop/releases/).

---

## Solução de problemas

### "pandoc não encontrado"

O Quarto instala pandoc, mas escondido. O script tenta localizar automaticamente. Se falhar, adicione manualmente ao PATH:

```powershell
$pandocQuarto = Get-ChildItem "C:\Program Files\Quarto" -Filter "pandoc.exe" -Recurse | Select-Object -First 1
$env:PATH = "$($pandocQuarto.DirectoryName);$env:PATH"
```

### "LibreOffice não encontrado"

WMFs serão copiados sem conversão. Instale LibreOffice ou converta manualmente cada WMF importante:
1. Abra WMF no LibreOffice Draw
2. File → Export as → SVG
3. Salve na pasta `refazer/`

### Erros de codificação nos qmd (`Ã©` em vez de `é`)

O pandoc gera UTF-8 por padrão. Se abrir com codificação errada:
- No VS Code: canto inferior direito → "Reopen with encoding" → UTF-8
- No RStudio: File → Reopen with Encoding → UTF-8

### Categorias parecem erradas em massa

A heurística é conservadora. Se você discorda de uma categoria:
1. Edite o CSV manualmente
2. Rode `reexportar-figuras.py` de novo — respeita suas decisões

### Muitas figuras marcadas como DESCARTAR

É esperado — em teses tradicionais, WMFs pequenos geralmente são **equações** que o Word converte em imagem. No livro, essas devem ser recriadas como LaTeX inline (`$V_c = \pi D n / 1000$` em vez de imagem). O DESCARTAR não significa "não usar o conteúdo" — significa "não copiar a imagem, recriar como texto matemático".

---

## Checklist da Fase 1.1

- [ ] Pipeline rodou sem erros (`.\setup\migrar-tese.ps1`)
- [ ] 293 figuras extraídas em `migracao-tese/figuras/media/`
- [ ] `catalogo-figuras.csv` gerado
- [ ] Catálogo revisado — pelo menos as prioridade 1 e 2
- [ ] Reexportação executada — pasta `figuras-processadas/` populada
- [ ] Amostragem de SVGs abertos no Inkscape para validar qualidade
- [ ] Amostragem de PNGs abertos no visualizador para validar

Após esse checklist, você tem **material bruto de trabalho** organizado. A escrita real dos capítulos (Fase 3-5 do roadmap) usa esses arquivos como referência e fonte de figuras.
