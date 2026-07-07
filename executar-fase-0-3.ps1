<#
================================================================================
 SCRIPT MESTRE - FASE 0.3: Setup de Hospedagem Web
================================================================================

 Executa em sequencia todas as etapas automatizadas da Fase 0.3:
   [1] Distribuir arquivos do ZIP FASE_0_3.zip nas pastas corretas
   [2] Aplicar ajustes locais (CNAME, workflow, _quarto.yml)
   [3] Criar repositorio GitHub e fazer deploy inicial
   [4] Validar que tudo esta funcionando

 PRE-REQUISITOS:
   - Windows 10/11 com PowerShell 5.1+
   - Git instalado (git --version deve funcionar)
   - GitHub CLI (gh) instalado (winget install --id GitHub.cli)
   - Arquivo FASE_0_3.zip em Downloads
   - Fase 0.2 ja executada (projeto Quarto book criado)

 COMO EXECUTAR:
   No PowerShell, navegar ate a pasta do projeto e rodar:
     cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     .\executar-fase-0-3.ps1

 O script pergunta antes de cada etapa importante, permitindo pular
 partes ja executadas em uma execucao anterior.

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"
$ZipPath     = "$env:USERPROFILE\Downloads\FASE_0_3.zip"
$TempDir     = "$env:TEMP\fase_0_3"

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

# Pasta do projeto existe?
if (-not (Test-Path $ProjetoRaiz)) {
    Write-Err "Pasta do projeto nao encontrada: $ProjetoRaiz"
    Write-Host "Ajuste a variavel `$ProjetoRaiz no topo deste script."
    exit 1
}
Set-Location $ProjetoRaiz
Write-OK "Pasta do projeto: $ProjetoRaiz"

# _quarto.yml existe? (confirma que Fase 0.2 rodou)
if (-not (Test-Path "_quarto.yml")) {
    Write-Err "_quarto.yml nao encontrado. Execute a Fase 0.2 antes."
    exit 1
}
Write-OK "Projeto Quarto book detectado"

# Git instalado?
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "Git nao instalado. Baixe em: https://git-scm.com/download/win"
    exit 1
}
Write-OK "Git instalado: $((git --version) -join '')"

# gh CLI instalado?
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warn "GitHub CLI (gh) nao encontrado."
    if (Perguntar "Instalar via winget agora?") {
        winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
        Write-Warn "Reinicie o PowerShell e execute este script novamente."
        exit 0
    } else {
        exit 1
    }
}
Write-OK "GitHub CLI instalado: $((gh --version) -split "`n" | Select-Object -First 1)"

# ============================================================================
# ETAPA 1 - Distribuir arquivos do ZIP
# ============================================================================
Write-Etapa "1" "Distribuir arquivos do FASE_0_3.zip"

if (Test-Path ".\setup\aplicar-ajustes-fase-0-3.ps1") {
    Write-OK "Arquivos ja distribuidos anteriormente"
    if (-not (Perguntar "Refazer distribuicao (sobrescreve)?")) {
        Write-Host "Pulando etapa 1..."
    } else {
        $refazer = $true
    }
} else {
    $refazer = $true
}

if ($refazer) {
    if (-not (Test-Path $ZipPath)) {
        Write-Err "ZIP nao encontrado em: $ZipPath"
        Write-Host "Baixe FASE_0_3.zip para essa pasta ou ajuste `$ZipPath no script."
        exit 1
    }
    Write-Host "Descompactando ZIP em $TempDir..."
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

    Write-Host "Copiando arquivos para .\setup\..."
    $arquivos = @(
        "aplicar-ajustes-fase-0-3.ps1",
        "setup-github-pages.ps1",
        "validar-deploy.ps1",
        "HOSPEDAGEM_PASSO_A_PASSO.md",
        "publish.yml",
        "CNAME"
    )
    foreach ($arq in $arquivos) {
        $src = Join-Path $TempDir $arq
        if (Test-Path $src) {
            Copy-Item $src ".\setup\" -Force
            Write-OK "  Copiado: $arq"
        } else {
            Write-Warn "  Nao encontrado no ZIP: $arq"
        }
    }
}

# ============================================================================
# ETAPA 2 - Aplicar ajustes locais no projeto
# ============================================================================
Write-Etapa "2" "Aplicar ajustes locais (CNAME, workflow, _quarto.yml)"

Write-Host "Este script:"
Write-Host "  - Cria arquivo CNAME na raiz (doeusinagem.com.br)"
Write-Host "  - Atualiza .github/workflows/publish.yml"
Write-Host "  - Ajusta _quarto.yml para incluir CNAME como resource"
Write-Host "  - Renderiza HTML localmente para validar"
Write-Host ""

if (Perguntar "Executar ajustes locais?") {
    .\setup\aplicar-ajustes-fase-0-3.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha nos ajustes locais"
        exit 1
    }
} else {
    Write-Host "Pulando etapa 2..."
}

# ============================================================================
# ETAPA 3 - Setup GitHub Pages
# ============================================================================
Write-Etapa "3" "Setup GitHub (repo, push, Pages)"

Write-Host "Este script:"
Write-Host "  - Faz login no GitHub (se necessario)"
Write-Host "  - Inicializa repositorio Git local"
Write-Host "  - Cria repositorio remoto mariocezar1971/livro-doe-usinagem"
Write-Host "  - Faz primeiro commit e push"
Write-Host "  - Habilita GitHub Pages"
Write-Host ""

if (Perguntar "Executar setup GitHub?") {
    .\setup\setup-github-pages.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha no setup GitHub"
        exit 1
    }
} else {
    Write-Host "Pulando etapa 3..."
}

# ============================================================================
# ETAPA 4 - CHECKPOINT MANUAL: habilitar Pages via web
# ============================================================================
Write-Etapa "4" "CHECKPOINT MANUAL - Habilitar Pages"

Write-Host "IMPORTANTE: se este e o primeiro deploy, GitHub Pages precisa ser"
Write-Host "habilitado manualmente na pagina de settings."
Write-Host ""
Write-Host "  1. Acesse: https://github.com/mariocezar1971/livro-doe-usinagem/settings/pages"
Write-Host "  2. Se aparecer 'Upgrade or make repository public':"
Write-Host "     - Torne o repo publico: Settings -> Change visibility -> Public"
Write-Host "     - OU faca upgrade para GitHub Pro"
Write-Host "  3. Em 'Source', selecione 'GitHub Actions'"
Write-Host ""

if (Perguntar "Abrir pagina de configuracao no navegador?") {
    Start-Process "https://github.com/mariocezar1971/livro-doe-usinagem/settings/pages"
}

Write-Host ""
Read-Host "Pressione ENTER quando Pages estiver habilitado (Source = GitHub Actions)"

# ============================================================================
# ETAPA 5 - Disparar deploy inicial
# ============================================================================
Write-Etapa "5" "Disparar deploy inicial"

if (Perguntar "Fazer commit vazio para disparar workflow completo?") {
    git commit --allow-empty -m "Trigger deploy apos habilitar Pages"
    git push
    Write-OK "Push realizado. Workflow iniciado."
    Write-Host ""
    Write-Host "Aguardando 15 segundos antes de acompanhar o workflow..."
    Start-Sleep -Seconds 15

    $novoRunId = gh run list --repo mariocezar1971/livro-doe-usinagem --limit 1 --json databaseId --jq '.[0].databaseId'
    Write-Host "Acompanhando run $novoRunId..."
    gh run watch $novoRunId --repo mariocezar1971/livro-doe-usinagem
}

# ============================================================================
# ETAPA 6 - Validar deploy
# ============================================================================
Write-Etapa "6" "Validar deploy"

if (Perguntar "Rodar validacao completa?") {
    .\setup\validar-deploy.ps1
}

# ============================================================================
# ETAPA 7 - Abrir o livro no navegador
# ============================================================================
Write-Etapa "7" "Ver o livro no navegador"

if (Perguntar "Abrir o livro?") {
    Start-Process "https://mariocezar1971.github.io/livro-doe-usinagem/"
}

# ============================================================================
# CONCLUSAO
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 0.3"

Write-Host ""
Write-Host "$BOLD Status:$RESET"
Write-Host "  $GREEN [OK] Repositorio GitHub criado $RESET"
Write-Host "  $GREEN [OK] GitHub Action configurado (build + deploy) $RESET"
Write-Host "  $GREEN [OK] Deploy no GitHub Pages ativo $RESET"
Write-Host "  $GREEN [OK] URL publica: https://mariocezar1971.github.io/livro-doe-usinagem/ $RESET"
Write-Host ""
Write-Host "$BOLD Pendencias (manuais no Registro.br):$RESET"
Write-Host "  $YELLOW [ ] Registrar dominio doeusinagem.com.br (~R$40/ano) $RESET"
Write-Host "  $YELLOW [ ] Configurar 4 registros A no DNS $RESET"
Write-Host "  $YELLOW [ ] Adicionar custom domain no GitHub Pages $RESET"
Write-Host "  $YELLOW [ ] Aguardar propagacao DNS (1-24h) + emissao SSL $RESET"
Write-Host ""
Write-Host "Consulte o guia detalhado: .\setup\HOSPEDAGEM_PASSO_A_PASSO.md"
Write-Host ""
