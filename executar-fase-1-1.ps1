<#
================================================================================
 SCRIPT MESTRE - FASE 1.1: Migracao da Tese
================================================================================

 Executa em sequencia todas as etapas da Fase 1.1:
   [0] Validar ambiente (Python, Pandoc, Pillow, LibreOffice opcional)
   [1] Distribuir arquivos dos ZIPs FASE_1_1
   [2] Localizar tese docx
   [3] Executar migracao (docx -> qmd + catalogo de figuras)
   [4] Escolher entre reexportacao local (requer LibreOffice) OU
       descompactar ZIP com figuras pre-processadas
   [5] Ajustar .gitignore para nao versionar 'migracao-tese/'
   [6] Validar resultado final
   [7] Oferecer commit + push para GitHub

 PRE-REQUISITOS:
   - Fases 0.2 e 0.3 concluidas
   - Python 3.10+ instalado
   - Quarto instalado (para ter pandoc)
   - Pillow instalado via pip (o script instala se faltar)
   - Tese docx acessivel
   - FASE_1_1_scripts.zip em Downloads (obrigatorio)
   - FASE_1_1_figuras_processadas.zip em Downloads (opcional se tiver LibreOffice)

 COMO EXECUTAR:
   cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\executar-fase-1-1.ps1

 O script pergunta antes de cada etapa importante, permitindo pular
 partes ja executadas em uma execucao anterior.

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"
$ZipScriptsPath = "$env:USERPROFILE\Downloads\FASE_1_1_scripts.zip"
$ZipFigurasPath = "$env:USERPROFILE\Downloads\FASE_1_1_figuras_processadas.zip"
$TesePath = "C:\Users\mceza\OneDrive\PESSOAL\CARREIRA PROFISSIONAL\DOUTORADO\TESE\TextoCorrigido\TeseCorrigidaMargemEspelhoInicio.docx"
$OutputDir = ".\migracao-tese"
$TempDir = "$env:TEMP\fase_1_1"

# Cores para output visual
$ESC = [char]27
$GREEN = "$ESC[32m"; $YELLOW = "$ESC[33m"; $RED = "$ESC[31m"
$BLUE  = "$ESC[34m"; $BOLD   = "$ESC[1m";  $RESET = "$ESC[0m"

function Write-Etapa($num, $titulo) {
    Write-Host ""
    Write-Host "$BOLD$BLUE================================================================================$RESET"
    Write-Host "$BOLD$BLUE ETAPA $num - $titulo$RESET"
    Write-Host "$BOLD$BLUE================================================================================$RESET"
}
function Write-OK($msg)   { Write-Host "$GREEN[OK]$RESET $msg" }
function Write-Warn($msg) { Write-Host "$YELLOW[!]$RESET $msg" }
function Write-Err($msg)  { Write-Host "$RED[X]$RESET $msg" }

function Perguntar($pergunta) {
    $resp = Read-Host "$pergunta (S/N)"
    return ($resp -eq "S" -or $resp -eq "s" -or $resp -eq "")
}

# ============================================================================
# ETAPA 0 - Validar ambiente
# ============================================================================
Write-Etapa "0" "Validar ambiente"

# Pasta do projeto
if (-not (Test-Path $ProjetoRaiz)) {
    Write-Err "Pasta do projeto nao encontrada: $ProjetoRaiz"
    Write-Host "Ajuste a variavel `$ProjetoRaiz no topo deste script."
    exit 1
}
Set-Location $ProjetoRaiz
Write-OK "Pasta do projeto: $ProjetoRaiz"

# _quarto.yml (confirma que projeto foi criado)
if (-not (Test-Path "_quarto.yml")) {
    Write-Err "_quarto.yml nao encontrado. Execute Fase 0.2 antes."
    exit 1
}
Write-OK "Projeto Quarto detectado"

# Python
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Err "Python nao instalado"
    exit 1
}
Write-OK "Python: $($py.Path)"

# Pandoc (do Quarto, geralmente escondido)
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) {
    Write-Host "Localizando pandoc do Quarto..."
    $quartoCmd = Get-Command quarto -ErrorAction SilentlyContinue
    if ($quartoCmd) {
        $pandocEncontrado = Get-ChildItem `
            -Path (Split-Path (Split-Path $quartoCmd.Source)) `
            -Filter "pandoc.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($pandocEncontrado) {
            $env:PATH = "$($pandocEncontrado.DirectoryName);$env:PATH"
            Write-OK "Pandoc adicionado ao PATH: $($pandocEncontrado.FullName)"
        }
    }
}
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
    $pandocVer = (pandoc --version) -split "`n" | Select-Object -First 1
    Write-OK "Pandoc: $pandocVer"
} else {
    Write-Err "Pandoc nao encontrado. Instale Quarto ou Pandoc."
    exit 1
}

# Pillow
$temPillow = & $py.Path -c "from PIL import Image; print('OK')" 2>$null
if ($temPillow -ne "OK") {
    Write-Warn "Pillow nao instalado. Instalando..."
    & $py.Path -m pip install Pillow --quiet --user
}
Write-OK "Pillow disponivel"

# LibreOffice (opcional)
$temLibreOffice = $false
$soffice = Get-Command soffice -ErrorAction SilentlyContinue
if (-not $soffice) { $soffice = Get-Command libreoffice -ErrorAction SilentlyContinue }
if (-not $soffice) {
    $libreOfficePath = "C:\Program Files\LibreOffice\program\soffice.exe"
    if (Test-Path $libreOfficePath) {
        $env:PATH = "$(Split-Path $libreOfficePath);$env:PATH"
        $temLibreOffice = $true
    }
} else {
    $temLibreOffice = $true
}

if ($temLibreOffice) {
    Write-OK "LibreOffice disponivel (conversao WMF->SVG habilitada)"
} else {
    Write-Warn "LibreOffice ausente. Usaremos ZIP pre-processado nas figuras."
}

# ============================================================================
# ETAPA 1 - Distribuir arquivos do ZIP de scripts
# ============================================================================
Write-Etapa "1" "Distribuir arquivos do FASE_1_1_scripts.zip"

$arquivosNecessarios = @(
    ".\setup\migrar-tese.py",
    ".\setup\reexportar-figuras.py",
    ".\setup\migrar-tese.ps1",
    ".\setup\MIGRACAO_TESE_GUIA.md"
)

$temTudo = $true
foreach ($arq in $arquivosNecessarios) {
    if (-not (Test-Path $arq)) { $temTudo = $false; break }
}

if ($temTudo) {
    Write-OK "Scripts ja distribuidos"
    $refazerScripts = Perguntar "Reextrair do ZIP (sobrescreve)?"
} else {
    $refazerScripts = $true
}

if ($refazerScripts) {
    if (-not (Test-Path $ZipScriptsPath)) {
        Write-Err "ZIP nao encontrado: $ZipScriptsPath"
        Write-Host "Baixe FASE_1_1_scripts.zip para Downloads e execute de novo."
        exit 1
    }
    Write-Host "Descompactando $ZipScriptsPath..."
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $ZipScriptsPath -DestinationPath $TempDir -Force

    Copy-Item "$TempDir\migrar-tese.py"        ".\setup\" -Force
    Copy-Item "$TempDir\reexportar-figuras.py" ".\setup\" -Force
    Copy-Item "$TempDir\migrar-tese.ps1"       ".\setup\" -Force
    Copy-Item "$TempDir\MIGRACAO_TESE_GUIA.md" ".\setup\" -Force
    Write-OK "Scripts copiados para .\setup\"
}

# ============================================================================
# ETAPA 2 - Localizar tese docx
# ============================================================================
Write-Etapa "2" "Localizar tese docx"

if (-not (Test-Path $TesePath)) {
    Write-Warn "Tese nao encontrada em: $TesePath"
    Write-Host "Buscando em locais comuns (pode demorar alguns segundos)..."

    $localizacoes = @(
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Dropbox"
    )

    $encontradas = @()
    foreach ($loc in $localizacoes) {
        if (Test-Path $loc) {
            $achou = Get-ChildItem -Path $loc -Filter "*Tese*.docx" `
                -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
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
# ETAPA 3 - Executar migracao (docx -> qmd + catalogo)
# ============================================================================
Write-Etapa "3" "Executar migracao (docx -> qmd + catalogo)"

$qmdBruto = "$OutputDir\qmd\tese-bruta.qmd"
$catalogoCSV = "$OutputDir\catalogo\catalogo-figuras.csv"

if ((Test-Path $qmdBruto) -and (Test-Path $catalogoCSV)) {
    Write-OK "Migracao ja executada anteriormente"
    $refazerMigracao = Perguntar "Refazer migracao (sobrescreve)?"
} else {
    $refazerMigracao = $true
}

if ($refazerMigracao) {
    & $py.Path ".\setup\migrar-tese.py" $TesePath --output-dir $OutputDir
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha na migracao"
        exit 1
    }
    Write-OK "Migracao concluida"
}

# ============================================================================
# ETAPA 4 - Reexportacao (local com LibreOffice OU ZIP pre-processado)
# ============================================================================
Write-Etapa "4" "Reexportacao de figuras (PNG e SVG)"

$pastaProcessadas = "$OutputDir\figuras-processadas"
$jaTemProcessadas = (Test-Path "$pastaProcessadas\manter") -and
                    (Test-Path "$pastaProcessadas\refazer") -and
                    (Test-Path "$pastaProcessadas\avaliar")

if ($jaTemProcessadas) {
    Write-OK "Figuras processadas ja existem"
    $refazerFiguras = Perguntar "Refazer reexportacao?"
} else {
    $refazerFiguras = $true
}

if ($refazerFiguras) {
    if ($temLibreOffice) {
        # Opcao A: reexportar localmente
        Write-Host "Executando reexportacao local (LibreOffice disponivel)..."
        & $py.Path ".\setup\reexportar-figuras.py" $catalogoCSV `
            --figuras "$OutputDir\figuras" `
            --output $pastaProcessadas

        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Reexportacao local falhou. Tentando ZIP pre-processado..."
            $tentarZip = $true
        } else {
            Write-OK "Reexportacao local concluida"
            $tentarZip = $false
        }
    } else {
        $tentarZip = $true
    }

    if ($tentarZip) {
        if (Test-Path $ZipFigurasPath) {
            Write-Host "Descompactando ZIP pre-processado ($ZipFigurasPath)..."
            Expand-Archive -Path $ZipFigurasPath `
                -DestinationPath $OutputDir -Force
            Write-OK "Figuras pre-processadas descompactadas"
        } else {
            Write-Err "ZIP pre-processado nao encontrado: $ZipFigurasPath"
            Write-Warn "Instale LibreOffice OU baixe FASE_1_1_figuras_processadas.zip"
            Write-Host "  Continuando sem figuras processadas..."
        }
    }
}

# ============================================================================
# ETAPA 5 - Ajustar .gitignore
# ============================================================================
Write-Etapa "5" "Ajustar .gitignore para nao versionar migracao-tese/"

$gitignore = Get-Content .gitignore -ErrorAction SilentlyContinue -Raw
if ($gitignore -and $gitignore -match "migracao-tese") {
    Write-OK ".gitignore ja contem 'migracao-tese/'"
} else {
    Add-Content .gitignore "`n# Fase 1.1 - Material bruto gerado (nao versionar)`nmigracao-tese/"
    Write-OK ".gitignore atualizado"
}

# ============================================================================
# ETAPA 6 - Validar resultado
# ============================================================================
Write-Etapa "6" "Validar resultado final"

$checks = @{
    "qmd bruto"           = "$OutputDir\qmd\tese-bruta.qmd"
    "qmd Cap I"           = "$OutputDir\qmd\tese-cap-i.qmd"
    "qmd Cap V"           = "$OutputDir\qmd\tese-cap-v.qmd"
    "figuras originais"   = "$OutputDir\figuras\media"
    "figuras MANTER"      = "$pastaProcessadas\manter"
    "figuras REFAZER"     = "$pastaProcessadas\refazer"
    "figuras AVALIAR"     = "$pastaProcessadas\avaliar"
    "catalogo CSV"        = "$OutputDir\catalogo\catalogo-figuras.csv"
    "catalogo MD"         = "$OutputDir\catalogo\catalogo-figuras.md"
}

$tudoOk = $true
foreach ($check in $checks.GetEnumerator()) {
    if (Test-Path $check.Value) {
        if ((Get-Item $check.Value).PSIsContainer) {
            $count = (Get-ChildItem $check.Value -ErrorAction SilentlyContinue).Count
            Write-OK "$($check.Key): $count arquivos"
        } else {
            $size = [math]::Round((Get-Item $check.Value).Length / 1KB)
            Write-OK "$($check.Key): $size KB"
        }
    } else {
        Write-Err "$($check.Key): AUSENTE"
        $tudoOk = $false
    }
}

if (-not $tudoOk) {
    Write-Warn "Alguns componentes faltando. Revise as etapas acima."
}

# ============================================================================
# ETAPA 7 - Commit + push (opcional)
# ============================================================================
Write-Etapa "7" "Versionar no Git (commit + push)"

# Ver se ha algo para commitar
$status = git status --porcelain 2>$null
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-OK "Nenhuma mudanca pendente no Git"
} else {
    Write-Host "Mudancas detectadas no Git:"
    git status --short
    Write-Host ""

    if (Perguntar "Commitar scripts + .gitignore no Git?") {
        # Adicionar apenas o que interessa
        git add .gitignore
        if (Test-Path ".\setup\migrar-tese.py")        { git add .\setup\migrar-tese.py }
        if (Test-Path ".\setup\migrar-tese.ps1")       { git add .\setup\migrar-tese.ps1 }
        if (Test-Path ".\setup\reexportar-figuras.py") { git add .\setup\reexportar-figuras.py }
        if (Test-Path ".\setup\MIGRACAO_TESE_GUIA.md") { git add .\setup\MIGRACAO_TESE_GUIA.md }
        if (Test-Path ".\executar-fase-1-1.ps1")       { git add .\executar-fase-1-1.ps1 }

        git status --short
        Write-Host ""

        if (Perguntar "Confirmar commit?") {
            $msg = "Fase 1.1: scripts de migracao da tese docx -> qmd + catalogo de figuras`n`n" +
                   "- migrar-tese.py: pipeline completo (pandoc + analise + classificacao)`n" +
                   "- reexportar-figuras.py: converte TIFF->PNG e WMF->SVG conforme catalogo`n" +
                   "- migrar-tese.ps1: orquestrador PowerShell (auto-descobre pandoc do Quarto)`n" +
                   "- MIGRACAO_TESE_GUIA.md: guia de uso das figuras processadas`n" +
                   "- executar-fase-1-1.ps1: script mestre orquestrador da Fase 1.1`n`n" +
                   "Nao versiona migracao-tese/ (~100 MB de material bruto gerado)"
            git commit -m $msg

            if ($LASTEXITCODE -eq 0) {
                Write-OK "Commit realizado"
                if (Perguntar "Fazer push para GitHub?") {
                    git push
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "Push realizado. GitHub Action ira renderizar em ~3 min."
                    }
                }
            }
        }
    }
}

# ============================================================================
# CONCLUSAO
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 1.1"

Write-Host ""
Write-Host "$BOLD Status final:$RESET"
Write-Host "  $GREEN [OK] qmd bruto e por capitulo gerados $RESET"
Write-Host "  $GREEN [OK] 293 figuras extraidas e categorizadas $RESET"
Write-Host "  $GREEN [OK] Catalogo CSV + Markdown disponivel $RESET"
if ($jaTemProcessadas -or (Test-Path "$pastaProcessadas\manter")) {
    Write-Host "  $GREEN [OK] Figuras processadas (PNG e SVG) prontas para uso $RESET"
}
Write-Host ""
Write-Host "$BOLD Localizacao dos arquivos:$RESET"
Write-Host "  qmd:               $OutputDir\qmd\"
Write-Host "  Figuras originais: $OutputDir\figuras\media\"
Write-Host "  Figuras finais:    $OutputDir\figuras-processadas\"
Write-Host "  Catalogo:          $OutputDir\catalogo\"
Write-Host ""
Write-Host "$BOLD Proximos passos possiveis:$RESET"
Write-Host "  A - Fase 0.4 (Zotero + Better BibTeX) - ~1h"
Write-Host "  B - Fase 1.2 (marcacao MANTER/REESCREVER/CORTAR) - ~2-3h"
Write-Host "  C - Fase 3.1 (escrever Cap 1: Por que DOE em manufatura) - ~3-4h"
Write-Host ""
Write-Host "Consulte:"
Write-Host "  .\setup\MIGRACAO_TESE_GUIA.md   (uso das figuras processadas)"
Write-Host "  $OutputDir\catalogo\catalogo-figuras.md   (visao geral do material)"
Write-Host ""
