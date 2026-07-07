<#
.SYNOPSIS
    Valida o deploy do livro no GitHub Pages.

.DESCRIPTION
    Verifica em sequencia:
    1. Repositorio GitHub existe e e acessivel
    2. Ultimo workflow do GitHub Actions executou com sucesso
    3. GitHub Pages esta habilitado e configurado
    4. URL https://mariocezar1971.github.io/livro-doe-usinagem/ responde 200
    5. (Se DNS configurado) doeusinagem.com.br resolve para IPs do GitHub
    6. (Se DNS configurado) HTTPS funciona em doeusinagem.com.br
    7. Certificado SSL valido

.NOTES
    Execute apos rodar setup-github-pages.ps1
#>

$REPO_OWNER = "mariocezar1971"
$REPO_NAME  = "livro-doe-usinagem"
$DOMAIN     = "doeusinagem.com.br"   # Ajuste se outro dominio
$GITHUB_URL = "https://$REPO_OWNER.github.io/$REPO_NAME/"
$CUSTOM_URL = "https://$DOMAIN/"

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

# ==============================================================================
# 1. Verificar repositorio
# ==============================================================================
Write-Section "1. Verificando repositorio GitHub"

$repoInfo = gh repo view "$REPO_OWNER/$REPO_NAME" --json url,visibility,defaultBranchRef 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -eq 0) {
    Write-Success "Repositorio existe: $($repoInfo.url)"
    Write-Host "  Visibilidade: $($repoInfo.visibility)"
    Write-Host "  Branch principal: $($repoInfo.defaultBranchRef.name)"
} else {
    Write-Err "Repositorio nao encontrado ou sem acesso."
    exit 1
}

# ==============================================================================
# 2. Status do ultimo workflow
# ==============================================================================
Write-Section "2. Verificando ultimo workflow (GitHub Actions)"

$runs = gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit 1 --json status,conclusion,name,createdAt,databaseId,url | ConvertFrom-Json
if ($runs.Count -gt 0) {
    $lastRun = $runs[0]
    Write-Host "  Workflow: $($lastRun.name)"
    Write-Host "  Criado: $($lastRun.createdAt)"
    Write-Host "  Status: $($lastRun.status)"
    Write-Host "  Conclusao: $($lastRun.conclusion)"
    Write-Host "  URL: $($lastRun.url)"

    if ($lastRun.status -eq "completed") {
        if ($lastRun.conclusion -eq "success") {
            Write-Success "Ultimo workflow executou com sucesso"
        } else {
            Write-Err "Ultimo workflow falhou: $($lastRun.conclusion)"
            Write-Host "Verifique logs em: $($lastRun.url)"
        }
    } elseif ($lastRun.status -eq "in_progress" -or $lastRun.status -eq "queued") {
        Write-Warn "Workflow ainda esta executando. Aguarde e tente novamente em alguns minutos."
        Write-Host "Acompanhe em: $($lastRun.url)"
    }
} else {
    Write-Warn "Nenhum workflow encontrado. Verifique se ja houve push."
}

# ==============================================================================
# 3. Status do GitHub Pages
# ==============================================================================
Write-Section "3. Verificando configuracao do GitHub Pages"

$pagesInfo = gh api "repos/$REPO_OWNER/$REPO_NAME/pages" 2>&1 | ConvertFrom-Json
if ($pagesInfo.url) {
    Write-Success "Pages habilitado"
    Write-Host "  Source build: $($pagesInfo.build_type)"
    Write-Host "  Status: $($pagesInfo.status)"
    Write-Host "  URL Pages: $($pagesInfo.html_url)"
    if ($pagesInfo.cname) {
        Write-Host "  Dominio custom: $($pagesInfo.cname)"
    } else {
        Write-Warn "Sem dominio customizado configurado"
    }
    if ($pagesInfo.https_enforced) {
        Write-Success "HTTPS forcado"
    } else {
        Write-Warn "HTTPS nao forcado (configurar em Settings -> Pages)"
    }
} else {
    Write-Err "GitHub Pages nao habilitado ou erro ao consultar."
}

# ==============================================================================
# 4. Testar acesso a URL do GitHub Pages
# ==============================================================================
Write-Section "4. Testando URL GitHub Pages"

Write-Host "Tentando: $GITHUB_URL"
try {
    $response = Invoke-WebRequest -Uri $GITHUB_URL -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Success "URL responde HTTP 200"
        $title = if ($response.Content -match '<title>(.*?)</title>') { $Matches[1] } else { "N/A" }
        Write-Host "  Titulo da pagina: $title"
        Write-Host "  Tamanho: $($response.Content.Length) bytes"
    } else {
        Write-Warn "HTTP $($response.StatusCode)"
    }
} catch {
    Write-Err "Erro ao acessar URL: $($_.Exception.Message)"
    Write-Host "  Pode ser que o deploy ainda nao finalizou."
    Write-Host "  Aguarde 3-5 minutos e tente novamente."
}

# ==============================================================================
# 5. Testar DNS do dominio customizado (se configurado)
# ==============================================================================
Write-Section "5. Verificando DNS do dominio customizado"

Write-Host "Resolvendo: $DOMAIN"
try {
    $dnsResult = Resolve-DnsName -Name $DOMAIN -Type A -ErrorAction Stop

    $ipsGitHub = @("185.199.108.153", "185.199.109.153", "185.199.110.153", "185.199.111.153")
    $resolved = $dnsResult | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress

    Write-Host "  IPs resolvidos:"
    foreach ($ip in $resolved) {
        if ($ip -in $ipsGitHub) {
            Write-Host "    $GREEN  $ip  (GitHub Pages OK) $RESET"
        } else {
            Write-Host "    $YELLOW  $ip  (nao e do GitHub) $RESET"
        }
    }

    $hasGitHubIp = ($resolved | Where-Object { $_ -in $ipsGitHub }).Count -gt 0
    if ($hasGitHubIp) {
        Write-Success "DNS configurado corretamente para GitHub Pages"
    } else {
        Write-Warn "DNS NAO aponta para GitHub Pages. Configure no Registro.br."
        Write-Host "  Os 4 A records corretos sao:"
        $ipsGitHub | ForEach-Object { Write-Host "    $_" }
    }
} catch {
    Write-Warn "Dominio $DOMAIN nao resolve. Pode estar:"
    Write-Host "    - Ainda nao registrado no Registro.br"
    Write-Host "    - DNS ainda propagando (pode levar ate 48h)"
    Write-Host "    - Configurado errado"
    Write-Host "  Veja HOSPEDAGEM_PASSO_A_PASSO.md para detalhes"
}

# ==============================================================================
# 6. Testar HTTPS no dominio customizado
# ==============================================================================
Write-Section "6. Testando HTTPS no dominio customizado"

Write-Host "Tentando: $CUSTOM_URL"
try {
    $response = Invoke-WebRequest -Uri $CUSTOM_URL -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Success "Dominio customizado responde HTTP 200 via HTTPS"
        Write-Success "Certificado SSL valido (Lets Encrypt via GitHub)"
    } else {
        Write-Warn "HTTP $($response.StatusCode)"
    }
} catch {
    Write-Warn "Dominio customizado ainda nao acessivel."
    Write-Host "  Apos configurar DNS, aguarde:"
    Write-Host "    - 1-24h para propagacao DNS"
    Write-Host "    - 5-15 min para emissao do certificado SSL pelo GitHub"
}

# ==============================================================================
# Sumario final
# ==============================================================================
Write-Section "Sumario da validacao"

Write-Host ""
Write-Host "URLs do livro:"
Write-Host "  GitHub Pages: $GREEN $GITHUB_URL $RESET"
Write-Host "  Dominio custom: $GREEN $CUSTOM_URL $RESET (apos configurar DNS)"
Write-Host ""
Write-Host "Para diagnosticar problemas:"
Write-Host "  - Logs de build: gh run list --repo $REPO_OWNER/$REPO_NAME"
Write-Host "  - Logs detalhados: gh run view --repo $REPO_OWNER/$REPO_NAME"
Write-Host "  - Pages config: gh api repos/$REPO_OWNER/$REPO_NAME/pages"
Write-Host ""
