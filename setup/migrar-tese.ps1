<#
================================================================================
 FASE 1.1 - Migração da Tese
================================================================================

 Automatiza a Fase 1.1 do roadmap:
 [1] Converte tese docx -> qmd bruto (preservando equações e figuras)
 [2] Extrai todas as figuras para pasta figuras/media/
 [3] Analisa cada figura e localiza contexto no qmd
 [4] Classifica automaticamente (MANTER / REFAZER / DESCARTAR / AVALIAR)
 [5] Gera catálogo CSV + relatório Markdown
 [6] (Opcional) Reexporta figuras conforme categoria decidida

 PRE-REQUISITOS:
   - Python 3.10+ instalado
   - Pandoc no PATH (o Quarto instala junto, mas escondido)
   - LibreOffice instalado (opcional, para WMF -> SVG)
   - Pillow instalado via pip (o script instala se faltar)

 COMO EXECUTAR:
   cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\setup\migrar-tese.ps1

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================
$TesePath = "C:\Users\mceza\OneDrive\PESSOAL\CARREIRA PROFISSIONAL\DOUTORADO\TESE\TextoCorrigido\TeseCorrigidaMargemEspelhoInicio.docx"
$OutputDir = ".\migracao-tese"

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

# Projeto Quarto?
if (-not (Test-Path "_quarto.yml")) {
    Write-Err "Execute na raiz do projeto LIVRO_DOE_USINAGEM"
    exit 1
}
Write-OK "Projeto Quarto detectado"

# Python
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Err "Python nao instalado"
    exit 1
}
Write-OK "Python: $($py.Path)"

# Pandoc - o Quarto instala, mas precisa estar no PATH
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) {
    Write-Warn "Pandoc nao esta no PATH"
    Write-Host "Localizando pandoc do Quarto..."

    $quartoBin = Split-Path (Get-Command quarto -ErrorAction SilentlyContinue).Source
    if ($quartoBin) {
        $pandocEncontrado = Get-ChildItem -Path (Split-Path $quartoBin) -Filter "pandoc.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($pandocEncontrado) {
            Write-Host "  Encontrado: $($pandocEncontrado.FullName)"
            $env:PATH = "$($pandocEncontrado.DirectoryName);$env:PATH"
            Write-OK "Pandoc adicionado ao PATH desta sessao"
        }
    }
}
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
    Write-OK "Pandoc: $((pandoc --version) -split "`n" | Select-Object -First 1)"
} else {
    Write-Err "Pandoc nao encontrado"
    Write-Host "Instale via: https://pandoc.org/installing.html"
    exit 1
}

# Pillow
Write-Host "Verificando Pillow..."
$temPillow = & $py.Path -c "from PIL import Image; print('OK')" 2>$null
if ($temPillow -ne "OK") {
    Write-Warn "Pillow nao instalado. Instalando..."
    & $py.Path -m pip install Pillow --quiet --user
}
Write-OK "Pillow disponivel"

# LibreOffice (opcional, para WMF -> SVG)
$soffice = Get-Command soffice -ErrorAction SilentlyContinue
if (-not $soffice) {
    $soffice = Get-Command libreoffice -ErrorAction SilentlyContinue
}
$temLibreOffice = $null -ne $soffice

if (-not $temLibreOffice) {
    # Verificar caminho padrao Windows
    $libreOfficePath = "C:\Program Files\LibreOffice\program\soffice.exe"
    if (Test-Path $libreOfficePath) {
        $env:PATH = "$(Split-Path $libreOfficePath);$env:PATH"
        $temLibreOffice = $true
        Write-OK "LibreOffice encontrado: $libreOfficePath"
    }
}

if ($temLibreOffice) {
    Write-OK "LibreOffice disponivel (WMF -> SVG habilitado)"
} else {
    Write-Warn "LibreOffice nao encontrado - WMFs seraocopiados sem conversao"
    Write-Host "  Instale se quiser conversao automatica: https://www.libreoffice.org/download/"
}

# ============================================================================
# ETAPA 1 - Localizar tese
# ============================================================================
Write-Etapa "1" "Localizar tese docx"

if (-not (Test-Path $TesePath)) {
    Write-Warn "Tese nao encontrada em: $TesePath"
    Write-Host "Buscando em locais comuns..."

    $localizacoes = @(
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Dropbox"
    )

    $encontradas = @()
    foreach ($loc in $localizacoes) {
        if (Test-Path $loc) {
            $achou = Get-ChildItem -Path $loc -Filter "*Tese*.docx" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 5
            $encontradas += $achou
        }
    }

    if ($encontradas.Count -gt 0) {
        Write-Host "`nTeses encontradas:"
        for ($i = 0; $i -lt $encontradas.Count; $i++) {
            Write-Host "  [$i] $($encontradas[$i].FullName)"
        }
        $sel = Read-Host "`nEscolha (0-$($encontradas.Count-1)) ou cole caminho completo"
        if ($sel -match "^\d+$" -and [int]$sel -lt $encontradas.Count) {
            $TesePath = $encontradas[[int]$sel].FullName
        } else {
            $TesePath = $sel
        }
    } else {
        $TesePath = Read-Host "Cole o caminho completo da tese .docx"
    }
}

if (-not (Test-Path $TesePath)) {
    Write-Err "Tese nao encontrada: $TesePath"
    exit 1
}
Write-OK "Tese: $TesePath"

# ============================================================================
# ETAPA 2 - Executar migracao
# ============================================================================
Write-Etapa "2" "Executar migração (docx -> qmd + catálogo)"

$scriptMigracao = ".\setup\migrar-tese.py"
if (-not (Test-Path $scriptMigracao)) {
    Write-Err "Script Python nao encontrado: $scriptMigracao"
    exit 1
}

& $py.Path $scriptMigracao $TesePath --output-dir $OutputDir

if ($LASTEXITCODE -ne 0) {
    Write-Err "Falha na migracao"
    exit 1
}

# ============================================================================
# ETAPA 3 - Revisar catalogo (manual)
# ============================================================================
Write-Etapa "3" "Revisar catálogo (manual)"

$csvPath = "$OutputDir\catalogo\catalogo-figuras.csv"
$mdPath  = "$OutputDir\catalogo\catalogo-figuras.md"

if (Test-Path $csvPath) {
    Write-Host "Catalogo gerado:"
    Write-Host "  CSV:      $csvPath"
    Write-Host "  Relatorio: $mdPath"
    Write-Host ""
    Write-Host "$BOLD IMPORTANTE:$RESET revise o CSV no Excel/LibreOffice Calc antes de reexportar."
    Write-Host "  - Coluna 'categoria_sugerida' pode ser alterada (MANTER/REFAZER/DESCARTAR/AVALIAR)"
    Write-Host "  - As sugestoes automaticas sao heuristicas - ajuste conforme necessario"
    Write-Host ""

    if (Perguntar "Abrir CSV no editor padrao agora?") {
        Start-Process $csvPath
    }

    if (Perguntar "Abrir relatorio Markdown?") {
        Start-Process $mdPath
    }
} else {
    Write-Err "Catalogo nao foi gerado"
    exit 1
}

# ============================================================================
# ETAPA 4 - Reexportar figuras conforme catalogo
# ============================================================================
Write-Etapa "4" "Reexportar figuras conforme categoria"

Write-Host "Esta etapa:"
Write-Host "  - MANTER (TIFF/raster): converte para PNG otimizado"
Write-Host "  - REFAZER (WMF/EMF):    converte para SVG via LibreOffice"
Write-Host "  - DESCARTAR:            ignora (nao copia)"
Write-Host "  - AVALIAR:              copia para pasta separada"
Write-Host ""

if (Perguntar "Executar reexportacao agora?") {
    $scriptReexport = ".\setup\reexportar-figuras.py"
    & $py.Path $scriptReexport $csvPath `
        --figuras "$OutputDir\figuras" `
        --output "$OutputDir\figuras-processadas"
}

# ============================================================================
# ETAPA 5 - Instrucoes finais
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 1.1"

Write-Host ""
Write-Host "$BOLD Arquivos gerados:$RESET"
Write-Host "  $GREEN qmd bruto:                $OutputDir\qmd\tese-bruta.qmd $RESET"
Write-Host "  $GREEN qmd por capitulo:         $OutputDir\qmd\tese-cap-*.qmd $RESET"
Write-Host "  $GREEN Figuras originais:        $OutputDir\figuras\media\ $RESET"
Write-Host "  $GREEN Catalogo (CSV):           $csvPath $RESET"
Write-Host "  $GREEN Catalogo (Markdown):      $mdPath $RESET"

if (Test-Path "$OutputDir\figuras-processadas") {
    Write-Host "  $GREEN Figuras processadas:      $OutputDir\figuras-processadas\ $RESET"
    Write-Host "    - manter\    : PNG otimizados prontos para uso no livro"
    Write-Host "    - refazer\   : SVGs a revisar/adaptar no Inkscape ou draw.io"
    Write-Host "    - avaliar\   : figuras que precisam decisao manual"
}

Write-Host ""
Write-Host "$BOLD Proximos passos (Fase 1.2):$RESET"
Write-Host "  1. Ler tese-cap-i.qmd, ii.qmd, ... para entender o material bruto"
Write-Host "  2. Marcar trechos no qmd bruto: MANTER/REESCREVER/CORTAR/EXPANDIR"
Write-Host "  3. Usar figuras processadas como material inicial dos capitulos do livro"
Write-Host "  4. Consulte: .\setup\MIGRACAO_TESE_GUIA.md"
Write-Host ""
