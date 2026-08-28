#Requires -Version 5.1
<#
================================================================================
 ORQUESTRADOR - FASE 1.4 : CONFIGURACAO DE SEO                          (v2.0)
 Livro: Planejamento de Experimentos em Usinagem
================================================================================

 COMO EXECUTAR (2 linhas SEPARADAS - nao junte na mesma linha):

     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     .\executar-fase-1-4.ps1

 Ou, na mesma linha, usando ponto-e-virgula:

     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; .\executar-fase-1-4.ps1

 Permanente (uma vez por usuario):
     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

--------------------------------------------------------------------------------
 ETAPAS
--------------------------------------------------------------------------------
   [0]  Pre-voo: ambiente, git, quarto, encoding do console
   [1]  Guarda de integridade do _quarto.yml (anti-mojibake, anti-BOM)
   [2]  Dropbox: detectar, pausar, matar locks, limpar cache
   [3]  Distribuir arquivos SEO (idempotente)
   [4]  site-url -> github.io (ate o dominio proprio existir)
   [5]  sitemap: true + include-in-header (schema-book.html, seo-meta.html)
   [6]  Google Search Console: verificacao por Tag HTML ou Arquivo HTML
   [7]  Analytics (GA4 / Plausible / Umami / nenhum)
   [8]  Render HTML (com retry automatico em caso de lock do Dropbox)
   [9]  Validar meta tags no HTML gerado
   [10] Diagnostico e validacao do sitemap.xml + robots.txt
   [11] Commit + push
   [12] Verificar deploy no GitHub Pages
   [13] Resumo, pendencias manuais e log de auditoria

--------------------------------------------------------------------------------
 PARAMETROS
--------------------------------------------------------------------------------
   -ProjetoRaiz <caminho>   Raiz do projeto (default: pasta do proprio script)
   -Analytics <opcao>       ga4 | plausible | umami | nenhum | perguntar
   -Auto                    Nao interativo: usa os defaults recomendados
   -SomenteDiagnostico      Nao altera nada; so inspeciona e relata
   -SkipRender              Pula o quarto render
   -SkipCommit              Pula commit/push
   -SkipDeploy              Pula a verificacao de deploy
   -ForcarLimpeza           Limpa .quarto/_book/_freeze mesmo sem erro previo

 EXEMPLOS
   .\executar-fase-1-4.ps1
   .\executar-fase-1-4.ps1 -SomenteDiagnostico
   .\executar-fase-1-4.ps1 -Auto -Analytics nenhum
   .\executar-fase-1-4.ps1 -SkipRender -SkipDeploy

--------------------------------------------------------------------------------
 REGRAS DE OURO (aprendidas na marra)
--------------------------------------------------------------------------------
   * Este arquivo e 100% ASCII puro. Nunca inserir acentos aqui.
   * Toda escrita em _quarto.yml usa [System.IO.File]::WriteAllText com
     UTF8Encoding($false) - SEM BOM. Nunca usar Set-Content -Encoding UTF8
     no PowerShell 5.1 (gera mojibake do tipo "otimizaXXXao").
   * As edicoes do YAML sao linha a linha e preservam a quebra de linha
     original de cada linha - o diff no git fica minimo.
   * Novos itens de lista entram LOGO ABAIXO da chave, nunca no fim: o
     include-in-header termina com um bloco "- text: |" e inserir depois
     dele quebraria o YAML.
   * Sitemap no Search Console: digitar apenas "sitemap.xml", sem barra inicial.
   * Erro "os error 32" = Dropbox segurando .quarto/idx -> etapa [2].
================================================================================
#>

[CmdletBinding()]
param(
    [string] $ProjetoRaiz = "",

    [ValidateSet("ga4", "plausible", "umami", "nenhum", "perguntar")]
    [string] $Analytics = "perguntar",

    [switch] $Auto,
    [switch] $SomenteDiagnostico,
    [switch] $SkipRender,
    [switch] $SkipCommit,
    [switch] $SkipDeploy,
    [switch] $ForcarLimpeza
)

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# ------------------------------------------------------------------------------
# CONSTANTES
# ------------------------------------------------------------------------------
$RaizPadrao   = "C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"
$UrlPublica   = "https://mariocezar1971.github.io/livro-doe-usinagem/"
$HostPublico  = "mariocezar1971.github.io"
$SiteUrlYml   = "https://mariocezar1971.github.io/livro-doe-usinagem"
$RepoGitHub   = "mariocezar1971/livro-doe-usinagem"
$PerfilUsuario = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$PastaTemp     = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }

$Downloads    = Join-Path $PerfilUsuario "Downloads"
$ZipPath      = Join-Path $Downloads "FASE_1_4.zip"
$TempDir      = Join-Path $PastaTemp "fase_1_4"
$LogAuditoria = Join-Path $PerfilUsuario ".livro-doe-deploys.log"

$script:Avisos     = New-Object System.Collections.ArrayList
$script:Pendencias = New-Object System.Collections.ArrayList

# ==============================================================================
# HELPERS DE SAIDA
# ==============================================================================
function Write-Cabecalho($texto) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkCyan
    Write-Host " $texto" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor DarkCyan
}

function Write-Etapa($numero, $titulo) {
    Write-Host ""
    Write-Host ("-" * 80) -ForegroundColor DarkGray
    Write-Host "[$numero] $titulo" -ForegroundColor Cyan
    Write-Host ("-" * 80) -ForegroundColor DarkGray
}

function Write-Ok($m)    { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Info($m)  { Write-Host "  [i]  $m" -ForegroundColor Gray  }
function Write-Passo($m) { Write-Host "       $m" -ForegroundColor DarkGray }

function Write-Aviso($m) {
    Write-Host "  [!]  $m" -ForegroundColor Yellow
    [void]$script:Avisos.Add($m)
}

function Write-Falha($m) {
    Write-Host "  [X]  $m" -ForegroundColor Red
    [void]$script:Avisos.Add("FALHA: $m")
}

function Add-Pendencia($m) { [void]$script:Pendencias.Add($m) }

function Abortar($m) {
    Write-Host ""
    Write-Host "  ERRO FATAL: $m" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ==============================================================================
# HELPERS DE INTERACAO
# ==============================================================================
function Confirmar {
    param([string] $Pergunta, [bool] $Padrao = $true)

    if ($SomenteDiagnostico) { return $false }
    $rotulo = if ($Padrao) { "S/n" } else { "s/N" }

    if ($Auto) {
        $txt = if ($Padrao) { "SIM" } else { "NAO" }
        Write-Host "  ?    $Pergunta ($rotulo) -> [auto] $txt" -ForegroundColor DarkYellow
        return $Padrao
    }

    $r = Read-Host "  ?    $Pergunta ($rotulo)"
    if ([string]::IsNullOrWhiteSpace($r)) { return $Padrao }
    $r = $r.Trim().ToUpper()
    return ($r -eq "S" -or $r -eq "SIM" -or $r -eq "Y" -or $r -eq "YES")
}

function Pausar($mensagem) {
    if ($Auto -or $SomenteDiagnostico) { return }
    Write-Host ""
    Write-Host "       $mensagem" -ForegroundColor Yellow
    [void](Read-Host "       Pressione ENTER para continuar")
}

# ==============================================================================
# HELPERS DE ARQUIVO (UTF-8 SEM BOM VIA .NET - NUNCA Set-Content -Encoding UTF8)
# ==============================================================================
function Get-CaminhoAbsoluto {
    param([string] $Caminho)
    if (Test-Path $Caminho) { return (Resolve-Path $Caminho).Path }
    # Combine trata corretamente caminhos ja absolutos (nao concatena a raiz duas vezes)
    return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $Caminho))
}

function Read-FileUtf8 {
    param([string] $Caminho)
    return [System.IO.File]::ReadAllText((Get-CaminhoAbsoluto $Caminho), [System.Text.Encoding]::UTF8)
}

function Write-FileUtf8NoBom {
    param([string] $Caminho, [string] $Conteudo)
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Get-CaminhoAbsoluto $Caminho), $Conteudo, $utf8SemBom)
}

# Detecta mojibake: UTF-8 duplamente codificado (C3 83 = "A-til" espurio)
function Test-Mojibake {
    param([string] $Caminho)
    if (-not (Test-Path $Caminho)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes((Get-CaminhoAbsoluto $Caminho))
    for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
        if ($bytes[$i] -eq 0xC3 -and $bytes[$i + 1] -eq 0x83) { return $true }
    }
    return $false
}

function Backup-Arquivo {
    param([string] $Caminho, [string] $Sufixo)
    if (-not (Test-Path $Caminho)) { return }
    $destino = "$Caminho.bak_$Sufixo"
    Copy-Item $Caminho $destino -Force
    Write-Passo "backup -> $(Split-Path $destino -Leaf)"
}

# ==============================================================================
# EDITOR DE YAML LINHA A LINHA, PRESERVANDO A QUEBRA DE LINHA DE CADA LINHA
# ==============================================================================
function Get-YmlDoc {
    param([string] $Caminho)

    $texto = [System.IO.File]::ReadAllText((Get-CaminhoAbsoluto $Caminho), [System.Text.Encoding]::UTF8)
    $linhas = New-Object System.Collections.ArrayList
    $eols   = New-Object System.Collections.ArrayList

    $consumido = 0
    foreach ($m in [regex]::Matches($texto, "([^\r\n]*)(\r\n|\n|\r)")) {
        [void]$linhas.Add($m.Groups[1].Value)
        [void]$eols.Add($m.Groups[2].Value)
        $consumido = $m.Index + $m.Length
    }
    if ($consumido -lt $texto.Length) {
        [void]$linhas.Add($texto.Substring($consumido))
        [void]$eols.Add("")
    }

    # quebra de linha dominante, usada para linhas novas
    $crlf = ([regex]::Matches($texto, "\r\n")).Count
    $lf   = ([regex]::Matches($texto, "(?<!\r)\n")).Count
    $eolPadrao = if ($crlf -ge $lf) { "`r`n" } else { "`n" }

    return @{ Linhas = $linhas; Eols = $eols; EolPadrao = $eolPadrao }
}

function Save-YmlDoc {
    param($Doc, [string] $Caminho)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Doc.Linhas.Count; $i++) {
        [void]$sb.Append($Doc.Linhas[$i])
        [void]$sb.Append($Doc.Eols[$i])
    }
    Write-FileUtf8NoBom $Caminho $sb.ToString()
}

function Get-YmlTexto {
    param($Doc)
    return ($Doc.Linhas -join "`n")
}

function Add-LinhaYml {
    param($Doc, [int] $Depois, [string] $Texto)
    $eol = if ($Doc.Eols[$Depois] -ne "") { $Doc.Eols[$Depois] } else { $Doc.EolPadrao }
    if ($Doc.Eols[$Depois] -eq "") { $Doc.Eols[$Depois] = $Doc.EolPadrao }
    $Doc.Linhas.Insert($Depois + 1, $Texto)
    $Doc.Eols.Insert($Depois + 1, $eol)
}

function Remove-LinhaYml {
    param($Doc, [int] $Indice)
    $Doc.Linhas.RemoveAt($Indice)
    $Doc.Eols.RemoveAt($Indice)
}

# Delimita o bloco filho de uma chave. Retorna @{Inicio; Fim} ou $null.
function Get-BlocoYml {
    param($Doc, [string] $Chave, [int] $RecuoFilho)

    $inicio = -1
    for ($i = 0; $i -lt $Doc.Linhas.Count; $i++) {
        if ($Doc.Linhas[$i].TrimEnd() -eq $Chave) { $inicio = $i; break }
    }
    if ($inicio -lt 0) { return $null }

    $fim = $Doc.Linhas.Count
    for ($i = $inicio + 1; $i -lt $Doc.Linhas.Count; $i++) {
        $l = $Doc.Linhas[$i]
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $recuo = $l.Length - $l.TrimStart().Length
        if ($recuo -lt $RecuoFilho) { $fim = $i; break }
    }
    return @{ Inicio = $inicio; Fim = $fim }
}

# Localiza uma chave dentro de um bloco. Retorna o indice da linha ou -1.
function Find-ChaveNoBloco {
    param($Doc, $Bloco, [string] $Padrao)
    if ($null -eq $Bloco) { return -1 }
    for ($i = $Bloco.Inicio + 1; $i -lt $Bloco.Fim; $i++) {
        if ($Doc.Linhas[$i] -match $Padrao) { return $i }
    }
    return -1
}

# Insere "- valor" LOGO ABAIXO da chave da lista.
# Inserir no fim seria arriscado: o include-in-header termina com "- text: |"
# seguido de um bloco literal indentado, e um item novo depois disso quebraria
# o YAML. O topo da lista e sempre seguro e a ordem nao importa aqui.
function Add-ItemListaYml {
    param($Doc, [int] $IdxChave, [int] $RecuoPadrao, [string] $Valor)

    $recuo = $RecuoPadrao
    for ($i = $IdxChave + 1; $i -lt $Doc.Linhas.Count; $i++) {
        $l = $Doc.Linhas[$i]
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $r = $l.Length - $l.TrimStart().Length
        if ($l.TrimStart().StartsWith("- ") -and $r -gt ($Doc.Linhas[$IdxChave].Length - $Doc.Linhas[$IdxChave].TrimStart().Length)) {
            $recuo = $r
        }
        break
    }
    Add-LinhaYml -Doc $Doc -Depois $IdxChave -Texto ((" " * $recuo) + "- " + $Valor)
    return $recuo
}

function Assert-YmlIntegro {
    param([string] $Caminho)
    if (Test-Mojibake $Caminho) {
        Abortar "A escrita corrompeu o _quarto.yml. Restaure com: git checkout HEAD -- _quarto.yml"
    }
}

# ==============================================================================
# DROPBOX / LOCKS
# ==============================================================================
function Test-DentroDoDropbox {
    param([string] $Caminho)
    return ($Caminho -match "(?i)\\Dropbox\\")
}

function Stop-ProcessosQuarto {
    $alvos = Get-Process -ErrorAction SilentlyContinue |
             Where-Object { $_.ProcessName -match "(?i)^(quarto|deno|pandoc|esbuild)$" }
    if ($alvos) {
        foreach ($p in $alvos) {
            Write-Passo "encerrando $($p.ProcessName) (PID $($p.Id))"
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        return $true
    }
    return $false
}

function Remove-PastaComRetry {
    param([string] $Pasta, [int] $Tentativas = 4)
    if (-not (Test-Path $Pasta)) { return $true }
    for ($t = 1; $t -le $Tentativas; $t++) {
        Remove-Item $Pasta -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $Pasta)) { return $true }
        Write-Passo "tentativa $t/$Tentativas falhou em '$Pasta' - aguardando..."
        [void](Stop-ProcessosQuarto)
        Start-Sleep -Seconds (2 * $t)
    }
    return (-not (Test-Path $Pasta))
}

function Clear-CacheQuarto {
    $pastas = @(".quarto", "_book", "_freeze")
    $tudoOk = $true
    foreach ($p in $pastas) {
        if (Test-Path $p) {
            if (Remove-PastaComRetry -Pasta $p) {
                Write-Ok "removido: $p"
            } else {
                Write-Falha "nao foi possivel remover: $p (Dropbox ainda segurando?)"
                $tudoOk = $false
            }
        }
    }
    foreach ($p in $pastas) { Write-Passo ("{0,-9} existe: {1}" -f $p, (Test-Path $p)) }
    return $tudoOk
}

# ==============================================================================
# INICIO
# ==============================================================================
Write-Cabecalho "FASE 1.4 - CONFIGURACAO DE SEO   (orquestrador v2.0)"

if ($SomenteDiagnostico) {
    Write-Host ""
    Write-Host "  MODO DIAGNOSTICO: nada sera gravado, apenas inspecionado." -ForegroundColor Magenta
}

# ------------------------------------------------------------------------------
# [0] PRE-VOO
# ------------------------------------------------------------------------------
Write-Etapa 0 "Pre-voo: ambiente"

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

if ([string]::IsNullOrWhiteSpace($ProjetoRaiz)) {
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "_quarto.yml"))) {
        $ProjetoRaiz = $PSScriptRoot
    } elseif (Test-Path (Join-Path (Get-Location).Path "_quarto.yml")) {
        $ProjetoRaiz = (Get-Location).Path
    } else {
        $ProjetoRaiz = $RaizPadrao
    }
}

if (-not (Test-Path $ProjetoRaiz)) { Abortar "Pasta do projeto nao existe: $ProjetoRaiz" }
Set-Location $ProjetoRaiz
$ProjetoRaiz = (Get-Location).Path
Write-Ok "Projeto: $ProjetoRaiz"

if (-not (Test-Path "_quarto.yml")) { Abortar "_quarto.yml nao encontrado em $ProjetoRaiz" }
$ymlPath = (Resolve-Path "_quarto.yml").Path
Write-Ok "_quarto.yml localizado"

$temGit = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if ($temGit) {
    $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
    Write-Ok "git disponivel (branch: $branch)"
} else {
    Write-Aviso "git nao encontrado no PATH - etapas [11] e [12] ficam limitadas"
}

$temQuarto = $null -ne (Get-Command quarto -ErrorAction SilentlyContinue)
if ($temQuarto) {
    Write-Ok "quarto disponivel (v$(quarto --version 2>$null))"
} else {
    Write-Aviso "quarto nao encontrado no PATH - etapa [8] sera pulada"
}

$temGh = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if ($temGh) { Write-Ok "gh CLI disponivel" } else { Write-Info "gh CLI ausente (deploy sera checado por HTTP)" }

Write-Info "ExecutionPolicy (Process): $(Get-ExecutionPolicy -Scope Process)"

# ------------------------------------------------------------------------------
# [1] GUARDA DE INTEGRIDADE DO _quarto.yml
# ------------------------------------------------------------------------------
Write-Etapa 1 "Guarda de integridade do _quarto.yml"

if (Test-Mojibake $ymlPath) {
    Write-Aviso "_quarto.yml CORROMPIDO - mojibake detectado (acentos duplamente codificados)"
    Write-Passo "causa tipica: Set-Content -Encoding UTF8 no PowerShell 5.1"
    if ($SomenteDiagnostico) {
        Write-Passo "correcao: git checkout HEAD -- _quarto.yml"
    } elseif ($temGit -and (Confirmar "Restaurar do Git (git checkout HEAD -- _quarto.yml)?" $true)) {
        Backup-Arquivo $ymlPath "corrompido"
        git checkout HEAD -- _quarto.yml
        Assert-YmlIntegro $ymlPath
        Write-Ok "_quarto.yml restaurado do Git"
    } else {
        Abortar "Nao e seguro prosseguir com o _quarto.yml corrompido."
    }
} else {
    Write-Ok "sem mojibake"
}

$bytesYml = [System.IO.File]::ReadAllBytes($ymlPath)
if ($bytesYml.Length -ge 3 -and $bytesYml[0] -eq 0xEF -and $bytesYml[1] -eq 0xBB -and $bytesYml[2] -eq 0xBF) {
    Write-Aviso "_quarto.yml tem BOM UTF-8 (o Quarto pode reclamar)"
    if (-not $SomenteDiagnostico -and (Confirmar "Remover o BOM?" $true)) {
        Backup-Arquivo $ymlPath "bom"
        Write-FileUtf8NoBom $ymlPath (Read-FileUtf8 $ymlPath)
        Write-Ok "BOM removido"
    }
} else {
    Write-Ok "sem BOM"
}

# ------------------------------------------------------------------------------
# [2] DROPBOX E LOCKS
# ------------------------------------------------------------------------------
Write-Etapa 2 "Dropbox e locks de arquivo (causa do 'os error 32')"

$dentroDropbox = Test-DentroDoDropbox $ProjetoRaiz
$procDropbox   = Get-Process -Name "Dropbox" -ErrorAction SilentlyContinue

if ($dentroDropbox) {
    Write-Aviso "o projeto esta DENTRO de uma pasta do Dropbox"
    Write-Passo "solucao permanente: Explorer > botao direito na pasta > Dropbox > Ignorar"
    Write-Passo "aplicar a: .quarto, _book, _freeze"
    Add-Pendencia "Marcar .quarto, _book e _freeze como 'Ignorar' no Dropbox (mata o 'os error 32' de vez)"
} else {
    Write-Ok "projeto fora do Dropbox - sem risco de lock de sincronizacao"
}

if ($procDropbox) {
    Write-Aviso "processo do Dropbox ATIVO (PID $($procDropbox[0].Id))"
    if (-not $SomenteDiagnostico -and -not $SkipRender) {
        Write-Passo "pause a sincronizacao: icone na bandeja > engrenagem > Pausar sincronizacao > 3 horas"
        Pausar "Confirme que o Dropbox esta PAUSADO antes de continuar."
    }
} else {
    Write-Ok "Dropbox nao esta em execucao"
}

if ($SomenteDiagnostico) {
    foreach ($p in @(".quarto", "_book", "_freeze")) {
        Write-Passo ("{0,-9} existe: {1}" -f $p, (Test-Path $p))
    }
} elseif ($ForcarLimpeza -or -not $SkipRender) {
    if (Stop-ProcessosQuarto) { Write-Ok "processos quarto/deno encerrados" }
    else { Write-Info "nenhum processo quarto/deno travado" }

    if ($ForcarLimpeza -or (Confirmar "Limpar cache (.quarto, _book, _freeze) antes do render?" $true)) {
        if (Clear-CacheQuarto) {
            Write-Ok "cache limpo"
        } else {
            Write-Aviso "cache nao foi totalmente limpo"
            Write-Passo "1) confirme VISUALMENTE que o Dropbox esta pausado na bandeja"
            Write-Passo "2) se pausado e o erro persistir, mova o projeto para fora do Dropbox"
        }
    }
}

# ------------------------------------------------------------------------------
# [3] DISTRIBUIR ARQUIVOS SEO
# ------------------------------------------------------------------------------
Write-Etapa 3 "Distribuir arquivos SEO (idempotente)"

$destinos = [ordered]@{
    "styles/schema-book.html"         = "styles\schema-book.html"
    "styles/seo-meta.html"            = "styles\seo-meta.html"
    "styles/analytics-ga4.html"       = "styles\analytics-ga4.html"
    "styles/analytics-plausible.html" = "styles\analytics-plausible.html"
    "styles/analytics-umami.html"     = "styles\analytics-umami.html"
    "setup/SEO_SETUP_GUIA.md"         = "setup\SEO_SETUP_GUIA.md"
}

$faltando = @()
foreach ($d in $destinos.Values) { if (-not (Test-Path $d)) { $faltando += $d } }

if ($faltando.Count -eq 0) {
    Write-Ok "os $($destinos.Count) arquivos SEO ja estao no lugar"
    $distribuir = Confirmar "Redistribuir a partir do ZIP mesmo assim?" $false
} else {
    Write-Aviso "faltando $($faltando.Count) arquivo(s):"
    foreach ($f in $faltando) { Write-Passo $f }
    $distribuir = (-not $SomenteDiagnostico)
}

if ($distribuir) {
    if (-not (Test-Path $ZipPath)) {
        Write-Falha "ZIP nao encontrado: $ZipPath"
        if ($faltando.Count -gt 0) { Abortar "Arquivos SEO ausentes e sem ZIP para distribuir." }
    } else {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
        New-Item -ItemType Directory -Path "styles" -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Directory -Path "setup"  -Force -ErrorAction SilentlyContinue | Out-Null

        foreach ($item in $destinos.GetEnumerator()) {
            $src = Join-Path $TempDir ($item.Key -replace "/", "\")
            if (Test-Path $src) {
                [System.IO.File]::Copy((Resolve-Path $src).Path, (Join-Path $ProjetoRaiz $item.Value), $true)
                Write-Ok "$($item.Key) -> $($item.Value)"
            } else {
                Write-Aviso "ausente no ZIP: $($item.Key)"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# [4] site-url
# ------------------------------------------------------------------------------
Write-Etapa 4 "site-url no _quarto.yml"

$ymlTexto = Read-FileUtf8 $ymlPath

if ($ymlTexto -match [regex]::Escape($SiteUrlYml)) {
    Write-Ok "site-url ja aponta para github.io"
    Write-Passo $SiteUrlYml
} elseif ($ymlTexto -match "site-url:\s*`"?https://doeusinagem\.com\.br") {
    Write-Aviso "site-url aponta para doeusinagem.com.br - dominio ainda nao registrado"
    Write-Passo "isso faz o sitemap.xml apontar para URLs que retornam 404"
    if (Confirmar "Trocar temporariamente para github.io?" $true) {
        Backup-Arquivo $ymlPath "v14_siteurl"
        $ymlTexto = $ymlTexto -replace 'site-url:\s*"?https://doeusinagem\.com\.br/?"?', ('site-url: "' + $SiteUrlYml + '"')
        Write-FileUtf8NoBom $ymlPath $ymlTexto
        Assert-YmlIntegro $ymlPath
        Write-Ok "site-url trocado para github.io"
        Write-Passo "ao registrar doeusinagem.com.br: reverter aqui e conferir o CNAME"
        Add-Pendencia "Registrar doeusinagem.com.br e reverter o site-url no _quarto.yml"
    }
} else {
    Write-Aviso "site-url em formato nao reconhecido - confira manualmente:"
    Select-String -Path $ymlPath -Pattern "site-url" | ForEach-Object { Write-Passo $_.Line.Trim() }
}

# ------------------------------------------------------------------------------
# [5] sitemap: true + include-in-header
# ------------------------------------------------------------------------------
Write-Etapa 5 "sitemap: true e include-in-header (schema + meta SEO)"

$doc = Get-YmlDoc $ymlPath
$blocoHtml = Get-BlocoYml -Doc $doc -Chave "  html:" -RecuoFilho 4

if ($null -eq $blocoHtml) {
    Write-Falha "secao 'format: html:' nao localizada - edite manualmente:"
    Write-Passo "format:"
    Write-Passo "  html:"
    Write-Passo "    sitemap: true"
    Write-Passo "    include-in-header:"
    Write-Passo "      - styles/schema-book.html"
    Write-Passo "      - styles/seo-meta.html"
} else {
    Write-Info "bloco 'html:' nas linhas $($blocoHtml.Inicio + 1)..$($blocoHtml.Fim)"
    $mudouYml = $false

    # --- sitemap: true ---
    if ((Find-ChaveNoBloco -Doc $doc -Bloco $blocoHtml -Padrao "^\s{4}sitemap:\s*true\s*$") -ge 0) {
        Write-Ok "'sitemap: true' presente"
    } else {
        Write-Aviso "'sitemap: true' ausente - sem isso o Quarto NAO gera sitemap.xml"
        if (Confirmar "Inserir 'sitemap: true' no bloco html?" $true) {
            if (-not $mudouYml) { Backup-Arquivo $ymlPath "v14"; $mudouYml = $true }
            Add-LinhaYml -Doc $doc -Depois $blocoHtml.Inicio -Texto "    sitemap: true"
            Write-Ok "'sitemap: true' inserido"
            $blocoHtml = Get-BlocoYml -Doc $doc -Chave "  html:" -RecuoFilho 4
        }
    }

    # --- include-in-header ---
    $trechoHtml = ($doc.Linhas[$blocoHtml.Inicio..($blocoHtml.Fim - 1)] -join "`n")
    $temSchema  = $trechoHtml -match "schema-book\.html"
    $temMeta    = $trechoHtml -match "seo-meta\.html"

    if ($temSchema -and $temMeta) {
        Write-Ok "schema-book.html e seo-meta.html ja incluidos"
    } elseif ($SomenteDiagnostico) {
        if (-not $temSchema) { Write-Aviso "schema-book.html NAO incluido" }
        if (-not $temMeta)   { Write-Aviso "seo-meta.html NAO incluido" }
    } else {
        if (-not $mudouYml) { Backup-Arquivo $ymlPath "v14_include"; $mudouYml = $true }
        $idxInclude = Find-ChaveNoBloco -Doc $doc -Bloco $blocoHtml -Padrao "^\s{4}include-in-header:\s*$"

        if ($idxInclude -lt 0) {
            Add-LinhaYml -Doc $doc -Depois $blocoHtml.Inicio -Texto "    include-in-header:"
            Add-LinhaYml -Doc $doc -Depois ($blocoHtml.Inicio + 1) -Texto "      - styles/schema-book.html"
            Add-LinhaYml -Doc $doc -Depois ($blocoHtml.Inicio + 2) -Texto "      - styles/seo-meta.html"
            Write-Ok "include-in-header criado com schema + meta"
        } else {
            if (-not $temMeta) {
                [void](Add-ItemListaYml -Doc $doc -IdxChave $idxInclude -RecuoPadrao 6 -Valor "styles/seo-meta.html")
                Write-Ok "seo-meta.html adicionado"
            }
            if (-not $temSchema) {
                [void](Add-ItemListaYml -Doc $doc -IdxChave $idxInclude -RecuoPadrao 6 -Valor "styles/schema-book.html")
                Write-Ok "schema-book.html adicionado"
            }
        }
    }

    if ($mudouYml) {
        Save-YmlDoc -Doc $doc -Caminho $ymlPath
        Assert-YmlIntegro $ymlPath
        Write-Ok "_quarto.yml gravado (UTF-8 sem BOM, integro)"
    }
}

# ------------------------------------------------------------------------------
# [6] GOOGLE SEARCH CONSOLE
# ------------------------------------------------------------------------------
Write-Etapa 6 "Google Search Console - verificacao de propriedade"

$verificado   = $false
$seoMetaPath  = "styles\seo-meta.html"
$arqGoogle    = $null

# --- 6a. Metodo TAG HTML: .\google-verification.html com a meta tag ---
if (Test-Path ".\google-verification.html") {
    Write-Info "google-verification.html detectado (metodo Tag HTML)"
    $tag = Read-FileUtf8 ".\google-verification.html"
    if ($tag -match 'content="([^"]+)"') {
        $token = $Matches[1]
        if (-not (Test-Path $seoMetaPath)) {
            Write-Falha "styles/seo-meta.html nao existe - rode a etapa [3] antes"
        } else {
            $seoMeta = Read-FileUtf8 $seoMetaPath
            if ($seoMeta -match "google-site-verification") {
                Write-Ok "token ja presente em seo-meta.html"
                $verificado = $true
            } elseif (-not $SomenteDiagnostico) {
                Backup-Arquivo $seoMetaPath "v14"
                $novaMeta = '<meta name="google-site-verification" content="' + $token + '">' + "`r`n"
                Write-FileUtf8NoBom $seoMetaPath ($novaMeta + $seoMeta)
                Remove-Item ".\google-verification.html" -Force -ErrorAction SilentlyContinue
                Write-Ok "token inserido em styles/seo-meta.html"
                $verificado = $true
            }
        }
    } else {
        Write-Falha "nao foi possivel extrair content=\"...\" de google-verification.html"
    }
}

# --- 6b. Metodo ARQUIVO HTML: googleXXXX.html na raiz ou em Downloads ---
$arqGoogle = Get-ChildItem -Path "." -Filter "google*.html" -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -ne "google-verification.html" } |
             Select-Object -First 1

if (-not $arqGoogle -and -not $SomenteDiagnostico -and (Test-Path $Downloads)) {
    $baixado = Get-ChildItem -Path $Downloads -Filter "google*.html" -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($baixado) {
        Write-Info "encontrado em Downloads: $($baixado.Name)"
        if (Confirmar "Mover para a raiz do projeto?" $true) {
            Move-Item $baixado.FullName (Join-Path $ProjetoRaiz $baixado.Name) -Force
            $arqGoogle = Get-Item (Join-Path $ProjetoRaiz $baixado.Name)
            Write-Ok "$($baixado.Name) movido para a raiz"
        }
    }
}

if ($arqGoogle) {
    Write-Info "arquivo de verificacao: $($arqGoogle.Name) (metodo Arquivo HTML)"
    $doc = Get-YmlDoc $ymlPath

    if ((Get-YmlTexto $doc) -match [regex]::Escape($arqGoogle.Name)) {
        Write-Ok "$($arqGoogle.Name) ja declarado em resources"
        $verificado = $true
    } elseif (-not $SomenteDiagnostico) {
        Backup-Arquivo $ymlPath "v14_resources"
        $blocoProj = Get-BlocoYml -Doc $doc -Chave "project:" -RecuoFilho 2
        $idxRes = Find-ChaveNoBloco -Doc $doc -Bloco $blocoProj -Padrao "^\s{2}resources:\s*$"

        if ($idxRes -ge 0) {
            [void](Add-ItemListaYml -Doc $doc -IdxChave $idxRes -RecuoPadrao 4 -Valor $arqGoogle.Name)
            Write-Ok "$($arqGoogle.Name) adicionado em project.resources"
        } else {
            $ultima = $doc.Linhas.Count - 1
            Add-LinhaYml -Doc $doc -Depois $ultima -Texto ""
            Add-LinhaYml -Doc $doc -Depois ($ultima + 1) -Texto "resources:"
            Add-LinhaYml -Doc $doc -Depois ($ultima + 2) -Texto ("  - " + $arqGoogle.Name)
            Write-Ok "$($arqGoogle.Name) adicionado em resources (raiz)"
        }
        Save-YmlDoc -Doc $doc -Caminho $ymlPath
        Assert-YmlIntegro $ymlPath
        $verificado = $true
    }
}

# --- 6c. Higiene: resources: duplicado na raiz E dentro de project: ---
$doc = Get-YmlDoc $ymlPath
$idxResRaiz = -1
for ($i = 0; $i -lt $doc.Linhas.Count; $i++) {
    if ($doc.Linhas[$i] -match "^resources:\s*$") { $idxResRaiz = $i; break }
}
$blocoProj  = Get-BlocoYml -Doc $doc -Chave "project:" -RecuoFilho 2
$idxResProj = Find-ChaveNoBloco -Doc $doc -Bloco $blocoProj -Padrao "^\s{2}resources:\s*$"

if ($idxResRaiz -ge 0 -and $idxResProj -ge 0) {
    Write-Aviso "existe 'resources:' na raiz E em 'project:' - o canonico do Quarto e project.resources"
    if (-not $SomenteDiagnostico -and (Confirmar "Consolidar tudo em project.resources?" $true)) {
        Backup-Arquivo $ymlPath "v14_consolida"

        $itens = @()
        $fimRaiz = $idxResRaiz
        for ($i = $idxResRaiz + 1; $i -lt $doc.Linhas.Count; $i++) {
            $l = $doc.Linhas[$i]
            if ([string]::IsNullOrWhiteSpace($l)) { $fimRaiz = $i; continue }
            if ($l -match "^\s+-\s*(.+)$") { $itens += $Matches[1].Trim(); $fimRaiz = $i }
            else { break }
        }

        for ($i = $fimRaiz; $i -ge $idxResRaiz; $i--) { Remove-LinhaYml -Doc $doc -Indice $i }

        $blocoProj  = Get-BlocoYml -Doc $doc -Chave "project:" -RecuoFilho 2
        $idxResProj = Find-ChaveNoBloco -Doc $doc -Bloco $blocoProj -Padrao "^\s{2}resources:\s*$"
        foreach ($it in $itens) {
            if ((Get-YmlTexto $doc) -notmatch [regex]::Escape($it)) {
                [void](Add-ItemListaYml -Doc $doc -IdxChave $idxResProj -RecuoPadrao 4 -Valor $it)
                Write-Ok "movido para project.resources: $it"
            }
        }
        Save-YmlDoc -Doc $doc -Caminho $ymlPath
        Assert-YmlIntegro $ymlPath
        Write-Ok "resources consolidado"
    }
}

if (-not $verificado) {
    Write-Info "nenhuma verificacao pendente detectada"
    Write-Passo "Para verificar a propriedade no Search Console (~20 min):"
    Write-Passo "  1. https://search.google.com/search-console"
    Write-Passo "  2. Adicionar propriedade > 'Prefixo do URL' > $UrlPublica"
    Write-Passo "  3a. Metodo 'Tag HTML'     : salve a meta tag em .\google-verification.html"
    Write-Passo "  3b. Metodo 'Arquivo HTML' : baixe o googleXXXX.html (fica em Downloads)"
    Write-Passo "  4. Rode este script novamente - ele detecta os dois casos"
    Write-Passo "  5. Push, aguarde o deploy e clique em 'Verificar'"
    Add-Pendencia "Verificar propriedade no Google Search Console (~20 min)"
}

Write-Info "Ao submeter o sitemap, digite APENAS: sitemap.xml"
Write-Passo "NAO use /sitemap.xml (barra inicial) nem a URL completa"
Write-Passo "-> e o que causa 'Nao foi possivel buscar o sitemap'"

# ------------------------------------------------------------------------------
# [7] ANALYTICS
# ------------------------------------------------------------------------------
Write-Etapa 7 "Analytics"

$analyticsAtivo = "nenhum"

if (Test-Path "styles\analytics-ativo.html") {
    Write-Ok "analytics ja configurado (styles/analytics-ativo.html existe)"
    $analyticsAtivo = "ja configurado"
} elseif ($SomenteDiagnostico) {
    Write-Info "analytics nao configurado"
} else {
    $escolha = $Analytics
    if ($escolha -eq "perguntar") {
        if ($Auto) {
            $escolha = "nenhum"
            Write-Host "  ?    Analytics -> [auto] nenhum" -ForegroundColor DarkYellow
        } else {
            Write-Host "       1) Google Analytics 4  - gratuito, exige banner LGPD"
            Write-Host "       2) Plausible           - ~R$ 45/mes, sem cookies, LGPD-friendly"
            Write-Host "       3) Umami self-hosted   - gratuito, exige deploy proprio"
            Write-Host "       4) Nenhum por enquanto - recomendado ate haver trafego real"
            Write-Host "       Detalhes em setup/SEO_SETUP_GUIA.md"
            switch (Read-Host "  ?    Escolha 1/2/3/4") {
                "1" { $escolha = "ga4" }
                "2" { $escolha = "plausible" }
                "3" { $escolha = "umami" }
                default { $escolha = "nenhum" }
            }
        }
    }

    switch ($escolha) {
        "ga4" {
            if (Test-Path ".\ga4-id.txt") {
                $ga4Id = (Read-FileUtf8 ".\ga4-id.txt").Trim()
                $tmpl  = Read-FileUtf8 "styles\analytics-ga4.html"
                Write-FileUtf8NoBom "styles\analytics-ativo.html" ($tmpl -replace "G-XXXXXXXXXX", $ga4Id)
                Remove-Item ".\ga4-id.txt" -Force
                Write-Ok "GA4 configurado com o ID $ga4Id"
                $analyticsAtivo = "GA4"
                Add-Pendencia "Publicar banner de consentimento LGPD (obrigatorio com GA4)"
            } else {
                Write-Aviso "crie .\ga4-id.txt com uma linha 'G-XXXXXXXXXX' e rode novamente"
            }
        }
        "plausible" {
            if (Test-Path ".\plausible-domain.txt") {
                $dom  = (Read-FileUtf8 ".\plausible-domain.txt").Trim()
                $tmpl = Read-FileUtf8 "styles\analytics-plausible.html"
                Write-FileUtf8NoBom "styles\analytics-ativo.html" ($tmpl -replace "mariocezar1971\.github\.io/livro-doe-usinagem", $dom)
                Remove-Item ".\plausible-domain.txt" -Force
                Write-Ok "Plausible configurado para $dom"
                $analyticsAtivo = "Plausible"
            } else {
                Write-Aviso "crie .\plausible-domain.txt com o dominio e rode novamente"
            }
        }
        "umami" {
            if (Test-Path ".\umami-config.txt") {
                $cfg  = Read-FileUtf8 ".\umami-config.txt"
                $urlU = (($cfg -split "`n" | Where-Object { $_ -match "^url=" }) -replace "^url=", "").Trim()
                $idU  = (($cfg -split "`n" | Where-Object { $_ -match "^id=" })  -replace "^id=",  "").Trim()
                $tmpl = Read-FileUtf8 "styles\analytics-umami.html"
                $ativo = $tmpl -replace "https://SEU-UMAMI\.fly\.dev/script\.js", $urlU
                $ativo = $ativo -replace "SEU-WEBSITE-ID", $idU
                Write-FileUtf8NoBom "styles\analytics-ativo.html" $ativo
                Remove-Item ".\umami-config.txt" -Force
                Write-Ok "Umami configurado"
                $analyticsAtivo = "Umami"
            } else {
                Write-Aviso "crie .\umami-config.txt com as linhas 'url=' e 'id=' e rode novamente"
            }
        }
        default {
            Write-Info "analytics pulado - comece em ~30 dias, quando houver trafego real"
            Add-Pendencia "Ativar analytics quando houver trafego (Plausible recomendado)"
        }
    }
}

if ((Test-Path "styles\analytics-ativo.html") -and -not $SomenteDiagnostico) {
    $doc = Get-YmlDoc $ymlPath
    if ((Get-YmlTexto $doc) -notmatch "analytics-ativo\.html") {
        $blocoHtml  = Get-BlocoYml -Doc $doc -Chave "  html:" -RecuoFilho 4
        $idxInclude = Find-ChaveNoBloco -Doc $doc -Bloco $blocoHtml -Padrao "^\s{4}include-in-header:\s*$"
        if ($idxInclude -ge 0) {
            Backup-Arquivo $ymlPath "v14_analytics"
            [void](Add-ItemListaYml -Doc $doc -IdxChave $idxInclude -RecuoPadrao 6 -Valor "styles/analytics-ativo.html")
            Save-YmlDoc -Doc $doc -Caminho $ymlPath
            Assert-YmlIntegro $ymlPath
            Write-Ok "analytics-ativo.html adicionado ao include-in-header"
        } else {
            Write-Aviso "include-in-header nao localizado para adicionar o analytics"
        }
    }
}

# ------------------------------------------------------------------------------
# [8] RENDER
# ------------------------------------------------------------------------------
Write-Etapa 8 "Renderizar HTML"

$renderOk = $false

if ($SomenteDiagnostico -or $SkipRender) {
    Write-Info "render pulado"
    $renderOk = Test-Path "_book\index.html"
} elseif (-not $temQuarto) {
    Write-Aviso "quarto ausente - render pulado"
} elseif (Confirmar "Rodar 'quarto render --to html' agora? (1-2 minutos)" $true) {
    for ($tentativa = 1; $tentativa -le 2; $tentativa++) {
        Write-Passo "tentativa $tentativa de 2..."
        quarto render --to html
        if ($LASTEXITCODE -eq 0 -and (Test-Path "_book\index.html")) { $renderOk = $true; break }

        Write-Aviso "render falhou (exit $LASTEXITCODE)"
        if ($tentativa -eq 1) {
            Write-Passo "provavel lock do Dropbox ('os error 32') - limpando e tentando de novo"
            [void](Stop-ProcessosQuarto)
            [void](Clear-CacheQuarto)
            Pausar "Confirme que o Dropbox esta PAUSADO antes da segunda tentativa."
        }
    }
    if ($renderOk) {
        Write-Ok "render concluido - _book\index.html gerado"
    } else {
        Write-Falha "render falhou nas 2 tentativas"
        Write-Passo "se o Dropbox estava pausado e o erro persiste, mova o projeto para fora do Dropbox"
    }
}

if (Test-Path "_book") {
    $qtdHtml = (Get-ChildItem "_book" -Recurse -Filter "*.html" -ErrorAction SilentlyContinue).Count
    $qtdCss  = (Get-ChildItem "_book" -Recurse -Filter "*.css"  -ErrorAction SilentlyContinue).Count
    $qtdJs   = (Get-ChildItem "_book" -Recurse -Filter "*.js"   -ErrorAction SilentlyContinue).Count
    $qtdXml  = (Get-ChildItem "_book" -Recurse -Filter "*.xml"  -ErrorAction SilentlyContinue).Count
    Write-Info "conteudo de _book (recursivo): HTML=$qtdHtml  CSS=$qtdCss  JS=$qtdJs  XML=$qtdXml"
    if ($qtdHtml -gt 0 -and $qtdHtml -lt 19) {
        Write-Aviso "esperado ~19 HTML (19 capitulos/apendices) - confira se todos renderizaram"
    }
}

# ------------------------------------------------------------------------------
# [9] VALIDAR META TAGS
# ------------------------------------------------------------------------------
Write-Etapa 9 "Validar meta tags no HTML gerado"

if (Test-Path "_book\index.html") {
    $indexHtml = Read-FileUtf8 "_book\index.html"
    $checks = [ordered]@{
        "Schema.org Book (JSON-LD)" = 'application/ld\+json'
        "og:type = book"            = 'og:type"?\s+content="book'
        "og:title"                  = 'og:title'
        "og:image"                  = 'og:image'
        "og:locale = pt_BR"         = 'og:locale"?\s+content="pt_BR'
        "Twitter Card"              = 'twitter:card'
        "Meta description"          = 'name="description"'
        "Canonical link"            = 'rel="canonical"'
        "Google verification"       = 'google-site-verification'
    }
    foreach ($c in $checks.GetEnumerator()) {
        if ($indexHtml -match $c.Value) { Write-Ok $c.Key } else { Write-Aviso "$($c.Key) NAO encontrado" }
    }

    if ($indexHtml -match 'og:image"?\s+content="([^"]+)"') {
        Write-Info "og:image = $($Matches[1])"
    }
    if (Test-Path "figuras\capa.png") {
        Write-Ok "figuras/capa.png presente"
    } else {
        Write-Aviso "figuras/capa.png ausente - preview no LinkedIn/WhatsApp/Twitter vai quebrar"
        Write-Passo "um placeholder simples ja resolve"
        Add-Pendencia "Criar figuras/capa.png em 1200x630 px"
    }
} else {
    Write-Aviso "_book\index.html nao existe - rode o render (etapa 8) antes"
}

# ------------------------------------------------------------------------------
# [10] SITEMAP + ROBOTS
# ------------------------------------------------------------------------------
Write-Etapa 10 "Diagnostico do sitemap.xml e robots.txt"

Write-Info "linhas relevantes do _quarto.yml:"
Select-String -Path $ymlPath -Pattern "site-url|sitemap" | ForEach-Object {
    Write-Passo ("L{0}: {1}" -f $_.LineNumber, $_.Line.Trim())
}

if (Test-Path "_book\sitemap.xml") {
    $sitemap = Read-FileUtf8 "_book\sitemap.xml"
    $urls = ([regex]::Matches($sitemap, "<loc>")).Count
    Write-Ok "sitemap.xml gerado com $urls URLs"
    if ($urls -lt 15) { Write-Aviso "esperado ~19 URLs - confira se todos os capitulos renderizaram" }

    if ($sitemap -match [regex]::Escape($HostPublico)) {
        Write-Ok "URLs apontam para $HostPublico (correto)"
    } elseif ($sitemap -match "doeusinagem\.com\.br") {
        Write-Falha "URLs apontam para doeusinagem.com.br (dominio inativo) - volte a etapa [4]"
    } else {
        Write-Aviso "host das URLs nao reconhecido"
    }

    $primeira = [regex]::Match($sitemap, "<loc>([^<]+)</loc>")
    if ($primeira.Success) { Write-Passo "primeira URL: $($primeira.Groups[1].Value)" }
} else {
    Write-Aviso "_book\sitemap.xml NAO gerado"
    Write-Passo "confira 'site-url' em book: e 'sitemap: true' em format: html:"
}

if (Test-Path "_book\robots.txt") {
    Write-Ok "robots.txt gerado automaticamente"
    foreach ($l in ((Read-FileUtf8 "_book\robots.txt") -split "`r?`n" | Where-Object { $_.Trim() -ne "" })) {
        Write-Passo $l
    }
} else {
    Write-Info "robots.txt ausente (o Quarto so o gera junto com o sitemap)"
}

# ------------------------------------------------------------------------------
# [11] COMMIT + PUSH
# ------------------------------------------------------------------------------
Write-Etapa 11 "Versionar no Git"

$fezPush = $false

if ($SomenteDiagnostico -or $SkipCommit -or -not $temGit) {
    Write-Info "commit pulado"
} else {
    $status = git status --porcelain 2>$null
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Ok "nada para commitar - arvore limpa"
    } else {
        git status --short
        if (Confirmar "Commitar as mudancas da Fase 1.4?" $true) {

            $titulo = "Fase 1.4: SEO completo (schema.org Book, meta OG/Twitter, sitemap, analytics $analyticsAtivo)"
            $usouWrapper = $false

            if (Test-Path ".\commit-fase.ps1") {
                Write-Info "commit-fase.ps1 detectado - usando o wrapper"
                try {
                    . .\commit-fase.ps1
                    $arquivos = @(
                        "_quarto.yml",
                        ".gitignore",
                        "styles/schema-book.html",
                        "styles/seo-meta.html",
                        "styles/analytics-*.html",
                        "setup/SEO_SETUP_GUIA.md",
                        "executar-fase-1-4.ps1"
                    )
                    if ($arqGoogle) { $arquivos += $arqGoogle.Name }
                    Commit-Fase -Titulo $titulo -Arquivos $arquivos -AutoPush
                    $usouWrapper = $true
                    $fezPush = $true
                } catch {
                    Write-Aviso "wrapper falhou ($($_.Exception.Message)) - usando git direto"
                }
            }

            if (-not $usouWrapper) {
                git add _quarto.yml 2>$null
                if (Test-Path ".gitignore")               { git add .gitignore 2>$null }
                if (Test-Path "styles\schema-book.html")  { git add styles/schema-book.html 2>$null }
                if (Test-Path "styles\seo-meta.html")     { git add styles/seo-meta.html 2>$null }
                git add styles/analytics-*.html 2>$null
                if (Test-Path "setup\SEO_SETUP_GUIA.md")  { git add setup/SEO_SETUP_GUIA.md 2>$null }
                if (Test-Path "executar-fase-1-4.ps1")    { git add executar-fase-1-4.ps1 2>$null }
                if ($arqGoogle)                           { git add $arqGoogle.Name 2>$null }

                git commit -m $titulo
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "commit criado"
                    if (Confirmar "Push para o GitHub?" $true) {
                        git push
                        if ($LASTEXITCODE -eq 0) { Write-Ok "push concluido"; $fezPush = $true }
                        else { Write-Falha "push falhou (exit $LASTEXITCODE)" }
                    }
                } else {
                    Write-Aviso "commit nao criado (exit $LASTEXITCODE)"
                }
            }
        }
    }
    Write-Info "ultimos commits:"
    git log --oneline -3 2>$null | ForEach-Object { Write-Passo $_ }
}

# ------------------------------------------------------------------------------
# [12] VERIFICAR DEPLOY
# ------------------------------------------------------------------------------
Write-Etapa 12 "Verificar deploy no GitHub Pages"

if ($SomenteDiagnostico -or $SkipDeploy) {
    Write-Info "verificacao de deploy pulada"
} else {
    $wrapperDeploy = @("verificar-deploy.ps1", "validar-deploy.ps1") |
                     Where-Object { Test-Path ".\$_" } | Select-Object -First 1

    if ($wrapperDeploy) {
        Write-Info "$wrapperDeploy detectado"
        if (Confirmar "Rodar .\$wrapperDeploy agora?" $true) {
            & ".\$wrapperDeploy" -SkipPolling
        }
    } elseif ($fezPush -or (Confirmar "Checar o site publicado mesmo sem push nesta execucao?" $false)) {
        if ($temGh) {
            Write-Info "ultimos workflows:"
            gh run list --repo $RepoGitHub --limit 2 2>$null | ForEach-Object { Write-Passo $_ }
        }
        if ($fezPush) {
            Write-Passo "aguardando 90s pela propagacao do GitHub Pages..."
            Start-Sleep -Seconds 90
        }
        $alvos = @(
            @{ Nome = "homepage"; Url = $UrlPublica },
            @{ Nome = "sitemap ";  Url = ($UrlPublica + "sitemap.xml") },
            @{ Nome = "robots  ";  Url = ($UrlPublica + "robots.txt") }
        )
        foreach ($a in $alvos) {
            try {
                $resp = Invoke-WebRequest -Uri $a.Url -UseBasicParsing -TimeoutSec 15
                Write-Ok "$($a.Nome): HTTP $($resp.StatusCode) - $($resp.Content.Length) bytes"
                if ($a.Nome.Trim() -eq "sitemap") {
                    Write-Passo "sitemap publicado com $(([regex]::Matches($resp.Content, '<loc>')).Count) URLs"
                }
            } catch {
                Write-Aviso "$($a.Nome): $($_.Exception.Message)"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# [13] RESUMO
# ------------------------------------------------------------------------------
Write-Cabecalho "RESUMO DA FASE 1.4"

$ymlFinal = Read-FileUtf8 $ymlPath

$situacao = [ordered]@{
    "Meta tags Open Graph + Twitter Card (styles/seo-meta.html)" = (Test-Path "styles\seo-meta.html")
    "Schema.org Book JSON-LD (styles/schema-book.html)"          = (Test-Path "styles\schema-book.html")
    "site-url apontando para github.io"                          = ($ymlFinal -match [regex]::Escape($SiteUrlYml))
    "include-in-header com schema + meta"                        = (($ymlFinal -match "schema-book\.html") -and ($ymlFinal -match "seo-meta\.html"))
    "sitemap.xml gerado pelo Quarto"                             = (Test-Path "_book\sitemap.xml")
    "robots.txt apontando para o sitemap"                        = (Test-Path "_book\robots.txt")
    "Templates de analytics disponiveis"                         = (Test-Path "styles\analytics-ga4.html")
    "Guia SEO (setup/SEO_SETUP_GUIA.md)"                         = (Test-Path "setup\SEO_SETUP_GUIA.md")
    "Capa 1200x630 (figuras/capa.png)"                           = (Test-Path "figuras\capa.png")
}

Write-Host ""
Write-Host "  SITUACAO ATUAL" -ForegroundColor Green
foreach ($s in $situacao.GetEnumerator()) {
    if ($s.Value) { Write-Host "    [OK] $($s.Key)" -ForegroundColor Green }
    else          { Write-Host "    [  ] $($s.Key)" -ForegroundColor DarkYellow }
}
Write-Host "         Analytics ativo: $analyticsAtivo"

if ($script:Avisos.Count -gt 0) {
    Write-Host ""
    Write-Host "  AVISOS DESTA EXECUCAO ($($script:Avisos.Count))" -ForegroundColor Yellow
    foreach ($a in $script:Avisos) { Write-Host "    - $a" -ForegroundColor Yellow }
}

$manuais = New-Object System.Collections.ArrayList
[void]$manuais.Add("Verificar propriedade no Google Search Console (~20 min)")
[void]$manuais.Add("Submeter o sitemap digitando apenas: sitemap.xml")
[void]$manuais.Add("Criar figuras/capa.png em 1200x630 px")
[void]$manuais.Add("Testar Rich Results (apos ~15 dias de indexacao)")
foreach ($p in $script:Pendencias) { if (-not $manuais.Contains($p)) { [void]$manuais.Add($p) } }

Write-Host ""
Write-Host "  PENDENCIAS MANUAIS" -ForegroundColor Cyan
foreach ($p in $manuais) { Write-Host "    [ ] $p" }

Write-Host ""
Write-Host "  LINKS UTEIS" -ForegroundColor Cyan
Write-Host "    Site ............ $UrlPublica"
Write-Host "    Sitemap ......... $($UrlPublica)sitemap.xml"
Write-Host "    Search Console .. https://search.google.com/search-console"
Write-Host "    Rich Results .... https://search.google.com/test/rich-results"
Write-Host "    Actions ......... https://github.com/$RepoGitHub/actions/"
Write-Host "    Ping do Google .. https://www.google.com/ping?sitemap=$($UrlPublica)sitemap.xml"
Write-Host "                      (colar no navegador uma vez a cada ~30 dias)"

Write-Host ""
Write-Host "  PROXIMO PASSO RECOMENDADO" -ForegroundColor Magenta
Write-Host "    Capitulo 1 - 'Por que DOE em manufatura'"
Write-Host "    10-12 paginas, ~3-4 horas em 2 sessoes."
Write-Host "    Estabelece a voz autoral do livro e serve de material para o LinkedIn."
Write-Host ""
Write-Host "    Ordem sugerida depois dele:"
Write-Host "      1. Configurar Brevo real ................. ~40 min"
Write-Host "      2. Search Console (se ainda nao feito) ... ~20 min"
Write-Host "      3. Zotero + Better BibTeX ................ ~1 h"
Write-Host "      4. Registrar doeusinagem.com.br"

if ($dentroDropbox -and -not $SomenteDiagnostico) {
    Write-Host ""
    Write-Host "  NAO ESQUECA: REATIVAR O DROPBOX" -ForegroundColor Yellow
    Write-Host "    Icone na bandeja > Retomar sincronizacao"
    Write-Host "    Antes disso, marque .quarto, _book e _freeze como 'Ignorar':"
    Write-Host "    Explorer > botao direito na pasta > Dropbox > Ignorar"
}

if (-not $SomenteDiagnostico) {
    $sha = ""
    if ($temGit) { $sha = (git rev-parse --short HEAD 2>$null) }
    $linhaLog = "{0} | fase-1.4 | analytics={1} | push={2} | avisos={3} | commit={4}" -f `
                (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $analyticsAtivo, $fezPush, $script:Avisos.Count, $sha
    Add-Content -Path $LogAuditoria -Value $linhaLog -Encoding UTF8
    Write-Host ""
    Write-Info "log de auditoria: $LogAuditoria"
    Write-Passo $linhaLog
}

Write-Host ""
Write-Host ("=" * 80) -ForegroundColor DarkCyan
Write-Host " FIM - FASE 1.4" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor DarkCyan
Write-Host ""
