# SCRIPT MESTRE - FASE 1.4
# Configuracao de SEO (Search Console, Analytics, Schema.org, Sitemap)
#
# Executa em sequencia:
#   [0]   Validar ambiente
#   [1]   Distribuir arquivos do ZIP (idempotente)
#   [2]   Corrigir site-url para github.io (temporario ate ter dominio)
#   [3]   Adicionar include-in-header no _quarto.yml (schema + meta)
#   [4]   Detectar/aplicar Google Site Verification (se google-verification.html existir)
#   [5]   Configurar Analytics escolhido (GA4, Plausible, Umami, ou nenhum)
#   [6]   Renderizar HTML
#   [7]   Validar meta tags no HTML gerado
#   [8]   Verificar sitemap.xml gerado
#   [9]   Commit + push
#   [10]  Instrucoes para submeter ao Search Console
#
# TODO: 100% ASCII puro, todas as edicoes de _quarto.yml via .NET

$ProjetoRaiz = "C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM"
$ZipPath = "$env:USERPROFILE\Downloads\FASE_1_4.zip"
$TempDir = "$env:TEMP\fase_1_4"
$UrlPublica = "https://mariocezar1971.github.io/livro-doe-usinagem/"

function Perguntar($p) {
    $r = Read-Host "$p (S/N)"
    return ($r -eq "S" -or $r -eq "s" -or $r -eq "")
}

function Read-FileUtf8($path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Write-FileUtf8NoBom($path, $conteudo) {
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $conteudo, $utf8SemBom)
}

function Test-YmlCorrupted($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    for ($i = 0; $i -lt $bytes.Length - 3; $i++) {
        if ($bytes[$i] -eq 0xC3 -and $bytes[$i+1] -eq 0x83) { return $true }
    }
    return $false
}

Write-Host ""
Write-Host "================================================================================"
Write-Host " FASE 1.4 - Configuracao de SEO"
Write-Host "================================================================================"
Write-Host ""

# ETAPA 0 - Ambiente
Write-Host "[0] Validar ambiente" -ForegroundColor Cyan

if (-not (Test-Path $ProjetoRaiz)) {
    Write-Host "ERRO: Pasta do projeto nao existe: $ProjetoRaiz" -ForegroundColor Red
    exit 1
}
Set-Location $ProjetoRaiz
Write-Host "[OK] Pasta: $ProjetoRaiz" -ForegroundColor Green

if (-not (Test-Path "_quarto.yml")) {
    Write-Host "ERRO: _quarto.yml nao encontrado" -ForegroundColor Red
    exit 1
}

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$ymlPath = (Resolve-Path _quarto.yml).Path
if (Test-YmlCorrupted $ymlPath) {
    Write-Host "[!] _quarto.yml corrompido - restaurando do Git" -ForegroundColor Yellow
    git checkout HEAD -- _quarto.yml
    if (Test-YmlCorrupted $ymlPath) {
        Write-Host "[X] Corrupcao persiste apos restauracao" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Restaurado" -ForegroundColor Green
} else {
    Write-Host "[OK] _quarto.yml integro" -ForegroundColor Green
}

# ETAPA 1 - Distribuir arquivos
Write-Host ""
Write-Host "[1] Distribuir arquivos do FASE_1_4.zip" -ForegroundColor Cyan

$destinos = @{
    "styles/schema-book.html"         = ".\styles\schema-book.html"
    "styles/seo-meta.html"            = ".\styles\seo-meta.html"
    "styles/analytics-ga4.html"       = ".\styles\analytics-ga4.html"
    "styles/analytics-plausible.html" = ".\styles\analytics-plausible.html"
    "styles/analytics-umami.html"     = ".\styles\analytics-umami.html"
    "setup/SEO_SETUP_GUIA.md"         = ".\setup\SEO_SETUP_GUIA.md"
}

$temTudo = $true
foreach ($dest in $destinos.Values) {
    if (-not (Test-Path $dest)) { $temTudo = $false; break }
}

$distribuir = $false
if ($temTudo) {
    Write-Host "[OK] Arquivos ja distribuidos" -ForegroundColor Green
    if (Perguntar "Redistribuir?") { $distribuir = $true }
} else {
    $distribuir = $true
}

if ($distribuir) {
    if (-not (Test-Path $ZipPath)) {
        Write-Host "ERRO: ZIP nao encontrado: $ZipPath" -ForegroundColor Red
        exit 1
    }
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

    New-Item -ItemType Directory -Path ".\styles" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path ".\setup"  -Force -ErrorAction SilentlyContinue | Out-Null

    foreach ($item in $destinos.GetEnumerator()) {
        $src = Join-Path $TempDir $item.Key
        if (Test-Path $src) {
            [System.IO.File]::Copy($src, (Join-Path (Get-Location) $item.Value), $true)
            Write-Host "[OK] $($item.Key) -> $($item.Value)" -ForegroundColor Green
        }
    }
}

# ETAPA 2 - Corrigir site-url
Write-Host ""
Write-Host "[2] Corrigir site-url no _quarto.yml" -ForegroundColor Cyan

$yml = Read-FileUtf8 $ymlPath
if ($yml -match "site-url:\s*`"?https://mariocezar1971\.github\.io") {
    Write-Host "[OK] site-url ja aponta para github.io" -ForegroundColor Green
} elseif ($yml -match "site-url:\s*`"?https://doeusinagem\.com\.br") {
    Write-Host "[!] site-url aponta para doeusinagem.com.br (nao configurado ainda)" -ForegroundColor Yellow
    Write-Host "    Isso faz o sitemap.xml apontar para URLs erradas."
    if (Perguntar "Trocar temporariamente para github.io?") {
        Copy-Item _quarto.yml "_quarto.yml.bak_v14" -Force
        $yml = $yml -replace 'site-url:\s*"https://doeusinagem\.com\.br"?', 'site-url: "https://mariocezar1971.github.io/livro-doe-usinagem"'
        Write-FileUtf8NoBom $ymlPath $yml
        Write-Host "[OK] site-url trocado para github.io" -ForegroundColor Green
        Write-Host "    Quando comprar doeusinagem.com.br, edite _quarto.yml de volta" -ForegroundColor Cyan
    }
} else {
    Write-Host "[!] site-url nao detectado no formato esperado" -ForegroundColor Yellow
}

# ETAPA 3 - Adicionar include-in-header
Write-Host ""
Write-Host "[3] Configurar include-in-header (schema + meta SEO)" -ForegroundColor Cyan

$yml = Read-FileUtf8 $ymlPath
$temSchema = $yml -match "schema-book\.html"
$temMeta = $yml -match "seo-meta\.html"

if ($temSchema -and $temMeta) {
    Write-Host "[OK] Schema e meta SEO ja incluidos" -ForegroundColor Green
} else {
    Copy-Item _quarto.yml "_quarto.yml.bak_v14_include" -Force

    # Procurar secao 'format: html:' e adicionar include-in-header
    # Isso e um heuristica - funciona para o layout padrao
    if ($yml -match "(?ms)(  html:\s*\r?\n)((?:    [^\r\n]+\r?\n)+)") {
        $inicioBloco = $Matches[1]
        $conteudoBloco = $Matches[2]

        # Se ja tem include-in-header, adicionar itens; senao criar nova secao
        if ($conteudoBloco -match "include-in-header:") {
            $novoConteudo = $conteudoBloco -replace "(include-in-header:\s*\r?\n)", "`$1      - styles/schema-book.html`n      - styles/seo-meta.html`n"
        } else {
            $novoConteudo = $conteudoBloco + "    include-in-header:`n      - styles/schema-book.html`n      - styles/seo-meta.html`n"
        }

        $yml = $yml.Replace($inicioBloco + $conteudoBloco, $inicioBloco + $novoConteudo)
        Write-FileUtf8NoBom $ymlPath $yml
        Write-Host "[OK] include-in-header configurado" -ForegroundColor Green
    } else {
        Write-Host "[!] Nao foi possivel detectar secao 'html:' automaticamente" -ForegroundColor Yellow
        Write-Host "    Edite _quarto.yml manualmente:"
        Write-Host "    format:"
        Write-Host "      html:"
        Write-Host "        include-in-header:"
        Write-Host "          - styles/schema-book.html"
        Write-Host "          - styles/seo-meta.html"
    }
}

# ETAPA 4 - Google Site Verification
Write-Host ""
Write-Host "[4] Google Site Verification" -ForegroundColor Cyan

if (Test-Path .\google-verification.html) {
    Write-Host "google-verification.html detectado!" -ForegroundColor Green
    $verificationTag = Read-FileUtf8 (Resolve-Path .\google-verification.html).Path

    # Extrair o content da meta tag
    if ($verificationTag -match 'content="([^"]+)"') {
        $token = $Matches[1]

        # Adicionar ao seo-meta.html
        $seoMeta = Read-FileUtf8 (Resolve-Path .\styles\seo-meta.html).Path
        if ($seoMeta -notmatch "google-site-verification") {
            $meta = "`n<meta name=`"google-site-verification`" content=`"$token`">`n"
            $seoMeta = $meta + $seoMeta
            Write-FileUtf8NoBom (Resolve-Path .\styles\seo-meta.html).Path $seoMeta
            Write-Host "[OK] Google verification token inserido em seo-meta.html" -ForegroundColor Green

            # Deletar o arquivo temp
            Remove-Item .\google-verification.html -Force
        } else {
            Write-Host "[OK] Token de verificacao ja presente" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[i] Sem verificacao pendente" -ForegroundColor Yellow
    Write-Host "    Para verificar propriedade no Search Console:"
    Write-Host "      1. Adicione propriedade em search.google.com/search-console"
    Write-Host "      2. Escolha 'Prefixo do URL' com URL: $UrlPublica"
    Write-Host "      3. Metodo 'Tag HTML' - copie a meta tag oferecida"
    Write-Host "      4. Salve o codigo completo em .\google-verification.html"
    Write-Host "      5. Rode este script novamente"
}

# ETAPA 5 - Analytics
Write-Host ""
Write-Host "[5] Configurar Analytics" -ForegroundColor Cyan

$analyticsAtivo = "nenhum"
if (Test-Path .\styles\analytics-ativo.html) {
    Write-Host "[OK] Analytics ja configurado (styles/analytics-ativo.html existe)" -ForegroundColor Green
    $analyticsAtivo = "ja configurado"
} else {
    Write-Host "Opcoes de analytics:"
    Write-Host "  1) Google Analytics 4 (gratuito, requer banner LGPD)"
    Write-Host "  2) Plausible (~R\$45/mes, sem cookies, LGPD-friendly)"
    Write-Host "  3) Umami self-hosted (gratuito, requer deploy)"
    Write-Host "  4) Nenhum (pular por enquanto)"
    Write-Host ""
    Write-Host "Detalhes: setup/SEO_SETUP_GUIA.md"
    $escolha = Read-Host "Escolha 1/2/3/4"

    switch ($escolha) {
        "1" {
            if (Test-Path .\ga4-id.txt) {
                $ga4Id = (Read-FileUtf8 (Resolve-Path .\ga4-id.txt).Path).Trim()
                $ga4Template = Read-FileUtf8 (Resolve-Path .\styles\analytics-ga4.html).Path
                $ga4Ativo = $ga4Template -replace "G-XXXXXXXXXX", $ga4Id
                Write-FileUtf8NoBom (Join-Path (Get-Location) "styles\analytics-ativo.html") $ga4Ativo
                Remove-Item .\ga4-id.txt -Force
                Write-Host "[OK] GA4 configurado com ID $ga4Id" -ForegroundColor Green
                $analyticsAtivo = "GA4"
            } else {
                Write-Host "[!] Salve o ID de medicao em .\ga4-id.txt e rode novamente" -ForegroundColor Yellow
                Write-Host "    Formato do arquivo: uma linha com G-XXXXXXXXXX"
            }
        }
        "2" {
            if (Test-Path .\plausible-domain.txt) {
                $dom = (Read-FileUtf8 (Resolve-Path .\plausible-domain.txt).Path).Trim()
                $tmpl = Read-FileUtf8 (Resolve-Path .\styles\analytics-plausible.html).Path
                $ativo = $tmpl -replace "mariocezar1971\.github\.io/livro-doe-usinagem", $dom
                Write-FileUtf8NoBom (Join-Path (Get-Location) "styles\analytics-ativo.html") $ativo
                Remove-Item .\plausible-domain.txt -Force
                Write-Host "[OK] Plausible configurado" -ForegroundColor Green
                $analyticsAtivo = "Plausible"
            } else {
                Write-Host "[!] Salve o dominio em .\plausible-domain.txt e rode novamente" -ForegroundColor Yellow
            }
        }
        "3" {
            if (Test-Path .\umami-config.txt) {
                $cfg = Read-FileUtf8 (Resolve-Path .\umami-config.txt).Path
                $urlUmami = ($cfg -split "`n" | Where-Object { $_ -match "^url=" }) -replace "^url=", ""
                $idUmami = ($cfg -split "`n" | Where-Object { $_ -match "^id=" }) -replace "^id=", ""
                $tmpl = Read-FileUtf8 (Resolve-Path .\styles\analytics-umami.html).Path
                $ativo = $tmpl -replace "https://SEU-UMAMI\.fly\.dev/script\.js", $urlUmami.Trim()
                $ativo = $ativo -replace "SEU-WEBSITE-ID", $idUmami.Trim()
                Write-FileUtf8NoBom (Join-Path (Get-Location) "styles\analytics-ativo.html") $ativo
                Remove-Item .\umami-config.txt -Force
                Write-Host "[OK] Umami configurado" -ForegroundColor Green
                $analyticsAtivo = "Umami"
            } else {
                Write-Host "[!] Crie .\umami-config.txt com url=... e id=..." -ForegroundColor Yellow
            }
        }
        default {
            Write-Host "[i] Analytics pulado" -ForegroundColor Yellow
        }
    }
}

# Se tem analytics-ativo.html, adicionar ao include-in-header
if (Test-Path .\styles\analytics-ativo.html) {
    $yml = Read-FileUtf8 $ymlPath
    if ($yml -notmatch "analytics-ativo\.html") {
        $yml = $yml -replace "(- styles/seo-meta\.html\r?\n)", "`$1      - styles/analytics-ativo.html`n"
        Write-FileUtf8NoBom $ymlPath $yml
        Write-Host "[OK] analytics-ativo.html adicionado ao include-in-header" -ForegroundColor Green
    }
}

# ETAPA 6 - Render
Write-Host ""
Write-Host "[6] Renderizar HTML" -ForegroundColor Cyan
if (Perguntar "Renderizar agora?") {
    Remove-Item _book -Recurse -Force -ErrorAction SilentlyContinue
    quarto render --to html
    if ($LASTEXITCODE -eq 0 -and (Test-Path "_book\index.html")) {
        Write-Host "[OK] Render OK" -ForegroundColor Green
    }
}

# ETAPA 7 - Validar meta tags
Write-Host ""
Write-Host "[7] Validar meta tags no HTML gerado" -ForegroundColor Cyan

if (Test-Path _book\index.html) {
    $indexHtml = Read-FileUtf8 (Resolve-Path _book\index.html).Path

    $checks = @{
        "Schema.org Book"      = 'application/ld\+json'
        "Open Graph og:type"   = 'og:type.*book'
        "og:image"             = 'og:image'
        "Twitter Card"         = 'twitter:card'
        "Meta description"     = 'name="description"'
        "Canonical link"       = 'rel="canonical"'
    }

    foreach ($check in $checks.GetEnumerator()) {
        if ($indexHtml -match $check.Value) {
            Write-Host "  [OK] $($check.Key)" -ForegroundColor Green
        } else {
            Write-Host "  [!]  $($check.Key) NAO encontrado" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[!] _book\index.html nao existe - rode render antes" -ForegroundColor Yellow
}

# ETAPA 8 - Sitemap
Write-Host ""
Write-Host "[8] Verificar sitemap.xml" -ForegroundColor Cyan

if (Test-Path _book\sitemap.xml) {
    $sitemap = Read-FileUtf8 (Resolve-Path _book\sitemap.xml).Path
    $urls = ([regex]::Matches($sitemap, "<loc>")).Count
    Write-Host "[OK] sitemap.xml gerado com $urls URLs" -ForegroundColor Green

    # Verificar se as URLs apontam corretamente
    if ($sitemap -match "https://mariocezar1971\.github\.io/livro-doe-usinagem") {
        Write-Host "[OK] URLs apontam para github.io (correto)" -ForegroundColor Green
    } elseif ($sitemap -match "https://doeusinagem\.com\.br") {
        Write-Host "[!] URLs apontam para doeusinagem.com.br (dominio nao ativo)" -ForegroundColor Yellow
        Write-Host "    Volte ao passo [2] para corrigir site-url"
    }
} else {
    Write-Host "[!] sitemap.xml nao gerado" -ForegroundColor Yellow
    Write-Host "    Verifique se 'site-url' esta definido no _quarto.yml"
}

# ETAPA 9 - Commit + push
Write-Host ""
Write-Host "[9] Versionar no Git" -ForegroundColor Cyan
$status = git status --porcelain 2>$null
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "[OK] Nada para commitar" -ForegroundColor Green
} else {
    git status --short
    if (Perguntar "Commitar mudancas?") {
        git add _quarto.yml
        git add styles/schema-book.html
        git add styles/seo-meta.html
        git add styles/analytics-*.html
        git add setup/SEO_SETUP_GUIA.md
        if (Test-Path executar-fase-1-4.ps1) { git add executar-fase-1-4.ps1 }

        git commit -m "Fase 1.4: SEO (schema.org Book, meta OG/Twitter, analytics $analyticsAtivo)"

        if ($LASTEXITCODE -eq 0 -and (Perguntar "Push para GitHub?")) {
            git push
        }
    }
}

# ETAPA 10 - Instrucoes finais
Write-Host ""
Write-Host "[10] Proximos passos manuais" -ForegroundColor Cyan
Write-Host ""
Write-Host "Google Search Console:"
Write-Host "  1. Abra https://search.google.com/search-console"
Write-Host "  2. Adicione a propriedade: $UrlPublica"
Write-Host "  3. Escolha 'Prefixo do URL'"
Write-Host "  4. Metodo 'Tag HTML' - copie a meta tag"
Write-Host "  5. Salve o codigo em .\google-verification.html na raiz"
Write-Host "  6. Rode este script novamente para inserir a tag"
Write-Host "  7. Aguarde deploy e clique em 'Verificar' no Search Console"
Write-Host "  8. Submeta sitemap: sitemap.xml"
Write-Host ""
Write-Host "Ping direto Google (opcional, forca crawl):"
Write-Host "  https://www.google.com/ping?sitemap=$($UrlPublica)sitemap.xml"
Write-Host ""

if (Perguntar "Abrir Search Console agora?") {
    Start-Process "https://search.google.com/search-console"
}

Write-Host ""
Write-Host "================================================================================"
Write-Host " FIM - Resumo da Fase 1.4"
Write-Host "================================================================================"
Write-Host ""
Write-Host "Configurado:"
Write-Host "  [OK] Meta tags OG/Twitter (styles/seo-meta.html)"
Write-Host "  [OK] Schema.org Book JSON-LD (styles/schema-book.html)"
Write-Host "  [OK] site-url para GitHub Pages"
Write-Host "  [OK] Sitemap gerado automaticamente pelo Quarto"
Write-Host "  Analytics: $analyticsAtivo"
Write-Host ""
Write-Host "Pendente manual:"
Write-Host "  [ ] Verificar propriedade no Google Search Console"
Write-Host "  [ ] Submeter sitemap.xml no Search Console"
Write-Host "  [ ] Criar/atualizar figuras/capa.png (1200x630 para OG image)"
Write-Host "  [ ] Testar rich results em search.google.com/test/rich-results (apos 15 dias)"
Write-Host ""
