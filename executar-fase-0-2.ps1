# ============================================================================
# executar-fase-0-2.ps1
#
# Orquestrador interativo da Fase 0.2 - Setup Ambiente de Producao
#
# 6 etapas de verificacao/setup:
#   1. Quarto CLI (versao + PATH)
#   2. TinyTeX/LaTeX (para PDF)
#   3. Diretorio do projeto Quarto book
#   4. Configuracao _quarto.yml (html, pdf, epub)
#   5. Engine R + Python (reticulate)
#   6. Estrutura de pastas
#
# Modo:
#   - Health check (verifica sem modificar) - padrao
#   - Setup interativo (oferece instalacao/correcao quando faltando)
#
# Persistencia:
#   setup/fase-0-2-progresso.json    - estado JSON
#   setup/FASE_0_2_AMBIENTE.md       - relatorio Markdown
#
# USO:
#   .\executar-fase-0-2.ps1                       # Health check completo
#   .\executar-fase-0-2.ps1 -Etapa 1              # So verifica Quarto
#   .\executar-fase-0-2.ps1 -Status               # Ver ultimo estado
#   .\executar-fase-0-2.ps1 -QuickCheck           # Sem interacao
#   .\executar-fase-0-2.ps1 -ProjectPath "C:\..." # Path especifico
#   .\executar-fase-0-2.ps1 -Reset                # Zerar
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateRange(1, 6)]
    [int]$Etapa = 0,
    [switch]$Status,
    [switch]$Reset,
    [switch]$QuickCheck,
    [string]$ProjectPath = ""
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup       = ".\setup"
$Script:ArquivoProgresso = ".\setup\fase-0-2-progresso.json"
$Script:ArquivoDoc       = ".\setup\FASE_0_2_AMBIENTE.md"

# Paths candidatos do projeto (auto-deteccao)
$Script:PathsCandidatos = @(
    "$env:USERPROFILE\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM",
    "$env:USERPROFILE\Dropbox\PROGRAMACAO\LIVRO_DOE_USINAGEM",
    "$env:USERPROFILE\Documents\LIVRO_DOE_USINAGEM",
    (Get-Location).Path
)

# Paths onde procurar ferramentas
$Script:PathsFerramentas = @{
    Quarto = @(
        "C:\Program Files\Quarto\bin\quarto.exe",
        "$env:LOCALAPPDATA\Programs\Quarto\bin\quarto.exe",
        "$env:ProgramFiles\Quarto\bin\quarto.exe"
    )
    Git = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files\Git\bin\git.exe"
    )
    R = @(
        "C:\Program Files\R\R-4.5.1\bin\Rscript.exe",
        "C:\Program Files\R\R-4.4.0\bin\Rscript.exe",
        "C:\Program Files\R\R-4.3.0\bin\Rscript.exe"
    )
    Python = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "C:\Python313\python.exe",
        "C:\Python312\python.exe"
    )
}

# Estrutura esperada de pastas
$Script:EstruturaEsperada = @(
    "parte-1",
    "parte-2",
    "parte-3",
    "parte-4",
    "apendices",
    "figuras",
    "dados",
    "codigos",
    "styles",
    "setup"
)

# Capitulos esperados por parte
$Script:CapitulosEsperados = @{
    "parte-1" = @("cap-01-por-que-doe.qmd", "cap-02-metalurgia.qmd", "cap-03-torneamento.qmd")
    "parte-2" = @("cap-04-fatorial.qmd", "cap-05-pcc-rsm.qmd", "cap-06-otimizacao.qmd")
    "parte-3" = @("cap-07-projeto.qmd", "cap-08-fatorial-aluminio.qmd", "cap-09-rsm-pcc.qmd", "cap-10-otimizacao-global.qmd")
    "parte-4" = @("cap-11-chao-fabrica.qmd", "cap-12-sintese.qmd")
    "apendices" = @("apendice-a-instrumentacao.qmd", "apendice-b-codigos.qmd", "apendice-c-tabelas.qmd", "apendice-d-dados.qmd")
}

# ============================================================================
# HELPERS DE OUTPUT
# ============================================================================
function Write-Titulo($texto) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Blue
    Write-Host $texto -ForegroundColor Blue
    Write-Host ("=" * 78) -ForegroundColor Blue
}
function Write-Etapa($n, $titulo) {
    Write-Host ""
    Write-Host "--- [$n] $titulo ---" -ForegroundColor Cyan
}
function Write-OK($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Host "[i]    $msg" -ForegroundColor Cyan }
function Write-Warn($msg)  { Write-Host "[!]    $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[X]    $msg" -ForegroundColor Red }
function Write-Item($msg)  { Write-Host "       $msg" }

function Ask-YesNo($pergunta, $default = "S") {
    if ($QuickCheck) { return ($default -eq "S") }
    while ($true) {
        $r = Read-Host "$pergunta (S/N) [$default]"
        if ([string]::IsNullOrWhiteSpace($r)) { $r = $default }
        if ($r -match '^[SsYy]') { return $true }
        if ($r -match '^[Nn]')   { return $false }
        Write-Warn "Responda S ou N"
    }
}

# ============================================================================
# CORRIGIR PATH (temporariamente para esta sessao)
# ============================================================================
function Fix-Path {
    $adicionados = @()

    foreach ($tool in $Script:PathsFerramentas.Keys) {
        foreach ($p in $Script:PathsFerramentas[$tool]) {
            if (Test-Path $p) {
                $dir = Split-Path $p -Parent
                if ($env:PATH -notmatch [regex]::Escape($dir)) {
                    $env:PATH = "$dir;$env:PATH"
                    $adicionados += "$tool -> $dir"
                }
                break
            }
        }
    }

    return $adicionados
}

# ============================================================================
# PERSISTENCIA DE ESTADO
# ============================================================================
function Initialize-Progresso {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }

    if (Test-Path $Script:ArquivoProgresso) {
        $json = Get-Content $Script:ArquivoProgresso -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    }

    $progresso = [PSCustomObject]@{
        fase           = "0.2"
        titulo         = "Setup Ambiente de Producao"
        iniciada_em    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        project_path   = ""
        verificacoes   = @()
    }
    return $progresso
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10

    $path = if (Test-Path $Script:ArquivoProgresso) {
        (Resolve-Path $Script:ArquivoProgresso).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoProgresso
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# Deduplicacao embutida: se verificacao ja existe (mesmo id), sobrescreve
function Set-Verificacao($progresso, $id, $nome, $status, $detalhes = "", $acao = "") {
    $verif = [PSCustomObject]@{
        id            = $id
        nome          = $nome
        status        = $status   # OK | AVISO | ERRO | PENDENTE
        detalhes      = $detalhes
        acao          = $acao
        verificada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $novaLista = @($progresso.verificacoes | Where-Object { $_.id -ne $id })
    $novaLista += $verif
    $progresso.verificacoes = @($novaLista)

    return $verif
}

function Get-Verificacao($progresso, $id) {
    return $progresso.verificacoes | Where-Object { $_.id -eq $id } | Select-Object -First 1
}

# ============================================================================
# GERAR DOCUMENTACAO
# ============================================================================
function Update-Documentacao($progresso) {
    $md = "# Fase 0.2 - Ambiente de Producao`n`n"
    $md += "**Gerado automaticamente por executar-fase-0-2.ps1**`n"
    $md += "Ultima atualizacao: $($progresso.atualizada_em)`n`n"

    if ($progresso.project_path) {
        $md += "**Diretorio do projeto:** ``$($progresso.project_path)```n`n"
    }

    $md += "Total de verificacoes: $($progresso.verificacoes.Count) de 6`n`n---`n`n"

    $ordenadas = $progresso.verificacoes | Sort-Object id

    foreach ($v in $ordenadas) {
        $icone = switch ($v.status) {
            "OK"       { "[x]" }
            "AVISO"    { "[!]" }
            "ERRO"     { "[X]" }
            "PENDENTE" { "[ ]" }
            default    { "[?]" }
        }

        $md += "## $($v.id). $($v.nome) $icone`n`n"
        $md += "**Status:** $($v.status)`n`n"
        if ($v.detalhes) {
            $md += "**Detalhes:** $($v.detalhes)`n`n"
        }
        if ($v.acao) {
            $md += "**Acao necessaria:** $($v.acao)`n`n"
        }
        $md += "**Verificada em:** $($v.verificada_em)`n`n---`n`n"
    }

    # Adicionar secao de comandos uteis
    $md += "## Comandos uteis`n`n"
    $md += "### Navegar para o projeto`n"
    $md += "``````powershell`n"
    if ($progresso.project_path) {
        $md += "cd '$($progresso.project_path)'`n"
    } else {
        $md += "cd C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM`n"
    }
    $md += "``````" + "`n`n"

    $md += "### Renderizar`n"
    $md += "``````powershell`n"
    $md += "quarto render --to html          # Apenas HTML (rapido)`n"
    $md += "quarto render                    # Todos os formatos`n"
    $md += "quarto render parte-1\cap-01-por-que-doe.qmd  # Um capitulo`n"
    $md += "``````" + "`n`n"

    $md += "### Preview (recomendado para escrever)`n"
    $md += "``````powershell`n"
    $md += "quarto preview                                    # Livro inteiro`n"
    $md += "quarto preview parte-2\cap-04-fatorial.qmd       # Um capitulo`n"
    $md += "``````" + "`n`n"

    $md += "### Abrir HTML pronto`n"
    $md += "``````powershell`n"
    $md += "start _book\index.html`n"
    $md += "``````" + "`n"

    $path = if (Test-Path $Script:ArquivoDoc) {
        (Resolve-Path $Script:ArquivoDoc).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoDoc
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# ETAPA 1 - QUARTO CLI
# ============================================================================
function Verificar-Quarto($progresso) {
    Write-Etapa "1" "Verificar Quarto CLI"

    # Tentar detectar Quarto
    $quartoPath = $null
    foreach ($p in $Script:PathsFerramentas.Quarto) {
        if (Test-Path $p) {
            $quartoPath = $p
            break
        }
    }

    if (-not $quartoPath) {
        Write-Err "Quarto CLI NAO encontrado no disco"
        Write-Item ""
        Write-Item "Instalacao recomendada (winget):"
        Write-Item "  winget install --id Quarto.Quarto --accept-package-agreements --accept-source-agreements"
        Write-Item ""
        Write-Item "Alternativa: baixar em https://quarto.org/docs/get-started/"

        if (Ask-YesNo "Tentar instalar via winget agora?") {
            Write-Info "Executando winget install..."
            winget install --id Quarto.Quarto --accept-package-agreements --accept-source-agreements
            Write-Warn "Apos instalar, feche esta janela do PowerShell e abra uma nova"
            Set-Verificacao $progresso "1" "Quarto CLI" "PENDENTE" "Instalacao via winget executada" "Fechar PowerShell e reabrir" | Out-Null
        } else {
            Set-Verificacao $progresso "1" "Quarto CLI" "ERRO" "Nao instalado" "Instalar via winget ou manual" | Out-Null
        }
        return
    }

    # Quarto encontrado - obter versao
    $quartoDir = Split-Path $quartoPath -Parent
    $env:PATH = "$quartoDir;$env:PATH"

    try {
        $versao = & $quartoPath --version 2>&1 | Select-Object -First 1
        Write-OK "Quarto CLI: $versao"
        Write-Item "Path: $quartoPath"

        Set-Verificacao $progresso "1" "Quarto CLI" "OK" "Versao $versao em $quartoPath" "" | Out-Null

        # Verificar se versao e recente
        if ($versao -match '(\d+)\.(\d+)') {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -eq 1 -and $minor -lt 5) {
                Write-Warn "Versao antiga - considere atualizar para 1.5+"
                Write-Item "Comando: quarto update"
            }
        }
    } catch {
        Write-Err "Erro ao executar Quarto: $_"
        Set-Verificacao $progresso "1" "Quarto CLI" "ERRO" "Executavel encontrado mas nao roda" "Reinstalar" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 2 - TINYTEX / LATEX
# ============================================================================
function Verificar-TinyTeX($progresso) {
    Write-Etapa "2" "Verificar TinyTeX / LaTeX (para renderizar PDF)"

    # Verificar via quarto tools check tinytex
    if (Get-Command quarto -ErrorAction SilentlyContinue) {
        try {
            Write-Info "Verificando TinyTeX via 'quarto check'..."
            $output = quarto check 2>&1 | Out-String

            if ($output -match 'TinyTeX') {
                Write-OK "TinyTeX detectado via quarto check"
                Set-Verificacao $progresso "2" "TinyTeX / LaTeX" "OK" "TinyTeX presente e funcional" "" | Out-Null
                Save-Progresso $progresso
                Update-Documentacao $progresso
                return
            }
        } catch {
            Write-Warn "quarto check falhou - fallback para deteccao manual"
        }
    }

    # Fallback: procurar pdflatex.exe
    $pdflatex = @(
        "$env:APPDATA\TinyTeX\bin\windows\pdflatex.exe",
        "$env:LOCALAPPDATA\Programs\TinyTeX\bin\windows\pdflatex.exe",
        "C:\Program Files\MiKTeX\miktex\bin\x64\pdflatex.exe"
    )

    $encontrado = $null
    foreach ($p in $pdflatex) {
        if (Test-Path $p) {
            $encontrado = $p
            break
        }
    }

    if ($encontrado) {
        Write-OK "LaTeX encontrado: $encontrado"
        Set-Verificacao $progresso "2" "TinyTeX / LaTeX" "OK" "LaTeX em $encontrado" "" | Out-Null
    } else {
        Write-Warn "TinyTeX / LaTeX NAO encontrado"
        Write-Item ""
        Write-Item "TinyTeX e obrigatorio APENAS para renderizar PDF."
        Write-Item "Voce pode adiar isso e renderizar apenas HTML por agora."
        Write-Item ""
        Write-Item "Para instalar TinyTeX (recomendado - 100 MB):"
        Write-Item "  quarto install tinytex"
        Write-Item ""
        Write-Item "Alternativa (MiKTeX, ~2 GB):"
        Write-Item "  https://miktex.org/download"

        if ((Get-Command quarto -ErrorAction SilentlyContinue) -and (Ask-YesNo "Instalar TinyTeX agora?" "N")) {
            Write-Info "Executando 'quarto install tinytex'..."
            Write-Info "Isso vai levar 2-5 minutos e baixar ~100 MB"
            quarto install tinytex
            Set-Verificacao $progresso "2" "TinyTeX / LaTeX" "PENDENTE" "Instalacao iniciada" "Verificar apos conclusao" | Out-Null
        } else {
            Set-Verificacao $progresso "2" "TinyTeX / LaTeX" "AVISO" "Nao instalado - PDF nao disponivel" "quarto install tinytex quando precisar de PDF" | Out-Null
        }
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 3 - DIRETORIO DO PROJETO
# ============================================================================
function Verificar-Projeto($progresso) {
    Write-Etapa "3" "Localizar diretorio do projeto Quarto book"

    # Se path foi passado como parametro, usar
    if ($ProjectPath -and (Test-Path $ProjectPath)) {
        $encontrado = (Resolve-Path $ProjectPath).Path
    } else {
        # Auto-detectar
        $encontrado = $null
        foreach ($p in $Script:PathsCandidatos) {
            if (Test-Path $p) {
                if (Test-Path (Join-Path $p "_quarto.yml")) {
                    $encontrado = (Resolve-Path $p).Path
                    break
                }
            }
        }
    }

    if (-not $encontrado) {
        Write-Err "Diretorio do projeto NAO encontrado"
        Write-Item ""
        Write-Item "Paths pesquisados:"
        foreach ($p in $Script:PathsCandidatos) {
            Write-Item "  - $p"
        }
        Write-Item ""
        Write-Item "Para criar novo projeto:"
        Write-Item "  quarto create-project LIVRO_DOE_USINAGEM --type book"

        Set-Verificacao $progresso "3" "Diretorio do projeto" "ERRO" "_quarto.yml nao encontrado em paths candidatos" "Criar projeto ou informar path correto" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    Write-OK "Projeto encontrado: $encontrado"
    $progresso.project_path = $encontrado

    # Verificar _quarto.yml
    $ymlPath = Join-Path $encontrado "_quarto.yml"
    $ymlSize = (Get-Item $ymlPath).Length
    Write-Item "  _quarto.yml: $ymlSize bytes"

    Set-Verificacao $progresso "3" "Diretorio do projeto" "OK" "Projeto em $encontrado" "" | Out-Null

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 4 - CONFIGURACAO _quarto.yml
# ============================================================================
function Verificar-QuartoYml($progresso) {
    Write-Etapa "4" "Verificar configuracao _quarto.yml (html, pdf, epub)"

    if (-not $progresso.project_path -or -not (Test-Path $progresso.project_path)) {
        Write-Err "Diretorio do projeto nao definido - rode Etapa 3 primeiro"
        Set-Verificacao $progresso "4" "Configuracao _quarto.yml" "ERRO" "Etapa 3 pendente" "Rodar -Etapa 3" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $ymlPath = Join-Path $progresso.project_path "_quarto.yml"
    if (-not (Test-Path $ymlPath)) {
        Write-Err "_quarto.yml nao existe"
        Set-Verificacao $progresso "4" "Configuracao _quarto.yml" "ERRO" "Arquivo ausente" "Criar _quarto.yml" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $conteudo = Get-Content $ymlPath -Raw -Encoding UTF8

    # Verificar formatos configurados
    $formatos = @{
        html = $conteudo -match '^\s*html:'  -or $conteudo -match 'format:\s*\r?\n\s*html:'
        pdf  = $conteudo -match '^\s*pdf:'   -or $conteudo -match 'format:\s*\r?\n[^p]*pdf:'
        epub = $conteudo -match '^\s*epub:'  -or $conteudo -match 'format:\s*\r?\n[^e]*epub:'
    }

    Write-Info "Formatos configurados:"
    $detalhes = @()
    foreach ($f in "html", "pdf", "epub") {
        if ($formatos[$f]) {
            Write-OK "  $f"
            $detalhes += "$f=OK"
        } else {
            Write-Warn "  $f (nao configurado)"
            $detalhes += "$f=AUSENTE"
        }
    }

    # Verificar campos importantes
    Write-Info ""
    Write-Info "Campos essenciais:"
    $campos = @{
        title       = $conteudo -match 'title:\s*"([^"]+)"'
        author      = $conteudo -match 'author:'
        site_url    = $conteudo -match 'site-url:'
        bibliography = $conteudo -match 'bibliography:'
        chapters    = $conteudo -match 'chapters:'
    }

    foreach ($c in $campos.Keys) {
        if ($campos[$c]) {
            Write-OK "  $c"
        } else {
            Write-Warn "  $c (ausente ou incompleto)"
        }
    }

    $statusGeral = if ($formatos.html -and $formatos.pdf -and $formatos.epub) { "OK" }
                   elseif ($formatos.html) { "AVISO" }
                   else { "ERRO" }

    Set-Verificacao $progresso "4" "Configuracao _quarto.yml" $statusGeral ($detalhes -join ", ") "" | Out-Null

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 5 - R + PYTHON (reticulate)
# ============================================================================
function Verificar-Engines($progresso) {
    Write-Etapa "5" "Verificar Engines R + Python (reticulate)"

    # R
    Write-Info "R / Rscript:"
    $rPath = $null
    foreach ($p in $Script:PathsFerramentas.R) {
        if (Test-Path $p) {
            $rPath = $p
            break
        }
    }

    if ($rPath) {
        $rDir = Split-Path $rPath -Parent
        $env:PATH = "$rDir;$env:PATH"

        try {
            $rVersao = & $rPath --version 2>&1 | Select-Object -First 1
            Write-OK "  $rVersao"
            Write-Item "  Path: $rPath"

            # Verificar reticulate
            Write-Info ""
            Write-Info "Testando pacote reticulate no R..."
            $testeReticulate = & $rPath -e "if (requireNamespace('reticulate', quietly=TRUE)) cat('OK') else cat('AUSENTE')" 2>&1

            if ($testeReticulate -match 'OK') {
                Write-OK "  reticulate instalado"
            } else {
                Write-Warn "  reticulate NAO instalado"
                Write-Item "  Instalar: Rscript -e `"install.packages('reticulate')`""
            }
        } catch {
            Write-Warn "  Erro ao executar R: $_"
        }
    } else {
        Write-Warn "R nao encontrado nos paths padrao"
        Write-Item "  Instalar: https://cran.r-project.org/bin/windows/base/"
    }

    # Python
    Write-Host ""
    Write-Info "Python:"
    $pyPath = $null
    foreach ($p in $Script:PathsFerramentas.Python) {
        if (Test-Path $p) {
            $pyPath = $p
            break
        }
    }

    if (-not $pyPath) {
        $pyCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pyCmd) { $pyPath = $pyCmd.Source }
    }

    if ($pyPath) {
        try {
            $pyVersao = & $pyPath --version 2>&1
            Write-OK "  $pyVersao"
            Write-Item "  Path: $pyPath"
        } catch {
            Write-Warn "  Erro ao executar Python: $_"
        }
    } else {
        Write-Warn "Python nao encontrado"
        Write-Item "  Instalar: https://www.python.org/downloads/windows/"
        Write-Item "  Ou: winget install --id Python.Python.3.13"
    }

    # Status geral
    if ($rPath -and $pyPath) {
        Set-Verificacao $progresso "5" "Engines R + Python" "OK" "R: $rPath | Python: $pyPath" "" | Out-Null
    } elseif ($rPath) {
        Set-Verificacao $progresso "5" "Engines R + Python" "AVISO" "R OK, Python ausente" "Instalar Python se for usar codigo Python" | Out-Null
    } else {
        Set-Verificacao $progresso "5" "Engines R + Python" "AVISO" "R e/ou Python ausentes" "Instalar conforme necessidade" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 6 - ESTRUTURA DE PASTAS
# ============================================================================
function Verificar-Estrutura($progresso) {
    Write-Etapa "6" "Verificar estrutura de pastas"

    if (-not $progresso.project_path -or -not (Test-Path $progresso.project_path)) {
        Write-Err "Diretorio do projeto nao definido - rode Etapa 3 primeiro"
        Set-Verificacao $progresso "6" "Estrutura de pastas" "ERRO" "Etapa 3 pendente" "Rodar -Etapa 3" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    Push-Location $progresso.project_path

    try {
        Write-Info "Pastas esperadas:"
        $pastasOk = 0
        $pastasFalta = @()

        foreach ($pasta in $Script:EstruturaEsperada) {
            if (Test-Path $pasta) {
                Write-OK "  $pasta/"
                $pastasOk++
            } else {
                Write-Warn "  $pasta/ (AUSENTE)"
                $pastasFalta += $pasta
            }
        }

        # Verificar capitulos
        Write-Host ""
        Write-Info "Capitulos esperados:"
        $capsOk = 0
        $capsTotal = 0

        foreach ($parte in $Script:CapitulosEsperados.Keys) {
            foreach ($cap in $Script:CapitulosEsperados[$parte]) {
                $capsTotal++
                $capPath = Join-Path $parte $cap
                if (Test-Path $capPath) {
                    $tamanho = (Get-Item $capPath).Length
                    if ($tamanho -gt 3000) {
                        Write-OK "  $capPath ($tamanho bytes - substancial)"
                    } elseif ($tamanho -gt 500) {
                        Write-Item "  [~] $capPath ($tamanho bytes - stub)"
                    } else {
                        Write-Warn "  [!] $capPath ($tamanho bytes - vazio?)"
                    }
                    $capsOk++
                } else {
                    Write-Warn "  [X] $capPath (AUSENTE)"
                }
            }
        }

        Write-Host ""
        Write-Info "Resumo: $pastasOk/$($Script:EstruturaEsperada.Count) pastas | $capsOk/$capsTotal capitulos"

        # Oferecer criar pastas faltantes
        if ($pastasFalta.Count -gt 0) {
            Write-Host ""
            if (Ask-YesNo "Criar $($pastasFalta.Count) pastas faltantes?" "N") {
                foreach ($pasta in $pastasFalta) {
                    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
                    Write-OK "  Criado: $pasta/"
                }
            }
        }

        $status = if ($pastasOk -eq $Script:EstruturaEsperada.Count -and $capsOk -eq $capsTotal) { "OK" }
                  elseif ($pastasOk -ge 5) { "AVISO" }
                  else { "ERRO" }

        Set-Verificacao $progresso "6" "Estrutura de pastas" $status "$pastasOk/$($Script:EstruturaEsperada.Count) pastas, $capsOk/$capsTotal capitulos" "" | Out-Null

    } finally {
        Pop-Location
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# MOSTRAR STATUS
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "STATUS FASE 0.2 - Setup Ambiente de Producao"
    Write-Info "Iniciada em: $($progresso.iniciada_em)"
    Write-Info "Atualizada:  $($progresso.atualizada_em)"

    if ($progresso.project_path) {
        Write-Info "Projeto:     $($progresso.project_path)"
    }
    Write-Host ""

    $nomes = @{
        "1" = "Quarto CLI"
        "2" = "TinyTeX / LaTeX"
        "3" = "Diretorio do projeto"
        "4" = "Configuracao _quarto.yml"
        "5" = "Engines R + Python"
        "6" = "Estrutura de pastas"
    }

    for ($i = 1; $i -le 6; $i++) {
        $v = Get-Verificacao $progresso "$i"
        if ($v) {
            $indicador = switch ($v.status) {
                "OK"       { "[OK]" }
                "AVISO"    { "[!] " }
                "ERRO"     { "[X] " }
                "PENDENTE" { "[..]" }
                default    { "[?]" }
            }
            $cor = switch ($v.status) {
                "OK"       { "Green" }
                "AVISO"    { "Yellow" }
                "ERRO"     { "Red" }
                "PENDENTE" { "Cyan" }
                default    { "Gray" }
            }
            $texto = if ($v.detalhes) { $v.detalhes } else { "OK" }
        } else {
            $indicador = "[  ]"
            $cor = "Gray"
            $texto = "(nao verificado)"
        }

        $linha = "  {0} {1,-30} {2}" -f $indicador, $nomes["$i"], $texto
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Progresso salvo em: $Script:ArquivoProgresso"
    Write-Info "Documentacao em:    $Script:ArquivoDoc"
}

# ============================================================================
# MOSTRAR COMANDOS UTEIS
# ============================================================================
function Mostrar-Comandos($progresso) {
    Write-Titulo "COMANDOS UTEIS - Ambiente de Producao"

    if ($progresso.project_path) {
        Write-Host ""
        Write-Info "Navegar para o projeto:"
        Write-Host "  cd '$($progresso.project_path)'" -ForegroundColor White
    }

    Write-Host ""
    Write-Info "Renderizar:"
    Write-Host "  quarto render --to html          # Apenas HTML (rapido)" -ForegroundColor White
    Write-Host "  quarto render                    # Todos os formatos" -ForegroundColor White
    Write-Host "  quarto render parte-1\cap-01-por-que-doe.qmd  # Um capitulo" -ForegroundColor White

    Write-Host ""
    Write-Info "Preview (recomendado para escrever):"
    Write-Host "  quarto preview                                    # Livro inteiro" -ForegroundColor White
    Write-Host "  quarto preview parte-2\cap-04-fatorial.qmd       # Um capitulo" -ForegroundColor White

    Write-Host ""
    Write-Info "Abrir HTML pronto:"
    Write-Host "  start _book\index.html" -ForegroundColor White

    Write-Host ""
    Write-Info "Diagnostico:"
    Write-Host "  quarto check                     # Diagnostico completo" -ForegroundColor White
    Write-Host "  quarto --version                 # Versao do Quarto" -ForegroundColor White
}

# ============================================================================
# EXECUTAR TODAS AS 6 ETAPAS
# ============================================================================
function Executar-Todas($progresso) {
    Write-Titulo "FASE 0.2 - SETUP AMBIENTE DE PRODUCAO"

    Write-Info "Este orquestrador vai verificar 6 componentes do ambiente:"
    Write-Item "  1. Quarto CLI"
    Write-Item "  2. TinyTeX / LaTeX (para PDF)"
    Write-Item "  3. Diretorio do projeto Quarto"
    Write-Item "  4. Configuracao _quarto.yml"
    Write-Item "  5. Engines R + Python"
    Write-Item "  6. Estrutura de pastas"
    Write-Host ""

    # Corrigir PATH primeiro (esta sessao)
    Write-Info "Corrigindo PATH para esta sessao..."
    $adicionados = Fix-Path
    if ($adicionados.Count -gt 0) {
        foreach ($a in $adicionados) {
            Write-OK "  $a"
        }
    } else {
        Write-Item "  (nada a adicionar - PATH ja tem ferramentas ou nao encontradas)"
    }

    if (-not (Ask-YesNo "Prosseguir com verificacoes?")) { return }

    Verificar-Quarto    $progresso
    Verificar-TinyTeX   $progresso
    Verificar-Projeto   $progresso
    Verificar-QuartoYml $progresso
    Verificar-Engines   $progresso
    Verificar-Estrutura $progresso

    Write-Host ""
    Write-Titulo "FASE 0.2 - VERIFICACAO CONCLUIDA"
    Mostrar-Status $progresso

    # Contar OKs
    $oks = ($progresso.verificacoes | Where-Object { $_.status -eq "OK" }).Count
    $avisos = ($progresso.verificacoes | Where-Object { $_.status -eq "AVISO" }).Count
    $erros = ($progresso.verificacoes | Where-Object { $_.status -eq "ERRO" }).Count

    Write-Host ""
    if ($oks -eq 6) {
        Write-OK "AMBIENTE 100% PRONTO! ($oks/6 OK)"
        Mostrar-Comandos $progresso
    } elseif ($oks -ge 4) {
        Write-Warn "Ambiente parcialmente pronto ($oks OK, $avisos avisos, $erros erros)"
        Write-Item "Consulte $Script:ArquivoDoc para acoes"
    } else {
        Write-Err "Ambiente incompleto ($oks OK, $avisos avisos, $erros erros)"
        Write-Item "Consulte $Script:ArquivoDoc para acoes"
    }
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

# Verificar pasta setup/
if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    Write-OK "Pasta setup/ criada"
}

# Reset se solicitado
if ($Reset) {
    if (Ask-YesNo "ATENCAO: isto vai apagar as verificacoes. Confirmar?" "N") {
        Remove-Item $Script:ArquivoProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArquivoDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

# Carregar progresso
$progresso = Initialize-Progresso

# Status
if ($Status) {
    Mostrar-Status $progresso
    Write-Host ""
    Mostrar-Comandos $progresso
    exit 0
}

# Corrigir PATH sempre (silencioso se nao for verboso)
Fix-Path | Out-Null

# Executar etapa especifica
if ($Etapa -gt 0) {
    switch ($Etapa) {
        1 { Verificar-Quarto    $progresso }
        2 { Verificar-TinyTeX   $progresso }
        3 { Verificar-Projeto   $progresso }
        4 { Verificar-QuartoYml $progresso }
        5 { Verificar-Engines   $progresso }
        6 { Verificar-Estrutura $progresso }
    }
    Write-Host ""
    Mostrar-Status $progresso
    exit 0
}

# Executar tudo
Executar-Todas $progresso

Write-Host ""
Write-OK "Encerrando. Progresso salvo em $Script:ArquivoProgresso"
Write-Info "Retomar com: .\executar-fase-0-2.ps1 -Status"
