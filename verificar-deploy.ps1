# SCRIPT UTILITARIO - Verificar Deploy pos-push
#
# Verifica se o ultimo push para GitHub Pages foi bem-sucedido:
#   [0] Validar ambiente (git, gh)
#   [1] Ver ultimos commits (local + remoto)
#   [2] Comparar local vs remoto
#   [3] Ver status do ultimo workflow do GitHub Actions
#   [4] Polling inteligente do deploy (max 5 min, checa cada 20s)
#   [5] Testar URLs criticas (homepage, sitemap, em-breve, robots.txt)
#   [6] Diagnostico de falhas + sugestao de acao
#
# USO:
#   .\verificar-deploy.ps1                    # com padroes
#   .\verificar-deploy.ps1 -TimeoutMinutos 10 # aguardar mais tempo
#   .\verificar-deploy.ps1 -SkipPolling       # nao aguardar, so verificar
#
# 100% ASCII puro, robusto contra bugs de encoding

param(
    [int]$TimeoutMinutos = 5,
    [switch]$SkipPolling,
    [string]$Repo = "mariocezar1971/livro-doe-usinagem",
    [string]$UrlBase = "https://mariocezar1971.github.io/livro-doe-usinagem"
)

$ErrorActionPreference = "Continue"

# ============================================================================
# HELPERS
# ============================================================================
function Write-Etapa($n, $titulo) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Blue
    Write-Host "[$n] $titulo" -ForegroundColor Blue
    Write-Host ("=" * 78) -ForegroundColor Blue
}
function Write-OK($msg)   { Write-Host "[OK]  $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "[i]   $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[!]   $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[X]   $msg" -ForegroundColor Red }

# ============================================================================
# ETAPA 0 - Validar ambiente
# ============================================================================
Write-Etapa "0" "Validar ambiente"

# Fixar UTF-8
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

# Verificar git
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) { Write-Err "git nao encontrado"; exit 1 }
Write-OK "git disponivel: $($git.Source)"

# Verificar gh
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Warn "GitHub CLI (gh) nao encontrado - verificacao de workflow sera pulada"
    Write-Info "Instalar: winget install --id GitHub.cli"
    $temGh = $false
} else {
    Write-OK "gh disponivel"
    # Verificar login
    $ghStatus = gh auth status 2>&1 | Out-String
    if ($ghStatus -match "Logged in") {
        Write-OK "gh autenticado"
        $temGh = $true
    } else {
        Write-Warn "gh nao autenticado. Rode: gh auth login"
        $temGh = $false
    }
}

# Verificar se estamos em um repo git
$isRepo = git rev-parse --is-inside-work-tree 2>&1
if ($isRepo -ne "true") {
    Write-Err "Nao estamos em um repositorio git"
    exit 1
}
Write-OK "Repositorio Git detectado"

# ============================================================================
# ETAPA 1 - Ver ultimos commits (local + remoto)
# ============================================================================
Write-Etapa "1" "Historico de commits"

Write-Info "Ultimos 3 commits locais:"
$commitsLocais = git log --oneline -3 2>&1
$commitsLocais | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Info "Buscando estado do remoto..."
git fetch origin --quiet 2>&1 | Out-Null

Write-Info "Ultimos 3 commits do remoto (origin/main):"
$commitsRemotos = git log origin/main --oneline -3 2>&1
$commitsRemotos | ForEach-Object { Write-Host "  $_" }

# ============================================================================
# ETAPA 2 - Comparar local vs remoto
# ============================================================================
Write-Etapa "2" "Sincronizacao local vs remoto"

$headLocal = (git rev-parse HEAD 2>&1).Trim()
$headRemoto = (git rev-parse origin/main 2>&1).Trim()

Write-Info "HEAD local:  $($headLocal.Substring(0,7))"
Write-Info "HEAD remoto: $($headRemoto.Substring(0,7))"

if ($headLocal -eq $headRemoto) {
    Write-OK "Local e remoto SINCRONIZADOS"
} else {
    # Verificar direcao (ahead/behind)
    $status = git status -sb 2>&1 | Select-Object -First 1
    if ($status -match "ahead") {
        Write-Warn "Voce esta AHEAD do remoto (commits nao pushados)"
        Write-Info "Rode: git push"
    } elseif ($status -match "behind") {
        Write-Warn "Voce esta BEHIND do remoto (falta pull)"
        Write-Info "Rode: git pull"
    } else {
        Write-Warn "Divergencia detectada - conferir com git status"
    }
}

# Ver arquivos nao commitados
$dirty = git status --porcelain 2>&1
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    Write-Warn "Ha mudancas locais nao commitadas:"
    $dirty | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
} else {
    Write-OK "Workdir limpo (nenhuma mudanca pendente)"
}

# ============================================================================
# ETAPA 3 - Status do ultimo workflow
# ============================================================================
Write-Etapa "3" "Ultimo workflow do GitHub Actions"

if (-not $temGh) {
    Write-Warn "gh nao disponivel - pulando"
    Write-Info "Voce pode ver manualmente em:"
    Write-Info "  https://github.com/$Repo/actions"
} else {
    $runsJson = gh run list --repo $Repo --limit 3 --json databaseId,status,conclusion,workflowName,headBranch,event,createdAt,updatedAt,url 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Falha ao consultar workflow"
        Write-Info $runsJson
    } else {
        try {
            $runs = $runsJson | ConvertFrom-Json
            if ($runs.Count -eq 0) {
                Write-Warn "Nenhum workflow encontrado"
            } else {
                foreach ($run in $runs) {
                    $status = $run.status       # queued, in_progress, completed
                    $conclusion = $run.conclusion # success, failure, cancelled, null
                    $tempo = ""
                    if ($run.createdAt) {
                        $created = [DateTime]::Parse($run.createdAt)
                        $diff = (Get-Date).ToUniversalTime() - $created
                        if ($diff.TotalMinutes -lt 60) {
                            $tempo = "$([math]::Round($diff.TotalMinutes,0)) min atras"
                        } else {
                            $tempo = "$([math]::Round($diff.TotalHours,1)) h atras"
                        }
                    }
                    
                    $indicador = switch ($conclusion) {
                        "success"   { "[OK]" }
                        "failure"   { "[X] " }
                        "cancelled" { "[!] " }
                        default     { if ($status -eq "in_progress") { "[..] " } else { "[?] " } }
                    }
                    
                    Write-Host "  $indicador $($run.workflowName) - $tempo" -ForegroundColor $(
                        switch ($conclusion) {
                            "success"   { "Green" }
                            "failure"   { "Red" }
                            "cancelled" { "Yellow" }
                            default     { "Cyan" }
                        }
                    )
                }
                
                # Guardar ultimo run para etapa 4
                $ultimoRun = $runs[0]
            }
        } catch {
            Write-Err "Erro ao parsear resposta do gh"
            Write-Info $_.Exception.Message
        }
    }
}

# ============================================================================
# ETAPA 4 - Polling do deploy
# ============================================================================
Write-Etapa "4" "Polling do deploy"

if ($SkipPolling) {
    Write-Info "Polling desabilitado (-SkipPolling)"
} elseif (-not $temGh) {
    Write-Info "Sem gh, aguardando $TimeoutMinutos min cegamente..."
    Start-Sleep -Seconds ($TimeoutMinutos * 60)
} elseif ($ultimoRun -and $ultimoRun.conclusion -eq "success") {
    Write-OK "Ultimo workflow ja completou com sucesso - sem necessidade de aguardar"
} else {
    Write-Info "Aguardando conclusao do workflow (max $TimeoutMinutos min, checa cada 20s)..."
    Write-Info "Ctrl+C para cancelar polling"
    Write-Host ""
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $timeoutSec = $TimeoutMinutos * 60
    $intervalo = 20
    $ultimoStatus = ""
    
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        $runJson = gh run list --repo $Repo --limit 1 --json status,conclusion,url,databaseId 2>&1 | Out-String
        try {
            $run = ($runJson | ConvertFrom-Json)[0]
            $s = "$($run.status)/$($run.conclusion)"
            
            if ($s -ne $ultimoStatus) {
                $elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 0)
                Write-Host "  [$($elapsed)s] Status: $s"
                $ultimoStatus = $s
            }
            
            if ($run.status -eq "completed") {
                if ($run.conclusion -eq "success") {
                    Write-OK "Workflow completou em $([math]::Round($sw.Elapsed.TotalSeconds,0))s"
                } else {
                    Write-Err "Workflow falhou: $($run.conclusion)"
                    Write-Info "Detalhes: $($run.url)"
                }
                break
            }
        } catch {
            # Tentativa falhou, continua tentando
        }
        Start-Sleep -Seconds $intervalo
    }
    
    if ($sw.Elapsed.TotalSeconds -ge $timeoutSec) {
        Write-Warn "Timeout de $TimeoutMinutos min atingido - workflow ainda em execucao"
    }
}

# ============================================================================
# ETAPA 5 - Testar URLs criticas
# ============================================================================
Write-Etapa "5" "Testar URLs criticas (HTTP HEAD)"

Write-Info "Aguardando 15s adicionais para CDN propagar..."
Start-Sleep -Seconds 15

$urlsTestar = @(
    @{ Nome = "Homepage"          ; Url = "$UrlBase/" },
    @{ Nome = "Landing em-breve"  ; Url = "$UrlBase/em-breve.html" },
    @{ Nome = "Sitemap XML"       ; Url = "$UrlBase/sitemap.xml" },
    @{ Nome = "Robots.txt"        ; Url = "$UrlBase/robots.txt" },
    @{ Nome = "Google verification"; Url = "$UrlBase/googleec59d4807eff3619.html" },
    @{ Nome = "Referencias"       ; Url = "$UrlBase/references.html" }
)

$falhas = @()
$sucessos = 0
foreach ($item in $urlsTestar) {
    try {
        $resp = Invoke-WebRequest -Uri $item.Url -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $tamanho = if ($resp.Headers.'Content-Length') { 
            [int]$resp.Headers.'Content-Length'[0] 
        } else { "?" }
        Write-Host ("  [OK]  {0,-22} {1,6} B  HTTP {2}" -f $item.Nome, $tamanho, $resp.StatusCode) -ForegroundColor Green
        $sucessos++
    } catch {
        $statusCode = "?"
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        Write-Host ("  [X]   {0,-22} HTTP {1}" -f $item.Nome, $statusCode) -ForegroundColor Red
        $falhas += @{ Nome = $item.Nome; Url = $item.Url; Status = $statusCode }
    }
}

# ============================================================================
# ETAPA 6 - Testar conteudo do sitemap
# ============================================================================
Write-Etapa "6" "Validar conteudo do sitemap"

try {
    $sitemapContent = (Invoke-WebRequest -Uri "$UrlBase/sitemap.xml" -UseBasicParsing -TimeoutSec 10).Content
    $urls = ([regex]::Matches($sitemapContent, "<loc>")).Count
    Write-OK "Sitemap contem $urls URLs"
    
    if ($sitemapContent -match "mariocezar1971\.github\.io") {
        Write-OK "URLs apontam para github.io (correto)"
    } elseif ($sitemapContent -match "doeusinagem\.com\.br") {
        Write-Warn "URLs apontam para doeusinagem.com.br (dominio nao ativo)"
    }
    
    if ($urls -lt 15) {
        Write-Warn "Numero de URLs baixo - esperado ~19"
    }
} catch {
    Write-Err "Nao foi possivel baixar sitemap: $($_.Exception.Message)"
}

# ============================================================================
# ETAPA 7 - Diagnostico + Recomendacoes
# ============================================================================
Write-Etapa "7" "Diagnostico"

$totalUrls = $urlsTestar.Count
Write-Info "URLs testadas: $sucessos / $totalUrls sucesso"

if ($falhas.Count -eq 0) {
    Write-OK "DEPLOY VALIDADO - todas as URLs respondem"
    Write-Host ""
    Write-Info "Deploy da Fase 1.4 esta funcionando corretamente."
    Write-Info "Voce pode encerrar."
} else {
    Write-Warn "Algumas URLs falharam:"
    foreach ($f in $falhas) {
        Write-Host "  - $($f.Nome): HTTP $($f.Status) em $($f.Url)"
    }
    Write-Host ""
    Write-Info "Diagnostico por tipo de erro:"
    
    if ($falhas | Where-Object { $_.Status -eq 404 }) {
        Write-Host "  404 (Nao encontrado):" -ForegroundColor Yellow
        Write-Host "    - Arquivo pode nao estar em resources: no _quarto.yml"
        Write-Host "    - Render local ok mas nao subiu no deploy"
        Write-Host "    - Aguarde mais 5 min (CDN GitHub Pages)"
    }
    if ($falhas | Where-Object { $_.Status -eq 0 -or $_.Status -eq "?" }) {
        Write-Host "  Timeout/DNS:" -ForegroundColor Yellow
        Write-Host "    - GitHub Pages pode estar em manutencao"
        Write-Host "    - Verificar status: https://www.githubstatus.com"
    }
    if ($falhas | Where-Object { $_.Status -ge 500 }) {
        Write-Host "  Erro do servidor (5xx):" -ForegroundColor Yellow
        Write-Host "    - GitHub Pages com problema temporario"
        Write-Host "    - Aguarde 10-15 min e teste de novo"
    }
}

# ============================================================================
# ACOES OPCIONAIS
# ============================================================================
Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Blue
Write-Host "ACOES OPCIONAIS" -ForegroundColor Blue
Write-Host ("=" * 78) -ForegroundColor Blue
Write-Host ""
Write-Host "Abrir homepage:"
Write-Host "  Start-Process '$UrlBase/'"
Write-Host ""
Write-Host "Abrir sitemap:"
Write-Host "  Start-Process '$UrlBase/sitemap.xml'"
Write-Host ""
Write-Host "Abrir Search Console:"
Write-Host "  Start-Process 'https://search.google.com/search-console'"
Write-Host ""
Write-Host "Ver workflow no navegador:"
if ($temGh -and $ultimoRun) {
    Write-Host "  Start-Process '$($ultimoRun.url)'"
} else {
    Write-Host "  Start-Process 'https://github.com/$Repo/actions'"
}
Write-Host ""

# Log de auditoria
$logPath = "$env:USERPROFILE\.livro-doe-deploys.log"
$logLine = "{0} | pushed={1} | workflow={2} | urls_ok={3}/{4}" -f `
    (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
    $headLocal.Substring(0,7),
    $(if ($ultimoRun) { $ultimoRun.conclusion } else { "n/a" }),
    $sucessos,
    $totalUrls
Add-Content -Path $logPath -Value $logLine
Write-Info "Log de auditoria: $logPath"
