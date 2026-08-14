# ============================================================================
# executar-fase-0.ps1
#
# META ORQUESTRADOR da Fase 0 - Decisoes e Setup Tecnico
#
# Coordena as 4 sub-fases:
#   0.1 Decisoes editoriais fundadoras   (delegado para executar-fase-0-1.ps1)
#   0.2 Setup ambiente de producao       (delegado para executar-fase-0-2.ps1)
#   0.3 Setup hospedagem web             (inline - GitHub + dominio + SSL)
#   0.4 Gestao de referencias            (inline - Zotero/JabRef + .bib + CSL)
#
# COMPORTAMENTO:
#   - Se script individual existe (0-1, 0-2), delega para ele
#   - Se nao existe, oferece implementacao inline simplificada
#   - Dashboard consolidado le JSONs de todas as sub-fases
#
# Persistencia:
#   setup/fase-0-progresso.json          - meta estado
#   setup/fase-0-3-progresso.json        - hospedagem (inline)
#   setup/fase-0-4-progresso.json        - referencias (inline)
#   setup/FASE_0_STATUS.md               - dashboard consolidado
#
# USO:
#   .\executar-fase-0.ps1                # Menu principal
#   .\executar-fase-0.ps1 -Subfase "0.3" # Direto para uma sub-fase
#   .\executar-fase-0.ps1 -Status        # Dashboard consolidado
#   .\executar-fase-0.ps1 -Reset         # Zerar meta estado (nao apaga sub-fases)
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet("0.1", "0.2", "0.3", "0.4", "")]
    [string]$Subfase = "",
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup       = ".\setup"
$Script:ArquivoProgresso = ".\setup\fase-0-progresso.json"
$Script:ArquivoDoc       = ".\setup\FASE_0_STATUS.md"

# Scripts individuais das sub-fases
$Script:ScriptsIndividuais = @{
    "0.1" = ".\executar-fase-0-1.ps1"
    "0.2" = ".\executar-fase-0-2.ps1"
    "0.3" = ".\executar-fase-0-3.ps1"   # pode nao existir
    "0.4" = ".\executar-fase-0-4.ps1"   # pode nao existir
}

# JSONs de progresso das sub-fases
$Script:JsonsSubfases = @{
    "0.1" = ".\setup\fase-0-1-progresso.json"
    "0.2" = ".\setup\fase-0-2-progresso.json"
    "0.3" = ".\setup\fase-0-3-progresso.json"
    "0.4" = ".\setup\fase-0-4-progresso.json"
}

# Titulos legiveis
$Script:TitulosSubfases = @{
    "0.1" = "Decisoes editoriais fundadoras"
    "0.2" = "Setup ambiente de producao"
    "0.3" = "Setup hospedagem web"
    "0.4" = "Gestao de referencias bibliograficas"
}

# ============================================================================
# HELPERS DE OUTPUT
# ============================================================================
function Write-Titulo($texto) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Blue
    Write-Host $texto -ForegroundColor Blue
    Write-Host ("=" * 78) -ForegroundColor Blue
}
function Write-Etapa($n, $titulo) {
    Write-Host ""
    Write-Host "--- [$n] $titulo ---" -ForegroundColor Cyan
}
function Write-OK($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Host "[i]    $msg" -ForegroundColor Cyan }
function Write-Warn($msg)  { Write-Host "[!]    $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[X]    $msg" -ForegroundColor Red }
function Write-Item($msg)  { Write-Host "       $msg" }

function Ask-YesNo($pergunta, $default = "S") {
    while ($true) {
        $r = Read-Host "$pergunta (S/N) [$default]"
        if ([string]::IsNullOrWhiteSpace($r)) { $r = $default }
        if ($r -match '^[SsYy]') { return $true }
        if ($r -match '^[Nn]')   { return $false }
        Write-Warn "Responda S ou N"
    }
}

function Ask-Text($pergunta, $default = "") {
    $texto = if ($default) { "$pergunta [$default]" } else { $pergunta }
    $r = Read-Host $texto
    if ([string]::IsNullOrWhiteSpace($r) -and $default) { return $default }
    return $r
}

# ============================================================================
# PERSISTENCIA
# ============================================================================
function Initialize-MetaProgresso {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }

    if (Test-Path $Script:ArquivoProgresso) {
        $json = Get-Content $Script:ArquivoProgresso -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    }

    $meta = [PSCustomObject]@{
        fase          = "0"
        titulo        = "Decisoes e Setup Tecnico"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        subfases_exec = @()
    }
    return $meta
}

function Save-MetaProgresso($meta) {
    $meta.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $meta | ConvertTo-Json -Depth 10

    $path = if (Test-Path $Script:ArquivoProgresso) {
        (Resolve-Path $Script:ArquivoProgresso).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoProgresso
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# Carregar JSON de uma sub-fase (retorna null se nao existir)
function Load-SubfaseJson($subfase) {
    $jsonPath = $Script:JsonsSubfases[$subfase]
    if (Test-Path $jsonPath) {
        try {
            return (Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        } catch {
            return $null
        }
    }
    return $null
}

# ============================================================================
# ANALISAR STATUS DE UMA SUB-FASE
# ============================================================================
function Get-StatusSubfase($subfase) {
    $json = Load-SubfaseJson $subfase

    if (-not $json) {
        return @{
            status     = "NAO_INICIADA"
            detalhes   = "Sem dados de progresso"
            completos  = 0
            total      = 0
            percent    = 0
        }
    }

    # 0.1: tem "decisoes" (5 itens esperados)
    if ($subfase -eq "0.1") {
        $count = if ($json.decisoes) { @($json.decisoes).Count } else { 0 }
        $total = 5
        $percent = if ($total -gt 0) { [math]::Round(100 * $count / $total, 0) } else { 0 }
        $status = if ($count -eq $total) { "COMPLETA" }
                  elseif ($count -gt 0) { "EM_ANDAMENTO" }
                  else { "NAO_INICIADA" }
        return @{
            status = $status
            detalhes = "$count/$total decisoes registradas"
            completos = $count
            total = $total
            percent = $percent
        }
    }

    # 0.2: tem "verificacoes" (6 itens esperados)
    if ($subfase -eq "0.2") {
        $verifs = if ($json.verificacoes) { @($json.verificacoes) } else { @() }
        $oks = @($verifs | Where-Object { $_.status -eq "OK" }).Count
        $total = 6
        $percent = if ($total -gt 0) { [math]::Round(100 * $oks / $total, 0) } else { 0 }
        $status = if ($oks -eq $total) { "COMPLETA" }
                  elseif ($oks -ge 4) { "EM_ANDAMENTO" }
                  elseif ($oks -gt 0) { "INICIADA" }
                  else { "NAO_INICIADA" }
        return @{
            status = $status
            detalhes = "$oks/$total verificacoes OK"
            completos = $oks
            total = $total
            percent = $percent
        }
    }

    # 0.3 e 0.4: usam campo "itens" (checklist)
    if ($subfase -eq "0.3" -or $subfase -eq "0.4") {
        $itens = if ($json.itens) { @($json.itens) } else { @() }
        $completos = @($itens | Where-Object { $_.feito }).Count
        $total = if ($subfase -eq "0.3") { 6 } else { 4 }
        $percent = if ($total -gt 0) { [math]::Round(100 * $completos / $total, 0) } else { 0 }
        $status = if ($completos -eq $total) { "COMPLETA" }
                  elseif ($completos -gt 0) { "EM_ANDAMENTO" }
                  else { "NAO_INICIADA" }
        return @{
            status = $status
            detalhes = "$completos/$total itens feitos"
            completos = $completos
            total = $total
            percent = $percent
        }
    }
}

# ============================================================================
# DELEGACAO PARA SCRIPTS INDIVIDUAIS
# ============================================================================
function Delegar-Subfase($subfase) {
    $scriptPath = $Script:ScriptsIndividuais[$subfase]

    if (Test-Path $scriptPath) {
        Write-Info "Delegando para: $scriptPath"
        Write-Host ""
        & $scriptPath
        return $true
    }

    Write-Warn "Script individual nao encontrado: $scriptPath"
    return $false
}

# ============================================================================
# SUB-FASE 0.3 - HOSPEDAGEM WEB (implementacao INLINE)
# ============================================================================
function Executar-Subfase-03 {
    Write-Titulo "SUB-FASE 0.3 - Setup Hospedagem Web"

    Write-Info "Verificando 6 componentes de hospedagem:"
    Write-Item "  1. Repositorio GitHub existe"
    Write-Item "  2. GitHub Action de render configurado"
    Write-Item "  3. Branch gh-pages / GitHub Pages ativo"
    Write-Item "  4. Dominio registrado (opcional)"
    Write-Item "  5. CNAME configurado (opcional)"
    Write-Item "  6. SSL do GitHub Pages ativo"
    Write-Host ""

    if (-not (Ask-YesNo "Prosseguir?")) { return }

    # Estrutura de progresso
    $progresso = [PSCustomObject]@{
        subfase       = "0.3"
        titulo        = "Setup Hospedagem Web"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        itens         = @()
    }

    # Se ja existe, carregar
    if (Test-Path $Script:JsonsSubfases["0.3"]) {
        $progresso = Load-SubfaseJson "0.3"
    }

    # ---- Item 1: Repositorio GitHub ----
    Write-Etapa "1" "Repositorio GitHub"
    $repo = "mariocezar1971/livro-doe-usinagem"
    Write-Item "Verificando: https://github.com/$repo"

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $repoInfo = gh repo view $repo --json name,url 2>$null | ConvertFrom-Json
            if ($repoInfo) {
                Write-OK "Repositorio ativo: $($repoInfo.url)"
                $item1 = @{ nome="Repositorio GitHub"; feito=$true; notas="$repo" }
            } else {
                Write-Warn "gh nao retornou dados"
                $item1 = @{ nome="Repositorio GitHub"; feito=$false; notas="" }
            }
        } catch {
            Write-Warn "Erro ao verificar: $_"
            $item1 = @{ nome="Repositorio GitHub"; feito=$false; notas="" }
        }
    } else {
        Write-Warn "gh CLI nao disponivel - verificar manualmente"
        if (Ask-YesNo "Abrir repo no navegador?" "N") {
            Start-Process "https://github.com/$repo"
        }
        $confirma = Ask-YesNo "Repositorio existe?" "S"
        $item1 = @{ nome="Repositorio GitHub"; feito=$confirma; notas="Verificado manualmente" }
    }

    # ---- Item 2: GitHub Actions ----
    Write-Etapa "2" "GitHub Action de render automatico"
    $workflowPath = ".github\workflows\publish.yml"

    if (Test-Path $workflowPath) {
        Write-OK "Workflow encontrado: $workflowPath"
        $conteudo = Get-Content $workflowPath -Raw
        if ($conteudo -match 'quarto|quarto-actions') {
            Write-OK "  Configurado com Quarto"
        }
        $item2 = @{ nome="GitHub Action de render"; feito=$true; notas="$workflowPath" }
    } else {
        Write-Warn "Workflow nao encontrado em $workflowPath"
        Write-Item "Criar em .github/workflows/publish.yml"
        Write-Item "Template: quarto-dev/quarto-actions/publish"
        $item2 = @{ nome="GitHub Action de render"; feito=$false; notas="Workflow ausente" }
    }

    # ---- Item 3: GitHub Pages ativo ----
    Write-Etapa "3" "Branch gh-pages / GitHub Pages"
    $urlPages = "https://mariocezar1971.github.io/livro-doe-usinagem/"

    Write-Item "Testando URL publica: $urlPages"
    try {
        $resp = Invoke-WebRequest -Uri $urlPages -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-OK "Site publicado - HTTP 200"
            $item3 = @{ nome="GitHub Pages ativo"; feito=$true; notas="HTTP 200 em $urlPages" }
        } else {
            Write-Warn "HTTP $($resp.StatusCode)"
            $item3 = @{ nome="GitHub Pages ativo"; feito=$false; notas="HTTP $($resp.StatusCode)" }
        }
    } catch {
        Write-Err "Site nao acessivel: $($_.Exception.Message)"
        $item3 = @{ nome="GitHub Pages ativo"; feito=$false; notas="Erro HTTP" }
    }

    # ---- Item 4: Dominio registrado ----
    Write-Etapa "4" "Dominio proprio"
    Write-Item "Estrategia decidida: Estrategia A (usar ensinodoelab.com.br/livro)"
    Write-Item "  Alternativa: registrar doeusinagem.com.br (~R`$40/ano)"

    $decisaoDominio = Ask-Text "Dominio principal (ou 'sem-dominio-proprio')" "ensinodoelab.com.br"

    if ($decisaoDominio -eq "sem-dominio-proprio") {
        Write-Info "Usando dominio nativo do GitHub Pages"
        $item4 = @{ nome="Dominio proprio"; feito=$true; notas="Nativo GitHub Pages (adiado)" }
    } else {
        Write-Info "Verificando via DNS..."
        try {
            $dns = Resolve-DnsName -Name $decisaoDominio -Type A -ErrorAction Stop
            if ($dns) {
                Write-OK "Dominio $decisaoDominio ativo (resolve para $($dns[0].IPAddress))"
                $item4 = @{ nome="Dominio proprio"; feito=$true; notas="$decisaoDominio ativo" }
            }
        } catch {
            Write-Warn "Dominio $decisaoDominio nao resolve"
            $item4 = @{ nome="Dominio proprio"; feito=$false; notas="$decisaoDominio nao configurado" }
        }
    }

    # ---- Item 5: CNAME ----
    Write-Etapa "5" "Arquivo CNAME"

    if (Test-Path ".\CNAME") {
        $cname = (Get-Content ".\CNAME" -Raw).Trim()
        Write-OK "CNAME presente: $cname"
        $item5 = @{ nome="Arquivo CNAME"; feito=$true; notas="$cname" }
    } else {
        Write-Warn "Arquivo CNAME nao encontrado na raiz"
        Write-Item "Necessario apenas se usa dominio proprio"
        Write-Item "Criar: New-Item CNAME -Value 'seu.dominio.com'"

        if ($decisaoDominio -ne "sem-dominio-proprio") {
            if (Ask-YesNo "Criar arquivo CNAME agora?" "N") {
                $cnameDom = Ask-Text "Dominio para CNAME" "livro.$decisaoDominio"
                Set-Content -Path ".\CNAME" -Value $cnameDom -Encoding ASCII
                Write-OK "CNAME criado com: $cnameDom"
                $item5 = @{ nome="Arquivo CNAME"; feito=$true; notas="$cnameDom" }
            } else {
                $item5 = @{ nome="Arquivo CNAME"; feito=$false; notas="Ausente" }
            }
        } else {
            $item5 = @{ nome="Arquivo CNAME"; feito=$true; notas="Nao necessario" }
        }
    }

    # ---- Item 6: SSL ----
    Write-Etapa "6" "SSL / HTTPS"
    Write-Item "GitHub Pages fornece SSL automatico via Let's Encrypt"
    Write-Item "Verificando HTTPS em $urlPages..."

    try {
        $respHttps = Invoke-WebRequest -Uri $urlPages -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($urlPages -match '^https:') {
            Write-OK "HTTPS ativo (HTTP $($respHttps.StatusCode))"
            $item6 = @{ nome="SSL / HTTPS"; feito=$true; notas="Ativo em $urlPages" }
        } else {
            Write-Warn "URL nao usa HTTPS"
            $item6 = @{ nome="SSL / HTTPS"; feito=$false; notas="Configurar Enforce HTTPS no GitHub" }
        }
    } catch {
        Write-Err "Erro ao testar: $_"
        $item6 = @{ nome="SSL / HTTPS"; feito=$false; notas="Erro" }
    }

    # Salvar progresso (deduplicacao)
    $todosItens = @($item1, $item2, $item3, $item4, $item5, $item6)
    $progresso.itens = @($todosItens | ForEach-Object { [PSCustomObject]$_ })
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Progresso03 $progresso

    # Resumo
    $feitos = @($progresso.itens | Where-Object { $_.feito }).Count
    Write-Host ""
    Write-Info "Resumo: $feitos/6 itens completos"
}

function Save-Progresso03($progresso) {
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:JsonsSubfases["0.3"]
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# ============================================================================
# SUB-FASE 0.4 - REFERENCIAS BIBLIOGRAFICAS (implementacao INLINE)
# ============================================================================
function Executar-Subfase-04 {
    Write-Titulo "SUB-FASE 0.4 - Gestao de Referencias Bibliograficas"

    Write-Info "Verificando 4 componentes:"
    Write-Item "  1. Zotero ou JabRef instalado"
    Write-Item "  2. references.bib presente com entradas"
    Write-Item "  3. Estilo CSL configurado (ABNT ou Springer)"
    Write-Item "  4. Bibliografia integrada ao _quarto.yml"
    Write-Host ""

    if (-not (Ask-YesNo "Prosseguir?")) { return }

    $progresso = [PSCustomObject]@{
        subfase       = "0.4"
        titulo        = "Gestao de Referencias Bibliograficas"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        itens         = @()
    }

    if (Test-Path $Script:JsonsSubfases["0.4"]) {
        $progresso = Load-SubfaseJson "0.4"
    }

    # ---- Item 1: Zotero/JabRef ----
    Write-Etapa "1" "Zotero ou JabRef instalado"

    $zoteroPaths = @(
        "$env:LOCALAPPDATA\Zotero\zotero.exe",
        "C:\Program Files\Zotero\zotero.exe",
        "C:\Program Files (x86)\Zotero\zotero.exe"
    )
    $jabrefPaths = @(
        "C:\Program Files\JabRef\JabRef.exe",
        "$env:LOCALAPPDATA\Programs\JabRef\JabRef.exe"
    )

    $zoteroInstalado = $zoteroPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    $jabrefInstalado = $jabrefPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($zoteroInstalado) {
        Write-OK "Zotero encontrado: $zoteroInstalado"
        $item1 = @{ nome="Zotero/JabRef instalado"; feito=$true; notas="Zotero em $zoteroInstalado" }
    } elseif ($jabrefInstalado) {
        Write-OK "JabRef encontrado: $jabrefInstalado"
        $item1 = @{ nome="Zotero/JabRef instalado"; feito=$true; notas="JabRef em $jabrefInstalado" }
    } else {
        Write-Warn "Zotero e JabRef nao encontrados"
        Write-Item "Zotero (recomendado): https://www.zotero.org/download/"
        Write-Item "JabRef (alternativa): https://www.jabref.org/"
        Write-Item ""
        Write-Item "Voce pode manter references.bib manual sem essas ferramentas"

        $manual = Ask-YesNo "Vai gerenciar references.bib manualmente?" "S"
        if ($manual) {
            $item1 = @{ nome="Zotero/JabRef instalado"; feito=$true; notas="Gerenciamento manual" }
        } else {
            $item1 = @{ nome="Zotero/JabRef instalado"; feito=$false; notas="Nao instalado" }
        }
    }

    # ---- Item 2: references.bib ----
    Write-Etapa "2" "references.bib presente"

    if (Test-Path ".\references.bib") {
        $bibContent = Get-Content ".\references.bib" -Raw
        $entradas = ([regex]::Matches($bibContent, '@\w+\{')).Count
        Write-OK "references.bib presente com $entradas entradas"

        if ($entradas -eq 0) {
            Write-Warn "  Arquivo existe mas sem entradas"
            $item2 = @{ nome="references.bib presente"; feito=$false; notas="0 entradas" }
        } else {
            $item2 = @{ nome="references.bib presente"; feito=$true; notas="$entradas entradas" }
        }
    } else {
        Write-Warn "references.bib nao encontrado na raiz"
        Write-Item "Criar manualmente ou exportar do Zotero"

        if (Ask-YesNo "Criar references.bib vazio?" "N") {
            Set-Content -Path ".\references.bib" -Value "% Referencias bibliograficas do livro`n" -Encoding UTF8
            Write-OK "Arquivo criado: references.bib"
            $item2 = @{ nome="references.bib presente"; feito=$true; notas="Criado vazio" }
        } else {
            $item2 = @{ nome="references.bib presente"; feito=$false; notas="Ausente" }
        }
    }

    # ---- Item 3: CSL ----
    Write-Etapa "3" "Estilo CSL (Citation Style Language)"

    $cslDisponiveis = Get-ChildItem -Path "." -Filter "*.csl" -ErrorAction SilentlyContinue

    if ($cslDisponiveis) {
        Write-OK "Arquivos CSL encontrados:"
        foreach ($csl in $cslDisponiveis) {
            Write-Item "  - $($csl.Name) ($($csl.Length) bytes)"
        }
        $item3 = @{ nome="Estilo CSL configurado"; feito=$true; notas=($cslDisponiveis.Name -join ', ') }
    } else {
        Write-Warn "Nenhum CSL encontrado na raiz"
        Write-Item "Opcoes recomendadas:"
        Write-Item "  a) ABNT (padrao Brasil) - abnt-ipea.csl"
        Write-Item "  b) Springer (livros tecnicos internacionais)"
        Write-Item "  c) IEEE (engenharia)"
        Write-Item ""
        Write-Item "Baixar em: https://www.zotero.org/styles"

        if (Ask-YesNo "Abrir Zotero Styles para escolher?" "N") {
            Start-Process "https://www.zotero.org/styles?q=abnt"
        }

        $item3 = @{ nome="Estilo CSL configurado"; feito=$false; notas="Nenhum .csl na raiz" }
    }

    # ---- Item 4: Integracao com _quarto.yml ----
    Write-Etapa "4" "Bibliografia integrada ao _quarto.yml"

    if (Test-Path ".\_quarto.yml") {
        $ymlContent = Get-Content ".\_quarto.yml" -Raw

        $temBib = $ymlContent -match 'bibliography:'
        $temCsl = $ymlContent -match 'csl:'

        if ($temBib) { Write-OK "bibliography: configurado no _quarto.yml" }
        else         { Write-Warn "bibliography: NAO configurado" }

        if ($temCsl) { Write-OK "csl: configurado no _quarto.yml" }
        else         { Write-Warn "csl: NAO configurado" }

        if ($temBib -and $temCsl) {
            $item4 = @{ nome="Integracao com _quarto.yml"; feito=$true; notas="bibliography + csl OK" }
        } elseif ($temBib) {
            $item4 = @{ nome="Integracao com _quarto.yml"; feito=$false; notas="Falta csl:" }
        } else {
            $item4 = @{ nome="Integracao com _quarto.yml"; feito=$false; notas="Falta bibliography:" }
        }
    } else {
        Write-Err "_quarto.yml nao encontrado"
        $item4 = @{ nome="Integracao com _quarto.yml"; feito=$false; notas="_quarto.yml ausente" }
    }

    # Salvar
    $todosItens = @($item1, $item2, $item3, $item4)
    $progresso.itens = @($todosItens | ForEach-Object { [PSCustomObject]$_ })
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Save-Progresso04 $progresso

    $feitos = @($progresso.itens | Where-Object { $_.feito }).Count
    Write-Host ""
    Write-Info "Resumo: $feitos/4 itens completos"
}

function Save-Progresso04($progresso) {
    $json = $progresso | ConvertTo-Json -Depth 10
    $path = Join-Path (Get-Location) $Script:JsonsSubfases["0.4"]
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# ============================================================================
# DASHBOARD CONSOLIDADO
# ============================================================================
function Mostrar-Dashboard {
    Write-Titulo "DASHBOARD - FASE 0 CONSOLIDADA"

    $totalItens = 0
    $totalCompletos = 0

    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $st = Get-StatusSubfase $sf
        $totalItens += $st.total
        $totalCompletos += $st.completos
    }

    $percentGeral = if ($totalItens -gt 0) { [math]::Round(100 * $totalCompletos / $totalItens, 0) } else { 0 }

    Write-Host ""
    Write-Info "Progresso geral: $totalCompletos/$totalItens itens ($percentGeral%)"
    Write-Host ""

    # Barra de progresso simples
    $barraLen = 50
    $preenchido = [math]::Round(($percentGeral / 100) * $barraLen, 0)
    $vazio = $barraLen - $preenchido
    $barra = "[" + ("=" * $preenchido) + (" " * $vazio) + "]"
    Write-Host $barra -ForegroundColor Green

    Write-Host ""
    Write-Host "Detalhamento por sub-fase:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $st = Get-StatusSubfase $sf
        $titulo = $Script:TitulosSubfases[$sf]

        $indicador = switch ($st.status) {
            "COMPLETA"      { "[OK]" }
            "EM_ANDAMENTO"  { "[..]" }
            "INICIADA"      { "[..]" }
            "NAO_INICIADA"  { "[  ]" }
            default         { "[?] " }
        }

        $cor = switch ($st.status) {
            "COMPLETA"      { "Green" }
            "EM_ANDAMENTO"  { "Cyan" }
            "INICIADA"      { "Cyan" }
            "NAO_INICIADA"  { "Gray" }
            default         { "Yellow" }
        }

        $linha = "  {0} Fase {1} - {2,-42} {3} ({4}%)" -f $indicador, $sf, $titulo, $st.detalhes, $st.percent
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Scripts individuais disponiveis:"
    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $script = $Script:ScriptsIndividuais[$sf]
        if (Test-Path $script) {
            Write-OK "  $script"
        } else {
            Write-Item "  [!] $script (inline no meta orquestrador)"
        }
    }

    Write-Host ""
    Write-Info "JSONs de progresso:"
    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $json = $Script:JsonsSubfases[$sf]
        if (Test-Path $json) {
            $tamanho = (Get-Item $json).Length
            Write-OK "  $json ($tamanho bytes)"
        } else {
            Write-Item "  [!] $json (ainda nao criado)"
        }
    }
}

# ============================================================================
# GERAR MARKDOWN CONSOLIDADO
# ============================================================================
function Update-DocumentacaoConsolidada {
    $md = "# Fase 0 - Status Consolidado`n`n"
    $md += "**Gerado por executar-fase-0.ps1**`n"
    $md += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"

    $totalItens = 0
    $totalCompletos = 0

    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $st = Get-StatusSubfase $sf
        $totalItens += $st.total
        $totalCompletos += $st.completos
    }

    $percentGeral = if ($totalItens -gt 0) { [math]::Round(100 * $totalCompletos / $totalItens, 0) } else { 0 }
    $md += "## Progresso geral: $totalCompletos/$totalItens ($percentGeral%)`n`n---`n`n"

    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $st = Get-StatusSubfase $sf
        $titulo = $Script:TitulosSubfases[$sf]

        $icone = switch ($st.status) {
            "COMPLETA"      { "[x]" }
            "EM_ANDAMENTO"  { "[~]" }
            "INICIADA"      { "[~]" }
            default         { "[ ]" }
        }

        $md += "### $icone Fase $sf - $titulo`n`n"
        $md += "- **Status:** $($st.status)`n"
        $md += "- **Progresso:** $($st.detalhes)`n"
        $md += "- **Percentual:** $($st.percent)%`n`n"

        # Detalhes por sub-fase
        $json = Load-SubfaseJson $sf
        if ($json) {
            if ($sf -eq "0.1" -and $json.decisoes) {
                foreach ($d in ($json.decisoes | Sort-Object id)) {
                    $md += "  - [x] $($d.nome): $($d.valor)`n"
                }
            } elseif ($sf -eq "0.2" -and $json.verificacoes) {
                foreach ($v in ($json.verificacoes | Sort-Object id)) {
                    $check = if ($v.status -eq "OK") { "[x]" } else { "[!]" }
                    $md += "  - $check $($v.nome): $($v.status)`n"
                }
            } elseif (($sf -eq "0.3" -or $sf -eq "0.4") -and $json.itens) {
                foreach ($i in $json.itens) {
                    $check = if ($i.feito) { "[x]" } else { "[ ]" }
                    $md += "  - $check $($i.nome)"
                    if ($i.notas) { $md += " ($($i.notas))" }
                    $md += "`n"
                }
            }
        }

        $md += "`n---`n`n"
    }

    $path = Join-Path (Get-Location) $Script:ArquivoDoc
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================
function Show-Menu {
    Write-Titulo "META ORQUESTRADOR - FASE 0"

    # Mini dashboard no menu
    Write-Host ""
    Write-Host "Estado atual:" -ForegroundColor Yellow
    foreach ($sf in @("0.1", "0.2", "0.3", "0.4")) {
        $st = Get-StatusSubfase $sf
        $indicador = switch ($st.status) {
            "COMPLETA"      { "[OK]" }
            "EM_ANDAMENTO"  { "[..]" }
            "INICIADA"      { "[..]" }
            default         { "[  ]" }
        }
        $cor = switch ($st.status) {
            "COMPLETA"      { "Green" }
            "EM_ANDAMENTO"  { "Cyan" }
            "INICIADA"      { "Cyan" }
            default         { "Gray" }
        }
        $linha = "  {0} Fase {1} - {2} ({3})" -f $indicador, $sf, $Script:TitulosSubfases[$sf], $st.detalhes
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Host "Opcoes:" -ForegroundColor Yellow
    Write-Host "  1) Executar Fase 0.1 - Decisoes editoriais"
    Write-Host "  2) Executar Fase 0.2 - Ambiente de producao"
    Write-Host "  3) Executar Fase 0.3 - Hospedagem web"
    Write-Host "  4) Executar Fase 0.4 - Referencias bibliograficas"
    Write-Host ""
    Write-Host "  5) Dashboard consolidado"
    Write-Host "  6) Abrir documentacao gerada"
    Write-Host "  0) Sair"
    Write-Host ""
    return Read-Host "Escolha uma opcao"
}

# ============================================================================
# EXECUTAR TODAS
# ============================================================================
function Executar-Subfase($subfase) {
    switch ($subfase) {
        "0.1" {
            if (-not (Delegar-Subfase "0.1")) {
                Write-Err "Sub-fase 0.1 requer executar-fase-0-1.ps1"
                Write-Info "Baixe/crie o script e coloque na raiz do projeto"
            }
        }
        "0.2" {
            if (-not (Delegar-Subfase "0.2")) {
                Write-Err "Sub-fase 0.2 requer executar-fase-0-2.ps1"
                Write-Info "Baixe/crie o script e coloque na raiz do projeto"
            }
        }
        "0.3" {
            if (Test-Path $Script:ScriptsIndividuais["0.3"]) {
                Delegar-Subfase "0.3" | Out-Null
            } else {
                Executar-Subfase-03
            }
        }
        "0.4" {
            if (Test-Path $Script:ScriptsIndividuais["0.4"]) {
                Delegar-Subfase "0.4" | Out-Null
            } else {
                Executar-Subfase-04
            }
        }
    }

    Update-DocumentacaoConsolidada
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
}

# Reset
if ($Reset) {
    if (Ask-YesNo "ATENCAO: apagar META estado (nao apaga sub-fases individuais). Confirmar?" "N") {
        Remove-Item $Script:ArquivoProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArquivoDoc -ErrorAction SilentlyContinue
        Write-OK "Meta estado resetado"
        Write-Info "Sub-fases 0.1, 0.2, 0.3, 0.4 preservadas"
    }
    exit 0
}

$meta = Initialize-MetaProgresso

# Status
if ($Status) {
    Mostrar-Dashboard
    Update-DocumentacaoConsolidada
    exit 0
}

# Sub-fase especifica
if ($Subfase) {
    Executar-Subfase $Subfase
    Write-Host ""
    Mostrar-Dashboard
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $opcao = Show-Menu
    switch ($opcao) {
        "1" { Executar-Subfase "0.1" }
        "2" { Executar-Subfase "0.2" }
        "3" { Executar-Subfase "0.3" }
        "4" { Executar-Subfase "0.4" }
        "5" { Mostrar-Dashboard; Update-DocumentacaoConsolidada }
        "6" {
            if (Test-Path $Script:ArquivoDoc) {
                Start-Process $Script:ArquivoDoc
            } else {
                Update-DocumentacaoConsolidada
                Start-Process $Script:ArquivoDoc
            }
        }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Save-MetaProgresso $meta
Update-DocumentacaoConsolidada

Write-Host ""
Write-OK "Encerrando. Meta estado salvo em $Script:ArquivoProgresso"
Write-Info "Retomar com: .\executar-fase-0.ps1 -Status"
