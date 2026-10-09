#!/usr/bin/env python3
"""
exportar-dados.py - Exporta o banco usinagem.sqlite3 para CSVs documentados.
Apendice D do livro DOE em Usinagem.

Uso:
    python exportar-dados.py [caminho_do_banco] [pasta_saida]
    (padrao: usinagem.sqlite3 -> ./dados-csv/)

Gera um CSV por tabela + um manifesto com a estrutura.
"""
import sqlite3
import csv
import sys
import os
from datetime import datetime

banco = sys.argv[1] if len(sys.argv) > 1 else "usinagem.sqlite3"
saida = sys.argv[2] if len(sys.argv) > 2 else "dados-csv"

if not os.path.exists(banco):
    print(f"[ERRO] Banco nao encontrado: {banco}")
    print("Informe o caminho: python exportar-dados.py CAMINHO/usinagem.sqlite3")
    sys.exit(1)

os.makedirs(saida, exist_ok=True)
con = sqlite3.connect(banco)
cur = con.cursor()

# Listar tabelas
cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
tabelas = [r[0] for r in cur.fetchall()]
print(f"Tabelas encontradas: {tabelas}")

manifesto = [f"# Manifesto de exportacao - {datetime.now():%Y-%m-%d %H:%M}",
             f"Banco: {banco}", ""]

for tab in tabelas:
    # Estrutura
    cur.execute(f"PRAGMA table_info({tab})")
    colunas = [c[1] for c in cur.fetchall()]
    # Dados
    cur.execute(f"SELECT * FROM {tab}")
    linhas = cur.fetchall()
    # Gravar CSV (UTF-8 com BOM para abrir bem no Excel BR)
    caminho = os.path.join(saida, f"{tab}.csv")
    with open(caminho, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(colunas)
        w.writerows(linhas)
    print(f"  [OK] {tab}.csv ({len(linhas)} linhas, {len(colunas)} colunas)")
    manifesto.append(f"## {tab}.csv")
    manifesto.append(f"- Linhas: {len(linhas)} | Colunas: {len(colunas)}")
    manifesto.append(f"- Campos: {', '.join(colunas)}")
    manifesto.append("")

# Gravar manifesto
with open(os.path.join(saida, "MANIFESTO.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(manifesto))

con.close()
print(f"\nExportacao completa em: {saida}/")
print("Confira o MANIFESTO.md e compare com o dicionario de dados (Apendice D).")
