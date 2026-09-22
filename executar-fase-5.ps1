# ============================================================================
# executar-fase-5.ps1
#
# Orquestrador da Fase 5 - Parte III: Estudo de Caso (Cap 7, 8, 9, 10)
#
# ATENCAO - o que este script FAZ e o que NAO faz:
#   FAZ: rastreia tarefas de escrita, mede progresso mecanico (palavras,
#        citacoes, tabelas de DADOS, figuras, codigo), rastreia o Apendice A
#        acoplado ao Cap 7, e automatiza o fluxo backup->render->preview.
#   NAO FAZ: escrever os capitulos. O texto e trabalho de autoria.
#
# DIFERENCA das fases anteriores: a Parte III sao capitulos de RESULTADOS.
# Sao ricos em TABELAS DE DADOS e FIGURAS (matrizes, resultados, graficos,
# micrografias). O script mede especialmente esses dois.
# Alem disso, o Cap 7 esta ACOPLADO ao Apendice A (instrumentacao): a tarefa
# "mover instrumentacao para Apendice A" liga os dois arquivos.
#
# Sub-fases:
#   Cap 7  - Projeto experimental do estudo de caso  (4 tarefas) + Apendice A
#   Cap 8  - Fatorial 2^k aplicado ao aluminio        (placeholder)
#   Cap 9  - RSM/PCC aplicado                          (placeholder)
#   Cap 10 - Otimizacao global                         (placeholder)
#
# Persistencia:
#   setup/fase-5-progresso.json    - estado das tarefas
#   setup/FASE_5_ESTUDO_CASO.md    - relatorio
#
# USO:
#   .\executar-fase-5.ps1                    # Menu principal
#   .\executar-fase-5.ps1 -Cap 7             # Dashboard do Cap 7 (+ Apendice A)
#   .\executar-fase-5.ps1 -Cap 7 -Tarefa 3  # Marcar/desmarcar tarefa 3
#   .\executar-fase-5.ps1 -Cap 7 -Metricas  # So medir
#   .\executar-fase-5.ps1 -Cap 7 -Publicar  # Fluxo backup->render->preview
#   .\executar-fase-5.ps1 -Apendice         # Dashboard do Apendice A
#   .\executar-fase-5.ps1 -Status           # Visao geral da Parte III
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet(7, 8, 9, 10, 0)]
    [int]$Cap = 0,
    [ValidateRange(1, 8)]
    [int]$Tarefa = 0,
    [switch]$Apendice,
    [switch]$Metricas,
    [switch]$Publicar,
    [switch]$Preview,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup   = ".\setup"
$Script:ArqProgresso = ".\setup\fase-5-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_5_ESTUDO_CASO.md"

$Script:CapPath = @{
    7  = ".\parte-3\cap-07-projeto.qmd"
    8  = ".\parte-3\cap-08-fatorial-aluminio.qmd"
    9  = ".\parte-3\cap-09-rsm-pcc.qmd"
    10 = ".\parte-3\cap-10-otimizacao-global.qmd"
}
$Script:CapNome = @{
    7  = "Projeto experimental do estudo de caso"
    8  = "Fatorial 2^k aplicado ao aluminio"
    9  = "RSM e PCC aplicados"
    10 = "Otimizacao global"
}

# Apendice A acoplado ao Cap 7
$Script:ApendicePath = ".\apendices\apendice-a-instrumentacao.qmd"
$Script:ApendiceNome = "Instrumentacao e detalhes de medicao"

# Tarefas por capitulo
$Script:Tarefas = @{
    7  = @(
        "Reescrever caracterizacoes das ligas",
        "Reescrever configuracao dos ensaios",
        "Reescrever planejamentos (2k e PCC)",
        "Mover detalhes de instrumentacao para Apendice A"
    )
    8  = @(
        "Reescrever secao 5.2 com narrativa autoral",
        "Destacar interacoes contra-intuitivas (ponto-chave)",
        "Refazer graficos com ggplot2",
        "Validar reproduzindo a analise no codigo R atual",
        "Adicionar interpretacao industrial"
    )
    9  = @(
        "Reescrever secoes 5.3 e 5.4 (regressoes PCC + globais)",
        "Refazer curvas de nivel em ggplot2",
        "Reescrever estudo de controle do cavaco",
        "Reescrever estudo de desgastes"
    )
    10 = @(
        "Reescrever secoes 5.5 a 5.8 (globais, validacao, otimizacao)",
        "Reproduzir otimizacao com AG atualizado",
        "Apresentar Pareto-front NSGA-II como alternativa",
        "Escrever recomendacoes operacionais por liga",
        "Considerar incluir liga nova (trabalho futuro)"
    )
}

# Meta de palavras (capitulos de resultados - texto + muitas tabelas/figuras)
$Script:MetaPalavras = @{
    7  = @{ min = 3500; ideal = 5000 }
    8  = @{ min = 3500; ideal = 5000 }
    9  = @{ min = 3500; ideal = 5000 }
    10 = @{ min = 3000; ideal = 4500 }
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

    $caps = @()
    foreach ($nc in @(7, 8, 9, 10)) {
        $tarefas = @()
        $idx = 1
        foreach ($t in $Script:Tarefas[$nc]) {
            $tarefas += [PSCustomObject]@{ id = $idx; nome = $t; feito = $false }
            $idx++
        }
        $caps += [PSCustomObject]@{
            cap     = $nc
            nome    = $Script:CapNome[$nc]
            tarefas = $tarefas
        }
    }

    return [PSCustomObject]@{
        fase          = "5"
        titulo        = "Parte III - Estudo de Caso"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        capitulos     = $caps
    }
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:ArqProgresso
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

function Get-CapProgresso($progresso, $nc) {
    return $progresso.capitulos | Where-Object { $_.cap -eq $nc } | Select-Object -First 1
}

# ============================================================================
# METRICAS (enfase em TABELAS DE DADOS e FIGURAS - marca da Parte III)
# ============================================================================
function Medir-Arquivo($path, $metaMin) {
    $m = @{
        existe = $false; bytes = 0; palavras = 0; citacoes = 0
        figuras = 0; tabelas = 0; callouts = 0; blocos_cod = 0
        equacoes = 0; eh_stub = $true
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

    # Figuras
    $figMd = ([regex]::Matches($c, '!\[[^\]]*\]\(')).Count
    $figRef = ([regex]::Matches($c, '#fig-')).Count
    $m.figuras = [math]::Max($figMd, $figRef)

    # Tabelas de dados (marca dos capitulos de resultados): conta rotulos #tbl-
    $m.tabelas = ([regex]::Matches($c, '#tbl-')).Count

    $m.callouts = ([regex]::Matches($c, ':::\s*\{\.callout')).Count
    $m.blocos_cod = ([regex]::Matches($c, '```\s*\{?(r|python)[\s\}]')).Count
    $m.equacoes = ([regex]::Matches($c, '\$\$')).Count / 2

    $m.eh_stub = ($c -match 'em desenvolvimento|Stub criado') -or ($m.palavras -lt 1500)
    return $m
}

function Mostrar-Metricas($nc) {
    Write-Sec "Metricas do Cap $nc - $($Script:CapNome[$nc])"
    $meta = $Script:MetaPalavras[$nc]
    $m = Medir-Arquivo $Script:CapPath[$nc] $meta.min

    if (-not $m.existe) { Write-Err "Arquivo nao existe: $($Script:CapPath[$nc])"; return $m }

    $p = $m.palavras
    if ($p -ge $meta.ideal)     { Write-OK "Palavras: $p (meta ideal $($meta.ideal)) - ATINGIDO" }
    elseif ($p -ge $meta.min)   { Write-OK "Palavras: $p (min $($meta.min), ideal $($meta.ideal))" }
    elseif ($m.eh_stub)         { Write-Warn "Palavras: $p - ainda e STUB (meta $($meta.min)-$($meta.ideal))" }
    else                        { Write-Warn "Palavras: $p (abaixo do min $($meta.min))" }

    Write-Item "Paginas estimadas: ~$([math]::Round($p/350,1)) pp"
    Write-Host ""
    Write-Info "Riqueza de dados (marca da Parte III):"
    Write-Item "Tabelas de dados:  $($m.tabelas)"
    Write-Item "Figuras:           $($m.figuras)"
    Write-Host ""
    Write-Item "Citacoes:  $($m.citacoes) | Equacoes: $($m.equacoes) | Codigo: $($m.blocos_cod) | Callouts: $($m.callouts)"
    return $m
}

# ============================================================================
# DASHBOARD DO APENDICE A (acoplado ao Cap 7)
# ============================================================================
function Mostrar-Apendice {
    Write-Titulo "APENDICE A - $($Script:ApendiceNome)"
    Write-Info "Acoplado ao Cap 7: a instrumentacao 'movida' do Cap 7 vem para ca."
    Write-Host ""

    $m = Medir-Arquivo $Script:ApendicePath 1500
    if (-not $m.existe) {
        Write-Err "Apendice A nao encontrado: $($Script:ApendicePath)"
        return
    }

    if ($m.eh_stub) {
        Write-Warn "Apendice A ainda e STUB ($($m.palavras) palavras)"
    } else {
        Write-OK "Apendice A escrito ($($m.palavras) palavras)"
    }
    Write-Item "Tabelas: $($m.tabelas) | Figuras: $($m.figuras) | Citacoes: $($m.citacoes)"
    Write-Host ""
    Write-Info "Conteudo esperado (movido do Cap 7):"
    Write-Item "- Medicao de forcas, vibracao e potencia (dinamometro, condicionadores)"
    Write-Item "- Medicao de temperatura de corte (termopar)"
    Write-Item "- Medicao de rugosidade (rugosimetro, direcao de medicao)"
    Write-Item "- Especificacoes dos equipamentos e cadeia de medicao"
}

# ============================================================================
# FLUXO PUBLICAR
# ============================================================================
function Publicar-Capitulo($nc) {
    Write-Titulo "PUBLICAR Cap $nc - backup -> render -> preview"
    $path = $Script:CapPath[$nc]
    $nomeArq = Split-Path $path -Leaf
    $downloadNovo = "$env:USERPROFILE\Downloads\$nomeArq"

    Write-Sec "1. Substituir pelo novo (se houver no Downloads)"
    if (Test-Path $downloadNovo) {
        if (Test-Path $path) {
            Copy-Item $path ($path -replace '\.qmd$', '.STUB.bak') -Force
            Write-OK "Backup feito"
        }
        if (Ask-YesNo "Substituir $nomeArq pelo do Downloads?") {
            Copy-Item $downloadNovo $path -Force
            Write-OK "Substituido"
        }
    } else {
        Write-Info "Nada novo no Downloads - usando versao atual"
    }

    # Se for Cap 7, lembrar do Apendice A
    if ($nc -eq 7) {
        $apNome = Split-Path $Script:ApendicePath -Leaf
        $apDown = "$env:USERPROFILE\Downloads\$apNome"
        if (Test-Path $apDown) {
            Write-Info "Apendice A novo encontrado no Downloads"
            if (Test-Path $Script:ApendicePath) {
                Copy-Item $Script:ApendicePath ($Script:ApendicePath -replace '\.qmd$', '.STUB.bak') -Force
            }
            if (Ask-YesNo "Substituir tambem o Apendice A?") {
                Copy-Item $apDown $Script:ApendicePath -Force
                Write-OK "Apendice A substituido"
            }
        }
    }

    Write-Sec "2. Dropbox"
    if (-not (Ask-YesNo "Dropbox esta pausado?" "N")) {
        Write-Warn "Pause o Dropbox e rode novamente"
        return
    }

    Write-Sec "3. Limpar cache"
    Get-Process | Where-Object { $_.ProcessName -match 'quarto|deno' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item ".\_book", ".\.quarto", ".\_freeze" -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Cache limpo"

    Write-Sec "4. Renderizar"
    Write-Item "  a) Preview HTML do Cap $nc"
    Write-Item "  b) Render HTML do livro todo"
    $op = Read-Host "Escolha (a/b) [a]"
    if ([string]::IsNullOrWhiteSpace($op)) { $op = "a" }
    switch ($op) {
        "a" { & quarto preview $path --to html }
        "b" { & quarto render --to html }
    }
}

# ============================================================================
# TOGGLE TAREFA
# ============================================================================
function Toggle-Tarefa($progresso, $nc, $nt) {
    $cap = Get-CapProgresso $progresso $nc
    if (-not $cap) { Write-Err "Cap $nc nao existe"; return }
    $tarefa = $cap.tarefas | Where-Object { $_.id -eq $nt } | Select-Object -First 1
    if (-not $tarefa) { Write-Err "Tarefa $nt nao existe no Cap $nc"; return }
    $tarefa.feito = -not $tarefa.feito
    Write-OK "Cap $nc tarefa $nt -> $(if ($tarefa.feito) { 'FEITO' } else { 'pendente' })"
    Write-Item $tarefa.nome
    Save-Progresso $progresso
}

# ============================================================================
# DASHBOARD DE UM CAPITULO
# ============================================================================
function Dashboard-Cap($progresso, $nc) {
    Write-Titulo "CAP $nc - $($Script:CapNome[$nc])"
    $cap = Get-CapProgresso $progresso $nc

    Write-Sec "Tarefas de escrita"
    $feitas = 0
    foreach ($t in $cap.tarefas) {
        $box = if ($t.feito) { "[x]" } else { "[ ]" }
        $cor = if ($t.feito) { "Green" } else { "Gray" }
        if ($t.feito) { $feitas++ }
        Write-Host "  $box $($t.id). $($t.nome)" -ForegroundColor $cor
    }
    Write-Host ""
    Write-Info "Tarefas: $feitas/$($cap.tarefas.Count) concluidas"

    Mostrar-Metricas $nc | Out-Null

    # Cap 7: mostrar tambem o Apendice A acoplado
    if ($nc -eq 7) {
        Write-Host ""
        Write-Info "APENDICE A acoplado (instrumentacao):"
        $ma = Medir-Arquivo $Script:ApendicePath 1500
        if ($ma.existe) {
            $st = if ($ma.eh_stub) { "STUB" } else { "$($ma.palavras)p" }
            Write-Item "apendice-a-instrumentacao.qmd: $st (tabelas: $($ma.tabelas), figuras: $($ma.figuras))"
        } else {
            Write-Item "apendice-a-instrumentacao.qmd: ausente"
        }
    }

    Write-Sec "Proximo passo"
    $m = Medir-Arquivo $Script:CapPath[$nc] $Script:MetaPalavras[$nc].min
    if ($m.eh_stub) {
        Write-Item "Capitulo ainda e stub. Trabalho de ESCRITA (voce + Claude):"
        foreach ($t in $cap.tarefas | Where-Object { -not $_.feito }) {
            Write-Item "  -> $($t.nome)"
        }
    } else {
        Write-Item "Capitulo tem conteudo."
        if ($m.tabelas -eq 0) {
            Write-Warn "Nenhuma tabela - capitulo de resultados geralmente tem tabelas de dados"
        }
    }
}

# ============================================================================
# STATUS GERAL
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 5 - PARTE III: ESTUDO DE CASO"

    foreach ($nc in @(7, 8, 9, 10)) {
        $cap = Get-CapProgresso $progresso $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count
        $total = $cap.tarefas.Count
        $m = Medir-Arquivo $Script:CapPath[$nc] $Script:MetaPalavras[$nc].min

        $ind = if ($feitas -eq $total -and -not $m.eh_stub) { "[OK]" }
               elseif ($feitas -gt 0 -or -not $m.eh_stub) { "[..]" }
               else { "[  ]" }
        $cor = if ($feitas -eq $total -and -not $m.eh_stub) { "Green" }
               elseif ($feitas -gt 0 -or -not $m.eh_stub) { "Cyan" }
               else { "Gray" }

        $extra = if (-not $m.eh_stub) { " | tab:$($m.tabelas) fig:$($m.figuras)" } else { "" }
        $stub = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p$extra" }
        $linha = "  {0} Cap {1,-2} - {2,-38} {3}/{4}, {5}" -f $ind, $nc, $Script:CapNome[$nc], $feitas, $total, $stub
        Write-Host $linha -ForegroundColor $cor
    }

    # Linha do Apendice A
    Write-Host ""
    $ma = Medir-Arquivo $Script:ApendicePath 1500
    $stA = if (-not $ma.existe) { "ausente" } elseif ($ma.eh_stub) { "STUB" } else { "$($ma.palavras)p" }
    $corA = if ($ma.existe -and -not $ma.eh_stub) { "Green" } else { "Gray" }
    Write-Host ("  [Ap] Apendice A (instrumentacao, acoplado ao Cap 7)   $stA") -ForegroundColor $corA

    Write-Host ""
    Write-Info "Pre-requisito: Partes I e II (Fases 3 e 4) escritas"
    Write-Host ""
    Write-Info "Detalhar: .\executar-fase-5.ps1 -Cap 7"
    Write-Info "Apendice: .\executar-fase-5.ps1 -Apendice"
    Write-Info "Metricas: .\executar-fase-5.ps1 -Cap 7 -Metricas"
    Write-Info "Publicar: .\executar-fase-5.ps1 -Cap 7 -Publicar"
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 5 - Parte III: Estudo de Caso`n`n"
    $md += "Gerado por executar-fase-5.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n---`n`n"

    foreach ($nc in @(7, 8, 9, 10)) {
        $cap = Get-CapProgresso $progresso $nc
        $m = Medir-Arquivo $Script:CapPath[$nc] $Script:MetaPalavras[$nc].min
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count

        $md += "## Cap $nc - $($Script:CapNome[$nc])`n`n"
        $md += "- Tarefas: $feitas/$($cap.tarefas.Count)`n"
        $md += "- Palavras: $($m.palavras) (~$([math]::Round($m.palavras/350,1)) pp)`n"
        $md += "- Tabelas de dados: $($m.tabelas) | Figuras: $($m.figuras)`n"
        $md += "- Citacoes: $($m.citacoes) | Codigo: $($m.blocos_cod) | Equacoes: $($m.equacoes)`n"
        $md += "- Status: $(if ($m.eh_stub) { 'STUB' } else { 'Em desenvolvimento' })`n`n"
        foreach ($t in $cap.tarefas) {
            $box = if ($t.feito) { "[x]" } else { "[ ]" }
            $md += "  - $box $($t.nome)`n"
        }
        $md += "`n"
    }

    # Apendice A
    $ma = Medir-Arquivo $Script:ApendicePath 1500
    $md += "---`n`n## Apendice A - Instrumentacao (acoplado ao Cap 7)`n`n"
    $md += "- Status: $(if (-not $ma.existe) { 'ausente' } elseif ($ma.eh_stub) { 'STUB' } else { 'escrito' })`n"
    $md += "- Palavras: $($ma.palavras) | Tabelas: $($ma.tabelas) | Figuras: $($ma.figuras)`n"

    $path = Join-Path (Get-Location) $Script:ArqDoc
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# MENU
# ============================================================================
function Show-Menu($progresso) {
    Write-Titulo "FASE 5 - PARTE III: ESTUDO DE CASO"
    foreach ($nc in @(7, 8, 9, 10)) {
        $cap = Get-CapProgresso $progresso $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count
        $m = Medir-Arquivo $Script:CapPath[$nc] $Script:MetaPalavras[$nc].min
        $stub = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p" }
        Write-Host "  Cap $nc - $($Script:CapNome[$nc]) ($feitas/$($cap.tarefas.Count), $stub)"
    }
    Write-Host ""
    Write-Host "  1) Dashboard Cap 7 (Projeto experimental) + Apendice A"
    Write-Host "  2) Dashboard Cap 8 (Fatorial aplicado)"
    Write-Host "  3) Dashboard Cap 9 (RSM/PCC aplicado)"
    Write-Host "  4) Dashboard Cap 10 (Otimizacao global)"
    Write-Host "  5) Dashboard Apendice A (instrumentacao)"
    Write-Host "  6) Publicar Cap 7"
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
    if (Ask-YesNo "Apagar progresso da Fase 5?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($Apendice) {
    Mostrar-Apendice
    exit 0
}

if ($Status) {
    Mostrar-Status $progresso
    Update-Doc $progresso
    exit 0
}

if ($Cap -ne 0) {
    if ($Metricas) { Mostrar-Metricas $Cap | Out-Null; exit 0 }
    if ($Publicar) { Publicar-Capitulo $Cap; exit 0 }
    if ($Preview)  { Publicar-Capitulo $Cap; exit 0 }
    if ($Tarefa -ne 0) {
        Toggle-Tarefa $progresso $Cap $Tarefa
        Update-Doc $progresso
        exit 0
    }
    Dashboard-Cap $progresso $Cap
    Update-Doc $progresso
    exit 0
}

$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Dashboard-Cap $progresso 7 }
        "2" { Dashboard-Cap $progresso 8 }
        "3" { Dashboard-Cap $progresso 9 }
        "4" { Dashboard-Cap $progresso 10 }
        "5" { Mostrar-Apendice }
        "6" { Publicar-Capitulo 7 }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-5.ps1 -Status"
