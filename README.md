# Planejamento de Experimentos em Usinagem

**Fatorial, RSM e otimização multiresposta aplicados às ligas de alumínio**

Repositório do livro em desenvolvimento por Mário Cezar dos Santos Jr.

[![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)]()
[![Quarto](https://img.shields.io/badge/quarto-book-blue)](https://quarto.org/)
[![License HTML](https://img.shields.io/badge/HTML-CC%20BY--NC--ND%204.0-lightgrey)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

## Sobre o livro

Livro técnico-didático que une rigor metodológico em Planejamento de Experimentos (DOE) com estudo de caso completo em torneamento de ligas de alumínio. Cobre planejamento fatorial 2^k, planejamento composto central (PCC), superfícies de resposta (RSM) e otimização multiresposta por algoritmo genético.

Mais informações: [doeusinagem.com.br](https://doeusinagem.com.br) (em construção)

## Público-alvo

- Alunos de pós-graduação em Engenharia Mecânica, Produção e Materiais
- Professores de DOE e Usinagem
- Engenheiros de processo, qualidade e P&D

## Estrutura do projeto

```
LIVRO_DOE_USINAGEM/
├── _quarto.yml              # Configuração principal do Quarto book
├── index.qmd                # Prefácio
├── parte-1/                 # Fundamentos (Cap 1-3)
├── parte-2/                 # Metodologia DOE (Cap 4-6)
├── parte-3/                 # Estudo de caso (Cap 7-10)
├── parte-4/                 # Aplicação (Cap 11-12)
├── apendices/               # Apêndices A-D
├── figuras/                 # Imagens do livro
├── codigos/                 # Códigos R e Python
│   ├── R/
│   └── python/
├── dados/                   # Dados experimentais
├── styles/                  # CSS, SCSS, LaTeX preamble
├── setup/                   # Scripts de instalação
└── .github/workflows/       # Actions para deploy automático
```

## Setup do ambiente

### Pré-requisitos

- [Quarto CLI](https://quarto.org/docs/get-started/) >= 1.5
- [R](https://cran.r-project.org/) >= 4.3
- [Python](https://www.python.org/) >= 3.10 (opcional para Cap 6)
- [RStudio](https://posit.co/download/rstudio-desktop/) (recomendado)

### Instalação automatizada (Windows)

```powershell
# No PowerShell, dentro da pasta do projeto:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup\setup-projeto.ps1
```

### Instalação manual

```bash
# 1. Instalar pacotes R
Rscript setup/setup-r-env.R

# 2. Instalar pacotes Python
pip install -r setup/requirements.txt

# 3. Renderizar o livro
quarto render
```

## Como contribuir

Este é um projeto de autoria individual durante o desenvolvimento. Sugestões, erratas e correções podem ser enviadas via:

- Issues do GitHub
- E-mail: mariocezarsj@gmail.com

## Licença

- **Versão HTML aberta**: [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)
- **Versão PDF/EPUB paga**: Todos os direitos reservados
- **Versão impressa**: Todos os direitos reservados
- **Códigos**: [MIT License](https://opensource.org/licenses/MIT)

## Citação

Caso utilize este livro como referência acadêmica:

> Santos Jr., M. C. (2027). *Planejamento de Experimentos em Usinagem: Fatorial, RSM e otimização multiresposta aplicados às ligas de alumínio*. 1. ed. Vila Velha, ES: Edição do autor. ISBN: a definir.

## Autor

**Mário Cezar dos Santos Jr.**
Instituto Federal do Espírito Santo (IFES) — Campus Vila Velha
ORCID: [a definir]
LinkedIn: [linkedin.com/in/mariocezar](https://linkedin.com/in/mariocezar)

---

*Construído com [Quarto](https://quarto.org/) e código aberto.*
