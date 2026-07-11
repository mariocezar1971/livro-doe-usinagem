<#
================================================================================
 SCRIPT MESTRE - FASE 1.2: Esqueleto do Livro + Validacao dos Renders
================================================================================

 Executa em sequencia todas as etapas da Fase 1.2:

   [0] Validar ambiente (Quarto, R, Python, TinyTeX)
   [1] Verificar esqueleto existente (index.qmd + 12 caps + 4 apendices)
   [2] Enriquecer stubs se necessario (garantir minimo estrutural)
   [3] PRIMEIRO RENDER HTML  - validar pipeline basico
   [4] PRIMEIRO RENDER PDF   - validar LaTeX (o maior desafio)
   [5] PRIMEIRO RENDER EPUB  - validar para Kindle
   [6] Validar outputs gerados (existem, tem tamanho razoavel)
   [7] Sistema de diagnostico para erros LaTeX comuns
   [8] Commit + push opcional

 O que este script NAO faz:
   - NAO escreve conteudo real dos capitulos (isso e Fase 3+)
   - NAO configura design fino do PDF (isso e Fase 8)
   - NAO otimiza EPUB para KDP (isso e Fase 9)

 O objetivo e validar que os 3 formatos renderizam SEM ERRO,
 mesmo que visualmente ainda sejam stubs.

 PRE-REQUISITOS:
   - Fases 0.2, 0.3 e 1.1 concluidas
   - Quarto, R, Python instalados
   - TinyTeX instalado (para PDF)

 COMO EXECUTAR:
   cd C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\executar-fase-1-2.ps1

================================================================================
#>

# ============================================================================
# CONFIGURACAO
# ============================================================================

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"

# Cores
$ESC = [char]27
$GREEN = "$ESC[32m"; $YELLOW = "$ESC[33m"; $RED = "$ESC[31m"
$BLUE  = "$ESC[34m"; $BOLD   = "$ESC[1m";  $RESET = "$ESC[0m"

function Write-Etapa($num, $titulo) {
    Write-Host ""
    Write-Host "$BOLD$BLUE================================================================================$RESET"
    Write-Host "$BOLD$BLUE ETAPA $num - $titulo$RESET"
    Write-Host "$BOLD$BLUE================================================================================$RESET"
}
function Write-OK($msg)   { Write-Host "$GREEN[OK]$RESET $msg" }
function Write-Warn($msg) { Write-Host "$YELLOW[!]$RESET $msg" }
function Write-Err($msg)  { Write-Host "$RED[X]$RESET $msg" }
function Write-Info($msg) { Write-Host "$BLUE[i]$RESET $msg" }
function Perguntar($p)    {
    $r = Read-Host "$p (S/N)"
    return ($r -eq "S" -or $r -eq "s" -or $r -eq "")
}

# ============================================================================
# ETAPA 0 - Validar ambiente
# ============================================================================
Write-Etapa "0" "Validar ambiente de renderizacao"

if (-not (Test-Path $ProjetoRaiz)) {
    Write-Err "Pasta do projeto nao encontrada: $ProjetoRaiz"
    exit 1
}
Set-Location $ProjetoRaiz
Write-OK "Pasta do projeto: $ProjetoRaiz"

if (-not (Test-Path "_quarto.yml")) {
    Write-Err "_quarto.yml nao encontrado. Execute Fase 0.2 antes."
    exit 1
}
Write-OK "Projeto Quarto detectado"

$quarto = Get-Command quarto -ErrorAction SilentlyContinue
if (-not $quarto) { Write-Err "Quarto nao instalado"; exit 1 }
$quartoVer = (quarto --version) -join ''
Write-OK "Quarto: $quartoVer"

$r = Get-Command Rscript -ErrorAction SilentlyContinue
if ($r) { Write-OK "R detectado: $($r.Path)" }
else { Write-Warn "R nao detectado (nao critico se nao usar knitr no primeiro render)" }

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if ($py) { Write-OK "Python: $($py.Path)" }
else { Write-Warn "Python nao detectado (nao critico se nao usar chunks Python)" }

# TinyTeX - critico para PDF
Write-Info "Verificando TinyTeX (necessario para PDF)..."
$tinytex = quarto check tools 2>&1
$temTinyTex = $tinytex -match "TinyTeX"
if ($temTinyTex) {
    Write-OK "TinyTeX disponivel"
} else {
    Write-Warn "TinyTeX pode nao estar instalado"
    Write-Info "Se PDF falhar, instale com: quarto install tinytex"
}

# ============================================================================
# ETAPA 1 - Verificar esqueleto existente
# ============================================================================
Write-Etapa "1" "Verificar esqueleto (arquivos .qmd)"

$esqueleto = @{
    "index.qmd (prefacio)" = "index.qmd"
    "Cap 1"  = "parte-1\cap-01-por-que-doe.qmd"
    "Cap 2"  = "parte-1\cap-02-metalurgia.qmd"
    "Cap 3"  = "parte-1\cap-03-torneamento.qmd"
    "Cap 4"  = "parte-2\cap-04-fatorial.qmd"
    "Cap 5"  = "parte-2\cap-05-pcc-rsm.qmd"
    "Cap 6"  = "parte-2\cap-06-otimizacao.qmd"
    "Cap 7"  = "parte-3\cap-07-projeto.qmd"
    "Cap 8"  = "parte-3\cap-08-fatorial-aluminio.qmd"
    "Cap 9"  = "parte-3\cap-09-rsm-pcc.qmd"
    "Cap 10" = "parte-3\cap-10-otimizacao-global.qmd"
    "Cap 11" = "parte-4\cap-11-chao-fabrica.qmd"
    "Cap 12" = "parte-4\cap-12-sintese.qmd"
    "Ap A"   = "apendices\apendice-a-instrumentacao.qmd"
    "Ap B"   = "apendices\apendice-b-codigos.qmd"
    "Ap C"   = "apendices\apendice-c-tabelas.qmd"
    "Ap D"   = "apendices\apendice-d-dados.qmd"
    "Refs"   = "references.qmd"
}

$existentes = 0
$ausentes = @()
foreach ($item in $esqueleto.GetEnumerator()) {
    if (Test-Path $item.Value) {
        $bytes = (Get-Item $item.Value).Length
        $sizeStr = if ($bytes -lt 1024) { "$bytes B" } else { "$([math]::Round($bytes/1024, 1)) KB" }
        Write-OK "$($item.Key.PadRight(20)) $sizeStr - $($item.Value)"
        $existentes++
    } else {
        Write-Err "$($item.Key.PadRight(20)) AUSENTE - $($item.Value)"
        $ausentes += $item.Value
    }
}

Write-Host ""
Write-Info "$existentes de $($esqueleto.Count) arquivos existentes"

if ($ausentes.Count -gt 0) {
    Write-Warn "Ha arquivos ausentes. Execute Fase 0.2 primeiro:"
    foreach ($a in $ausentes) { Write-Host "  - $a" }
    if (-not (Perguntar "Continuar mesmo com arquivos ausentes?")) {
        exit 1
    }
}

# ============================================================================
# ETAPA 2 - Enriquecer stubs se necessario
# ============================================================================
Write-Etapa "2" "Verificar conteudo minimo dos stubs"

$stubsMagros = @()
foreach ($item in $esqueleto.GetEnumerator()) {
    if (Test-Path $item.Value) {
        $bytes = (Get-Item $item.Value).Length
        if ($bytes -lt 100) {
            $stubsMagros += $item.Value
        }
    }
}

if ($stubsMagros.Count -gt 0) {
    Write-Warn "Stubs com menos de 100 bytes (podem quebrar render):"
    foreach ($s in $stubsMagros) { Write-Host "  - $s" }
    Write-Info "O render pode falhar se um .qmd estiver vazio ou so com frontmatter."
    Write-Info "Recomendado: adicionar callout minimo 'Conteudo em desenvolvimento'."
} else {
    Write-OK "Todos os stubs tem tamanho minimo aceitavel"
}

# ============================================================================
# ETAPA 3 - RENDER HTML (deveria ja funcionar)
# ============================================================================
Write-Etapa "3" "Primeiro render HTML"

$renderHtml = Perguntar "Renderizar HTML agora?"
if ($renderHtml) {
    Write-Info "Executando: quarto render --to html"
    $htmlLog = "$env:TEMP\quarto-html-$([DateTime]::Now.ToString('HHmmss')).log"
    quarto render --to html 2>&1 | Tee-Object -FilePath $htmlLog

    if ($LASTEXITCODE -eq 0) {
        if (Test-Path "_book\index.html") {
            $sizeIdx = [math]::Round((Get-Item "_book\index.html").Length / 1KB, 1)
            Write-OK "HTML gerado: _book\index.html ($sizeIdx KB)"

            # Contar arquivos gerados
            $htmlCount = (Get-ChildItem "_book\*.html" -ErrorAction SilentlyContinue).Count
            Write-OK "$htmlCount paginas HTML no _book\"
        } else {
            Write-Err "Render OK mas _book\index.html nao encontrado"
        }
    } else {
        Write-Err "Falha no render HTML. Log salvo em: $htmlLog"
        Write-Info "Ultimas 15 linhas do log:"
        Get-Content $htmlLog -Tail 15 | ForEach-Object { Write-Host "  $_" }
        if (-not (Perguntar "Continuar para PDF mesmo assim?")) { exit 1 }
    }
} else {
    Write-Info "HTML pulado (se ja funciona no GitHub Pages, e OK)"
}

# ============================================================================
# ETAPA 4 - RENDER PDF (o desafio - LaTeX)
# ============================================================================
Write-Etapa "4" "Primeiro render PDF (validar LaTeX)"

Write-Info "Este e o render mais complexo. Erros comuns:"
Write-Host "  - Fontes ausentes (fontenc, fontspec)"
Write-Host "  - Pacotes LaTeX faltando (tinytex resolve automaticamente)"
Write-Host "  - Callouts do Quarto exigindo pacotes especificos"
Write-Host "  - Codificacao UTF-8 em citacoes"
Write-Host "  - Imagens em SVG/WMF que LaTeX nao le nativamente"
Write-Host ""

if (Perguntar "Renderizar PDF agora?") {
    Write-Info "Executando: quarto render --to pdf"
    Write-Info "Isso pode demorar 2-5 minutos na primeira execucao"
    Write-Info "(TinyTeX baixa pacotes LaTeX automaticamente conforme necessidade)"
    Write-Host ""

    $pdfLog = "$env:TEMP\quarto-pdf-$([DateTime]::Now.ToString('HHmmss')).log"
    quarto render --to pdf 2>&1 | Tee-Object -FilePath $pdfLog
    $pdfExitCode = $LASTEXITCODE

    Write-Host ""

    if ($pdfExitCode -eq 0) {
        # Procurar PDF gerado
        $pdfFile = Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pdfFile) {
            $sizePdf = [math]::Round($pdfFile.Length / 1KB, 1)
            Write-OK "PDF gerado: $($pdfFile.FullName) ($sizePdf KB)"
        } else {
            Write-Warn "Render OK mas PDF nao encontrado em _book\"
        }
    } else {
        Write-Err "Falha no render PDF (exit code $pdfExitCode)"
        Write-Info "Log salvo em: $pdfLog"

        # DIAGNOSTICO AUTOMATICO
        Write-Host ""
        Write-Info "Analisando log para diagnostico..."
        $logContent = Get-Content $pdfLog -Raw

        # Padroes de erro conhecidos
        $diagnosticos = @()

        if ($logContent -match "! LaTeX Error: File `([^']+)' not found") {
            $pacote = $Matches[1]
            $diagnosticos += "Pacote LaTeX ausente: $pacote"
            $diagnosticos += "  Solucao: quarto usara tinytex para instalar automaticamente"
            $diagnosticos += "  Se persistir: tlmgr install $($pacote -replace '\..*$','')"
        }

        if ($logContent -match "Package fontenc") {
            $diagnosticos += "Problema com codificacao de fontes"
            $diagnosticos += "  Solucao: adicionar em _quarto.yml sob format.pdf:"
            $diagnosticos += "    include-in-header:"
            $diagnosticos += "      text: \\usepackage[T1]{fontenc}"
        }

        if ($logContent -match "! Undefined control sequence") {
            $diagnosticos += "Comando LaTeX indefinido no texto"
            $diagnosticos += "  Solucao: procure por \\ em .qmd que nao seja escape valido"
        }

        if ($logContent -match "! Package inputenc Error") {
            $diagnosticos += "Problema de codificacao UTF-8"
            $diagnosticos += "  Solucao: em _quarto.yml sob format.pdf:"
            $diagnosticos += "    pdf-engine: xelatex   # em vez de pdflatex"
        }

        if ($logContent -match "! I can't find file `([^']+)'") {
            $arquivo = $Matches[1]
            $diagnosticos += "Arquivo referenciado nao encontrado: $arquivo"
            $diagnosticos += "  Solucao: verificar caminho relativo no .qmd"
        }

        if ($logContent -match "Missing character:") {
            $diagnosticos += "Caractere Unicode nao suportado pela fonte"
            $diagnosticos += "  Solucao: usar pdf-engine: xelatex ou lualatex"
        }

        if ($diagnosticos.Count -eq 0) {
            Write-Warn "Nenhum diagnostico automatico. Ultimas 30 linhas do log:"
            Get-Content $pdfLog -Tail 30 | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host ""
            Write-Host "$BOLD Diagnostico automatico:$RESET"
            foreach ($d in $diagnosticos) { Write-Host "  $d" }
        }

        Write-Host ""
        if (-not (Perguntar "Continuar para EPUB mesmo com falha no PDF?")) { exit 1 }
    }
} else {
    Write-Info "PDF pulado"
}

# ============================================================================
# ETAPA 5 - RENDER EPUB (para Kindle/leitores)
# ============================================================================
Write-Etapa "5" "Primeiro render EPUB (validar para Kindle)"

Write-Info "EPUB e mais permissivo que PDF - normalmente funciona."
Write-Host ""

if (Perguntar "Renderizar EPUB agora?") {
    Write-Info "Executando: quarto render --to epub"

    $epubLog = "$env:TEMP\quarto-epub-$([DateTime]::Now.ToString('HHmmss')).log"
    quarto render --to epub 2>&1 | Tee-Object -FilePath $epubLog

    if ($LASTEXITCODE -eq 0) {
        $epubFile = Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($epubFile) {
            $sizeEpub = [math]::Round($epubFile.Length / 1KB, 1)
            Write-OK "EPUB gerado: $($epubFile.FullName) ($sizeEpub KB)"

            # EPUB e um zip - validar estrutura
            Write-Info "Validando estrutura EPUB..."
            $temp = "$env:TEMP\epub-validate-$([DateTime]::Now.ToString('HHmmss'))"
            Expand-Archive -Path $epubFile.FullName -DestinationPath $temp -Force -ErrorAction SilentlyContinue
            if (Test-Path "$temp\META-INF\container.xml") {
                Write-OK "Estrutura EPUB valida (META-INF/container.xml presente)"
            } else {
                Write-Warn "EPUB gerado mas estrutura pode estar incompleta"
            }
            Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Warn "Render OK mas EPUB nao encontrado em _book\"
        }
    } else {
        Write-Err "Falha no render EPUB"
        Write-Info "Log: $epubLog"
        Write-Info "Ultimas 15 linhas:"
        Get-Content $epubLog -Tail 15 | ForEach-Object { Write-Host "  $_" }
    }
} else {
    Write-Info "EPUB pulado"
}

# ============================================================================
# ETAPA 6 - Validar outputs
# ============================================================================
Write-Etapa "6" "Validar outputs em _book\"

if (Test-Path "_book") {
    $arquivos = Get-ChildItem "_book" -Recurse -File
    $totalMB = [math]::Round(($arquivos | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-OK "$($arquivos.Count) arquivos gerados, total $totalMB MB"

    # Contagens por tipo
    $tipos = @{
        "HTML" = ($arquivos | Where-Object { $_.Name -match '\.html$' }).Count
        "PDF"  = ($arquivos | Where-Object { $_.Name -match '\.pdf$' }).Count
        "EPUB" = ($arquivos | Where-Object { $_.Name -match '\.epub$' }).Count
        "CSS"  = ($arquivos | Where-Object { $_.Name -match '\.css$' }).Count
        "JS"   = ($arquivos | Where-Object { $_.Name -match '\.js$' }).Count
        "IMG"  = ($arquivos | Where-Object { $_.Name -match '\.(png|jpg|svg|gif)$' }).Count
    }
    foreach ($t in $tipos.GetEnumerator()) {
        if ($t.Value -gt 0) {
            Write-OK "  $($t.Key.PadRight(6)): $($t.Value) arquivos"
        }
    }
} else {
    Write-Err "Pasta _book\ nao existe. Nenhum render bem-sucedido."
}

# ============================================================================
# ETAPA 7 - Abrir outputs para inspecao visual
# ============================================================================
Write-Etapa "7" "Inspecao visual dos outputs"

if (Test-Path "_book\index.html") {
    if (Perguntar "Abrir HTML no navegador?") {
        Start-Process "_book\index.html"
    }
}

$pdf = Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pdf) {
    if (Perguntar "Abrir PDF?") {
        Start-Process $pdf.FullName
    }
}

$epub = Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($epub) {
    if (Perguntar "Abrir pasta contendo EPUB (para arrastar ao Kindle/leitor)?") {
        Start-Process (Split-Path $epub.FullName)
    }
}

# ============================================================================
# ETAPA 8 - Commit + push opcional
# ============================================================================
Write-Etapa "8" "Versionar mudancas no Git"

$status = git status --porcelain 2>$null
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-OK "Nenhuma mudanca pendente no Git"
} else {
    Write-Host "Mudancas detectadas:"
    git status --short
    Write-Host ""

    if (Perguntar "Commitar este script no Git?") {
        if (Test-Path ".\executar-fase-1-2.ps1") {
            git add .\executar-fase-1-2.ps1
        }

        # Se .gitignore mudou (ex: acrescentar _book se ainda nao esta)
        $temIgnoreBook = (Get-Content .gitignore -ErrorAction SilentlyContinue) -match "_book"
        if (-not $temIgnoreBook) {
            Add-Content .gitignore "`n# Outputs de render locais (nao versionar)`n_book/`n.quarto/"
            Write-OK ".gitignore atualizado para excluir _book/"
            git add .gitignore
        }

        git status --short

        if (Perguntar "Confirmar commit?") {
            $msg = "Fase 1.2: script mestre de esqueleto e validacao dos 3 renders`n`n" +
                   "- executar-fase-1-2.ps1: orquestrador da Fase 1.2`n" +
                   "- Valida esqueleto do livro (17 arquivos .qmd)`n" +
                   "- Executa primeiro render HTML, PDF e EPUB`n" +
                   "- Sistema de diagnostico automatico para erros LaTeX comuns`n" +
                   "- Ajusta .gitignore para nao versionar _book/ e .quarto/"
            git commit -m $msg

            if ($LASTEXITCODE -eq 0 -and (Perguntar "Push para GitHub?")) {
                git push
            }
        }
    }
}

# ============================================================================
# CONCLUSAO
# ============================================================================
Write-Etapa "FIM" "Resumo da Fase 1.2"

Write-Host ""
Write-Host "$BOLD Status dos 3 formatos:$RESET"

$statusHtml = if (Test-Path "_book\index.html") { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }
$statusPdf  = if ((Get-ChildItem "_book\*.pdf" -ErrorAction SilentlyContinue).Count -gt 0) { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }
$statusEpub = if ((Get-ChildItem "_book\*.epub" -ErrorAction SilentlyContinue).Count -gt 0) { "$GREEN [OK]$RESET" } else { "$RED [X]$RESET" }

Write-Host "  $statusHtml HTML (essencial - site publico)"
Write-Host "  $statusPdf  PDF  (comercial - produto principal)"
Write-Host "  $statusEpub EPUB (Kindle - amplia alcance)"
Write-Host ""

Write-Host "$BOLD Se algum falhou:$RESET"
Write-Host "  - HTML: raro falhar. Ver log em `$env:TEMP\quarto-html-*.log"
Write-Host "  - PDF:  frequentemente falha na 1a rodada (LaTeX)"
Write-Host "          quarto install tinytex - resolve maioria"
Write-Host "          Ver diagnostico automatico acima"
Write-Host "  - EPUB: geralmente funciona. Se falhar, e problema de imagem/CSS"
Write-Host ""

Write-Host "$BOLD Proximos passos possiveis:$RESET"
Write-Host "  A - Fase 0.4 (Zotero + Better BibTeX) - ~1h"
Write-Host "  B - Fase 3.1 (escrever Cap 1: Por que DOE em manufatura) - ~3-4h"
Write-Host "  C - Fase 8 (design fino do PDF/EPUB) - so quando ja tiver conteudo"
Write-Host ""
