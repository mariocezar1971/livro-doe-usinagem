# Zotero + Better BibTeX — Guia Passo a Passo

Guia completo para gestão de referências bibliográficas do livro, com **Zotero como gerenciador principal** e integração automática com o Quarto via **Better BibTeX**.

---

## Por que Zotero + Better BibTeX?

| Recurso | Zotero puro | Zotero + Better BibTeX |
|---|---|---|
| Coleta de refs via navegador | ✅ | ✅ |
| Sync entre dispositivos | ✅ | ✅ |
| Exporta para BibTeX | ✅ (manual) | ✅ (automático) |
| Citekeys estáveis | ❌ | ✅ (baseado em regra) |
| Auto-export ao editar | ❌ | ✅ |
| Cite-while-you-write no Quarto | Limitado | ✅ (via keys) |

**Conclusão:** Zotero puro serve. Zotero + Better BibTeX **muda o jogo** para escrever no Quarto porque o `references.bib` do projeto fica sempre atualizado sozinho.

---

## Passo 1 — Instalar Zotero (5 min)

### Download

Acesse [zotero.org/download](https://www.zotero.org/download/) e baixe:

1. **Zotero desktop** (Windows, ~90 MB)
2. **Zotero Connector** para seu navegador (Chrome, Firefox, Edge)

### Instalação

1. Execute o instalador do desktop — opções padrão
2. No primeiro início, **crie conta gratuita** em zotero.org
   - Serve para sync entre computadores (casa/trabalho/laptop)
   - Free tier: 300 MB (suficiente para milhares de refs bibliográficas + PDFs anexados)
3. **Faça login no desktop:** Edit → Preferences → Sync → Login

### Configurações recomendadas

Edit → Preferences:

- **General** → *Automatically retrieve metadata for PDFs*: ON
- **Sync** → *Sync automatically*: ON
- **Sync** → *Download PDFs*: On demand (economiza espaço)
- **Advanced → Files and Folders** → *Base directory* (opcional): defina uma pasta local para os PDFs

---

## Passo 2 — Instalar Better BibTeX (2 min)

### Download

Acesse [retorque.re/zotero-better-bibtex/installation](https://retorque.re/zotero-better-bibtex/installation/) e baixe o arquivo `.xpi` da última versão.

### Instalação

1. No Zotero desktop: **Tools → Add-ons**
2. Clique no ícone de engrenagem ⚙️ (canto superior direito)
3. **Install Add-on From File...**
4. Selecione o `.xpi` baixado
5. **Restart Zotero** quando solicitado

### Configuração inicial

Após reiniciar, aparecerá um assistente de configuração. Recomendações para o livro:

**Citation key formula:**

```
auth.lower + year + shorttitle(1,1).lower
```

Isso gera keys como `montgomery2017design`, `machado2011teoria`, `santosjr2012emprego` — legíveis e estáveis.

**Import BibTeX:**
- On import, apply casing to non-cased words: OFF (preserva capitalização original)

**Automatic export:**
- Ativar quando exportar (veremos no Passo 5)

---

## Passo 3 — Importar `references.bib` gerado da tese (3 min)

Você já tem o `references.bib` inicial (189 entradas extraídas da sua tese pelo script Python).

### Importação

1. No Zotero: **File → Import...**
2. Selecione **A file (BibTeX, RIS, Zotero RDF, etc.)**
3. Navegue até a pasta do projeto e selecione `references.bib`
4. **Place imported collection into new collection**: ✅ marcar
5. Nome da coleção: `Livro DOE Usinagem`
6. **Import**

Após a importação, na barra lateral esquerda aparecerá:

```
📁 My Library
  📁 Livro DOE Usinagem  ← sua nova coleção
     - 189 itens importados
```

---

## Passo 4 — Revisar entradas problemáticas (30-60 min)

O script Python marcou entradas com `% TODO REVISAR` (~14 de 189).

### Como identificar

No Zotero, na coleção `Livro DOE Usinagem`:

1. Clique na coluna **Title** para ordenar alfabeticamente
2. As entradas problemáticas estarão espalhadas — busque por títulos suspeitos:
   - Títulos muito curtos (ex.: apenas uma letra ou sigla)
   - "Author" contendo pedaço do título
   - Ano ausente

### Como corrigir

**Para cada entrada problemática:**

1. Selecione a entrada
2. No painel direito, **Info** aba principal
3. Compare com a referência original (abra o `references.bib` e busque pela citekey)
4. Corrija: autor, título, ano, revista, volume, número, páginas
5. Salvar acontece automaticamente

### Enriquecimento (opcional, mas recomendado)

Zotero pode buscar metadados enriquecidos automaticamente:

1. Selecione uma entrada
2. Botão direito → **Find Available PDF**
3. Se tiver DOI, botão direito → **Look Up by Identifier** (adiciona keywords, abstract, etc.)

Para busca em massa:
- Selecione todas as entradas → botão direito → **Update Item...**

---

## Passo 5 — Auto-export para o Quarto (5 min)

**Este é o passo mais importante.** Configura o Zotero para atualizar automaticamente o `references.bib` do projeto sempre que você adicionar/editar uma referência.

### Configuração

1. Na coleção `Livro DOE Usinagem`, **botão direito → Export Collection...**
2. **Format**: **Better BibTeX**
3. **Keep updated**: ✅ marcar (crítico!)
4. **Include**: ✅ Notes, ✅ Files (opcional)
5. **OK**
6. Na janela de salvar, navegue até a raiz do projeto:
   ```
   C:\Users\mceza\Dropbox\PROGRAMACAO\R_STUDIO\APLICATIVOS\LIVRO_DOE_USINAGEM\
   ```
7. Nome do arquivo: **references.bib** (sobrescreve o gerado inicialmente)
8. **Salvar**

### O que acontece agora

- Sempre que você **adicionar** uma nova referência ao Zotero (via clipboard, navegador, drag-drop de PDF)
- Sempre que você **editar** uma existente
- O arquivo `references.bib` do projeto é **regravado automaticamente**
- Seu Quarto renderiza usando a versão atualizada sem esforço manual

### Validar

1. Faça uma pequena mudança em qualquer entrada (ex.: adicione um "." ao final do título)
2. Salve (auto-salva)
3. Abra `references.bib` no VS Code / RStudio — a mudança já está lá

---

## Passo 6 — Adicionar referências novas (fluxo diário)

### Método 1: Via navegador (mais rápido)

1. Você acha um artigo interessante em `sciencedirect.com`, `springer.com`, `scholar.google.com`, etc.
2. Clique no ícone do **Zotero Connector** na barra do navegador
3. Escolha a coleção `Livro DOE Usinagem`
4. Pronto — ref e PDF baixados automaticamente

### Método 2: Via DOI

1. No Zotero desktop, clique no ícone da varinha mágica 🪄
2. Cole o DOI (ex.: `10.1007/s00170-015-7454-9`)
3. Zotero busca todos os metadados

### Método 3: Manual

1. Zotero → botão **Novo Item** (ícone verde +)
2. Escolha o tipo (Journal Article, Book, Thesis, etc.)
3. Preencha os campos

**Em todos os casos**, o `references.bib` do projeto é atualizado automaticamente.

---

## Passo 7 — Citar no Quarto (fluxo de escrita)

Ao escrever qualquer capítulo `.qmd`, use a citekey:

```markdown
O planejamento fatorial 2^k é a base da metodologia DOE moderna
[@montgomery2017design]. Trabalhos aplicados ao alumínio incluem
[@santosjr2012emprego] e [@machado2011teoria].

Análises mais recentes [-@wu2020fatorial; @silva2023rsm] mostram...
```

Ao renderizar, o Quarto:
1. Localiza `references.bib`
2. Formata citações usando o CSL configurado (ABNT ou Springer)
3. Gera a lista de referências no fim do capítulo/livro

### Descobrir citekeys rapidamente

**Dica:** No Zotero, botão direito na entrada → **Better BibTeX → Show Citation Key**

Ou copie citações prontas:
- Botão direito → **Better BibTeX → Copy Citation Key** — cola direto no `.qmd`

---

## Passo 8 — Alternar entre CSLs (livro ABNT × artigo Springer)

Você tem **dois CSLs** na raiz do projeto:

- `associacao-brasileira-de-normas-tecnicas.csl` — para o livro (padrão)
- `springer-basic-author-date.csl` — para artigos IJAMT, JMPT, JMP, etc.

### No `_quarto.yml`

```yaml
# Para o livro (padrão)
csl: associacao-brasileira-de-normas-tecnicas.csl

# Para submissão a periódico Springer
csl: springer-basic-author-date.csl
```

### Para projetos separados

Se você mantém um **projeto separado para cada artigo**, cada um pode ter seu próprio CSL. Mas pode reutilizar o mesmo `references.bib` — basta criar um link simbólico ou apontar diretamente.

Exemplo em um projeto de artigo `.qmd`:

```yaml
---
title: "Meu artigo IJAMT"
bibliography: "../LIVRO_DOE_USINAGEM/references.bib"
csl: "../LIVRO_DOE_USINAGEM/springer-basic-author-date.csl"
---
```

---

## Passo 9 — Sync entre casa e trabalho

Zotero sync (gratuito) permite ter as mesmas referências em qualquer máquina:

1. Em **cada** computador onde usar Zotero: **Edit → Preferences → Sync → Login**
2. Sync roda automaticamente
3. PDFs também sincronizam (até 300 MB no plano gratuito)

**Better BibTeX auto-export funciona por máquina** — configure em cada uma apontando para o `references.bib` local (via Dropbox ou via `git pull` do projeto).

---

## Backup e versionamento

### Backup nativo do Zotero

- Zotero → **File → Export Library** — gera arquivo `.rdf` completo
- Automático via sync (contas gratuitas)

### Backup para o Git do livro

Como o `references.bib` está no projeto Git:

```powershell
git add references.bib
git commit -m "Atualiza referencias (importa Zotero)"
git push
```

**Toda mudança nas refs vai para o histórico do Git** — pode reverter mudanças acidentais.

---

## Solução de problemas

### "Citation key não encontrada" ao renderizar

Verifique se:
1. O `references.bib` está atualizado (Zotero exportou)
2. A citekey no `.qmd` está correta (case-sensitive)
3. Quarto encontra o arquivo `.bib` (`bibliography:` no `_quarto.yml`)

### Auto-export parou de funcionar

1. Zotero → Edit → Preferences → Better BibTeX → **Automatic Export**
2. Verificar se a coleção `Livro DOE Usinagem` aparece na lista
3. Se não aparecer, reconfigurar exportação (Passo 5)

### Duplicatas ao importar

Better BibTeX detecta duplicatas por citekey. Se você importa 2× o mesmo `references.bib`:
1. Zotero → **Duplicate Items** (na barra lateral)
2. Selecione todas → **Merge Items**

### Perdi o Zotero — como recuperar tudo?

1. Instale Zotero em qualquer máquina
2. Login com sua conta zotero.org
3. Sync automático baixa tudo de volta
4. Re-configure Better BibTeX auto-export para o projeto local

---

## Checklist final da Fase 0.4

Quando todos estes estiverem marcados, a Fase 0.4 está completa:

- [ ] Zotero desktop instalado e logado
- [ ] Better BibTeX instalado e configurado
- [ ] Zotero Connector no navegador (Chrome/Edge/Firefox)
- [ ] `references.bib` importado no Zotero na coleção "Livro DOE Usinagem"
- [ ] Entradas marcadas "TODO REVISAR" foram revisadas
- [ ] Auto-export Better BibTeX configurado para o `references.bib` do projeto
- [ ] CSL ABNT baixado na raiz do projeto
- [ ] CSL Springer baixado na raiz do projeto
- [ ] Teste: `quarto render` gera lista de referências corretamente
- [ ] Sync do Zotero ativado

Após esse checklist, você tem infraestrutura de referências profissional que:
- Cresce naturalmente à medida que você lê novos artigos
- Atualiza o livro automaticamente
- Permite alternar entre estilos (livro vs artigo) sem retrabalho
- Está versionada no Git e sincronizada na nuvem
