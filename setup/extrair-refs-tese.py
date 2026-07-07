#!/usr/bin/env python3
"""
Extrator de referências da tese docx para BibTeX.

Uso:
    python extrair-refs-tese.py <caminho_tese.docx> [--output references-tese.bib]

Requer: pandoc instalado no sistema (usado via subprocess).

O script:
1. Converte o docx para markdown via pandoc
2. Localiza a seção "REFERÊNCIAS BIBLIOGRÁFICAS"
3. Parseia cada referência com regex heurística
4. Identifica tipo (article, book, thesis, misc)
5. Gera arquivo .bib pronto para importar no Zotero
6. Reporta estatísticas + referências que precisam revisão manual

O resultado NÃO é 100% acurado — depende da formatação original.
Referências que o parser não reconhece bem são marcadas com TODO
para revisão manual no Zotero.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Estruturas de dados
# ---------------------------------------------------------------------------

@dataclass
class Reference:
    """Representa uma referência bibliográfica parseada."""
    raw_text: str
    entry_type: str = "misc"           # article, book, inproceedings, phdthesis, misc
    citekey: str = ""
    authors: list[str] = field(default_factory=list)
    title: str = ""
    journal: str = ""
    booktitle: str = ""
    publisher: str = ""
    address: str = ""
    year: str = ""
    volume: str = ""
    number: str = ""
    pages: str = ""
    month: str = ""
    edition: str = ""
    school: str = ""
    url: str = ""
    doi: str = ""
    note: str = ""
    needs_review: bool = False
    review_reason: str = ""


# ---------------------------------------------------------------------------
# Pipeline principal
# ---------------------------------------------------------------------------

def extract_text_from_docx(docx_path: Path) -> str:
    """Usa pandoc para converter docx -> markdown."""
    result = subprocess.run(
        ["pandoc", "-f", "docx", "-t", "markdown", str(docx_path)],
        capture_output=True, text=True, check=True
    )
    return result.stdout


def find_references_section(text: str) -> str:
    """Localiza a seção de referências no texto."""
    # Padrão flexível: aceita variações
    patterns = [
        r"REFER[EÊ]NCIAS BIBLIOGR[AÁ]FICAS",
        r"REFERENCES",
        r"CAP[IÍ]TULO\s+VIII",
    ]

    start_idx = None
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            # Pegar do último match (evita pegar o TOC)
            all_matches = list(re.finditer(pattern, text, re.IGNORECASE))
            start_idx = all_matches[-1].end()
            break

    if start_idx is None:
        raise ValueError("Seção de referências não encontrada")

    # Buscar fim: próximo capítulo, apêndice, ou fim do documento
    remainder = text[start_idx:]
    end_patterns = [
        r"\n\s*(?:CAP[IÍ]TULO|ANEXO|AP[EÊ]NDICE)\s+[IVX]",
        r"\n\s*ANEXO",
        r"\n\s*AP[EÊ]NDICE",
    ]

    end_idx = len(remainder)
    for pattern in end_patterns:
        match = re.search(pattern, remainder)
        if match and match.start() < end_idx:
            end_idx = match.start()

    return remainder[:end_idx].strip()


def clean_markdown(text: str) -> str:
    """Remove artefatos de markdown do pandoc."""
    # Remove links markdown [texto](url) mantendo apenas o texto
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)
    # Remove ** de negrito, mantendo texto
    text = text.replace("**", "")
    # Múltiplos asteriscos residuais
    text = re.sub(r"\*+", "", text)
    # Espaços múltiplos
    text = re.sub(r"[ \t]+", " ", text)
    # Linhas em branco excessivas
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)
    return text.strip()


def split_references(refs_text: str) -> list[str]:
    """Divide o texto de referências em entradas individuais."""
    # Cada referência começa com SOBRENOME, ou nome em maiúsculas
    # Estratégia: dividir por linhas em branco
    lines = refs_text.split("\n")
    entries = []
    current = []

    for line in lines:
        line = line.rstrip()
        if not line.strip():
            if current:
                entries.append(" ".join(current))
                current = []
        else:
            current.append(line.strip())

    if current:
        entries.append(" ".join(current))

    # Filtrar entradas muito curtas (não são referências reais)
    return [e for e in entries if len(e) > 20 and not e.startswith("|")]


# ---------------------------------------------------------------------------
# Parser de referência individual
# ---------------------------------------------------------------------------

def parse_authors(text: str) -> tuple[list[str], str]:
    """Extrai autores do início da referência. Retorna (autores, resto).

    Trata três cenários:
    1. Autor pessoal padrão: SOBRENOME, X. Y.; OUTRO, Z.
    2. Autor institucional: ABNT / ALCOA / SANDVIK COROMANT
    3. Erros de digitação: SOBRENOME; X. Y. (ponto-e-vírgula em vez de vírgula)
    """
    # --- Padrão 1: autores pessoais padrão ---
    # Aceita:
    # - "SILVA, J." (padrão)
    # - "Da SILVA, J." / "De SOUZA, A." (prefixos ABNT)
    # - "DeGARMO, P." (nomes concatenados)
    # - "NG, E." (nomes orientais curtos, 2 caracteres)
    # - "MARUSICH .T." (espaço extra antes de vírgula)
    prefix = r"(?:D[ae]\s+|Dos\s+|Das\s+|Del\s+|Do\s+|van\s+|von\s+|de\s+la\s+)?"
    surname = r"[A-ZÁÉÍÓÚÂÊÔÃÕÇÑ][A-Za-zÁÉÍÓÚÂÊÔÃÕÇÑáéíóúâêôãõç\'\-]*"
    # Inicial: letra maiúscula + PONTO obrigatório (pode ter hífen para nomes compostos)
    # Ex: X., X.-Y., X. Y.
    initials = r"(?:[A-ZÁÉÍÓÚÂÊÔÃÕÇÑ]\.-?\s*){1,4}"

    author_pattern = (
        rf"{prefix}{surname}"
        rf"(?:\s+(?:Sr\.|Jr\.|{surname}))*"                # sobrenomes múltiplos, Jr./Sr.
        rf"\s*[,;]\s*"                                     # separador (com espaço tolerante)
        rf"{initials}"
    )
    multi_author_pattern = rf"^({author_pattern}(?:\s*;\s*{author_pattern})*)"
    match = re.match(multi_author_pattern, text)

    if match:
        authors_str = match.group(1).strip().rstrip(";").strip()
        rest = text[match.end():].strip()
        # Separar por ";" (agora com certeza é separador entre autores)
        authors = [
            a.strip().rstrip(".").strip().replace(";", ",", 1)  # ; interno vira ,
            for a in re.split(r"\s*;\s*", authors_str)
        ]
        return [a for a in authors if a], rest

    # --- Padrão 2: instituição/nome coletivo ---
    # Formato: PALAVRAS EM CAIXA ALTA. [Título...] ou PALAVRAS EM CAIXA ALTA, ANO
    institution_pattern = (
        r"^([A-ZÁÉÍÓÚÂÊÔÃÕÇÑ][A-ZÁÉÍÓÚÂÊÔÃÕÇÑ\-]+"
        r"(?:\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇÑ][A-ZÁÉÍÓÚÂÊÔÃÕÇÑ\-]+){0,6})"
        r"[\.,]\s*"
    )
    match = re.match(institution_pattern, text)
    if match:
        institution = match.group(1).strip()
        # Filtrar falsos positivos (ex.: só uma palavra "TITLE...")
        # Institucional válido: várias palavras OU sigla conhecida
        known_institutions = {"ABNT", "ALCOA", "ISO", "ASTM", "SAE", "DIN", "SANDVIK",
                              "COROMANT", "ROMI", "LEM", "ITW", "MITSUBISHI"}
        words = institution.split()
        is_known = any(w in known_institutions for w in words)
        is_multi_word = len(words) >= 2

        if is_known or is_multi_word:
            rest = text[match.end():].strip()
            return [institution], rest

    return [], text


def parse_year(text: str) -> tuple[str, str]:
    """Extrai ano (procura padrão XXXX no fim)."""
    # Padrão: ano com 4 dígitos entre 1800 e 2099
    matches = list(re.finditer(r"\b(1[89]\d{2}|20\d{2})\b", text))
    if not matches:
        return "", ""
    # Usa o último match (geralmente ano de publicação está no fim)
    year = matches[-1].group(1)
    return year, text[:matches[-1].start()] + text[matches[-1].end():]


def parse_volume_number_pages(text: str) -> dict:
    """Extrai v. X, n. Y, p. Z-W."""
    result = {}

    # Volume
    m = re.search(r"v\.\s*(\d+)", text)
    if m: result["volume"] = m.group(1)

    # Número
    m = re.search(r"n\.\s*([\d\-/]+)", text)
    if m: result["number"] = m.group(1)

    # Páginas
    m = re.search(r"p\.\s*(\d+[\-–]?\d*)", text)
    if m: result["pages"] = m.group(1).replace("–", "--")

    return result


def parse_month(text: str) -> str:
    """Extrai mês abreviado ou nome completo."""
    months = {
        "jan": "jan", "feb": "feb", "fev": "feb", "mar": "mar", "abr": "apr",
        "apr": "apr", "may": "may", "mai": "may", "jun": "jun", "jul": "jul",
        "aug": "aug", "ago": "aug", "sep": "sep", "set": "sep", "oct": "oct",
        "out": "oct", "nov": "nov", "dec": "dec", "dez": "dec"
    }
    for pt, en in months.items():
        if re.search(rf"\b{pt}\b\.?", text, re.IGNORECASE):
            return en
    return ""


def detect_entry_type(text: str) -> str:
    """Heurística para identificar tipo de entrada."""
    text_lower = text.lower()

    if re.search(r"\bthesis\b|\btese\b|\bdissertação\b|\bph\.?d\.?\b", text_lower):
        return "phdthesis"
    if re.search(r"\bproceedings\b|\bconference\b|\bcongresso\b|\banais\b", text_lower):
        return "inproceedings"
    if "acesso em" in text_lower or "available" in text_lower or "www." in text_lower:
        return "misc"  # site web
    # Livro: sem v./n./p. + tem editora conhecida ou endereço
    has_journal_markers = bool(re.search(r"v\.\s*\d+|n\.\s*\d+", text))
    has_publisher = bool(re.search(r":\s*[A-Z][a-z]+", text))
    if not has_journal_markers and has_publisher:
        return "book"
    if has_journal_markers:
        return "article"
    return "misc"


def make_citekey(authors: list[str], year: str, title: str, existing: set[str]) -> str:
    """Gera citekey único no formato lastnameYEARfirstword."""
    if not authors:
        base = "anon"
    else:
        first_author = authors[0].split(",")[0].strip()
        base = re.sub(r"[^a-zA-Z]", "", first_author).lower()[:15]

    if not base:
        base = "ref"

    year_str = year if year else "nd"

    # Primeira palavra significativa do título
    title_word = ""
    if title:
        words = re.findall(r"\b[a-zA-Z]{4,}\b", title.lower())
        stop = {"the", "and", "for", "with", "using", "com", "para", "das", "dos"}
        for w in words:
            if w not in stop:
                title_word = w[:8]
                break

    key = f"{base}{year_str}{title_word}"
    key = re.sub(r"[^a-zA-Z0-9]", "", key)

    # Garantir unicidade
    if key in existing:
        suffix = "a"
        while f"{key}{suffix}" in existing:
            suffix = chr(ord(suffix) + 1)
        key = f"{key}{suffix}"

    return key


def parse_reference(raw: str, existing_keys: set[str]) -> Reference:
    """Parser principal de uma referência."""
    ref = Reference(raw_text=raw)
    working = clean_markdown(raw)

    # 1. Autores
    authors, rest = parse_authors(working)
    if not authors:
        ref.needs_review = True
        ref.review_reason = "Não identificou autores"
        ref.note = raw[:200]
        return ref
    ref.authors = authors

    # 2. Ano
    year, rest_no_year = parse_year(rest)
    ref.year = year

    # 3. Título — heurística: primeiro trecho até "**" ou ". " seguido de letra maiúscula
    # Como já removemos **, usar "." como delimitador
    # Título vem primeiro, revista/livro vem depois
    parts = re.split(r"\.\s+(?=[A-ZÁÉÍÓÚÂÊÔÃÕÇ])", rest, maxsplit=1)
    if parts:
        ref.title = parts[0].strip().rstrip(".").strip()

    # 4. Volume, número, páginas
    vnp = parse_volume_number_pages(working)
    ref.volume = vnp.get("volume", "")
    ref.number = vnp.get("number", "")
    ref.pages = vnp.get("pages", "")

    # 5. Mês
    ref.month = parse_month(working)

    # 6. Tipo de entrada
    ref.entry_type = detect_entry_type(working)

    # 7. Journal/booktitle: entre título e volume/ano
    if ref.entry_type == "article" and len(parts) > 1:
        # Journal geralmente é a segunda parte, antes do v.
        journal_match = re.match(r"^(.+?)(?:\.\s*v\.|\.\s*\d{4}|,\s*v\.)", parts[1])
        if journal_match:
            ref.journal = journal_match.group(1).strip().rstrip(".").strip()
        else:
            # Pega até o primeiro ponto
            first_part = parts[1].split(".")[0].strip()
            if first_part:
                ref.journal = first_part

    # 8. URL
    url_match = re.search(r"(www\.[^\s>]+|https?://[^\s>]+)", working)
    if url_match:
        ref.url = url_match.group(1).rstrip(".,>")

    # 9. Detectar problemas para revisão
    if not ref.year:
        ref.needs_review = True
        ref.review_reason = "Ano não identificado"
    if not ref.title or len(ref.title) < 5:
        ref.needs_review = True
        ref.review_reason = "Título curto ou ausente"
    if ref.entry_type == "article" and not ref.journal:
        ref.needs_review = True
        ref.review_reason = "Article sem journal"

    # 10. Citekey
    ref.citekey = make_citekey(ref.authors, ref.year, ref.title, existing_keys)

    return ref


# ---------------------------------------------------------------------------
# Geração do BibTeX
# ---------------------------------------------------------------------------

def normalize_author(author: str) -> str:
    """Converte 'SOBRENOME, INICIAIS' para 'Sobrenome, Iniciais' (title case)."""
    # Preservar casing das iniciais (X. Y.)
    parts = author.split(",", 1)
    if len(parts) != 2:
        return author

    surname = parts[0].strip()
    initials = parts[1].strip()

    # Título case para sobrenome (mas mantém acentos e nomes compostos)
    surname_norm = " ".join(
        w.capitalize() if w.isalpha() and len(w) > 2 else w
        for w in surname.split()
    )

    return f"{surname_norm}, {initials}"


def escape_bibtex(text: str) -> str:
    """Escapa caracteres especiais para BibTeX."""
    # Preservar acentos (usar UTF-8 no arquivo final)
    text = text.replace("&", "\\&")
    text = text.replace("%", "\\%")
    text = text.replace("#", "\\#")
    return text


def reference_to_bibtex(ref: Reference) -> str:
    """Converte Reference em entrada BibTeX."""
    lines = [f"@{ref.entry_type}{{{ref.citekey},"]

    if ref.needs_review:
        lines.append(f"  % TODO REVISAR: {ref.review_reason}")

    fields = []
    if ref.authors:
        authors_bibtex = " and ".join(normalize_author(a) for a in ref.authors)
        fields.append(("author", authors_bibtex))
    if ref.title:
        fields.append(("title", ref.title))
    if ref.journal:
        fields.append(("journal", ref.journal))
    if ref.booktitle:
        fields.append(("booktitle", ref.booktitle))
    if ref.publisher:
        fields.append(("publisher", ref.publisher))
    if ref.address:
        fields.append(("address", ref.address))
    if ref.year:
        fields.append(("year", ref.year))
    if ref.month:
        fields.append(("month", ref.month))
    if ref.volume:
        fields.append(("volume", ref.volume))
    if ref.number:
        fields.append(("number", ref.number))
    if ref.pages:
        fields.append(("pages", ref.pages))
    if ref.edition:
        fields.append(("edition", ref.edition))
    if ref.school:
        fields.append(("school", ref.school))
    if ref.doi:
        fields.append(("doi", ref.doi))
    if ref.url:
        fields.append(("url", ref.url))
    if ref.note:
        fields.append(("note", ref.note))

    for name, value in fields:
        escaped = escape_bibtex(str(value))
        lines.append(f"  {name} = {{{escaped}}},")

    # Remover vírgula final da última linha
    if lines[-1].endswith(","):
        lines[-1] = lines[-1][:-1]

    lines.append("}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("docx", type=Path, help="Caminho do arquivo .docx da tese")
    parser.add_argument("--output", "-o", type=Path, default=Path("references-tese.bib"),
                        help="Arquivo .bib de saída (default: references-tese.bib)")
    parser.add_argument("--report", type=Path, default=Path("references-tese.report.md"),
                        help="Relatório de qualidade (default: references-tese.report.md)")
    args = parser.parse_args()

    if not args.docx.exists():
        print(f"ERRO: arquivo não encontrado: {args.docx}", file=sys.stderr)
        sys.exit(1)

    print(f"[1/5] Extraindo texto de {args.docx}...")
    text = extract_text_from_docx(args.docx)
    print(f"      {len(text):,} caracteres extraídos")

    print("[2/5] Localizando seção de referências...")
    refs_section = find_references_section(text)
    print(f"      {len(refs_section):,} caracteres na seção")

    print("[3/5] Dividindo em entradas...")
    entries = split_references(refs_section)
    print(f"      {len(entries)} entradas encontradas")

    print("[4/5] Parseando referências...")
    existing_keys: set[str] = set()
    references: list[Reference] = []
    for entry in entries:
        try:
            ref = parse_reference(entry, existing_keys)
            existing_keys.add(ref.citekey)
            references.append(ref)
        except Exception as e:
            print(f"      ERRO parseando: {entry[:80]}... ({e})", file=sys.stderr)

    # Estatísticas
    by_type: dict[str, int] = {}
    needs_review = []
    for ref in references:
        by_type[ref.entry_type] = by_type.get(ref.entry_type, 0) + 1
        if ref.needs_review:
            needs_review.append(ref)

    print("[5/5] Gerando arquivos de saída...")

    # Escrever .bib
    header = f"""% Referências extraídas automaticamente da tese
% Fonte: {args.docx.name}
% Total: {len(references)} referências
% Distribuição por tipo:
"""
    for t, n in sorted(by_type.items()):
        header += f"%   {t}: {n}\n"
    header += f"% Precisam revisão: {len(needs_review)}\n"
    header += "%\n"
    header += "% IMPORTANTE: revise as entradas marcadas com 'TODO REVISAR'\n"
    header += "% no Zotero antes de usar em publicação.\n\n"

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(header)
        for ref in references:
            f.write(reference_to_bibtex(ref))
            f.write("\n\n")

    # Escrever relatório
    with open(args.report, "w", encoding="utf-8") as f:
        f.write(f"# Relatório de extração de referências\n\n")
        f.write(f"**Fonte:** `{args.docx.name}`\n\n")
        f.write(f"**Total de referências:** {len(references)}\n\n")
        f.write(f"## Distribuição por tipo\n\n")
        for t, n in sorted(by_type.items()):
            f.write(f"- `{t}`: {n}\n")
        f.write(f"\n## Referências que precisam revisão manual\n\n")
        f.write(f"Total: {len(needs_review)} de {len(references)} ({100 * len(needs_review) // max(len(references), 1)}%)\n\n")

        # Agrupar por razão
        by_reason: dict[str, list] = {}
        for ref in needs_review:
            by_reason.setdefault(ref.review_reason, []).append(ref)

        for reason, refs in sorted(by_reason.items()):
            f.write(f"### {reason} ({len(refs)})\n\n")
            for ref in refs[:20]:
                f.write(f"- `{ref.citekey}`: {ref.raw_text[:120]}...\n")
            if len(refs) > 20:
                f.write(f"- ... e mais {len(refs) - 20}\n")
            f.write("\n")

    print(f"\n[OK] Arquivo BibTeX: {args.output}")
    print(f"[OK] Relatório: {args.report}")
    print(f"\nResumo:")
    print(f"  Total de referências: {len(references)}")
    print(f"  Por tipo: {dict(sorted(by_type.items()))}")
    print(f"  Precisam revisão manual: {len(needs_review)} ({100 * len(needs_review) // max(len(references), 1)}%)")


if __name__ == "__main__":
    main()
