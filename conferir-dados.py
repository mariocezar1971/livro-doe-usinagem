#!/usr/bin/env python3
"""
conferir-dados.py - Confere valores numericos do livro contra a tese.
Uso: python conferir-dados.py (com o PDF-texto da tese no mesmo diretorio)
"""
import re, sys

TESE = "TeseCorrigidaMargemEspelhoTexto.pdf"  # texto puro UTF-8

valores = {
    "Cap8 ap->Fu +714": ["714"],
    "Cap8 Vc->Fu -107": ["107"],
    "Cap8 Liga->Fu -52": ["51,89"],
    "Cap8 media Fu 585": ["584,88"],
    "Cap10 otimo Vc 126": ["126"],
    "Cap10 otimo ap 2,43": ["2,43"],
    "Cap10 otimo f 0,19": ["0,19"],
    "Cap10 Fu otimo 723": ["723"],
    "Cap10 valid 6351 R 336": ["336"],
    # ... adicionar mais conforme necessario
}

try:
    tese = open(TESE, encoding="utf-8", errors="replace").read()
except FileNotFoundError:
    print(f"Tese nao encontrada: {TESE}"); sys.exit(1)

ok = 0
for nome, cands in valores.items():
    achou = any(c in tese for c in cands)
    print(f"  {'[OK]' if achou else '[!!]'} {nome}")
    ok += achou
print(f"\n{ok}/{len(valores)} confirmados")
