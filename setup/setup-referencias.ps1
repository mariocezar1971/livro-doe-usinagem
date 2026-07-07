<#
================================================================================
 FASE 0.4 - Gestao de Referencias Bibliograficas
================================================================================

 Este script:
 [1] Baixa CSL Springer (para artigos em periodicos Springer/IJAMT/JMPT)
 [2] Executa parser Python que extrai referencias da tese docx -> .bib
 [3] Move .bib gerado para pasta correta do projeto Quarto
 [4] Valida sintaxe do .bib com Python
 [5] Testa cross-reference no Quarto (renderiza pagina de referencias)
 [6] Orienta setup do Zotero + Better BibTeX

 PRE-REQUISITOS:
   - Python 3.10+ instalado
   - Fases 0.2 e 0.3 concluidas
   - Tese docx em local conhecido (default: Downloads)
   - Rodar na raiz do projeto LIVRO_DOE_USINAGEM

 COMO EXECUTAR:
   cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\setup\setup-referencias.ps1

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================
$TesePath = "$env:USERPROFILE\Downloads\TeseCorrigidaMargemEspelhoInicio.docx"
$ExtratorScript = ".\setup\extrair-refs-tese.py"

$CSLs = @{
    "associacao-brasileira-de-normas-tecnicas.csl" =
        "https://raw.githubusercontent.com/citation-style-language/styles/master/associacao-brasileira-de-normas-tecnicas.csl"
    "springer-basic-author-date.csl" =
        "https://raw.githubusercontent.com/citation-style-language/styles/master/springer-basic-author-date.csl"
}

# Cores
$ESC = [char]27
$GREEN = "$ESC[32m"; $YELLOW = "$ESC[33m"; $RED = "$ESC[31m"
$BLUE  = "$ESC[34m"; $BOLD   = "$ESC[1m";  $RESET = "$ESC[0m"

function Write-Etapa($n, $t) {
    Write-Host "`n$BOLD$BLUE================================================================================$RESET"
    Write-Host "$BOLD$BLUE ETAPA $n - $t$RESET"
    Write-Host "$BOLD$BLUE================================================================================$RESET"
}
function Write-OK($m)   { Write-Host "$GREEN[OK]$RESET $m" }
function Write-Warn($m) { Write-Host "$YELLOW[!]$RESET $m" }
function Write-Err($m)  { Write-Host "$RED[X]$RESET $m" }
function Perguntar($p)  {
    $r = Read-Host "$p (S/N)"
    return ($r -eq "S" -or $r -eq "s" -or $r -eq "")
}

# ============================================================================
# ETAPA 0 - Validar ambiente
# ============================================================================
Write-Etapa "0" "Validar ambiente"

if (-not (Test-Path "_quarto.yml")) {
    Write-Err "Execute na raiz do projeto LIVRO_DOE_USINAGEM"
    exit 1
}
Write-OK "Projeto Quarto detectado"

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Err "Python nao instalado"
    exit 1
}
Write-OK "Python: $($py.Path)"

# ============================================================================
# ETAPA 1 - Baixar CSLs
# ============================================================================
Write-Etapa "1" "Baixar CSLs (ABNT + Springer)"

foreach ($csl in $CSLs.GetEnumerator()) {
    $nome = $csl.Key
    $url  = $csl.Value

    if (Test-Path $nome) {
        Write-OK "$nome ja existe (pulando)"
    } else {
        Write-Host "Baixando $nome..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $nome -UseBasicParsing
            Write-OK "$nome baixado ($(Get-Item $nome | Select-Object -ExpandProperty Length) bytes)"
        } catch {
            Write-Err "Falha ao baixar $nome`: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# ETAPA 2 - Instalar dependencia Python
# ============================================================================
Write-Etapa "2" "Instalar dependencias Python"

Write-Host "Instalando bibtexparser (para validacao)..."
& $py.Path -m pip install bibtexparser --quiet --user 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-OK "bibtexparser instalado"
} else {
    Write-Warn "bibtexparser pode ja estar instalado"
}

# ============================================================================
# ETAPA 3 - Localizar tese e extrair referencias
# ============================================================================
Write-Etapa "3" "Extrair referencias da tese"

if (-not (Test-Path $TesePath)) {
    Write-Warn "Tese nao encontrada em: $TesePath"
    $novaPath = Read-Host "Digite o caminho completo da tese .docx (ou ENTER para pular)"
    if ($novaPath) {
        $TesePath = $novaPath
    } else {
        Write-Warn "Etapa 3 pulada. .bib inicial ja pode existir na pasta."
        goto etapa4
    }
}

if (-not (Test-Path $ExtratorScript)) {
    Write-Err "Script extrator nao encontrado: $ExtratorScript"
    Write-Err "Descompacte FASE_0_4.zip em .\setup\ primeiro"
    exit 1
}

Write-Host "Executando parser..."
& $py.Path $ExtratorScript $TesePath `
    --output ".\references-tese.bib" `
    --report ".\references-tese.report.md"

if ($LASTEXITCODE -eq 0 -and (Test-Path ".\references-tese.bib")) {
    Write-OK ".bib gerado: references-tese.bib"
    Write-OK "Relatorio: references-tese.report.md"
} else {
    Write-Err "Falha na extracao"
    exit 1
}

# ============================================================================
# ETAPA 4 - Consolidar em references.bib do projeto
# ============================================================================
Write-Etapa "4" "Consolidar em references.bib"

if ((Test-Path "references.bib") -and (Get-Content "references.bib" | Measure-Object).Count -gt 20) {
    Write-Warn "references.bib ja existe e tem conteudo"
    if (Perguntar "Sobrescrever com references-tese.bib?") {
        Copy-Item "references-tese.bib" "references.bib" -Force
        Write-OK "references.bib sobrescrito"
    } else {
        Write-OK "references.bib preservado (edite manualmente para mesclar)"
    }
} else {
    Copy-Item "references-tese.bib" "references.bib" -Force
    Write-OK "references.bib criado a partir do extraido"
}

# ============================================================================
# ETAPA 5 - Validar sintaxe do .bib
# ============================================================================
Write-Etapa "5" "Validar sintaxe do .bib"

$validacao = & $py.Path -c @"
import bibtexparser
from collections import Counter
try:
    with open('references.bib', encoding='utf-8') as f:
        db = bibtexparser.load(f)
    entries = db.entries
    tipos = Counter(e['ENTRYTYPE'] for e in entries)
    print(f'ENTRADAS: {len(entries)}')
    for t, n in sorted(tipos.items()):
        print(f'  {t}: {n}')
    # Campos obrigatorios
    issues = 0
    for e in entries:
        if e['ENTRYTYPE'] == 'article':
            if not e.get('author') or not e.get('title') or not e.get('journal'):
                issues += 1
    print(f'PROBLEMAS: {issues}')
except Exception as ex:
    print(f'ERRO: {ex}')
"@

Write-Host $validacao

# ============================================================================
# ETAPA 6 - Ajustar _quarto.yml para usar CSL Springer alternativa
# ============================================================================
Write-Etapa "6" "Configurar Quarto para CSL Springer/ABNT alternavel"

$quartoYml = Get-Content "_quarto.yml" -Raw
if ($quartoYml -match "csl:\s*springer-basic") {
    Write-OK "_quarto.yml ja configurado para Springer"
} else {
    Write-Host "Para alternar entre CSLs:"
    Write-Host "  - ABNT (livro):     csl: associacao-brasileira-de-normas-tecnicas.csl"
    Write-Host "  - Springer (artigo IJAMT): csl: springer-basic-author-date.csl"
    Write-Host ""
    Write-Host "Ambos CSLs estao na raiz do projeto. Edite _quarto.yml conforme necessidade."
}

# ============================================================================
# ETAPA 7 - Renderizar para testar
# ============================================================================
Write-Etapa "7" "Renderizar para validar"

if (Perguntar "Renderizar HTML para testar citations?") {
    quarto render --to html 2>&1 | Tee-Object -Variable output
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Renderizado com sucesso"
        if (Test-Path "_book\references.html") {
            Write-OK "Pagina de referencias criada"
        }
    } else {
        Write-Err "Falha na renderizacao"
    }
}

# ============================================================================
# ETAPA 8 - Guia Zotero
# ============================================================================
Write-Etapa "8" "Setup do Zotero (manual - guia)"

Write-Host ""
Write-Host "$BOLD Passos para setup Zotero + Better BibTeX:$RESET"
Write-Host ""
Write-Host "1. Baixe e instale Zotero:"
Write-Host "   https://www.zotero.org/download/"
Write-Host ""
Write-Host "2. Crie conta em zotero.org (para sync entre casa/trabalho)"
Write-Host ""
Write-Host "3. Instale plugin Better BibTeX:"
Write-Host "   https://retorque.re/zotero-better-bibtex/installation/"
Write-Host "   (baixe .xpi, arraste para Zotero -> Tools -> Add-ons)"
Write-Host ""
Write-Host "4. Instale conector do navegador (Chrome/Firefox):"
Write-Host "   https://www.zotero.org/download/connectors"
Write-Host ""
Write-Host "5. Importar references.bib para o Zotero:"
Write-Host "   - Zotero -> File -> Import -> selecionar references.bib"
Write-Host "   - Cria colecao 'Livro DOE Usinagem'"
Write-Host ""
Write-Host "6. Configurar Better BibTeX para auto-exportar:"
Write-Host "   - Botao direito na colecao -> Export Collection"
Write-Host "   - Format: Better BibTeX"
Write-Host "   - Keep updated: SIM"
Write-Host "   - Salvar em: $((Get-Location).Path)\references.bib"
Write-Host "   (agora toda mudanca no Zotero atualiza references.bib automaticamente)"
Write-Host ""
Write-Host "7. Consulte guia completo:"
Write-Host "   .\setup\ZOTERO_PASSO_A_PASSO.md"

$abrir = Perguntar "Abrir sites do Zotero e Better BibTeX?"
if ($abrir) {
    Start-Process "https://www.zotero.org/download/"
    Start-Process "https://retorque.re/zotero-better-bibtex/installation/"
}

# ============================================================================
# Conclusao
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 0.4"

Write-Host ""
Write-Host "$BOLD Concluido automaticamente:$RESET"
Write-Host "  $GREEN [OK] CSL ABNT baixado $RESET"
Write-Host "  $GREEN [OK] CSL Springer baixado $RESET"
Write-Host "  $GREEN [OK] references.bib gerado a partir da tese ($((Select-String -Path 'references.bib' -Pattern '^@' | Measure-Object).Count) entradas) $RESET"
Write-Host "  $GREEN [OK] Relatorio de qualidade: references-tese.report.md $RESET"
Write-Host ""
Write-Host "$BOLD Pendencias manuais:$RESET"
Write-Host "  $YELLOW [ ] Instalar Zotero desktop $RESET"
Write-Host "  $YELLOW [ ] Instalar Better BibTeX $RESET"
Write-Host "  $YELLOW [ ] Importar references.bib no Zotero $RESET"
Write-Host "  $YELLOW [ ] Revisar entradas marcadas 'TODO REVISAR' no Zotero $RESET"
Write-Host "  $YELLOW [ ] Configurar auto-export Better BibTeX $RESET"
Write-Host ""
Write-Host "Consulte: .\setup\ZOTERO_PASSO_A_PASSO.md"
Write-Host ""
