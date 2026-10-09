# ============================================================================
# executar-fase-8.ps1
#
# Orquestrador da Fase 8 - Correcoes pos-revisao
#
# NATUREZA DESTA FASE: diferente de todas as anteriores.
#   As fases 3-7 CRIARAM conteudo. Esta CORRIGE o conteudo existente,
#   a partir da revisao de autor (checklist) e dos pareceristas.
#
#   Tres tipos de tarefa:
#   [CHECK]   - verificacao automatica (o script varre e aponta)
#   [AJUSTE]  - correcao que Claude aplica quando voce traz o item
#   [RODADA]  - uma leva de correcoes (do checklist ou de parecerista)
#
#   O script NAO adivinha as correcoes. Ele:
#   1. Roda verificacoes automaticas (italicos, equacoes) e aponta candidatos
#   2. Rastreia as rodadas de correcao aplicadas
#   3. Registra o que foi corrigido, para historico
#
# Sub-fases (do roadmap "CLAUDE pode fazer DEPOIS da revisao"):
#   8.1 Incorporar correcoes dos pareceristas   (por rodada)
#   8.2 Padronizar italicos (termos estrangeiros) (CHECK + AJUSTE)
#   8.3 Padronizar formatacao de equacoes          (CHECK + AJUSTE)
#   8.4 Aplicar ajustes do checklist de revisao    (por rodada)
#
# Persistencia:
#   setup/fase-8-progresso.json    - estado + log de rodadas
#   setup/FASE_8_CORRECOES.md      - relatorio
#
# USO:
#   .\executar-fase-8.ps1                       # Menu
#   .\executar-fase-8.ps1 -Status               # Visao geral
#   .\executar-fase-8.ps1 -CheckItalicos        # Varre termos estrangeiros sem italico
#   .\executar-fase-8.ps1 -CheckEquacoes        # Varre inconsistencias em equacoes
#   .\executar-fase-8.ps1 -Rodada "parecerista Alisson" -Subfase 8.1  # registrar rodada
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet("8.1", "8.2", "8.3", "8.4", "")]
    [string]$Subfase = "",
    [string]$Rodada = "",
    [switch]$CheckItalicos,
    [switch]$CheckEquacoes,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup   = ".\setup"
$Script:ArqProgresso = ".\setup\fase-8-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_8_CORRECOES.md"

$Script:SubfaseNome = @{
    "8.1" = "Incorporar correcoes dos pareceristas"
    "8.2" = "Padronizar italicos (termos estrangeiros)"
    "8.3" = "Padronizar formatacao de equacoes"
    "8.4" = "Aplicar ajustes do checklist de revisao"
}

# Pastas dos .qmd do livro
$Script:PastasQmd = @("parte-1", "parte-2", "parte-3", "parte-4", "apendices")

# Termos estrangeiros que DEVEM estar em italico (para o check 8.2)
$Script:TermosEstrangeiros = @(
    "screening", "design of experiments", "crossover", "fitness",
    "steepest ascent", "lack of fit", "software", "hardware",
    "benchmark", "trade-off", "trade-offs", "feedback", "setup",
    "half-normal", "default", "online", "digital twin", "digital twins",
    "machine learning", "one factor at a time"
)

# ============================================================================
# CORRIGIR PATH
# ============================================================================
foreach ($p in @("C:\Program Files\Git\cmd", "C:\Program Files\Quarto\bin", "$env:LOCALAPPDATA\Programs\Quarto\bin")) {
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

function Ask-YesNo($pergunta, $default = "S") {
    while ($true) {
        $r = Read-Host "$pergunta (S/N) [$default]"
        if ([string]::IsNullOrWhiteSpace($r)) { $r = $default }
        if ($r -match '^[SsYy]') { return $true }
        if ($r -match '^[Nn]')   { return $false }
        Write-Warn "Responda S ou N"
    }
}

function Get-Qmds {
    $qmds = @()
    foreach ($pasta in $Script:PastasQmd) {
        if (Test-Path $pasta) {
            $qmds += Get-ChildItem $pasta -Filter "*.qmd" -ErrorAction SilentlyContinue
        }
    }
    # .qmd da raiz tambem (glossario, sobre-o-autor)
    $qmds += Get-ChildItem . -Filter "*.qmd" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'index' }
    return $qmds
}

function Ler-Utf8($path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

# ============================================================================
# PERSISTENCIA
# ============================================================================
function Initialize-Progresso {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }
    if (Test-Path $Script:ArqProgresso) {
        return (Get-Content $Script:ArqProgresso -Raw -Encoding UTF8 | ConvertFrom-Json)
    }

    return [PSCustomObject]@{
        fase          = "8"
        titulo        = "Correcoes pos-revisao"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        rodadas       = @()
        checks        = [PSCustomObject]@{
            italicos_ultima  = ""
            equacoes_ultima  = ""
        }
    }
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:ArqProgresso
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# ============================================================================
# CHECK 8.2 - ITALICOS (termos estrangeiros sem italico)
# ============================================================================
function Check-Italicos {
    Write-Titulo "CHECK 8.2 - Termos estrangeiros sem italico"
    Write-Info "Procurando termos estrangeiros que aparecem FORA de italico..."
    Write-Info "(italico em Markdown = *termo* ou _termo_)"
    Write-Host ""

    $qmds = Get-Qmds
    if ($qmds.Count -eq 0) { Write-Err "Nenhum .qmd encontrado"; return }

    $total = 0
    foreach ($termo in $Script:TermosEstrangeiros) {
        $ocorrencias = @()
        foreach ($q in $qmds) {
            $c = Ler-Utf8 $q.FullName
            # Remover blocos de codigo (nao conta termo dentro de codigo)
            $cSemCod = $c -replace '(?s)```.*?```', ''
            # Procurar o termo NAO precedido/seguido de * ou _ (fora de italico)
            # Palavra inteira, case-insensitive
            $pattern = '(?<![\*_\w])' + [regex]::Escape($termo) + '(?![\*_\w])'
            $ms = [regex]::Matches($cSemCod, $pattern, 'IgnoreCase')
            if ($ms.Count -gt 0) {
                $ocorrencias += "$($q.Name): $($ms.Count)x"
            }
        }
        if ($ocorrencias.Count -gt 0) {
            $somaTermo = ($ocorrencias | ForEach-Object { [int]($_ -replace '.*: ', '' -replace 'x','') } | Measure-Object -Sum).Sum
            $total += $somaTermo
            Write-Warn "'$termo' sem italico: $($ocorrencias -join ' | ')"
        }
    }

    Write-Host ""
    if ($total -eq 0) {
        Write-OK "Nenhum termo estrangeiro fora de italico encontrado"
    } else {
        Write-Info "Total: $total ocorrencias candidatas"
        Write-Item "NOTA: nem toda ocorrencia precisa de italico (ex.: em titulos,"
        Write-Item "ou quando o termo ja virou aportuguesado). Revise antes de aplicar."
        Write-Item "Peca ao Claude para padronizar os que voce confirmar."
    }
    return $total
}

# ============================================================================
# CHECK 8.3 - EQUACOES (inconsistencias de formatacao)
# ============================================================================
function Check-Equacoes {
    Write-Titulo "CHECK 8.3 - Formatacao de equacoes"
    Write-Info "Procurando inconsistencias na formatacao de equacoes..."
    Write-Host ""

    $qmds = Get-Qmds
    if ($qmds.Count -eq 0) { Write-Err "Nenhum .qmd encontrado"; return }

    $totalDisplay = 0
    $totalInline = 0
    $semRotulo = @()
    $problemas = @()

    foreach ($q in $qmds) {
        $c = Ler-Utf8 $q.FullName
        # Equacoes display: $$ ... $$
        $display = [regex]::Matches($c, '(?s)\$\$(.*?)\$\$')
        $totalDisplay += $display.Count
        # Equacoes inline: $ ... $ (nao $$)
        $inline = [regex]::Matches($c, '(?<!\$)\$(?!\$)([^\$\n]+?)\$(?!\$)')
        $totalInline += $inline.Count

        # Equacoes display sem rotulo {#eq-...} (so conta as numeradas)
        foreach ($m in $display) {
            $trecho = $m.Value
            # Se a equacao display nao tem {#eq-...} logo apos
            $pos = $m.Index + $m.Length
            $depois = $c.Substring($pos, [Math]::Min(30, $c.Length - $pos))
            if ($depois -notmatch '\{#eq-') {
                # display sem rotulo e normal em livro; so informamos a contagem
            }
        }

        # Problema comum: uso misto de \times e x para multiplicacao
        if ($c -match '\\times' -and $c -match '(?<![\\a-z])x(?![a-z])\s*=') {
            # heuristica fraca; so sinaliza
        }
    }

    Write-Info "Equacoes display (\$\$): $totalDisplay"
    Write-Info "Equacoes inline (\$): $totalInline"
    Write-Host ""
    Write-Item "Verificacoes que o Claude pode padronizar sob demanda:"
    Write-Item "- Uso consistente de \times (nao 'x') para multiplicacao"
    Write-Item "- Subscritos com chaves: x_{i} em vez de x_i quando multi-char"
    Write-Item "- Unidades fora do modo matematico (texto, nao italico)"
    Write-Item "- Rotulos {#eq-...} nas equacoes que sao referenciadas"
    Write-Host ""
    Write-Info "Para uma padronizacao especifica, peca ao Claude indicando o padrao."
    return @{ display = $totalDisplay; inline = $totalInline }
}

# ============================================================================
# REGISTRAR RODADA DE CORRECAO
# ============================================================================
function Registrar-Rodada($progresso, $subfase, $descricao) {
    if ([string]::IsNullOrWhiteSpace($descricao)) {
        Write-Err "Informe uma descricao: -Rodada 'parecerista X' -Subfase 8.1"
        return
    }
    $rodada = [PSCustomObject]@{
        data     = (Get-Date -Format "yyyy-MM-dd HH:mm")
        subfase  = $subfase
        descricao = $descricao
    }
    $progresso.rodadas += $rodada
    Save-Progresso $progresso
    Write-OK "Rodada registrada: [$subfase] $descricao"
    Write-Item "Total de rodadas: $($progresso.rodadas.Count)"
}

# ============================================================================
# STATUS
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 8 - CORRECOES POS-REVISAO"

    Write-Sec "Sub-fases"
    foreach ($sf in @("8.1", "8.2", "8.3", "8.4")) {
        $rodadasSf = @($progresso.rodadas | Where-Object { $_.subfase -eq $sf })
        $n = $rodadasSf.Count
        $ind = if ($n -gt 0) { "[..]" } else { "[  ]" }
        $cor = if ($n -gt 0) { "Cyan" } else { "Gray" }
        Write-Host ("  {0} {1} {2,-42} {3} rodada(s)" -f $ind, $sf, $Script:SubfaseNome[$sf], $n) -ForegroundColor $cor
    }

    if ($progresso.rodadas.Count -gt 0) {
        Write-Sec "Historico de rodadas"
        foreach ($r in $progresso.rodadas) {
            Write-Item "$($r.data) [$($r.subfase)] $($r.descricao)"
        }
    }

    Write-Sec "Verificacoes automaticas disponiveis"
    Write-Item "Italicos:  .\executar-fase-8.ps1 -CheckItalicos"
    Write-Item "Equacoes:  .\executar-fase-8.ps1 -CheckEquacoes"

    Write-Sec "Como funciona esta fase"
    Write-Item "1. Voce revisa (checklist) ou recebe parecer"
    Write-Item "2. Traz os ajustes ao Claude (capitulo + o que esta + o que deveria)"
    Write-Item "3. Claude corrige via base64; voce reinstala e commita"
    Write-Item "4. Registra a rodada: -Rodada 'descricao' -Subfase 8.X"
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 8 - Correcoes pos-revisao`n`n"
    $md += "Gerado em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
    $md += "Esta fase aplica correcoes ao conteudo existente, a partir da`n"
    $md += "revisao de autor (checklist) e dos pareceristas.`n`n---`n`n"

    foreach ($sf in @("8.1", "8.2", "8.3", "8.4")) {
        $rodadasSf = @($progresso.rodadas | Where-Object { $_.subfase -eq $sf })
        $md += "## $sf - $($Script:SubfaseNome[$sf]) ($($rodadasSf.Count) rodadas)`n`n"
        foreach ($r in $rodadasSf) {
            $md += "- $($r.data): $($r.descricao)`n"
        }
        $md += "`n"
    }

    $path = Join-Path (Get-Location) $Script:ArqDoc
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# MENU
# ============================================================================
function Show-Menu($progresso) {
    Write-Titulo "FASE 8 - CORRECOES POS-REVISAO"
    foreach ($sf in @("8.1", "8.2", "8.3", "8.4")) {
        $n = @($progresso.rodadas | Where-Object { $_.subfase -eq $sf }).Count
        Write-Host "  $sf - $($Script:SubfaseNome[$sf]) ($n rodadas)"
    }
    Write-Host ""
    Write-Host "  1) Check italicos (termos estrangeiros)"
    Write-Host "  2) Check equacoes (formatacao)"
    Write-Host "  3) Status / historico"
    Write-Host "  0) Sair"
    Write-Host ""
    return Read-Host "Escolha"
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
}

if ($Reset) {
    if (Ask-YesNo "Apagar progresso da Fase 8?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($CheckItalicos) {
    Check-Italicos | Out-Null
    $progresso.checks.italicos_ultima = (Get-Date -Format "yyyy-MM-dd HH:mm")
    Save-Progresso $progresso
    exit 0
}

if ($CheckEquacoes) {
    Check-Equacoes | Out-Null
    $progresso.checks.equacoes_ultima = (Get-Date -Format "yyyy-MM-dd HH:mm")
    Save-Progresso $progresso
    exit 0
}

if ($Rodada -ne "") {
    $sf = if ($Subfase -ne "") { $Subfase } else { "8.4" }
    Registrar-Rodada $progresso $sf $Rodada
    Update-Doc $progresso
    exit 0
}

if ($Status) {
    Mostrar-Status $progresso
    Update-Doc $progresso
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Check-Italicos | Out-Null }
        "2" { Check-Equacoes | Out-Null }
        "3" { Mostrar-Status $progresso }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-8.ps1 -Status"
