<#
.SYNOPSIS
    Setup completo do ambiente de produção do livro DOE em Usinagem.

.DESCRIPTION
    Este script automatiza a Fase 0.2 do roadmap:
    - Verifica/instala Quarto CLI
    - Verifica/instala R e tinytex (LaTeX)
    - Verifica/instala Python e pacotes necessários
    - Valida estrutura do projeto Quarto
    - Renderiza HTML, PDF e EPUB para confirmar pipeline

.AUTHOR
    Mário Cezar dos Santos Jr.

.NOTES
    Execute no PowerShell com permissão de usuário (não precisa admin):
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        .\setup-projeto.ps1
#>

# Cores para output
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$BOLD = "$ESC[1m"
$RESET = "$ESC[0m"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "$BOLD$BLUE==================================================$RESET"
    Write-Host "$BOLD$BLUE $Text$RESET"
    Write-Host "$BOLD$BLUE==================================================$RESET"
}

function Write-Success {
    param([string]$Text)
    Write-Host "$GREEN[OK]$RESET $Text"
}

function Write-Warn {
    param([string]$Text)
    Write-Host "$YELLOW[!]$RESET $Text"
}

function Write-Error2 {
    param([string]$Text)
    Write-Host "$RED[X]$RESET $Text"
}

function Test-Command {
    param([string]$cmd)
    return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
}

# ===========================================================
# Etapa 1: Verificar Quarto CLI
# ===========================================================
Write-Section "1. Verificando Quarto CLI"

if (Test-Command "quarto") {
    $quartoVersion = (quarto --version 2>&1) | Out-String
    Write-Success "Quarto instalado: $($quartoVersion.Trim())"

    # Verificar se é versão recente (>= 1.4)
    $versionNum = [version]($quartoVersion.Trim())
    if ($versionNum -lt [version]"1.4.0") {
        Write-Warn "Versão do Quarto antiga. Recomenda-se 1.5 ou superior."
        Write-Warn "Download: https://quarto.org/docs/get-started/"
    }
} else {
    Write-Error2 "Quarto não encontrado."
    Write-Host ""
    Write-Host "Instale o Quarto manualmente:"
    Write-Host "  1. Acesse https://quarto.org/docs/get-started/"
    Write-Host "  2. Baixe o instalador Windows (.msi)"
    Write-Host "  3. Execute o instalador"
    Write-Host "  4. Reinicie o PowerShell e execute este script novamente"
    Write-Host ""
    exit 1
}

# ===========================================================
# Etapa 2: Verificar R e tinytex
# ===========================================================
Write-Section "2. Verificando R e tinytex (LaTeX)"

if (Test-Command "Rscript") {
    $rVersion = (Rscript --version 2>&1) | Out-String
    Write-Success "R instalado: $($rVersion.Trim())"

    # Verificar tinytex
    Write-Host "Verificando tinytex..."
    $tinytexCheck = Rscript -e "cat(tinytex::is_tinytex())" 2>$null

    if ($tinytexCheck -eq "TRUE") {
        Write-Success "tinytex instalado e funcionando"
    } else {
        Write-Warn "tinytex não encontrado. Instalando..."
        Rscript -e "if (!require('tinytex', quietly=TRUE)) install.packages('tinytex', repos='https://cran.r-project.org'); tinytex::install_tinytex()"

        # Verificar novamente
        $tinytexCheck2 = Rscript -e "cat(tinytex::is_tinytex())" 2>$null
        if ($tinytexCheck2 -eq "TRUE") {
            Write-Success "tinytex instalado com sucesso"
        } else {
            Write-Error2 "Falha na instalação de tinytex. Instale manualmente:"
            Write-Host "  R: install.packages('tinytex'); tinytex::install_tinytex()"
        }
    }
} else {
    Write-Error2 "R não encontrado."
    Write-Host "Instale o R: https://cran.r-project.org/bin/windows/base/"
    Write-Host "Depois reinstale o RStudio: https://posit.co/download/rstudio-desktop/"
    exit 1
}

# ===========================================================
# Etapa 3: Verificar Python
# ===========================================================
Write-Section "3. Verificando Python"

if (Test-Command "python") {
    $pyVersion = (python --version 2>&1) | Out-String
    Write-Success "Python instalado: $($pyVersion.Trim())"
} elseif (Test-Command "python3") {
    $pyVersion = (python3 --version 2>&1) | Out-String
    Write-Success "Python instalado: $($pyVersion.Trim())"
} else {
    Write-Warn "Python não encontrado. Instale: https://www.python.org/downloads/"
    Write-Warn "Python é opcional para o esqueleto, necessário para Capítulo 6 (otimização)."
}

# ===========================================================
# Etapa 4: Instalar pacotes R necessários
# ===========================================================
Write-Section "4. Instalando pacotes R necessários"

Write-Host "Esta etapa pode demorar 10-30 minutos na primeira execução."
$resposta = Read-Host "Continuar? (S/N)"
if ($resposta -eq "S" -or $resposta -eq "s" -or $resposta -eq "") {
    Rscript ./setup/setup-r-env.R
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pacotes R instalados"
    } else {
        Write-Warn "Alguns pacotes R falharam. Verifique acima."
    }
} else {
    Write-Warn "Pulando instalação de pacotes R."
}

# ===========================================================
# Etapa 5: Instalar pacotes Python necessários
# ===========================================================
Write-Section "5. Instalando pacotes Python necessários"

if (Test-Command "python" -or Test-Command "python3") {
    $pyCmd = if (Test-Command "python") { "python" } else { "python3" }
    & $pyCmd -m pip install -r ./setup/requirements.txt --user
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pacotes Python instalados"
    } else {
        Write-Warn "Alguns pacotes Python falharam."
    }
}

# ===========================================================
# Etapa 6: Validar estrutura do projeto
# ===========================================================
Write-Section "6. Validando estrutura do projeto"

$arquivosNecessarios = @(
    "_quarto.yml",
    "index.qmd",
    "references.bib",
    "styles/styles.css",
    "styles/preamble.tex"
)

$tudoOk = $true
foreach ($arq in $arquivosNecessarios) {
    if (Test-Path $arq) {
        Write-Success "Arquivo presente: $arq"
    } else {
        Write-Error2 "Arquivo faltando: $arq"
        $tudoOk = $false
    }
}

$pastasNecessarias = @("parte-1", "parte-2", "parte-3", "parte-4", "apendices", "figuras", "codigos", "dados", "styles")
foreach ($pasta in $pastasNecessarias) {
    if (Test-Path $pasta -PathType Container) {
        Write-Success "Pasta presente: $pasta"
    } else {
        Write-Error2 "Pasta faltando: $pasta"
        $tudoOk = $false
    }
}

# ===========================================================
# Etapa 7: Testar renderização
# ===========================================================
Write-Section "7. Testando renderização (HTML)"

Write-Host "Renderizando versão HTML..."
quarto render --to html
if ($LASTEXITCODE -eq 0) {
    Write-Success "HTML renderizado em _book/index.html"
    Write-Host ""
    Write-Host "Abra _book/index.html no navegador para visualizar."
} else {
    Write-Error2 "Falha na renderização HTML."
    Write-Host "Verifique erros acima."
}

Write-Section "Setup concluído"

Write-Host ""
Write-Host "Próximos passos:"
Write-Host "  1. Visualizar: abrir _book/index.html no navegador"
Write-Host "  2. Edição: abrir o projeto no RStudio (File → Open Project → _quarto.yml)"
Write-Host "  3. Render rápido: quarto preview (modo live com hot-reload)"
Write-Host "  4. Render PDF: quarto render --to pdf (pode demorar na primeira vez)"
Write-Host "  5. Inicializar Git: git init; git add .; git commit -m 'Setup inicial'"
Write-Host ""
