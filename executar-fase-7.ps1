# ============================================================================
# executar-fase-7.ps1
#
# Orquestrador da Fase 7 - Revisao e Finalizacao
#
# NATUREZA DESTA FASE: diferente de todas as anteriores.
#   Nao ha codigo a gerar nem capitulos a escrever. Esta fase e
#   majoritariamente TRABALHO HUMANO E EXTERNO: revisores, designer,
#   revisor linguistico, pareceristas. O orquestrador e um CHECKLIST
#   de acompanhamento das tarefas de finalizacao editorial.
#
#   Algumas tarefas Claude pode ajudar a PREPARAR (glossario, sobre o
#   autor, sinopse, verificacao automatica de refs cruzadas). Outras
#   dependem inteiramente de voce (contratar revisor, convidar prefacio,
#   contratar designer). O script distingue os dois tipos.
#
# 5 sub-fases:
#   7.1 Revisao tecnica interna     (4 itens)
#   7.2 Revisao tecnica externa     (4 itens)
#   7.3 Revisao linguistica         (3 itens)
#   7.4 Materiais finais            (5 itens)
#   7.5 Design da capa              (4 itens)
#
# Cada item tem um TIPO:
#   [AUTO]    - verificacao automatizavel pelo script
#   [CLAUDE]  - Claude pode preparar/escrever o material
#   [VOCE]    - acao externa sua (contratar, convidar, decidir)
#
# Persistencia:
#   setup/fase-7-progresso.json    - estado dos itens
#   setup/FASE_7_FINALIZACAO.md    - relatorio/checklist
#
# USO:
#   .\executar-fase-7.ps1                      # Menu principal
#   .\executar-fase-7.ps1 -Subfase "7.1"       # Dashboard de uma sub-fase
#   .\executar-fase-7.ps1 -Subfase "7.1" -Item 3  # Marcar/desmarcar item
#   .\executar-fase-7.ps1 -VerificarRefs       # Checagem automatica de refs cruzadas
#   .\executar-fase-7.ps1 -Status              # Visao geral
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet("7.1", "7.2", "7.3", "7.4", "7.5", "")]
    [string]$Subfase = "",
    [ValidateRange(1, 5)]
    [int]$Item = 0,
    [switch]$VerificarRefs,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup   = ".\setup"
$Script:ArqProgresso = ".\setup\fase-7-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_7_FINALIZACAO.md"

$Script:SubfaseNome = @{
    "7.1" = "Revisao tecnica interna"
    "7.2" = "Revisao tecnica externa"
    "7.3" = "Revisao linguistica"
    "7.4" = "Materiais finais"
    "7.5" = "Design da capa"
}

# Itens por sub-fase: @{ nome; tipo }
# tipo: AUTO (script verifica) | CLAUDE (Claude prepara) | VOCE (acao externa)
$Script:Itens = @{
    "7.1" = @(
        @{ nome = "Releitura integral em PDF impresso"; tipo = "VOCE" },
        @{ nome = "Verificar consistencia de notacao e simbolos"; tipo = "CLAUDE" },
        @{ nome = "Verificar referencias cruzadas (fig, tab, eq)"; tipo = "AUTO" },
        @{ nome = "Verificar reproducibilidade de todos os codigos"; tipo = "VOCE" }
    )
    "7.2" = @(
        @{ nome = "Convidar Prof. Alisson Machado para prefacio"; tipo = "VOCE" },
        @{ nome = "Convidar 2 pareceristas externos (academico + industrial)"; tipo = "VOCE" },
        @{ nome = "Incorporar correcoes recebidas"; tipo = "CLAUDE" },
        @{ nome = "Coletar 3-5 depoimentos para capa/orelha"; tipo = "VOCE" }
    )
    "7.3" = @(
        @{ nome = "Contratar revisor de portugues tecnico"; tipo = "VOCE" },
        @{ nome = "Padronizar italicos para termos estrangeiros"; tipo = "CLAUDE" },
        @{ nome = "Padronizar formatacao de equacoes"; tipo = "CLAUDE" }
    )
    "7.4" = @(
        @{ nome = "Escrever glossario (50-80 termos)"; tipo = "CLAUDE" },
        @{ nome = "Gerar indice remissivo via makeindex/LaTeX"; tipo = "VOCE" },
        @{ nome = "Escrever Sobre o autor"; tipo = "CLAUDE" },
        @{ nome = "Escrever sinopse e orelha (2 paragrafos)"; tipo = "CLAUDE" },
        @{ nome = "Lista de figuras, tabelas, equacoes (automatica Quarto)"; tipo = "AUTO" }
    )
    "7.5" = @(
        @{ nome = "Contratar designer (Fiverr/99designs, R`$200-600)"; tipo = "VOCE" },
        @{ nome = "Brief: tema usinagem + grafico DOE estilizado"; tipo = "CLAUDE" },
        @{ nome = "Versoes: ebook (1600x2400) + impresso KDP (template)"; tipo = "VOCE" },
        @{ nome = "Validar capa em thumbnail (legibilidade Amazon)"; tipo = "VOCE" }
    )
}

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

function Cor-Tipo($tipo) {
    switch ($tipo) {
        "AUTO"   { "Cyan" }
        "CLAUDE" { "Magenta" }
        "VOCE"   { "Yellow" }
        default  { "Gray" }
    }
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

    $subfases = @()
    foreach ($sf in @("7.1", "7.2", "7.3", "7.4", "7.5")) {
        $itens = @()
        $idx = 1
        foreach ($it in $Script:Itens[$sf]) {
            $itens += [PSCustomObject]@{ id = $idx; nome = $it.nome; tipo = $it.tipo; feito = $false }
            $idx++
        }
        $subfases += [PSCustomObject]@{
            subfase = $sf
            nome    = $Script:SubfaseNome[$sf]
            itens   = $itens
        }
    }

    return [PSCustomObject]@{
        fase          = "7"
        titulo        = "Revisao e Finalizacao"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        subfases      = $subfases
    }
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:ArqProgresso
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

function Get-SubfaseProgresso($progresso, $sf) {
    return $progresso.subfases | Where-Object { $_.subfase -eq $sf } | Select-Object -First 1
}

# ============================================================================
# TOGGLE ITEM
# ============================================================================
function Toggle-Item($progresso, $sf, $nit) {
    $comp = Get-SubfaseProgresso $progresso $sf
    if (-not $comp) { Write-Err "Sub-fase $sf nao existe"; return }
    $item = $comp.itens | Where-Object { $_.id -eq $nit } | Select-Object -First 1
    if (-not $item) { Write-Err "Item $nit nao existe na sub-fase $sf"; return }
    $item.feito = -not $item.feito
    Write-OK "Sub-fase $sf item $nit -> $(if ($item.feito) { 'FEITO' } else { 'pendente' })"
    Write-Item $item.nome
    Save-Progresso $progresso
}

# ============================================================================
# VERIFICACAO AUTOMATICA DE REFERENCIAS CRUZADAS
# ============================================================================
function Verificar-Refs {
    Write-Titulo "VERIFICACAO AUTOMATICA - Referencias cruzadas"
    Write-Info "Checando se cada @ref (fig/tbl/sec/eq) tem um rotulo correspondente..."
    Write-Host ""

    # Coletar todos os .qmd
    $qmds = @()
    foreach ($pasta in @("parte-1", "parte-2", "parte-3", "parte-4", "apendices", ".")) {
        if (Test-Path $pasta) {
            $qmds += Get-ChildItem $pasta -Filter "*.qmd" -ErrorAction SilentlyContinue
        }
    }
    if ($qmds.Count -eq 0) { Write-Err "Nenhum .qmd encontrado"; return }

    # Reunir todos os rotulos definidos (#fig-x, #tbl-x, #sec-x, #eq-x)
    $rotulos = @{}
    $refs = @()
    foreach ($q in $qmds) {
        $c = [System.IO.File]::ReadAllText($q.FullName, [System.Text.Encoding]::UTF8)
        # Rotulos definidos: {#fig-...}, {#tbl-...}, {#sec-...}, {#eq-...}
        foreach ($m in [regex]::Matches($c, '\{#((?:fig|tbl|sec|eq)-[a-zA-Z0-9_-]+)')) {
            $rotulos[$m.Groups[1].Value] = $q.Name
        }
        # Referencias usadas: @fig-..., @tbl-..., @sec-..., @eq-...
        foreach ($m in [regex]::Matches($c, '@((?:fig|tbl|sec|eq)-[a-zA-Z0-9_-]+)')) {
            $refs += [PSCustomObject]@{ ref = $m.Groups[1].Value; arquivo = $q.Name }
        }
    }

    Write-Info "Rotulos definidos: $($rotulos.Count)"
    Write-Info "Referencias usadas: $($refs.Count)"
    Write-Host ""

    # Refs que apontam para rotulo inexistente (links quebrados)
    $quebradas = @($refs | Where-Object { -not $rotulos.ContainsKey($_.ref) })
    if ($quebradas.Count -eq 0) {
        Write-OK "Nenhuma referencia quebrada - todos os @ref tem rotulo"
    } else {
        Write-Err "$($quebradas.Count) referencias QUEBRADAS (apontam para rotulo inexistente):"
        foreach ($qb in $quebradas | Select-Object -First 25) {
            Write-Item "@$($qb.ref)  (usado em $($qb.arquivo))"
        }
    }

    # Rotulos definidos mas nunca referenciados (aviso leve)
    $usados = $refs | ForEach-Object { $_.ref } | Sort-Object -Unique
    $orfaos = @($rotulos.Keys | Where-Object { $_ -notin $usados })
    if ($orfaos.Count -gt 0) {
        Write-Host ""
        Write-Warn "$($orfaos.Count) rotulos definidos mas nunca referenciados (ok para secoes):"
        foreach ($o in $orfaos | Select-Object -First 15) {
            Write-Item "#$o  (em $($rotulos[$o]))"
        }
    }
}

# ============================================================================
# DASHBOARD DE UMA SUB-FASE
# ============================================================================
function Dashboard-Subfase($progresso, $sf) {
    Write-Titulo "$sf - $($Script:SubfaseNome[$sf])"
    $comp = Get-SubfaseProgresso $progresso $sf

    Write-Sec "Itens"
    $feitos = 0
    foreach ($it in $comp.itens) {
        $box = if ($it.feito) { "[x]" } else { "[ ]" }
        if ($it.feito) { $feitos++ }
        $tag = "[$($it.tipo)]"
        $cor = if ($it.feito) { "Green" } else { Cor-Tipo $it.tipo }
        Write-Host ("  {0} {1} {2,-9} {3}" -f $box, $it.id, $tag, $it.nome) -ForegroundColor $cor
    }
    Write-Host ""
    Write-Info "Itens: $feitos/$($comp.itens.Count) concluidos"

    # Legenda de tipos
    Write-Host ""
    Write-Host "  Legenda: " -NoNewline
    Write-Host "[AUTO]" -ForegroundColor Cyan -NoNewline
    Write-Host " script verifica | " -NoNewline
    Write-Host "[CLAUDE]" -ForegroundColor Magenta -NoNewline
    Write-Host " Claude prepara | " -NoNewline
    Write-Host "[VOCE]" -ForegroundColor Yellow -NoNewline
    Write-Host " acao externa sua"

    # Dica para itens CLAUDE pendentes
    $claudePend = @($comp.itens | Where-Object { -not $_.feito -and $_.tipo -eq "CLAUDE" })
    if ($claudePend.Count -gt 0) {
        Write-Sec "Claude pode preparar (pendentes)"
        foreach ($c in $claudePend) {
            Write-Item "-> $($c.nome)"
        }
        Write-Item "Peca ao Claude: ele escreve o material; voce instala via base64."
    }
}

# ============================================================================
# STATUS GERAL
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 7 - REVISAO E FINALIZACAO"

    $totalItens = 0
    $totalFeitos = 0
    foreach ($sf in @("7.1", "7.2", "7.3", "7.4", "7.5")) {
        $comp = Get-SubfaseProgresso $progresso $sf
        $feitos = @($comp.itens | Where-Object { $_.feito }).Count
        $total = $comp.itens.Count
        $totalItens += $total
        $totalFeitos += $feitos

        $ind = if ($feitos -eq $total) { "[OK]" }
               elseif ($feitos -gt 0) { "[..]" }
               else { "[  ]" }
        $cor = if ($feitos -eq $total) { "Green" }
               elseif ($feitos -gt 0) { "Cyan" }
               else { "Gray" }
        $linha = "  {0} {1} {2,-26} {3}/{4}" -f $ind, $sf, $Script:SubfaseNome[$sf], $feitos, $total
        Write-Host $linha -ForegroundColor $cor
    }

    $pct = if ($totalItens -gt 0) { [math]::Round(100 * $totalFeitos / $totalItens, 0) } else { 0 }
    Write-Host ""
    Write-Info "Progresso geral: $totalFeitos/$totalItens itens ($pct%)"

    # Resumo por tipo (quanto depende de quem)
    $porTipo = @{ AUTO = 0; CLAUDE = 0; VOCE = 0 }
    $feitoTipo = @{ AUTO = 0; CLAUDE = 0; VOCE = 0 }
    foreach ($sf in @("7.1", "7.2", "7.3", "7.4", "7.5")) {
        $comp = Get-SubfaseProgresso $progresso $sf
        foreach ($it in $comp.itens) {
            $porTipo[$it.tipo]++
            if ($it.feito) { $feitoTipo[$it.tipo]++ }
        }
    }
    Write-Host ""
    Write-Info "Por responsavel:"
    Write-Host ("       [AUTO]   script:  {0}/{1}" -f $feitoTipo.AUTO, $porTipo.AUTO) -ForegroundColor Cyan
    Write-Host ("       [CLAUDE] Claude:  {0}/{1}" -f $feitoTipo.CLAUDE, $porTipo.CLAUDE) -ForegroundColor Magenta
    Write-Host ("       [VOCE]   voce:    {0}/{1}" -f $feitoTipo.VOCE, $porTipo.VOCE) -ForegroundColor Yellow

    Write-Host ""
    Write-Info "Detalhar: .\executar-fase-7.ps1 -Subfase 7.1  (ou 7.2 ... 7.5)"
    Write-Info "Verificar refs: .\executar-fase-7.ps1 -VerificarRefs"
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 7 - Revisao e Finalizacao`n`n"
    $md += "Gerado por executar-fase-7.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
    $md += "Legenda de tipos: [AUTO] script verifica, [CLAUDE] Claude prepara, [VOCE] acao externa sua`n`n---`n`n"

    foreach ($sf in @("7.1", "7.2", "7.3", "7.4", "7.5")) {
        $comp = Get-SubfaseProgresso $progresso $sf
        $feitos = @($comp.itens | Where-Object { $_.feito }).Count
        $md += "## $sf - $($Script:SubfaseNome[$sf]) ($feitos/$($comp.itens.Count))`n`n"
        foreach ($it in $comp.itens) {
            $box = if ($it.feito) { "[x]" } else { "[ ]" }
            $md += "- $box **[$($it.tipo)]** $($it.nome)`n"
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
    Write-Titulo "FASE 7 - REVISAO E FINALIZACAO"
    foreach ($sf in @("7.1", "7.2", "7.3", "7.4", "7.5")) {
        $comp = Get-SubfaseProgresso $progresso $sf
        $feitos = @($comp.itens | Where-Object { $_.feito }).Count
        Write-Host "  $sf - $($Script:SubfaseNome[$sf]) ($feitos/$($comp.itens.Count))"
    }
    Write-Host ""
    Write-Host "  1) 7.1 Revisao tecnica interna"
    Write-Host "  2) 7.2 Revisao tecnica externa"
    Write-Host "  3) 7.3 Revisao linguistica"
    Write-Host "  4) 7.4 Materiais finais"
    Write-Host "  5) 7.5 Design da capa"
    Write-Host "  6) Verificar referencias cruzadas (automatico)"
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
    if (Ask-YesNo "Apagar progresso da Fase 7?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($VerificarRefs) {
    Verificar-Refs
    exit 0
}

if ($Status) {
    Mostrar-Status $progresso
    Update-Doc $progresso
    exit 0
}

if ($Subfase -ne "") {
    if ($Item -ne 0) {
        Toggle-Item $progresso $Subfase $Item
        Update-Doc $progresso
        exit 0
    }
    Dashboard-Subfase $progresso $Subfase
    Update-Doc $progresso
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Dashboard-Subfase $progresso "7.1" }
        "2" { Dashboard-Subfase $progresso "7.2" }
        "3" { Dashboard-Subfase $progresso "7.3" }
        "4" { Dashboard-Subfase $progresso "7.4" }
        "5" { Dashboard-Subfase $progresso "7.5" }
        "6" { Verificar-Refs }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-7.ps1 -Status"
