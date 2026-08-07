# ============================================================================
# executar-fase-0-1.ps1
#
# Orquestrador interativo da Fase 0.1 - Decisoes Editoriais Fundadoras
#
# 5 decisoes fundadoras do livro:
#   1. Titulo e subtitulo finais
#   2. Publico-alvo primario
#   3. Precos (PDF, Impresso, HTML)
#   4. Prefacio do Prof. Alisson Machado
#   5. Nome do dominio
#
# CARACTERISTICAS:
#   - Deduplicacao embutida (nao repete itens em reruns)
#   - Registra decisoes com timestamp e nota justificativa
#   - Verificacao de domino via DNS (opcional)
#   - Analise contextual (precos comparaveis, referencias)
#
# Persistencia:
#   setup/fase-0-1-progresso.json          - estado JSON
#   setup/FASE_0_1_DECISOES.md             - decisoes documentadas
#
# USO:
#   .\executar-fase-0-1.ps1                # Executar todas as 5 decisoes
#   .\executar-fase-0-1.ps1 -Item 3        # Ir direto para uma decisao
#   .\executar-fase-0-1.ps1 -Status        # Ver progresso
#   .\executar-fase-0-1.ps1 -Reset         # Zerar (com confirmacao)
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateRange(1, 5)]
    [int]$Item = 0,
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup       = ".\setup"
$Script:ArquivoProgresso = ".\setup\fase-0-1-progresso.json"
$Script:ArquivoDoc       = ".\setup\FASE_0_1_DECISOES.md"

# Sugestoes padrao (baseadas em memoria do projeto)
$Script:Sugestoes = @{
    Titulo    = 'Planejamento de Experimentos em Usinagem'
    Subtitulo = 'Fatorial, RSM e otimizacao multiresposta aplicados as ligas de aluminio'
    PublicoPrimario = 'Pos-graduacao em Eng Mecanica e Eng Producao'
    PrecoPDF      = '79'
    PrecoImpresso = '119'
    PrecoHTML     = '0'
    Dominio       = 'doeusinagem.com.br'
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

function Ask-YesNo($pergunta) {
    while ($true) {
        $r = Read-Host "$pergunta (S/N)"
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
# PERSISTENCIA DE ESTADO
# ============================================================================
function Initialize-Progresso {
    if (-not (Test-Path $Script:PastaSetup)) {
        New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    }

    if (Test-Path $Script:ArquivoProgresso) {
        $json = Get-Content $Script:ArquivoProgresso -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    }

    # Estrutura inicial
    $progresso = [PSCustomObject]@{
        fase          = "0.1"
        titulo        = "Decisoes Editoriais Fundadoras"
        iniciada_em   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        decisoes      = @()
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

# Deduplicacao EMBUTIDA: se decisao ja existe (mesmo id), sobrescreve
function Set-Decisao($progresso, $id, $nome, $valor, $justificativa = "") {
    $decisao = [PSCustomObject]@{
        id             = $id
        nome           = $nome
        valor          = $valor
        justificativa  = $justificativa
        decidida_em    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    # Se existe uma decisao com mesmo id, remove antes de adicionar
    $novaLista = @($progresso.decisoes | Where-Object { $_.id -ne $id })
    $novaLista += $decisao
    $progresso.decisoes = @($novaLista)

    return $decisao
}

function Get-Decisao($progresso, $id) {
    return $progresso.decisoes | Where-Object { $_.id -eq $id } | Select-Object -First 1
}

# ============================================================================
# GERAR DOCUMENTACAO MARKDOWN
# ============================================================================
function Update-Documentacao($progresso) {
    $md = "# Fase 0.1 - Decisoes Editoriais Fundadoras`n`n"
    $md += "**Gerado automaticamente por executar-fase-0-1.ps1**`n"
    $md += "Ultima atualizacao: $($progresso.atualizada_em)`n`n"
    $md += "Total de decisoes tomadas: $($progresso.decisoes.Count) de 5`n`n---`n`n"

    if ($progresso.decisoes.Count -eq 0) {
        $md += "*Nenhuma decisao registrada ainda.*`n"
    } else {
        # Ordenar por id
        $ordenadas = $progresso.decisoes | Sort-Object id

        foreach ($d in $ordenadas) {
            $md += "## $($d.id). $($d.nome)`n`n"
            $md += "**Decisao:** $($d.valor)`n`n"
            if ($d.justificativa) {
                $md += "**Justificativa:** $($d.justificativa)`n`n"
            }
            $md += "**Decidida em:** $($d.decidida_em)`n`n"
            $md += "---`n`n"
        }
    }

    $path = if (Test-Path $Script:ArquivoDoc) {
        (Resolve-Path $Script:ArquivoDoc).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoDoc
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $md, $utf8SemBom)
}

# ============================================================================
# DECISAO 1 - TITULO E SUBTITULO
# ============================================================================
function Decidir-Titulo($progresso) {
    Write-Etapa "1" "Confirmar titulo e subtitulo finais"

    $existente = Get-Decisao $progresso "1"
    if ($existente) {
        Write-Info "Decisao ja registrada: $($existente.valor)"
        if (-not (Ask-YesNo "Deseja revisar?")) { return }
    }

    Write-Item "Titulo sugerido:"
    Write-Item "  '$($Script:Sugestoes.Titulo)'"
    Write-Item ""
    Write-Item "Subtitulo sugerido:"
    Write-Item "  '$($Script:Sugestoes.Subtitulo)'"
    Write-Item ""
    Write-Item "Consideracoes:"
    Write-Item "  - Titulo curto (5 palavras) - bom para SEO e memoria"
    Write-Item "  - Subtitulo enumera metodos (Fatorial, RSM, otim) - facilita busca"
    Write-Item "  - Menciona 'ligas de aluminio' - especifica o escopo"

    if (Ask-YesNo "Aceitar titulo e subtitulo sugeridos?") {
        $valor = "$($Script:Sugestoes.Titulo) - $($Script:Sugestoes.Subtitulo)"
        $just  = "Titulo curto memoravel, subtitulo enumera metodos, escopo especifico em aluminio"
    } else {
        $titulo    = Ask-Text "Titulo desejado" $Script:Sugestoes.Titulo
        $subtitulo = Ask-Text "Subtitulo desejado" $Script:Sugestoes.Subtitulo
        $valor = "$titulo - $subtitulo"
        $just  = Ask-Text "Justificativa da mudanca (opcional)" ""
    }

    Set-Decisao $progresso "1" "Titulo e subtitulo" $valor $just | Out-Null
    Write-OK "Decisao 1 registrada"

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# DECISAO 2 - PUBLICO-ALVO PRIMARIO
# ============================================================================
function Decidir-Publico($progresso) {
    Write-Etapa "2" "Definir publico-alvo primario"

    $existente = Get-Decisao $progresso "2"
    if ($existente) {
        Write-Info "Decisao ja registrada: $($existente.valor)"
        if (-not (Ask-YesNo "Deseja revisar?")) { return }
    }

    Write-Item "3 publicos potenciais (nao mutuamente exclusivos):"
    Write-Item ""
    Write-Item "  A) Pos-graduacao em Eng Mecanica e Eng Producao"
    Write-Item "     - Mestrandos e doutorandos com projeto de DOE em curso"
    Write-Item "     - Buscam base teorica + exemplo integrado"
    Write-Item "     - ~15.000 alunos ativos no Brasil"
    Write-Item ""
    Write-Item "  B) Engenheiros de manufatura na industria"
    Write-Item "     - Chao de fabrica, melhoria continua, Six Sigma"
    Write-Item "     - Buscam solucao pragmatica para problemas reais"
    Write-Item "     - Base potencial: ~50.000 engenheiros no Brasil"
    Write-Item ""
    Write-Item "  C) Professores/pesquisadores em usinagem"
    Write-Item "     - Adotam livros em disciplinas de pos-graduacao"
    Write-Item "     - Compram para acervo pessoal e biblioteca"
    Write-Item "     - Base menor mas mais influente (~500 no Brasil)"
    Write-Item ""
    Write-Item "IMPACTO DA ESCOLHA:"
    Write-Item "  A -> tom academico, mais rigor estatistico"
    Write-Item "  B -> tom pragmatico, casos industriais fortes"
    Write-Item "  C -> tom formal, referencias bibliograficas densas"

    $opcao = Ask-Text "Publico primario (A, B, C, ou combinacao ex: 'AB')" "A"

    $mapa = @{
        "A"  = "Pos-graduacao em Eng Mecanica e Eng Producao"
        "B"  = "Engenheiros de manufatura na industria"
        "C"  = "Professores/pesquisadores em usinagem"
        "AB" = "Pos-graduacao + Engenheiros industriais (foco duplo)"
        "AC" = "Pos-graduacao + Professores/pesquisadores"
        "BC" = "Engenheiros industriais + Professores"
        "ABC"= "Todos os tres publicos"
    }

    $valor = if ($mapa.ContainsKey($opcao.ToUpper())) { $mapa[$opcao.ToUpper()] } else { $opcao }

    Write-Info "Publico definido: $valor"

    $just = Ask-Text "Justificativa da escolha (opcional)" ""

    Set-Decisao $progresso "2" "Publico-alvo primario" $valor $just | Out-Null
    Write-OK "Decisao 2 registrada"

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# DECISAO 3 - PRECOS
# ============================================================================
function Decidir-Precos($progresso) {
    Write-Etapa "3" "Definir precos (PDF, Impresso, HTML)"

    $existente = Get-Decisao $progresso "3"
    if ($existente) {
        Write-Info "Decisao ja registrada: $($existente.valor)"
        if (-not (Ask-YesNo "Deseja revisar?")) { return }
    }

    Write-Item "Precos sugeridos:"
    Write-Item '  PDF        R$79'
    Write-Item '  Impresso   R$119'
    Write-Item '  HTML       R$0 (gratuito - Creative Commons)'
    Write-Item ""
    Write-Item "Comparaveis do mercado (livros tecnicos BR):"
    Write-Item '  Montgomery DOE (traducao): R$180-250 impresso'
    Write-Item '  Ferramentas Qualidade (Werkema): R$60-90 PDF'
    Write-Item '  Livros SBS/Blucher tecnicos: R$120-200 impresso'
    Write-Item ""
    Write-Item "Consideracoes estrategicas:"
    Write-Item "  - Preco baixo demais reduz percepcao de valor"
    Write-Item "  - HTML gratuito e ISCA para PDF (leitor curte, quer versao offline)"
    Write-Item "  - Impresso e pouco elastico ao preco (comprador quer o objeto)"
    Write-Item "  - Kiwify cobra 4% + R\$1 - considerar na margem"

    if (Ask-YesNo "Aceitar precos sugeridos?") {
        $pdf      = $Script:Sugestoes.PrecoPDF
        $impresso = $Script:Sugestoes.PrecoImpresso
        $html     = $Script:Sugestoes.PrecoHTML
    } else {
        $pdf      = Ask-Text 'Preco PDF (R$)' $Script:Sugestoes.PrecoPDF
        $impresso = Ask-Text 'Preco Impresso (R$)' $Script:Sugestoes.PrecoImpresso
        $html     = Ask-Text 'Preco HTML (R$)' $Script:Sugestoes.PrecoHTML
    }

    $valor = "PDF R`$$pdf | Impresso R`$$impresso | HTML R`$$html"
    Write-Info "Precos: $valor"

    # Calcular margens brutas estimadas
    Write-Item ""
    Write-Item "Analise rapida de margem estimada:"
    $margenPDF = [math]::Round([int]$pdf * 0.96 - 1, 2)
    $margenKDP = [math]::Round([int]$impresso * 0.60, 2)
    Write-Item "  PDF via Kiwify (4% + R\$1): recebe ~R\$$margenPDF"
    Write-Item "  Impresso via KDP (~40% royalty): recebe ~R\$$margenKDP"

    $just = Ask-Text "Justificativa dos precos (opcional)" "Precos escolhidos considerando percepcao de valor + margens Kiwify/KDP"

    Set-Decisao $progresso "3" "Precos" $valor $just | Out-Null
    Write-OK "Decisao 3 registrada"

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# DECISAO 4 - PREFACIO DO PROF. ALISSON MACHADO
# ============================================================================
function Decidir-Prefacio($progresso) {
    Write-Etapa "4" "Decidir sobre prefacio do Prof. Alisson Rocha Machado"

    $existente = Get-Decisao $progresso "4"
    if ($existente) {
        Write-Info "Decisao ja registrada: $($existente.valor)"
        if (-not (Ask-YesNo "Deseja revisar?")) { return }
    }

    Write-Item "Contexto:"
    Write-Item "  - Prof. Alisson Machado foi orientador da tese UFU (2012)"
    Write-Item "  - Referencia nacional em usinagem"
    Write-Item "  - Prefacio dele agrega credibilidade academica ao livro"
    Write-Item ""
    Write-Item "3 opcoes:"
    Write-Item ""
    Write-Item "  A) SIM - convidar e aguardar prefacio"
    Write-Item "     - Add ~2-4 semanas ao cronograma final"
    Write-Item "     - Requer manuscrito completo ou proximo do final"
    Write-Item "     - Valor: credibilidade + endorsement + rede de contatos"
    Write-Item ""
    Write-Item "  B) NAO - dispensar prefacio externo"
    Write-Item "     - Livro sai apenas com prefacio proprio"
    Write-Item "     - Mais agilidade no cronograma"
    Write-Item "     - Perde impulso academico inicial"
    Write-Item ""
    Write-Item "  C) DECIDIR DEPOIS - deixar para reta final"
    Write-Item "     - Foca em escrever agora"
    Write-Item "     - Avalia quando manuscrito estiver 80% pronto"
    Write-Item "     - Padrao mais pragmatico"

    Write-Item ""
    Write-Warn "IMPORTANTE: se for pedir, tenha 3 coisas prontas antes do convite:"
    Write-Item "  1. Manuscrito quase final (80%+)"
    Write-Item "  2. Sinopse e indice enviaveis por email"
    Write-Item "  3. Prazo realista (pedir com 4-6 semanas de antecedencia)"

    $opcao = Ask-Text "Escolha (A/B/C)" "C"

    $mapa = @{
        "A" = "Convidar Prof. Alisson Machado para prefacio (aguardar reta final)"
        "B" = "Sem prefacio externo (apenas prefacio proprio)"
        "C" = "Decisao adiada para quando manuscrito estiver 80% pronto"
    }

    $valor = if ($mapa.ContainsKey($opcao.ToUpper())) { $mapa[$opcao.ToUpper()] } else { $opcao }
    Write-Info "Decisao: $valor"

    $just = Ask-Text "Justificativa (opcional)" ""

    Set-Decisao $progresso "4" "Prefacio Prof. Alisson Machado" $valor $just | Out-Null
    Write-OK "Decisao 4 registrada"

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# DECISAO 5 - NOME DO DOMINIO
# ============================================================================
function Decidir-Dominio($progresso) {
    Write-Etapa "5" "Definir nome do dominio"

    $existente = Get-Decisao $progresso "5"
    if ($existente) {
        Write-Info "Decisao ja registrada: $($existente.valor)"
        if (-not (Ask-YesNo "Deseja revisar?")) { return }
    }

    Write-Item "Dominio sugerido: $($Script:Sugestoes.Dominio)"
    Write-Item ""
    Write-Item "Analise do dominio sugerido:"
    Write-Item "  + Curto (12 caracteres) - facil digitar/lembrar"
    Write-Item "  + .com.br - reforca posicionamento brasileiro"
    Write-Item "  + Descritivo - engenheiros entendem 'DOE usinagem'"
    Write-Item "  + SEO friendly - keywords no proprio dominio"
    Write-Item "  - Nao universaliza (dominio para publico BR)"
    Write-Item ""
    Write-Item "Alternativas a considerar:"
    Write-Item "  - livrodoeusinagem.com.br  (mais explicito)"
    Write-Item "  - doenaindustria.com.br    (mais amplo)"
    Write-Item "  - cezarengenharia.com.br   (nome pessoal)"
    Write-Item "  - planejamentoexperimentos.com.br (longo)"
    Write-Item ""
    Write-Item "IMPORTANTE:"
    Write-Item "  - Verificar disponibilidade em registro.br"
    Write-Item "  - Custo: R\$40/ano (dominio .com.br pessoa fisica)"
    Write-Item "  - Nao registre antes de decidir - registro trava a decisao"

    $dominio = Ask-Text "Dominio escolhido" $Script:Sugestoes.Dominio

    # Verificar disponibilidade via DNS
    if (Ask-YesNo "Verificar se dominio ja esta registrado (via DNS)?") {
        Write-Info "Consultando DNS..."
        try {
            $resultado = Resolve-DnsName -Name $dominio -Type A -ErrorAction Stop
            if ($resultado) {
                Write-Warn "Dominio '$dominio' aparenta estar REGISTRADO (resolveu para $($resultado[0].IPAddress))"
                Write-Item "  Verificar em registro.br para confirmar disponibilidade"
            }
        } catch {
            Write-OK "Dominio '$dominio' aparenta estar DISPONIVEL (nao resolveu)"
            Write-Item "  Confirmar em registro.br antes de registrar"
        }
    }

    if (Ask-YesNo "Abrir registro.br para verificar disponibilidade?") {
        Start-Process "https://registro.br/tecnologia/ferramentas/whois/?search=$dominio"
    }

    $registrar = Ask-YesNo "Ja registrou este dominio?"
    $statusDom = if ($registrar) { "REGISTRADO" } else { "PENDENTE" }

    $valor = "$dominio ($statusDom)"
    $just = Ask-Text "Justificativa da escolha (opcional)" ""

    Set-Decisao $progresso "5" "Nome do dominio" $valor $just | Out-Null
    Write-OK "Decisao 5 registrada"

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# MOSTRAR STATUS
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "STATUS FASE 0.1 - Decisoes Editoriais Fundadoras"
    Write-Info "Iniciada em: $($progresso.iniciada_em)"
    Write-Info "Atualizada:  $($progresso.atualizada_em)"
    Write-Host ""
    Write-Info "Total de decisoes tomadas: $($progresso.decisoes.Count) de 5"
    Write-Host ""

    $nomes = @{
        "1" = "Titulo e subtitulo"
        "2" = "Publico-alvo primario"
        "3" = "Precos"
        "4" = "Prefacio Prof. Alisson"
        "5" = "Nome do dominio"
    }

    for ($i = 1; $i -le 5; $i++) {
        $d = Get-Decisao $progresso "$i"
        if ($d) {
            $indicador = "[OK]"
            $cor = "Green"
            $valor = $d.valor
        } else {
            $indicador = "[  ]"
            $cor = "Gray"
            $valor = "(pendente)"
        }

        $linha = "  {0} {1,-35} {2}" -f $indicador, $nomes["$i"], $valor
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Progresso salvo em: $Script:ArquivoProgresso"
    Write-Info "Documentacao em:    $Script:ArquivoDoc"
}

# ============================================================================
# EXECUTAR TODAS AS DECISOES
# ============================================================================
function Executar-Todas($progresso) {
    Write-Titulo "FASE 0.1 - DECISOES EDITORIAIS FUNDADORAS"

    Write-Info "Este orquestrador vai guiar voce por 5 decisoes fundamentais"
    Write-Info "que estabelecem a identidade editorial e comercial do livro."
    Write-Host ""
    Write-Info "Voce pode:"
    Write-Item "  - Aceitar sugestoes padrao (rapido, ~5 min total)"
    Write-Item "  - Deliberar cada item (mais reflexivo, ~15 min total)"
    Write-Item "  - Adiar itens especificos e voltar depois"
    Write-Host ""

    if (-not (Ask-YesNo "Prosseguir?")) { return }

    Decidir-Titulo   $progresso
    Decidir-Publico  $progresso
    Decidir-Precos   $progresso
    Decidir-Prefacio $progresso
    Decidir-Dominio  $progresso

    Write-Host ""
    Write-Titulo "FASE 0.1 - SESSAO CONCLUIDA"
    Mostrar-Status $progresso

    Write-Host ""
    if ($progresso.decisoes.Count -eq 5) {
        Write-OK "TODAS AS 5 DECISOES REGISTRADAS!"
        Write-Info "Voce pode agora atualizar _quarto.yml com essas informacoes"
        Write-Info "e prosseguir para Fase 0.2 (Ambiente de desenvolvimento)"
    } else {
        Write-Warn "$($progresso.decisoes.Count)/5 decisoes registradas"
        Write-Info "Rode novamente para completar as pendentes"
    }
}

# ============================================================================
# EXECUCAO PRINCIPAL
# ============================================================================

# Verificar pasta setup/
if (-not (Test-Path $Script:PastaSetup)) {
    New-Item -ItemType Directory -Path $Script:PastaSetup -Force | Out-Null
    Write-OK "Pasta setup/ criada"
}

# Reset se solicitado
if ($Reset) {
    if (Ask-YesNo "ATENCAO: isto vai apagar as decisoes registradas. Confirmar?") {
        Remove-Item $Script:ArquivoProgresso -ErrorAction SilentlyContinue
        Remove-Item $Script:ArquivoDoc -ErrorAction SilentlyContinue
        Write-OK "Progresso resetado"
    }
    exit 0
}

# Carregar/inicializar progresso
$progresso = Initialize-Progresso

# Se pediu status
if ($Status) {
    Mostrar-Status $progresso
    exit 0
}

# Se especificou item, executar direto
if ($Item -gt 0) {
    switch ($Item) {
        1 { Decidir-Titulo   $progresso }
        2 { Decidir-Publico  $progresso }
        3 { Decidir-Precos   $progresso }
        4 { Decidir-Prefacio $progresso }
        5 { Decidir-Dominio  $progresso }
    }
    Write-Host ""
    Mostrar-Status $progresso
    exit 0
}

# Executar todas as 5 decisoes
Executar-Todas $progresso

Write-Host ""
Write-OK "Encerrando. Progresso salvo em $Script:ArquivoProgresso"
Write-Info "Retomar com: .\executar-fase-0-1.ps1"
