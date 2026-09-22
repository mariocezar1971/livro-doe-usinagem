# ============================================================================
# executar-fase-4.ps1
#
# Orquestrador da Fase 4 - Parte II: Metodologia DOE (Cap 4, 5, 6)
#
# ATENCAO - o que este script FAZ e o que NAO faz:
#   FAZ: rastreia tarefas de escrita, mede progresso mecanico (palavras,
#        citacoes, blocos de codigo R/Python, figuras, exercicios), e
#        automatiza o fluxo backup->substituir->render->preview.
#   NAO FAZ: escrever os capitulos. O texto e trabalho de autoria.
#
# Diferenca da Fase 3: estes capitulos tem CODIGO R e Python. O script
# conta blocos de codigo executavel alem das metricas usuais.
#
# Sub-fases:
#   Cap 4 - Fatorial 2^k                    (8 tarefas)
#   Cap 5 - PCC e Superficies de Resposta   (7 tarefas)
#   Cap 6 - Otimizacao multiresposta        (6 tarefas)
#
# Persistencia:
#   setup/fase-4-progresso.json    - estado das tarefas
#   setup/FASE_4_METODOLOGIA.md    - relatorio
#
# USO:
#   .\executar-fase-4.ps1                    # Menu principal
#   .\executar-fase-4.ps1 -Cap 4             # Dashboard do Cap 4
#   .\executar-fase-4.ps1 -Cap 4 -Tarefa 3  # Marcar/desmarcar tarefa 3
#   .\executar-fase-4.ps1 -Cap 4 -Metricas  # So medir palavras/codigo/exercicios
#   .\executar-fase-4.ps1 -Cap 4 -Publicar  # Fluxo backup->render->preview
#   .\executar-fase-4.ps1 -Status           # Visao geral dos 3 capitulos
#   .\executar-fase-4.ps1 -Divulgacao       # Checklist de divulgacao mes 4-7
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet(4, 5, 6, 0)]
    [int]$Cap = 0,
    [ValidateRange(1, 8)]
    [int]$Tarefa = 0,
    [switch]$Metricas,
    [switch]$Publicar,
    [switch]$Preview,
    [switch]$Divulgacao,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup   = ".\setup"
$Script:ArqProgresso = ".\setup\fase-4-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_4_METODOLOGIA.md"

$Script:CapPath = @{
    4 = ".\parte-2\cap-04-fatorial.qmd"
    5 = ".\parte-2\cap-05-pcc-rsm.qmd"
    6 = ".\parte-2\cap-06-otimizacao.qmd"
}
$Script:CapNome = @{
    4 = "Fatorial 2^k"
    5 = "PCC e Superficies de Resposta"
    6 = "Otimizacao multiresposta"
}

# Tarefas por capitulo
$Script:Tarefas = @{
    4 = @(
        "Escrever fundamentacao matematica",
        "Escrever matrizes 2^k, replicacao, aleatorizacao",
        "Escrever estimativa de efeitos e interacoes",
        "Escrever ANOVA fatorial interpretada",
        "Escrever analise de residuos",
        "Criar exemplo resolvido didatico",
        "Implementar codigo R (FrF2/pid)",
        "Criar 8-10 exercicios com gabarito"
    )
    5 = @(
        "Escrever limitacoes do fatorial puro",
        "Escrever construcao do PCC",
        "Escrever regressao multipla com quadraticos",
        "Escrever RSM e vetor gradiente",
        "Criar exemplo com pacote rsm",
        "Criar visualizacoes 3D (rgl/plotly)",
        "Criar 6-8 exercicios com gabarito"
    )
    6 = @(
        "Escrever desejabilidade Derringer-Suich",
        "Escrever comparacao desejabilidade x AG x NSGA-II",
        "Adaptar framework Funcoes_Regressao Python",
        "Criar exemplo com pymoo (Python)",
        "Criar exemplo com desirability (R)",
        "Criar 5-6 exercicios com gabarito"
    )
}

# Meta de palavras por capitulo (capitulos metodologicos - densos, com codigo)
$Script:MetaPalavras = @{
    4 = @{ min = 5000; ideal = 7000 }   # fatorial - o mais longo
    5 = @{ min = 4500; ideal = 6000 }
    6 = @{ min = 4000; ideal = 5500 }
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
    foreach ($nc in @(4, 5, 6)) {
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
        fase          = "4"
        titulo        = "Parte II - Metodologia DOE"
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
# METRICAS MECANICAS (inclui blocos de codigo R/Python)
# ============================================================================
function Medir-Capitulo($nc) {
    $path = $Script:CapPath[$nc]
    $metricas = @{
        existe        = $false
        bytes         = 0
        palavras      = 0
        citacoes      = 0
        figuras       = 0
        quadros       = 0
        callouts      = 0
        blocos_r      = 0
        blocos_python = 0
        exercicios    = 0
        equacoes      = 0
        eh_stub       = $true
    }

    if (-not (Test-Path $path)) { return $metricas }

    $metricas.existe = $true
    $conteudo = Get-Content $path -Raw -Encoding UTF8
    $metricas.bytes = (Get-Item $path).Length

    # Palavras (remove YAML e sintaxe)
    $corpo = $conteudo -replace '(?s)^---.*?---', ''
    $corpoTxt = $corpo -replace '(?s)```.*?```', ' '   # remove blocos de codigo da contagem de palavras
    $corpoTxt = $corpoTxt -replace '[#>*`:\[\]{}|-]', ' '
    $palavras = ($corpoTxt -split '\s+' | Where-Object { $_ -match '\w' }).Count
    $metricas.palavras = $palavras

    # Citacoes
    $metricas.citacoes = ([regex]::Matches($conteudo, '@[a-zA-Z][a-zA-Z0-9_]+')).Count

    # Figuras
    $figMd = ([regex]::Matches($conteudo, '!\[[^\]]*\]\(')).Count
    $figRef = ([regex]::Matches($conteudo, '#fig-')).Count
    $metricas.figuras = [math]::Max($figMd, $figRef)

    # Quadros (tabelas)
    $linhasTabela = ([regex]::Matches($conteudo, '(?m)^\s*\|.*\|\s*$')).Count
    $metricas.quadros = [math]::Floor($linhasTabela / 3)

    # Callouts
    $metricas.callouts = ([regex]::Matches($conteudo, ':::\s*\{\.callout')).Count

    # Blocos de codigo R (```{r} ou ```r)
    $metricas.blocos_r = ([regex]::Matches($conteudo, '```\s*\{?r[\s\}]')).Count

    # Blocos de codigo Python (```{python} ou ```python)
    $metricas.blocos_python = ([regex]::Matches($conteudo, '```\s*\{?python[\s\}]')).Count

    # Exercicios (linhas numeradas apos "Exercicios propostos")
    if ($conteudo -match '(?s)Exerc.cios propostos(.*)$') {
        $secExerc = $Matches[1]
        $metricas.exercicios = ([regex]::Matches($secExerc, '(?m)^\s*\d+\.\s+\*\*')).Count
        if ($metricas.exercicios -eq 0) {
            $metricas.exercicios = ([regex]::Matches($secExerc, '(?m)^\s*\d+\.\s')).Count
        }
    }

    # Equacoes (blocos $$ ou inline display)
    $metricas.equacoes = ([regex]::Matches($conteudo, '\$\$')).Count / 2

    # Eh stub?
    $metricas.eh_stub = ($conteudo -match 'em desenvolvimento|Stub criado') -or ($palavras -lt 1500)

    return $metricas
}

function Mostrar-Metricas($nc) {
    Write-Sec "Metricas do Cap $nc - $($Script:CapNome[$nc])"

    $m = Medir-Capitulo $nc

    if (-not $m.existe) {
        Write-Err "Arquivo nao existe: $($Script:CapPath[$nc])"
        return $m
    }

    $meta = $Script:MetaPalavras[$nc]
    $palavras = $m.palavras

    if ($palavras -ge $meta.ideal) {
        Write-OK "Palavras: $palavras (meta ideal: $($meta.ideal)) - ATINGIDO"
    } elseif ($palavras -ge $meta.min) {
        Write-OK "Palavras: $palavras (min: $($meta.min), ideal: $($meta.ideal))"
    } elseif ($m.eh_stub) {
        Write-Warn "Palavras: $palavras - ainda e STUB (meta: $($meta.min)-$($meta.ideal))"
    } else {
        Write-Warn "Palavras: $palavras (abaixo do min $($meta.min))"
    }

    $paginas = [math]::Round($palavras / 350, 1)
    Write-Item "Paginas estimadas: ~$paginas pp"

    Write-Host ""
    Write-Item "Citacoes (@chave):   $($m.citacoes)"
    Write-Item "Equacoes (blocos):   $($m.equacoes)"
    Write-Item "Figuras:             $($m.figuras)"
    Write-Item "Quadros/tabelas:     ~$($m.quadros)"
    Write-Item "Callouts:            $($m.callouts)"
    Write-Host ""
    Write-Info "Codigo executavel (marca da Parte II):"
    Write-Item "Blocos R:            $($m.blocos_r)"
    Write-Item "Blocos Python:       $($m.blocos_python)"
    Write-Item "Exercicios:          $($m.exercicios)"

    return $m
}

# ============================================================================
# FLUXO PUBLICAR
# ============================================================================
function Publicar-Capitulo($nc) {
    Write-Titulo "PUBLICAR Cap $nc - fluxo backup -> render -> preview"

    $path = $Script:CapPath[$nc]
    $nomeArq = Split-Path $path -Leaf
    $downloadNovo = "$env:USERPROFILE\Downloads\$nomeArq"

    Write-Sec "1. Substituir pelo novo (se houver no Downloads)"
    if (Test-Path $downloadNovo) {
        Write-Info "Encontrado no Downloads: $downloadNovo"
        if (Test-Path $path) {
            $backup = $path -replace '\.qmd$', '.STUB.bak'
            Copy-Item $path $backup -Force
            Write-OK "Backup: $backup"
        }
        if (Ask-YesNo "Substituir $nomeArq pelo do Downloads?") {
            Copy-Item $downloadNovo $path -Force
            Write-OK "Substituido"
        }
    } else {
        Write-Info "Nada novo no Downloads - usando versao atual do repo"
    }

    Write-Sec "2. Dropbox (bug os error 32)"
    Write-Warn "CONFIRME que o Dropbox esta PAUSADO antes de renderizar"
    if (-not (Ask-YesNo "Dropbox esta pausado?" "N")) {
        Write-Warn "Pause o Dropbox e rode novamente com -Publicar"
        return
    }

    Write-Sec "3. Limpar cache de build"
    Get-Process | Where-Object { $_.ProcessName -match 'quarto|deno' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item ".\_book" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item ".\.quarto" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item ".\_freeze" -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Cache limpo"

    Write-Sec "4. Renderizar"
    Write-Info "NOTA: capitulos da Parte II tem codigo R/Python."
    Write-Item "O preview executa o codigo - pode demorar mais que capitulos de texto."
    Write-Host ""
    Write-Item "  a) Preview HTML do Cap $nc (executa codigo, hot-reload)"
    Write-Item "  b) Render HTML do livro todo"
    Write-Item "  c) Render completo (HTML+PDF+EPUB, lento)"
    $op = Read-Host "Escolha (a/b/c) [a]"
    if ([string]::IsNullOrWhiteSpace($op)) { $op = "a" }

    switch ($op) {
        "a" { & quarto preview $path --to html }
        "b" { & quarto render --to html }
        "c" { & quarto render }
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
    $estado = if ($tarefa.feito) { "FEITO" } else { "pendente" }
    Write-OK "Cap $nc tarefa $nt -> $estado"
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

    Write-Sec "Proximo passo sugerido"
    $m = Medir-Capitulo $nc
    if ($m.eh_stub) {
        Write-Item "Capitulo ainda e stub. Trabalho de ESCRITA (voce + Claude):"
        foreach ($t in $cap.tarefas | Where-Object { -not $_.feito }) {
            Write-Item "  -> $($t.nome)"
        }
        Write-Host ""
        Write-Item "Quando tiver o texto pronto, use: -Publicar"
    } else {
        Write-Item "Capitulo tem conteudo."
        if ($m.blocos_r -eq 0 -and $m.blocos_python -eq 0) {
            Write-Warn "Nenhum bloco de codigo detectado - Parte II precisa de codigo R/Python"
        }
    }
}

# ============================================================================
# STATUS GERAL
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 4 - PARTE II: METODOLOGIA DOE"

    foreach ($nc in @(4, 5, 6)) {
        $cap = Get-CapProgresso $progresso $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count
        $total = $cap.tarefas.Count
        $m = Medir-Capitulo $nc

        $indicador = if ($feitas -eq $total -and -not $m.eh_stub) { "[OK]" }
                     elseif ($feitas -gt 0 -or -not $m.eh_stub) { "[..]" }
                     else { "[  ]" }
        $cor = if ($feitas -eq $total -and -not $m.eh_stub) { "Green" }
               elseif ($feitas -gt 0 -or -not $m.eh_stub) { "Cyan" }
               else { "Gray" }

        $codigo = ""
        if (-not $m.eh_stub) {
            $codigo = " | R:$($m.blocos_r) Py:$($m.blocos_python)"
        }
        $stubTxt = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p$codigo" }
        $linha = "  {0} Cap {1} - {2,-32} {3}/{4} tarefas, {5}" -f $indicador, $nc, $Script:CapNome[$nc], $feitas, $total, $stubTxt
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Pre-requisito: Parte I (Fase 3) escrita"
    Write-Host ""
    Write-Info "Detalhar: .\executar-fase-4.ps1 -Cap 4"
    Write-Info "Metricas: .\executar-fase-4.ps1 -Cap 4 -Metricas"
    Write-Info "Publicar: .\executar-fase-4.ps1 -Cap 4 -Publicar"
    Write-Info "Divulgacao mes 4-7: .\executar-fase-4.ps1 -Divulgacao"
}

# ============================================================================
# DIVULGACAO MES 4-7
# ============================================================================
function Mostrar-Divulgacao {
    Write-Titulo "DIVULGACAO PARALELA - MES 4-7"

    Write-Info "Acoes de marketing durante a escrita da Parte II:"
    Write-Host ""
    Write-Item "[ ] Posts LinkedIn com casos resolvidos de DOE"
    Write-Item "[ ] Email mensal para a lista com previews"
    Write-Item "[ ] Monitorar Google Search Console (primeiros rankings)"
    Write-Item "[ ] Meta de captura: 500 emails na lista"
    Write-Host ""
    Write-Info "Ferramentas relacionadas:"
    Write-Item "Search Console: .\executar-fase-1-5.ps1 (monitoramento semanal)"
    Write-Item "Metas de trafego: .\executar-fase-1-5.ps1 -Metas"
    Write-Host ""
    Write-Info "Meta da lista Brevo evolui de 200 (Parte I) para 500 (Parte II)"
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 4 - Parte II: Metodologia DOE`n`n"
    $md += "Gerado por executar-fase-4.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n---`n`n"

    foreach ($nc in @(4, 5, 6)) {
        $cap = Get-CapProgresso $progresso $nc
        $m = Medir-Capitulo $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count

        $md += "## Cap $nc - $($Script:CapNome[$nc])`n`n"
        $md += "- Tarefas: $feitas/$($cap.tarefas.Count)`n"
        $md += "- Palavras: $($m.palavras) (~$([math]::Round($m.palavras/350,1)) pp)`n"
        $md += "- Codigo: R=$($m.blocos_r), Python=$($m.blocos_python)`n"
        $md += "- Citacoes: $($m.citacoes) | Figuras: $($m.figuras) | Quadros: ~$($m.quadros) | Equacoes: $($m.equacoes)`n"
        $md += "- Exercicios: $($m.exercicios)`n"
        $md += "- Status: $(if ($m.eh_stub) { 'STUB' } else { 'Em desenvolvimento' })`n`n"

        foreach ($t in $cap.tarefas) {
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
    Write-Titulo "FASE 4 - PARTE II: METODOLOGIA DOE"
    foreach ($nc in @(4, 5, 6)) {
        $cap = Get-CapProgresso $progresso $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count
        $m = Medir-Capitulo $nc
        $stubTxt = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p" }
        Write-Host "  Cap $nc - $($Script:CapNome[$nc]) ($feitas/$($cap.tarefas.Count) tarefas, $stubTxt)"
    }
    Write-Host ""
    Write-Host "  1) Dashboard Cap 4 (Fatorial 2^k)"
    Write-Host "  2) Dashboard Cap 5 (PCC e RSM)"
    Write-Host "  3) Dashboard Cap 6 (Otimizacao multiresposta)"
    Write-Host "  4) Publicar Cap 4"
    Write-Host "  5) Publicar Cap 5"
    Write-Host "  6) Publicar Cap 6"
    Write-Host "  7) Divulgacao mes 4-7"
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
    if (Ask-YesNo "Apagar progresso da Fase 4?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($Divulgacao) {
    Mostrar-Divulgacao
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

# Menu interativo
$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Dashboard-Cap $progresso 4 }
        "2" { Dashboard-Cap $progresso 5 }
        "3" { Dashboard-Cap $progresso 6 }
        "4" { Publicar-Capitulo 4 }
        "5" { Publicar-Capitulo 5 }
        "6" { Publicar-Capitulo 6 }
        "7" { Mostrar-Divulgacao }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-4.ps1 -Status"
