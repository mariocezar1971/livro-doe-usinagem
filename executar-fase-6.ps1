# ============================================================================
# executar-fase-6.ps1
#
# Orquestrador da Fase 6 - Parte IV + Apendices
#
# ATENCAO - o que este script FAZ e o que NAO faz:
#   FAZ: rastreia tarefas de escrita/preparo, mede progresso mecanico
#        (palavras, tabelas, figuras, codigo, esquemas SVG), e automatiza
#        o fluxo de verificacao. Lida com 2 capitulos + 4 apendices.
#   NAO FAZ: escrever o conteudo. Texto e trabalho de autoria; o preparo
#        dos apendices (SVG, CSV, repo de codigos) e trabalho manual.
#
# DIFERENCA das fases anteriores: componentes HETEROGENEOS.
#   - Caps 11, 12: capitulos de texto (como as fases 3-5)
#   - Apendice A: instrumentacao (texto + esquemas SVG)
#   - Apendice B: codigos R/Python (repo externo + QR)
#   - Apendice C: tabelas estatisticas (t, F, qui-quadrado, PCC)
#   - Apendice D: dados experimentais (CSV + dicionario + recurso aberto)
#   O script mede o que cada tipo exige.
#
# Componentes (usar -Item):
#   11  Cap 11 - Do laboratorio ao chao de fabrica   (4 tarefas)
#   12  Cap 12 - Sintese e direcoes de pesquisa       (3 tarefas)
#   A   Apendice A - Instrumentacao detalhada          (3 tarefas)
#   B   Apendice B - Codigos R e Python                (4 tarefas)
#   C   Apendice C - Tabelas estatisticas              (2 tarefas)
#   D   Apendice D - Dados experimentais consolidados  (3 tarefas)
#
# Persistencia:
#   setup/fase-6-progresso.json    - estado das tarefas
#   setup/FASE_6_PARTE_IV.md       - relatorio
#
# USO:
#   .\executar-fase-6.ps1                    # Menu principal
#   .\executar-fase-6.ps1 -Item 11           # Dashboard do Cap 11
#   .\executar-fase-6.ps1 -Item A            # Dashboard do Apendice A
#   .\executar-fase-6.ps1 -Item 11 -Tarefa 3 # Marcar/desmarcar tarefa 3
#   .\executar-fase-6.ps1 -Item B -Metricas  # So medir
#   .\executar-fase-6.ps1 -Status            # Visao geral da Fase 6
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet("11", "12", "A", "B", "C", "D", "")]
    [string]$Item = "",
    [ValidateRange(1, 8)]
    [int]$Tarefa = 0,
    [switch]$Metricas,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup   = ".\setup"
$Script:ArqProgresso = ".\setup\fase-6-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_6_PARTE_IV.md"

# Caminhos dos componentes
$Script:ItemPath = @{
    "11" = ".\parte-4\cap-11-chao-fabrica.qmd"
    "12" = ".\parte-4\cap-12-sintese.qmd"
    "A"  = ".\apendices\apendice-a-instrumentacao.qmd"
    "B"  = ".\apendices\apendice-b-codigos.qmd"
    "C"  = ".\apendices\apendice-c-tabelas.qmd"
    "D"  = ".\apendices\apendice-d-dados.qmd"
}
$Script:ItemNome = @{
    "11" = "Cap 11 - Do laboratorio ao chao de fabrica"
    "12" = "Cap 12 - Sintese e direcoes de pesquisa"
    "A"  = "Apendice A - Instrumentacao detalhada"
    "B"  = "Apendice B - Codigos R e Python"
    "C"  = "Apendice C - Tabelas estatisticas"
    "D"  = "Apendice D - Dados experimentais consolidados"
}

# Tipo de componente (decide quais metricas importam)
$Script:ItemTipo = @{
    "11" = "texto"; "12" = "texto"
    "A"  = "instrumentacao"; "B"  = "codigo"
    "C"  = "tabelas"; "D"  = "dados"
}

# Tarefas por componente
$Script:Tarefas = @{
    "11" = @(
        "Escrever adaptacao da metodologia para industria",
        "Escrever restricoes tipicas (custo, ruido, disponibilidade)",
        "Criar checklist de projeto experimental industrial",
        "Escrever erros frequentes e como evitar"
    )
    "12" = @(
        "Reescrever conclusoes em formato executivo",
        "Absorver trabalhos futuros atualizados para 2026",
        "Incluir tendencias: MQL, criogenia, IA, Industria 4.0"
    )
    "A" = @(
        "Migrar Cap IV da tese (dispositivos)",
        "Atualizar com instrumentacao PICTI 2026 (INA333+ADS1220+Arduino)",
        "Inserir esquemas eletricos em SVG limpo"
    )
    "B" = @(
        "Consolidar codigos R comentados",
        "Consolidar codigos Python comentados",
        "Publicar repositorio de codigos no GitHub",
        "Vincular QR code do repo no apendice impresso"
    )
    "C" = @(
        "Tabelas t-Student, F-Snedecor, qui-quadrado",
        "Coeficientes ortogonais para PCC"
    )
    "D" = @(
        "Exportar SQLite usinagem.sqlite3 para CSVs documentados",
        "Criar dicionario de dados",
        "Publicar dados como recurso aberto"
    )
}

# Meta de palavras (so para os de texto; apendices tecnicos variam)
$Script:MetaPalavras = @{
    "11" = @{ min = 3000; ideal = 4500 }
    "12" = @{ min = 2500; ideal = 3500 }
    "A"  = @{ min = 1000; ideal = 2500 }
    "B"  = @{ min = 500;  ideal = 1500 }
    "C"  = @{ min = 300;  ideal = 1000 }
    "D"  = @{ min = 300;  ideal = 1000 }
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

    $componentes = @()
    foreach ($id in @("11", "12", "A", "B", "C", "D")) {
        $tarefas = @()
        $idx = 1
        foreach ($t in $Script:Tarefas[$id]) {
            $tarefas += [PSCustomObject]@{ id = $idx; nome = $t; feito = $false }
            $idx++
        }
        $componentes += [PSCustomObject]@{
            item    = $id
            nome    = $Script:ItemNome[$id]
            tipo    = $Script:ItemTipo[$id]
            tarefas = $tarefas
        }
    }

    return [PSCustomObject]@{
        fase          = "6"
        titulo        = "Parte IV + Apendices"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        componentes   = $componentes
    }
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:ArqProgresso
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

function Get-ItemProgresso($progresso, $id) {
    return $progresso.componentes | Where-Object { $_.item -eq $id } | Select-Object -First 1
}

# ============================================================================
# METRICAS (adaptadas ao TIPO de componente)
# ============================================================================
function Medir-Item($id) {
    $path = $Script:ItemPath[$id]
    $m = @{
        existe = $false; bytes = 0; palavras = 0; citacoes = 0
        figuras = 0; tabelas = 0; callouts = 0; blocos_cod = 0
        svg = 0; links = 0; eh_stub = $true
    }
    if (-not (Test-Path $path)) { return $m }

    $m.existe = $true
    $c = Get-Content $path -Raw -Encoding UTF8
    $m.bytes = (Get-Item $path).Length

    $corpo = $c -replace '(?s)^---.*?---', ''
    $corpoTxt = $corpo -replace '(?s)```.*?```', ' '
    $corpoTxt = $corpoTxt -replace '[#>*`:\[\]{}|-]', ' '
    $m.palavras = ($corpoTxt -split '\s+' | Where-Object { $_ -match '\w' }).Count

    $m.citacoes = ([regex]::Matches($c, '@[a-zA-Z][a-zA-Z0-9_]+')).Count
    $figMd = ([regex]::Matches($c, '!\[[^\]]*\]\(')).Count
    $figRef = ([regex]::Matches($c, '#fig-')).Count
    $m.figuras = [math]::Max($figMd, $figRef)
    $m.tabelas = ([regex]::Matches($c, '#tbl-')).Count
    $m.callouts = ([regex]::Matches($c, ':::\s*\{\.callout')).Count
    # Blocos de codigo (exibicao ```r ou executavel ```{r})
    $m.blocos_cod = ([regex]::Matches($c, '(?m)^```\s*\{?(r|python)')).Count
    # SVG embutido ou referenciado
    $m.svg = ([regex]::Matches($c, '\.svg|<svg')).Count
    # Links (para repo de codigos, dados abertos)
    $m.links = ([regex]::Matches($c, 'https?://')).Count

    $m.eh_stub = ($c -match 'em desenvolvimento|Stub criado') -or ($m.palavras -lt 400)
    return $m
}

function Mostrar-Metricas($id) {
    Write-Sec "Metricas: $($Script:ItemNome[$id])"
    $tipo = $Script:ItemTipo[$id]
    $meta = $Script:MetaPalavras[$id]
    $m = Medir-Item $id

    if (-not $m.existe) { Write-Err "Arquivo nao existe: $($Script:ItemPath[$id])"; return $m }

    $p = $m.palavras
    if ($p -ge $meta.ideal)     { Write-OK "Palavras: $p (meta ideal $($meta.ideal)) - ATINGIDO" }
    elseif ($p -ge $meta.min)   { Write-OK "Palavras: $p (min $($meta.min), ideal $($meta.ideal))" }
    elseif ($m.eh_stub)         { Write-Warn "Palavras: $p - ainda e STUB" }
    else                        { Write-Warn "Palavras: $p (abaixo do min $($meta.min))" }

    Write-Item "Paginas estimadas: ~$([math]::Round($p/350,1)) pp"
    Write-Host ""

    # Metricas especificas por tipo
    switch ($tipo) {
        "texto" {
            Write-Item "Citacoes: $($m.citacoes) | Figuras: $($m.figuras) | Tabelas: $($m.tabelas) | Callouts: $($m.callouts)"
        }
        "instrumentacao" {
            Write-Info "Marca de instrumentacao:"
            Write-Item "Esquemas SVG:  $($m.svg)   (esperado: esquemas eletricos)"
            Write-Item "Figuras:       $($m.figuras)"
            Write-Item "Tabelas:       $($m.tabelas) (especificacoes de equipamentos)"
        }
        "codigo" {
            Write-Info "Marca de codigo:"
            Write-Item "Blocos de codigo: $($m.blocos_cod)"
            Write-Item "Links (repo/QR):  $($m.links)   (esperado: link do repo de codigos)"
        }
        "tabelas" {
            Write-Info "Marca de tabelas estatisticas:"
            Write-Item "Tabelas: $($m.tabelas) (t-Student, F, qui-quadrado, PCC)"
        }
        "dados" {
            Write-Info "Marca de dados abertos:"
            Write-Item "Tabelas: $($m.tabelas) (dicionario de dados)"
            Write-Item "Links:   $($m.links)   (esperado: link dos CSVs/recurso aberto)"
        }
    }
    return $m
}

# ============================================================================
# TOGGLE TAREFA
# ============================================================================
function Toggle-Tarefa($progresso, $id, $nt) {
    $comp = Get-ItemProgresso $progresso $id
    if (-not $comp) { Write-Err "Item $id nao existe"; return }
    $tarefa = $comp.tarefas | Where-Object { $_.id -eq $nt } | Select-Object -First 1
    if (-not $tarefa) { Write-Err "Tarefa $nt nao existe no item $id"; return }
    $tarefa.feito = -not $tarefa.feito
    Write-OK "Item $id tarefa $nt -> $(if ($tarefa.feito) { 'FEITO' } else { 'pendente' })"
    Write-Item $tarefa.nome
    Save-Progresso $progresso
}

# ============================================================================
# DASHBOARD DE UM COMPONENTE
# ============================================================================
function Dashboard-Item($progresso, $id) {
    Write-Titulo $Script:ItemNome[$id]
    $comp = Get-ItemProgresso $progresso $id

    Write-Sec "Tarefas"
    $feitas = 0
    foreach ($t in $comp.tarefas) {
        $box = if ($t.feito) { "[x]" } else { "[ ]" }
        $cor = if ($t.feito) { "Green" } else { "Gray" }
        if ($t.feito) { $feitas++ }
        Write-Host "  $box $($t.id). $($t.nome)" -ForegroundColor $cor
    }
    Write-Host ""
    Write-Info "Tarefas: $feitas/$($comp.tarefas.Count) concluidas"

    Mostrar-Metricas $id | Out-Null

    Write-Sec "Proximo passo"
    $m = Medir-Item $id
    if ($m.eh_stub) {
        Write-Item "Ainda e stub. Trabalho pendente:"
        foreach ($t in $comp.tarefas | Where-Object { -not $_.feito }) {
            Write-Item "  -> $($t.nome)"
        }
    } else {
        Write-Item "Componente tem conteudo."
        # Alertas especificos
        $tipo = $Script:ItemTipo[$id]
        if ($tipo -eq "instrumentacao" -and $m.svg -eq 0) {
            Write-Warn "Nenhum SVG - Apendice A pede esquemas eletricos em SVG"
        }
        if ($tipo -eq "codigo" -and $m.links -eq 0) {
            Write-Warn "Nenhum link - Apendice B pede link do repo de codigos"
        }
        if ($tipo -eq "dados" -and $m.links -eq 0) {
            Write-Warn "Nenhum link - Apendice D pede link dos dados abertos"
        }
    }
}

# ============================================================================
# STATUS GERAL
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 6 - PARTE IV + APENDICES"

    Write-Host ""
    Write-Host "  PARTE IV (capitulos):" -ForegroundColor Yellow
    foreach ($id in @("11", "12")) {
        Mostrar-LinhaStatus $progresso $id
    }
    Write-Host ""
    Write-Host "  APENDICES:" -ForegroundColor Yellow
    foreach ($id in @("A", "B", "C", "D")) {
        Mostrar-LinhaStatus $progresso $id
    }

    Write-Host ""
    Write-Info "Pre-requisito: Partes I, II e III (Fases 3-5) escritas"
    Write-Host ""
    Write-Info "Detalhar: .\executar-fase-6.ps1 -Item 11  (ou 12, A, B, C, D)"
    Write-Info "Metricas: .\executar-fase-6.ps1 -Item A -Metricas"
}

function Mostrar-LinhaStatus($progresso, $id) {
    $comp = Get-ItemProgresso $progresso $id
    $feitas = @($comp.tarefas | Where-Object { $_.feito }).Count
    $total = $comp.tarefas.Count
    $m = Medir-Item $id

    $ind = if ($feitas -eq $total -and -not $m.eh_stub) { "[OK]" }
           elseif ($feitas -gt 0 -or -not $m.eh_stub) { "[..]" }
           else { "[  ]" }
    $cor = if ($feitas -eq $total -and -not $m.eh_stub) { "Green" }
           elseif ($feitas -gt 0 -or -not $m.eh_stub) { "Cyan" }
           else { "Gray" }

    $extra = ""
    if (-not $m.eh_stub) {
        switch ($Script:ItemTipo[$id]) {
            "instrumentacao" { $extra = " | svg:$($m.svg) tab:$($m.tabelas)" }
            "codigo"         { $extra = " | cod:$($m.blocos_cod) links:$($m.links)" }
            "tabelas"        { $extra = " | tab:$($m.tabelas)" }
            "dados"          { $extra = " | tab:$($m.tabelas) links:$($m.links)" }
            default          { $extra = " | tab:$($m.tabelas)" }
        }
    }
    $estado = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p$extra" }
    $linha = "    {0} {1,-46} {2}/{3}, {4}" -f $ind, $Script:ItemNome[$id], $feitas, $total, $estado
    Write-Host $linha -ForegroundColor $cor
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 6 - Parte IV + Apendices`n`n"
    $md += "Gerado por executar-fase-6.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n---`n`n"

    foreach ($id in @("11", "12", "A", "B", "C", "D")) {
        $comp = Get-ItemProgresso $progresso $id
        $m = Medir-Item $id
        $feitas = @($comp.tarefas | Where-Object { $_.feito }).Count

        $md += "## $($Script:ItemNome[$id])`n`n"
        $md += "- Tipo: $($Script:ItemTipo[$id])`n"
        $md += "- Tarefas: $feitas/$($comp.tarefas.Count)`n"
        $md += "- Palavras: $($m.palavras) | Tabelas: $($m.tabelas) | Figuras: $($m.figuras) | Codigo: $($m.blocos_cod) | SVG: $($m.svg) | Links: $($m.links)`n"
        $md += "- Status: $(if ($m.eh_stub) { 'STUB' } else { 'Em desenvolvimento' })`n`n"
        foreach ($t in $comp.tarefas) {
            $box = if ($t.feito) { "[x]" } else { "[ ]" }
            $md += "  - $box $($t.nome)`n"
        }
        $md += "`n---`n`n"
    }

    $path = Join-Path (Get-Location) $Script:ArqDoc
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# MENU
# ============================================================================
function Show-Menu($progresso) {
    Write-Titulo "FASE 6 - PARTE IV + APENDICES"
    foreach ($id in @("11", "12", "A", "B", "C", "D")) {
        Mostrar-LinhaStatus $progresso $id
    }
    Write-Host ""
    Write-Host "  1) Cap 11 (Chao de fabrica)"
    Write-Host "  2) Cap 12 (Sintese)"
    Write-Host "  3) Apendice A (Instrumentacao)"
    Write-Host "  4) Apendice B (Codigos)"
    Write-Host "  5) Apendice C (Tabelas)"
    Write-Host "  6) Apendice D (Dados)"
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
    if (Ask-YesNo "Apagar progresso da Fase 6?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($Status) {
    Mostrar-Status $progresso
    Update-Doc $progresso
    exit 0
}

if ($Item -ne "") {
    if ($Metricas) { Mostrar-Metricas $Item | Out-Null; exit 0 }
    if ($Tarefa -ne 0) {
        Toggle-Tarefa $progresso $Item $Tarefa
        Update-Doc $progresso
        exit 0
    }
    Dashboard-Item $progresso $Item
    Update-Doc $progresso
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Dashboard-Item $progresso "11" }
        "2" { Dashboard-Item $progresso "12" }
        "3" { Dashboard-Item $progresso "A" }
        "4" { Dashboard-Item $progresso "B" }
        "5" { Dashboard-Item $progresso "C" }
        "6" { Dashboard-Item $progresso "D" }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-6.ps1 -Status"
