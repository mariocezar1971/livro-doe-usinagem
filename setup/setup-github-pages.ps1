<#
.SYNOPSIS
    Setup completo de hospedagem web no GitHub Pages.

.DESCRIPTION
    Automatiza a Fase 0.3 do roadmap:
    - Verifica/instala GitHub CLI (gh)
    - Faz login no GitHub
    - Inicializa Git local
    - Cria repositorio github.com/mariocezar1971/livro-doe-usinagem
    - Faz primeiro commit + push
    - Habilita GitHub Pages via GitHub Actions
    - Configura branch gh-pages

    Apos a execucao, o livro estara disponivel em:
    https://mariocezar1971.github.io/livro-doe-usinagem/

    O dominio doeusinagem.com.br sera configurado manualmente
    (Registro.br) - consulte HOSPEDAGEM_PASSO_A_PASSO.md.

.NOTES
    Executar no PowerShell (nao requer admin):
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        .\setup\setup-github-pages.ps1
#>

# ==============================================================================
# Configuracao do script
# ==============================================================================
$REPO_OWNER = "mariocezar1971"
$REPO_NAME  = "livro-doe-usinagem"
$REPO_DESC  = "Livro tecnico: Planejamento de Experimentos em Usinagem aplicado as ligas de aluminio"
$VISIBILITY = "private"   # Mude para "public" quando quiser tornar publico

# Cores ANSI
$ESC = [char]27
$RED = "$ESC[31m"; $GREEN = "$ESC[32m"; $YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"; $BOLD = "$ESC[1m"; $RESET = "$ESC[0m"

function Write-Section($Text) {
    Write-Host ""
    Write-Host "$BOLD$BLUE==================================================$RESET"
    Write-Host "$BOLD$BLUE $Text$RESET"
    Write-Host "$BOLD$BLUE==================================================$RESET"
}
function Write-Success($Text) { Write-Host "$GREEN[OK]$RESET $Text" }
function Write-Warn($Text)    { Write-Host "$YELLOW[!]$RESET $Text" }
function Write-Err($Text)     { Write-Host "$RED[X]$RESET $Text" }
function Test-Command($cmd)   { return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

# ==============================================================================
# Etapa 1 - Verificar Git
# ==============================================================================
Write-Section "1. Verificando Git"

if (Test-Command "git") {
    $gitVersion = (git --version) | Out-String
    Write-Success "Git instalado: $($gitVersion.Trim())"
} else {
    Write-Err "Git nao encontrado."
    Write-Host "Instale Git para Windows: https://git-scm.com/download/win"
    Write-Host "Depois reinicie o PowerShell e execute este script novamente."
    exit 1
}

# Configurar identidade Git se ainda nao estiver
$gitUserName = git config --global user.name 2>$null
$gitUserEmail = git config --global user.email 2>$null

if ([string]::IsNullOrWhiteSpace($gitUserName)) {
    $nome = Read-Host "Digite seu nome completo para o Git (ex: Mario Cezar)"
    git config --global user.name "$nome"
    Write-Success "Git user.name configurado"
}
if ([string]::IsNullOrWhiteSpace($gitUserEmail)) {
    $email = Read-Host "Digite seu email do GitHub"
    git config --global user.email "$email"
    Write-Success "Git user.email configurado"
}

# ==============================================================================
# Etapa 2 - Verificar GitHub CLI
# ==============================================================================
Write-Section "2. Verificando GitHub CLI (gh)"

if (Test-Command "gh") {
    $ghVersion = (gh --version | Select-Object -First 1)
    Write-Success "GitHub CLI instalado: $ghVersion"
} else {
    Write-Warn "GitHub CLI nao encontrado."
    Write-Host ""
    Write-Host "Instale via uma das opcoes:"
    Write-Host "  A) Winget (recomendado):"
    Write-Host "       winget install --id GitHub.cli"
    Write-Host "  B) Chocolatey:"
    Write-Host "       choco install gh"
    Write-Host "  C) Manual:"
    Write-Host "       https://cli.github.com/"
    Write-Host ""
    $resposta = Read-Host "Instalar via winget agora? (S/N)"
    if ($resposta -eq "S" -or $resposta -eq "s") {
        winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
        Write-Warn "Reinicie o PowerShell apos a instalacao e execute este script novamente."
        exit 0
    } else {
        exit 1
    }
}

# ==============================================================================
# Etapa 3 - Login no GitHub
# ==============================================================================
Write-Section "3. Autenticando no GitHub"

$ghAuth = gh auth status 2>&1 | Out-String
if ($ghAuth -match "Logged in to github.com") {
    Write-Success "Ja autenticado no GitHub"
    $ghUser = (gh api user --jq .login 2>$null)
    Write-Host "Usuario: $ghUser"
} else {
    Write-Warn "Nao autenticado. Iniciando login..."
    Write-Host "Sera aberta uma janela do navegador para autenticar."
    gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha no login. Tente novamente."
        exit 1
    }
    Write-Success "Login realizado"
}

# ==============================================================================
# Etapa 4 - Inicializar repositorio Git local
# ==============================================================================
Write-Section "4. Inicializando repositorio Git local"

if (Test-Path ".git") {
    Write-Success "Repositorio Git ja inicializado"
} else {
    git init
    git branch -M main
    Write-Success "Repositorio Git inicializado (branch main)"
}

# ==============================================================================
# Etapa 5 - Criar repositorio remoto no GitHub
# ==============================================================================
Write-Section "5. Criando repositorio remoto no GitHub"

$repoExists = gh repo view "$REPO_OWNER/$REPO_NAME" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Repositorio $REPO_OWNER/$REPO_NAME ja existe"
} else {
    Write-Host "Criando repositorio $REPO_OWNER/$REPO_NAME ($VISIBILITY)..."
    gh repo create "$REPO_OWNER/$REPO_NAME" `
        --$VISIBILITY `
        --description "$REPO_DESC" `
        --disable-wiki

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha ao criar repositorio."
        exit 1
    }
    Write-Success "Repositorio criado"
}

# Adicionar remote se nao existir
$remoteUrl = git remote get-url origin 2>$null
if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
    git remote add origin "https://github.com/$REPO_OWNER/$REPO_NAME.git"
    Write-Success "Remote 'origin' adicionado"
} else {
    Write-Success "Remote 'origin' ja configurado: $remoteUrl"
}

# ==============================================================================
# Etapa 6 - Primeiro commit
# ==============================================================================
Write-Section "6. Preparando primeiro commit"

# Verificar se ha algo para commitar
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    $hasCommits = git log --oneline 2>$null
    if ([string]::IsNullOrWhiteSpace($hasCommits)) {
        Write-Warn "Nenhum arquivo para commitar. Verifique se esta na pasta correta."
        exit 1
    } else {
        Write-Success "Repositorio ja possui commits"
    }
} else {
    Write-Host "Arquivos pendentes encontrados. Adicionando ao Git..."
    git add .

    # Mostra resumo
    $staged = (git diff --cached --name-only | Measure-Object -Line).Lines
    Write-Host "  -> $staged arquivos adicionados"

    git commit -m "Setup inicial - Fase 0.2 e 0.3 do roadmap

- Esqueleto Quarto book com 12 capitulos + 4 apendices
- Configuracao multi-formato (HTML, PDF, EPUB)
- Engine R + Python via reticulate
- Estilos CSS, SCSS e LaTeX preamble customizados
- GitHub Action para deploy automatico
- Scripts de setup PowerShell"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Primeiro commit realizado"
    } else {
        Write-Err "Falha no commit"
        exit 1
    }
}

# ==============================================================================
# Etapa 7 - Push para GitHub
# ==============================================================================
Write-Section "7. Enviando para o GitHub"

git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Success "Push realizado com sucesso"
} else {
    Write-Err "Falha no push. Verifique credenciais Git."
    exit 1
}

# ==============================================================================
# Etapa 8 - Habilitar GitHub Pages
# ==============================================================================
Write-Section "8. Habilitando GitHub Pages"

# A partir de 2024, o metodo recomendado e usar GitHub Actions como fonte
# (nao mais branch gh-pages). Nossa workflow ja faz isso.

Write-Host "Configurando Pages para source = GitHub Actions..."

# Habilita Pages com fonte = workflow (Actions)
gh api `
    --method POST `
    -H "Accept: application/vnd.github+json" `
    "repos/$REPO_OWNER/$REPO_NAME/pages" `
    -f "build_type=workflow" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "GitHub Pages habilitado (source = GitHub Actions)"
} else {
    # Pode ja estar habilitado - testa
    $pagesInfo = gh api "repos/$REPO_OWNER/$REPO_NAME/pages" 2>&1
    if ($pagesInfo -match "build_type") {
        Write-Success "GitHub Pages ja estava habilitado"
    } else {
        Write-Warn "Pages pode precisar ser habilitado manualmente:"
        Write-Host "  https://github.com/$REPO_OWNER/$REPO_NAME/settings/pages"
        Write-Host "  Source: GitHub Actions"
    }
}

# ==============================================================================
# Etapa 9 - Disparar primeiro deploy
# ==============================================================================
Write-Section "9. Disparando primeiro deploy"

Write-Host "O push acima ja deve ter disparado o workflow automaticamente."
Write-Host "Acompanhe em:"
Write-Host "  https://github.com/$REPO_OWNER/$REPO_NAME/actions"
Write-Host ""
Write-Host "Apos o build terminar (~3-5 minutos na primeira vez), o livro estara em:"
Write-Host ""
Write-Host "$BOLD$GREEN  https://$REPO_OWNER.github.io/$REPO_NAME/$RESET"
Write-Host ""

# Tentar abrir a pagina de Actions no navegador
$resposta = Read-Host "Abrir a pagina de Actions no navegador? (S/N)"
if ($resposta -eq "S" -or $resposta -eq "s") {
    Start-Process "https://github.com/$REPO_OWNER/$REPO_NAME/actions"
}

# ==============================================================================
# Conclusao
# ==============================================================================
Write-Section "Setup GitHub Pages concluido"

Write-Host ""
Write-Host "$BOLD Resumo:$RESET"
Write-Host "  - Repositorio: $GREEN https://github.com/$REPO_OWNER/$REPO_NAME $RESET"
Write-Host "  - Visibilidade: $VISIBILITY"
Write-Host "  - URL GitHub Pages: $GREEN https://$REPO_OWNER.github.io/$REPO_NAME/ $RESET"
Write-Host ""
Write-Host "$BOLD Proximos passos:$RESET"
Write-Host "  1. Aguardar o primeiro deploy terminar (3-5 minutos)"
Write-Host "  2. Validar acesso: $BOLD .\setup\validar-deploy.ps1 $RESET"
Write-Host "  3. Registrar dominio: $BOLD HOSPEDAGEM_PASSO_A_PASSO.md $RESET"
Write-Host "  4. Configurar DNS no Registro.br (apos compra do dominio)"
Write-Host ""
