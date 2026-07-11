#!/usr/bin/env python3
"""
Migração da tese docx para qmd bruto + catálogo de figuras.

Etapas executadas:
1. Converte docx -> qmd via pandoc (preservando equações LaTeX)
2. Extrai todas as figuras para pasta figuras/media/
3. Analisa cada figura: formato, tamanho, dimensões
4. Localiza cada figura no qmd bruto (frase de contexto + legenda)
5. Classifica automaticamente por heurística:
   - WMF/EMF: vetorial, gráfico/esquema -> sugestão REFAZER em SVG
   - TIFF grande: foto/micrografia -> sugestão MANTER
   - PNG/JPG médio: figura raster comum -> sugestão avaliar
   - Muito pequeno (<3KB): provavelmente equação -> sugestão DESCARTAR
6. Gera catálogo em CSV + relatório Markdown navegável com previews

Uso:
    python migrar-tese.py <tese.docx> [--output-dir migracao/]

Requer: pandoc, Python 3.10+, Pillow.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path


# ---------------------------------------------------------------------------
# Estruturas
# ---------------------------------------------------------------------------

@dataclass
class Figura:
    """Metadados de uma figura extraída."""
    filename: str
    caminho_relativo: str
    formato: str                    # WMF, TIFF, EMF, PNG, JPG
    tamanho_bytes: int
    tamanho_kb: float
    largura_px: int = 0
    altura_px: int = 0
    modo_cor: str = ""              # RGB, CMYK, L, etc.
    md5: str = ""

    # Contextualização no texto
    linha_referencia: int = 0       # linha no qmd onde a figura aparece
    contexto_antes: str = ""        # 200 chars antes
    legenda: str = ""               # texto Figura X.Y - ...
    capitulo_estimado: str = ""     # I, II, III, etc.

    # Classificação
    categoria_sugerida: str = ""    # MANTER, REFAZER, DESCARTAR, AVALIAR
    razao_sugestao: str = ""
    prioridade: int = 0             # 1=alta 2=media 3=baixa


# ---------------------------------------------------------------------------
# Etapa 1: conversão docx -> qmd via pandoc
# ---------------------------------------------------------------------------

def converter_docx_para_qmd(docx: Path, saida_qmd: Path, saida_figuras: Path) -> None:
    """Chama pandoc para converter docx em qmd, extraindo figuras."""
    saida_qmd.parent.mkdir(parents=True, exist_ok=True)
    saida_figuras.mkdir(parents=True, exist_ok=True)

    cmd = [
        "pandoc",
        str(docx),
        "-f", "docx",
        "-t", "markdown",
        f"--extract-media={saida_figuras}",
        "--wrap=none",
        "-o", str(saida_qmd),
    ]

    print(f"  Executando pandoc...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"pandoc falhou:\n{result.stderr}")

    tamanho = saida_qmd.stat().st_size
    print(f"  qmd bruto: {tamanho:,} bytes ({tamanho // 1024} KB)")


# ---------------------------------------------------------------------------
# Etapa 2: extração de metadados de figura
# ---------------------------------------------------------------------------

def analisar_figura(caminho: Path, base: Path) -> Figura:
    """Extrai metadados de uma figura."""
    tamanho = caminho.stat().st_size
    formato = caminho.suffix.lower().lstrip(".").upper()

    fig = Figura(
        filename=caminho.name,
        caminho_relativo=str(caminho.relative_to(base)),
        formato=formato,
        tamanho_bytes=tamanho,
        tamanho_kb=round(tamanho / 1024, 1),
    )

    # MD5 para deduplicação
    fig.md5 = hashlib.md5(caminho.read_bytes()).hexdigest()[:8]

    # Dimensões via Pillow (para formatos suportados)
    try:
        from PIL import Image
        with Image.open(caminho) as img:
            fig.largura_px, fig.altura_px = img.size
            fig.modo_cor = img.mode
    except Exception:
        # WMF/EMF geralmente não abrem via Pillow
        pass

    return fig


# ---------------------------------------------------------------------------
# Etapa 3: localizar figuras no qmd e capturar contexto
# ---------------------------------------------------------------------------

def localizar_figuras_no_qmd(qmd: Path, figuras: dict[str, Figura]) -> None:
    """
    Percorre o qmd procurando referências às figuras extraídas.
    Captura contexto (frase antes) e legenda (linha seguinte).
    """
    texto = qmd.read_text(encoding="utf-8")
    linhas = texto.split("\n")

    # Padrão pandoc: ![](figuras/media/imageN.wmf){...}
    padrao_ref = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")

    for num_linha, linha in enumerate(linhas, 1):
        for match in padrao_ref.finditer(linha):
            caminho = match.group(1)
            nome = Path(caminho).name

            if nome not in figuras:
                continue

            fig = figuras[nome]
            fig.linha_referencia = num_linha

            # Contexto: linhas anteriores (buscando até 3 linhas de conteúdo)
            contexto = []
            for i in range(max(0, num_linha - 5), num_linha - 1):
                if i < len(linhas) and linhas[i].strip():
                    contexto.append(linhas[i].strip())
            fig.contexto_antes = " ".join(contexto)[-250:]

            # Legenda: procurar "Figura X.Y" nas próximas 3 linhas
            for i in range(num_linha, min(num_linha + 4, len(linhas))):
                m = re.search(
                    r"(Figura\s+[\d\.]+\s*[-–—:]?\s*[^\.]{5,200})",
                    linhas[i] if i < len(linhas) else "",
                    re.IGNORECASE,
                )
                if m:
                    fig.legenda = m.group(1).strip()[:200]
                    break

            # Capítulo estimado: procurar retroativamente
            for i in range(num_linha, 0, -1):
                if i - 1 < len(linhas):
                    m = re.search(
                        r"CAP[IÍ]TULO\s+([IVX]+)",
                        linhas[i - 1],
                        re.IGNORECASE,
                    )
                    if m:
                        fig.capitulo_estimado = m.group(1).upper()
                        break


# ---------------------------------------------------------------------------
# Etapa 4: classificação heurística
# ---------------------------------------------------------------------------

def classificar_figura(fig: Figura) -> None:
    """
    Aplica heurística para sugerir MANTER, REFAZER, DESCARTAR ou AVALIAR.

    Regras:
    - WMF/EMF pequeno (<15 KB): provável equação -> DESCARTAR (recriar em LaTeX)
    - WMF/EMF médio/grande: gráfico ou esquema vetorial -> REFAZER em SVG (qualidade)
    - TIFF grande (>200 KB): foto/micrografia -> MANTER (converter PNG p/ web)
    - TIFF pequeno: micrografia pequena -> AVALIAR
    - PNG/JPG: raster comum -> AVALIAR caso a caso
    """
    fmt = fig.formato

    # Formatos vetoriais Microsoft
    if fmt in ("WMF", "EMF"):
        if fig.tamanho_kb < 15:
            fig.categoria_sugerida = "DESCARTAR"
            fig.razao_sugestao = "Provável equação/símbolo — recriar em LaTeX inline"
            fig.prioridade = 3
        elif fig.tamanho_kb < 100:
            fig.categoria_sugerida = "REFAZER"
            fig.razao_sugestao = "Vetorial pequeno — redesenhar em SVG (ggplot2/Inkscape)"
            fig.prioridade = 2
        else:
            fig.categoria_sugerida = "REFAZER"
            fig.razao_sugestao = "Vetorial complexo — redesenhar como gráfico ou esquema moderno"
            fig.prioridade = 1

    # TIFF (raster de alta qualidade)
    elif fmt == "TIFF":
        if fig.tamanho_kb > 500:
            fig.categoria_sugerida = "MANTER"
            fig.razao_sugestao = "Foto/micrografia de alta qualidade — converter para PNG otimizado"
            fig.prioridade = 1
        elif fig.tamanho_kb > 100:
            fig.categoria_sugerida = "MANTER"
            fig.razao_sugestao = "Micrografia — converter para PNG otimizado (web)"
            fig.prioridade = 2
        else:
            fig.categoria_sugerida = "AVALIAR"
            fig.razao_sugestao = "Raster pequeno — verificar resolução e uso"
            fig.prioridade = 3

    # PNG/JPG (raster comum)
    elif fmt in ("PNG", "JPG", "JPEG"):
        if fig.tamanho_kb > 100:
            fig.categoria_sugerida = "MANTER"
            fig.razao_sugestao = "Raster comum de tamanho adequado"
            fig.prioridade = 2
        else:
            fig.categoria_sugerida = "AVALIAR"
            fig.razao_sugestao = "Raster pequeno — verificar qualidade"
            fig.prioridade = 3

    else:
        fig.categoria_sugerida = "AVALIAR"
        fig.razao_sugestao = f"Formato incomum ({fmt}) — inspeção manual"
        fig.prioridade = 3

    # Ajustar prioridade se tiver contexto (figura referenciada tem uso claro)
    if fig.legenda and fig.prioridade > 1:
        fig.prioridade -= 1


# ---------------------------------------------------------------------------
# Etapa 5: geração do catálogo (CSV + Markdown)
# ---------------------------------------------------------------------------

def gerar_csv(figuras: list[Figura], saida: Path) -> None:
    """Gera catálogo CSV para análise em Excel/Sheets."""
    campos = [
        "filename", "formato", "tamanho_kb", "largura_px", "altura_px",
        "modo_cor", "categoria_sugerida", "prioridade", "capitulo_estimado",
        "linha_referencia", "legenda", "razao_sugestao", "contexto_antes",
        "md5",
    ]
    with open(saida, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=campos)
        writer.writeheader()
        for fig in figuras:
            row = {k: getattr(fig, k, "") for k in campos}
            writer.writerow(row)


def gerar_relatorio_md(figuras: list[Figura], saida: Path, docx_nome: str) -> None:
    """Gera relatório em Markdown navegável."""
    from collections import Counter

    total = len(figuras)
    por_categoria = Counter(f.categoria_sugerida for f in figuras)
    por_formato = Counter(f.formato for f in figuras)
    por_capitulo = Counter(f.capitulo_estimado for f in figuras if f.capitulo_estimado)
    com_legenda = sum(1 for f in figuras if f.legenda)

    volume_mb = sum(f.tamanho_bytes for f in figuras) / 1024 / 1024

    md = f"""# Catálogo de Figuras — Migração da Tese

**Fonte:** `{docx_nome}`
**Total de figuras extraídas:** {total}
**Volume total:** {volume_mb:.1f} MB
**Com legenda identificada:** {com_legenda} ({100 * com_legenda // max(total, 1)}%)

## Distribuição por categoria sugerida

| Categoria | Quantidade | % | Ação recomendada |
|-----------|-----------|---|------------------|
"""
    acoes = {
        "MANTER": "Converter TIFF/raster para PNG otimizado; usar como está",
        "REFAZER": "Redesenhar em SVG (Inkscape/ggplot2/draw.io) para qualidade tipográfica",
        "DESCARTAR": "Recriar em LaTeX inline (equações, símbolos, marcadores)",
        "AVALIAR": "Decisão manual — inspecionar a figura",
    }
    for cat, n in por_categoria.most_common():
        acao = acoes.get(cat, "—")
        md += f"| {cat} | {n} | {100 * n // total}% | {acao} |\n"

    md += "\n## Distribuição por formato\n\n"
    for fmt, n in por_formato.most_common():
        md += f"- `{fmt}`: {n}\n"

    if por_capitulo:
        md += "\n## Distribuição por capítulo (estimado)\n\n"
        for cap, n in sorted(por_capitulo.items()):
            md += f"- Capítulo {cap}: {n} figuras\n"

    # Top 20 figuras de alta prioridade
    md += "\n## Figuras de ALTA PRIORIDADE (top 20)\n\n"
    md += "Estas são as figuras mais importantes de manter/refazer conforme heurística.\n\n"
    md += "| # | Arquivo | Formato | Tamanho | Categoria | Cap | Legenda |\n"
    md += "|---|---------|---------|---------|-----------|-----|---------|\n"
    alta_prio = sorted(figuras, key=lambda f: (f.prioridade, -f.tamanho_bytes))[:20]
    for i, f in enumerate(alta_prio, 1):
        leg = (f.legenda or "—")[:60].replace("|", "\\|")
        md += (
            f"| {i} | `{f.filename}` | {f.formato} | {f.tamanho_kb} KB | "
            f"**{f.categoria_sugerida}** | {f.capitulo_estimado or '?'} | {leg} |\n"
        )

    # Lista completa por categoria
    for categoria in ("MANTER", "REFAZER", "DESCARTAR", "AVALIAR"):
        figs_cat = [f for f in figuras if f.categoria_sugerida == categoria]
        if not figs_cat:
            continue
        md += f"\n## Todas as figuras: {categoria} ({len(figs_cat)})\n\n"
        md += "<details><summary>Expandir lista</summary>\n\n"
        md += "| Arquivo | Tamanho | Cap | Legenda |\n|---------|---------|-----|---------|\n"
        for f in sorted(figs_cat, key=lambda x: (x.capitulo_estimado, x.filename)):
            leg = (f.legenda or "—")[:80].replace("|", "\\|")
            md += (
                f"| `{f.filename}` | {f.tamanho_kb} KB | "
                f"{f.capitulo_estimado or '?'} | {leg} |\n"
            )
        md += "\n</details>\n"

    md += """

## Como usar este catálogo

### Passo 1: revisar categorias
Abra o `catalogo-figuras.csv` no Excel ou LibreOffice Calc. Cada linha é uma figura, com sugestão automática de categoria e razão.

Você pode:
- Mudar `categoria_sugerida` conforme sua decisão real
- Anotar em uma coluna extra ("meu_plano", "usar_no_cap") como pretende usar cada figura no livro

### Passo 2: ações por categoria

**MANTER** — figuras que vão direto para o livro:
- Se for TIFF/raster grande, converter para PNG otimizado (ver script `converter-tiff-png.ps1`)
- Guardar em `figuras/` do projeto Quarto com nome descritivo

**REFAZER** — vetoriais que devem virar SVG:
- Abrir no LibreOffice Draw ou Inkscape
- Refazer/aprimorar em SVG limpo
- Alternativa moderna: recriar gráficos em `ggplot2` (R) ou `matplotlib` (Python) reprodutíveis

**DESCARTAR** — equações e símbolos pequenos:
- Recriar como LaTeX inline no texto (`$E = mc^2$`)
- Não copiar como imagem para o livro

**AVALIAR** — decisão caso a caso:
- Abrir a figura e decidir manualmente

### Passo 3: reexportação
Após decidir, use o script `reexportar-figuras.ps1` para:
- Copiar TIFFs mantidos para PNG otimizado
- Converter WMFs marcados como REFAZER para SVG (via LibreOffice)
- Descartar figuras marcadas como DESCARTAR (não copiar para o projeto)
"""

    saida.write_text(md, encoding="utf-8")


# ---------------------------------------------------------------------------
# Etapa 6: separação em arquivos por capítulo
# ---------------------------------------------------------------------------

def separar_qmd_por_capitulo(qmd: Path, saida_dir: Path) -> None:
    """
    Divide o qmd bruto em arquivos separados por capítulo.
    Útil para trabalhar em cada capítulo separadamente durante a reescrita.
    """
    saida_dir.mkdir(parents=True, exist_ok=True)
    texto = qmd.read_text(encoding="utf-8")
    linhas = texto.split("\n")

    # Localizar inícios de capítulos
    capitulos = {}
    padrao_cap = re.compile(r"CAP[IÍ]TULO\s+([IVX]+)", re.IGNORECASE)

    inicio_atual = 0
    cap_atual = "pre-textual"

    for i, linha in enumerate(linhas):
        m = padrao_cap.search(linha)
        if m:
            # Salvar capítulo anterior
            if i > inicio_atual:
                capitulos.setdefault(cap_atual, []).extend(linhas[inicio_atual:i])
            cap_atual = m.group(1).upper()
            inicio_atual = i

    # Último bloco
    if inicio_atual < len(linhas):
        capitulos.setdefault(cap_atual, []).extend(linhas[inicio_atual:])

    # Salvar cada capítulo
    for cap, conteudo in capitulos.items():
        nome_arquivo = f"tese-cap-{cap.lower()}.qmd"
        saida = saida_dir / nome_arquivo
        saida.write_text("\n".join(conteudo), encoding="utf-8")

    return capitulos


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("docx", type=Path, help="Arquivo .docx da tese")
    parser.add_argument(
        "--output-dir", "-o", type=Path, default=Path("migracao"),
        help="Diretório de saída (default: migracao/)",
    )
    args = parser.parse_args()

    if not args.docx.exists():
        print(f"ERRO: arquivo não encontrado: {args.docx}", file=sys.stderr)
        sys.exit(1)

    args.output_dir.mkdir(parents=True, exist_ok=True)

    qmd_dir = args.output_dir / "qmd"
    figuras_dir = args.output_dir / "figuras"
    catalogo_dir = args.output_dir / "catalogo"

    print(f"\n=== Fase 1.1: Migração da tese ===\n")
    print(f"Entrada:  {args.docx}")
    print(f"Saída:    {args.output_dir}/\n")

    # 1. Conversão docx -> qmd
    print("[1/5] Convertendo docx -> qmd via pandoc...")
    qmd_bruto = qmd_dir / "tese-bruta.qmd"
    converter_docx_para_qmd(args.docx, qmd_bruto, figuras_dir)

    # 2. Analisar figuras
    print("\n[2/5] Analisando figuras extraídas...")
    figuras: dict[str, Figura] = {}
    figuras_lista: list[Figura] = []
    for caminho in sorted(figuras_dir.rglob("*")):
        if caminho.is_file():
            fig = analisar_figura(caminho, figuras_dir)
            figuras[fig.filename] = fig
            figuras_lista.append(fig)
    print(f"  {len(figuras_lista)} figuras processadas")

    # 3. Localizar no qmd
    print("\n[3/5] Localizando figuras no qmd e capturando contexto...")
    localizar_figuras_no_qmd(qmd_bruto, figuras)
    com_ref = sum(1 for f in figuras_lista if f.linha_referencia > 0)
    com_legenda = sum(1 for f in figuras_lista if f.legenda)
    print(f"  {com_ref} figuras com referência no qmd")
    print(f"  {com_legenda} com legenda identificada")

    # 4. Classificar
    print("\n[4/5] Classificando figuras (heurística)...")
    for fig in figuras_lista:
        classificar_figura(fig)

    from collections import Counter
    dist = Counter(f.categoria_sugerida for f in figuras_lista)
    for cat, n in dist.most_common():
        print(f"  {cat}: {n}")

    # 5. Separar qmd por capítulo
    print("\n[5/5] Separando qmd por capítulo e gerando catálogo...")
    caps = separar_qmd_por_capitulo(qmd_bruto, qmd_dir)
    print(f"  {len(caps)} capítulos separados")

    # Salvar catálogo
    catalogo_dir.mkdir(parents=True, exist_ok=True)
    csv_path = catalogo_dir / "catalogo-figuras.csv"
    md_path = catalogo_dir / "catalogo-figuras.md"

    gerar_csv(figuras_lista, csv_path)
    gerar_relatorio_md(figuras_lista, md_path, args.docx.name)
    print(f"  CSV: {csv_path}")
    print(f"  Relatório MD: {md_path}")

    print("\n=== Migração concluída ===\n")
    print(f"Consulte:")
    print(f"  - Relatório: {md_path}")
    print(f"  - Catálogo CSV: {csv_path}")
    print(f"  - qmd bruto: {qmd_bruto}")
    print(f"  - qmd por capítulo: {qmd_dir}/tese-cap-*.qmd")
    print(f"  - Figuras: {figuras_dir}")


if __name__ == "__main__":
    main()
