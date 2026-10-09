# Relatório de Conferência de Dados — Livro × Tese

> **Gerado automaticamente:** comparação dos valores numéricos [DADO] usados
> nos capítulos do livro contra o texto da tese original.
> **Método:** cada valor-chave do livro foi buscado no PDF-texto da tese.
> **Objetivo:** pegar erros de transcrição (o risco que o checklist aponta).

## Resultado geral: 25/25 valores confirmados ✓

Todos os valores numéricos críticos usados nos capítulos de resultados
(Caps 8 e 10), no projeto experimental (Cap 7) e na instrumentação
(Apêndice A) foram **localizados na tese** e conferem.

---

## Detalhamento por capítulo

### Cap 8 — Análise fatorial (efeitos e R²)

| Valor no livro | Na tese | Status |
|---|---|---|
| Efeito ap na força: +714 N | 714 (Tab. efeitos) | ✓ confere |
| Efeito Vc na força: −107 N | 107 | ✓ confere |
| Efeito Liga na força: −52 N | 51,89 (arredondado p/ 52) | ✓ confere |
| Efeito Liga na temperatura: +260 | 260 | ✓ confere |
| Média da força: 585 N | **584,88** (L3452) → 585 | ✓ confere (arredondado) |
| R² força: 0,99 | 0,99 | ✓ confere |
| R² vibração: 0,74 (ajustado) | 0,74 / 0,81 | ✓ confere |

### Cap 10 — Modelos globais e otimização (ponto ótimo e validação)

| Valor no livro | Na tese | Status |
|---|---|---|
| Ótimo Vc: 126 m/min | 126 | ✓ confere |
| Ótimo ap: 2,43 mm | 2,43 | ✓ confere |
| Ótimo f: 0,19 mm/volta | 0,19 | ✓ confere |
| Ótimo R: 323 MPa | 323 | ✓ confere |
| Ótimo Ar: 44% | 44 | ✓ confere |
| Ótimo Hd: 34,5 HV | 34,5 | ✓ confere |
| Fu ótimo: ~723 N | 723 | ✓ confere |
| Ne ótimo: ~1395 W | 1395 | ✓ confere |
| Tc ótimo: ~344 °C | 344 | ✓ confere |
| Ra ótimo: ~2,47 µm | 2,47 | ✓ confere |
| Validação 6351-T6 R: 336 MPa | 336 | ✓ confere |
| Validação 6351-T6 Ar: 17% | 17 | ✓ confere |
| Validação 6351-T6 Hd: 119 HV | 119 | ✓ confere |

### Cap 7 / Apêndice A — Projeto e instrumentação

| Valor no livro | Na tese | Status |
|---|---|---|
| Torno ROMI: 11 kW | 11 kW | ✓ confere |
| Pastilha: HTi10 | HTi10 | ✓ confere |
| Ferramenta temperatura: K15 | K15 | ✓ confere |
| MQF Accu-Lube: 100 ml/h | 100 | ✓ confere |
| Jorro Vasco 1000: 360 L/h | 360 | ✓ confere |

---

## O que esta conferência NÃO cobre

Esta verificação automática confirma que os **números aparecem na tese** —
o que pega erros de transcrição grosseiros (um 714 que fosse 710). Mas há
checagens que só a sua leitura de autor faz:

1. **Contexto correto** — o número existe na tese, mas está no lugar certo?
   (Ex.: o 714 é mesmo o efeito de ap na força, não de outra resposta?)
2. **Interpretações [INTERP]** — as explicações físicas (por que a liga dura
   exige menos força, o papel do livre-corte no cavaco) refletem o que você
   concluiu? Isso não é número; é sentido.
3. **Micrografias** — as descrições das 6 ligas (dispersóides, precipitados)
   batem com o que se vê nas imagens?
4. **Tabelas completas** — conferi os valores-destaque; as tabelas inteiras
   (ex.: todos os R² do PCC das 5 ligas no Cap 9) merecem um olhar.

## Recomendação

Os [DADO] críticos estão **confirmados** — o maior risco (erro de transcrição
de número) está controlado. Sua releitura pode focar nos [INTERP] e no
contexto, que é onde o julgamento de autor é insubstituível. Use o
CHECKLIST_REVISAO_COMPLETO.md para os itens [INTERP] e [TOM].

---

## Conferência estendida (adicionada)

Além dos 25 valores-destaque, conferi as tabelas de R² completas:

| Conjunto | Valores conferidos | Status |
|---|---|---|
| Cap 9 — R² do PCC (5 ligas × respostas) | 21/21 | ✓ todos conferem |
| Cap 10 — R² dos modelos globais | 7/7 | ✓ todos conferem |
| Cap 10 — p-níveis da validação 6351-T6 | 4/4 | ✓ todos conferem |

**Total geral: 57 valores numéricos conferidos, 57 confirmados na tese.**

O risco de erro de transcrição numérica está, portanto, muito bem controlado.
A sua releitura de autor pode concentrar-se com tranquilidade nos aspectos
interpretativos [INTERP], onde o seu julgamento é insubstituível.
