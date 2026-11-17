# Install only missing dependencies from the snapshot used by this deployment.
args <- commandArgs(trailingOnly = TRUE)
if (!identical(args, character()) && !identical(args, "--check")) {
  stop("Uso: Rscript install-deps.R [--check]")
}
if (getRversion() != package_version("4.1.2")) {
  stop("Este entorno requiere R 4.1.2. Ejecute el script dentro de su imagen Docker.")
}

repo <- "https://packagemanager.rstudio.com/cran/__linux__/focal/2022-03-09"
# --vanilla skips the image's Rprofile.site, which is what sets this header.
# Without it the repository serves source tarballs, which need build tools
# (e.g. cmake for nloptr) that the image does not have.
options(HTTPUserAgent = sprintf(
  "R/%s R (%s)", getRversion(),
  paste(getRversion(), R.version$platform, R.version$arch, R.version$os)
))
paquetes <- c(
  "shiny", "httpuv", "later", "shiny.i18n", "xml2", "fontawesome",
  "rmarkdown", "knitr", "learnr", "htmltools", "ggplot2", "readxl",
  "Hmisc", "psych", "ggalluvial", "reshape", "ggdendro", "tibble",
  "msm", "tidyverse", "dplyr", "ggpubr", "car",
  "DiagrammeR", "gtools", "combinat", "Rmisc"
)
disponibles <- vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)
if (!identical(args, "--check") && any(!disponibles)) {
  install.packages(paquetes[!disponibles], repos = repo)
}

disponibles <- vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)
if (any(!disponibles)) {
  stop("No se pudieron cargar: ", paste(paquetes[!disponibles], collapse = ", "))
}
stopifnot(rmarkdown::pandoc_available())
if (as.character(rmarkdown::pandoc_version()) != "3.14") {
  stop("La imagen debe utilizar Pandoc 3.14.")
}
print(vapply(paquetes, function(p) as.character(packageVersion(p)), character(1)))
