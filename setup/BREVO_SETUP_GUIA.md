# Brevo — Guia de Configuração do Funil de Captura

Guia passo a passo para configurar o Brevo (antigo Sendinblue) como serviço de captura de e-mails da landing page `em-breve.qmd`.

**Por que Brevo?**
- Plano gratuito generoso: **300 emails/dia** (mais que suficiente para captura pré-lançamento)
- Interface em português
- Formulários customizáveis com embed HTML
- Automações (email de boas-vindas, sequência de nurturing)
- Conformidade LGPD nativa

---

## Passo 1 — Criar conta (5 min)

1. Acesse: [brevo.com](https://www.brevo.com/pt/)
2. Clique em **"Criar conta gratuita"**
3. Preencha: nome, email profissional (recomendo `mcezarjr@ifes.edu.br`), senha
4. **Confirme o email** que chegou na sua caixa
5. Ao entrar, complete o **perfil da empresa**:
   - Empresa/Organização: "Prof. Mário Cezar / IFES"
   - Setor: "Educação"
   - Website: `https://mariocezar1971.github.io/livro-doe-usinagem/`

---

## Passo 2 — Criar a lista de contatos (2 min)

1. Menu lateral esquerdo: **Contatos** → **Listas**
2. Clique em **"+ Criar uma nova lista"**
3. Nome: `Lançamento Livro DOE Usinagem`
4. Descrição: `Inscritos na landing page em-breve para lançamento do livro`
5. Salvar

**Anote o ID da lista** (aparece na URL: `/contact/list/ID`). Vai precisar depois.

---

## Passo 3 — Criar campos personalizados (opcional, 3 min)

Para segmentar melhor os inscritos, crie campos além de email/nome:

1. **Contatos** → **Atributos**
2. Crie estes atributos personalizados:
   - `INSTITUICAO` (texto) — universidade/empresa
   - `FUNCAO` (texto) — professor, engenheiro, estudante, outro
   - `INTERESSE_PRINCIPAL` (múltipla escolha) — DOE, Usinagem, Metrologia, Estatística

---

## Passo 4 — Criar o formulário embed (10 min)

1. Menu lateral: **Contatos** → **Formulários**
2. Clique em **"+ Novo formulário"**
3. Escolha o modelo **"Formulário simples"** (não popup, não sidebar)
4. Configure:

### Aba "Design"
- **Nome interno:** `Landing em-breve Livro DOE`
- **Campos:**
  - E-mail (obrigatório)
  - Nome (opcional)
  - Instituição (opcional)
  - Função (opcional, dropdown com: Professor, Pesquisador, Engenheiro, Estudante, Outro)

### Aba "Design visual"
- **Cor principal:** `#1a237e` (azul-marinho, combina com a landing)
- **Botão CTA:** texto = `Quero o capítulo grátis`
- **Alinhamento:** centro

### Aba "Confirmação"
- **Ação após submit:** Exibir mensagem de agradecimento
- **Mensagem:**
  ```
  🎉 Inscrição confirmada! Verifique seu email para confirmar (double opt-in).

  Você receberá o Capítulo 4 gratuito assim que o livro for lançado.
  ```

### Aba "Lista de destino"
- Selecionar: `Lançamento Livro DOE Usinagem`

### Aba "Configurações avançadas"
- **Double opt-in:** ✅ ATIVAR (conformidade LGPD)
  - Email de confirmação: personalize com "Confirme sua inscrição na lista do Prof. Mário"
- **Redirect URL após confirmação:** `https://mariocezar1971.github.io/livro-doe-usinagem/`

5. **Salvar formulário**

---

## Passo 5 — Copiar o código embed (2 min)

1. Após salvar, clique em **"Compartilhar" → "Incorporar"**
2. Escolha **"HTML (código HTML)"** — NÃO iframe
3. Copie **todo o código** (começa com `<script>` e termina com `</script>` ou `<link>` + `<div>`)

O código será parecido com:

```html
<!-- START - We recommend to place the below code where you want the form in your website html  -->
<div class="sib-form" ...>
  <div id="sib-form-container" class="sib-form-container">
    ...
  </div>
</div>
<!-- END - We recommend to place the below code where you want the form in your website html  -->

<!-- START - We recommend to place the below code in footer or bottom of your website html  -->
<script>
  window.REQUIRED_CODE_ERROR_MESSAGE = 'Please choose an option';
  ...
</script>
<script src="https://sibforms.com/forms/end-form/build/main.js"></script>
<!-- END - We recommend to place the below code in footer or bottom of your website html  -->
```

---

## Passo 6 — Inserir no `em-breve.qmd`

1. Abrir `em-breve.qmd` no editor (VS Code, RStudio, ou o script vai perguntar)
2. Localizar o bloco:

```markdown
<!-- INICIO FORMULARIO BREVO -->
::: {.brevo-form}
<!-- COLE AQUI O CÓDIGO DO FORMULÁRIO BREVO -->

<div style="padding: 2rem; background: #fff3cd; ...">
<strong>⚠️ Formulário ainda não configurado</strong>
...
</div>

:::
<!-- FIM FORMULARIO BREVO -->
```

3. Substituir **tudo entre `::: {.brevo-form}` e `:::`** pelo código copiado do Brevo:

```markdown
<!-- INICIO FORMULARIO BREVO -->
::: {.brevo-form}
<div class="sib-form" style="...">
  <div id="sib-form-container">
    ... (código completo do Brevo) ...
  </div>
</div>
<script>
  ... (JavaScript do Brevo) ...
</script>
<script src="https://sibforms.com/forms/end-form/build/main.js"></script>
:::
<!-- FIM FORMULARIO BREVO -->
```

4. Salvar

---

## Passo 7 — Configurar email de boas-vindas (5 min)

Quando alguém confirmar a inscrição, envie um email profissional automaticamente:

1. Brevo → **Automações** → **+ Nova automação**
2. Modelo: **"Enviar mensagem de boas-vindas"**
3. Gatilho: **"Contato foi adicionado à lista"** → `Lançamento Livro DOE Usinagem`
4. Ação: **Enviar email**

### Template do email de boas-vindas

**Assunto:** `Bem-vindo(a)! Seu capítulo grátis está a caminho 📚`

**Corpo:**

```
Olá {{contact.FIRSTNAME|"leitor(a)"}},

Bem-vindo(a) à lista de pré-lançamento do livro
"Planejamento de Experimentos em Usinagem"!

Nos próximos meses você vai receber:

📚 Atualizações mensais sobre o progresso do livro
📊 Trechos exclusivos de capítulos em desenvolvimento
🎁 Capítulo 4 completo GRÁTIS quando o livro for lançado
💰 40% de desconto na pré-venda (versão PDF por R$ 49)

Enquanto isso, você pode acompanhar o desenvolvimento
em tempo real no site:

https://mariocezar1971.github.io/livro-doe-usinagem/

E se quiser espiar os capítulos que já estão sendo escritos:

https://github.com/mariocezar1971/livro-doe-usinagem

Se tiver qualquer dúvida ou sugestão, é só responder este email.

Um abraço,

Prof. Dr. Mário Cezar dos Santos Junior
IFES - Instituto Federal do Espírito Santo
Campus Vila Velha, ES
```

5. Salvar automação

---

## Passo 8 — Testar o funil

Antes de anunciar publicamente, teste com seu próprio email:

1. Abra o site em modo anônimo/incógnito: `https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html`
2. Preencha o formulário com um email seu diferente do usado na conta Brevo
3. **Cheque:**
   - Mensagem de confirmação aparece
   - Email de "confirme sua inscrição" chega (double opt-in)
   - Ao clicar no link, redireciona corretamente
   - Email de boas-vindas chega em seguida
   - Você aparece na lista `Lançamento Livro DOE Usinagem`

Se algum passo falhar, revise a configuração no Brevo.

---

## Passo 9 — Divulgar

Assim que o teste passar, divulgar a landing:

### Canais recomendados

1. **LinkedIn** (post pessoal e no grupo Engenharia de Manufatura)
2. **Grupos do WhatsApp/Telegram** de professores e alunos de Eng Mecânica/Produção
3. **Twitter/X** (com hashtags #DOE, #Usinagem, #Manufatura, #Alumínio)
4. **Assinatura de email institucional** (link para em-breve.html)
5. **Rodapé de artigos científicos** que ainda vai publicar em 2027

### Template de post LinkedIn

```
📚 Estou escrevendo o primeiro livro brasileiro sobre
Planejamento de Experimentos (DOE) aplicado à usinagem
de ligas de alumínio.

Cobrindo:
✓ Fatorial 2^k
✓ Planejamento composto central (PCC)
✓ Superfícies de resposta (RSM)
✓ Otimização multiresposta

Baseado em mais de 10 anos de pesquisa na UFU e IFES,
com casos reais de torneamento de Al 6061, 6351, 7075.

Previsão de lançamento: 1º semestre de 2027.

Se você atua com pesquisa aplicada em manufatura,
metalurgia ou usinagem, se cadastre para receber
o Capítulo 4 completo GRÁTIS quando o livro sair:

🔗 https://mariocezar1971.github.io/livro-doe-usinagem/em-breve.html

#DOE #Usinagem #Manufatura #Alumínio #Estatística #Engenharia
```

---

## Monitoramento

Semanalmente, no Brevo:

- **Estatísticas** → **Contatos** → veja crescimento da lista
- **Formulários** → performance de cada formulário (taxa de conversão)
- **Automações** → taxa de abertura do email de boas-vindas

**Metas realistas:**

| Marco | Meta |
|-------|------|
| 1º mês | 30-50 inscritos |
| 3º mês | 100-150 inscritos |
| 6º mês | 250-400 inscritos |
| Lançamento (~14-18 meses) | 800-1200 inscritos |

Taxa de conversão pré-venda esperada: 5-8% dos inscritos.

---

## Alternativas ao Brevo (opcional)

Se preferir outro serviço, alternativas gratuitas ou baratas:

| Serviço | Free tier | Notas |
|---------|-----------|-------|
| **Brevo** | 300 emails/dia | ✅ RECOMENDADO — melhor equilíbrio |
| **MailerLite** | 12.000 emails/mês, 1000 subs | Boa alternativa |
| **Buttondown** | 100 subs | Focado em newsletters |
| **ConvertKit** | 1000 subs | Mais caro depois, focado em criadores |
| **Substack** | Ilimitado, mas 10% receita | Ótimo se virar newsletter paga |

---

## Solução de problemas

### Formulário não aparece na landing após deploy

- Verifique se o código embed foi colado inteiro no `em-breve.qmd`
- Rode `quarto render em-breve.qmd` localmente e abra o HTML gerado
- Se aparecer local mas não no GitHub Pages, aguarde 3-5 min de propagação

### Emails de confirmação não chegam

- Verifique se **double opt-in** está ativo no Brevo (Passo 4)
- Cheque pasta de SPAM
- Verifique o **remetente** configurado — se for `noreply@brevo.com` genérico, muitos servidores marcam como spam. Configure remetente autenticado (Brevo → Configurações → Remetentes)

### Baixa taxa de conversão

- Refine o copy da landing (Passo 6 do guia)
- Adicione depoimento/prova social (quando tiver primeiros inscritos)
- A/B test do botão CTA ("Quero o capítulo" vs "Receber grátis" vs "Cadastrar")

### LGPD

- Brevo trata isso automaticamente com o double opt-in
- Mantenha a política de privacidade acessível: crie página `politica-privacidade.qmd` no projeto
- Cancelamento com 1 clique já vem por padrão nos emails do Brevo
