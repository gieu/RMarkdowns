# Produce a separate, complete site. Never overwrite the input checkout.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 2L && args[[1]] == "--render-one") {
  salida <- rmarkdown::render(args[[2]], encoding = "UTF-8", quiet = TRUE)
  stopifnot(file.exists(salida))
  quit(status = 0L)
}
if (length(args) != 2L) {
  stop("Uso: Rscript render-notebooks.R DIRECTORIO_FUENTE DIRECTORIO_NUEVO")
}
origen <- normalizePath(args[[1]], mustWork = TRUE)
padre <- normalizePath(dirname(args[[2]]), mustWork = TRUE)
destino <- file.path(padre, basename(args[[2]]))
if (file.exists(destino) || dir.exists(destino)) {
  stop("El directorio de salida ya existe: ", destino)
}
if (identical(destino, origen) || startsWith(destino, paste0(origen, "/"))) {
  stop("La salida debe estar fuera del directorio fuente.")
}
requeridos <- file.path(origen, c("markdowns", "datos"))
if (!all(dir.exists(requeridos))) {
  stop("La fuente debe contener las carpetas markdowns/ y datos/.")
}
stopifnot(requireNamespace("rmarkdown", quietly = TRUE))
stopifnot(rmarkdown::pandoc_available())
limite <- suppressWarnings(as.integer(Sys.getenv("RENDER_TIMEOUT_SECONDS", "120")))
if (is.na(limite) || limite <= 0L) stop("RENDER_TIMEOUT_SECONDS debe ser positivo.")

dir.create(destino)
sitio <- file.path(destino, "site")
logs <- file.path(destino, "logs")
dir.create(sitio)
dir.create(logs)
publicables <- file.path(
  origen, c("markdowns", "datos", "index.html", "asset-manifest.json", "static")
)
publicables <- publicables[file.exists(publicables)]
if (!all(file.copy(publicables, sitio, recursive = TRUE))) {
  stop("No se pudieron copiar todos los archivos del sitio.")
}
archivos <- sort(list.files(
  file.path(sitio, "markdowns"), pattern = "[.][Rr]md$",
  recursive = TRUE, full.names = TRUE
))
if (!length(archivos)) stop("No se encontraron cuadernos.")

script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
script <- normalizePath(script, mustWork = TRUE)
resultados <- vector("list", length(archivos))
for (i in seq_along(archivos)) {
  archivo <- archivos[[i]]
  nombre <- substring(archivo, nchar(sitio) + 2L)
  log <- file.path(logs, sprintf("%02d.log", i))
  cat(sprintf("[%d/%d] %s\n", i, length(archivos), nombre))
  estado <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script), "--render-one", shQuote(archivo)),
    stdout = log, stderr = log, timeout = limite
  ))
  resultados[[i]] <- data.frame(cuaderno = nombre, estado = as.integer(estado))
  if (estado != 0L) {
    cat(paste(tail(readLines(log, warn = FALSE), 14L), collapse = "\n"), "\n")
  }
}
# This runs as root but Shiny serves the site as "shiny". Directory modes are
# not tracked by Git, so a source copy can carry 700 and make an app unreadable.
if (system2("chmod", c("-R", "a+rX", shQuote(sitio))) != 0L) {
  stop("No se pudieron ajustar los permisos del sitio.")
}
tabla <- do.call(rbind, resultados)
write.table(
  tabla, file.path(destino, "resultados.tsv"), sep = "\t", row.names = FALSE
)
capture.output(sessionInfo(), file = file.path(destino, "entorno.txt"))
cat(sprintf("Renderizados correctamente: %d/%d\n", sum(tabla$estado == 0L), nrow(tabla)))
if (any(tabla$estado != 0L)) {
  stop("Hay cuadernos con errores. No publique esta preparación; revise logs/ y resultados.tsv.")
}
cat("SITIO PREPARADO: ", sitio, "\n", sep = "")
