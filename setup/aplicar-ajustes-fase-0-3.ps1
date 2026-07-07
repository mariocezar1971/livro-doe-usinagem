<#
.SYNOPSIS
    Aplica os ajustes da Fase 0.3 nos arquivos do projeto.

.DESCRIPTION
    Este script:
    1. Copia o arquivo CNAME para a raiz do projeto
    2. Atualiza .github/workflows/publish.yml com a versao correta do Quarto
    3. Adiciona CNAME como resource no _quarto.yml (para ser copiado para _book)

.NOTES
    Executar na pasta raiz do projeto LIVRO_DOE_USINAGEM/
    Os arquivos auxiliares (CNAME, publish.yml) devem estar na mesma pasta deste script.
#>

$ESC = [char]27
$GREEN = "$ESC[32m"; $YELLOW = "$ESC[33m"; $RED = "$ESC[31m"; $RESET = "$ESC[0m"

function Write-Success($Text) { Write-Host "$GREEN[OK]$RESET $Text" }
function Write-Warn($Text)    { Write-Host "$YELLOW[!]$RESET $Text" }
function Write-Err($Text)     { Write-Host "$RED[X]$RESET $Text" }

# ==============================================================================
# 1. Verificar que estamos no diretorio correto
# ==============================================================================
if (-not (Test-Path "_quarto.yml")) {
    Write-Err "Este script deve ser executado na raiz do projeto LIVRO_DOE_USINAGEM"
    Write-Host "Arquivo _quarto.yml nao encontrado no diretorio atual."
    exit 1
}

# ==============================================================================
# 2. Copiar CNAME para a raiz do projeto
# ==============================================================================
Write-Host "`n--- Atualizando arquivo CNAME ---"

$cnameContent = "doeusinagem.com.br"
$cnameContent | Out-File -FilePath "CNAME" -Encoding ascii -NoNewline
Write-Success "Arquivo CNAME criado (dominio: doeusinagem.com.br)"

# ==============================================================================
# 3. Atualizar GitHub Action workflow
# ==============================================================================
Write-Host "`n--- Atualizando GitHub Action workflow ---"

$workflowPath = ".github\workflows\publish.yml"
$workflowSource = Join-Path $PSScriptRoot "publish.yml"

if (Test-Path $workflowSource) {
    if (-not (Test-Path ".github\workflows")) {
        New-Item -ItemType Directory -Path ".github\workflows" -Force | Out-Null
    }
    Copy-Item -Path $workflowSource -Destination $workflowPath -Force
    Write-Success "Workflow atualizado: $workflowPath"
} else {
    Write-Warn "Arquivo publish.yml nao encontrado em $workflowSource"
    Write-Warn "Voce precisa colocar publish.yml manualmente em .github\workflows\"
}

# ==============================================================================
# 4. Ajustar _quarto.yml para incluir CNAME como resource
# ==============================================================================
Write-Host "`n--- Ajustando _quarto.yml ---"

$quartoYml = Get-Content "_quarto.yml" -Raw

if ($quartoYml -match "- CNAME") {
    Write-Success "_quarto.yml ja inclui CNAME como resource"
} else {
    # Adiciona CNAME a lista de resources do project
    $newYml = $quartoYml -replace '(\s+resources:\s*\n(?:\s+- .+\n)+)', "`$1    - CNAME`n"

    if ($newYml -ne $quartoYml) {
        Set-Content -Path "_quarto.yml" -Value $newYml -NoNewline
        Write-Success "_quarto.yml ajustado para copiar CNAME para _book/"
    } else {
        Write-Warn "Nao foi possivel ajustar _quarto.yml automaticamente."
        Write-Host "Edite manualmente, na secao project.resources, adicione:"
        Write-Host "    - CNAME"
    }
}

# ==============================================================================
# 5. Validar resultado
# ==============================================================================
Write-Host "`n--- Validando ---"

if (Test-Path "CNAME") { Write-Success "CNAME presente" } else { Write-Err "CNAME faltando" }
if (Test-Path ".github\workflows\publish.yml") { Write-Success "Workflow presente" } else { Write-Err "Workflow faltando" }

$quartoFinal = Get-Content "_quarto.yml" -Raw
if ($quartoFinal -match "- CNAME") { Write-Success "_quarto.yml referencia CNAME" } else { Write-Warn "_quarto.yml NAO referencia CNAME" }

# ==============================================================================
# 6. Renderizar de teste para confirmar
# ==============================================================================
Write-Host "`n--- Testando render local ---"
$resposta = Read-Host "Renderizar HTML agora para testar? (S/N)"
if ($resposta -eq "S" -or $resposta -eq "s") {
    quarto render --to html
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Render OK"
        if (Test-Path "_book\CNAME") {
            Write-Success "Arquivo CNAME foi copiado para _book/CNAME (correto)"
        } else {
            Write-Warn "Arquivo CNAME nao foi copiado para _book/. Adicione manualmente no _quarto.yml em resources."
        }
    } else {
        Write-Err "Render falhou"
    }
}

Write-Host ""
Write-Host "Proximo passo: rodar .\setup\setup-github-pages.ps1 para criar o repositorio remoto"
