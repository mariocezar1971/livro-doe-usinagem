# SCRIPT SIMPLIFICADO - FASE 1.3
# Landing Page de Captura de Emails
# Versao ASCII pura, sem regex complexos

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"
$ZipPath = "$env:USERPROFILE\Downloads\FASE_1_3.zip"
$TempDir = "$env:TEMP\fase_1_3"
$BrevoDashboard = "https://app.brevo.com/"

function Perguntar($p) {
    $r = Read-Host "$p (S/N)"
    return ($r -eq "S" -or $r -eq "s" -or $r -eq "")
}

Write-Host ""
Write-Host "================================================================================"
Write-Host " FASE 1.3 - Landing Page de Captura"
Write-Host "================================================================================"
Write-Host ""

# ETAPA 0 - Ambiente
Write-Host "[0] Validar ambiente" -ForegroundColor Cyan

if (-not (Test-Path $ProjetoRaiz)) {
    Write-Host "ERRO: Pasta do projeto nao existe: $ProjetoRaiz" -ForegroundColor Red
    exit 1
}
Set-Location $ProjetoRaiz
Write-Host "[OK] Pasta: $ProjetoRaiz" -ForegroundColor Green

if (-not (Test-Path "_quarto.yml")) {
    Write-Host "ERRO: _quarto.yml nao encontrado" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Projeto Quarto detectado" -ForegroundColor Green

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

# ETAPA 1 - Distribuir arquivos
Write-Host ""
Write-Host "[1] Distribuir arquivos do FASE_1_3.zip" -ForegroundColor Cyan

$destinos = @{
    "em-breve.qmd"        = ".\em-breve.qmd"
    "em-breve.css"        = ".\styles\em-breve.css"
    "BREVO_SETUP_GUIA.md" = ".\setup\BREVO_SETUP_GUIA.md"
}

$temTudo = $true
foreach ($dest in $destinos.Values) {
    if (-not (Test-Path $dest)) { $temTudo = $false; break }
}

$distribuir = $false
if ($temTudo) {
    Write-Host "[OK] Arquivos ja distribuidos" -ForegroundColor Green
    if (Perguntar "Redistribuir?") { $distribuir = $true }
} else {
    $distribuir = $true
}

if ($distribuir) {
    if (-not (Test-Path $ZipPath)) {
        Write-Host "ERRO: ZIP nao encontrado: $ZipPath" -ForegroundColor Red
        exit 1
    }
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    New-Item -ItemType Directory -Path ".\styles" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path ".\setup"  -Force -ErrorAction SilentlyContinue | Out-Null
    foreach ($item in $destinos.GetEnumerator()) {
        $src = Join-Path $TempDir $item.Key
        if (Test-Path $src) {
            Copy-Item $src $item.Value -Force
            Write-Host "[OK] $($item.Key) -> $($item.Value)" -ForegroundColor Green
        }
    }
}

# ETAPA 2 - Ajustar _quarto.yml
Write-Host ""
Write-Host "[2] Ajustar _quarto.yml" -ForegroundColor Cyan
$yml = Get-Content _quarto.yml -Raw
if ($yml -match "em-breve") {
    Write-Host "[OK] _quarto.yml ja referencia em-breve" -ForegroundColor Green
} else {
    if (Perguntar "Adicionar em-breve.qmd como resource?") {
        Copy-Item _quarto.yml "_quarto.yml.bak_pre_fase-1-3" -Force
        Add-Content _quarto.yml "`nresources:`n  - em-breve.qmd`n  - styles/em-breve.css`n"
        Write-Host "[OK] _quarto.yml atualizado" -ForegroundColor Green
    }
}

# ETAPA 3 - Brevo
Write-Host ""
Write-Host "[3] Setup Brevo (manual)" -ForegroundColor Cyan

$emBreve = Get-Content .\em-breve.qmd -Raw -ErrorAction SilentlyContinue
$temForm = $false
if ($emBreve) {
    if ($emBreve -match "sib-form|sibforms") {
        Write-Host "[OK] Formulario Brevo ja inserido" -ForegroundColor Green
        $temForm = $true
    }
}

if (-not $temForm) {
    Write-Host "Formulario Brevo NAO configurado ainda" -ForegroundColor Yellow
    Write-Host "Guia: setup\BREVO_SETUP_GUIA.md"
    Write-Host ""
    if (Perguntar "Abrir guia Brevo?") { Start-Process ".\setup\BREVO_SETUP_GUIA.md" }
    if (Perguntar "Abrir Brevo no navegador?") { Start-Process $BrevoDashboard }
    Write-Host ""
    Write-Host "Quando tiver o codigo do formulario:"
    Write-Host "  1. Salve em .\brevo-embed.html"
    Write-Host "  2. Rode este script novamente"
    Write-Host ""

    # Opcao: inserir agora se tem o arquivo
    if (Test-Path .\brevo-embed.html) {
        if (Perguntar "brevo-embed.html detectado. Inserir agora?") {
            $codigo = Get-Content .\brevo-embed.html -Raw
            # Marcador simples que existe no template
            $marcador = "COLE AQUI O CODIGO DO FORMULARIO BREVO"
            if ($emBreve -match $marcador) {
                # Substituir a linha do marcador ate o proximo :::
                $novoEmBreve = $emBreve -replace "(?s)<!--[^>]*$marcador[^>]*-->.*?(?=:::)", "$codigo`n"
                Set-Content .\em-breve.qmd -Value $novoEmBreve -Encoding UTF8
                Write-Host "[OK] Codigo inserido em em-breve.qmd" -ForegroundColor Green
                $temForm = $true
            }
        }
    }
}

# ETAPA 4 - Render
Write-Host ""
Write-Host "[4] Renderizar em-breve.qmd" -ForegroundColor Cyan
if (Perguntar "Renderizar agora?") {
    quarto render em-breve.qmd
    if ($LASTEXITCODE -eq 0) {
        $outputs = @(".\em-breve.html", ".\_book\em-breve.html")
        foreach ($o in $outputs) {
            if (Test-Path $o) {
                Write-Host "[OK] Gerado: $o" -ForegroundColor Green
                if (Perguntar "Abrir no navegador?") { Start-Process $o }
                break
            }
        }
    }
}

# ETAPA 5 - Git
Write-Host ""
Write-Host "[5] Versionar no Git" -ForegroundColor Cyan
$status = git status --porcelain 2>$null
if (-not [string]::IsNullOrWhiteSpace($status)) {
    git status --short
    if (Perguntar "Commitar mudancas?") {
        if (Test-Path em-breve.qmd) { git add em-breve.qmd }
        if (Test-Path styles\em-breve.css) { git add styles/em-breve.css }
        if (Test-Path setup\BREVO_SETUP_GUIA.md) { git add setup/BREVO_SETUP_GUIA.md }
        git add _quarto.yml
        if (Test-Path executar-fase-1-3.ps1) { git add executar-fase-1-3.ps1 }

        $statusFm = if ($temForm) { "OK" } else { "pendente" }
        git commit -m "Fase 1.3: landing page em-breve.qmd + brevo $statusFm"
        if ($LASTEXITCODE -eq 0) {
            if (Perguntar "Push para GitHub?") {
                git push
                Write-Host ""
                Write-Host "Landing estara em ~3 min em:"
                Write-Host "  https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html"
            }
        }
    }
}

Write-Host ""
Write-Host "================================================================================"
Write-Host " FIM - Resumo da Fase 1.3"
Write-Host "================================================================================"
Write-Host ""
if ($temForm) {
    Write-Host "[OK] Formulario Brevo integrado" -ForegroundColor Green
} else {
    Write-Host "[ ] Formulario Brevo pendente - ver setup\BREVO_SETUP_GUIA.md" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "URL publica: https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html"
Write-Host ""
