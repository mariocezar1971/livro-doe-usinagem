#!/usr/bin/env python3
"""
Reexporta figuras conforme categoria decidida no catálogo CSV.

Lê o `catalogo-figuras.csv` (possivelmente editado manualmente pelo autor)
e aplica as ações:

- MANTER (TIFF) -> converte para PNG otimizado, salva em figuras-final/
- REFAZER (WMF/EMF) -> converte para SVG via LibreOffice (se disponível)
                       ou copia para figuras-a-refazer/ para trabalho manual
- DESCARTAR -> ignora (não copia para pasta final)
- AVALIAR -> copia para figuras-avaliar/ com nome descritivo

Uso:
    python reexportar-figuras.py <catalogo.csv> --figuras <dir> --output <dir>

Requer: ImageMagick (`convert`) para TIFF->PNG; LibreOffice opcional para WMF->SVG.
"""

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
import sys
from pathlib import Path


def sanitizar_nome(texto: str, max_len: int = 60) -> str:
    """Cria um nome de arquivo seguro a partir de um texto."""
    import re
    texto = texto.lower()
    texto = re.sub(r"[^\w\s\-]", "", texto)
    texto = re.sub(r"\s+", "-", texto).strip("-")
    return texto[:max_len]


def converter_tiff_para_png(entrada: Path, saida: Path, qualidade: int = 95) -> bool:
    """Converte TIFF para PNG otimizado.

    Tenta ImageMagick primeiro; fallback para Pillow (que trata TIFFs CMYK
    proprietários melhor que ImageMagick em alguns casos).
    """
    saida.parent.mkdir(parents=True, exist_ok=True)

    # Tentativa 1: ImageMagick (mais rápido)
    try:
        subprocess.run(
            ["convert", str(entrada), "-quality", str(qualidade),
             "-strip", str(saida)],
            check=True, capture_output=True, timeout=60
        )
        if saida.exists() and saida.stat().st_size > 100:
            return True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Tentativa 2: Pillow (melhor com TIFFs CMYK proprietários)
    try:
        from PIL import Image
        with Image.open(entrada) as img:
            # Converter CMYK/outros para RGB antes de salvar PNG
            if img.mode == "CMYK":
                img = img.convert("RGB")
            elif img.mode not in ("RGB", "RGBA", "L", "LA"):
                img = img.convert("RGB")
            img.save(saida, "PNG", optimize=True)
        return saida.exists()
    except Exception:
        return False


def converter_wmf_para_svg(entrada: Path, saida: Path) -> bool:
    """Converte WMF/EMF para SVG via LibreOffice headless."""
    saida.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(
            ["libreoffice", "--headless", "--convert-to", "svg",
             "--outdir", str(saida.parent), str(entrada)],
            capture_output=True, timeout=60
        )
        # LibreOffice salva com nome original mudando extensão
        svg_gerado = saida.parent / (entrada.stem + ".svg")
        if svg_gerado.exists() and svg_gerado != saida:
            svg_gerado.rename(saida)
        return saida.exists()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path, help="Arquivo catalogo-figuras.csv")
    parser.add_argument("--figuras", type=Path, required=True,
                        help="Diretório onde estão as figuras originais")
    parser.add_argument("--output", type=Path, default=Path("figuras-processadas"),
                        help="Diretório de saída")
    parser.add_argument("--dry-run", action="store_true",
                        help="Simular sem gerar arquivos")
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"ERRO: CSV não encontrado: {args.csv}", file=sys.stderr)
        sys.exit(1)

    # Preparar pastas de saída
    dir_manter = args.output / "manter"
    dir_refazer = args.output / "refazer"
    dir_avaliar = args.output / "avaliar"

    # Estatísticas
    stats = {"MANTER": 0, "REFAZER": 0, "DESCARTAR": 0, "AVALIAR": 0}
    convertidas = {"TIFF_PNG": 0, "WMF_SVG": 0, "COPIADAS": 0, "FALHAS": 0}

    print(f"\n=== Reexportação de figuras ===\n")
    print(f"CSV:      {args.csv}")
    print(f"Figuras:  {args.figuras}")
    print(f"Saída:    {args.output}\n")

    with open(args.csv, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    for row in rows:
        filename = row.get("filename", "").strip()
        categoria = row.get("categoria_sugerida", "").strip().upper()
        formato = row.get("formato", "").strip().upper()
        legenda = row.get("legenda", "").strip()
        cap = row.get("capitulo_estimado", "").strip()

        if not filename:
            continue

        entrada = args.figuras / "media" / filename
        if not entrada.exists():
            print(f"  [!] Não encontrado: {filename}")
            continue

        stats[categoria] = stats.get(categoria, 0) + 1

        # Nome descritivo baseado em legenda + capítulo
        legenda_curta = sanitizar_nome(legenda) if legenda else Path(filename).stem
        cap_prefix = f"cap{cap.lower()}-" if cap else ""
        base_novo_nome = f"{cap_prefix}{legenda_curta}"

        if categoria == "DESCARTAR":
            continue

        if args.dry_run:
            print(f"  [DRY] {categoria}: {filename} -> {base_novo_nome}")
            continue

        if categoria == "MANTER":
            # TIFF/raster -> converter para PNG
            if formato in ("TIFF", "TIF"):
                saida = dir_manter / f"{base_novo_nome}.png"
                if converter_tiff_para_png(entrada, saida):
                    convertidas["TIFF_PNG"] += 1
                    print(f"  [OK] MANTER: {filename} -> {saida.name}")
                else:
                    # Fallback: copiar original
                    saida = dir_manter / filename
                    shutil.copy2(entrada, saida)
                    convertidas["COPIADAS"] += 1
                    convertidas["FALHAS"] += 1
                    print(f"  [!] MANTER (falha conversão, copiado): {filename}")
            else:
                # Outros formatos: copiar como está
                saida = dir_manter / f"{base_novo_nome}{entrada.suffix}"
                shutil.copy2(entrada, saida)
                convertidas["COPIADAS"] += 1
                print(f"  [OK] MANTER (copiado): {filename}")

        elif categoria == "REFAZER":
            # WMF/EMF -> tentar SVG; se falhar, copiar
            if formato in ("WMF", "EMF"):
                saida = dir_refazer / f"{base_novo_nome}.svg"
                if converter_wmf_para_svg(entrada, saida):
                    convertidas["WMF_SVG"] += 1
                    print(f"  [OK] REFAZER: {filename} -> {saida.name}")
                else:
                    saida = dir_refazer / filename
                    shutil.copy2(entrada, saida)
                    convertidas["COPIADAS"] += 1
                    convertidas["FALHAS"] += 1
            else:
                saida = dir_refazer / f"{base_novo_nome}{entrada.suffix}"
                shutil.copy2(entrada, saida)
                convertidas["COPIADAS"] += 1

        elif categoria == "AVALIAR":
            saida = dir_avaliar / filename
            saida.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entrada, saida)
            convertidas["COPIADAS"] += 1

    # Sumário
    print("\n=== Sumário ===")
    print(f"Total processado: {sum(stats.values())}")
    for cat, n in stats.items():
        print(f"  {cat}: {n}")
    print(f"\nConversões:")
    for op, n in convertidas.items():
        print(f"  {op}: {n}")
    print(f"\nOutput:")
    for d in (dir_manter, dir_refazer, dir_avaliar):
        if d.exists():
            n = len(list(d.iterdir()))
            print(f"  {d}: {n} arquivos")


if __name__ == "__main__":
    main()
