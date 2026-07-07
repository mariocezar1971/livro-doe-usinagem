# =============================================================================
# Setup do ambiente R para o livro DOE em Usinagem
# =============================================================================
# Instala todos os pacotes R necessários para:
# - Renderização do livro via Quarto (knitr, rmarkdown)
# - DOE (FrF2, rsm, DoE.base, desirability)
# - Visualização (ggplot2, plotly, rgl)
# - Análise estatística (broom, performance)
# - Utilitários (tidyverse, here)
# =============================================================================

cat("\n=== Setup ambiente R - Livro DOE em Usinagem ===\n\n")

# Espelho CRAN
opcoes <- options(repos = c(CRAN = "https://cran.r-project.org"))

# Função utilitária: instalar se necessário
instalar_se_necessario <- function(pacote) {
  if (!requireNamespace(pacote, quietly = TRUE)) {
    cat(sprintf("Instalando: %s\n", pacote))
    install.packages(pacote, dependencies = TRUE, quiet = TRUE)
  } else {
    cat(sprintf("Ja instalado: %s\n", pacote))
  }
}

# Pacotes essenciais para Quarto
cat("\n--- Pacotes Quarto/Rmarkdown ---\n")
pacotes_quarto <- c(
  "knitr",
  "rmarkdown",
  "bookdown",
  "downlit",
  "tinytex",
  "yaml",
  "xfun"
)
invisible(lapply(pacotes_quarto, instalar_se_necessario))

# Verificar tinytex
cat("\n--- Verificando tinytex (LaTeX) ---\n")
if (!tinytex::is_tinytex()) {
  cat("Instalando tinytex (LaTeX leve)... pode demorar 5-10 minutos.\n")
  tinytex::install_tinytex(force = FALSE)
} else {
  cat("tinytex OK.\n")
}

# Pacotes para DOE
cat("\n--- Pacotes DOE ---\n")
pacotes_doe <- c(
  "FrF2",          # Fatorial 2^k
  "rsm",           # Superficies de resposta
  "DoE.base",      # Base DoE
  "DoE.wrapper",   # Wrappers
  "desirability",  # Desejabilidade Derringer-Suich
  "qualityTools",  # Controle de qualidade
  "pid"            # Process Improvement using Data
)
invisible(lapply(pacotes_doe, instalar_se_necessario))

# Pacotes para visualizacao
cat("\n--- Pacotes Visualização ---\n")
pacotes_viz <- c(
  "ggplot2",
  "plotly",
  "gganimate",
  "ggrepel",
  "patchwork",
  "viridis",
  "scales",
  "rgl"
)
invisible(lapply(pacotes_viz, instalar_se_necessario))

# Pacotes para analise estatistica
cat("\n--- Pacotes Análise estatística ---\n")
pacotes_stat <- c(
  "broom",
  "performance",
  "car",
  "MASS",
  "leaps",
  "GA"             # Algoritmo genético
)
invisible(lapply(pacotes_stat, instalar_se_necessario))

# Utilitarios
cat("\n--- Pacotes Utilitários ---\n")
pacotes_util <- c(
  "tidyverse",
  "here",
  "fs",
  "glue",
  "kableExtra",
  "gt",
  "DT"
)
invisible(lapply(pacotes_util, instalar_se_necessario))

# Reticulate (para Python via R)
cat("\n--- Pacote reticulate (R + Python) ---\n")
instalar_se_necessario("reticulate")

# Restaurar opcoes
options(opcoes)

# Sumario
cat("\n=== Setup concluído ===\n")
cat("\nVerificando instalações críticas:\n")

pacotes_criticos <- c("knitr", "rmarkdown", "FrF2", "rsm", "ggplot2", "reticulate", "tinytex")
for (p in pacotes_criticos) {
  status <- if (requireNamespace(p, quietly = TRUE)) "OK" else "FALHA"
  cat(sprintf("  %-15s : %s\n", p, status))
}

cat("\nPróximos passos:\n")
cat("  1. Abrir o projeto no RStudio\n")
cat("  2. Build do livro: comando no terminal -> quarto render\n")
cat("  3. Preview interativo: quarto preview\n\n")
