# ============================================================================
# executar-fase-1-5.ps1
#
# Orquestrador da Fase 1.5 - Monitoramento Continuo (SEO + Analytics)
#
# Diferente das fases anteriores: NAO e setup pontual, e uma rotina
# RECORRENTE de registro semanal. Roda toda semana ao longo de meses.
#
# O que faz:
#   1. Coleta automatica do que da para pegar sem login:
#      - GitHub Pages traffic (views/clones via gh api)
#      - Status das URLs publicas
#      - Contagem de URLs no sitemap
#   2. Captura interativa dos KPIs que exigem painel (voce digita):
#      - Search Console: impressoes, cliques, CTR, posicao, consultas top
#      - Analytics: visitantes, paginas top, fonte, bounce, conversoes
#   3. Grava tudo em setup/monitoramento-semanal.md (append, dedup por semana ISO)
#   4. Compara com metas realistas por mes de projeto
#   5. Dispara sinais de alerta (CTR baixo, bounce alto, zero impressoes)
#
# Persistencia:
#   setup/monitoramento-semanal.md       - registro humano-legivel (versionar!)
#   setup/fase-1-5-progresso.json        - dados estruturados por semana
#
# USO:
#   .\executar-fase-1-5.ps1              # Registro da semana atual (interativo)
#   .\executar-fase-1-5.ps1 -Auto        # So coleta automatica (sem perguntar KPIs)
#   .\executar-fase-1-5.ps1 -Status      # Ver historico e tendencias
#   .\executar-fase-1-5.ps1 -Ferramentas # Abrir ferramentas auxiliares no browser
#   .\executar-fase-1-5.ps1 -Metas       # Mostrar tabela de metas por mes
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [switch]$Auto,
    [switch]$Status,
    [switch]$Ferramentas,
    [switch]$Metas,
    [datetime]$InicioProjeto = "2026-07-01"
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:Repo       = "mariocezar1971/livro-doe-usinagem"
$Script:UrlBase    = "https://mariocezar1971.github.io/livro-doe-usinagem"
$Script:UrlSitemap = "$($Script:UrlBase)/sitemap.xml"
$Script:PastaSetup = ".\setup"
$Script:ArqRegistro = ".\setup\monitoramento-semanal.md"
$Script:ArqProgresso = ".\setup\fase-1-5-progresso.json"

# Corrigir PATH
foreach ($p in @("C:\Program Files\Git\cmd", "C:\Program Files\GitHub CLI")) {
    if ((Test-Path $p) -and ($env:PATH -notmatch [regex]::Escape($p))) {
        $env:PATH = "$p;$env:PATH"
    }
}

# ============================================================================
# HELPERS
# ============================================================================
function Write-Titulo($t) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Blue
    Write-Host $t -ForegroundColor Blue
    Write-Host ("=" * 78) -ForegroundColor Blue
}
function Write-Sec($t)   { Write-Host ""; Write-Host "--- $t ---" -ForegroundColor Cyan }
function Write-OK($m)    { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Info($m)  { Write-Host "[i]    $m" -ForegroundColor Cyan }
function Write-Warn($m)  { Write-Host "[!]    $m" -ForegroundColor Yellow }
function Write-Err($m)   { Write-Host "[X]    $m" -ForegroundColor Red }
function Write-Item($m)  { Write-Host "       $m" }

function Ask-Num($pergunta, $default = "") {
    $texto = if ($default -ne "") { "$pergunta [$default]" } else { $pergunta }
    $r = Read-Host $texto
    if ([string]::IsNullOrWhiteSpace($r)) {
        if ($default -ne "") { return $default } else { return "" }
    }
    return $r.Trim()
}

function Ask-Text($pergunta, $default = "") {
    $r = Read-Host $pergunta
    if ([string]::IsNullOrWhiteSpace($r) -and $default) { return $default }
    return $r
}

# Semana ISO 8601 (mesma que o Search Console usa)
function Get-SemanaISO($data = (Get-Date)) {
    $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $dia = $cal.GetDayOfWeek($data)
    if ($dia -ge [System.DayOfWeek]::Monday -and $dia -le [System.DayOfWeek]::Wednesday) {
        $data = $data.AddDays(3)
    } elseif ($dia -eq [System.DayOfWeek]::Sunday) {
        $data = $data.AddDays(-3)
    } else {
        $data = $data.AddDays(4 - [int]$dia)
    }
    $semana = $cal.GetWeekOfYear($data, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [System.DayOfWeek]::Monday)
    return @{ ano = $data.Year; semana = $semana; label = "$($data.Year)-W$('{0:D2}' -f $semana)" }
}

# Mes do projeto (1, 2, 3...) desde o inicio
function Get-MesProjeto {
    $hoje = Get-Date
    $meses = ($hoje.Year - $InicioProjeto.Year) * 12 + ($hoje.Month - $InicioProjeto.Month)
    return [math]::Max(1, $meses + 1)
}

# ============================================================================
# METAS POR MES DE PROJETO
# ============================================================================
function Get-Metas($mesProjeto) {
    # Retorna hashtable com metas de impressoes, cliques, visitantes
    if ($mesProjeto -le 1) {
        return @{ imp="50-200"; cliques="5-30"; visitantes="30-80"; posicao="30-50"; fonte="DIRETO" }
    } elseif ($mesProjeto -le 3) {
        return @{ imp="500-2000"; cliques="30-100"; visitantes="100-250"; posicao="25-40"; fonte="Google comecando" }
    } elseif ($mesProjeto -le 6) {
        return @{ imp="3000-10000"; cliques="100-400"; visitantes="300-600"; posicao="15-25"; fonte="Google + LinkedIn" }
    } elseif ($mesProjeto -le 12) {
        return @{ imp="10000-30000"; cliques="400-1000"; visitantes="800-1500"; posicao="5-15"; fonte="Diversificado" }
    } else {
        return @{ imp="30000+"; cliques="1000+"; visitantes="2000-4000"; posicao="5-15"; fonte="Efeito lancamento" }
    }
}

function Mostrar-Metas {
    Write-Titulo "METAS REALISTAS DE TRAFEGO (por mes de projeto)"

    $mesAtual = Get-MesProjeto
    Write-Info "Projeto iniciado em: $($InicioProjeto.ToString('yyyy-MM-dd'))"
    Write-Info "Mes atual do projeto: $mesAtual"
    Write-Host ""

    $linhas = @(
        @{ periodo="1o mes";      imp="50-200";       cliques="5-30";    visit="30-80";     pos="30-50" },
        @{ periodo="3o mes";      imp="500-2000";     cliques="30-100";  visit="100-250";   pos="25-40" },
        @{ periodo="6o mes";      imp="3000-10000";   cliques="100-400"; visit="300-600";   pos="15-25" },
        @{ periodo="1 ano";       imp="10000-30000";  cliques="400-1k";  visit="800-1500";  pos="5-15" },
        @{ periodo="Lancamento";  imp="30000+";       cliques="1000+";   visit="2000-4000"; pos="5-15" }
    )

    $fmt = "  {0,-12} {1,-14} {2,-12} {3,-14} {4,-10}"
    Write-Host ($fmt -f "Periodo", "Impressoes", "Cliques", "Visitantes", "Posicao") -ForegroundColor Yellow
    Write-Host ($fmt -f "-------", "----------", "-------", "----------", "-------") -ForegroundColor DarkGray
    foreach ($l in $linhas) {
        Write-Host ($fmt -f $l.periodo, $l.imp, $l.cliques, $l.visit, $l.pos)
    }

    Write-Host ""
    Write-Info "REGRA DA CAUDA LONGA:"
    Write-Item "Livros tecnicos de nicho acumulam trafego LENTAMENTE."
    Write-Item "Tracao real leva 12-18 meses. Paciencia e chave."
    Write-Item "Depois de indexar, o trafego fica ESTAVEL POR ANOS."
}

# ============================================================================
# COLETA AUTOMATICA (sem login)
# ============================================================================
function Coletar-Automatico {
    Write-Sec "Coleta automatica (sem login necessario)"

    $dados = @{
        github_views      = "n/d"
        github_visitors   = "n/d"
        sitemap_urls      = "n/d"
        urls_ok           = "n/d"
    }

    # GitHub Pages traffic via gh api
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Info "GitHub traffic (ultimos 14 dias)..."
        try {
            $traffic = gh api "/repos/$($Script:Repo)/traffic/views" 2>$null | ConvertFrom-Json
            if ($traffic) {
                $dados.github_views = $traffic.count
                $dados.github_visitors = $traffic.uniques
                Write-OK "Views: $($traffic.count) | Visitantes unicos: $($traffic.uniques)"
            }
        } catch {
            Write-Warn "Nao foi possivel obter traffic (requer permissao push no repo)"
        }
    } else {
        Write-Warn "gh CLI ausente - pulando GitHub traffic"
    }

    # Sitemap
    Write-Info "Sitemap publico..."
    try {
        $resp = Invoke-WebRequest -Uri $Script:UrlSitemap -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $urls = ([regex]::Matches($resp.Content, '<loc>')).Count
        $dados.sitemap_urls = $urls
        Write-OK "Sitemap: $urls URLs indexaveis (HTTP $($resp.StatusCode))"
    } catch {
        Write-Warn "Sitemap inacessivel"
    }

    # URLs principais
    Write-Info "Status das URLs principais..."
    $urlsTeste = @(
        "$($Script:UrlBase)/",
        "$($Script:UrlBase)/em-breve.html",
        "$($Script:UrlBase)/parte-1/cap-01-por-que-doe.html"
    )
    $ok = 0
    foreach ($u in $urlsTeste) {
        try {
            $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10 -Method Head -ErrorAction Stop
            if ($r.StatusCode -eq 200) { $ok++ }
        } catch { }
    }
    $dados.urls_ok = "$ok/$($urlsTeste.Count)"
    if ($ok -eq $urlsTeste.Count) {
        Write-OK "URLs: $ok/$($urlsTeste.Count) no ar"
    } else {
        Write-Warn "URLs: $ok/$($urlsTeste.Count) no ar (verificar deploy)"
    }

    return $dados
}

# ============================================================================
# CAPTURA INTERATIVA DE KPIs
# ============================================================================
function Capturar-SearchConsole {
    Write-Sec "KPIs Google Search Console (voce coleta no painel)"

    Write-Info "Abra: https://search.google.com/search-console"
    Write-Item "Menu Desempenho > ultimos 7 dias"
    Write-Host ""

    $sc = @{}
    $sc.impressoes = Ask-Num "Impressoes (7 dias)" "0"
    $sc.cliques    = Ask-Num "Cliques (7 dias)" "0"

    # CTR calculado
    $imp = [double]($sc.impressoes -replace '[^\d.]', '')
    $cli = [double]($sc.cliques -replace '[^\d.]', '')
    if ($imp -gt 0) {
        $sc.ctr = [math]::Round(100 * $cli / $imp, 2)
        Write-Info "CTR calculado: $($sc.ctr)%"
    } else {
        $sc.ctr = 0
    }

    $sc.posicao    = Ask-Num "Posicao media" "0"
    $sc.consulta1  = Ask-Text "Consulta TOP 1 (ou Enter para pular)"
    $sc.consulta2  = Ask-Text "Consulta TOP 2 (ou Enter)"
    $sc.consulta3  = Ask-Text "Consulta TOP 3 (ou Enter)"
    $sc.cobertura  = Ask-Num "Paginas indexadas (Cobertura)" "0"

    return $sc
}

function Capturar-Analytics {
    Write-Sec "KPIs Analytics (voce coleta no painel, se ativo)"

    $temAnalytics = Read-Host "Analytics ja esta ativo? (S/N) [N]"
    if ($temAnalytics -notmatch '^[SsYy]') {
        Write-Info "Analytics ainda nao ativo - pulando (normal ate ~30 dias)"
        return @{ ativo = $false }
    }

    $an = @{ ativo = $true }
    $an.visitantes = Ask-Num "Visitantes unicos (7 dias)" "0"
    $an.pagina_top = Ask-Text "Pagina mais vista (ou Enter)"
    $an.fonte_top  = Ask-Text "Fonte principal (Direto/Google/LinkedIn/etc)"
    $an.duracao    = Ask-Text "Duracao media sessao (ex: 2m30s, ou Enter)"
    $an.bounce     = Ask-Num "Bounce rate % (ou 0)" "0"
    $an.conversoes = Ask-Num "Conversoes (cadastros Brevo, ou 0)" "0"

    return $an
}

# ============================================================================
# SINAIS DE ALERTA
# ============================================================================
function Verificar-Alertas($sc, $an, $mesProjeto) {
    Write-Sec "Sinais de alerta"

    $alertas = @()

    # CTR < 1%
    if ($sc.ctr -ne $null -and $sc.ctr -lt 1 -and [double]($sc.impressoes -replace '[^\d.]','') -gt 50) {
        $alertas += "CTR < 1% - titulo/meta description pouco atraentes. Revisar setup/SEO_SETUP_GUIA.md"
    }

    # Bounce > 85%
    if ($an.ativo -and [double]($an.bounce -replace '[^\d.]','') -gt 85) {
        $alertas += "Bounce rate > 85% - conteudo nao entrega o prometido. Melhorar introducoes."
    }

    # Zero impressoes apos mes 1
    if ($mesProjeto -gt 1 -and [double]($sc.impressoes -replace '[^\d.]','') -eq 0) {
        $alertas += "Zero impressoes apos mes 1 - indexacao pode ter travado. Ping sitemap + solicitar indexacao."
    }

    # Cobertura estagnada
    $cob = [double]($sc.cobertura -replace '[^\d.]','')
    if ($mesProjeto -ge 2 -and $cob -gt 0 -and $cob -lt 10) {
        $alertas += "Cobertura baixa ($cob paginas) apos mes $mesProjeto - verificar Cobertura > Excluidas."
    }

    if ($alertas.Count -eq 0) {
        Write-OK "Nenhum sinal de alerta disparado"
    } else {
        foreach ($a in $alertas) {
            Write-Warn $a
        }
    }

    return $alertas
}

# ============================================================================
# COMPARAR COM METAS
# ============================================================================
function Comparar-Metas($sc, $mesProjeto) {
    Write-Sec "Comparacao com metas (mes $mesProjeto do projeto)"

    $metas = Get-Metas $mesProjeto

    Write-Info "Meta de impressoes ($('mes ' + $mesProjeto)): $($metas.imp)"
    Write-Item "Voce tem: $($sc.impressoes) impressoes"
    Write-Host ""
    Write-Info "Meta de cliques: $($metas.cliques)"
    Write-Item "Voce tem: $($sc.cliques) cliques"
    Write-Host ""
    Write-Info "Posicao media esperada: $($metas.posicao)"
    Write-Item "Voce tem: $($sc.posicao)"
    Write-Host ""
    Write-Info "Fonte principal esperada: $($metas.fonte)"
}

# ============================================================================
# GRAVAR REGISTRO SEMANAL
# ============================================================================
function Gravar-Registro($semana, $auto, $sc, $an, $alertas, $mesProjeto) {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }

    # Bloco Markdown desta semana
    $bloco = ""
    $bloco += "## $($semana.label) (mes $mesProjeto do projeto)`n`n"
    $bloco += "Registrado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"

    $bloco += "### Coleta automatica`n"
    $bloco += "- GitHub views (14d): $($auto.github_views)`n"
    $bloco += "- GitHub visitantes (14d): $($auto.github_visitors)`n"
    $bloco += "- Sitemap URLs: $($auto.sitemap_urls)`n"
    $bloco += "- URLs no ar: $($auto.urls_ok)`n`n"

    $bloco += "### Search Console`n"
    $bloco += "- Impressoes: $($sc.impressoes)`n"
    $bloco += "- Cliques: $($sc.cliques)`n"
    $bloco += "- CTR: $($sc.ctr)%`n"
    $bloco += "- Posicao media: $($sc.posicao)`n"
    $bloco += "- Cobertura (paginas indexadas): $($sc.cobertura)`n"
    $consultas = @($sc.consulta1, $sc.consulta2, $sc.consulta3) | Where-Object { $_ }
    if ($consultas.Count -gt 0) {
        $bloco += "- Top consultas: $($consultas -join '; ')`n"
    }
    $bloco += "`n"

    if ($an.ativo) {
        $bloco += "### Analytics`n"
        $bloco += "- Visitantes unicos: $($an.visitantes)`n"
        $bloco += "- Pagina top: $($an.pagina_top)`n"
        $bloco += "- Fonte principal: $($an.fonte_top)`n"
        $bloco += "- Duracao media: $($an.duracao)`n"
        $bloco += "- Bounce rate: $($an.bounce)%`n"
        $bloco += "- Conversoes: $($an.conversoes)`n`n"
    } else {
        $bloco += "### Analytics`n- (nao ativo ainda)`n`n"
    }

    if ($alertas.Count -gt 0) {
        $bloco += "### Alertas`n"
        foreach ($a in $alertas) { $bloco += "- [!] $a`n" }
        $bloco += "`n"
    }

    $bloco += "### Acoes tomadas`n- (preencher manualmente)`n`n"
    $bloco += "### Proximas acoes`n- (preencher manualmente)`n`n"
    $bloco += "---`n`n"

    # Ler registro existente e fazer DEDUP por semana ISO
    $cabecalho = "# Monitoramento Semanal - Livro DOE em Usinagem`n`n"
    $cabecalho += "Registro automatico gerado por executar-fase-1-5.ps1`n"
    $cabecalho += "Versionar este arquivo no Git para historico auditavel.`n`n"
    $cabecalho += "---`n`n"

    $conteudoExistente = ""
    if (Test-Path $Script:ArqRegistro) {
        $conteudoExistente = Get-Content $Script:ArqRegistro -Raw -Encoding UTF8
        # Remover cabecalho antigo para nao duplicar
        $conteudoExistente = $conteudoExistente -replace '(?s)^.*?---\r?\n\r?\n', ''
        # DEDUP: remover bloco desta mesma semana se ja existir
        $padrao = "(?s)## $([regex]::Escape($semana.label)).*?(?=## \d{4}-W|\z)"
        $conteudoExistente = $conteudoExistente -replace $padrao, ''
        $conteudoExistente = $conteudoExistente.TrimStart()
    }

    # Novo registro no topo (mais recente primeiro)
    $final = $cabecalho + $bloco + $conteudoExistente

    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    $path = Join-Path (Get-Location) $Script:ArqRegistro
    [System.IO.File]::WriteAllText($path, $final, $utf8SemBom)

    Write-OK "Registro gravado: $($Script:ArqRegistro) (semana $($semana.label))"
}

# ============================================================================
# STATUS / HISTORICO
# ============================================================================
function Mostrar-Status {
    Write-Titulo "HISTORICO DE MONITORAMENTO"

    if (-not (Test-Path $Script:ArqRegistro)) {
        Write-Warn "Nenhum registro ainda. Rode: .\executar-fase-1-5.ps1"
        return
    }

    $conteudo = Get-Content $Script:ArqRegistro -Raw -Encoding UTF8

    # Contar semanas registradas
    $semanas = ([regex]::Matches($conteudo, '## \d{4}-W\d{2}')).Count
    Write-Info "Semanas registradas: $semanas"

    # Extrair series de impressoes/cliques para mini tendencia
    Write-Host ""
    Write-Info "Evolucao (mais recente primeiro):"
    Write-Host ""

    $blocos = [regex]::Matches($conteudo, '(?s)## (\d{4}-W\d{2}).*?(?=## \d{4}-W|\z)')
    $count = 0
    foreach ($b in $blocos) {
        if ($count -ge 8) { break }
        $texto = $b.Value
        $label = $b.Groups[1].Value

        $imp = if ($texto -match 'Impressoes:\s*(\S+)') { $Matches[1] } else { "?" }
        $cli = if ($texto -match 'Cliques:\s*(\S+)') { $Matches[1] } else { "?" }
        $ctr = if ($texto -match 'CTR:\s*(\S+)') { $Matches[1] } else { "?" }
        $vis = if ($texto -match 'Visitantes unicos:\s*(\S+)') { $Matches[1] } else { "-" }

        $linha = "  {0}  imp={1,-8} cli={2,-6} ctr={3,-7} visit={4}" -f $label, $imp, $cli, $ctr, $vis
        Write-Host $linha
        $count++
    }

    Write-Host ""
    Write-Info "Registro completo: $($Script:ArqRegistro)"
}

# ============================================================================
# FERRAMENTAS AUXILIARES (abrir no browser)
# ============================================================================
function Abrir-Ferramentas {
    Write-Titulo "FERRAMENTAS AUXILIARES"

    $ferramentas = @(
        @{ nome="Google Search Console"; url="https://search.google.com/search-console" },
        @{ nome="Google Trends"; url="https://trends.google.com/trends" },
        @{ nome="Rich Results Test"; url="https://search.google.com/test/rich-results" },
        @{ nome="LinkedIn Post Inspector"; url="https://www.linkedin.com/post-inspector/" },
        @{ nome="Facebook Sharing Debugger (WhatsApp)"; url="https://developers.facebook.com/tools/debug/" }
    )

    Write-Info "Ferramentas de monitoramento:"
    for ($i = 0; $i -lt $ferramentas.Count; $i++) {
        Write-Item "$($i+1). $($ferramentas[$i].nome)"
        Write-Item "   $($ferramentas[$i].url)"
    }

    Write-Host ""
    $escolha = Read-Host "Abrir qual? (1-5, ou 'todas', ou Enter para nenhuma)"

    if ($escolha -eq "todas") {
        foreach ($f in $ferramentas) { Start-Process $f.url }
        Write-OK "Todas abertas"
    } elseif ($escolha -match '^\d+$') {
        $idx = [int]$escolha - 1
        if ($idx -ge 0 -and $idx -lt $ferramentas.Count) {
            Start-Process $ferramentas[$idx].url
            Write-OK "Aberto: $($ferramentas[$idx].nome)"
        }
    }
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
}

# Modos especiais
if ($Metas) {
    Mostrar-Metas
    exit 0
}
if ($Status) {
    Mostrar-Status
    exit 0
}
if ($Ferramentas) {
    Abrir-Ferramentas
    exit 0
}

# Registro semanal
Write-Titulo "FASE 1.5 - MONITORAMENTO SEMANAL"

$semana = Get-SemanaISO
$mesProjeto = Get-MesProjeto

Write-Info "Semana ISO: $($semana.label)"
Write-Info "Mes do projeto: $mesProjeto"
Write-Info "Repositorio: $($Script:Repo)"

# 1. Coleta automatica (sempre)
$auto = Coletar-Automatico

# 2. Captura interativa (a menos que -Auto)
if ($Auto) {
    Write-Info "Modo -Auto: pulando captura manual de KPIs"
    $sc = @{ impressoes="n/d"; cliques="n/d"; ctr=0; posicao="n/d"; cobertura="n/d"; consulta1=""; consulta2=""; consulta3="" }
    $an = @{ ativo=$false }
    $alertas = @()
} else {
    $sc = Capturar-SearchConsole
    $an = Capturar-Analytics
    Comparar-Metas $sc $mesProjeto
    $alertas = Verificar-Alertas $sc $an $mesProjeto
}

# 3. Gravar registro
Gravar-Registro $semana $auto $sc $an $alertas $mesProjeto

# 4. Lembrete de commit
Write-Host ""
Write-Titulo "REGISTRO SEMANAL CONCLUIDO"
Write-Info "Nao esqueca de versionar o registro:"
Write-Host "  git add $($Script:ArqRegistro)" -ForegroundColor White
Write-Host "  git commit -m `"Monitoramento semana $($semana.label)`"" -ForegroundColor White
Write-Host "  git push" -ForegroundColor White
Write-Host ""
Write-Info "Ver historico:    .\executar-fase-1-5.ps1 -Status"
Write-Info "Ver metas:        .\executar-fase-1-5.ps1 -Metas"
Write-Info "Abrir ferramentas: .\executar-fase-1-5.ps1 -Ferramentas"
