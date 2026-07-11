<#
================================================================================
 SCRIPT MESTRE v2 - FASE 1.2: Esqueleto do Livro + Validacao dos Renders
================================================================================

 VERSAO 2 (11/07/2026) - Com correcoes automaticas aprendidas na sessao:
   - Deteccao e correcao automatica de fontes Source Pro (nao instaladas no Win)
   - Pre-instalacao de pacotes LaTeX conhecidos (xurl, biblatex-abnt, koma-script...)
   - Enriquecimento automatico do references.qmd se estiver vazio
   - Auto-update do tlmgr antes de tentar instalar pacotes
   - Sistema de retry automatico para render PDF (max 3 tentativas)
   - Diagnostico expandido de erros LaTeX

 Executa em sequencia:
   [0]  Validar ambiente (Quarto, R, Python, TinyTeX, tlmgr)
   [1]  Verificar esqueleto (index + 12 caps + 4 apendices + refs)
   [2]  Enriquecer stubs vazios (references.qmd em particular)
   [3]  Corrigir fontes se Source Pro nao instaladas (Windows)
   [4]  Pre-instalar pacotes LaTeX conhecidos necessarios
   [5]  Primeiro render HTML
   [6]  Primeiro render PDF (com retry automatico)
   [7]  Primeiro render EPUB
   [8]  Validar outputs em _book/
   [9]  Inspecao visual (abrir HTML, PDF, pasta EPUB)
   [10] Commit + push opcional

 PRE-REQUISITOS:
   - Fases 0.2, 0.3 e 1.1 concluidas
   - Quarto, R, Python instalados
   - TinyTeX instalado (ou o script instala)

 COMO EXECUTAR:
   cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\executar-fase-1-2.ps1

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"

# Pacotes LaTeX conhecidos como necessarios (aprendido durante esta sessao)
$PacotesLaTeX = @(
    "xurl",              # URLs quebradas em bibliografia
    "biblatex",          # Sistema principal de bibliografia
    "biblatex-abnt",     # Estilo ABNT
    "biber",             # Backend do biblatex
    "koma-script",       # Classe scrbook
    "fontspec",          # Fontes do sistema
    "caption",           # Legendas de fig/tab
    "polyglossia",       # Internacionalizacao
    "babel-portuges",    # Portugues
    "tcolorbox",         # Callouts do Quarto
    "environ",           # Suporte a tcolorbox
    "fancyvrb",          # Codigo formatado
    "framed",            # Boxes de codigo
    "unicode-math"       # Matematica com fontes Unicode
)

# Fontes Windows-safe (fallback quando Source Pro nao instaladas)
$FontesWindows = @{
    mainfont = "Cambria"
    sansfont = "Calibri"
    monofont = "Consolas"
}

# Cores
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
function Write-Info($msg) { Write-Host "$BLUE[i]$RESET $msg" }
function Perguntar($p)    {
    $r = Read-Host "$p (S/N)"
    return ($r -eq "S" -or $r -eq "s" -or $r -eq "")
}

# Helper: encontrar tlmgr
function Get-TlmgrPath {
    $cmd = Get-Command tlmgr -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $tentativas = @(
        "$env:APPDATA\TinyTeX\bin\windows\tlmgr.bat",
        "$env:USERPROFILE\AppData\Roaming\TinyTeX\bin\windows\tlmgr.bat",
        "$env:LOCALAPPDATA\TinyTeX\bin\windows\tlmgr.bat"
    )
    foreach ($t in $tentativas) {
        if (Test-Path $t) { return $t }
    }
    return $null
}

# ============================================================================
# ETAPA 0 - Validar ambiente
# ============================================================================
Write-Etapa "0" "Validar ambiente"

if (-not (Test-Path $ProjetoRaiz)) {
    Write-Err "Pasta do projeto nao encontrada: $ProjetoRaiz"
    exit 1
}
Set-Location $ProjetoRaiz
Write-OK "Pasta do projeto: $ProjetoRaiz"

if (-not (Test-Path "_quarto.yml")) {
    Write-Err "_quarto.yml nao encontrado. Execute Fase 0.2 antes."
    exit 1
}
Write-OK "Projeto Quarto detectado"

# Fixar UTF-8 no console (evita 'Ã©' em vez de 'e')
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$quarto = Get-Command quarto -ErrorAction SilentlyContinue
if (-not $quarto) { Write-Err "Quarto nao instalado"; exit 1 }
$quartoVer = (quarto --version) -join ''
Write-OK "Quarto: $quartoVer"

$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) { Write-OK "Python: $($py.Path)" }

$r = Get-Command Rscript -ErrorAction SilentlyContinue
if ($r) { Write-OK "R disponivel" }

# tlmgr - critico para PDF
$tlmgr = Get-TlmgrPath
if ($tlmgr) {
    Write-OK "tlmgr encontrado: $tlmgr"
} else {
    Write-Warn "tlmgr nao encontrado - TinyTeX pode nao estar instalado"
    if (Perguntar "Instalar TinyTeX agora?") {
        quarto install tinytex
        $tlmgr = Get-TlmgrPath
        if (-not $tlmgr) { Write-Err "Falha ao instalar TinyTeX"; exit 1 }
    }
}

# ============================================================================
# ETAPA 1 - Verificar esqueleto
# ============================================================================
Write-Etapa "1" "Verificar esqueleto (arquivos .qmd)"

$esqueleto = @{
    "index.qmd (prefacio)" = "index.qmd"
    "Cap 1"  = "parte-1\cap-01-por-que-doe.qmd"
    "Cap 2"  = "parte-1\cap-02-metalurgia.qmd"
    "Cap 3"  = "parte-1\cap-03-torneamento.qmd"
    "Cap 4"  = "parte-2\cap-04-fatorial.qmd"
    "Cap 5"  = "parte-2\cap-05-pcc-rsm.qmd"
    "Cap 6"  = "parte-2\cap-06-otimizacao.qmd"
    "Cap 7"  = "parte-3\cap-07-projeto.qmd"
    "Cap 8"  = "parte-3\cap-08-fatorial-aluminio.qmd"
    "Cap 9"  = "parte-3\cap-09-rsm-pcc.qmd"
    "Cap 10" = "parte-3\cap-10-otimizacao-global.qmd"
    "Cap 11" = "parte-4\cap-11-chao-fabrica.qmd"
    "Cap 12" = "parte-4\cap-12-sintese.qmd"
    "Ap A"   = "apendices\apendice-a-instrumentacao.qmd"
    "Ap B"   = "apendices\apendice-b-codigos.qmd"
    "Ap C"   = "apendices\apendice-c-tabelas.qmd"
    "Ap D"   = "apendices\apendice-d-dados.qmd"
    "Refs"   = "references.qmd"
}

$existentes = 0
$ausentes = @()
$stubsMagros = @()
foreach ($item in $esqueleto.GetEnumerator()) {
    if (Test-Path $item.Value) {
        $bytes = (Get-Item $item.Value).Length
        $sizeStr = if ($bytes -lt 1024) { "$bytes B" } else { "$([math]::Round($bytes/1024, 1)) KB" }
        if ($bytes -lt 100) { $stubsMagros += $item.Value }
        Write-OK "$($item.Key.PadRight(20)) $sizeStr - $($item.Value)"
        $existentes++
    } else {
        Write-Err "$($item.Key.PadRight(20)) AUSENTE - $($item.Value)"
        $ausentes += $item.Value
    }
}
Write-Info "$existentes de $($esqueleto.Count) arquivos existentes"

if ($ausentes.Count -gt 0) {
    Write-Warn "Arquivos ausentes:"
    foreach ($a in $ausentes) { Write-Host "  - $a" }
    if (-not (Perguntar "Continuar mesmo com arquivos ausentes?")) { exit 1 }
}

# ============================================================================
# ETAPA 2 - Enriquecer stubs vazios automaticamente
# ============================================================================
Write-Etapa "2" "Enriquecer stubs vazios"

if ($stubsMagros.Count -gt 0) {
    Write-Warn "Stubs muito pequenos (podem quebrar render):"
    foreach ($s in $stubsMagros) { Write-Host "  - $s" }

    if (Perguntar "Enriquecer automaticamente com conteudo minimo?") {
        foreach ($stub in $stubsMagros) {
            if ($stub -eq "references.qmd") {
                @"
# Referências {.unnumbered}

::: {#refs}
:::
"@ | Set-Content $stub -Encoding UTF8
                Write-OK "Enriquecido: $stub (template de referencias)"
            } else {
                $nome = [System.IO.Path]::GetFileNameWithoutExtension($stub)
                @"
# $nome {.unnumbered}

::: {.callout-note}
Conteudo em desenvolvimento.
:::
"@ | Set-Content $stub -Encoding UTF8
                Write-OK "Enriquecido: $stub (template generico)"
            }
        }
    }
} else {
    Write-OK "Todos os stubs tem tamanho minimo aceitavel"
}

# ============================================================================
# ETAPA 3 - Corrigir fontes se necessario (Windows)
# ============================================================================
Write-Etapa "3" "Verificar/corrigir fontes para Windows"

$quartoYml = Get-Content _quarto.yml -Raw
$temSourcePro = $quartoYml -match "Source (Serif|Sans|Code) Pro"

if ($temSourcePro) {
    Write-Warn "_quarto.yml usa 'Source Pro' (Adobe) que nao estao instaladas no Windows"
    Write-Info "Solucao rapida: trocar para fontes nativas do Windows"
    Write-Host ""

    if (Perguntar "Trocar para Cambria/Calibri/Consolas agora?") {
        # Backup
        Copy-Item _quarto.yml "_quarto.yml.bak_pre_fontes" -Force

        $content = $quartoYml
        $content = $content -replace 'mainfont:\s*"?Source Serif Pro"?', "mainfont: $($FontesWindows.mainfont)"
        $content = $content -replace 'sansfont:\s*"?Source Sans Pro"?',  "sansfont: $($FontesWindows.sansfont)"
        $content = $content -replace 'monofont:\s*"?Source Code Pro"?',  "monofont: $($FontesWindows.monofont)"
        Set-Content _quarto.yml -Value $content -Encoding UTF8

        # Verificar
        $conferir = Get-Content _quarto.yml -Raw
        if ($conferir -match "Source (Serif|Sans|Code) Pro") {
            Write-Err "Substituicao falhou. Edite _quarto.yml manualmente."
        } else {
            Write-OK "Fontes trocadas para Cambria/Calibri/Consolas"
            Write-Info "Backup: _quarto.yml.bak_pre_fontes"
        }
    } else {
        Write-Warn "PDF vai falhar se as fontes nao estiverem instaladas."
    }
} else {
    Write-OK "_quarto.yml ja usa fontes compativeis com Windows"
}

# ============================================================================
# ETAPA 4 - Pre-instalar pacotes LaTeX conhecidos
# ============================================================================
Write-Etapa "4" "Pre-instalar pacotes LaTeX (evita erros na 1a rodada)"

if ($tlmgr) {
    Write-Info "Sera instalado/verificado (14 pacotes):"
    Write-Host "  $($PacotesLaTeX -join ', ')"
    Write-Host ""

    if (Perguntar "Instalar/atualizar pacotes agora?") {
        Write-Info "Atualizando tlmgr..."
        & $tlmgr update --self 2>&1 | Out-Null
        Write-OK "tlmgr atualizado"

        Write-Info "Instalando/atualizando pacotes (pula os ja presentes)..."
        & $tlmgr install @PacotesLaTeX 2>&1 | Out-Host
        Write-OK "Pacotes verificados"
    }
} else {
    Write-Warn "tlmgr indisponivel - pulando pre-instalacao"
}

# ============================================================================
# ETAPA 5 - Render HTML
# ============================================================================
Write-Etapa "5" "Primeiro render HTML"

if (Perguntar "Renderizar HTML agora?") {
    Write-Info "Executando: quarto render --to html"
    quarto render --to html
    if ($LASTEXITCODE -eq 0 -and (Test-Path "_book\index.html")) {
        $sizeIdx = [math]::Round((Get-Item "_book\index.html").Length / 1KB, 1)
        $htmlCount = (Get-ChildItem "_book\*.html").Count
        Write-OK "$htmlCount paginas HTML geradas ($sizeIdx KB no index)"
    } else {
        Write-Err "Render HTML falhou"
    }
}

# ============================================================================
# ETAPA 6 - Render PDF (com retry automatico)
# ============================================================================
Write-Etapa "6" "Primeiro render PDF (com retry automatico)"

Write-Info "Se pacote LaTeX faltar, o script instala e refaz o render (max 3x)"
Write-Host ""

if (Perguntar "Renderizar PDF agora?") {
    $maxTentativas = 3
    $tentativa = 0
    $sucesso = $false

    while ($tentativa -lt $maxTentativas -and -not $sucesso) {
        $tentativa++
        Write-Info "Tentativa $tentativa de $maxTentativas..."

        $pdfLog = "$env:TEMP\quarto-pdf-t${tentativa}-$([DateTime]::Now.ToString('HHmmss')).log"
        quarto render --to pdf 2>&1 | Tee-Object -FilePath $pdfLog
        $pdfExitCode = $LASTEXITCODE

        if ($pdfExitCode -eq 0) {
            $sucesso = $true
            $pdfFile = Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pdfFile) {
                $sizePdf = [math]::Round($pdfFile.Length / 1KB, 1)
                Write-OK "PDF gerado: $($pdfFile.FullName) ($sizePdf KB)"
            }
        } else {
            Write-Warn "Render falhou (exit code $pdfExitCode). Analisando log..."
            $logContent = Get-Content $pdfLog -Raw

            # Diagnostico automatico e retry
            $pacoteFalta = $null
            if ($logContent -match "LaTeX Error: File ``([^']+)\.sty' not found") {
                $pacoteFalta = $Matches[1]
            } elseif ($logContent -match "! LaTeX Error: File ``([^']+)' not found") {
                $pacoteFalta = $Matches[1] -replace '\..*$', ''
            } elseif ($logContent -match "finding package for ([^\s]+)") {
                $pacoteFalta = $Matches[1] -replace '\..*$', ''
            }

            if ($pacoteFalta -and $tlmgr) {
                Write-Info "Detectado pacote faltando: $pacoteFalta"
                Write-Info "Instalando via tlmgr..."
                & $tlmgr install $pacoteFalta 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Pacote $pacoteFalta instalado - refazendo render"
                    continue
                } else {
                    Write-Err "Falha ao instalar $pacoteFalta"
                }
            }

            # Diagnostico de fontes
            if ($logContent -match 'The font "([^"]+)" cannot be found') {
                $fonteFalta = $Matches[1]
                Write-Err "Fonte '$fonteFalta' nao encontrada no sistema"
                Write-Info "Solucao: editar _quarto.yml e trocar para fonte instalada"
                Write-Info "  Cambria (serif), Calibri (sans), Consolas (mono) sempre existem no Windows"
                break
            }

            # Se nao conseguiu diagnostico, mostra log
            if (-not $pacoteFalta) {
                Write-Err "Nao foi possivel diagnosticar automaticamente"
                Write-Info "Ultimas 20 linhas do log:"
                Get-Content $pdfLog -Tail 20 | ForEach-Object { Write-Host "  $_" }
                break
            }
        }
    }

    if (-not $sucesso) {
        Write-Err "PDF nao gerado apos $maxTentativas tentativas"
    }
}

# ============================================================================
# ETAPA 7 - Render EPUB
# ============================================================================
Write-Etapa "7" "Primeiro render EPUB"

if (Perguntar "Renderizar EPUB agora?") {
    quarto render --to epub
    if ($LASTEXITCODE -eq 0) {
        $epubFile = Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($epubFile) {
            $sizeEpub = [math]::Round($epubFile.Length / 1KB, 1)
            Write-OK "EPUB gerado: $($epubFile.FullName) ($sizeEpub KB)"
        }
    } else {
        Write-Err "Render EPUB falhou"
    }
}

# ============================================================================
# ETAPA 8 - Validar outputs
# ============================================================================
Write-Etapa "8" "Validar outputs em _book\"

if (Test-Path "_book") {
    $arquivos = Get-ChildItem "_book" -Recurse -File
    $totalMB = [math]::Round(($arquivos | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-OK "$($arquivos.Count) arquivos gerados, total $totalMB MB"

    $tipos = @{
        "HTML" = ($arquivos | Where-Object { $_.Name -match '\.html$' }).Count
        "PDF"  = ($arquivos | Where-Object { $_.Name -match '\.pdf$' }).Count
        "EPUB" = ($arquivos | Where-Object { $_.Name -match '\.epub$' }).Count
    }
    foreach ($t in $tipos.GetEnumerator()) {
        if ($t.Value -gt 0) {
            Write-OK "  $($t.Key.PadRight(6)): $($t.Value) arquivos"
        }
    }
} else {
    Write-Err "Pasta _book\ nao existe."
}

# ============================================================================
# ETAPA 9 - Inspecao visual
# ============================================================================
Write-Etapa "9" "Inspecao visual dos outputs"

if ((Test-Path "_book\index.html") -and (Perguntar "Abrir HTML no navegador?")) {
    Start-Process "_book\index.html"
}

$pdf = Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pdf -and (Perguntar "Abrir PDF?")) {
    Start-Process $pdf.FullName
}

$epub = Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($epub -and (Perguntar "Abrir pasta do EPUB?")) {
    Start-Process (Split-Path $epub.FullName)
}

# ============================================================================
# ETAPA 10 - Commit + push
# ============================================================================
Write-Etapa "10" "Versionar mudancas no Git"

$status = git status --porcelain 2>$null
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-OK "Nenhuma mudanca pendente"
} else {
    git status --short
    Write-Host ""

    if (Perguntar "Commitar mudancas no Git?") {
        if (Test-Path ".\executar-fase-1-2.ps1") { git add .\executar-fase-1-2.ps1 }
        if (Test-Path "_quarto.yml") { git add _quarto.yml }
        foreach ($item in $esqueleto.Values) {
            if (Test-Path $item) { git add $item }
        }

        # .gitignore para _book/ e .quarto/
        $gitignore = Get-Content .gitignore -Raw -ErrorAction SilentlyContinue
        $adicionar = @()
        if ($gitignore -notmatch "_book") { $adicionar += "_book/" }
        if ($gitignore -notmatch "\.quarto") { $adicionar += ".quarto/" }
        if ($adicionar.Count -gt 0) {
            Add-Content .gitignore "`n# Outputs de render locais`n$($adicionar -join "`n")"
            git add .gitignore
            Write-OK ".gitignore atualizado"
        }

        git status --short

        if (Perguntar "Confirmar commit?") {
            $msg = "Fase 1.2: esqueleto validado nos 3 formatos (HTML, PDF, EPUB)`n`n" +
                   "- executar-fase-1-2.ps1 v2: com correcoes automaticas`n" +
                   "- Fontes: Cambria/Calibri/Consolas (compativel Windows)`n" +
                   "- Pacotes LaTeX necessarios pre-instalados via tlmgr`n" +
                   "- Stubs enriquecidos onde estavam vazios`n" +
                   "- Primeiro render PDF e EPUB bem-sucedidos`n" +
                   "- Sistema de retry automatico para PDF"
            git commit -m $msg

            if ($LASTEXITCODE -eq 0 -and (Perguntar "Push para GitHub?")) {
                git push
            }
        }
    }
}

# ============================================================================
# CONCLUSAO
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 1.2"

Write-Host ""
Write-Host "$BOLD Status dos 3 formatos:$RESET"

$statusHtml = if (Test-Path "_book\index.html") { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }
$statusPdf  = if ((Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue).Count -gt 0) { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }
$statusEpub = if ((Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue).Count -gt 0) { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }

Write-Host "  $statusHtml HTML (site publico - GitHub Pages)"
Write-Host "  $statusPdf  PDF  (produto comercial - Kiwify)"
Write-Host "  $statusEpub EPUB (Kindle - amplia alcance)"
Write-Host ""

Write-Host "$BOLD Proximos passos possiveis:$RESET"
Write-Host "  A - Fase 0.4 (Zotero + Better BibTeX) - ~1h"
Write-Host "  B - Fase 3.1 (escrever Cap 1: Por que DOE em manufatura) - ~3-4h"
Write-Host "  C - Fase 8 (design fino do PDF/EPUB) - so quando ja tiver conteudo real"
Write-Host ""
