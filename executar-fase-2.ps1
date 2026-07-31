# ============================================================================
# executar-fase-2.ps1 - v2 (atualizado com precos reais CBL e correcoes)
#
# Orquestrador interativo da Fase 2 - Setup Comercial Antecipado
#
# 4 Sub-fases:
#   2.1 Kiwify        (plataforma de venda digital)
#   2.2 Amazon KDP    (venda impressa)
#   2.3 Brevo         (email marketing)
#   2.4 Registros     (legais, fiscais, ISBN, licenca)
#
# CORRECOES v2:
#   - ISBN NAO e gratuito: R$28,60 por unidade (CBL Servicos)
#   - Adicionadas URLs especificas do menu CBL
#   - Bug de escape do $ corrigido (R/mes -> R\$99/mes)
#   - Info sobre Ficha Catalografica (R$65,80) e Codigo Barras (R$41,20)
#   - ISNI opcional (para autores com ORCID como Mario)
#   - Registro Autoral CBL como alternativa a BN
#
# Persistencia:
#   setup/fase-2-progresso.json         - estado JSON (auto-criado/atualizado)
#   setup/FASE_2_CONFIGURACOES.md       - documentacao gerada
#
# USO:
#   .\executar-fase-2.ps1                   # Menu principal
#   .\executar-fase-2.ps1 -Subfase "2.1"    # Ir direto para uma sub-fase
#   .\executar-fase-2.ps1 -Status           # Ver progresso atual
#   .\executar-fase-2.ps1 -Reset            # Zerar progresso
#
# 100% ASCII, PowerShell 5.1 compativel
# ============================================================================

param(
    [ValidateSet("2.1", "2.2", "2.3", "2.4", "")]
    [string]$Subfase = "",
    [switch]$Status,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"

# ============================================================================
# CONFIGURACAO
# ============================================================================
$Script:PastaSetup      = ".\setup"
$Script:ArquivoProgresso = ".\setup\fase-2-progresso.json"
$Script:ArquivoDoc      = ".\setup\FASE_2_CONFIGURACOES.md"

# URLs do CBL Servicos (menu real Minha Conta)
$Script:CBL = @{
    Base            = 'https://www.cblservicos.org.br'
    PerfilPessoa    = 'https://www.cblservicos.org.br/servicos/completar-cadastro/pessoa-fisica/'
    PerfilEmpresa   = 'https://www.cblservicos.org.br/servicos/completar-cadastro/consultar-cnpj/'
    SolicitarISBN   = 'https://www.cblservicos.org.br/servicos/solicitar-isbn/'
    MinhasPublicacoes = 'https://www.cblservicos.org.br/servicos/meus-livros/'
    SolicitarISNI   = 'https://www.cblservicos.org.br/servicos/ISNI/solicitar/'
    RegistroAutoral = 'https://www.cblservicos.org.br/servicos/direito-autoral/solicitar/'
    Duvidas         = 'https://www.cblservicos.org.br/isbn/duvidas-frequentes-isbn/'
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
        if ($r -match '^[NnNn]') { return $false }
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
        fase           = "2"
        titulo         = "Setup Comercial Antecipado"
        iniciada_em    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        atualizada_em  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        subfases       = [PSCustomObject]@{
            "2.1_kiwify"      = New-Subfase "Plataforma de venda digital (Kiwify)"
            "2.2_amazon_kdp"  = New-Subfase "Plataforma de venda impressa (Amazon KDP)"
            "2.3_brevo"       = New-Subfase "Email marketing (Brevo)"
            "2.4_legais"      = New-Subfase "Registros legais, fiscais, ISBN, licenca"
        }
    }
    return $progresso
}

function New-Subfase($titulo) {
    return [PSCustomObject]@{
        titulo      = $titulo
        status      = "pendente"    # pendente | em_andamento | completa
        iniciada_em = $null
        completa_em = $null
        notas       = ""
        itens       = @()
    }
}

function Save-Progresso($progresso) {
    $progresso.atualizada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $json = $progresso | ConvertTo-Json -Depth 10

    # Escrita segura via .NET (evita bugs de encoding)
    $path = if (Test-Path $Script:ArquivoProgresso) {
        (Resolve-Path $Script:ArquivoProgresso).Path
    } else {
        Join-Path (Get-Location) $Script:ArquivoProgresso
    }
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8SemBom)
}

function Add-Item($subfase, $nome, $feito, $notas = "") {
    $item = [PSCustomObject]@{
        nome  = $nome
        feito = $feito
        data  = (Get-Date -Format "yyyy-MM-dd HH:mm")
        notas = $notas
    }
    $subfase.itens += $item
    return $item
}

# ============================================================================
# GERAR DOCUMENTACAO MARKDOWN
# ============================================================================
function Update-Documentacao($progresso) {
    $md = "# Fase 2 - Configuracoes Comerciais`n`n"
    $md += "**Gerado automaticamente por executar-fase-2.ps1**`n"
    $md += "Ultima atualizacao: $($progresso.atualizada_em)`n`n---`n`n"

    foreach ($key in $progresso.subfases.PSObject.Properties.Name) {
        $sf = $progresso.subfases.$key
        $md += "## $($sf.titulo)`n`n"
        $md += "**Status:** $($sf.status)`n"

        if ($sf.iniciada_em) { $md += "**Iniciada em:** $($sf.iniciada_em)`n" }
        if ($sf.completa_em) { $md += "**Concluida em:** $($sf.completa_em)`n" }
        $md += "`n"

        if ($sf.itens.Count -gt 0) {
            $md += "### Itens`n`n"
            foreach ($item in $sf.itens) {
                $check = if ($item.feito) { "[x]" } else { "[ ]" }
                $md += "- $check $($item.nome)"
                if ($item.notas) { $md += " - _$($item.notas)_" }
                $md += "`n"
            }
            $md += "`n"
        }

        if ($sf.notas) {
            $md += "### Notas`n`n$($sf.notas)`n`n"
        }

        $md += "---`n`n"
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
# SUB-FASE 2.1 - KIWIFY
# ============================================================================
function Executar-Kiwify($progresso) {
    Write-Titulo "SUB-FASE 2.1 - Plataforma de Venda Digital (Kiwify)"

    $sf = $progresso.subfases."2.1_kiwify"
    if ($sf.status -eq "pendente") {
        $sf.iniciada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $sf.status = "em_andamento"
    }

    Write-Info "Objetivo: vender PDF + EPUB do livro"
    Write-Info 'Taxa Kiwify: 4% + R$1 por venda'
    Write-Info "Alternativas: Hotmart (mais caro), Eduzz, Braip"

    # ---- Item 1: Criar conta ----
    Write-Etapa "1" "Criar conta na Kiwify"
    if (Ask-YesNo "Abrir kiwify.com.br agora?") {
        Start-Process "https://dashboard.kiwify.com.br/register"
        Read-Host "Pressione Enter apos criar a conta"
    }
    $criouConta = Ask-YesNo "Conta criada com sucesso?"
    if ($criouConta) {
        $email = Ask-Text "Email cadastrado na Kiwify" ""
        Add-Item $sf "Criar conta Kiwify" $true "email: $email" | Out-Null
        Write-OK "Conta criada"
    } else {
        Add-Item $sf "Criar conta Kiwify" $false "" | Out-Null
        Write-Warn "Pendente"
    }

    # ---- Item 2: Nota fiscal automatica ----
    Write-Etapa "2" "Emissao automatica de Nota Fiscal"
    Write-Item "Kiwify emite NF automaticamente para vendas B2C"
    Write-Item "Requer: CNPJ configurado ou uso do CNPJ Kiwify (fee adicional)"
    Write-Item "Ver: Configuracoes > Fiscal > Emissao Automatica"
    $nfOk = Ask-YesNo "Emissao automatica de NF esta configurada?"
    Add-Item $sf "Validar emissao automatica de NF" $nfOk | Out-Null

    # ---- Item 3: Marca dagua personalizada ----
    Write-Etapa "3" "Marca d'agua personalizada (CPF + nome do comprador)"
    Write-Item "Reduz pirataria - PDF marcado com dados do comprador"
    Write-Item "Configurar em: Produtos > seu produto > Marca d'Agua"
    Write-Item 'Padrao recomendado: Licenciado a [NOME] - CPF [XXX.XXX.XXX-XX]'
    $mdaOk = Ask-YesNo "Marca d'agua personalizada configurada?"
    Add-Item $sf "Configurar marca d'agua personalizada" $mdaOk | Out-Null

    # ---- Item 4: Entrega automatica ----
    Write-Etapa "4" "Entrega automatica de PDF + EPUB"
    Write-Item "Kiwify envia link do arquivo por email logo apos pagamento"
    Write-Item "Configurar em: Produtos > seu produto > Entrega"
    Write-Item "Upload: PDF + EPUB (ate 2GB por arquivo)"
    Write-Item "IMPORTANTE: o livro ainda nao esta pronto - configurar quando tiver"
    $entregaOk = Ask-YesNo "Entrega automatica testada (ou preparada para quando tiver PDF)?"
    Add-Item $sf "Configurar entrega automatica PDF+EPUB" $entregaOk | Out-Null

    # ---- Item 5: Pix nativo ----
    Write-Etapa "5" "Pix nativo"
    Write-Item "Pix e essencial no Brasil (~60% das vendas)"
    Write-Item "Configurar em: Configuracoes > Pagamentos > Metodos"
    Write-Item "Verifique se Pix esta ativo (deveria ser padrao)"
    $pixOk = Ask-YesNo "Pix nativo esta ativo?"
    Add-Item $sf "Configurar Pix nativo" $pixOk | Out-Null

    # ---- Encerramento da sub-fase ----
    $todosItens = $sf.itens | Where-Object { $_.feito }
    if ($todosItens.Count -eq 5) {
        $sf.status = "completa"
        $sf.completa_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host ""
        Write-OK "SUB-FASE 2.1 COMPLETA (5/5 itens)"
    } else {
        Write-Host ""
        Write-Warn "SUB-FASE 2.1 parcial ($($todosItens.Count)/5 itens)"
        Write-Info "Rode novamente para completar os itens pendentes"
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# SUB-FASE 2.2 - AMAZON KDP
# ============================================================================
function Executar-KDP($progresso) {
    Write-Titulo "SUB-FASE 2.2 - Plataforma de Venda Impressa (Amazon KDP)"

    $sf = $progresso.subfases."2.2_amazon_kdp"
    if ($sf.status -eq "pendente") {
        $sf.iniciada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $sf.status = "em_andamento"
    }

    Write-Info "Objetivo: publicar versao impressa via Print-on-Demand"
    Write-Info "Sem estoque, sem investimento inicial, royalty ~35-40%"
    Write-Warn "Requer: dados bancarios BR, formulario fiscal W-8BEN (EUA)"

    # ---- Item 1: Criar conta ----
    Write-Etapa "1" "Criar conta KDP"
    if (Ask-YesNo "Abrir kdp.amazon.com agora?") {
        Start-Process "https://kdp.amazon.com/en_US/signin"
        Read-Host "Pressione Enter apos criar/logar na conta"
    }
    $criouConta = Ask-YesNo "Conta KDP acessivel?"
    Add-Item $sf "Criar conta Amazon KDP" $criouConta | Out-Null

    # ---- Item 2: Pagamento via banco BR ----
    Write-Etapa "2" "Configurar pagamento (transferencia bancaria BR)"
    Write-Item "Amazon paga em USD - converta para BRL via banco"
    Write-Item "Requer: conta corrente + numero de agencia + banco"
    Write-Item "Config em: Account > Tax Information > Payment Method"
    Write-Item "Alternativa: PayPal (nao recomendado - taxa alta)"
    $bancoOk = Ask-YesNo "Dados bancarios configurados?"
    Add-Item $sf "Configurar pagamento via transferencia bancaria BR" $bancoOk | Out-Null

    # ---- Item 3: W-8BEN ----
    Write-Etapa "3" "Formulario fiscal W-8BEN (tax interview)"
    Write-Item "OBRIGATORIO: reduz retencao de imposto de 30% para 0%"
    Write-Item "Preencher em: Account > Tax Information > Tax Interview"
    Write-Item "Como Brasil tem tratado com EUA, voce paga imposto so no Brasil"
    Write-Item "Requer: CPF (nao TIN), endereco no Brasil"
    Write-Item "Guia detalhado: kdp.amazon.com/en_US/help/topic/G200641090"
    $w8Ok = Ask-YesNo "Tax interview W-8BEN concluida?"
    Add-Item $sf "Verificar formulario W-8BEN" $w8Ok | Out-Null

    # ---- Item 4: Especificacoes 6x9 ----
    Write-Etapa "4" "Estudar especificacoes 6x9 polegadas"
    Write-Item "Formato 6x9 = 15,24 x 22,86 cm (padrao livros tecnicos)"
    Write-Item "Margens: gutter 0,5 pol + externa 0,375 pol"
    Write-Item "Capa: front + spine + back em 1 arquivo (PDF)"
    Write-Item "Ferramenta: Cover Creator do KDP (gratuita)"
    Write-Item "Ou usar template: kdp.amazon.com/cover-templates"
    Write-Item "IMPORTANTE: Quarto pode gerar PDF 6x9 - ver documentacao"
    $specOk = Ask-YesNo "Especificacoes 6x9 estudadas?"
    Add-Item $sf "Estudar especificacoes 6x9 polegadas" $specOk | Out-Null

    # ---- Item 5: Author Central BR ----
    Write-Etapa "5" "Perfil de autor (Author Central BR)"
    Write-Item "Perfil publico do autor na Amazon Brasil"
    Write-Item "Elementos: biografia, foto, redes sociais, lista de obras"
    Write-Item "Cadastro: author.amazon.com.br"
    Write-Item "Aumenta credibilidade - especialmente para livros tecnicos"
    if (Ask-YesNo "Abrir Author Central BR agora?") {
        Start-Process "https://author.amazon.com.br/"
        Read-Host "Pressione Enter apos configurar (ou pular por enquanto)"
    }
    $acOk = Ask-YesNo "Perfil Author Central criado?"
    Add-Item $sf "Configurar Author Central BR" $acOk | Out-Null

    # ---- Encerramento ----
    $todosItens = $sf.itens | Where-Object { $_.feito }
    if ($todosItens.Count -eq 5) {
        $sf.status = "completa"
        $sf.completa_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-OK "SUB-FASE 2.2 COMPLETA (5/5 itens)"
    } else {
        Write-Warn "SUB-FASE 2.2 parcial ($($todosItens.Count)/5 itens)"
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# SUB-FASE 2.3 - BREVO
# ============================================================================
function Executar-Brevo($progresso) {
    Write-Titulo "SUB-FASE 2.3 - Email Marketing (Brevo)"

    $sf = $progresso.subfases."2.3_brevo"
    if ($sf.status -eq "pendente") {
        $sf.iniciada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $sf.status = "em_andamento"
    }

    Write-Info "Objetivo: capturar leads e engajar audiencia ate lancamento"
    Write-Info "Brevo (ex-Sendinblue) - free tier: 300 envios/dia"
    Write-Info "Alternativas: Mailchimp, ConvertKit, MailerLite"

    # ---- Item 1: Criar conta ----
    Write-Etapa "1" "Criar conta Brevo"
    if (Ask-YesNo "Abrir brevo.com/pt/registro?") {
        Start-Process "https://onboarding.brevo.com/account/register"
        Read-Host "Pressione Enter apos criar a conta"
    }
    $criouConta = Ask-YesNo "Conta Brevo criada?"
    if ($criouConta) {
        $emailBrevo = Ask-Text "Email da conta Brevo" ""
        Add-Item $sf "Criar conta Brevo" $true "email: $emailBrevo" | Out-Null
    } else {
        Add-Item $sf "Criar conta Brevo" $false | Out-Null
    }

    # ---- Item 2: DKIM/SPF/DMARC ----
    Write-Etapa "2" "Configurar dominio de envio (DKIM, SPF, DMARC)"
    Write-Item "CRITICO: sem isso, emails caem na caixa de spam"
    Write-Item "Requer: acesso ao painel DNS do dominio doeusinagem.com.br"
    Write-Item "Ou usar subdominio: mail.doeusinagem.com.br"
    Write-Item ""
    Write-Item "Registros a adicionar (Brevo fornece na configuracao):"
    Write-Item "  1. TXT: v=spf1 include:spf.brevo.com ~all"
    Write-Item "  2. CNAME: mail._domainkey.SEUDOMINIO -> mail.domainkey.uXXX.brevo.com"
    Write-Item "  3. TXT DMARC: v=DMARC1; p=none; rua=mailto:seuemail@dominio.com"
    Write-Item ""
    Write-Warn "AGUARDAR: dominio doeusinagem.com.br ainda nao foi registrado"
    Write-Warn "Adiar este item ate ter dominio proprio"

    $usarDominio = Ask-YesNo "Ja tem dominio proprio configurado?"
    if ($usarDominio) {
        $dominio = Ask-Text "Dominio de envio" "doeusinagem.com.br"

        # Validar DNS
        Write-Info "Verificando registros DNS..."
        try {
            $spf = Resolve-DnsName -Name $dominio -Type TXT -ErrorAction Stop |
                   Where-Object { $_.Strings -match "spf1" }
            if ($spf) { Write-OK "SPF encontrado: $($spf.Strings)" }
            else { Write-Warn "SPF nao encontrado" }
        } catch {
            Write-Warn "Nao foi possivel validar DNS: $($_.Exception.Message)"
        }

        $dnsOk = Ask-YesNo "Registros DNS (SPF, DKIM, DMARC) configurados?"
        Add-Item $sf "Configurar dominio de envio (DKIM/SPF/DMARC)" $dnsOk "dominio: $dominio" | Out-Null
    } else {
        Add-Item $sf "Configurar dominio de envio (DKIM/SPF/DMARC)" $false "aguardando dominio proprio" | Out-Null
        Write-Info "Item marcado como pendente - retomar quando tiver dominio"
    }

    # ---- Item 3: Lista de pre-lancamento ----
    Write-Etapa "3" "Criar lista 'Pre-lancamento Livro DOE'"
    Write-Item "No Brevo: Contatos > Listas > Criar Lista"
    Write-Item "Nome sugerido: 'Livro DOE Pre-lancamento'"
    Write-Item "Origem: formulario Brevo embed na landing em-breve.html"
    if (Ask-YesNo "Abrir Brevo -> Contatos -> Listas?") {
        Start-Process "https://app.brevo.com/contact/list"
        Read-Host "Pressione Enter apos criar a lista"
    }
    $listaOk = Ask-YesNo "Lista criada?"
    Add-Item $sf "Criar lista 'Pre-lancamento Livro DOE'" $listaOk | Out-Null

    # ---- Item 4: Sequencia automatica ----
    Write-Etapa "4" "Desenhar sequencia automatica de 5-7 emails"
    Write-Item "Sugestao de sequencia:"
    Write-Item "  Email 1 (D+0):  Boas-vindas + primeiro conteudo (ex: Cap 1 preview)"
    Write-Item "  Email 2 (D+3):  Contexto - por que DOE em usinagem"
    Write-Item "  Email 3 (D+7):  Case tecnico - dados reais de tese"
    Write-Item "  Email 4 (D+14): Bastidores da escrita do livro"
    Write-Item "  Email 5 (D+21): Preview de outro capitulo (Cap 4?)"
    Write-Item "  Email 6 (D+30): Anuncio: pre-venda com 40% off (quando tiver)"
    Write-Item "  Email 7 (D+45): Ultima chamada pre-venda (se aplicavel)"
    Write-Item ""
    Write-Item "Configurar em: Automacoes > Criar Automacao"
    Write-Item "Trigger: 'Contato adicionado a lista Pre-lancamento'"
    $seqOk = Ask-YesNo "Sequencia desenhada (mesmo que ainda nao configurada)?"
    Add-Item $sf "Desenhar sequencia automatica 5-7 emails" $seqOk | Out-Null

    # ---- Item 5: Dupla opt-in (LGPD) ----
    Write-Etapa "5" "Dupla opt-in (LGPD compliance)"
    Write-Item "OBRIGATORIO no Brasil (LGPD Art. 8, 9)"
    Write-Item "Usuario cadastra > recebe email > confirma > entra na lista"
    Write-Item "Configurar em: Contatos > Formularios > seu formulario > Confirmacao"
    Write-Item "Tambem: guardar log de consentimento com data/hora/IP"
    $optinOk = Ask-YesNo "Dupla opt-in ativa?"
    Add-Item $sf "Configurar dupla opt-in (LGPD)" $optinOk | Out-Null

    # ---- Encerramento ----
    $todosItens = $sf.itens | Where-Object { $_.feito }
    if ($todosItens.Count -eq 5) {
        $sf.status = "completa"
        $sf.completa_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-OK "SUB-FASE 2.3 COMPLETA (5/5 itens)"
    } else {
        Write-Warn "SUB-FASE 2.3 parcial ($($todosItens.Count)/5 itens)"
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# SUB-FASE 2.4 - REGISTROS LEGAIS E FISCAIS
# ============================================================================
function Executar-Legais($progresso) {
    Write-Titulo "SUB-FASE 2.4 - Registros Legais e Fiscais"

    $sf = $progresso.subfases."2.4_legais"
    if ($sf.status -eq "pendente") {
        $sf.iniciada_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $sf.status = "em_andamento"
    }

    Write-Info "Objetivo: formalizar aspectos legais e fiscais da publicacao"

    # ---- Item 1: Avaliar ME ----
    Write-Etapa "1" "Avaliar momento de abrir ME (Simples Nacional)"
    Write-Item "Como pessoa fisica: pagar IR sobre royalties na declaracao anual"
    Write-Item "Como ME: DAS mensal ~6% (Anexo III - servicos), NF-e por venda"
    Write-Item ""
    Write-Warn "ATENCAO: professor federal (IFES) pode ter restricoes estatutarias"
    Write-Warn "Verificar com RH IFES antes de decidir por CNPJ"
    Write-Item ""
    Write-Item "Perguntas para decisao:"
    Write-Item "  a) Estimativa de receita anual do livro?"
    Write-Item "  b) Tera outras fontes de renda como PJ (consultoria)?"
    Write-Item "  c) Precisa emitir NF para clientes B2B?"

    $receita = Ask-Text 'Receita anual estimada (R$)' "20000"
    $outrasRendas = Ask-YesNo "Tera outras fontes PJ (consultoria, palestras)?"

    Write-Host ""
    Write-Info "Analise:"
    if ([int]$receita -lt 15000 -and -not $outrasRendas) {
        Write-Item "Receita baixa + sem outras rendas PJ -> pode comecar como PF"
        Write-Item 'Reavaliar ME quando ultrapassar ~R$28.560/ano (limite MEI)'
    } elseif ([int]$receita -gt 28560) {
        Write-Item 'Receita > limite MEI (R$28.560) -> abrir ME direto (Simples Nacional)'
    } elseif ($outrasRendas) {
        Write-Item "Outras rendas PJ + livro -> ME faz sentido (regularizar tudo)"
    }

    $meDecidido = Ask-Text "Sua decisao (PF, MEI, ME, adiar)" "adiar"
    Add-Item $sf "Avaliar momento de abrir ME" $true "decisao: $meDecidido" | Out-Null

    # ---- Item 2: Contador ----
    Write-Etapa "2" "Pesquisar contador"
    Write-Item "Opcoes:"
    Write-Item '  a) Contabilizei (online, ~R$99/mes MEI, ~R$149/mes ME)'
    Write-Item "  b) Agilize / Contabilizando (similares)"
    Write-Item "  c) Contador local em Vila Velha (relacionamento pessoal)"
    Write-Item ""
    Write-Item "Recomendacao: Contabilizei tem processo digital rapido"
    Write-Item "Alternativa forte: contador especializado em autoautores/professores"

    if (Ask-YesNo "Abrir Contabilizei para simular?") {
        Start-Process "https://www.contabilizei.com.br/"
        Read-Host "Pressione Enter apos revisar (ou pular)"
    }
    $contador = Ask-Text "Contador escolhido (ou 'adiar')" "adiar"
    Add-Item $sf "Pesquisar contador" ($contador -ne "adiar") "escolha: $contador" | Out-Null

    # ---- Item 3: Registro Autoral (Biblioteca Nacional OU CBL OU Cartorio) ----
    Write-Etapa "3" "Registro autoral (protecao intelectual)"
    Write-Item "Sua obra ja e protegida desde a criacao - registro e prova documental"
    Write-Item ""
    Write-Item "3 alternativas com custos e beneficios diferentes:"
    Write-Item ""
    Write-Item 'a) Biblioteca Nacional (BN) - ~R$40-60 por obra'
    Write-Item "   URL: www.bn.gov.br > Direitos Autorais > Registro"
    Write-Item "   Prazo: 60-90 dias"
    Write-Item ""
    Write-Item 'b) CBL - Registro Autoral (alternativa mais rapida)'
    Write-Item "   URL: $($Script:CBL.RegistroAutoral)"
    Write-Item "   Prazo: 5-10 dias uteis"
    Write-Item ""
    Write-Item 'c) Cartorio de Titulos e Documentos (data certa) - ~R$30-50'
    Write-Item "   Presencial no cartorio local (Vila Velha)"
    Write-Item "   Prazo: 1-2 dias"
    Write-Item "   Mesma forca juridica em disputas"
    Write-Item ""
    Write-Warn "TODAS as opcoes requerem manuscrito pronto"
    Write-Warn "Recomendacao: aguardar termino do livro para registrar"

    $tipoReg = Ask-Text "Tipo escolhido (BN, CBL, cartorio, adiar)" "adiar"
    Add-Item $sf "Definir registro autoral" $true "tipo: $tipoReg (aguardar manuscrito)" | Out-Null

    # ---- Item 4: ISBN ----
    Write-Etapa "4" "Solicitar ISBN (CBL Servicos)"
    Write-Item "ISBN e obrigatorio para venda comercial no Brasil"
    Write-Warn 'ISBN NAO e gratuito - custa R$28,60 por unidade (CBL)'
    Write-Item ""
    Write-Item "Como o livro tera 3 formatos, precisara de 3 ISBNs:"
    Write-Item '  ISBN PDF        R$28,60'
    Write-Item '  ISBN EPUB       R$28,60'
    Write-Item '  ISBN Impresso   R$28,60  (ou gratuito via Amazon KDP*)'
    Write-Item '  -----------------------'
    Write-Item '  TOTAL           R$85,80  (ou R$57,20 usando Amazon para impresso)'
    Write-Item ""
    Write-Item "* ISBN Amazon KDP so serve para venda via Amazon"
    Write-Item ""
    Write-Item "Servicos adicionais opcionais (CBL):"
    Write-Item '  Ficha Catalografica   R$65,80  (obrigatoria para impresso)'
    Write-Item '  Codigo de Barras EAN  R$41,20  (obrigatorio para impresso fisico)'
    Write-Item '  ISNI (autor)          R$28,60  (opcional - Mario ja tem ORCID)'
    Write-Item ""
    Write-Item "Fluxo no site CBL (menu Minha Conta):"
    Write-Item "  1. Perfil Pessoal      -> preencher CPF, endereco"
    Write-Item "  2. Perfil de Empresa   -> preencher como autoautor (CPF, sem CNPJ)"
    Write-Item "  3. + Solicitar ISBN    -> cadastro do livro + escolha do formato"
    Write-Item "  4. Repetir para os 3 formatos (PDF, EPUB, Impresso)"

    if (Ask-YesNo "Abrir CBL Servicos (pagina de solicitacao)?") {
        Start-Process $Script:CBL.SolicitarISBN
        Read-Host "Pressione Enter apos revisar"
    }
    if (Ask-YesNo "Abrir tambem Perfil Pessoal (obrigatorio antes de solicitar)?") {
        Start-Process $Script:CBL.PerfilPessoa
    }

    Write-Item ""
    Write-Item "Estrategia recomendada dado o custo:"
    Write-Item "  a) Adiar: comprar so na hora de publicar (evita risco)"
    Write-Item "  b) Amazon: economizar R$28,60 usando ISBN gratuito Amazon KDP (impresso)"
    Write-Item "  c) Comprar tudo: garantir todos os ISBNs proprios agora"

    $isbnDecisao = Ask-Text "Decisao ISBN (adiar, amazon, tudo)" "adiar"
    $isbnFeito = ($isbnDecisao -ne "adiar")
    Add-Item $sf "Definir estrategia ISBN" $isbnFeito "decisao: $isbnDecisao" | Out-Null

    # ---- Item 5: Licenca ----
    Write-Etapa "5" "Definir licenca de distribuicao"
    Write-Item "Estrategia recomendada:"
    Write-Item "  - Versao PAGA (PDF/EPUB/impresso): (C) todos os direitos reservados"
    Write-Item "  - Versao HTML gratuita: Creative Commons BY-NC-ND"
    Write-Item ""
    Write-Item "CC BY-NC-ND = Atribuicao + Nao-Comercial + Sem Derivadas"
    Write-Item "Permite: ler, compartilhar link, citar academicamente"
    Write-Item "Proibe: copiar conteudo, uso comercial, criar versoes modificadas"
    Write-Item ""
    Write-Item "Referencia: creativecommons.org/licenses/by-nc-nd/4.0/deed.pt-br"

    if (Ask-YesNo "Abrir CC para conferir?") {
        Start-Process "https://creativecommons.org/licenses/by-nc-nd/4.0/deed.pt-br"
        Read-Host "Pressione Enter apos revisar"
    }
    $licencaOk = Ask-YesNo "Estrategia de licenca definida?"
    Add-Item $sf "Definir licenca (paga + HTML CC BY-NC-ND)" $licencaOk | Out-Null

    # ---- Encerramento ----
    $todosItens = $sf.itens | Where-Object { $_.feito }
    if ($todosItens.Count -eq 5) {
        $sf.status = "completa"
        $sf.completa_em = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-OK "SUB-FASE 2.4 COMPLETA (5/5 itens)"
    } else {
        Write-Warn "SUB-FASE 2.4 parcial ($($todosItens.Count)/5 itens)"
    }

    Save-Progresso $progresso
    Update-Documentacao $progresso
}

# ============================================================================
# MOSTRAR STATUS
# ============================================================================
function Mostrar-Status($progresso) {
    Write-Titulo "STATUS FASE 2 - Setup Comercial Antecipado"
    Write-Info "Iniciada em: $($progresso.iniciada_em)"
    Write-Info "Atualizada:  $($progresso.atualizada_em)"
    Write-Host ""

    foreach ($key in $progresso.subfases.PSObject.Properties.Name) {
        $sf = $progresso.subfases.$key
        $feitos = ($sf.itens | Where-Object { $_.feito }).Count
        $total = $sf.itens.Count

        $indicador = switch ($sf.status) {
            "completa"     { "[OK] " }
            "em_andamento" { "[..] " }
            default        { "[  ] " }
        }

        $cor = switch ($sf.status) {
            "completa"     { "Green" }
            "em_andamento" { "Cyan" }
            default        { "Gray" }
        }

        $linha = "  {0} {1,-45} ({2}/{3})" -f $indicador, $sf.titulo, $feitos, $total
        Write-Host $linha -ForegroundColor $cor
    }

    Write-Host ""
    Write-Info "Progresso salvo em: $Script:ArquivoProgresso"
    Write-Info "Documentacao em:    $Script:ArquivoDoc"
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================
function Show-Menu {
    Write-Titulo "FASE 2 - Setup Comercial Antecipado"
    Write-Host ""
    Write-Host "  1) Sub-fase 2.1 - Plataforma de venda digital (Kiwify)"
    Write-Host "  2) Sub-fase 2.2 - Plataforma de venda impressa (Amazon KDP)"
    Write-Host "  3) Sub-fase 2.3 - Email marketing (Brevo)"
    Write-Host "  4) Sub-fase 2.4 - Registros legais e fiscais"
    Write-Host ""
    Write-Host "  5) Ver status geral"
    Write-Host "  6) Abrir documentacao gerada"
    Write-Host "  0) Sair"
    Write-Host ""
    return Read-Host "Escolha uma opcao"
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
    if (Ask-YesNo "ATENCAO: isto vai apagar todo progresso da Fase 2. Confirmar?") {
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

# Se especificou sub-fase, executar direto
if ($Subfase) {
    switch ($Subfase) {
        "2.1" { Executar-Kiwify  $progresso }
        "2.2" { Executar-KDP     $progresso }
        "2.3" { Executar-Brevo   $progresso }
        "2.4" { Executar-Legais  $progresso }
    }
    Mostrar-Status $progresso
    exit 0
}

# Menu interativo
$continuar = $true
while ($continuar) {
    $opcao = Show-Menu
    switch ($opcao) {
        "1" { Executar-Kiwify  $progresso }
        "2" { Executar-KDP     $progresso }
        "3" { Executar-Brevo   $progresso }
        "4" { Executar-Legais  $progresso }
        "5" { Mostrar-Status   $progresso }
        "6" {
            if (Test-Path $Script:ArquivoDoc) {
                Start-Process $Script:ArquivoDoc
            } else {
                Write-Warn "Documentacao ainda nao gerada. Execute uma sub-fase primeiro."
            }
        }
        "0" { $continuar = $false }
        default { Write-Warn "Opcao invalida" }
    }
}

Write-Host ""
Write-OK "Encerrando. Progresso salvo em $Script:ArquivoProgresso"
Write-Info "Retomar com: .\executar-fase-2.ps1"
