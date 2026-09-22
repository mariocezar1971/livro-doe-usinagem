# ============================================================================
# executar-fase-3.ps1
#
# Orquestrador da Fase 3 - Parte I: Fundamentos (Cap 2 e Cap 3)
#
# ATENCAO - o que este script FAZ e o que NAO faz:
#   FAZ: rastreia tarefas de escrita, mede progresso mecanico (palavras,
#        citacoes, figuras, quadros), lista micrografias disponiveis, e
#        automatiza o fluxo backup->substituir->render->preview.
#   NAO FAZ: escrever o capitulo. O texto e trabalho de autoria (voce + Claude).
#
# Sub-fases:
#   Cap 1 - Por que DOE em manufatura        (4 tarefas) - CONCLUIDO (referencia)
#   Cap 2 - Metalurgia das ligas de aluminio (5 tarefas)
#   Cap 3 - Fundamentos de torneamento       (3 tarefas)
#
# Persistencia:
#   setup/fase-3-progresso.json    - estado das tarefas
#   setup/FASE_3_FUNDAMENTOS.md    - relatorio
#
# USO:
#   .\executar-fase-3.ps1                    # Menu principal
#   .\executar-fase-3.ps1 -Cap 2             # Dashboard do Cap 2
#   .\executar-fase-3.ps1 -Cap 2 -Tarefa 3  # Marcar/desmarcar tarefa 3 do Cap 2
#   .\executar-fase-3.ps1 -Cap 2 -Metricas  # So medir palavras/citacoes/figuras
#   .\executar-fase-3.ps1 -Cap 2 -Figuras   # Listar micrografias disponiveis
#   .\executar-fase-3.ps1 -Cap 2 -Publicar  # Fluxo backup->render->preview
#   .\executar-fase-3.ps1 -Status           # Visao geral das duas sub-fases
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet(1, 2, 3, 0)]
    [int]$Cap = 0,
    [ValidateRange(1, 5)]
    [int]$Tarefa = 0,
    [switch]$Metricas,
    [switch]$Figuras,
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
$Script:ArqProgresso = ".\setup\fase-3-progresso.json"
$Script:ArqDoc       = ".\setup\FASE_3_FUNDAMENTOS.md"
$Script:PastaFiguras = ".\figuras"
$Script:UrlBase      = "https://mariocezar1971.github.io/livro-doe-usinagem"

# Caminhos dos capitulos
$Script:CapPath = @{
    1 = ".\parte-1\cap-01-por-que-doe.qmd"
    2 = ".\parte-1\cap-02-metalurgia.qmd"
    3 = ".\parte-1\cap-03-torneamento.qmd"
}
$Script:CapNome = @{
    1 = "Por que DOE em manufatura"
    2 = "Metalurgia das ligas de aluminio"
    3 = "Fundamentos de torneamento"
}

# Tarefas por capitulo (do mapa mental da Fase 3)
$Script:Tarefas = @{
    1 = @(
        "Pesquisar casos industriais brasileiros",
        "Escrever introducao motivacional",
        "Escrever secao Limites do OFAT",
        "Escrever Mapa do livro"
    )
    2 = @(
        "Condensar revisao da tese (8pp -> 15-18pp didaticos)",
        "Adicionar mecanismos de endurecimento detalhados",
        "Atualizar com literatura 2012-2026",
        "Criar quadros-sintese comparativos",
        "Inserir micrografias originais ja existentes"
    )
    3 = @(
        "Condensar fundamentos da tese",
        "Reescrever Circulo de Merchant didaticamente",
        "Adicionar quadros 'Na pratica' e 'Erro comum'"
    )
}

# Meta de palavras por capitulo (15-18 pp didaticas ~ 350 palavras/pp)
$Script:MetaPalavras = @{
    1 = @{ min = 3000; ideal = 3900 }   # 10-12 pp (Cap 1 tem ~3900)
    2 = @{ min = 5000; ideal = 6300 }   # 15-18 pp
    3 = @{ min = 4000; ideal = 5250 }   # 12-15 pp
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

    # Estrutura inicial: cada cap tem lista de tarefas.
    # Cap 1 ja esta concluido (referencia), entao suas tarefas nascem feito=true.
    $caps = @()
    foreach ($nc in @(1, 2, 3)) {
        $capConcluido = ($nc -eq 1)
        $tarefas = @()
        $idx = 1
        foreach ($t in $Script:Tarefas[$nc]) {
            $tarefas += [PSCustomObject]@{ id = $idx; nome = $t; feito = $capConcluido }
            $idx++
        }
        $caps += [PSCustomObject]@{
            cap     = $nc
            nome    = $Script:CapNome[$nc]
            tarefas = $tarefas
        }
    }

    return [PSCustomObject]@{
        fase          = "3"
        titulo        = "Parte I - Fundamentos"
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
# METRICAS MECANICAS DO CAPITULO
# ============================================================================
function Medir-Capitulo($nc) {
    $path = $Script:CapPath[$nc]
    $metricas = @{
        existe     = $false
        bytes      = 0
        palavras   = 0
        citacoes   = 0
        figuras    = 0
        quadros    = 0
        callouts   = 0
        eh_stub    = $true
    }

    if (-not (Test-Path $path)) { return $metricas }

    $metricas.existe = $true
    $conteudo = Get-Content $path -Raw -Encoding UTF8
    $metricas.bytes = (Get-Item $path).Length

    # Palavras (aproximado - remove YAML header e sintaxe)
    $corpo = $conteudo -replace '(?s)^---.*?---', ''      # remove YAML
    $corpo = $corpo -replace '[#>*`:\[\]{}|-]', ' '        # remove sintaxe md
    $palavras = ($corpo -split '\s+' | Where-Object { $_ -match '\w' }).Count
    $metricas.palavras = $palavras

    # Citacoes @chave
    $metricas.citacoes = ([regex]::Matches($conteudo, '@[a-zA-Z][a-zA-Z0-9_]+')).Count

    # Figuras: ![...](...) OU ::: {#fig- OU @fig-
    $figMd = ([regex]::Matches($conteudo, '!\[[^\]]*\]\(')).Count
    $figRef = ([regex]::Matches($conteudo, '#fig-')).Count
    $metricas.figuras = [math]::Max($figMd, $figRef)

    # Quadros-sintese: tabelas markdown (linhas com | ... |) OU divs de tabela
    $linhasTabela = ([regex]::Matches($conteudo, '(?m)^\s*\|.*\|\s*$')).Count
    $metricas.quadros = [math]::Floor($linhasTabela / 3)  # ~3 linhas por tabela minima

    # Callouts
    $metricas.callouts = ([regex]::Matches($conteudo, ':::\s*\{\.callout')).Count

    # Eh stub? (tem "em desenvolvimento" ou < 1500 palavras)
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

    # Palavras vs meta
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

    # Paginas estimadas (~350 palavras/pagina didatica)
    $paginas = [math]::Round($palavras / 350, 1)
    Write-Item "Paginas estimadas: ~$paginas pp"

    Write-Host ""
    Write-Item "Citacoes (@chave):   $($m.citacoes)"
    Write-Item "Figuras:             $($m.figuras)"
    Write-Item "Quadros/tabelas:     ~$($m.quadros)"
    Write-Item "Callouts:            $($m.callouts)"
    Write-Item "Tamanho:             $($m.bytes) bytes"

    return $m
}

# ============================================================================
# LISTAR MICROGRAFIAS / FIGURAS DISPONIVEIS
# ============================================================================
function Listar-Figuras {
    Write-Sec "Micrografias e figuras disponiveis em figuras/"

    if (-not (Test-Path $Script:PastaFiguras)) {
        Write-Warn "Pasta figuras/ nao encontrada"
        return
    }

    $exts = @("*.png", "*.jpg", "*.jpeg", "*.tif", "*.tiff", "*.svg", "*.pdf")
    $todas = @()
    foreach ($e in $exts) {
        $todas += Get-ChildItem $Script:PastaFiguras -Filter $e -Recurse -ErrorAction SilentlyContinue
    }

    if ($todas.Count -eq 0) {
        Write-Warn "Nenhuma figura encontrada em figuras/"
        return
    }

    Write-Info "Total: $($todas.Count) arquivos de imagem"
    Write-Host ""

    # Agrupar por extensao
    $porExt = $todas | Group-Object Extension | Sort-Object Count -Descending
    Write-Info "Por tipo:"
    foreach ($g in $porExt) {
        Write-Item "$($g.Name): $($g.Count)"
    }

    # Tentar identificar micrografias (nome sugestivo)
    Write-Host ""
    $micro = $todas | Where-Object { $_.Name -match 'micro|mev|sem|metalog|grao|grain|fase|precipit' }
    if ($micro.Count -gt 0) {
        Write-Info "Possiveis micrografias (por nome):"
        foreach ($f in $micro | Select-Object -First 20) {
            $rel = $f.FullName.Replace((Resolve-Path $Script:PastaFiguras).Path, "figuras").Replace('\', '/')
            Write-Item "$rel ($([math]::Round($f.Length/1KB,0)) KB)"
        }
    } else {
        Write-Info "Nenhum nome sugestivo de micrografia. Primeiras 15 figuras:"
        foreach ($f in $todas | Select-Object -First 15) {
            $rel = $f.FullName.Replace((Resolve-Path $Script:PastaFiguras).Path, "figuras").Replace('\', '/')
            Write-Item "$rel ($([math]::Round($f.Length/1KB,0)) KB)"
        }
    }

    Write-Host ""
    Write-Info "Para inserir no .qmd (sintaxe Quarto):"
    Write-Item "![Legenda da figura](figuras/nome.png){#fig-rotulo}"
    Write-Item "Referenciar no texto: @fig-rotulo"
}

# ============================================================================
# FLUXO PUBLICAR (backup -> substituir -> render -> preview)
# ============================================================================
function Publicar-Capitulo($nc) {
    Write-Titulo "PUBLICAR Cap $nc - fluxo backup -> render -> preview"

    $path = $Script:CapPath[$nc]
    $nomeArq = Split-Path $path -Leaf

    # Passo 1: verificar se ha versao nova no Downloads
    $downloadNovo = "$env:USERPROFILE\Downloads\$nomeArq"
    Write-Sec "1. Substituir pelo novo (se houver no Downloads)"

    if (Test-Path $downloadNovo) {
        Write-Info "Encontrado no Downloads: $downloadNovo"

        # Backup do atual
        if (Test-Path $path) {
            $backup = $path -replace '\.qmd$', '.STUB.bak'
            Write-Info "Backup do atual -> $backup"
            Copy-Item $path $backup -Force
            Write-OK "Backup criado"
        }

        if (Ask-YesNo "Substituir $nomeArq pelo do Downloads?") {
            Copy-Item $downloadNovo $path -Force
            Write-OK "Substituido"
        }
    } else {
        Write-Info "Nada novo no Downloads - usando versao atual do repo"
    }

    # Passo 2: pausar Dropbox (lembrete)
    Write-Sec "2. Dropbox (bug conhecido os error 32)"
    Write-Warn "CONFIRME que o Dropbox esta PAUSADO antes de renderizar"
    Write-Item "Bandeja > Dropbox > Pausar sincronizacao > 3 horas"
    if (-not (Ask-YesNo "Dropbox esta pausado?" "N")) {
        Write-Warn "Pause o Dropbox e rode novamente com -Publicar"
        return
    }

    # Passo 3: limpar cache
    Write-Sec "3. Limpar cache de build"
    Get-Process | Where-Object { $_.ProcessName -match 'quarto|deno' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item ".\_book" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item ".\.quarto" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item ".\_freeze" -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Cache limpo (_book, .quarto, _freeze)"

    # Passo 4: render ou preview
    Write-Sec "4. Renderizar"
    Write-Info "Opcoes:"
    Write-Item "  a) Preview HTML do Cap $nc (rapido, hot-reload)"
    Write-Item "  b) Render HTML do livro todo"
    Write-Item "  c) Render completo (HTML+PDF+EPUB, lento)"
    $op = Read-Host "Escolha (a/b/c) [a]"
    if ([string]::IsNullOrWhiteSpace($op)) { $op = "a" }

    switch ($op) {
        "a" {
            Write-Info "Rodando: quarto preview $path --to html"
            & quarto preview $path --to html
        }
        "b" {
            Write-Info "Rodando: quarto render --to html"
            & quarto render --to html
        }
        "c" {
            Write-Info "Rodando: quarto render (todos formatos)"
            & quarto render
        }
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

    # Tarefas
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

    # Metricas
    Mostrar-Metricas $nc | Out-Null

    # Dica de proximo passo
    Write-Sec "Proximo passo sugerido"
    $m = Medir-Capitulo $nc
    if ($m.eh_stub) {
        Write-Item "Capitulo ainda e stub. Trabalho de ESCRITA (voce + Claude):"
        foreach ($t in $cap.tarefas | Where-Object { -not $_.feito }) {
            Write-Item "  -> $($t.nome)"
        }
        Write-Host ""
        Write-Item "Quando tiver o texto pronto, use: -Publicar para render+preview"
    } else {
        Write-Item "Capitulo tem conteudo. Verificar tarefas pendentes e metricas."
    }
}

# ============================================================================
# STATUS GERAL
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "FASE 3 - PARTE I: FUNDAMENTOS"

    foreach ($nc in @(1, 2, 3)) {
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

        $stubTxt = if ($m.eh_stub) { "STUB" } else { "$($m.palavras) palavras" }
        $linha = "  {0} Cap {1} - {2,-38} {3}/{4} tarefas, {5}" -f $indicador, $nc, $Script:CapNome[$nc], $feitas, $total, $stubTxt
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Cap 1 exibido como referencia (concluido em fase anterior)"
    Write-Host ""
    Write-Info "Detalhar: .\executar-fase-3.ps1 -Cap 2"
    Write-Info "Metricas: .\executar-fase-3.ps1 -Cap 2 -Metricas"
    Write-Info "Figuras:  .\executar-fase-3.ps1 -Cap 2 -Figuras"
    Write-Info "Publicar: .\executar-fase-3.ps1 -Cap 2 -Publicar"
}

# ============================================================================
# GERAR DOC
# ============================================================================
function Update-Doc($progresso) {
    $md = "# Fase 3 - Parte I: Fundamentos`n`n"
    $md += "Gerado por executar-fase-3.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n---`n`n"

    foreach ($nc in @(1, 2, 3)) {
        $cap = Get-CapProgresso $progresso $nc
        $m = Medir-Capitulo $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count

        $md += "## Cap $nc - $($Script:CapNome[$nc])`n`n"
        $md += "- Tarefas: $feitas/$($cap.tarefas.Count)`n"
        $md += "- Palavras: $($m.palavras) (~$([math]::Round($m.palavras/350,1)) pp)`n"
        $md += "- Citacoes: $($m.citacoes) | Figuras: $($m.figuras) | Quadros: ~$($m.quadros) | Callouts: $($m.callouts)`n"
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
    Write-Titulo "FASE 3 - PARTE I: FUNDAMENTOS"
    foreach ($nc in @(1, 2, 3)) {
        $cap = Get-CapProgresso $progresso $nc
        $feitas = @($cap.tarefas | Where-Object { $_.feito }).Count
        $m = Medir-Capitulo $nc
        $stubTxt = if ($m.eh_stub) { "STUB" } else { "$($m.palavras)p" }
        Write-Host "  Cap $nc - $($Script:CapNome[$nc]) ($feitas/$($cap.tarefas.Count) tarefas, $stubTxt)"
    }
    Write-Host ""
    Write-Host "  1) Dashboard Cap 1 (Por que DOE - referencia)"
    Write-Host "  2) Dashboard Cap 2 (Metalurgia)"
    Write-Host "  3) Dashboard Cap 3 (Torneamento)"
    Write-Host "  4) Listar micrografias/figuras"
    Write-Host "  5) Publicar Cap 2 (backup->render->preview)"
    Write-Host "  6) Publicar Cap 3"
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
    if (Ask-YesNo "Apagar progresso da Fase 3?" "N") {
        Remove-Item $Script:ArqProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArqDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

# Status geral
if ($Status) {
    Mostrar-Status $progresso
    Update-Doc $progresso
    exit 0
}

# Acoes com -Cap
if ($Cap -ne 0) {
    if ($Figuras)  { Listar-Figuras; exit 0 }
    if ($Metricas) { Mostrar-Metricas $Cap | Out-Null; exit 0 }
    if ($Publicar) { Publicar-Capitulo $Cap; exit 0 }
    if ($Preview)  { Publicar-Capitulo $Cap; exit 0 }
    if ($Tarefa -ne 0) {
        Toggle-Tarefa $progresso $Cap $Tarefa
        Update-Doc $progresso
        exit 0
    }
    # Sem sub-acao: dashboard do capitulo
    Dashboard-Cap $progresso $Cap
    Update-Doc $progresso
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $op = Show-Menu $progresso
    switch ($op) {
        "1" { Dashboard-Cap $progresso 1 }
        "2" { Dashboard-Cap $progresso 2 }
        "3" { Dashboard-Cap $progresso 3 }
        "4" { Listar-Figuras }
        "5" { Publicar-Capitulo 2 }
        "6" { Publicar-Capitulo 3 }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Update-Doc $progresso
Write-Host ""
Write-OK "Encerrando. Progresso em $Script:ArqProgresso"
Write-Info "Retomar: .\executar-fase-3.ps1 -Status"
