# ============================================================================
# verificar-manual.ps1
#
# Verificacao manual avulsa (fallback de diagnostico)
#
# Agrupa checagens pontuais uteis quando algo parece errado e voce
# quer diagnosticar rapido sem rodar um orquestrador de fase inteiro.
#
# 6 blocos de verificacao:
#   1. Estado do _quarto.yml (site-url + sitemap)
#   2. Arquivos gerados em _book (contagem por tipo)
#   3. Validacao do sitemap (URLs + dominio)
#   4. Estado do deploy (git log + gh run list)
#   5. Teste de URL publica
#   6. Log de auditoria de deploys
#
# USO:
#   .\verificar-manual.ps1              # Roda todos os 6 blocos
#   .\verificar-manual.ps1 -Bloco 3     # So valida sitemap
#   .\verificar-manual.ps1 -Abrir       # Abre index/sitemap no navegador
#   .\verificar-manual.ps1 -Quiet       # Sem abrir nada, so relatorio
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateRange(1, 6)]
    [int]$Bloco = 0,
    [switch]$Abrir,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:Repo      = "mariocezar1971/livro-doe-usinagem"
$Script:UrlBase   = "https://mariocezar1971.github.io/livro-doe-usinagem"
$Script:UrlSitemap = "$($Script:UrlBase)/sitemap.xml"
$Script:LogDeploy = "$env:USERPROFILE\.livro-doe-deploys.log"
$Script:SitemapEsperado = 19

# ============================================================================
# CORRIGIR PATH (Git, gh, Quarto) para esta sessao
# ============================================================================
$pathsFerramentas = @(
    "C:\Program Files\Git\cmd",
    "C:\Program Files\GitHub CLI",
    "C:\Program Files\Quarto\bin",
    "$env:LOCALAPPDATA\Programs\Quarto\bin"
)
foreach ($p in $pathsFerramentas) {
    if ((Test-Path $p) -and ($env:PATH -notmatch [regex]::Escape($p))) {
        $env:PATH = "$p;$env:PATH"
    }
}

# ============================================================================
# HELPERS DE OUTPUT
# ============================================================================
function Write-Bloco($n, $titulo) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Blue
    Write-Host "[$n] $titulo" -ForegroundColor Blue
    Write-Host ("=" * 78) -ForegroundColor Blue
}
function Write-OK($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Host "[i]    $msg" -ForegroundColor Cyan }
function Write-Warn($msg)  { Write-Host "[!]    $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[X]    $msg" -ForegroundColor Red }
function Write-Item($msg)  { Write-Host "       $msg" }

# ============================================================================
# BLOCO 1 - ESTADO DO _quarto.yml
# ============================================================================
function Verificar-QuartoYml {
    Write-Bloco "1" "Estado do _quarto.yml (site-url + sitemap)"

    if (-not (Test-Path ".\_quarto.yml")) {
        Write-Err "_quarto.yml nao encontrado na pasta atual"
        Write-Item "Voce esta no diretorio do projeto?"
        Write-Item "Local atual: $(Get-Location)"
        return
    }

    $yml = Get-Content ".\_quarto.yml" -Raw -Encoding UTF8

    # site-url
    if ($yml -match 'site-url:\s*["'']?([^"''\r\n]+)') {
        Write-OK "site-url: $($Matches[1].Trim())"
    } else {
        Write-Warn "site-url NAO encontrado"
        Write-Item "Necessario para sitemap e SEO"
    }

    # sitemap: true
    if ($yml -match 'sitemap:\s*true') {
        Write-OK "sitemap: true (geracao de sitemap ativa)"
    } elseif ($yml -match 'sitemap:') {
        Write-Warn "sitemap: presente mas nao 'true'"
        if ($yml -match 'sitemap:\s*(\S+)') {
            Write-Item "Valor atual: $($Matches[1])"
        }
    } else {
        Write-Warn "sitemap: NAO configurado"
        Write-Item "Adicionar 'sitemap: true' no bloco format: html:"
    }

    # Mostrar as linhas relevantes (equivalente ao Select-String do usuario)
    Write-Host ""
    Write-Info "Linhas com site-url|sitemap:"
    $linhas = Select-String -Path ".\_quarto.yml" -Pattern 'site-url|sitemap'
    foreach ($l in $linhas) {
        Write-Item "L$($l.LineNumber): $($l.Line.Trim())"
    }
}

# ============================================================================
# BLOCO 2 - ARQUIVOS GERADOS EM _book
# ============================================================================
function Verificar-Book {
    Write-Bloco "2" "Arquivos gerados em _book (contagem por tipo)"

    if (-not (Test-Path ".\_book")) {
        Write-Warn "_book/ nao existe (nenhum render local feito)"
        Write-Item "Rodar: quarto render --to html"
        Write-Item "Ou o deploy do GitHub Actions gera no servidor"
        return
    }

    $html = (Get-ChildItem "_book" -Recurse -Filter *.html -ErrorAction SilentlyContinue).Count
    $css  = (Get-ChildItem "_book" -Recurse -Filter *.css -ErrorAction SilentlyContinue).Count
    $js   = (Get-ChildItem "_book" -Recurse -Filter *.js -ErrorAction SilentlyContinue).Count
    $xml  = (Get-ChildItem "_book" -Recurse -Filter *.xml -ErrorAction SilentlyContinue).Count

    Write-Host ""
    Write-Host "       HTML=$html CSS=$css JS=$js XML=$xml" -ForegroundColor White
    Write-Host ""

    if ($html -ge 15) {
        Write-OK "HTML: $html arquivos (livro completo esperado ~20)"
    } elseif ($html -gt 0) {
        Write-Warn "HTML: $html arquivos (parcial - esperado ~20 com todos capitulos)"
    } else {
        Write-Err "Nenhum HTML gerado"
    }

    if ($xml -ge 1) {
        Write-OK "XML: $xml (sitemap.xml presente)"
    } else {
        Write-Warn "XML: 0 (sitemap nao gerado - verificar Bloco 1)"
    }

    # Listar os HTMLs (para conferencia)
    if ($html -gt 0 -and $html -le 25) {
        Write-Host ""
        Write-Info "HTMLs gerados:"
        Get-ChildItem "_book" -Recurse -Filter *.html | ForEach-Object {
            $rel = $_.FullName.Replace((Resolve-Path "_book").Path, "").TrimStart('\')
            Write-Item "$rel ($($_.Length) bytes)"
        }
    }
}

# ============================================================================
# BLOCO 3 - VALIDAR SITEMAP
# ============================================================================
function Verificar-Sitemap {
    Write-Bloco "3" "Validar sitemap"

    # Tentar local primeiro, depois publico
    $sitemapLocal = ".\_book\sitemap.xml"

    if (Test-Path $sitemapLocal) {
        Write-Info "Sitemap LOCAL encontrado: $sitemapLocal"
        $s = Get-Content $sitemapLocal -Raw
        $urls = ([regex]::Matches($s, '<loc>')).Count
        Write-Host ""
        Write-Host "       Sitemap com $urls URLs" -ForegroundColor White

        if ($s -match 'mariocezar1971\.github\.io') {
            Write-OK "URLs apontam para github.io"
        } else {
            Write-Warn "URLs NAO apontam para github.io - verificar site-url"
        }

        if ($urls -eq $Script:SitemapEsperado) {
            Write-OK "Contagem esperada: $urls URLs"
        } elseif ($urls -gt $Script:SitemapEsperado) {
            Write-OK "Mais URLs que o esperado: $urls (>$($Script:SitemapEsperado)) - novos capitulos?"
        } else {
            Write-Warn "Menos URLs que o esperado: $urls (<$($Script:SitemapEsperado))"
        }
    } else {
        Write-Warn "Sitemap local ausente - testando publico"
    }

    # Testar sitemap publico
    Write-Host ""
    Write-Info "Testando sitemap PUBLICO: $($Script:UrlSitemap)"
    try {
        $resp = Invoke-WebRequest -Uri $Script:UrlSitemap -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $urlsPub = ([regex]::Matches($resp.Content, '<loc>')).Count
        Write-OK "Sitemap publico acessivel: $urlsPub URLs (HTTP $($resp.StatusCode))"

        # Listar as URLs publicas
        Write-Host ""
        Write-Info "URLs no sitemap publico:"
        [regex]::Matches($resp.Content, '<loc>([^<]+)</loc>') | ForEach-Object {
            Write-Item $_.Groups[1].Value
        }
    } catch {
        Write-Err "Sitemap publico inacessivel: $($_.Exception.Message)"
    }
}

# ============================================================================
# BLOCO 4 - VERIFICAR DEPLOY
# ============================================================================
function Verificar-Deploy {
    Write-Bloco "4" "Verificar deploy (git log + gh run list)"

    # Git log
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Info "Ultimos 3 commits:"
        $log = git log --oneline -3 2>&1
        foreach ($l in $log) {
            Write-Item $l
        }
    } else {
        Write-Err "git nao disponivel no PATH"
    }

    Write-Host ""

    # gh run list
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Info "Ultimos 2 workflows (GitHub Actions):"
        try {
            $runs = gh run list --repo $Script:Repo --limit 2 2>&1
            foreach ($r in $runs) {
                Write-Item $r
            }
        } catch {
            Write-Warn "Erro ao listar workflows: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "gh CLI nao disponivel"
        Write-Item "Ver deploy manualmente: https://github.com/$($Script:Repo)/actions"
    }

    # Sincronizacao local vs remoto
    Write-Host ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $local  = git rev-parse HEAD 2>$null
        $remoto = git rev-parse origin/main 2>$null
        if ($local -and $remoto) {
            if ($local -eq $remoto) {
                Write-OK "Local = Remoto (sincronizado): $($local.Substring(0,7))"
            } else {
                Write-Warn "Local != Remoto (divergencia)"
                Write-Item "Local:  $($local.Substring(0,7))"
                Write-Item "Remoto: $($remoto.Substring(0,7))"
                Write-Item "Rodar: git push (ou git pull)"
            }
        }
    }
}

# ============================================================================
# BLOCO 5 - TESTAR URL PUBLICA
# ============================================================================
function Verificar-UrlPublica {
    Write-Bloco "5" "Testar URL publica"

    $urls = @(
        @{ nome="Index (livro)"; url="$($Script:UrlBase)/" },
        @{ nome="Landing (em-breve)"; url="$($Script:UrlBase)/em-breve.html" },
        @{ nome="Sitemap"; url=$Script:UrlSitemap },
        @{ nome="Cap 1"; url="$($Script:UrlBase)/parte-1/cap-01-por-que-doe.html" }
    )

    foreach ($item in $urls) {
        try {
            $resp = Invoke-WebRequest -Uri $item.url -UseBasicParsing -TimeoutSec 10 -Method Head -ErrorAction Stop
            Write-OK "$($item.nome): HTTP $($resp.StatusCode)"
        } catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "erro" }
            Write-Err "$($item.nome): HTTP $status"
        }
    }

    # Abrir no navegador se solicitado
    if ($Abrir -and -not $Quiet) {
        Write-Host ""
        Write-Info "Abrindo sitemap no navegador..."
        Start-Process $Script:UrlSitemap
    }
}

# ============================================================================
# BLOCO 6 - LOG DE AUDITORIA
# ============================================================================
function Verificar-LogAuditoria {
    Write-Bloco "6" "Log de auditoria de deploys"

    if (Test-Path $Script:LogDeploy) {
        Write-Info "Log encontrado: $($Script:LogDeploy)"
        Write-Host ""
        Write-Info "Ultimas 5 entradas:"
        $tail = Get-Content $Script:LogDeploy -Tail 5 -ErrorAction SilentlyContinue
        foreach ($linha in $tail) {
            Write-Item $linha
        }
    } else {
        Write-Warn "Log de auditoria nao existe ainda"
        Write-Item "Criado pelo verificar-deploy.ps1 apos primeira execucao"
        Write-Item "Path esperado: $($Script:LogDeploy)"
    }
}

# ============================================================================
# ORQUESTRADOR DEDICADO (chamada opcional)
# ============================================================================
function Chamar-VerificarDeploy {
    Write-Bloco "*" "Orquestrador dedicado (verificar-deploy.ps1)"

    if (Test-Path ".\verificar-deploy.ps1") {
        Write-Info "Executando .\verificar-deploy.ps1 -SkipPolling"
        Write-Host ""
        & ".\verificar-deploy.ps1" -SkipPolling
    } else {
        Write-Warn "verificar-deploy.ps1 nao encontrado na raiz"
        Write-Item "Este e um script separado, mais completo"
    }
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

Write-Host ""
Write-Host ("#" * 78) -ForegroundColor Magenta
Write-Host "# VERIFICACAO MANUAL AVULSA - Livro DOE em Usinagem" -ForegroundColor Magenta
Write-Host "# $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host ("#" * 78) -ForegroundColor Magenta

# Bloco especifico
if ($Bloco -gt 0) {
    switch ($Bloco) {
        1 { Verificar-QuartoYml }
        2 { Verificar-Book }
        3 { Verificar-Sitemap }
        4 { Verificar-Deploy }
        5 { Verificar-UrlPublica }
        6 { Verificar-LogAuditoria }
    }
    Write-Host ""
    exit 0
}

# Todos os blocos
Verificar-QuartoYml
Verificar-Book
Verificar-Sitemap
Verificar-Deploy
Verificar-UrlPublica
Verificar-LogAuditoria

# Abrir index local se solicitado
if ($Abrir -and -not $Quiet) {
    if (Test-Path ".\_book\index.html") {
        Write-Host ""
        Write-Info "Abrindo _book\index.html localmente..."
        Start-Process ".\_book\index.html"
    }
}

Write-Host ""
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host "VERIFICACAO CONCLUIDA" -ForegroundColor Green
Write-Host ("=" * 78) -ForegroundColor Green
Write-Host ""
Write-Info "Para rodar bloco especifico: .\verificar-manual.ps1 -Bloco N (1-6)"
Write-Info "Para abrir no navegador:     .\verificar-manual.ps1 -Abrir"
