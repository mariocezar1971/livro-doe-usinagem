# ============================================================================
# executar-fase-1-3.ps1
#
# Orquestrador interativo da Fase 1.3 - Landing Page de Captura de Emails
#
# 6 verificacoes/acoes:
#   1. em-breve.qmd existe e tem conteudo substancial
#   2. em-breve.css presente (visual da landing)
#   3. Registrada no _quarto.yml (aparece no site)
#   4. Formulario Brevo integrado (codigo HTML embed)
#   5. Promessa do capitulo gratuito presente no texto
#   6. URL publica responde (deploy funcional)
#
# Persistencia:
#   setup/fase-1-3-progresso.json    - estado JSON
#   setup/FASE_1_3_LANDING.md        - relatorio Markdown
#
# USO:
#   .\executar-fase-1-3.ps1              # Executar todas as 6 verificacoes
#   .\executar-fase-1-3.ps1 -Etapa 4     # So verificar formulario Brevo
#   .\executar-fase-1-3.ps1 -Status      # Ver ultimo estado
#   .\executar-fase-1-3.ps1 -Reset       # Zerar
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateRange(1, 6)]
    [int]$Etapa = 0,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup       = ".\setup"
$Script:ArquivoProgresso = ".\setup\fase-1-3-progresso.json"
$Script:ArquivoDoc       = ".\setup\FASE_1_3_LANDING.md"

$Script:ArqQMD       = ".\em-breve.qmd"
$Script:ArqCSS       = ".\em-breve.css"
$Script:ArqCSSStyles = ".\styles\em-breve.css"
$Script:ArqYML       = ".\_quarto.yml"
$Script:UrlPublica   = "https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html"

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
function Initialize-Progresso {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }

    if (Test-Path $Script:ArquivoProgresso) {
        $json = Get-Content $Script:ArquivoProgresso -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    }

    $progresso = [PSCustomObject]@{
        fase          = "1.3"
        titulo        = "Landing Page de Captura de Emails"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        verificacoes  = @()
    }
    return $progresso
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10

    $path = if (Test-Path $Script:ArquivoProgresso) {
        (Resolve-Path $Script:ArquivoProgresso).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoProgresso
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

# Deduplicacao EMBUTIDA
function Set-Verificacao($progresso, $id, $nome, $status, $detalhes = "", $acao = "") {
    $verif = [PSCustomObject]@{
        id            = $id
        nome          = $nome
        status        = $status   # OK | AVISO | ERRO | PENDENTE
        detalhes      = $detalhes
        acao          = $acao
        verificada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $novaLista = @($progresso.verificacoes | Where-Object { $_.id -ne $id })
    $novaLista += $verif
    $progresso.verificacoes = @($novaLista)

    return $verif
}

function Get-Verificacao($progresso, $id) {
    return $progresso.verificacoes | Where-Object { $_.id -eq $id } | Select-Object -First 1
}

# ============================================================================
# GERAR DOCUMENTACAO
# ============================================================================
function Update-Documentacao($progresso) {
    $md = "# Fase 1.3 - Landing Page de Captura`n`n"
    $md += "**Gerado por executar-fase-1-3.ps1**`n"
    $md += "Ultima atualizacao: $($progresso.atualizada_em)`n`n"

    $oks = @($progresso.verificacoes | Where-Object { $_.status -eq "OK" }).Count
    $md += "**Progresso:** $oks/6 verificacoes OK`n`n"

    $md += "**URL publica:** $($Script:UrlPublica)`n`n---`n`n"

    $ordenadas = $progresso.verificacoes | Sort-Object id

    foreach ($v in $ordenadas) {
        $icone = switch ($v.status) {
            "OK"       { "[x]" }
            "AVISO"    { "[!]" }
            "ERRO"     { "[X]" }
            default    { "[ ]" }
        }

        $md += "## $($v.id). $($v.nome) $icone`n`n"
        $md += "**Status:** $($v.status)`n`n"
        if ($v.detalhes) { $md += "**Detalhes:** $($v.detalhes)`n`n" }
        if ($v.acao)     { $md += "**Acao:** $($v.acao)`n`n" }
        $md += "**Verificada em:** $($v.verificada_em)`n`n---`n`n"
    }

    # Comandos uteis no rodape
    $md += "## Comandos uteis`n`n"
    $md += "``````powershell`n"
    $md += "# Deploy: renderiza + push (Actions renderiza no servidor)`n"
    $md += "git add em-breve.qmd em-breve.css _quarto.yml`n"
    $md += 'git commit -m "Fase 1.3: atualizacao landing page"' + "`n"
    $md += "git push`n`n"
    $md += "# Ver deploy rodando`n"
    $md += "Start-Sleep -Seconds 15`n"
    $md += "gh run list --repo mariocezar1971/livro-doe-usinagem --limit 1`n`n"
    $md += "# Abrir landing publica`n"
    $md += "Start-Process '$($Script:UrlPublica)'`n"
    $md += "``````" + "`n"

    $path = if (Test-Path $Script:ArquivoDoc) {
        (Resolve-Path $Script:ArquivoDoc).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoDoc
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# ETAPA 1 - em-breve.qmd EXISTE E TEM CONTEUDO
# ============================================================================
function Verificar-QMD($progresso) {
    Write-Etapa "1" "em-breve.qmd existe e tem conteudo substancial"

    if (-not (Test-Path $Script:ArqQMD)) {
        Write-Err "$($Script:ArqQMD) NAO existe"
        Write-Item ""
        Write-Item "Criar template basico agora?"

        if (Ask-YesNo "Gerar em-breve.qmd basico?" "N") {
            $template = @'
---
title: "Em breve: Planejamento de Experimentos em Usinagem"
subtitle: "Fatorial, RSM e otimizacao multiresposta aplicados as ligas de aluminio"
css: em-breve.css
pagetitle: "Livro DOE em Usinagem - Em breve"
description-meta: "Livro tecnico sobre DOE aplicado ao torneamento de ligas de aluminio. Inscreva-se para receber capitulo gratuito no lancamento."
sidebar: false
toc: false
number-sections: false
format:
  html:
    include-in-header:
      - text: |
          <meta name="robots" content="index,follow">
---

## O que voce vai encontrar neste livro

Um guia completo em portugues sobre **Planejamento de Experimentos (DOE)** aplicado ao torneamento de ligas de aluminio, escrito para:

- Alunos de pos-graduacao em Engenharia Mecanica e de Producao
- Engenheiros de manufatura em industrias automotiva, aeronautica e de auto pecas
- Professores e pesquisadores em usinagem

### Metodologia coberta

- Planejamento fatorial 2^k completo e fracionario
- Planejamento composto central (PCC) e superficies de resposta (RSM)
- Otimizacao multiresposta com funcao desejabilidade e algoritmos geneticos
- Estudo de caso com 6 ligas de aluminio 6xxx e 7xxx

### Reserve seu capitulo gratuito

Ao se inscrever, voce recebe **um capitulo completo do livro gratuitamente** quando ele for publicado, alem de:

- Atualizacoes exclusivas sobre o lancamento
- Codigo R + Python usado nos exemplos
- Datasets abertos em CSV/SQLite (licenca CC BY 4.0)

<!-- BREVO FORM PLACEHOLDER - substituir por embed real -->
<!-- Instrucoes: Brevo > Contatos > Formularios > Criar > copiar HTML aqui -->

::: {.callout-note}
## Cadastro em desenvolvimento
Este formulario esta sendo configurado. Volte em alguns dias, ou envie um email para mcezarjr@ifes.edu.br com o assunto "Livro DOE" para reservar seu capitulo gratuito.
:::
'@
            Set-Content -Path $Script:ArqQMD -Value $template -Encoding UTF8
            Write-OK "em-breve.qmd criado (template basico)"
            Set-Verificacao $progresso "1" "em-breve.qmd" "AVISO" "Criado com template basico - personalizar" "Editar textos e adicionar Brevo" | Out-Null
        } else {
            Set-Verificacao $progresso "1" "em-breve.qmd" "ERRO" "Arquivo nao existe" "Criar em-breve.qmd" | Out-Null
        }
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $arq = Get-Item $Script:ArqQMD
    $tamanho = $arq.Length
    Write-OK "em-breve.qmd presente"
    Write-Item "  Tamanho: $tamanho bytes"

    if ($tamanho -lt 1500) {
        Write-Warn "  Conteudo pequeno (<1.5 KB) - considere expandir"
        Set-Verificacao $progresso "1" "em-breve.qmd" "AVISO" "$tamanho bytes (pequeno)" "Expandir conteudo" | Out-Null
    } elseif ($tamanho -lt 4000) {
        Write-Item "  Conteudo moderado (>1.5 KB) - OK"
        Set-Verificacao $progresso "1" "em-breve.qmd" "OK" "$tamanho bytes" "" | Out-Null
    } else {
        Write-OK "  Conteudo substancial (>4 KB)"
        Set-Verificacao $progresso "1" "em-breve.qmd" "OK" "$tamanho bytes (substancial)" "" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 2 - em-breve.css PRESENTE
# ============================================================================
function Verificar-CSS($progresso) {
    Write-Etapa "2" "em-breve.css presente (visual da landing)"

    $encontrado = $null
    if (Test-Path $Script:ArqCSS) { $encontrado = $Script:ArqCSS }
    elseif (Test-Path $Script:ArqCSSStyles) { $encontrado = $Script:ArqCSSStyles }

    if ($encontrado) {
        $arq = Get-Item $encontrado
        Write-OK "CSS encontrado: $encontrado ($($arq.Length) bytes)"
        Set-Verificacao $progresso "2" "em-breve.css" "OK" "$encontrado ($($arq.Length) bytes)" "" | Out-Null
    } else {
        Write-Warn "em-breve.css nao encontrado (raiz nem styles/)"
        Write-Item ""
        Write-Item "Sem CSS, a landing usara estilos padrao do Quarto"
        Write-Item "CSS customizado melhora conversao (call-to-action visivel)"

        if (Ask-YesNo "Criar em-breve.css basico?" "N") {
            $cssTemplate = @'
/* em-breve.css - Landing page do livro DOE em Usinagem */

/* Titulo principal */
h1.title {
    font-size: 2.5rem;
    color: #1a5490;
    text-align: center;
    margin-bottom: 0.5rem;
}
h1.subtitle {
    font-size: 1.25rem;
    color: #555;
    text-align: center;
    font-weight: 400;
    margin-bottom: 2rem;
}

/* Corpo do texto */
main {
    max-width: 720px;
    margin: 0 auto;
    padding: 2rem 1rem;
}

/* Secoes com destaque */
h2 {
    color: #1a5490;
    border-bottom: 2px solid #e0e6ed;
    padding-bottom: 0.5rem;
    margin-top: 2rem;
}
h3 {
    color: #2c3e50;
    margin-top: 1.5rem;
}

/* Listas */
ul li {
    margin-bottom: 0.5rem;
    line-height: 1.6;
}

/* Callout de cadastro */
.callout-note {
    border-left: 4px solid #1a5490;
    background: #f0f7ff;
    padding: 1rem;
    margin: 1.5rem 0;
    border-radius: 4px;
}

/* Formulario Brevo (quando integrado) */
.sib-form {
    max-width: 500px;
    margin: 2rem auto;
    padding: 2rem;
    background: #fff;
    border: 1px solid #e0e6ed;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

/* Responsivo */
@media (max-width: 600px) {
    h1.title { font-size: 1.75rem; }
    h1.subtitle { font-size: 1rem; }
    main { padding: 1rem; }
}
'@
            Set-Content -Path $Script:ArqCSS -Value $cssTemplate -Encoding UTF8
            Write-OK "em-breve.css criado (template basico)"
            Set-Verificacao $progresso "2" "em-breve.css" "OK" "Criado com template" "" | Out-Null
        } else {
            Set-Verificacao $progresso "2" "em-breve.css" "AVISO" "Ausente - usa estilos padrao" "Criar CSS quando quiser diferenciar visual" | Out-Null
        }
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 3 - REGISTRADA NO _quarto.yml
# ============================================================================
function Verificar-YAML($progresso) {
    Write-Etapa "3" "em-breve registrada no _quarto.yml"

    if (-not (Test-Path $Script:ArqYML)) {
        Write-Err "_quarto.yml nao encontrado na raiz"
        Set-Verificacao $progresso "3" "Registro _quarto.yml" "ERRO" "_quarto.yml ausente" "Criar _quarto.yml" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $yml = Get-Content $Script:ArqYML -Raw -Encoding UTF8

    if ($yml -match 'em-breve\.qmd') {
        Write-OK "em-breve.qmd registrado no _quarto.yml"

        # Verificar se esta em chapters ou resources
        if ($yml -match 'chapters:[^#]*em-breve\.qmd') {
            Write-Item "  Registrado como CHAPTER (aparece no sumario)"
        } elseif ($yml -match 'resources:[^#]*em-breve\.qmd') {
            Write-Item "  Registrado como RESOURCE (URL avulsa, nao aparece no sumario)"
        } else {
            Write-Item "  Registrado (localizacao especifica nao identificada)"
        }

        Set-Verificacao $progresso "3" "Registro _quarto.yml" "OK" "em-breve.qmd presente" "" | Out-Null
    } else {
        Write-Warn "em-breve.qmd NAO registrado no _quarto.yml"
        Write-Item ""
        Write-Item "Sem registro, a pagina NAO sera renderizada pelo Quarto"
        Write-Item ""
        Write-Item "Opcoes de registro:"
        Write-Item ""
        Write-Item "  A) Como CHAPTER (aparece no sumario do livro):"
        Write-Item "     chapters:"
        Write-Item "       - index.qmd"
        Write-Item "       - em-breve.qmd"
        Write-Item "       - parte-1/cap-01-por-que-doe.qmd"
        Write-Item ""
        Write-Item "  B) Como RESOURCE (URL avulsa em /em-breve.html, fora do livro):"
        Write-Item "     project:"
        Write-Item "       resources:"
        Write-Item "         - em-breve.qmd"
        Write-Item ""
        Write-Item "RECOMENDACAO: registrar como CHAPTER e ocultar do sumario com sidebar:false"

        Set-Verificacao $progresso "3" "Registro _quarto.yml" "ERRO" "em-breve.qmd nao listado" "Adicionar em chapters: ou resources:" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 4 - FORMULARIO BREVO INTEGRADO
# ============================================================================
function Verificar-Brevo($progresso) {
    Write-Etapa "4" "Formulario Brevo integrado"

    if (-not (Test-Path $Script:ArqQMD)) {
        Write-Err "em-breve.qmd nao existe (rode Etapa 1 primeiro)"
        Set-Verificacao $progresso "4" "Brevo integrado" "ERRO" "em-breve.qmd ausente" "Etapa 1 primeiro" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $conteudo = Get-Content $Script:ArqQMD -Raw -Encoding UTF8

    # Marcadores de Brevo
    $marcadores = @(
        'sib-form',
        'sib-container',
        'sib_form',
        'brevo\.com',
        'sendinblue\.com',
        'BREVO_FORM'
    )

    $encontrados = @()
    foreach ($m in $marcadores) {
        if ($conteudo -match $m) {
            $encontrados += $m
        }
    }

    if ($encontrados.Count -eq 0) {
        Write-Warn "Nenhum marcador de Brevo encontrado no em-breve.qmd"
        Write-Item ""
        Write-Item "Para integrar o formulario Brevo:"
        Write-Item ""
        Write-Item "  1. Login em Brevo (app.brevo.com)"
        Write-Item "  2. Contatos > Formularios > Criar Formulario"
        Write-Item "  3. Nome sugerido: 'Livro DOE - Pre-lancamento'"
        Write-Item "  4. Campos: email + nome (opcional)"
        Write-Item "  5. Lista destino: 'Livro DOE Pre-lancamento'"
        Write-Item "  6. Dupla opt-in: ATIVAR (LGPD)"
        Write-Item "  7. Copiar embed code (HTML)"
        Write-Item "  8. Colar no em-breve.qmd substituindo o PLACEHOLDER"
        Write-Item ""
        Write-Item "Placeholder atual no template: <!-- BREVO FORM PLACEHOLDER -->"

        if (Ask-YesNo "Abrir Brevo agora?" "N") {
            Start-Process "https://app.brevo.com/contact/list"
        }

        Set-Verificacao $progresso "4" "Formulario Brevo" "ERRO" "Nao integrado" "Copiar embed do Brevo para em-breve.qmd" | Out-Null

    } elseif ($encontrados -contains 'BREVO_FORM') {
        Write-Warn "Placeholder do Brevo presente (nao substituido)"
        Write-Item "Marcadores encontrados: $($encontrados -join ', ')"
        Write-Item "Substituir <!-- BREVO_FORM_PLACEHOLDER --> pelo embed real do Brevo"

        Set-Verificacao $progresso "4" "Formulario Brevo" "AVISO" "Placeholder, embed real ausente" "Substituir placeholder" | Out-Null

    } else {
        Write-OK "Formulario Brevo integrado"
        Write-Item "  Marcadores: $($encontrados -join ', ')"

        # Detalhes adicionais
        if ($conteudo -match 'action="([^"]+brevo[^"]*)"') {
            Write-Item "  Endpoint: $($Matches[1])"
        }
        if ($conteudo -match 'name="EMAIL"|type="email"') {
            Write-Item "  Campo email: presente"
        }
        if ($conteudo -match 'sib_captcha|hcaptcha|recaptcha') {
            Write-Item "  Captcha: presente (anti-spam)"
        }

        Set-Verificacao $progresso "4" "Formulario Brevo" "OK" "Integrado com marcadores: $($encontrados -join ', ')" "" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 5 - PROMESSA DO CAPITULO GRATUITO
# ============================================================================
function Verificar-Promessa($progresso) {
    Write-Etapa "5" "Promessa do capitulo gratuito no texto"

    if (-not (Test-Path $Script:ArqQMD)) {
        Write-Err "em-breve.qmd nao existe"
        Set-Verificacao $progresso "5" "Promessa capitulo gratuito" "ERRO" "em-breve.qmd ausente" "" | Out-Null
        Save-Progresso $progresso
        Update-Documentacao $progresso
        return
    }

    $conteudo = Get-Content $Script:ArqQMD -Raw -Encoding UTF8
    $conteudoLower = $conteudo.ToLower()

    # Buscar padroes de promessa
    $temCapitulo = ($conteudoLower -match 'capitulo|cap[00ED]tulo')
    $temGratuito = ($conteudoLower -match 'gratuito|gratuita|gr[00E1]tis|amostra')
    $temAmostra  = ($conteudoLower -match 'amostra|sample|preview|trecho')

    $score = 0
    if ($temCapitulo) { $score++ }
    if ($temGratuito) { $score++ }
    if ($temAmostra)  { $score++ }

    Write-Info "Detectores de promessa:"
    if ($temCapitulo) { Write-OK  "  'capitulo' - encontrado" }
    else              { Write-Warn "  'capitulo' - ausente" }

    if ($temGratuito) { Write-OK  "  'gratuito/gratis' - encontrado" }
    else              { Write-Warn "  'gratuito/gratis' - ausente" }

    if ($temAmostra)  { Write-OK  "  'amostra/preview' - encontrado" }
    else              { Write-Warn "  'amostra/preview' - ausente" }

    if ($score -ge 2) {
        Write-OK "Promessa detectada ($score/3 palavras-chave)"
        Set-Verificacao $progresso "5" "Promessa capitulo gratuito" "OK" "$score/3 palavras-chave" "" | Out-Null
    } elseif ($score -eq 1) {
        Write-Warn "Promessa parcial ($score/3)"
        Write-Item ""
        Write-Item "Considere adicionar frase tipo:"
        Write-Item "  'Ao se inscrever, voce recebe um capitulo completo do livro'"
        Write-Item "  'gratuitamente quando ele for publicado.'"
        Set-Verificacao $progresso "5" "Promessa capitulo gratuito" "AVISO" "$score/3 palavras-chave" "Reforcar promessa no texto" | Out-Null
    } else {
        Write-Err "Promessa NAO detectada"
        Write-Item ""
        Write-Item "A promessa e a razao do usuario dar email (conversao)"
        Write-Item "Sugestao de secao para adicionar:"
        Write-Item ""
        Write-Item "  ### Reserve seu capitulo gratuito"
        Write-Item "  Ao se inscrever, voce recebe um capitulo completo"
        Write-Item "  do livro gratuitamente quando ele for publicado."
        Set-Verificacao $progresso "5" "Promessa capitulo gratuito" "ERRO" "Nao detectada" "Adicionar promessa clara no texto" | Out-Null
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# ETAPA 6 - URL PUBLICA RESPONDE
# ============================================================================
function Verificar-Deploy($progresso) {
    Write-Etapa "6" "URL publica responde (deploy funcional)"

    Write-Info "Testando: $($Script:UrlPublica)"

    try {
        $resp = Invoke-WebRequest -Uri $Script:UrlPublica -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop

        if ($resp.StatusCode -eq 200) {
            $tamanho = $resp.Content.Length
            Write-OK "HTTP 200 - Landing acessivel"
            Write-Item "  Tamanho: $tamanho bytes"

            # Verificar se conteudo tem elementos esperados
            $conteudoWeb = $resp.Content
            $checkList = @()

            if ($conteudoWeb -match 'em breve|Em breve|EM BREVE') {
                Write-OK "  Titulo 'Em breve' presente na pagina"
                $checkList += "titulo"
            }
            if ($conteudoWeb -match 'sib-form|brevo|sendinblue') {
                Write-OK "  Formulario Brevo detectado no HTML publicado"
                $checkList += "brevo"
            }
            if ($conteudoWeb -match 'capitulo|cap[00ED]tulo') {
                Write-OK "  Menciona 'capitulo' (promessa presente)"
                $checkList += "promessa"
            }

            Set-Verificacao $progresso "6" "URL publica" "OK" "HTTP 200 - $($checkList -join ', ')" "" | Out-Null
        } else {
            Write-Warn "HTTP $($resp.StatusCode)"
            Set-Verificacao $progresso "6" "URL publica" "AVISO" "HTTP $($resp.StatusCode)" "" | Out-Null
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match '404') {
            Write-Err "HTTP 404 - Pagina nao encontrada"
            Write-Item ""
            Write-Item "Possiveis causas:"
            Write-Item "  1. em-breve.qmd nao esta registrado no _quarto.yml (Etapa 3)"
            Write-Item "  2. Ultimo deploy do GitHub Actions falhou"
            Write-Item "  3. Deploy ainda em progresso (aguardar 2-3 min)"
            Write-Item ""
            Write-Item "Verificar workflow:"
            Write-Item "  gh run list --repo mariocezar1971/livro-doe-usinagem --limit 3"
            Set-Verificacao $progresso "6" "URL publica" "ERRO" "HTTP 404" "Verificar registro no _quarto.yml e deploy" | Out-Null
        } else {
            Write-Err "Erro: $msg"
            Set-Verificacao $progresso "6" "URL publica" "ERRO" $msg "Investigar" | Out-Null
        }
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# MOSTRAR STATUS
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "STATUS FASE 1.3 - Landing Page de Captura"
    Write-Info "Iniciada em: $($progresso.iniciada_em)"
    Write-Info "Atualizada:  $($progresso.atualizada_em)"
    Write-Info "URL publica: $($Script:UrlPublica)"
    Write-Host ""

    $nomes = @{
        "1" = "em-breve.qmd conteudo"
        "2" = "em-breve.css visual"
        "3" = "Registro _quarto.yml"
        "4" = "Formulario Brevo"
        "5" = "Promessa capitulo gratis"
        "6" = "URL publica responde"
    }

    for ($i = 1; $i -le 6; $i++) {
        $v = Get-Verificacao $progresso "$i"
        if ($v) {
            $indicador = switch ($v.status) {
                "OK"       { "[OK]" }
                "AVISO"    { "[!] " }
                "ERRO"     { "[X] " }
                default    { "[?] " }
            }
            $cor = switch ($v.status) {
                "OK"       { "Green" }
                "AVISO"    { "Yellow" }
                "ERRO"     { "Red" }
                default    { "Gray" }
            }
            $texto = if ($v.detalhes) { $v.detalhes } else { "OK" }
        } else {
            $indicador = "[  ]"
            $cor = "Gray"
            $texto = "(nao verificado)"
        }

        $linha = "  {0} {1,-30} {2}" -f $indicador, $nomes["$i"], $texto
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Progresso salvo em: $Script:ArquivoProgresso"
    Write-Info "Documentacao em:    $Script:ArquivoDoc"
}

# ============================================================================
# COMANDOS UTEIS
# ============================================================================
function Mostrar-Comandos {
    Write-Titulo "COMANDOS UTEIS - Fase 1.3"

    Write-Host ""
    Write-Info "Deploy manual (Actions renderiza no servidor):"
    Write-Host "  git add em-breve.qmd em-breve.css _quarto.yml" -ForegroundColor White
    Write-Host '  git commit -m "Fase 1.3: landing page atualizada"' -ForegroundColor White
    Write-Host "  git push" -ForegroundColor White

    Write-Host ""
    Write-Info "Acompanhar deploy:"
    Write-Host "  Start-Sleep -Seconds 15" -ForegroundColor White
    Write-Host "  `$runId = gh run list --repo mariocezar1971/livro-doe-usinagem --limit 1 --json databaseId --jq '.[0].databaseId'" -ForegroundColor White
    Write-Host "  gh run watch `$runId --repo mariocezar1971/livro-doe-usinagem" -ForegroundColor White

    Write-Host ""
    Write-Info "Abrir landing publica:"
    Write-Host "  Start-Process '$($Script:UrlPublica)'" -ForegroundColor White

    Write-Host ""
    Write-Info "Preview local (sem push):"
    Write-Host "  quarto preview em-breve.qmd" -ForegroundColor White
}

# ============================================================================
# EXECUTAR TODAS AS 6 ETAPAS
# ============================================================================
function Executar-Todas($progresso) {
    Write-Titulo "FASE 1.3 - LANDING PAGE DE CAPTURA DE EMAILS"

    Write-Info "6 verificacoes/acoes:"
    Write-Item "  1. em-breve.qmd existe e tem conteudo"
    Write-Item "  2. em-breve.css presente (visual)"
    Write-Item "  3. Registrada no _quarto.yml"
    Write-Item "  4. Formulario Brevo integrado"
    Write-Item "  5. Promessa do capitulo gratuito"
    Write-Item "  6. URL publica responde"
    Write-Host ""

    if (-not (Ask-YesNo "Prosseguir?")) { return }

    Verificar-QMD      $progresso
    Verificar-CSS      $progresso
    Verificar-YAML     $progresso
    Verificar-Brevo    $progresso
    Verificar-Promessa $progresso
    Verificar-Deploy   $progresso

    Write-Host ""
    Write-Titulo "FASE 1.3 - VERIFICACAO CONCLUIDA"
    Mostrar-Status $progresso

    $oks    = @($progresso.verificacoes | Where-Object { $_.status -eq "OK" }).Count
    $avisos = @($progresso.verificacoes | Where-Object { $_.status -eq "AVISO" }).Count
    $erros  = @($progresso.verificacoes | Where-Object { $_.status -eq "ERRO" }).Count

    Write-Host ""
    if ($oks -eq 6) {
        Write-OK "LANDING 100% PRONTA! ($oks/6 OK)"
        Mostrar-Comandos
    } elseif ($oks -ge 4) {
        Write-Warn "Landing parcialmente pronta ($oks OK, $avisos avisos, $erros erros)"
        Write-Item "Consulte $Script:ArquivoDoc para acoes"
    } else {
        Write-Err "Landing incompleta ($oks OK, $avisos avisos, $erros erros)"
        Write-Item "Consulte $Script:ArquivoDoc para acoes"
    }
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
}

if ($Reset) {
    if (Ask-YesNo "ATENCAO: apagar verificacoes. Confirmar?" "N") {
        Remove-Item $Script:ArquivoProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArquivoDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

$progresso = Initialize-Progresso

if ($Status) {
    Mostrar-Status $progresso
    Write-Host ""
    Mostrar-Comandos
    exit 0
}

if ($Etapa -gt 0) {
    switch ($Etapa) {
        1 { Verificar-QMD      $progresso }
        2 { Verificar-CSS      $progresso }
        3 { Verificar-YAML     $progresso }
        4 { Verificar-Brevo    $progresso }
        5 { Verificar-Promessa $progresso }
        6 { Verificar-Deploy   $progresso }
    }
    Write-Host ""
    Mostrar-Status $progresso
    exit 0
}

Executar-Todas $progresso

Write-Host ""
Write-OK "Encerrando. Progresso salvo em $Script:ArquivoProgresso"
Write-Info "Retomar com: .\executar-fase-1-3.ps1 -Status"
